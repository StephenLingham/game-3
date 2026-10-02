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
		check(enemy.enemy_type == 0, "opening pack uses only golems")
		check(enemy.max_health == 100.0 and enemy.move_speed == 3.2, "golem retains opening stats")
		check(is_instance_valid(enemy.walk_player), "golem has an imported animation player")
	for i in 100:
		check(scene._choose_enemy_type(0.0) == 0 and scene._choose_enemy_type(59.9) == 0, "opening minute only selects golems")
	check(scene._primary_enemy_type(60.0) == 1, "second wave still unlocks after one minute")
	var golem = get_nodes_in_group("enemies")[0]
	check(not golem.walk_animation.is_empty(), "imported walk clip is selected")
	check(golem.walk_player.get_animation(golem.walk_animation).loop_mode == Animation.LOOP_LINEAR, "walk loops")
	var skeleton = golem.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	check(is_instance_valid(skeleton) and skeleton.get_bone_count() == 16, "mesh has the stone golem skeleton")
	var thigh := skeleton.find_bone("Thigh.L")
	golem.velocity = Vector3(0, 0, -3.2)
	golem._advance_walk(0.0)
	var before: Quaternion = skeleton.get_bone_pose_rotation(thigh)
	golem._advance_walk(0.4)
	check(not before.is_equal_approx(skeleton.get_bone_pose_rotation(thigh)), "walking moves leg bones")
	var animation_position: float = golem.walk_player.current_animation_position
	golem.freeze(2.0)
	golem._advance_walk(0.3)
	check(is_equal_approx(golem.walk_player.current_animation_position, animation_position), "freeze stops walk playback")
	golem.freeze_timer = 0.0
	golem.vortex_hold_timer = 1.0
	golem._advance_walk(0.3)
	check(is_equal_approx(golem.walk_player.current_animation_position, animation_position), "vortex hold stops walk playback")
	golem.vortex_hold_timer = 0.0
	golem.velocity = Vector3.ZERO
	golem._advance_walk(0.1)
	check(is_zero_approx(golem.walk_player.current_animation_position), "stopping returns to a standing pose")
	var next_enemy = scene.EnemyScript.new()
	scene.add_child(next_enemy)
	next_enemy.setup(scene.player, 1, 200.0, scene.ENEMY_COLORS[1])
	check(not is_instance_valid(next_enemy.walk_player) and is_instance_valid(next_enemy.body_material), "later types retain their cube visuals")
	if failures.is_empty():
		print("GOLEM TEST PASSED: opening wave, stats, imported skin, walk, freeze, and vortex")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
