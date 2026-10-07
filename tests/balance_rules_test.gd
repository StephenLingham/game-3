extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	# Check the mathematical curve across its entire domain, not just endpoints.
	var previous_rate := 0.0
	for second in range(0, 601):
		var rate: float = 1.0 / scene._enemy_spawn_interval(float(second))
		assert(rate >= previous_rate, "Spawn pressure must increase monotonically")
		previous_rate = rate
	assert(1.0 / scene._enemy_spawn_interval(120.0) < 0.7, "Opening two minutes remain gentle")
	assert(scene._health_regen(120.0) == scene.GameConsts.HEALTH_REGEN_START)
	assert(is_equal_approx(1.0 / scene._enemy_spawn_interval(540.0), 100.0), "Final wave starts at 100 spawns per second")
	assert(is_equal_approx(1.0 / scene._enemy_spawn_interval(599.0), 100.0), "Final wave sustains 100 spawns per second")
	assert(scene._enemy_health_for_type(9) == 1900.0, "Final enemy health is doubled")
	for time in [0.0, 120.0, 300.0, 540.0, 599.0]:
		scene.elapsed = time
		scene._spawn_enemy()
		var spawned = get_nodes_in_group("enemies").back()
		spawned.set_physics_process(false)
		assert(is_equal_approx(spawned.move_speed, 3.2), "Enemy speed stays constant through the run")
	scene.elapsed = 0.0
	assert(is_equal_approx(scene._health_regen(scene.RUN_DURATION), scene.GameConsts.HEALTH_REGEN_END))
	for i in 100:
		assert(scene._choose_enemy_type(119.0) == 0, "Opening enemies are always one-shot red cubes")
	# Test the actual spawn geometry at the centre, sides and corners.
	var sides := [0, 0, 0, 0]
	var edge: float = scene.GameConsts.ENEMY_SPAWN_EDGE
	for player_pos in [Vector3.ZERO, Vector3(46, 0, 0), Vector3(-46, 0, 0), Vector3(0, 0, 46), Vector3(0, 0, -46), Vector3(46, 0, 46), Vector3(-46, 0, -46)]:
		scene.player.global_position = player_pos
		for sample in 200:
			var spawn: Vector3 = scene._enemy_spawn_position()
			assert(is_equal_approx(absf(spawn.x), edge) or is_equal_approx(absf(spawn.z), edge), "Enemies must spawn on an arena edge")
			assert(absf(spawn.x) <= edge and absf(spawn.z) <= edge, "Spawns must remain inside the walls")
			assert(Vector2(spawn.x, spawn.z).distance_to(Vector2(player_pos.x, player_pos.z)) >= scene.GameConsts.ENEMY_SPAWN_DISTANCE_MIN, "No surprise contact spawns")
			if spawn.x == -edge: sides[0] += 1
			elif spawn.x == edge: sides[1] += 1
			elif spawn.z == -edge: sides[2] += 1
			else: sides[3] += 1
	for count in sides: assert(count > 0, "All four sides must spawn enemies")
	scene.player.global_position = Vector3.ZERO
	assert(1.0 / scene._enemy_spawn_interval(360.0) >= 7.0, "Wave six brings a substantial horde")
	# Spawn debt must survive frames slower than the requested spawn interval.
	scene.elapsed = 570.0
	scene.enemy_spawn_clock = 0.0
	var count_before: int = scene._alive_enemy_count()
	# Avoid an exact floating-point interval boundary (100/s gives 0.01s).
	scene._process(0.505)
	var expected_spawns := int(floor(0.505 / scene._enemy_spawn_interval(scene.elapsed))) + 1
	assert(scene._alive_enemy_count() == count_before + expected_spawns, "Slow frames must repay all late-wave spawn debt")
	scene.player_health = scene.GameConsts.PLAYER_MAX_HEALTH
	scene.player.hurt_cooldown = 0.0
	scene.player.take_damage(scene.GameConsts.ENEMY_CONTACT_DAMAGE)
	var after_hit: float = scene.player_health
	scene.player.take_damage(scene.GameConsts.ENEMY_CONTACT_DAMAGE)
	assert(scene.player_health == after_hit, "Crowd hits share a short recovery window")
	scene.player.hurt_cooldown = 0.0
	scene.player.take_damage(scene.GameConsts.ENEMY_CONTACT_DAMAGE)
	assert(scene.player_health < after_hit, "Recovery must not give permanent immunity")
	assert(scene.GameConsts.DASH_DURATION / scene.GameConsts.DASH_COOLDOWN < 0.2, "Dash cannot give continuous immunity")
	assert(get_nodes_in_group("bosses").is_empty(), "Late waves must not spawn a boss")
	scene.elapsed = scene.RUN_DURATION - 0.01
	scene._process(0.02)
	assert(scene.game_over and root.get_node("RunStats").last_run.won, "Surviving the full timer wins with enemies still alive")
	await process_frame
	await process_frame
	assert(current_scene.name == "Results" and not paused, "Victory opens a separate results scene")
	print("BALANCE RULES PASSED: opening, horde ramp, perimeter spawns, regeneration, spawn debt, survival victory, hit grace and dash uptime")
	quit(0)
