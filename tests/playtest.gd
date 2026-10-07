extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _physics_frames(3)

	_check(scene.player != null, "player spawned")
	_check(DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "game window starts maximized")
	_check(get_nodes_in_group("enemies").size() >= 7, "enemy pack spawned")
	var first_enemy: Node = get_nodes_in_group("enemies")[0]
	_check(is_instance_valid(first_enemy.health_bar_fill), "enemies display an overhead health bar")
	_check(first_enemy.max_health in scene.ENEMY_HEALTH and first_enemy.health_bar_text.text.ends_with("/ %d" % int(first_enemy.max_health)), "enemy health bar displays its fixed type health")
	_check(get_nodes_in_group("pickups").size() >= 4, "world collectibles spawned")

	# Exercise the exact camera rotation helper used by live mouse-motion events.
	var yaw_before: float = scene.player.rotation.y
	var pitch_before: float = scene.player.head.rotation.x
	scene.player._apply_mouse_look(Vector2(120.0, -60.0))
	_check(scene.player.rotation.y < yaw_before, "mouse X turns the player")
	_check(scene.player.head.rotation.x > pitch_before, "mouse Y pitches the camera")
	scene.player.rotation.y = 0.0
	scene.player.head.rotation.x = 0.0

	# Drive movement through Godot's action input state.
	var start_position: Vector3 = scene.player.global_position
	Input.action_press("move_forward")
	await _physics_frames(30)
	Input.action_release("move_forward")
	_check(scene.player.global_position.distance_to(start_position) > 1.0, "WASD movement changes position")

	# Perform four real grounded jumps through the jump action.
	for hop_number in range(1, 5):
		await _wait_for_floor(scene.player, 180)
		Input.action_press("jump")
		await physics_frame
		Input.action_release("jump")
		await physics_frame
		_check(scene.player.hop_chain == hop_number, "hop %d advances the speed chain" % hop_number)
	_check(scene.player.hop_chain == 4, "fourth hop reaches the full chain")

	await _wait_for_floor(scene.player, 180)
	# Place a stationary opening-wave enemy in the crosshair and hit it.
	var enemies := get_nodes_in_group("enemies")
	var target: Node3D = enemies[0]
	target.max_health = 200.0
	target.health = 200.0
	target._update_health_bar()
	scene.enemy_spawn_clock = 999.0
	for enemy_index in enemies.size():
		enemies[enemy_index].set_physics_process(false)
		if enemies[enemy_index] != target:
			enemies[enemy_index].global_position = Vector3(35.0, 0.05, -35.0 + enemy_index * 2.0)
	target.global_position = scene.player.global_position + Vector3(0, 0.05, -6.0)
	scene.player.head.look_at(target.global_position + Vector3.UP * 0.68, Vector3.UP)
	await physics_frame
	var kills_before: int = scene.kills
	var health_bar_reacted := false
	var health_text_reacted := false
	for shot in 2:
		scene._on_player_fire(scene.player.muzzle.global_position, -scene.player.camera.global_transform.basis.z)
		await _physics_frames(36)
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			if target.health_bar_fill.scale.x < 1.0:
				health_bar_reacted = true
			if target.health_bar_text.text != "300 / 300":
				health_text_reacted = true
			print("  COMBAT TRACE: shot %d, target health %.1f, live projectiles %d" % [shot + 1, target.health, get_nodes_in_group("projectiles").size()])
		else:
			print("  COMBAT TRACE: shot %d defeated target" % (shot + 1))
	_check(scene.kills > kills_before, "two 100-damage fireballs defeat a 200 HP enemy")
	_check(health_bar_reacted, "enemy health bar shrinks when damage is dealt")
	_check(health_text_reacted, "enemy health text updates when damage is dealt")
	_check(get_nodes_in_group("pickups").size() > 4, "defeated enemy drops XP cubes")
	_check(get_nodes_in_group("damage_numbers").size() > 0, "fireball hits display floating damage numbers")

	# One bounce should damage the aimed cube, then redirect to a second cube.
	var bounce_a: Node3D = enemies[1]
	var bounce_b: Node3D = enemies[2]
	bounce_a.global_position = scene.player.global_position + Vector3(0, 0.05, -6.0)
	bounce_b.global_position = scene.player.global_position + Vector3(5.0, 0.05, -10.0)
	var bounce_a_health: float = bounce_a.health
	var bounce_b_health: float = bounce_b.health
	scene.stats.bounces = 1
	scene.stats.crit = 0.0
	scene.player.head.look_at(bounce_a.global_position + Vector3.UP * 0.68, Vector3.UP)
	scene._on_player_fire(scene.player.muzzle.global_position, -scene.player.camera.global_transform.basis.z)
	var locked_on := false
	for lock_frame in 45:
		for active_projectile in get_nodes_in_group("projectiles"):
			if active_projectile.homing_target == bounce_b:
				locked_on = true
				break
		if locked_on:
			break
		await physics_frame
	# Move the target after the ricochet has already committed to its old path.
	bounce_b.global_position += Vector3(-8.0, 0.0, 0.0)
	await _physics_frames(60)
	_check(not is_instance_valid(bounce_a) or bounce_a.health < bounce_a_health, "ricochet damages the first enemy")
	_check(locked_on, "ricochet locks onto its next enemy")
	_check(not is_instance_valid(bounce_b) or bounce_b.health < bounce_b_health, "locked ricochet adjusts course and hits a moving enemy")
	scene.stats.bounces = 0

	# Gold relics grant immediate progress based on the current level and retain
	# their permanent pickup-range increase.
	scene.xp = 0.0
	var relic_xp_grant: float = scene.xp_needed * 0.25
	var range_before_relic: float = scene.collection_radius
	scene._on_pickup_collected("relic", 1.0)
	_check(is_equal_approx(scene.xp, relic_xp_grant), "gold relic grants 25% of the current level XP requirement")
	_check(is_equal_approx(scene.collection_radius, range_before_relic + 0.55), "gold relic still increases collection radius")
	_check(scene.pickup_message.visible and "Gold Relic" in scene.pickup_message.text, "gold relic displays its pickup message")

	# Damage should flash the screen edges, then health should regenerate.
	scene.player_health = 60.0
	scene._on_player_hurt(10.0)
	_check(scene.hit_material.get_shader_parameter("intensity") > 0.8, "taking damage flashes the red edge vignette")
	scene._process(2.0)
	_check(is_equal_approx(scene.player_health, 54.0), "health regenerates at 2 HP per second")

	# Exercise the complete level-up pause/selection/resume path.
	scene.xp = scene.xp_needed
	var next_level: int = scene.level + 1
	scene._check_level_up()
	_check(scene.upgrade_active, "full XP bar opens the upgrade screen")
	_check(scene.current_offers.size() == 3, "upgrade screen presents three choices")
	_check(scene.upgrade_overlay.color.a == 0.0, "level-up choices leave the game visible behind them")
	_check(is_equal_approx(scene.xp_needed, scene._xp_required_for_level(next_level)), "level-up applies the progressive XP curve")
	var number_key := InputEventKey.new()
	number_key.pressed = true
	number_key.keycode = KEY_1
	scene._input(number_key)
	_check(scene.upgrade_active, "number keys do not select a level-up option")
	var first_upgrade_card: Button = scene.cards_row.get_child(0)
	first_upgrade_card.pressed.emit()
	_check(not scene.upgrade_active and not paused, "clicking an upgrade resumes gameplay")
	_check(scene._enemy_spawn_interval(600.0) < scene._enemy_spawn_interval(0.0), "enemy spawn interval decreases over time")
	_check(is_equal_approx(scene._enemy_spawn_interval(0.0), 1.0 / scene.GameConsts.ENEMY_SPAWN_RATES[0]) and is_equal_approx(scene._enemy_spawn_interval(scene.RUN_DURATION), 1.0 / scene.GameConsts.ENEMY_SPAWN_RATES.back()), "enemy spawn endpoints follow the balance constants")
	_check(scene._enemy_health_multiplier(600.0) > scene._enemy_health_multiplier(0.0), "new enemy health increases over time")
	_check(scene._enemy_health_for_type(0) == 100.0 and scene._enemy_health_for_type(9) == scene.GameConsts.ENEMY_HEALTH[9] and scene.ENEMY_COLORS.size() == 10, "ten coloured enemy types use the configured health table")

	var elapsed_before_pause: float = scene.elapsed
	scene._set_pause(true)
	_check(scene.pause_active and paused and scene.pause_overlay.visible, "Escape pause state stops the game and displays its screen")
	scene._process(2.0)
	_check(is_equal_approx(scene.elapsed, elapsed_before_pause), "survival timer does not advance while paused")
	scene._set_pause(false)
	_check(not scene.pause_active and not paused and not scene.pause_overlay.visible, "resuming hides the pause screen and continues gameplay")

	# Surviving the full timer wins without a boss or clearing remaining enemies.
	scene.elapsed = scene.RUN_DURATION - 0.1
	scene._process(0.2)
	_check(scene.game_over and paused, "surviving ten minutes ends the run")
	_check(root.get_node("RunStats").last_run.won, "ten-minute survival records victory")
	await process_frame
	await process_frame
	_check(current_scene.name == "Results" and not paused, "ten-minute survival opens the separate results screen")

	Input.action_release("move_forward")
	Input.action_release("jump")
	if failures.is_empty():
		print("PLAYTEST PASSED: movement, combat, pickups, healing, damage VFX, upgrades, and victory")
		quit(0)
	else:
		for failure in failures:
			push_error("PLAYTEST FAILED: " + failure)
		quit(1)

func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _wait_for_floor(body: CharacterBody3D, max_frames: int) -> void:
	for frame in max_frames:
		if body.is_on_floor():
			return
		await physics_frame
	_failures_append_once("player did not return to the floor")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: " + description)
	else:
		_failures_append_once(description)

func _failures_append_once(description: String) -> void:
	if not failures.has(description):
		failures.append(description)
