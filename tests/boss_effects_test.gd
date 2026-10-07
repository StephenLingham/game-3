extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_process(false)
	scene.player.set_physics_process(false)
	scene._spawn_xp(Vector3(20, 5, 20))
	for pickup in get_nodes_in_group("pickups"):
		if pickup.kind == "xp":
			pickup._physics_process(0.3)
			check(is_equal_approx(pickup.position.y, 0.24), "XP sphere touches the ground without bobbing")
			check(pickup.get_child(1).mesh is SphereMesh, "XP uses a sphere mesh")
	scene._spawn_powerup("star")
	var star = get_nodes_in_group("pickups").back()
	check(star.get_node("StarSparkles") is CPUParticles3D, "star emits particles")
	scene.player.activate_star_power(5.0)
	check(scene.player.star_overlay.visible, "star effect activates")
	scene.player.star_power_timer = 0.0
	scene.player._update_star_effect()
	check(not scene.player.star_overlay.visible, "star effect clears")
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.freeze(0.1)
	check(enemy.ice_shell.visible, "freeze effect activates")
	enemy._physics_process(0.2)
	check(not enemy.ice_shell.visible, "freeze effect clears")
	scene.elapsed = 539.0
	scene._process(0.5)
	check(get_nodes_in_group("bosses").is_empty(), "boss is absent before the final wave")
	scene._process(0.5)
	check(get_nodes_in_group("bosses").is_empty(), "final wave contains only the horde")
	check(not scene.game_over, "final wave must be survived completely")
	scene.elapsed = 599.9
	scene._process(0.1)
	check(scene.game_over and root.get_node("RunStats").last_run.won, "survival wins at ten minutes")
	await process_frame
	await process_frame
	check(current_scene.name == "Results", "victory leaves the arena")
	current_scene.queue_free()
	await process_frame
	var second = load("res://main.tscn").instantiate()
	root.add_child(second)
	current_scene = second
	second.set_process(false)
	second.elapsed = 540.0
	second._process(0.01)
	second.player_health = 1.0
	second._on_player_hurt(12.0)
	check(second.game_over and not root.get_node("RunStats").last_run.won, "death in the final wave still loses")
	await process_frame
	await process_frame
	check(current_scene.name == "Results", "death leaves the arena")
	if failures.is_empty():
		print("HORDE SURVIVAL AND EFFECTS TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
