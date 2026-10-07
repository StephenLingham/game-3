extends Control

const ACCENT := Color("63ddff")
var title_label: Label
var stat_values: Dictionary = {}
var play_again_button: Button
var lobby_button: Button

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var result: Dictionary = RunStats.last_run
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("102033")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 850
	panel.add_theme_stylebox_override("panel", _panel_style(Color("091320"), ACCENT, 28))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	title_label = _label("Victory — Horde Survived!" if result.get("won", false) else "Run Over", 36, ACCENT if result.get("won", false) else Color("ff787e"))
	content.add_child(title_label)
	content.add_child(_label("RUN RESULTS", 16, Color("93a9be")))
	var duration := float(result.get("duration", 0.0))
	var whole_seconds := int(floor(duration))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	_add_stat(grid, "total_damage", "Total Damage Dealt", _number(float(result.get("total_damage", 0.0))), true)
	_add_stat(grid, "kills", "Enemies Defeated", _number(float(result.get("kills", 0))))
	_add_stat(grid, "duration", "Survival Time", "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60])
	_add_stat(grid, "wave", "Wave Reached", "%d / 10" % int(result.get("wave", 1)))
	_add_stat(grid, "level", "Level Reached", str(result.get("level", 1)))
	_add_stat(grid, "damage_taken", "Damage Taken", _number(float(result.get("damage_taken", 0.0))))
	_add_stat(grid, "biggest_hit", "Biggest Hit", _number(float(result.get("biggest_hit", 0.0))))
	_add_stat(grid, "best_attack_kills", "Best Attack · Kills", _number(float(result.get("best_attack_kills", 0))))
	_add_stat(grid, "attacks", "Attacks Used", _number(float(result.get("attacks", 0))))
	content.add_child(_label("Damage dealt counts enemy health removed, including abilities and Star Power.", 15, Color("93a9be")))
	var build: Dictionary = result.get("build", {})
	if not build.is_empty():
		content.add_child(_label("FINAL BUILD", 16, ACCENT))
		content.add_child(_label("%d projectiles  ·  %d bounces  ·  %.0f damage  ·  %.1fm blast\n%d%% crit chance  ·  ×%.2f attack speed" % [build.projectiles, build.bounces, build.damage, build.radius, int(build.crit * 100), build.attack_speed], 18))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	play_again_button = _button("Play Again  [R]", _play_again)
	buttons.add_child(play_again_button)
	lobby_button = _button("Back To Lobby  [Esc]", _return_to_lobby)
	buttons.add_child(lobby_button)
	play_again_button.grab_focus()

func _add_stat(grid: GridContainer, key: String, caption: String, value: String, highlighted := false) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(250, 84)
	card.add_theme_stylebox_override("panel", _panel_style(Color("103249") if highlighted else Color("152538"), ACCENT if highlighted else Color("293d50"), 12))
	grid.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(_label(caption, 16, Color("b2c6d8")))
	var value_label := _label(value, 28, ACCENT if highlighted else Color.WHITE)
	box.add_child(value_label)
	stat_values[key] = value_label

func _label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(action)
	return button

func _panel_style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _number(amount: float) -> String:
	var digits := str(int(round(amount)))
	var formatted := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += ","
		formatted += digits[i]
	return formatted

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_play_again()
		elif event.is_action_pressed("ui_cancel"):
			_return_to_lobby()

func _play_again() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://lobby.tscn")
