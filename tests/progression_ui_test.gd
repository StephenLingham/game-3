extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.testdata/progression-" + label + ".png")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	_check_run_xp_budget(scene)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var before := get_nodes_in_group("pickups").size()
	scene._spawn_xp(Vector3(0, 0, -5))
	assert(get_nodes_in_group("pickups").size() == before + 1, "An enemy drops exactly one XP ball")
	var orb = get_nodes_in_group("pickups").back()
	orb.set_physics_process(false)
	assert(orb.value == 12.0 and orb.has_node("XPGlow"), "Each ball gives 12 XP and has a glow halo")
	orb._on_body_entered(scene.player)
	assert(scene.xp == 12.0, "Collecting a ball grants its XP once")
	await process_frame
	assert(get_nodes_in_group("pickups").size() == before)
	var offers := [
		{"kind": "damage", "amount": 20.0},
		{"kind": "projectiles", "amount": 2.0},
		{"kind": "bounces", "amount": 1.0},
		{"kind": "radius", "amount": 0.45},
		{"kind": "crit", "amount": 3.0},
		{"kind": "attack_speed", "amount": 17.0}
	]
	var expected := ["100 -> 120", "1 -> 3", "0 -> 1", "1.50m -> 1.95m", "5% -> 8%", "×1.00 -> ×1.17"]
	for i in offers.size():
		assert(scene._upgrade_preview(offers[i]) == expected[i], "Upgrade previews show current and next values with units")
	scene.stats.crit = 0.73
	assert(scene._upgrade_preview({"kind": "crit", "amount": 12.0}) == "73% -> 75%", "Crit preview respects the actual cap")
	scene.stats.crit = 0.05
	# Open the real pause menu through Escape and check the timer and build.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	scene._input(escape)
	assert(paused and scene.pause_active and scene.pause_overlay.visible)
	var elapsed: float = scene.elapsed
	scene._process(1.0)
	assert(scene.elapsed == elapsed, "Pause stops the survival timer")
	assert(scene.pause_stat_values.Damage.text == "100" and scene.pause_stat_values.Projectiles.text == "1")
	await process_frame
	await process_frame
	var panel: Control = scene.pause_stats_label.get_parent().get_parent()
	var viewport_size := root.get_visible_rect().size
	assert(panel.get_global_rect().end.x < viewport_size.x * 0.5, "Build is displayed to the left of pause actions")
	assert(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= viewport_size.y, "Build panel fits the screen")
	await _capture("pause")
	scene._show_pause_tutorial()
	assert(paused and scene.tutorial_overlay.visible)
	scene._hide_pause_tutorial()
	scene._set_pause(false)
	scene.xp = scene.xp_needed
	scene._check_level_up()
	for card in scene.cards_row.get_children():
		assert(" -> " in card.text, "All offered cards show their stat transition")
	await _capture("upgrades")
	scene.current_offers.clear()
	scene.current_offers.append({"kind": "damage", "amount": 20.0})
	scene._choose_upgrade(0)
	scene._set_pause(true)
	assert(scene.pause_stat_values.Damage.text == "120", "Pause build refreshes after an upgrade")
	scene._set_pause(false)
	# Place actual glowing pickups in view for compatibility-renderer QA.
	scene.player.position = Vector3(0, 0.05, 0)
	scene.player.rotation = Vector3.ZERO
	scene.player.head.rotation.x = -0.2
	for x in [-2.0, 0.0, 2.0]:
		scene._spawn_xp(Vector3(x, 0.0, -6.0))
	for pickup in get_nodes_in_group("pickups"):
		pickup.set_physics_process(false)
	await _capture("glow")
	print("PROGRESSION UI TEST PASSED: single 12-XP drop, glow, all stat previews, crit cap, Escape pause, frozen timer and refreshed build")
	quit(0)

func _check_run_xp_budget(scene: Node) -> void:
	# An independent reward budget, not a survival or collection guarantee:
	# all scheduled enemies defeated, all XP and scheduled relics collected.
	var budget_level := 1
	var budget_xp: float = scene.GameConsts.INITIAL_ENEMY_COUNT * scene.GameConsts.XP_PER_DROP
	budget_xp += scene.GameConsts.INITIAL_RELIC_COUNT * scene.GameConsts.XP_BASE_REQUIREMENT * scene.GameConsts.RELIC_LEVEL_XP_FRACTION
	var next_relic: float = scene.GameConsts.RELIC_FIRST_SPAWN_TIME
	for second in int(scene.RUN_DURATION):
		budget_xp += scene.GameConsts.XP_PER_DROP / scene._enemy_spawn_interval(float(second) + 0.5)
		if float(second) >= next_relic:
			budget_xp += scene._xp_required_for_level(budget_level) * scene.GameConsts.RELIC_LEVEL_XP_FRACTION
			next_relic += scene.GameConsts.RELIC_SPAWN_INTERVAL
		while budget_xp >= scene._xp_required_for_level(budget_level):
			budget_xp -= scene._xp_required_for_level(budget_level)
			budget_level += 1
	assert(budget_level == 40, "Ten-minute reward budget should reach roughly level 40")
	print("TEN-MINUTE XP BUDGET: level %d with all drops and scheduled relics" % budget_level)
