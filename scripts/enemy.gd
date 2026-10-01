extends CharacterBody3D

signal died(enemy: Node, position: Vector3, attack_id: int, damage_amount: float)

var target: Node3D
var health := 300.0
var max_health := 300.0
var move_speed := 3.2
var touch_cooldown := 0.0
var visual: Node3D
var flash_timer := 0.0
var health_bar_fill: MeshInstance3D
var health_bar_material: StandardMaterial3D
var health_bar_text: Label3D
var freeze_timer := 0.0
var defeated := false
var vortex_hold_timer := 0.0
var vortex_hold_point := Vector3.ZERO
var enemy_type := 0
var ice_shell: MeshInstance3D
var body_material: StandardMaterial3D

func setup(player: Node3D, type_index := 0, fixed_health := 100.0, color := Color("ff2020")) -> void:
	target = player
	enemy_type = type_index
	max_health = fixed_health
	health = max_health
	move_speed = 3.2 + float(type_index) * 0.10
	scale = Vector3.ONE * (1.0 + float(type_index) * 0.035)
	if is_instance_valid(body_material):
		body_material.albedo_color = color
		body_material.emission = color
	_update_health_bar()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	_build_cube()

func _build_cube() -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.35, 1.35, 1.35)
	collision.shape = box
	collision.position.y = 0.68
	add_child(collision)
	visual = Node3D.new()
	visual.position.y = 0.68
	add_child(visual)
	var body := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(1.35, 1.35, 1.35)
	body.mesh = cube
	body_material = _mat(Color("ff2020"))
	body_material.emission_enabled = true
	body_material.emission = Color("ff2020")
	body_material.emission_energy_multiplier = 0.35
	body.material_override = body_material
	visual.add_child(body)
	for x in [-0.32, 0.32]:
		var eye := MeshInstance3D.new()
		var eye_mesh := BoxMesh.new()
		eye_mesh.size = Vector3(0.23, 0.28, 0.12)
		eye.mesh = eye_mesh
		eye.position = Vector3(x, 0.18, -0.70)
		eye.material_override = _mat(Color.WHITE)
		visual.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pupil_mesh := BoxMesh.new()
		pupil_mesh.size = Vector3(0.09, 0.13, 0.04)
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(0, 0, -0.08)
		pupil.material_override = _mat(Color("18202a"))
		eye.add_child(pupil)
	_build_health_bar()
	_build_ice_shell()

func _build_health_bar() -> void:
	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(1.62, 0.22, 0.07)
	background.mesh = background_mesh
	background.position = Vector3(0, 1.66, -0.74)
	background.material_override = _mat(Color("17202a"))
	add_child(background)

	health_bar_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(1.46, 0.12, 0.08)
	health_bar_fill.mesh = fill_mesh
	health_bar_fill.position = Vector3(0, 1.66, -0.79)
	health_bar_material = _mat(Color("62e36b"))
	health_bar_material.emission_enabled = true
	health_bar_material.emission = Color("36b94b")
	health_bar_material.emission_energy_multiplier = 1.2
	health_bar_fill.material_override = health_bar_material
	add_child(health_bar_fill)

	health_bar_text = Label3D.new()
	health_bar_text.position = Vector3(0, 1.66, -0.86)
	health_bar_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_text.no_depth_test = true
	health_bar_text.font_size = 30
	health_bar_text.pixel_size = 0.0065
	health_bar_text.modulate = Color.WHITE
	health_bar_text.outline_modulate = Color("111820")
	health_bar_text.outline_size = 10
	health_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(health_bar_text)
	_update_health_bar()

func _update_health_bar() -> void:
	if not is_instance_valid(health_bar_fill):
		return
	var ratio := clampf(health / maxf(1.0, max_health), 0.0, 1.0)
	health_bar_fill.scale.x = ratio
	health_bar_fill.position.x = -0.73 * (1.0 - ratio)
	var bar_color := Color("62e36b")
	if ratio <= 0.25:
		bar_color = Color("ff4f45")
	elif ratio <= 0.55:
		bar_color = Color("ffd45c")
	health_bar_material.albedo_color = bar_color
	health_bar_material.emission = bar_color
	health_bar_text.text = "%d / %d" % [maxi(0, int(ceil(health))), int(round(max_health))]

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	touch_cooldown = maxf(0.0, touch_cooldown - delta)
	freeze_timer = maxf(0.0, freeze_timer - delta)
	ice_shell.visible = freeze_timer > 0.0
	vortex_hold_timer = maxf(0.0, vortex_hold_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	visual.scale = Vector3.ONE * (1.08 if flash_timer > 0.0 else 1.0)
	if vortex_hold_timer > 0.0:
		global_position.x = move_toward(global_position.x, vortex_hold_point.x, 32.0 * delta)
		global_position.z = move_toward(global_position.z, vortex_hold_point.z, 32.0 * delta)
		velocity = Vector3.ZERO
		return
	if freeze_timer > 0.0:
		velocity = Vector3.ZERO
		return
	var offset := target.global_position - global_position
	offset.y = 0
	if offset.length() > 1.2:
		var direction := offset.normalized()
		velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
		# Godot's forward axis is -Z, the same face the eyes are attached to.
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		if touch_cooldown <= 0.0 and target.has_method("take_damage") and not (target.has_method("is_contact_invulnerable") and target.is_contact_invulnerable()):
			target.take_damage(12.0)
			touch_cooldown = 0.8
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	move_and_slide()

func take_damage(amount: float, is_crit := false, attack_id := -1) -> void:
	if defeated:
		return
	health -= amount
	_update_health_bar()
	flash_timer = 0.09
	if is_crit:
		visual.scale = Vector3.ONE * 1.18
	if health <= 0.0:
		defeat(attack_id, amount)

func defeat(attack_id := -1, damage_amount := 0.0) -> void:
	if defeated:
		return
	defeated = true
	died.emit(self, global_position + Vector3.UP * 0.5, attack_id, damage_amount)
	queue_free()

func apply_knockback(origin: Vector3, force: float) -> void:
	var direction := global_position - origin
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	velocity += direction.normalized() * force
	velocity.y = maxf(velocity.y, force * 0.22)

func apply_directional_knockback(direction: Vector3, force: float) -> void:
	velocity.x = direction.x * force
	velocity.z = direction.z * force

func freeze(duration: float) -> void:
	freeze_timer = maxf(freeze_timer, duration)
	ice_shell.visible = freeze_timer > 0.0

func pull_toward(point: Vector3, force: float, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	var distance := direction.length()
	const CAPTURE_RADIUS := 1.35
	if distance <= CAPTURE_RADIUS:
		vortex_hold_point = point
		vortex_hold_timer = 0.16
		global_position.x = move_toward(global_position.x, point.x, 32.0 * delta)
		global_position.z = move_toward(global_position.z, point.z, 32.0 * delta)
		velocity = Vector3.ZERO
		return
	# The distance-limited step cannot overshoot the capture zone, so enemies
	# converge on the core instead of being accelerated through it.
	var pull_speed := clampf(distance * 1.8, 12.0, force)
	var step := minf(pull_speed * delta, distance - CAPTURE_RADIUS)
	global_position += direction.normalized() * step
	velocity = direction.normalized() * pull_speed

func _build_ice_shell() -> void:
	ice_shell = MeshInstance3D.new()
	ice_shell.name = "FrozenIce"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.6
	ice_shell.mesh = box
	ice_shell.position.y = 0.68
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.8, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color("5bcfff")
	mat.emission_energy_multiplier = 1.2
	ice_shell.material_override = mat
	ice_shell.visible = false
	add_child(ice_shell)
