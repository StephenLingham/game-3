extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lobby: Control = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await process_frame
	assert(is_instance_valid(lobby.start_button), "Lobby should display a start button")
	assert(lobby.start_button.text == "START RUN", "Lobby button should clearly start a run")

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
