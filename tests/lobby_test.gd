extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lobby: Control = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await process_frame
	assert(is_instance_valid(lobby.start_button), "Lobby should display a start button")
	assert(ProjectSettings.get_setting("application/config/name") == "Arena Shooter", "Web and desktop title should be Arena Shooter")
	var mega_events := InputMap.action_get_events("mega_fireball")
	assert(mega_events.size() == 1 and mega_events[0] is InputEventMouseButton and mega_events[0].button_index == MOUSE_BUTTON_RIGHT, "Mega fireball should be mapped to right mouse")
	assert(lobby.start_button.text == "Start Run", "Lobby button should clearly start a run in title case")
	assert(is_instance_valid(lobby.stats_button) and lobby.stats_button.text == "Stats", "Lobby should display a Stats button")
	assert(is_instance_valid(lobby.tutorial_button) and lobby.tutorial_button.text == "Tutorial", "Lobby should display a Tutorial button")
	assert(is_instance_valid(lobby.exit_button) and lobby.exit_button.text == "Exit Game", "Lobby should display a title-case exit button")
	assert(not lobby.exit_button.pressed.get_connections().is_empty(), "Exit button should be connected")
	assert(lobby.start_button.custom_minimum_size == lobby.exit_button.custom_minimum_size, "Lobby buttons should use consistent dimensions")
	assert(lobby.start_button.get_theme_font_size("font_size") == lobby.exit_button.get_theme_font_size("font_size"), "Lobby buttons should use a consistent font size")
	lobby._show_tutorial()
	assert(lobby.page_panel.visible and "Right Mouse" in lobby.page_body.text and "Esc" in lobby.page_body.text, "Tutorial should clearly list every control")
	lobby._show_stats()
	assert("Highest Level" in lobby.page_body.text and "Most Enemies" in lobby.page_body.text, "Stats screen should list the persistent run records")
	lobby._show_main()

	lobby._start_run()
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.name == "CubeHopper", "Start button should open the game")
	assert(current_scene.player != null, "Started run should spawn the player")

	var run_scene: Node = current_scene
	run_scene._set_pause(true)
	assert(paused, "Pause menu should pause the run")
	run_scene._return_to_lobby()
	await process_frame
	await process_frame
	assert(not paused, "Returning to lobby should clear the paused state")
	assert(current_scene != null and current_scene.name == "Lobby", "Pause menu should return to the lobby")

	print("LOBBY TEST PASSED: start flow and pause-menu return flow")
	quit(0)
