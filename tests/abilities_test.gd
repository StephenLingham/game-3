extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _physics_frames(3)

	# Spawning remains rate-only and is now four times faster than before.
	_check(is_equal_approx(scene._enemy_spawn_interval(0.0), 0.25), "opening enemy spawn rate is quadrupled")
	_check(is_equal_approx(scene._enemy_spawn_interval(600.0), 0.0375), "late enemy spawn rate is quadrupled")
	var count_before: int = get_nodes_in_group("enemies").size()
	scene.enemy_spawn_clock = 0.0
	scene._process(0.01)
	_check(get_nodes_in_group("enemies").size() == count_before + 1, "spawn clock creates an enemy without a population cap")
	_check(is_equal_approx(scene.STAR_SPAWN_INTERVAL, 120.0) and is_equal_approx(scene.MAGNET_SPAWN_INTERVAL, 14.0), "star power spawns every two minutes without slowing magnet spawns")
	var stars_before := 0
	for pickup in get_nodes_in_group("pickups"):
		if pickup.kind == "star":
			stars_before += 1
	scene.star_spawn_clock = 0.0
	scene.magnet_spawn_clock = 999.0
	scene._process(0.01)
	var stars_after := 0
	for pickup in get_nodes_in_group("pickups"):
		if pickup.kind == "star":
			stars_after += 1
	_check(stars_after == stars_before + 1 and is_equal_approx(scene.star_spawn_clock, 120.0), "star clock spawns one star and resets to two minutes")

	var player: CharacterBody3D = scene.player
	player._perform_mega_jump()
	_check(player.velocity.y == player.MEGA_JUMP_VELOCITY and player.mega_air_jumps_remaining == 2, "mega jump launches high and grants two air jumps")
	player._perform_mega_air_jump()
	player._perform_mega_air_jump()
	_check(player.mega_air_jumps_remaining == 0 and is_equal_approx(player.velocity.y, player.JUMP_VELOCITY), "mega jump chain ends after the triple jump")
	player.rotation.y = 0.0
	player._perform_long_jump()
	_check(Vector2(player.velocity.x, player.velocity.z).length() >= 26.9 and player.velocity.z < 0.0, "long jump launches quickly forward")

	player._start_dash()
	scene.player_health = 50.0
	player.take_damage(12.0)
	_check(player.is_dashing() and is_equal_approx(scene.player_health, 50.0), "dash works in any movement state and blocks contact damage")

	var enemies := get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(35.0, 0.05, 35.0)
	var target: Node = enemies[0]
	target.global_position = player.global_position + Vector3(3.0, 0.05, 0.0)
	target.velocity = Vector3.ZERO
	scene._use_skill(1)
	_check(target.velocity.x > 0.0, "shock wave knocks nearby enemies away")
	var wide_target: Node = enemies[4]
	wide_target.global_position = player.global_position + Vector3(15.0, 0.05, 0.0)
	wide_target.velocity = Vector3.ZERO
	scene._use_skill(1)
	_check(wide_target.velocity.x > 0.0, "shock wave reaches the widened radius")
	scene._use_skill(2)
	_check(target.freeze_timer >= 3.9, "frost nova freezes nearby enemies")
	_check(get_nodes_in_group("frost_nova_visuals").size() == 1, "frost nova creates an ice-ring visual")
	var effects_before_nuke: int = get_nodes_in_group("skill_effects").size()
	var health_before: float = target.health
	scene._use_skill(3)
	_check(target.defeated or target.health < health_before - 800.0, "nuke deals high area damage")
	_check(get_nodes_in_group("skill_effects").size() > effects_before_nuke, "nuke creates a fast expanding sphere")
	scene._use_skill(4)
	_check(get_nodes_in_group("vortices").size() == 1, "vortex skill launches a black pulling sphere")
	_check(scene.VortexScript.PULL_RADIUS >= 150.0, "vortex reaches enemies across the whole map")
	var vortex: Node = get_nodes_in_group("vortices")[0]
	vortex.set_physics_process(false)
	var vortex_target: Node = enemies[2]
	var vortex_core := Vector3(0.0, 0.05, 0.0)
	vortex_target.global_position = Vector3(45.0, 0.05, 0.0)
	for frame in 240:
		vortex_target.pull_toward(vortex_core, vortex.PULL_FORCE, 1.0 / 60.0)
	_check(vortex_target.global_position.distance_to(vortex_core) <= 1.36, "vortex pulls a far enemy into its capture core")
	vortex_target.global_position = vortex_core + Vector3(0.5, 0.0, 0.0)
	vortex_target.velocity = Vector3(100.0, 0.0, 0.0)
	vortex_target.pull_toward(vortex_core, vortex.PULL_FORCE, 1.0 / 60.0)
	_check(vortex_target.vortex_hold_timer > 0.0 and vortex_target.velocity.is_zero_approx(), "captured enemies stay in the vortex instead of crossing it")

	var mega_count_before := get_nodes_in_group("mega_fireballs").size()
	scene._fire_mega_fireball()
	_check(get_nodes_in_group("mega_fireballs").size() == mega_count_before + 1, "Q ability launches a giant straight-flying fireball")
	var mega_fireball: Node3D = get_nodes_in_group("mega_fireballs")[0]
	var mega_target: Node = enemies[3]
	mega_target.global_position = mega_fireball.global_position + mega_fireball.direction * 6.0
	await _physics_frames(20)
	_check(not is_instance_valid(mega_target) or mega_target.defeated, "giant fireball kills enemies it touches without changing course")
	_check(is_instance_valid(scene.health_bar) and scene.health_bar.max_value == 100.0 and "/" in scene.health_label.text and not "Health" in scene.health_label.text, "player health is overlaid numerically on its top-left bar")
	_check(scene.health_bar.get_theme_stylebox("background") is StyleBoxEmpty, "player health displays only the red fill without an outer track")
	_check(scene.health_bar.get_global_rect().end.x < scene.xp_bar.get_global_rect().position.x, "top-left health bar does not overlap the centered level bar")
	_check(is_equal_approx(scene.xp_bar.anchor_left, 0.5) and scene.level_label.text.begins_with("Level "), "centered XP bar displays only the title-case player level")
	_check(scene.xp_label.get_parent() != scene.xp_bar and "XP" in scene.xp_label.text, "XP statistics are displayed below the XP bar")
	scene._update_hud()
	_check("Spawn" in scene.wave_label.text and "%d Alive" % scene._alive_enemy_count() in scene.wave_label.text, "HUD displays the spawn rate and current living enemy count")
	_check(scene.wave_label.global_position.y >= scene.xp_bar.global_position.y + scene.xp_bar.size.y, "top-right status text sits below the level bar")
	var upgrade_card: Button = scene._create_upgrade_card(scene._make_offer("damage"), 0)
	_check(upgrade_card.mouse_filter == Control.MOUSE_FILTER_STOP and upgrade_card.focus_mode == Control.FOCUS_NONE and not upgrade_card.pressed.get_connections().is_empty(), "level-up cards can be clicked while numeric shortcuts remain available")
	upgrade_card.free()

	# A magnet affects XP already on the map, not unrelated collectible types.
	scene._spawn_xp(player.global_position + Vector3(12.0, 0.0, 0.0))
	var xp_pickups: Array[Node] = []
	for pickup in get_nodes_in_group("pickups"):
		if pickup.kind == "xp":
			xp_pickups.append(pickup)
	scene._on_pickup_collected("magnet", 1.0)
	var all_magnetized := not xp_pickups.is_empty()
	for pickup in xp_pickups:
		all_magnetized = all_magnetized and pickup.magnetized
	_check(all_magnetized, "magnet pulls every uncollected XP orb")
	var silver_xp := false
	for pickup in xp_pickups:
		for child in pickup.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var xp_color: Color = child.material_override.albedo_color
				silver_xp = absf(xp_color.r - xp_color.g) < 0.08 and absf(xp_color.g - xp_color.b) < 0.08
	_check(silver_xp, "XP pickups are silver")

	scene._spawn_powerup("star")
	scene._spawn_powerup("magnet")
	var star_shaped := false
	var magnet_blue := false
	for pickup in get_nodes_in_group("pickups"):
		if pickup.kind == "star":
			for child in pickup.get_children():
				if child is MeshInstance3D and child.mesh is ArrayMesh:
					star_shaped = true
		elif pickup.kind == "magnet":
			for child in pickup.get_children():
				if child is Label3D:
					magnet_blue = child.modulate.b > child.modulate.r
	_check(star_shaped, "star power pickup uses a five-point star mesh")
	_check(magnet_blue, "magnet pickup and its world text are blue")

	# Star power lasts five seconds, grants contact immunity, and kills on touch.
	var star_target: Node = enemies[1]
	star_target.global_position = player.global_position + Vector3(0.5, 0.0, 0.0)
	star_target.defeated = false
	scene._on_pickup_collected("star", 1.0)
	await physics_frame
	player._handle_enemy_contacts()
	_check(player.is_star_powered() and player.star_power_timer > 4.9, "star power activates for five seconds")
	_check(star_target.defeated, "star power instantly defeats enemies on contact")

	if failures.is_empty():
		print("ABILITIES TEST PASSED: spawning, traversal, skills, star power, and magnet")
		quit(0)
	else:
		for failure in failures:
			push_error("ABILITIES TEST FAILED: " + failure)
		quit(1)

func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: " + description)
	elif not failures.has(description):
		failures.append(description)
