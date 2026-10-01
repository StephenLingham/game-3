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
	check(not scene.boss_spawned, "boss does not spawn early")
	scene._process(0.5)
	check(scene.boss_spawned and scene.boss.health == scene.GameConsts.BOSS_HEALTH, "boss spawns at nine minutes")
	var health: float = scene.boss.health
	scene.boss.defeat()
	check(scene.boss.health < health and not scene.boss.defeated, "boss resists contact instant kills")
	scene.elapsed = 599.9
	scene._process(0.1)
	check(scene.game_over and "Failed" in scene.upgrade_title.text, "living boss causes failure at ten minutes")
	paused = false
	scene.queue_free()
	await process_frame
	var second = load("res://main.tscn").instantiate()
	root.add_child(second)
	second.set_process(false)
	second.elapsed = 540.0
	second._process(0.01)
	second.boss.take_damage(second.boss.health)
	check(second.boss_defeated and not second.game_over, "killing boss does not end run early")
	second.elapsed = 599.9
	second._process(0.1)
	check(second.game_over and "Victory" in second.upgrade_title.text, "survival plus boss kill wins")
	if failures.is_empty():
		print("BOSS AND EFFECTS TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
