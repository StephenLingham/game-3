extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.testdata/vortex-" + label + ".png")
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
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		scene.player.position = Vector3(10, 0.05, 20)
		scene.player.camera.look_at(vortex.position, Vector3.UP)
	for i in 120:
		enemy.pull_toward(vortex.position, 38, 1.0 / 60, vortex)
	var before: Vector3 = enemy.position
	var rotation_before: Vector3 = enemy.visual.rotation
	for i in 30:
		enemy.pull_toward(vortex.position, 38, 1.0 / 60, vortex)
	check(enemy.position.distance_to(before) > 0.2, "captured enemy orbits the vortex")
	check(enemy.visual.rotation != rotation_before, "captured enemy tumbles")
	var relative_center: Vector3 = enemy.position + Vector3.UP * 0.68 * enemy.scale.y - vortex.position
	check(absf(relative_center.y) <= 0.25, "enemy orbits beside the vortex rather than above it")
	check(Vector2(relative_center.x, relative_center.z).length() >= scene.GameConsts.VORTEX_ORBIT_RADIUS_MIN, "orbit clears the large starting sphere and halo")
	check(is_equal_approx(vortex.visual_root.scale.x, 1.0), "vortex starts at full size")
	await _capture("large-orbit")
	vortex.setup(Vector3.DOWN)
	for i in 60:
		vortex._physics_process(1.0 / 60.0)
		check(vortex.position.y + 0.00001 >= scene.GameConsts.VORTEX_OUTER_RADIUS * vortex.visual_scale + scene.GameConsts.VORTEX_GROUND_CLEARANCE, "downward vortex stays completely above ground")
	check(is_equal_approx(vortex.visual_root.scale.x, 0.25), "vortex shrinks to 25 percent of its starting size")
	if DisplayServer.get_name() != "headless":
		scene.player.camera.look_at(vortex.position, Vector3.UP)
	await _capture("small-ground")
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
