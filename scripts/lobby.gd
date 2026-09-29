extends Control

const BUTTON_SIZE := Vector2(380, 64)
const BUTTON_FONT_SIZE := 24

var start_button: Button
var stats_button: Button
var tutorial_button: Button
var exit_button: Button
var main_panel: PanelContainer
var page_panel: PanelContainer
var page_title: Label
var page_body: Label

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

	main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.position = Vector2(-260, -210)
	main_panel.custom_minimum_size = Vector2(520, 420)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.06, 0.10, 0.94)
	panel_style.border_color = Color("63ddff")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(main_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 45)
	margin.add_theme_constant_override("margin_right", 45)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	main_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)

	start_button = Button.new()
	start_button.text = "Start Run"
	start_button.custom_minimum_size = BUTTON_SIZE
	start_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	start_button.pressed.connect(_start_run)
	content.add_child(start_button)

	stats_button = Button.new()
	stats_button.text = "Stats"
	stats_button.custom_minimum_size = BUTTON_SIZE
	stats_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	stats_button.pressed.connect(_show_stats)
	content.add_child(stats_button)

	tutorial_button = Button.new()
	tutorial_button.text = "Tutorial"
	tutorial_button.custom_minimum_size = BUTTON_SIZE
	tutorial_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	tutorial_button.pressed.connect(_show_tutorial)
	content.add_child(tutorial_button)

	exit_button = Button.new()
	exit_button.text = "Exit Game"
	exit_button.custom_minimum_size = BUTTON_SIZE
	exit_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	exit_button.pressed.connect(_exit_game)
	content.add_child(exit_button)


	_build_page_panel()

func _build_page_panel() -> void:
	page_panel = PanelContainer.new()
	page_panel.set_anchors_preset(Control.PRESET_CENTER)
	page_panel.position = Vector2(-350, -285)
	page_panel.custom_minimum_size = Vector2(700, 570)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.10, 0.97)
	style.border_color = Color("63ddff")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	page_panel.add_theme_stylebox_override("panel", style)
	page_panel.visible = false
	add_child(page_panel)
	var page_margin := MarginContainer.new()
	page_margin.add_theme_constant_override("margin_left", 45)
	page_margin.add_theme_constant_override("margin_right", 45)
	page_margin.add_theme_constant_override("margin_top", 30)
	page_margin.add_theme_constant_override("margin_bottom", 30)
	page_panel.add_child(page_margin)
	var page_content := VBoxContainer.new()
	page_content.alignment = BoxContainer.ALIGNMENT_CENTER
	page_content.add_theme_constant_override("separation", 16)
	page_margin.add_child(page_content)
	page_title = Label.new()
	page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_title.add_theme_font_size_override("font_size", 40)
	page_content.add_child(page_title)
	page_body = Label.new()
	page_body.custom_minimum_size = Vector2(590, 370)
	page_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_body.add_theme_font_size_override("font_size", 21)
	page_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_content.add_child(page_body)
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = BUTTON_SIZE
	back_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	back_button.pressed.connect(_show_main)
	page_content.add_child(back_button)

func _show_stats() -> void:
	page_title.text = "Stats"
	page_body.text = "Highest Level Reached:  %d\n\nMost Enemies Defeated In A Run:  %d\n\nLongest Survival Time:  %s\n\nMost Damage In One Hit:  %d\n\nMost Enemies Defeated With One Attack:  %d" % [int(RunStats.records.highest_level), int(RunStats.records.most_kills), RunStats.formatted_time(), int(round(float(RunStats.records.most_damage))), int(RunStats.records.most_attack_kills)]
	_show_page()

func _show_tutorial() -> void:
	page_title.text = "Tutorial"
	page_body.text = "W A S D  —  Move\nMouse  —  Look\nLeft Mouse  —  Fire\nRight Mouse  —  Mega Fireball\n\nSpace  —  Jump / Bunny Hop\nShift + Space  —  Long Jump\nCtrl + Space  —  Mega Triple Jump\nE  —  Dash\n\n1  —  Force Push\n2  —  Frost Nova\n3  —  Explosion\n4  —  Vortex\nEsc  —  Pause"
	_show_page()

func _show_page() -> void:
	main_panel.visible = false
	page_panel.visible = true

func _show_main() -> void:
	page_panel.visible = false
	main_panel.visible = true

func _start_run() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _exit_game() -> void:
	get_tree().quit()
