extends Control

var start_button: Button
var exit_button: Button

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("102033")
	add_child(background)

	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.position = Vector2(-360, -250)
	glow.size = Vector2(720, 500)
	glow.color = Color(0.08, 0.26, 0.39, 0.72)
	background.add_child(glow)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -220)
	panel.custom_minimum_size = Vector2(520, 440)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.06, 0.10, 0.94)
	panel_style.border_color = Color("63ddff")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 45)
	margin.add_theme_constant_override("margin_right", 45)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)

	start_button = Button.new()
	start_button.text = "Start Run"
	start_button.custom_minimum_size = Vector2(380, 72)
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(_start_run)
	content.add_child(start_button)

	exit_button = Button.new()
	exit_button.text = "Exit Game"
	exit_button.custom_minimum_size = Vector2(380, 56)
	exit_button.add_theme_font_size_override("font_size", 22)
	exit_button.pressed.connect(_exit_game)
	content.add_child(exit_button)

	var hint := Label.new()
	hint.text = "WASD: Move  •  Space: Jump  •  LMB: Fire\nShift: Long Jump  •  Ctrl: Mega Jump  •  E: Dash"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.64)
	content.add_child(hint)

func _start_run() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _exit_game() -> void:
	get_tree().quit()
