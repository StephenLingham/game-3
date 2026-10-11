extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var settings = scene.GameConsts
	# Swarms have precise windows, with a sustained finale inside the survival run.
	for start in settings.ENEMY_SWARM_TIMES:
		assert(not scene._is_enemy_swarm(start - 0.01))
		assert(scene._is_enemy_swarm(start))
		assert(scene._is_enemy_swarm(start + settings.ENEMY_SWARM_DURATION - 0.01))
		assert(not scene._is_enemy_swarm(start + settings.ENEMY_SWARM_DURATION))
	assert(not scene._is_enemy_swarm(settings.ENEMY_FINAL_SWARM_TIME - 0.01))
	assert(scene._is_enemy_swarm(599.0))
	# Use real enemies: a full opening crowd stops spawning and loses banked credit.
	scene.elapsed = 0.0
	var target: int = scene._enemy_population_target(0.0)
	while scene._alive_enemy_count() < target:
		scene._spawn_enemy()
	scene.enemy_spawn_credits = settings.ENEMY_SPAWN_CREDIT_CAP
	scene._update_enemy_spawning(2.0)
	assert(scene._alive_enemy_count() == target, "A saturated crowd must stop spawning")
	assert(scene.enemy_spawn_credits == 0.0, "Crowd caps discard credit instead of banking a delayed avalanche")
	# Dead nodes still awaiting deletion must free slots immediately.
	for enemy in get_nodes_in_group("enemies"):
		enemy.defeated = true
	assert(scene._alive_enemy_count() == 0)
	scene.enemy_spawn_credits = float(settings.ENEMY_CLUMP_MIN_SIZE)
	scene._update_enemy_spawning(settings.ENEMY_SPAWN_TICK)
	assert(scene._alive_enemy_count() == settings.ENEMY_CLUMP_MIN_SIZE, "Killed enemies release population slots before queue_free finishes")
	# Killing quickly permits more actual replenishment than leaving a dense crowd.
	var thin_spawns := _measure_spawns(scene, 0)
	var dense_spawns := _measure_spawns(scene, 129)
	assert(thin_spawns > dense_spawns and dense_spawns > 0, "Clear speed controls replenishment through the population deficit")
	# Swarm bursts can add enemies above the normal target; ending one does not cull them.
	_clear_enemies()
	scene.elapsed = 300.0
	while scene._alive_enemy_count() < 100:
		scene._spawn_enemy()
	scene.enemy_spawn_clock = 0.0
	scene.enemy_spawn_credits = 5.0
	scene._update_enemy_spawning(settings.ENEMY_SPAWN_TICK)
	assert(scene._alive_enemy_count() > 100, "A swarm admits reinforcements beyond the normal population")
	scene.elapsed = 330.0
	scene.enemy_spawn_credits = settings.ENEMY_SPAWN_CREDIT_CAP
	var survivors: int = scene._alive_enemy_count()
	# At 5:30 the normal target is 110, so create a crowd above that target.
	while scene._alive_enemy_count() < 130:
		scene._spawn_enemy()
	survivors = scene._alive_enemy_count()
	scene._update_enemy_spawning(settings.ENEMY_SPAWN_TICK)
	assert(scene._alive_enemy_count() == survivors, "Swarm survivors persist while replenishment rests")
	assert(scene.enemy_spawn_credits == 0.0)
	# Even a huge stall is bounded; final replenishment respects the hard cap.
	_clear_enemies()
	scene.elapsed = 570.0
	scene.enemy_spawn_clock = 0.0
	scene.enemy_spawn_credits = settings.ENEMY_SPAWN_CREDIT_CAP
	scene._update_enemy_spawning(60.0)
	assert(scene._alive_enemy_count() == settings.ENEMY_SPAWN_MAX_PER_FRAME, "A stalled frame cannot instantiate an unlimited crowd")
	assert(scene.enemy_spawn_credits <= settings.ENEMY_SPAWN_CREDIT_CAP)
	while scene._alive_enemy_count() < settings.ENEMY_POPULATION_CAP - 2:
		scene._spawn_enemy()
	scene.enemy_spawn_credits = settings.ENEMY_SPAWN_CREDIT_CAP
	scene._update_enemy_spawning(2.0)
	assert(scene._alive_enemy_count() == settings.ENEMY_POPULATION_CAP, "Final replenishment cannot exceed the living enemy cap")
	# Pause and upgrade time do not advance the director or accumulate credits.
	var clock_before: float = scene.enemy_spawn_clock
	var credits_before: float = scene.enemy_spawn_credits
	var time_before: float = scene.elapsed
	scene._set_pause(true)
	scene._process(10.0)
	assert(scene.elapsed == time_before and scene.enemy_spawn_clock == clock_before and scene.enemy_spawn_credits == credits_before)
	scene._set_pause(false)
	scene._update_hud()
	assert(scene.wave_label.text.contains("FINAL SWARM"))
	print("SPAWN DIRECTOR PASSED: swarm windows, population targets, kill-driven refill, deferred deaths, crowd rest, frame budget, hard cap and pause")
	quit(0)

func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()

func _measure_spawns(scene: Node, population: int) -> int:
	_clear_enemies()
	scene.elapsed = 360.0
	scene.enemy_spawn_clock = 0.0
	scene.enemy_spawn_credits = 0.0
	for i in population:
		scene._spawn_enemy()
	for tick in 16:
		scene.elapsed += scene.GameConsts.ENEMY_SPAWN_TICK
		scene._update_enemy_spawning(scene.GameConsts.ENEMY_SPAWN_TICK)
	return scene._alive_enemy_count() - population
