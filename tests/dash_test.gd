extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_process(false)
	var player = scene.player
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	player.global_position = Vector3(0, 0.05, 24)
	player.rotation.y = 0.0
	var targets: Array[Node] = []
	for x in [-0.5, 0.5]:
		var enemy = scene.EnemyScript.new()
		enemy.add_to_group("enemies")
		scene.add_child(enemy)
		enemy.setup(player)
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(x, 0.05, 10)
		targets.append(enemy)
	await physics_frame
	var start: Vector3 = player.global_position
	player._start_dash()
	for i in ceili(player.DASH_DURATION * 60.0) + 1:
		player._physics_process(1.0 / 60.0)
	var distance: float = Vector2(player.position.x - start.x, player.position.z - start.z).length()
	if absf(distance - player.GameConsts.DASH_DISTANCE) > 0.01:
		push_error("Wrong dash distance: %s" % distance)
		quit(1)
		return
	if targets[0].velocity.x >= 0 or targets[1].velocity.x <= 0 or absf(targets[0].velocity.z) > 0.01 or absf(targets[1].velocity.z) > 0.01:
		push_error("Crowd did not split perpendicular to dash")
		quit(1)
		return
	player.global_position = Vector3(0, 0.05, -40)
	player._start_dash()
	for i in ceili(player.DASH_DURATION * 60.0) + 1:
		player._physics_process(1.0 / 60.0)
	if player.position.z < -47.1:
		push_error("Dash crossed arena wall")
		quit(1)
		return
	print("DASH TEST PASSED: configured dash distance, swept crowd splitting, wall collision")
	quit(0)
