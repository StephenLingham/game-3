extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	await process_frame
	await process_frame

func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.testdata/results-" + label + ".png")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	# Test actual combat paths: partial hits, overkill, abilities and direct kills.
	var enemies := get_nodes_in_group("enemies")
	var projectile = scene.FireballScript.new()
	scene.add_child(projectile)
	projectile.setup(Vector3.FORWARD, 40.0, 1.5, 0, 0.0, scene.player, scene._begin_attack())
	projectile._damage_enemy(enemies[0])
	assert(is_equal_approx(scene.run_total_damage, 40.0), "Nonlethal fireball damage is counted")
	enemies[0].take_damage(200.0, true, 1)
	assert(is_equal_approx(scene.run_total_damage, 100.0), "Overkill counts only health removed, once")
	enemies[0].take_damage(200.0)
	assert(is_equal_approx(scene.run_total_damage, 100.0), "Dead enemies cannot add damage")
	enemies[1].defeat() # Star Power uses direct defeat.
	enemies[2].defeat(scene._begin_attack(), enemies[2].health) # Mega fireball.
	scene._use_skill(3) # Explosion kills the remaining four.
	assert(is_equal_approx(scene.run_total_damage, 700.0), "All seven enemies count exactly their health, across damage sources")
	assert(scene.kills == 7 and scene.run_max_attack_kills == 4 and scene.run_max_damage == 200.0)
	scene.player_health = 10.0
	scene._on_player_hurt(200.0)
	var records = root.get_node("RunStats")
	assert(records.last_run.damage_taken == 10.0 and not records.last_run.won, "Death records actual health lost")
	assert(records.last_run.total_damage == 700.0 and records.last_run.biggest_hit == 200.0)
	await _settle()
	assert(current_scene.name == "Results" and not paused)
	assert(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("projectiles").is_empty(), "Arena is freed when results open")
	assert(current_scene.title_label.text == "Run Over")
	assert(current_scene.stat_values.total_damage.text == "700" and current_scene.stat_values.damage_taken.text == "10")
	await _capture("death")
	current_scene.play_again_button.pressed.emit()
	await _settle()
	assert(current_scene.name == "CubeHopper" and records.last_run.is_empty(), "Replay starts a fresh run")
	scene = current_scene
	scene.set_process(false)
	scene.player.set_physics_process(false)
	scene.elapsed = 599.99
	scene.run_total_damage = 1234567.0
	scene._process(0.02)
	assert(records.last_run.won and records.last_run.duration == 600.0 and records.last_run.wave == 10)
	await _settle()
	assert(current_scene.name == "Results" and "Victory" in current_scene.title_label.text)
	assert(current_scene.stat_values.total_damage.text == "1,234,567" and current_scene.stat_values.duration.text == "10:00")
	await _capture("victory")
	current_scene.lobby_button.pressed.emit()
	await _settle()
	assert(current_scene.name == "Lobby" and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("RESULTS TEST PASSED: damage accounting, death/victory scenes, arena cleanup, replay, lobby and formatting")
	quit(0)
