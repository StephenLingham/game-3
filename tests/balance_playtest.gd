extends SceneTree

# A real run: movement/fire input, physical projectiles, earned XP and offered
# upgrades only. No teleporting, damage injection, stat grants or timer skips.
# godot --headless --path . --fixed-fps 60 --script tests/balance_playtest.gd -- --seed=11 --pilot=skilled
var scene: Node
var pilot := "skilled"
var run_seed := 11
var next_report := 60.0
var peak_alive := 0
var final_minimum_health := 100.0
var damage_taken := 0.0
var final_damage_taken := 0.0
var minimum_health := 100.0
var orbit_sign := 1.0
var action_releases := {}
var max_time := 601.0
var capture := false

class PlaytestRecords:
	extends "res://scripts/run_stats.gd"
	func _save() -> void:
		pass # Native visual playtests must not change the player's records.

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): run_seed = int(arg.get_slice("=", 1))
		if arg.begins_with("--pilot="): pilot = arg.get_slice("=", 1)
		if arg.begins_with("--seconds="): max_time = float(arg.get_slice("=", 1))
		if arg == "--capture": capture = true
	call_deferred("_run")

func _run() -> void:
	root.get_node("RunStats").set_script(PlaytestRecords)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	seed(run_seed)
	if capture and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene.player.hurt.connect(func(amount: float):
		damage_taken += amount
		if scene.elapsed >= scene.RUN_DURATION * 0.9: final_damage_taken += amount)
	Input.action_press("fire")
	physics_frame.connect(_drive)

func _drive() -> void:
	if not is_instance_valid(scene): return
	if scene.pause_active: return
	minimum_health = minf(minimum_health, scene.player_health)
	peak_alive = maxi(peak_alive, scene._alive_enemy_count())
	if scene.elapsed >= scene.RUN_DURATION * 0.9: final_minimum_health = minf(final_minimum_health, scene.player_health)
	if scene.elapsed >= next_report:
		_report()
		next_report += 60.0
	if scene.game_over or scene.elapsed >= max_time:
		_report()
		print("RESULT seed=%d pilot=%s victory=%s finished_at=%.2f hp=%.1f minimum_hp=%.1f final_minimum_hp=%.1f damage=%.1f final_damage=%.1f peak_alive=%d" % [run_seed, pilot, scene.game_over and scene.elapsed >= scene.RUN_DURATION and scene.player_health > 0.0, scene.elapsed, scene.player_health, minimum_health, final_minimum_health, damage_taken, final_damage_taken, peak_alive])
		for action in ["fire", "move_forward", "move_back", "move_left", "move_right", "jump", "dash"]: Input.action_release(action)
		quit(0)
		return
	if scene.upgrade_active:
		var best := 0
		var score := -INF
		for i in scene.current_offers.size():
			var candidate := _upgrade_score(scene.current_offers[i])
			if candidate > score:
				score = candidate
				best = i
		scene._choose_upgrade(best)
		return
	for action in action_releases.keys():
		action_releases[action] -= 1
		if action_releases[action] <= 0:
			Input.action_release(action)
			action_releases.erase(action)
	var p: Node3D = scene.player
	var pos: Vector3 = p.global_position
	var nearest: Node3D
	var nearest_distance := INF
	var alive := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.defeated: continue
		alive += 1
		var distance: float = pos.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	var aim: Node3D = nearest
	if is_instance_valid(aim):
		var center: Vector3 = aim.global_position + Vector3.UP * 0.68 * aim.scale.y
		# Lead a moving target by its projectile flight time.
		center += Vector3(aim.velocity.x, 0.0, aim.velocity.z) * p.camera.global_position.distance_to(center) / scene.GameConsts.FIREBALL_SPEED
		var dir: Vector3 = center - p.camera.global_position
		var desired_yaw := atan2(-dir.x, -dir.z)
		p.rotation.y = rotate_toward(p.rotation.y, desired_yaw, 0.055 if pilot == "skilled" else 0.025)
		p.head.rotation.x = clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -1.45, 1.45)
	# Headless DisplayServer cannot capture a cursor, so mirror the held-fire
	# path with the same cooldown and real projectiles (no synthetic hits).
	if DisplayServer.get_name() == "headless" and p.fire_cooldown <= 0.0:
		p.fire_cooldown = p.attack_interval
		scene._on_player_fire(p.muzzle.global_position, -p.camera.global_transform.basis.z)
	# Follow a circle through the arena; turn inward when a wall/tree blocks us.
	var horizontal := Vector3(pos.x, 0.0, pos.z)
	var radial := horizontal.normalized() if horizontal.length() > 0.1 else Vector3.RIGHT
	var desired := radial.cross(Vector3.UP) * orbit_sign + radial * clampf((21.0 - horizontal.length()) / 5.0, -1.0, 1.0)
	# Deliberately collect real magnets/relics instead of granting XP to the pilot.
	var pickup_target: Node3D
	var pickup_distance := 24.0
	for pickup in get_nodes_in_group("pickups"):
		if pickup.kind == "xp": continue
		var distance: float = pos.distance_to(pickup.global_position)
		if distance < pickup_distance:
			pickup_target = pickup
			pickup_distance = distance
	if is_instance_valid(pickup_target) and nearest_distance > 5.0:
		desired = pickup_target.global_position - pos
		desired.y = 0.0
	if is_instance_valid(nearest) and nearest_distance < 4.0:
		var away := pos - nearest.global_position
		away.y = 0.0
		desired += away.normalized() * 1.3
	var local := p.transform.basis.inverse() * desired.normalized()
	_set_axis("move_right", "move_left", local.x)
	_set_axis("move_back", "move_forward", local.z)
	if pilot == "skilled" and p.is_on_floor(): _pulse("jump")
	if nearest_distance < 5.0 and p.dash_cooldown <= 0.0 and pilot == "skilled": _pulse("dash")
	if pilot != "passive":
		if alive > 8: scene._use_skill(3)
		if nearest_distance < 7.0: scene._use_skill(2)
		if alive > 15: scene._use_skill(4)
		if nearest_distance < 4.0: scene._use_skill(1)
		if is_instance_valid(aim) and absf(angle_difference(p.rotation.y, atan2(-(aim.global_position - pos).x, -(aim.global_position - pos).z))) < 0.1:
			scene._fire_mega_fireball()

func _set_axis(positive: String, negative: String, value: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if value > 0.05: Input.action_press(positive, value)
	elif value < -0.05: Input.action_press(negative, -value)

func _pulse(action: String) -> void:
	if action_releases.has(action): return
	Input.action_press(action)
	action_releases[action] = 3

func _upgrade_score(offer: Dictionary) -> float:
	var amount: float = offer.amount
	match offer.kind:
		"damage": return amount / scene.stats.damage
		"attack_speed": return amount / 100.0 / scene.stats.attack_speed
		"crit": return amount / 100.0 / (1.0 + scene.stats.crit)
		"projectiles": return amount * 0.18 / float(scene.stats.projectiles) if scene.stats.projectiles < 5 else 0.005
		"bounces": return amount * 0.2 / float(scene.stats.bounces + 1) if scene.stats.bounces < 3 else 0.005
		"radius": return amount * 0.18 / scene.stats.radius
	return 0.0

func _report() -> void:
	print("TRACE t=%.2f physics=%d hop=%d pos=%s hp=%.1f level=%d kills=%d alive=%d stats=%s" % [scene.elapsed, Engine.get_physics_frames(), scene.player.hop_chain, scene.player.position, scene.player_health, scene.level, scene.kills, scene._alive_enemy_count(), scene.stats])
	if capture and DisplayServer.get_name() != "headless": _capture.call_deferred(int(scene.elapsed))

func _capture(second: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.testdata/horde-%d-%s-%d.png" % [run_seed, pilot, second])
