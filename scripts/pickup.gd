extends Area3D

signal collected(kind: String, value: float)

var kind := "xp"
var value := 20.0
var target: Node3D
var collection_radius := 2.2
var base_y := 0.0
var age := 0.0
var magnetized := false

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
	collision.shape = box
	add_child(collision)
	var mat := StandardMaterial3D.new()
	var color := Color("c7cdd6")
	match kind:
		"relic": color = Color("ffe66b")
		"star": color = Color("fff34d")
		"magnet": color = Color("4b9cff")
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.8
	if kind == "star":
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_build_star_visual(mat)
	else:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = box.size
		mesh.mesh = cube
		mesh.material_override = mat
		add_child(mesh)
	if kind == "relic":
		_build_relic_beacon(mat)
	elif kind == "star":
		_build_star_beacon(mat)
	elif kind == "magnet":
		_build_powerup_beacon(mat, "XP Magnet\nPull Every XP Orb")
	base_y = global_position.y

func _build_relic_beacon(material: StandardMaterial3D) -> void:
	# A large rotating plus, warm light, and billboard label distinguish this
	# permanent-stat relic from the small cyan XP cubes.
	for size in [Vector3(1.45, 0.20, 0.20), Vector3(0.20, 1.45, 0.20)]:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = size
		bar.mesh = bar_mesh
		bar.material_override = material
		add_child(bar)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd84d")
	light.light_energy = 3.0
	light.omni_range = 6.0
	add_child(light)
	var label := Label3D.new()
	label.text = "Gold Relic\nXP +10%  •  Pull +0.55m"
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
	# Crossed blue beams make the map-wide magnet easy to spot.
	for size in [Vector3(1.7, 0.18, 0.18), Vector3(0.18, 1.7, 0.18), Vector3(0.18, 0.18, 1.7)]:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = size
		bar.mesh = bar_mesh
		bar.material_override = material
		add_child(bar)
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
