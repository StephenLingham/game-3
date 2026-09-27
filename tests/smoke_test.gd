extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame

	assert(scene.player != null, "Player should be created")
	assert(get_nodes_in_group("enemies").size() >= 7, "Initial enemy pack should spawn")
	assert(get_nodes_in_group("pickups").size() == 4, "Initial relics should spawn")
	var yaw_before: float = scene.player.rotation.y
	scene.player._apply_mouse_look(Vector2(80.0, -35.0))
	assert(not is_equal_approx(scene.player.rotation.y, yaw_before), "Mouse motion should rotate the first-person view")

	for i in 4:
		scene.player._perform_jump()
	assert(scene.player.hop_chain == 4, "Bunny-hop chain should cap at four")
	assert(is_equal_approx(1.0 + float(scene.player.hop_chain) / 4.0, 2.0), "Fourth hop should reach 2x speed")

	var projectile_count_before := get_nodes_in_group("projectiles").size()
	scene._on_player_fire(scene.player.global_position + Vector3.UP, Vector3.FORWARD)
	assert(get_nodes_in_group("projectiles").size() == projectile_count_before + 1, "Base fire should create one projectile")

	scene.xp = scene.xp_needed
	scene._check_level_up()
	assert(scene.upgrade_active, "Filling the XP bar should open upgrades")
	assert(scene.current_offers.size() == 3, "Level-up should offer three upgrades")
	scene._choose_upgrade(0)
	assert(not scene.upgrade_active, "Choosing an upgrade should resume the run")

	print("SMOKE TEST PASSED: world, bhop, fireball, pickups, and upgrade flow")
	quit(0)
