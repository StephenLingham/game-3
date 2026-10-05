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
	assert(is_equal_approx(scene._health_regen(scene.RUN_DURATION), scene.GameConsts.HEALTH_REGEN_END))
	for i in 100:
		assert(scene._choose_enemy_type(119.0) == 0, "Opening enemies are always one-shot red cubes")
	# Spawn debt must survive frames slower than the requested spawn interval.
	scene.elapsed = 570.0
	scene._spawn_boss()
	scene.boss.set_physics_process(false)
	scene.enemy_spawn_clock = 0.0
	var count_before: int = scene._alive_enemy_count()
	scene._process(0.5)
	assert(scene._alive_enemy_count() >= count_before + 5, "Slow frames must not lower late difficulty")
	scene.boss.global_position = scene.player.global_position + Vector3(2.5, 0.0, 0.0)
	scene.player_health = scene.GameConsts.PLAYER_MAX_HEALTH
	scene.player.hurt_cooldown = 0.0
	scene.boss._physics_process(0.01)
	assert(scene.player_health == scene.GameConsts.PLAYER_MAX_HEALTH - scene.GameConsts.BOSS_CONTACT_DAMAGE, "Scaled boss must reach the player")
	var after_hit: float = scene.player_health
	scene.player.take_damage(scene.GameConsts.ENEMY_CONTACT_DAMAGE)
	assert(scene.player_health == after_hit, "Crowd hits share a short recovery window")
	scene.player.hurt_cooldown = 0.0
	scene.player.take_damage(scene.GameConsts.ENEMY_CONTACT_DAMAGE)
	assert(scene.player_health < after_hit, "Recovery must not give permanent immunity")
	assert(scene.GameConsts.DASH_DURATION / scene.GameConsts.DASH_COOLDOWN < 0.2, "Dash cannot give continuous immunity")
	print("BALANCE RULES PASSED: opening, full ramp, regeneration, spawn debt, boss contact, hit grace and dash uptime")
	quit(0)
