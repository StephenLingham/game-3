extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const FireballScript = preload("res://scripts/fireball.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const VortexScript = preload("res://scripts/vortex.gd")
const MegaFireballScript = preload("res://scripts/mega_fireball.gd")

const ARENA_HALF := 48.0
const RUN_DURATION := 600.0
const HEALTH_REGEN_PER_SECOND := 2.0
const RARITIES := [
	{"name": "COMMON", "color": Color("f4f4f4"), "mult": 1.0, "weight": 50.0},
	{"name": "UNCOMMON", "color": Color("59e66b"), "mult": 1.45, "weight": 27.0},
	{"name": "RARE", "color": Color("55a6ff"), "mult": 2.0, "weight": 14.0},
	{"name": "EPIC", "color": Color("bd6bff"), "mult": 2.8, "weight": 7.0},
	{"name": "LEGENDARY", "color": Color("ff9d32"), "mult": 4.0, "weight": 2.0}
]
const UPGRADE_DATA := {
	"projectiles": {"title": "MULTISHOT", "description": "+%s fireball projectile", "icon": "▦"},
	"bounces": {"title": "RICOCHET", "description": "+%s projectile bounce", "icon": "↗"},
	"radius": {"title": "BIG BANG", "description": "+%s explosion radius", "icon": "□"},
	"damage": {"title": "INFERNO", "description": "+%s fireball damage", "icon": "◆"},
	"crit": {"title": "LUCKY SPARK", "description": "+%s%% critical chance", "icon": "✦"},
	"attack_speed": {"title": "QUICK CAST", "description": "+%s%% attack speed", "icon": "»"}
}

var player: CharacterBody3D
var player_health := 100.0
var level := 1
var xp := 0.0
var xp_needed := 100.0
var xp_bonus := 0.0
var collection_radius := 2.2
var stats := {
	"projectiles": 1,
	"bounces": 0,
	"radius": 1.5,
	"damage": 100.0,
	"crit": 0.05,
	"attack_speed": 1.0
}
var enemy_spawn_clock := 0.0
var relic_spawn_clock := 10.0
var powerup_spawn_clock := 7.0
var next_powerup_kind := "star"
var elapsed := 0.0
var kills := 0
var upgrade_active := false
var game_over := false
var pause_active := false
var current_offers: Array[Dictionary] = []

var health_label: Label
var health_bar: ProgressBar
var xp_label: Label
var xp_bar: ProgressBar
var level_label: Label
var hop_label: Label
var stats_label: Label
var wave_label: Label
var upgrade_overlay: ColorRect
var upgrade_title: Label
var cards_row: HBoxContainer
var hit_overlay: ColorRect
var hit_material: ShaderMaterial
var damage_tween: Tween
var pickup_message: Label
var pickup_message_tween: Tween
var pause_overlay: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	seed(1337)
	_build_environment()
	_build_arena()
	_spawn_player()
	_build_hud()
	for i in 7:
		_spawn_enemy()
	for i in 4:
		_spawn_relic()
	_update_hud()

func _process(delta: float) -> void:
	if get_tree().paused or game_over:
		return
	elapsed += delta
	player_health = minf(100.0, player_health + HEALTH_REGEN_PER_SECOND * delta)
	if elapsed >= RUN_DURATION:
		_win_run()
		return
	enemy_spawn_clock -= delta
	relic_spawn_clock -= delta
	powerup_spawn_clock -= delta
	var spawn_interval := _enemy_spawn_interval(elapsed)
	if enemy_spawn_clock <= 0.0:
		_spawn_enemy()
		enemy_spawn_clock = spawn_interval
	if relic_spawn_clock <= 0.0:
		_spawn_relic()
		relic_spawn_clock = 13.0
	if powerup_spawn_clock <= 0.0:
		_spawn_powerup(next_powerup_kind)
		next_powerup_kind = "magnet" if next_powerup_kind == "star" else "star"
		powerup_spawn_clock = 14.0
	_update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"):
			if not game_over and not upgrade_active:
				_set_pause(not pause_active)
			get_viewport().set_input_as_handled()
		elif game_over and event.keycode == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif upgrade_active and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			var index := int(event.keycode - KEY_1)
			if index < current_offers.size():
				_choose_upgrade(index)
		elif not game_over and not pause_active and not upgrade_active and event.is_action_pressed("mega_fireball"):
			_fire_mega_fireball()
		elif not game_over and not pause_active and not upgrade_active and event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_use_skill(int(event.keycode - KEY_1) + 1)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3f93df")
	sky_mat.sky_horizon_color = Color("9bd8f4")
	sky_mat.ground_bottom_color = Color("315b35")
	sky_mat.ground_horizon_color = Color("b1d69b")
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("fff0c7")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

func _build_arena() -> void:
	_add_static_box("Grass", Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0), Vector3(0, -0.5, 0), Color("55a956"))
	var wall_color := Color("e9d6a4")
	_add_static_box("NorthWall", Vector3(ARENA_HALF * 2.0 + 2.0, 3.0, 1.0), Vector3(0, 1.5, -ARENA_HALF), wall_color)
	_add_static_box("SouthWall", Vector3(ARENA_HALF * 2.0 + 2.0, 3.0, 1.0), Vector3(0, 1.5, ARENA_HALF), wall_color)
	_add_static_box("WestWall", Vector3(1.0, 3.0, ARENA_HALF * 2.0), Vector3(-ARENA_HALF, 1.5, 0), wall_color)
	_add_static_box("EastWall", Vector3(1.0, 3.0, ARENA_HALF * 2.0), Vector3(ARENA_HALF, 1.5, 0), wall_color)

	# Trees frame the arena; the grass itself stays clear so pickups stand out.
	for i in 16:
		var angle := randf() * TAU
		var radius := randf_range(31.0, 43.0)
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_add_tree(pos)
	for i in 9:
		_add_cloud(Vector3(randf_range(-55, 55), randf_range(18, 27), randf_range(-55, 55)))

func _add_static_box(box_name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	body.position = pos
	add_child(body)
	return body

func _add_visual_box(size: Vector3, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	return mat

func _add_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos
	add_child(tree)
	_add_visual_box(Vector3(0.8, 3.1, 0.8), Vector3(0, 1.55, 0), Color("755035"), tree)
	_add_visual_box(Vector3(3.0, 1.5, 3.0), Vector3(0, 3.3, 0), Color("3c873f"), tree)
	_add_visual_box(Vector3(2.1, 1.2, 2.1), Vector3(0.35, 4.35, -0.2), Color("4e9e4c"), tree)

func _add_cloud(pos: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.position = pos
	add_child(cloud)
	var white := Color(1, 1, 1, 0.92)
	_add_visual_box(Vector3(5.0, 1.3, 2.2), Vector3.ZERO, white, cloud)
	_add_visual_box(Vector3(2.5, 1.8, 2.0), Vector3(-1.2, 0.7, 0), white, cloud)
	_add_visual_box(Vector3(2.7, 1.6, 2.0), Vector3(1.4, 0.55, 0), white, cloud)

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector3(0, 0.05, 8)
	add_child(player)
	player.fire_requested.connect(_on_player_fire)
	player.hop_changed.connect(_on_hop_changed)
	player.hurt.connect(_on_player_hurt)

func _spawn_enemy() -> void:
	if not is_instance_valid(player):
		return
	var enemy := EnemyScript.new()
	enemy.add_to_group("enemies")
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	var angle := randf() * TAU
	var distance := randf_range(18.0, 38.0)
	var candidate: Vector3 = player.global_position + Vector3(cos(angle), 0, sin(angle)) * distance
	candidate.x = clampf(candidate.x, -44.0, 44.0)
	candidate.z = clampf(candidate.z, -44.0, 44.0)
	enemy.position = Vector3(candidate.x, 0.05, candidate.z)
	add_child(enemy)
	var health_multiplier := _enemy_health_multiplier(elapsed)
	enemy.setup(player, health_multiplier)
	enemy.died.connect(_on_enemy_died)

func _enemy_spawn_interval(at_time: float) -> float:
	var progress := clampf(at_time / RUN_DURATION, 0.0, 1.0)
	# Four times the previous rate, still with no active-enemy cap.
	return lerpf(0.25, 0.0375, pow(progress, 0.75))

func _enemy_health_multiplier(at_time: float) -> float:
	var progress := clampf(at_time / RUN_DURATION, 0.0, 1.0)
	return lerpf(1.0, 3.0, progress)

func _spawn_relic() -> void:
	var pickup := PickupScript.new()
	pickup.add_to_group("pickups")
	pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
	pickup.position = Vector3(randf_range(-42, 42), 0.75, randf_range(-42, 42))
	pickup.setup("relic", 1.0, player)
	pickup.collection_radius = collection_radius
	add_child(pickup)
	pickup.collected.connect(_on_pickup_collected)

func _spawn_powerup(kind: String) -> void:
	var pickup := PickupScript.new()
	pickup.add_to_group("pickups")
	pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
	pickup.position = Vector3(randf_range(-40, 40), 0.95, randf_range(-40, 40))
	pickup.setup(kind, 1.0, player)
	pickup.collection_radius = collection_radius
	add_child(pickup)
	pickup.collected.connect(_on_pickup_collected)

func _spawn_xp(pos: Vector3) -> void:
	for i in randi_range(2, 4):
		var pickup := PickupScript.new()
		pickup.add_to_group("pickups")
		pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
		pickup.position = pos + Vector3(randf_range(-0.8, 0.8), randf_range(0.15, 0.65), randf_range(-0.8, 0.8))
		pickup.setup("xp", 12.0, player)
		pickup.collection_radius = collection_radius
		add_child(pickup)
		pickup.collected.connect(_on_pickup_collected)

func _on_player_fire(origin: Vector3, direction: Vector3) -> void:
	var aim_point: Vector3 = player.get_aim_point()
	var center_direction: Vector3 = (aim_point - origin).normalized()
	var count: int = stats.projectiles
	for i in count:
		var projectile := FireballScript.new()
		projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
		projectile.position = origin
		var spread_index := float(i) - float(count - 1) * 0.5
		var spread := deg_to_rad(spread_index * 4.0)
		var shot_direction: Vector3 = center_direction.rotated(Vector3.UP, spread)
		add_child(projectile)
		projectile.setup(shot_direction, stats.damage, stats.radius, stats.bounces, stats.crit, player)

func _fire_mega_fireball() -> void:
	if not is_instance_valid(player):
		return
	var projectile := MegaFireballScript.new()
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	projectile.position = player.muzzle.global_position
	add_child(projectile)
	projectile.setup(-player.camera.global_transform.basis.z)
	_show_pickup_message("MEGA FIREBALL", Color("ff7b18"))

func _on_enemy_died(_enemy: Node, pos: Vector3) -> void:
	kills += 1
	_spawn_xp(pos)

func _on_pickup_collected(kind: String, value: float) -> void:
	match kind:
		"xp":
			xp += value * (1.0 + xp_bonus)
			_check_level_up()
		"relic":
			xp_bonus += 0.10
			collection_radius += 0.55
			for pickup in get_tree().get_nodes_in_group("pickups"):
				pickup.collection_radius = collection_radius
			_show_pickup_message("GOLD RELIC COLLECTED\n+10% XP GAIN   •   +0.55m PICKUP RANGE")
		"star":
			player.activate_star_power(5.0)
			_show_pickup_message("STAR POWER!\n3× SPEED   •   CONTACT KILLS   •   5 SECONDS")
		"magnet":
			for pickup in get_tree().get_nodes_in_group("pickups"):
				if pickup.kind == "xp":
					pickup.activate_magnet()
			_show_pickup_message("XP MAGNET!\nALL UNCOLLECTED XP IS INBOUND", Color("55a6ff"))
	_update_hud()

func _use_skill(skill_number: int) -> void:
	if not is_instance_valid(player):
		return
	var center := player.global_position
	match skill_number:
		1:
			for enemy in _enemies_within(center, 18.0):
				enemy.apply_knockback(center, 31.0)
			_spawn_skill_pulse(center + Vector3.UP * 0.7, 18.0, Color("7de9ff"), 0.3, 0.3)
			_show_pickup_message("SHOCK WAVE")
		2:
			for enemy in _enemies_within(center, 10.0):
				enemy.freeze(4.0)
			_spawn_frost_nova_visual(center + Vector3.UP * 0.15, 10.0)
			_show_pickup_message("FROST NOVA   •   4 SECOND FREEZE")
		3:
			for enemy in _enemies_within(center, 11.0):
				enemy.take_damage(900.0)
			_spawn_skill_pulse(center + Vector3.UP * 0.7, 11.0, Color("ff6b24"), 0.16, 0.72)
			_show_pickup_message("NUKE   •   900 DAMAGE")
		4:
			var vortex := VortexScript.new()
			vortex.process_mode = Node.PROCESS_MODE_PAUSABLE
			vortex.position = player.camera.global_position + -player.camera.global_transform.basis.z * 1.6
			add_child(vortex)
			vortex.setup(-player.camera.global_transform.basis.z)
			_show_pickup_message("VORTEX LAUNCHED")

func _enemies_within(center: Vector3, radius: float) -> Array[Node]:
	var nearby: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.global_position.distance_to(center) <= radius:
			nearby.append(enemy)
	return nearby

func _spawn_skill_pulse(center: Vector3, radius: float, color: Color, duration := 0.34, opacity := 0.34) -> void:
	var pulse := MeshInstance3D.new()
	pulse.add_to_group("skill_effects")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	pulse.mesh = sphere
	pulse.position = center
	pulse.scale = Vector3.ONE * 0.1
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, opacity)
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	pulse.material_override = mat
	add_child(pulse)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE * radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(pulse.queue_free)

func _spawn_frost_nova_visual(center: Vector3, radius: float) -> void:
	_spawn_skill_pulse(center + Vector3.UP * 0.55, radius, Color("68d9ff"), 0.28, 0.44)
	var ice_root := Node3D.new()
	ice_root.add_to_group("frost_nova_visuals")
	ice_root.position = center
	ice_root.scale = Vector3.ONE * 0.12
	add_child(ice_root)
	var ice_mat := StandardMaterial3D.new()
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.albedo_color = Color(0.35, 0.86, 1.0, 0.84)
	ice_mat.emission_enabled = true
	ice_mat.emission = Color("45bfff")
	ice_mat.emission_energy_multiplier = 2.8
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var shard := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.23
		cone.height = 2.4
		shard.mesh = cone
		shard.position = Vector3(cos(angle) * radius * 0.52, 1.2, sin(angle) * radius * 0.52)
		shard.scale.y = 0.65 + float(i % 4) * 0.16
		shard.material_override = ice_mat
		ice_root.add_child(shard)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.48
	ring_mesh.outer_radius = radius * 0.55
	ring.mesh = ring_mesh
	ring.position.y = 0.08
	ring.material_override = ice_mat
	ice_root.add_child(ring)
	var tween := ice_root.create_tween()
	tween.tween_property(ice_root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.22)
	tween.tween_property(ice_mat, "albedo_color:a", 0.0, 0.24)
	tween.parallel().tween_property(ice_root, "scale", Vector3.ONE * 1.12, 0.24)
	tween.tween_callback(ice_root.queue_free)

func _check_level_up() -> void:
	if xp >= xp_needed and not upgrade_active:
		xp -= xp_needed
		level += 1
		xp_needed = 100.0 + float(level - 1) * 42.0
		_show_upgrade_choices()

func _roll_rarity() -> Dictionary:
	var roll := randf() * 100.0
	var running := 0.0
	for rarity in RARITIES:
		running += rarity.weight
		if roll <= running:
			return rarity
	return RARITIES[0]

func _make_offer(kind: String) -> Dictionary:
	var rarity := _roll_rarity()
	var mult: float = rarity.mult
	var amount: float
	match kind:
		"projectiles": amount = clampi(int(round(mult)), 1, 3)
		"bounces": amount = clampi(int(round(mult)), 1, 4)
		"radius": amount = snapped(0.30 * mult, 0.05)
		"damage": amount = snapped(20.0 * mult, 5.0)
		"crit": amount = snapped(3.0 * mult, 1.0)
		"attack_speed": amount = snapped(12.0 * mult, 1.0)
	return {"kind": kind, "rarity": rarity, "amount": amount}

func _show_upgrade_choices() -> void:
	upgrade_active = true
	player.alive = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_offers.clear()
	var kinds: Array = UPGRADE_DATA.keys()
	kinds.shuffle()
	for i in 3:
		current_offers.append(_make_offer(kinds[i]))
	for child in cards_row.get_children():
		child.queue_free()
	for i in current_offers.size():
		var card := _create_upgrade_card(current_offers[i], i)
		cards_row.add_child(card)
	upgrade_title.text = "LEVEL %d  •  CHOOSE AN UPGRADE" % level
	upgrade_overlay.visible = true

func _create_upgrade_card(offer: Dictionary, index: int) -> Button:
	var data: Dictionary = UPGRADE_DATA[offer.kind]
	var rarity: Dictionary = offer.rarity
	var amount_text := str(int(offer.amount)) if offer.kind in ["projectiles", "bounces", "damage", "crit", "attack_speed"] else "%.2f m" % offer.amount
	var description: String = data.description % amount_text
	if offer.kind in ["projectiles", "bounces"] and int(offer.amount) != 1:
		description += "s"
	var button := Button.new()
	# Upgrade cards are display-only: selection is intentionally restricted to
	# the 1/2/3 keys so a held mouse button cannot auto-select a card.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(285, 320)
	button.text = "%s\n\n%s\n\n%s\n\n[%d]  SELECT" % [data.icon, data.title, description, index + 1]
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", rarity.color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_constant_override("outline_size", 8)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("172331")
	normal.border_color = rarity.color
	normal.set_border_width_all(4)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	var hover := normal.duplicate()
	hover.bg_color = Color("25384b")
	hover.set_border_width_all(7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.tooltip_text = rarity.name
	return button

func _choose_upgrade(index: int) -> void:
	if not upgrade_active or index >= current_offers.size():
		return
	var offer := current_offers[index]
	match offer.kind:
		"projectiles": stats.projectiles += int(offer.amount)
		"bounces": stats.bounces += int(offer.amount)
		"radius": stats.radius += offer.amount
		"damage": stats.damage += offer.amount
		"crit": stats.crit = minf(0.75, stats.crit + offer.amount / 100.0)
		"attack_speed": stats.attack_speed += offer.amount / 100.0
	player.set_attack_speed(stats.attack_speed)
	upgrade_active = false
	upgrade_overlay.visible = false
	get_tree().paused = false
	player.alive = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()
	# If one giant pickup crossed several thresholds, present the next choice shortly after.
	if xp >= xp_needed:
		get_tree().create_timer(0.2).timeout.connect(_check_level_up)

func _on_hop_changed(chain: int, multiplier: float) -> void:
	hop_label.text = "HOP %d / 4   ×%.2f SPEED" % [chain, multiplier]
	hop_label.modulate = Color("ffd35a") if chain == 4 else Color.WHITE

func _on_player_hurt(amount: float) -> void:
	if game_over:
		return
	player_health = maxf(0.0, player_health - amount)
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	_set_damage_vignette(0.92)
	damage_tween = create_tween()
	damage_tween.tween_method(_set_damage_vignette, 0.92, 0.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if player_health <= 0.0:
		_game_over()

func _set_damage_vignette(intensity: float) -> void:
	if is_instance_valid(hit_material):
		hit_material.set_shader_parameter("intensity", intensity)

func _show_pickup_message(message: String, color := Color("ffe66b")) -> void:
	if pickup_message_tween and pickup_message_tween.is_valid():
		pickup_message_tween.kill()
	pickup_message.text = message
	pickup_message.add_theme_color_override("font_color", color)
	pickup_message.add_theme_color_override("font_outline_color", color.darkened(0.72))
	pickup_message.visible = true
	pickup_message.modulate = Color.WHITE
	pickup_message.scale = Vector2(0.88, 0.88)
	pickup_message.pivot_offset = pickup_message.size * 0.5
	pickup_message_tween = create_tween()
	pickup_message_tween.tween_property(pickup_message, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pickup_message_tween.tween_interval(1.15)
	pickup_message_tween.tween_property(pickup_message, "modulate:a", 0.0, 0.45)
	pickup_message_tween.tween_callback(func() -> void: pickup_message.visible = false)

func _set_pause(should_pause: bool) -> void:
	if game_over or upgrade_active:
		return
	pause_active = should_pause
	pause_overlay.visible = should_pause
	get_tree().paused = should_pause
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if should_pause else Input.MOUSE_MODE_CAPTURED

func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_lobby() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://lobby.tscn")

func _game_over() -> void:
	game_over = true
	player.alive = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in cards_row.get_children():
		child.queue_free()
	upgrade_title.text = "RUN OVER\n\nLEVEL %d  •  %d CUBES DEFEATED\n\nPRESS R TO RUN AGAIN" % [level, kills]
	upgrade_overlay.visible = true

func _win_run() -> void:
	game_over = true
	player.alive = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in cards_row.get_children():
		child.queue_free()
	upgrade_title.text = "YOU SURVIVED!\n\n10:00 COMPLETE  •  LEVEL %d  •  %d CUBES DEFEATED\n\nPRESS R TO PLAY AGAIN" % [level, kills]
	upgrade_overlay.visible = true

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	canvas.add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(350, 0)
	left_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.08, 0.12, 0.78), Color("6ee7ff")))
	top.add_child(left_panel)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 16)
	left_margin.add_theme_constant_override("margin_right", 16)
	left_margin.add_theme_constant_override("margin_top", 10)
	left_margin.add_theme_constant_override("margin_bottom", 10)
	left_panel.add_child(left_margin)
	var left := VBoxContainer.new()
	left_margin.add_child(left)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(315, 30)
	health_bar.max_value = 100.0
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _flat_style(Color("2a1720")))
	health_bar.add_theme_stylebox_override("fill", _flat_style(Color("ff5d62")))
	left.add_child(health_bar)
	health_label = Label.new()
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 18)
	_style_hud_label(health_label)
	health_bar.add_child(health_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	wave_label = Label.new()
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", 20)
	_style_hud_label(wave_label)
	top.add_child(wave_label)

	# The XP bar is independent of the corner panels so it remains exactly
	# centered at every supported viewport size.
	xp_bar = ProgressBar.new()
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	xp_bar.position = Vector2(-285, 22)
	xp_bar.size = Vector2(570, 34)
	xp_bar.custom_minimum_size = Vector2(570, 34)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", _panel_style(Color("152132"), Color("92efff")))
	xp_bar.add_theme_stylebox_override("fill", _flat_style(Color("58dcff")))
	canvas.add_child(xp_bar)
	level_label = Label.new()
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 18)
	_style_hud_label(level_label)
	xp_bar.add_child(level_label)
	xp_label = Label.new()
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	xp_label.position = Vector2(-285, 60)
	xp_label.size = Vector2(570, 24)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 15)
	_style_hud_label(xp_label)
	canvas.add_child(xp_label)

	var center_spacer := Control.new()
	center_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center_spacer)
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var info := VBoxContainer.new()
	bottom.add_child(info)
	hop_label = Label.new()
	hop_label.text = "HOP 0 / 4   ×1.00 SPEED"
	hop_label.add_theme_font_size_override("font_size", 20)
	_style_hud_label(hop_label)
	info.add_child(hop_label)
	var controls := Label.new()
	controls.text = "SPACE HOP   •   SHIFT+SPACE LONG JUMP   •   CTRL+SPACE MEGA/TRIPLE\nE DASH   •   Q MEGA FIREBALL   •   1 SHOCK   2 FREEZE   3 NUKE   4 VORTEX   •   LMB FIRE"
	controls.modulate = Color(1, 1, 1, 0.72)
	controls.add_theme_font_size_override("font_size", 14)
	_style_hud_label(controls)
	info.add_child(controls)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_font_size_override("font_size", 16)
	_style_hud_label(stats_label)
	bottom.add_child(stats_label)

	var crosshair := Label.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 26)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.9))
	crosshair.add_theme_constant_override("outline_size", 3)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-9, -18)
	canvas.add_child(crosshair)

	hit_overlay = ColorRect.new()
	hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_overlay.color = Color.WHITE
	var hit_shader := Shader.new()
	hit_shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = 1.0 - smoothstep(0.01, 0.19, edge_distance);
	COLOR = vec4(0.9, 0.01, 0.0, edge * intensity);
}
"""
	hit_material = ShaderMaterial.new()
	hit_material.shader = hit_shader
	hit_overlay.material = hit_material
	canvas.add_child(hit_overlay)

	pickup_message = Label.new()
	pickup_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pickup_message.position = Vector2(-360, 138)
	pickup_message.size = Vector2(720, 90)
	pickup_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_message.add_theme_font_size_override("font_size", 25)
	pickup_message.add_theme_color_override("font_color", Color("ffe66b"))
	pickup_message.add_theme_color_override("font_outline_color", Color("4a2d00"))
	pickup_message.add_theme_constant_override("outline_size", 8)
	pickup_message.visible = false
	canvas.add_child(pickup_message)

	pause_overlay = ColorRect.new()
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.02, 0.04, 0.07, 0.88)
	pause_overlay.visible = false
	canvas.add_child(pause_overlay)
	var pause_box := VBoxContainer.new()
	pause_box.set_anchors_preset(Control.PRESET_CENTER)
	pause_box.position = Vector2(-210, -190)
	pause_box.custom_minimum_size = Vector2(420, 380)
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 20)
	pause_overlay.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 52)
	_style_hud_label(pause_title)
	pause_box.add_child(pause_title)
	var pause_hint := Label.new()
	pause_hint.text = "The survival timer is stopped"
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.add_theme_font_size_override("font_size", 18)
	pause_hint.modulate = Color(1, 1, 1, 0.75)
	pause_box.add_child(pause_hint)
	var resume_button := Button.new()
	resume_button.text = "RESUME"
	resume_button.custom_minimum_size = Vector2(300, 56)
	resume_button.add_theme_font_size_override("font_size", 22)
	resume_button.pressed.connect(_set_pause.bind(false))
	pause_box.add_child(resume_button)
	var restart_button := Button.new()
	restart_button.text = "RESTART RUN"
	restart_button.custom_minimum_size = Vector2(300, 48)
	restart_button.add_theme_font_size_override("font_size", 18)
	restart_button.pressed.connect(_restart_run)
	pause_box.add_child(restart_button)
	var lobby_button := Button.new()
	lobby_button.text = "RETURN TO LOBBY"
	lobby_button.custom_minimum_size = Vector2(300, 48)
	lobby_button.add_theme_font_size_override("font_size", 18)
	lobby_button.pressed.connect(_return_to_lobby)
	pause_box.add_child(lobby_button)
	var escape_hint := Label.new()
	escape_hint.text = "Press ESC to resume"
	escape_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_hint.add_theme_font_size_override("font_size", 16)
	escape_hint.modulate = Color(1, 1, 1, 0.65)
	pause_box.add_child(escape_hint)

	upgrade_overlay = ColorRect.new()
	upgrade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.color = Color(0.025, 0.045, 0.07, 0.94)
	upgrade_overlay.visible = false
	canvas.add_child(upgrade_overlay)
	var upgrade_box := VBoxContainer.new()
	upgrade_box.set_anchors_preset(Control.PRESET_CENTER)
	upgrade_box.position = Vector2(-455, -235)
	upgrade_box.custom_minimum_size = Vector2(910, 470)
	upgrade_box.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_box.add_theme_constant_override("separation", 28)
	upgrade_overlay.add_child(upgrade_box)
	upgrade_title = Label.new()
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 34)
	upgrade_box.add_child(upgrade_title)
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 22)
	upgrade_box.add_child(cards_row)

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _style_hud_label(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.88))
	label.add_theme_constant_override("outline_size", 4)

func _update_hud() -> void:
	if not is_instance_valid(health_label):
		return
	health_label.text = "%d / %d" % [int(ceil(player_health)), 100]
	health_label.modulate = Color.WHITE
	health_bar.value = player_health
	xp_bar.max_value = xp_needed
	xp_bar.value = xp
	level_label.text = "Level %d" % level
	xp_label.text = "XP %d / %d   •   BONUS +%d%%   •   PULL %.1fm" % [int(xp), int(xp_needed), int(xp_bonus * 100), collection_radius]
	if player.is_star_powered():
		xp_label.text += "   •   STAR %.1fs" % player.star_power_timer
	stats_label.text = "FIREBALL  %d × %.0f DMG\nBOUNCE %d   •   BLAST %.1fm   •   CRIT %d%%   •   RATE ×%.2f" % [stats.projectiles, stats.damage, stats.bounces, stats.radius, int(stats.crit * 100), stats.attack_speed]
	var remaining := ceili(maxf(0.0, RUN_DURATION - elapsed))
	var spawn_rate := 1.0 / _enemy_spawn_interval(elapsed)
	wave_label.text = "%d CUBES  •  SPAWN %.1f/s  •  %02d:%02d REMAINING" % [kills, spawn_rate, remaining / 60, remaining % 60]
