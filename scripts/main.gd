extends Node3D

const BossScript = preload("res://scripts/boss.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const FireballScript = preload("res://scripts/fireball.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const VortexScript = preload("res://scripts/vortex.gd")
const MegaFireballScript = preload("res://scripts/mega_fireball.gd")

const GameConsts = preload("res://scripts/consts.gd")

const ARENA_HALF := GameConsts.ARENA_HALF
const ARENA_FULL_RADIUS := ARENA_HALF * 1.45
const RUN_DURATION := GameConsts.RUN_DURATION
const STAR_SPAWN_INTERVAL := GameConsts.STAR_SPAWN_INTERVAL
const MAGNET_SPAWN_INTERVAL := GameConsts.MAGNET_SPAWN_INTERVAL
const SKILL_COOLDOWN := GameConsts.SKILL_COOLDOWN
const ENEMY_HEALTH := GameConsts.ENEMY_HEALTH
const ENEMY_COLORS := [
	Color("ff2020"), Color("ffe600"), Color("1769ff"), Color("20e050"), Color("ff20d6"),
	Color("16e8ff"), Color("ff7b16"), Color("8b32ff"), Color("f5f5f5"), Color("ff3c8e")
]
const RARITIES := GameConsts.RARITIES
const UPGRADE_DATA := {
	"projectiles": {"title": "Multishot", "description": "+%s Fireball Projectile", "icon": "▦"},
	"bounces": {"title": "Ricochet", "description": "+%s Projectile Bounce", "icon": "↗"},
	"radius": {"title": "Big Bang", "description": "+%s Explosion Radius", "icon": "□"},
	"damage": {"title": "Inferno", "description": "+%s Fireball Damage", "icon": "◆"},
	"crit": {"title": "Lucky Spark", "description": "+%s%% Critical Chance", "icon": "✦"},
	"attack_speed": {"title": "Quick Cast", "description": "+%s%% Attack Speed", "icon": "»"}
}

var player: CharacterBody3D
var player_health := GameConsts.PLAYER_MAX_HEALTH
var level := 1
var xp := 0.0
var xp_needed := GameConsts.XP_BASE_REQUIREMENT
var collection_radius := GameConsts.INITIAL_COLLECTION_RADIUS
var stats := {
	"projectiles": GameConsts.BASE_PROJECTILES,
	"bounces": GameConsts.BASE_BOUNCES,
	"radius": GameConsts.BASE_EXPLOSION_RADIUS,
	"damage": GameConsts.BASE_DAMAGE,
	"crit": GameConsts.BASE_CRIT_CHANCE,
	"attack_speed": GameConsts.BASE_ATTACK_SPEED
}
var enemy_spawn_clock := 0.0
var relic_spawn_clock := GameConsts.RELIC_FIRST_SPAWN_TIME
var magnet_spawn_clock := GameConsts.MAGNET_FIRST_SPAWN_TIME
var star_spawn_clock := STAR_SPAWN_INTERVAL
var elapsed := 0.0
var kills := 0
var upgrade_active := false
var boss: CharacterBody3D
var boss_spawned := false
var boss_defeated := false
var game_over := false
var pause_active := false
var current_offers: Array[Dictionary] = []
var skill_cooldowns := [0.0, 0.0, 0.0, 0.0, 0.0]
var skill_labels: Array[Label] = []
var skill_bars: Array[ProgressBar] = []
var tutorial_overlay: ColorRect
var run_max_damage := 0.0
var run_max_attack_kills := 0
var attack_kills: Dictionary = {}
var next_attack_id := 1

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
	for i in GameConsts.INITIAL_ENEMY_COUNT:
		_spawn_enemy()
	for i in GameConsts.INITIAL_RELIC_COUNT:
		_spawn_relic()
	_update_hud()

func _process(delta: float) -> void:
	if get_tree().paused or game_over:
		return
	elapsed += delta
	player_health = minf(GameConsts.PLAYER_MAX_HEALTH, player_health + _health_regen(elapsed) * delta)
	if not boss_spawned and elapsed >= GameConsts.BOSS_SPAWN_TIME:
		_spawn_boss()
	if elapsed >= RUN_DURATION:
		if boss_defeated:
			_win_run()
		else:
			_game_over()
			upgrade_title.text = "Run Failed — Boss Still Alive\n\nDefeat the final boss before %s.\n\nPress R To Run Again" % _format_time(RUN_DURATION)
		return
	enemy_spawn_clock -= delta
	relic_spawn_clock -= delta
	magnet_spawn_clock -= delta
	star_spawn_clock -= delta
	for i in skill_cooldowns.size():
		skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i] - delta)
	var spawn_interval := _enemy_spawn_interval(elapsed)
	while enemy_spawn_clock <= 0.0:
		_spawn_enemy()
		enemy_spawn_clock += spawn_interval
	if relic_spawn_clock <= 0.0:
		_spawn_relic()
		relic_spawn_clock = GameConsts.RELIC_SPAWN_INTERVAL
	if magnet_spawn_clock <= 0.0:
		_spawn_powerup("magnet")
		magnet_spawn_clock = MAGNET_SPAWN_INTERVAL
	if star_spawn_clock <= 0.0:
		_spawn_powerup("star")
		star_spawn_clock = STAR_SPAWN_INTERVAL
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
		elif not game_over and not pause_active and not upgrade_active and event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_use_skill(int(event.keycode - KEY_1) + 1)
	elif event is InputEventMouseButton and event.pressed and event.is_action_pressed("mega_fireball"):
		if not game_over and not pause_active and not upgrade_active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fire_mega_fireball()
			get_viewport().set_input_as_handled()

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
	var distance := randf_range(GameConsts.ENEMY_SPAWN_DISTANCE_MIN, GameConsts.ENEMY_SPAWN_DISTANCE_MAX)
	var candidate: Vector3 = player.global_position + Vector3(cos(angle), 0, sin(angle)) * distance
	candidate.x = clampf(candidate.x, -44.0, 44.0)
	candidate.z = clampf(candidate.z, -44.0, 44.0)
	enemy.position = Vector3(candidate.x, 0.05, candidate.z)
	add_child(enemy)
	var enemy_type := _choose_enemy_type(elapsed)
	enemy.setup(player, enemy_type, ENEMY_HEALTH[enemy_type], ENEMY_COLORS[enemy_type])
	enemy.move_speed = lerpf(GameConsts.ENEMY_SPEED_START, GameConsts.ENEMY_SPEED_END, pow(clampf(elapsed / RUN_DURATION, 0.0, 1.0), GameConsts.ENEMY_SPEED_RAMP_EXPONENT))
	enemy.died.connect(_on_enemy_died)

func _enemy_spawn_interval(at_time: float) -> float:
	var rates: Array = GameConsts.ENEMY_SPAWN_RATES
	var phase := clampf(at_time / RUN_DURATION, 0.0, 1.0) * float(rates.size() - 1)
	var lower := mini(int(phase), rates.size() - 2)
	return 1.0 / lerpf(rates[lower], rates[lower + 1], phase - float(lower))

func _health_regen(at_time: float) -> float:
	var ramp := clampf((at_time - GameConsts.HEALTH_REGEN_RAMP_START) / (RUN_DURATION - GameConsts.HEALTH_REGEN_RAMP_START), 0.0, 1.0)
	return lerpf(GameConsts.HEALTH_REGEN_START, GameConsts.HEALTH_REGEN_END, ramp)

func _enemy_health_multiplier(at_time: float) -> float:
	return _enemy_health_for_type(_primary_enemy_type(at_time)) / ENEMY_HEALTH[0]

func _primary_enemy_type(at_time: float) -> int:
	return clampi(int(floor(at_time / (RUN_DURATION / float(ENEMY_HEALTH.size())))), 0, ENEMY_HEALTH.size() - 1)

func _enemy_health_for_type(enemy_type: int) -> float:
	return ENEMY_HEALTH[clampi(enemy_type, 0, ENEMY_HEALTH.size() - 1)]

func _choose_enemy_type(at_time: float) -> int:
	# Red cubes are the sole opening enemy type.
	if at_time < GameConsts.OPENING_GRACE_DURATION:
		return 0
	var primary := _primary_enemy_type(at_time)
	var roll := randf()
	if roll < GameConsts.ENEMY_PREVIOUS_TYPE_CHANCE and primary > 0:
		return primary - 1
	if roll >= 1.0 - GameConsts.ENEMY_NEXT_TYPE_CHANCE and primary < ENEMY_HEALTH.size() - 1:
		return primary + 1
	return primary

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
	for i in randi_range(GameConsts.XP_DROPS_MIN, GameConsts.XP_DROPS_MAX):
		var pickup := PickupScript.new()
		pickup.add_to_group("pickups")
		pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
		pickup.position = pos + Vector3(randf_range(-0.8, 0.8), randf_range(0.15, 0.65), randf_range(-0.8, 0.8))
		pickup.setup("xp", GameConsts.XP_PER_DROP, player)
		pickup.collection_radius = collection_radius
		add_child(pickup)
		pickup.collected.connect(_on_pickup_collected)

func _on_player_fire(origin: Vector3, direction: Vector3) -> void:
	var aim_point: Vector3 = player.get_aim_point()
	var center_direction: Vector3 = (aim_point - origin).normalized()
	var count: int = stats.projectiles
	var attack_id := _begin_attack()
	for i in count:
		var projectile := FireballScript.new()
		projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
		projectile.position = origin
		var spread_index := float(i) - float(count - 1) * 0.5
		var spread := deg_to_rad(spread_index * GameConsts.FIREBALL_SPREAD_DEGREES)
		var shot_direction: Vector3 = center_direction.rotated(Vector3.UP, spread)
		add_child(projectile)
		projectile.damage_dealt.connect(_on_damage_dealt)
		projectile.setup(shot_direction, stats.damage, stats.radius, stats.bounces, stats.crit, player, attack_id)

func _fire_mega_fireball() -> void:
	if not is_instance_valid(player) or skill_cooldowns[4] > 0.0:
		return
	skill_cooldowns[4] = SKILL_COOLDOWN
	var projectile := MegaFireballScript.new()
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	projectile.position = player.muzzle.global_position
	add_child(projectile)
	projectile.setup(-player.camera.global_transform.basis.z, _begin_attack())
	_show_pickup_message("Mega Fireball", Color("ff7b18"))
	_update_hud()

func _begin_attack() -> int:
	var attack_id := next_attack_id
	next_attack_id += 1
	attack_kills[attack_id] = 0
	return attack_id

func _on_damage_dealt(amount: float) -> void:
	run_max_damage = maxf(run_max_damage, amount)

func _on_enemy_died(_enemy: Node, pos: Vector3, attack_id := -1, damage_amount := 0.0) -> void:
	kills += 1
	run_max_damage = maxf(run_max_damage, damage_amount)
	if attack_id >= 0:
		attack_kills[attack_id] = int(attack_kills.get(attack_id, 0)) + 1
		run_max_attack_kills = maxi(run_max_attack_kills, int(attack_kills[attack_id]))
	_spawn_xp(pos)

func _on_pickup_collected(kind: String, value: float) -> void:
	match kind:
		"xp":
			xp += value
			_check_level_up()
		"relic":
			xp += xp_needed * GameConsts.RELIC_LEVEL_XP_FRACTION
			collection_radius += GameConsts.RELIC_COLLECTION_RADIUS_BONUS
			for pickup in get_tree().get_nodes_in_group("pickups"):
				pickup.collection_radius = collection_radius
			_show_pickup_message("Gold Relic Collected\n+%.0f%% Level XP   •   +%.2fm Pickup Range" % [GameConsts.RELIC_LEVEL_XP_FRACTION * 100.0, GameConsts.RELIC_COLLECTION_RADIUS_BONUS])
			_check_level_up()
		"star":
			player.activate_star_power(GameConsts.STAR_DURATION)
			_show_pickup_message("Star Power!\n%.1f× Speed   •   Contact Kills   •   %.1f Seconds" % [GameConsts.STAR_SPEED_MULTIPLIER, GameConsts.STAR_DURATION])
		"magnet":
			for pickup in get_tree().get_nodes_in_group("pickups"):
				if pickup.kind == "xp":
					pickup.activate_magnet()
			_show_pickup_message("XP Magnet!\nAll Uncollected XP Is Inbound", Color("55a6ff"))
	_update_hud()

func _use_skill(skill_number: int) -> void:
	if not is_instance_valid(player):
		return
	var cooldown_index := skill_number - 1
	if cooldown_index < 0 or cooldown_index >= skill_cooldowns.size() or skill_cooldowns[cooldown_index] > 0.0:
		return
	skill_cooldowns[cooldown_index] = SKILL_COOLDOWN
	var center := player.global_position
	var attack_id := _begin_attack()
	match skill_number:
		1:
			# The arena is 96 units wide, so a 48-unit radius is half its size.
			var force_radius := ARENA_HALF
			for enemy in _enemies_within(center, force_radius):
				enemy.apply_knockback(center, GameConsts.FORCE_PUSH_STRENGTH)
			_spawn_skill_pulse(center + Vector3.UP * 0.7, force_radius, Color("7de9ff"), 0.3, 0.3)
			_show_pickup_message("Force Push")
		2:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				enemy.freeze(GameConsts.FROST_DURATION)
			_spawn_frost_nova_visual(center + Vector3.UP * 0.15, ARENA_FULL_RADIUS)
			_show_pickup_message("Frost Nova   •   Arena Frozen")
		3:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and not enemy.defeated:
					var damage: float = GameConsts.BOSS_SPECIAL_HIT_DAMAGE if enemy.is_in_group("bosses") else enemy.max_health
					enemy.take_explosion_damage(damage, attack_id)
			_spawn_skill_pulse(center + Vector3.UP * 0.7, ARENA_FULL_RADIUS, Color("ff6b24"), 0.55, 0.72)
			_show_pickup_message("Explosion   •   Arena Cleared")
		4:
			var vortex := VortexScript.new()
			vortex.process_mode = Node.PROCESS_MODE_PAUSABLE
			vortex.position = player.camera.global_position + -player.camera.global_transform.basis.z * 1.6
			add_child(vortex)
			vortex.setup(-player.camera.global_transform.basis.z)
			_show_pickup_message("Vortex Launched")
	_update_hud()

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
		xp_needed = _xp_required_for_level(level)
		_record_run_stats()
		_show_upgrade_choices()

func _xp_required_for_level(target_level: int) -> float:
	var completed_levels := float(maxi(0, target_level - 1))
	return GameConsts.XP_BASE_REQUIREMENT + completed_levels * GameConsts.XP_REQUIREMENT_LINEAR + completed_levels * completed_levels * GameConsts.XP_REQUIREMENT_QUADRATIC

func _roll_rarity() -> Dictionary:
	var total_weight := 0.0
	for rarity in RARITIES:
		total_weight += rarity.weight
	var roll := randf() * total_weight
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
		"radius": amount = snapped(GameConsts.UPGRADE_RADIUS * mult, 0.05)
		"damage": amount = snapped(GameConsts.UPGRADE_DAMAGE * mult, 5.0)
		"crit": amount = snapped(GameConsts.UPGRADE_CRIT_PERCENT * mult, 1.0)
		"attack_speed": amount = snapped(GameConsts.UPGRADE_ATTACK_SPEED_PERCENT * mult, 1.0)
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
	upgrade_title.text = "Level %d  •  Choose An Upgrade" % level
	upgrade_overlay.visible = true

func _create_upgrade_card(offer: Dictionary, index: int) -> Button:
	var data: Dictionary = UPGRADE_DATA[offer.kind]
	var rarity: Dictionary = offer.rarity
	var amount_text := str(int(offer.amount)) if offer.kind in ["projectiles", "bounces", "damage", "crit", "attack_speed"] else "%.2f m" % offer.amount
	var description: String = data.description % amount_text
	if offer.kind in ["projectiles", "bounces"] and int(offer.amount) != 1:
		description += "s"
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(285, 320)
	button.text = "%s\n\n%s\n\n%s\n\nClick To Select" % [data.icon, data.title, description]
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
	button.pressed.connect(_choose_upgrade.bind(index))
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
		"crit": stats.crit = minf(GameConsts.CRIT_CHANCE_CAP, stats.crit + offer.amount / 100.0)
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
	hop_label.text = "Hop %d / 4   ×%.2f Speed" % [chain, multiplier]
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
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.visible = false
	get_tree().paused = should_pause
	if should_pause:
		_release_mouse_cursor()
		call_deferred("_release_mouse_cursor")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_mouse_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_pause_tutorial() -> void:
	tutorial_overlay.visible = true
	pause_overlay.visible = false
	_release_mouse_cursor()

func _hide_pause_tutorial() -> void:
	tutorial_overlay.visible = false
	pause_overlay.visible = true
	_release_mouse_cursor()

func _record_run_stats() -> void:
	RunStats.record_run(level, kills, minf(elapsed, RUN_DURATION), run_max_damage, run_max_attack_kills)

func _restart_run() -> void:
	_record_run_stats()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_lobby() -> void:
	_record_run_stats()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://lobby.tscn")

func _game_over() -> void:
	_record_run_stats()
	game_over = true
	player.alive = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in cards_row.get_children():
		child.queue_free()
	upgrade_title.text = "Run Over\n\nLevel %d  •  %d Enemies Defeated\n\nPress R To Run Again" % [level, kills]
	upgrade_overlay.visible = true

func _format_time(seconds: float) -> String:
	var whole_seconds := ceili(seconds)
	return "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]

func _win_run() -> void:
	_record_run_stats()
	game_over = true
	player.alive = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in cards_row.get_children():
		child.queue_free()
	upgrade_title.text = "Victory — Boss Defeated!\n\n%s Complete  •  Level %d  •  %d Enemies Defeated\n\nPress R To Play Again" % [_format_time(RUN_DURATION), level, kills]
	upgrade_overlay.visible = true

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	canvas.add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(300, 30)
	health_bar.max_value = GameConsts.PLAYER_MAX_HEALTH
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	health_bar.add_theme_stylebox_override("fill", _flat_style(Color("ff5d62")))
	top.add_child(health_bar)
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
	var wave_margin := MarginContainer.new()
	wave_margin.add_theme_constant_override("margin_top", 48)
	top.add_child(wave_margin)
	wave_label = Label.new()
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", 20)
	_style_hud_label(wave_label)
	wave_margin.add_child(wave_label)

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
	hop_label.text = "Hop 0 / 4   ×1.00 Speed"
	hop_label.add_theme_font_size_override("font_size", 20)
	_style_hud_label(hop_label)
	info.add_child(hop_label)
	var skills_row := HBoxContainer.new()
	skills_row.add_theme_constant_override("separation", 8)
	info.add_child(skills_row)
	var skill_names := ["Force Push", "Frost Nova", "Explosion", "Vortex", "Mega Fireball"]
	var skill_colors := [Color("7de9ff"), Color("68d9ff"), Color("ff6b24"), Color("9b55ff"), Color("ff7b18")]
	for i in skill_names.size():
		var skill_bar := ProgressBar.new()
		skill_bar.custom_minimum_size = Vector2(132, 32)
		skill_bar.max_value = SKILL_COOLDOWN
		skill_bar.value = SKILL_COOLDOWN
		skill_bar.show_percentage = false
		skill_bar.add_theme_stylebox_override("background", _panel_style(Color("152132"), skill_colors[i].darkened(0.35)))
		skill_bar.add_theme_stylebox_override("fill", _flat_style(skill_colors[i]))
		skills_row.add_child(skill_bar)
		skill_bars.append(skill_bar)
		var skill_label := Label.new()
		skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_label.add_theme_font_size_override("font_size", 13)
		_style_hud_label(skill_label)
		skill_bar.add_child(skill_label)
		skill_labels.append(skill_label)
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
	pause_box.position = Vector2(-210, -220)
	pause_box.custom_minimum_size = Vector2(420, 440)
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 20)
	pause_overlay.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "Paused"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 52)
	_style_hud_label(pause_title)
	pause_box.add_child(pause_title)
	var pause_hint := Label.new()
	pause_hint.text = "The Survival Timer Is Stopped"
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.add_theme_font_size_override("font_size", 18)
	pause_hint.modulate = Color(1, 1, 1, 0.75)
	pause_box.add_child(pause_hint)
	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(300, 56)
	resume_button.add_theme_font_size_override("font_size", 22)
	resume_button.pressed.connect(_set_pause.bind(false))
	pause_box.add_child(resume_button)
	var tutorial_button := Button.new()
	tutorial_button.text = "Tutorial"
	tutorial_button.custom_minimum_size = Vector2(300, 48)
	tutorial_button.add_theme_font_size_override("font_size", 18)
	tutorial_button.pressed.connect(_show_pause_tutorial)
	pause_box.add_child(tutorial_button)
	var restart_button := Button.new()
	restart_button.text = "Restart Run"
	restart_button.custom_minimum_size = Vector2(300, 48)
	restart_button.add_theme_font_size_override("font_size", 18)
	restart_button.pressed.connect(_restart_run)
	pause_box.add_child(restart_button)
	var lobby_button := Button.new()
	lobby_button.text = "Return To Lobby"
	lobby_button.custom_minimum_size = Vector2(300, 48)
	lobby_button.add_theme_font_size_override("font_size", 18)
	lobby_button.pressed.connect(_return_to_lobby)
	pause_box.add_child(lobby_button)

	tutorial_overlay = ColorRect.new()
	tutorial_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.color = Color(0.02, 0.04, 0.07, 0.94)
	tutorial_overlay.visible = false
	canvas.add_child(tutorial_overlay)
	var tutorial_box := VBoxContainer.new()
	tutorial_box.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_box.position = Vector2(-350, -285)
	tutorial_box.custom_minimum_size = Vector2(700, 570)
	tutorial_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tutorial_box.add_theme_constant_override("separation", 16)
	tutorial_overlay.add_child(tutorial_box)
	var tutorial_title := Label.new()
	tutorial_title.text = "Tutorial"
	tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_title.add_theme_font_size_override("font_size", 42)
	_style_hud_label(tutorial_title)
	tutorial_box.add_child(tutorial_title)
	var tutorial_text := Label.new()
	tutorial_text.custom_minimum_size = Vector2(650, 390)
	tutorial_text.text = "W A S D  —  Move\nMouse  —  Look\nLeft Mouse  —  Fire\nRight Mouse  —  Mega Fireball\n\nSpace  —  Jump / Bunny Hop\nShift + Space  —  Long Jump\nCtrl + Space  —  Mega Triple Jump\nE  —  Dash\n\n1  —  Force Push\n2  —  Frost Nova\n3  —  Explosion\n4  —  Vortex\nEsc  —  Pause"
	tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_text.add_theme_font_size_override("font_size", 20)
	_style_hud_label(tutorial_text)
	tutorial_box.add_child(tutorial_text)
	var tutorial_back := Button.new()
	tutorial_back.text = "Back"
	tutorial_back.custom_minimum_size = Vector2(300, 52)
	tutorial_back.add_theme_font_size_override("font_size", 20)
	tutorial_back.pressed.connect(_hide_pause_tutorial)
	tutorial_box.add_child(tutorial_back)

	upgrade_overlay = ColorRect.new()
	upgrade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.color = Color(0, 0, 0, 0)
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

func _alive_enemy_count() -> int:
	var alive := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.defeated:
			alive += 1
	return alive

func _update_hud() -> void:
	if not is_instance_valid(health_label):
		return
	health_label.text = "%d / %d" % [int(ceil(player_health)), int(GameConsts.PLAYER_MAX_HEALTH)]
	health_label.modulate = Color.WHITE
	health_bar.value = player_health
	xp_bar.max_value = xp_needed
	xp_bar.value = xp
	level_label.text = "Level %d" % level
	xp_label.text = "XP %d / %d   •   Pull %.1fm" % [int(xp), int(xp_needed), collection_radius]
	if player.is_star_powered():
		xp_label.text += "   •   Star %.1fs" % player.star_power_timer
	var skill_names := ["Force Push", "Frost Nova", "Explosion", "Vortex", "Mega Fireball"]
	for i in mini(skill_labels.size(), skill_cooldowns.size()):
		var remaining: float = skill_cooldowns[i]
		skill_bars[i].value = SKILL_COOLDOWN - remaining
		skill_labels[i].text = "%s  READY" % skill_names[i] if remaining <= 0.0 else "%s  %02ds" % [skill_names[i], ceili(remaining)]
	stats_label.text = "Fireball  %d × %.0f Dmg\nBounce %d   •   Blast %.1fm   •   Crit %d%%   •   Rate ×%.2f" % [stats.projectiles, stats.damage, stats.bounces, stats.radius, int(stats.crit * 100), stats.attack_speed]
	var run_remaining := ceili(maxf(0.0, RUN_DURATION - elapsed))
	var spawn_rate := 1.0 / _enemy_spawn_interval(elapsed)
	var primary_type := _primary_enemy_type(elapsed)
	wave_label.text = "Wave %d/10  •  %d HP  •  %d Alive  •  %d Defeated  •  Spawn %.1f/s  •  %02d:%02d Remaining" % [primary_type + 1, int(ENEMY_HEALTH[primary_type]), _alive_enemy_count(), kills, spawn_rate, run_remaining / 60, run_remaining % 60]
	if boss_spawned:
		wave_label.text += "\nBoss defeated" if boss_defeated else "\nFINAL BOSS: %d / %d HP" % [int(boss.health), int(boss.max_health)]

func _spawn_boss() -> void:
	boss_spawned = true
	boss = BossScript.new()
	boss.name = "FinalBoss"
	boss.add_to_group("enemies")
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	var forward: Vector3 = -player.global_transform.basis.z
	var spawn: Vector3 = player.global_position + forward * GameConsts.BOSS_SPAWN_DISTANCE
	spawn.x = clampf(spawn.x, -40.0, 40.0)
	spawn.z = clampf(spawn.z, -40.0, 40.0)
	boss.position = Vector3(spawn.x, 0.05, spawn.z)
	add_child(boss)
	boss.setup(player, 9, GameConsts.BOSS_HEALTH, Color("b92cff"))
	boss.scale = Vector3.ONE * GameConsts.BOSS_SCALE
	boss.move_speed = GameConsts.BOSS_SPEED
	boss.died.connect(_on_enemy_died)
	boss.died.connect(func(_enemy: Node, _pos: Vector3, _attack: int, _damage: float): boss_defeated = true)
	_show_pickup_message("FINAL BOSS\nDefeat it before %s!" % _format_time(RUN_DURATION), Color("ffba38"))
