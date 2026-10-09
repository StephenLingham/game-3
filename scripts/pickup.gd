extends Area3D

signal collected(kind: String, value: float)

var kind := "xp"
var value := preload("res://scripts/consts.gd").XP_PER_DROP
var target: Node3D
var collection_radius := 2.2
var base_y := 0.0
var age := 0.0
var magnetized := false
static var xp_glow_mesh: QuadMesh

func setup(pickup_kind: String, pickup_value: float, player: Node3D) -> void:
	kind = pickup_kind
	value = pickup_value
	target = player

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match kind:
		"xp": box.size = Vector3.ONE * 0.48
		"relic": box.size = Vector3.ONE * 0.75
		_: box.size = Vector3.ONE * 0.95
	if kind == "star":
		collision.shape = box
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = box.size.x * 0.5
		collision.shape = sphere
	add_child(collision)
	var mat := StandardMaterial3D.new()
	var color := Color("258bff")
	match kind:
		"relic": color = Color("ffe66b")
		"star": color = Color("fff34d")
		"magnet": color = Color("ff3030")
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.8
	if kind == "xp":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("b8eaff")
		mat.emission_energy_multiplier = 6.0
	if kind == "star":
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_build_star_visual(mat)
	else:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = box.size.x * 0.5
		sphere.height = box.size.x
		mesh.mesh = sphere
		mesh.material_override = mat
		if kind == "xp":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	if kind == "relic":
		_build_relic_beacon(mat)
	elif kind == "star":
		_build_star_beacon(mat)
	elif kind == "magnet":
		_build_powerup_beacon(mat, "XP Magnet\nPull Every XP Orb")
	if kind == "xp":
		_build_xp_glow()
		global_position.y = 0.24
	base_y = global_position.y

func _build_xp_glow() -> void:
	# A soft additive billboard stays visible in the Web compatibility renderer,
	# which cannot rely on environment bloom. No per-orb dynamic lights.
	if xp_glow_mesh == null:
		xp_glow_mesh = _create_xp_glow_mesh()
	var glow := MeshInstance3D.new()
	glow.name = "XPGlow"
	glow.mesh = xp_glow_mesh
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

static func _create_xp_glow_mesh() -> QuadMesh:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0.55, 0.85, 1.0, 0.95), Color(0.15, 0.6, 1.0, 0.75), Color(0.04, 0.3, 1.0, 0.35), Color(0.0, 0.2, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.emission_enabled = true
	material.emission = Color("70caff")
	material.emission_texture = texture
	material.emission_energy_multiplier = 6.0
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = material
	return quad

func _build_relic_beacon(material: StandardMaterial3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffd84d")
	light.light_energy = 3.0
	light.omni_range = 6.0
	add_child(light)
	var label := Label3D.new()
	label.text = "Gold Relic\n25% Level XP  •  Pull +0.55m"
	label.position = Vector3(0, 1.45, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.pixel_size = 0.009
	label.modulate = Color("fff5ad")
	label.outline_modulate = Color("4a2d00")
	label.outline_size = 10
	add_child(label)

func _build_powerup_beacon(material: StandardMaterial3D, text: String) -> void:
	_add_powerup_light_and_label(material, text)

func _build_star_visual(material: StandardMaterial3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for i in 10:
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var radius := 1.05 if i % 2 == 0 else 0.44
		points.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
	for i in 10:
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(Vector3.ZERO)
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(points[i])
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(points[(i + 1) % 10])
	var star_mesh := surface.commit()
	for yaw in [0.0, 90.0]:
		var star := MeshInstance3D.new()
		star.mesh = star_mesh
		star.rotation_degrees.y = yaw
		star.material_override = material
		add_child(star)

func _build_star_beacon(material: StandardMaterial3D) -> void:
	_build_star_particles()
	_add_powerup_light_and_label(material, "Star Power\n3× Speed  •  Contact Kills")

func _add_powerup_light_and_label(material: StandardMaterial3D, text: String) -> void:
	var light := OmniLight3D.new()
	light.light_color = material.albedo_color
	light.light_energy = 4.0
	light.omni_range = 8.0
	add_child(light)
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(0, 1.55, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.pixel_size = 0.009
	label.modulate = material.albedo_color
	label.outline_modulate = material.albedo_color.darkened(0.78)
	label.outline_size = 10
	add_child(label)

func _physics_process(delta: float) -> void:
	age += delta
	rotate_y(delta * (2.4 if kind == "xp" else 1.2))
	if kind != "xp" and not magnetized:
		position.y = base_y + sin(age * 3.0) * 0.14
	if is_instance_valid(target):
		var offset := target.global_position + Vector3.UP - global_position
		if magnetized:
			global_position += offset.normalized() * 32.0 * delta
		elif offset.length() < collection_radius:
			global_position += offset.normalized() * (7.0 + 14.0 * (1.0 - offset.length() / collection_radius)) * delta

func activate_magnet() -> void:
	if kind == "xp":
		magnetized = true

func _on_body_entered(body: Node3D) -> void:
	if body == target:
		collected.emit(kind, value)
		queue_free()

func _build_star_particles() -> void:
	var sparks := CPUParticles3D.new()
	sparks.name = "StarSparkles"
	sparks.amount = 80
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 65.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.8
	sparks.gravity = Vector3(0, 0.3, 0)
	sparks.scale_amount_min = 0.04
	sparks.scale_amount_max = 0.12
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("fff5ad"), Color("ffac25"), Color(1, 0.3, 0.8, 0)])
	sparks.color_ramp = gradient
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("ffcf45")
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	sparks.mesh = mesh
	add_child(sparks)
