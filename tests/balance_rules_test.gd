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
	assert(scene._enemy_max_spawn_rate(120.0) < 0.7, "Opening two minutes remain gentle")
	assert(scene._health_regen(120.0) == scene.GameConsts.HEALTH_REGEN_START)
	assert(scene._enemy_population_target(540.0) == scene.GameConsts.ENEMY_POPULATION_CAP, "Final swarm targets the population cap")
	assert(is_equal_approx(scene._enemy_max_spawn_rate(599.0), 40.0), "Final swarm can replace up to 40 enemies per second")
	assert(scene._enemy_health_for_type(9) == 10000.0, "Final enemy tier has 10000 HP")
	for time in [0.0, 120.0, 300.0, 540.0, 599.0]:
		scene.elapsed = time
		scene._spawn_enemy()
		var spawned = get_nodes_in_group("enemies").back()
		spawned.set_physics_process(false)
		assert(is_equal_approx(spawned.move_speed, 3.2), "Enemy speed stays constant through the run")
		assert(spawned.health == scene._enemy_health_for_type(spawned.enemy_type), "Spawned enemies receive their configured tier health")
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
			assert(absf(spawn.x) <= edge and absf(spawn.z) <= edge, "Spawns must remain inside the walls")
			var distance := Vector2(spawn.x, spawn.z).distance_to(Vector2(player_pos.x, player_pos.z))
			assert(distance >= scene.GameConsts.ENEMY_SPAWN_DISTANCE_MIN - 0.001, "No surprise contact spawns")
			assert(distance <= scene.GameConsts.ENEMY_SPAWN_DISTANCE_MAX + 0.001, "Spawns follow the player instead of staying on distant walls")
			if player_pos == Vector3.ZERO:
				var quadrant := (0 if spawn.x < 0.0 else 1) + (0 if spawn.z < 0.0 else 2)
				sides[quadrant] += 1
	for count in sides: assert(count > 0, "Enemies approach from every direction")
	scene.player.global_position = Vector3.ZERO
	assert(scene._enemy_max_spawn_rate(360.0) >= 7.0, "Wave six brings a substantial horde")
	# Credit must survive frames slower than the director tick.
	scene.elapsed = 570.0
	scene.enemy_spawn_clock = 0.0
	scene.enemy_spawn_credits = 0.0
	var count_before: int = scene._alive_enemy_count()
	scene._process(0.505)
	assert(scene._alive_enemy_count() == count_before + 20, "Two director ticks replenish a thin final crowd during a slow frame")
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
	print("BALANCE RULES PASSED: opening, final swarm, nearby spawns, regeneration, slow-frame credit, survival victory, hit grace and dash uptime")
	quit(0)
