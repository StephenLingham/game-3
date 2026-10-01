extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_process(false)
	scene.player.set_physics_process(false)
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(10, 0.05, 10)
	var vortex = scene.VortexScript.new()
	scene.add_child(vortex)
	vortex.set_physics_process(false)
	vortex.position = Vector3(10, 4, 10)
	for i in 120:
		enemy.pull_toward(vortex.position, 38, 1.0 / 60, vortex)
	var before: Vector3 = enemy.position
	var rotation_before: Vector3 = enemy.visual.rotation
	for i in 30:
		enemy.pull_toward(vortex.position, 38, 1.0 / 60, vortex)
	check(enemy.position.distance_to(before) > 0.2, "captured enemy orbits the vortex")
	check(enemy.visual.rotation != rotation_before, "captured enemy tumbles")
	check(enemy.position.y > 4, "vortex holds enemy above ground")
	vortex.queue_free()
	await process_frame
	check(enemy.vortex_hold_timer == 0 and enemy.visual.rotation.is_zero_approx(), "vortex expiry releases enemy")
	enemy.set_physics_process(true)
	for i in 150:
		await physics_frame
	check(enemy.position.y < 0.1, "released enemy falls back to ground")
	scene._use_skill(3)
	var effects: int = get_nodes_in_group("explosion_death_effects").size()
	check(effects > 0, "Explosion kills create detached particle bursts")
	await process_frame
	check(get_nodes_in_group("explosion_death_effects").size() == effects, "bursts survive enemy deletion")
	for i in 90:
		await process_frame
	if failures.is_empty():
		print("EXPLOSION AND VORTEX TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
