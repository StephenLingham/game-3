extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		check(enemy.enemy_type == 0, "opening pack uses red cube enemies")
		check(enemy.max_health == scene.GameConsts.ENEMY_HEALTH[0] and is_equal_approx(enemy.move_speed, scene.GameConsts.ENEMY_SPEED_START), "opening cubes retain their balanced stats")
		check(is_instance_valid(enemy.body_material), "opening enemy retains its cube material")
		check(enemy.visual.get_child(0).mesh is BoxMesh, "opening enemy uses the original cube body")
		check(enemy.visual.get_child_count() == 3, "cube retains its two eyes")
		check(enemy.visual.find_child("StoneGolem", true, false) == null, "golem model is not instantiated")
	for i in 100:
		check(scene._choose_enemy_type(0.0) == 0 and scene._choose_enemy_type(59.9) == 0, "opening minute only selects red cubes")
	check(scene._primary_enemy_type(60.0) == 1, "second wave still unlocks after one minute")
	var next_enemy = scene.EnemyScript.new()
	scene.add_child(next_enemy)
	next_enemy.setup(scene.player, 1, 200.0, scene.ENEMY_COLORS[1])
	check(next_enemy.visual.get_child(0).mesh is BoxMesh and is_instance_valid(next_enemy.body_material), "later types retain their cube visuals")
	if failures.is_empty():
		print("CUBE RESTORATION TEST PASSED: opening wave, balanced stats, cube body, eyes, and later enemy visuals")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
