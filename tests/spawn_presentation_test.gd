extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.player.set_physics_process(false)
	var settings = scene.GameConsts
	var opening := get_nodes_in_group("enemies")
	assert(opening.size() == settings.INITIAL_ENEMY_COUNT)
	# The opening seven arrive in two real spatial groups (4 + 3).
	for group in [opening.slice(0, 4), opening.slice(4, 7)]:
		for enemy in group:
			assert(enemy.emerging and enemy.collision_layer == 0)
			enemy.set_physics_process(false)
			for other in group:
				assert(enemy.position.distance_to(other.position) <= 2.0 * settings.ENEMY_CLUMP_RADIUS + 0.001)
	for enemy in opening:
		enemy.free()
	seed(711)
	scene.player.position = Vector3.ZERO
	scene.player.velocity = Vector3.ZERO
	# Whole clumps fit the annulus and walls, even when movement points outwards.
	for player_pos in [Vector3.ZERO, Vector3(46, 0, 0), Vector3(-46, 0, 0), Vector3(0, 0, 46), Vector3(0, 0, -46), Vector3(46, 0, 46), Vector3(-46, 0, -46)]:
		scene.player.position = player_pos
		scene.player.velocity = player_pos.normalized() * 9.0
		for count in range(1, settings.ENEMY_CLUMP_MAX_SIZE + 1):
			for sample in 40:
				var positions: Array[Vector3] = scene._enemy_clump_positions(count)
				assert(positions.size() == count)
				for i in count:
					var spawn := positions[i]
					assert(absf(spawn.x) <= settings.ENEMY_SPAWN_EDGE and absf(spawn.z) <= settings.ENEMY_SPAWN_EDGE)
					var distance := Vector2(spawn.x - player_pos.x, spawn.z - player_pos.z).length()
					assert(distance >= settings.ENEMY_SPAWN_DISTANCE_MIN - 0.001 and distance <= settings.ENEMY_SPAWN_DISTANCE_MAX + 0.001)
					for j in range(i + 1, count):
						assert(spawn.distance_to(positions[j]) >= 2.0, "Clump members have clearance for the largest enemy")
	scene.player.position = Vector3.ZERO
	# Camera rotation must not override actual forward, backward or strafe motion.
	for movement in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		scene.player.velocity = movement * 9.0
		var ahead := 0
		for sample in 400:
			var positions: Array[Vector3] = scene._enemy_clump_positions(6)
			var centre := Vector3.ZERO
			for pos in positions:
				centre += pos
			centre /= float(positions.size())
			if centre.dot(movement) > 0.0:
				ahead += 1
		assert(ahead >= 320, "Movement bias must put most clumps ahead of travel")
	scene.player.velocity = Vector3(0.0, 15.0, 0.0)
	var quadrants := [0, 0, 0, 0]
	for sample in 400:
		var spawn: Vector3 = scene._enemy_spawn_position()
		quadrants[(0 if spawn.x < 0.0 else 1) + (0 if spawn.z < 0.0 else 2)] += 1
	for count in quadrants:
		assert(count >= 60, "Jumping in place keeps all horizontal directions available")
	# Low income waits for a batch instead of creating isolated trickle spawns.
	scene.elapsed = 0.0
	scene.enemy_spawn_clock = 0.0
	scene.enemy_spawn_credits = 1.0
	scene._update_enemy_spawning(settings.ENEMY_SPAWN_TICK)
	assert(scene._alive_enemy_count() == 0)
	scene.enemy_spawn_credits = 3.0
	scene._update_enemy_spawning(settings.ENEMY_SPAWN_TICK)
	assert(scene._alive_enemy_count() == 3)
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	# Exercise the actual spawn path and the staggered underground appearance.
	scene.player.velocity = Vector3.FORWARD * 9.0
	scene._spawn_enemy_clumps(6)
	var enemies := get_nodes_in_group("enemies")
	var centre := Vector3.ZERO
	for enemy in enemies:
		enemy.set_physics_process(false)
		centre += enemy.position
		assert(enemy.emerging and enemy.collision_layer == 0 and enemy.collision_mask == 0)
		assert(not enemy.health_bar_root.visible)
		var top: float = enemy.position.y + (enemy.appearance_root.position.y + 1.355) * enemy.scale.y
		assert(top < 0.0, "New bodies start completely under the ground")
	centre /= float(enemies.size())
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		scene.player.camera.global_position = centre + Vector3(7, 5, 11)
		scene.player.camera.look_at(centre + Vector3.UP * 0.7, Vector3.UP)
	await _capture("buried")
	var first = enemies[0]
	var origin: Vector3 = first.position
	first._physics_process(0.4)
	assert(first.emerging and is_equal_approx(first.appearance_root.position.y, -settings.ENEMY_EMERGENCE_DEPTH * 0.5))
	assert(first.position == origin and first.velocity == Vector3.ZERO, "Emerging bodies stay grounded and don't chase")
	first.apply_knockback(Vector3.ZERO, 31.0)
	first.pull_toward(Vector3.UP * 4.0, 38.0, 0.1)
	assert(first.position == origin and first.velocity == Vector3.ZERO)
	for enemy in enemies.slice(1):
		enemy._advance_emergence(0.4)
	assert(enemies.back().appearance_root.position.y < first.appearance_root.position.y, "Clump members rise with a small stagger")
	# A paused tree does not advance emergence through the normal physics loop.
	first.set_physics_process(true)
	scene._set_pause(true)
	var paused_height: float = first.appearance_root.position.y
	for frame in 3:
		await physics_frame
	assert(first.appearance_root.position.y == paused_height)
	scene._set_pause(false)
	first.set_physics_process(false)
	await _capture("rising")
	# Buried colliders and bounce targets remain unavailable until the rise ends.
	var fireball = scene.FireballScript.new()
	scene.add_child(fireball)
	assert(fireball._find_bounce_target() == null)
	for enemy in enemies:
		enemy._advance_emergence(2.0)
		assert(not enemy.emerging and enemy.appearance_root.position.is_zero_approx())
		assert(enemy.health_bar_root.visible and enemy.collision_layer == 4 and enemy.collision_mask == 3)
	assert(fireball._find_bounce_target() != null)
	fireball.free()
	await _capture("emerged")
	print("SPAWN PRESENTATION PASSED: initial/batched clumps, member clearance, wall/annulus bounds, movement bias, underground rise, stagger, pause and activation")
	quit(0)

func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.testdata/spawn-" + label + ".png")
