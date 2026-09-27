extends CharacterBody3D

signal fire_requested(origin: Vector3, direction: Vector3)
signal hop_changed(chain: int, speed_multiplier: float)
signal hurt(amount: float)

const WALK_SPEED := 9.0
const MAX_HOP_SPEED := 18.0
const JUMP_VELOCITY := 7.6
const MEGA_JUMP_VELOCITY := 15.5
const LONG_JUMP_SPEED := 27.0
const DASH_SPEED := 34.0
const DASH_DURATION := 0.22
const DASH_COOLDOWN := 0.55
const GROUND_ACCEL := 64.0
const AIR_ACCEL := 22.0
const GROUND_FRICTION := 48.0
const COYOTE_TIME := 0.16
const JUMP_BUFFER_TIME := 0.16
const CHAIN_GRACE := 0.38

var camera: Camera3D
var head: Node3D
var muzzle: Marker3D
var hop_chain := 0
var coyote_timer := 0.0
var jump_buffer := 0.0
var grounded_timer := 0.0
var fire_cooldown := 0.0
var attack_interval := 0.65
var alive := true
var mouse_sensitivity := 0.0022
var mega_jump_active := false
var mega_air_jumps_remaining := 0
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.ZERO
var dash_hit_enemies := {}
var burst_speed_timer := 0.0
var star_power_timer := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	_build_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.55
	add_child(head)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 82.0
	head.add_child(camera)

	# Chunky first-person wand and glowing fire cube.
	var wand := MeshInstance3D.new()
	var wand_mesh := BoxMesh.new()
	wand_mesh.size = Vector3(0.12, 0.12, 0.65)
	wand.mesh = wand_mesh
	wand.position = Vector3(0.46, -0.38, -0.7)
	wand.rotation_degrees = Vector3(-14, 0, 0)
	wand.material_override = _material(Color("70452a"), 0.25)
	camera.add_child(wand)
	var gem := MeshInstance3D.new()
	var gem_mesh := BoxMesh.new()
	gem_mesh.size = Vector3(0.17, 0.17, 0.17)
	gem.mesh = gem_mesh
	gem.position = Vector3(0.46, -0.29, -1.03)
	gem.material_override = _material(Color("ff6a22"), 1.7)
	camera.add_child(gem)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0.34, -0.18, -1.2)
	camera.add_child(muzzle)

func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

# Read look input before the full-screen HUD can consume mouse motion.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and alive:
		_apply_mouse_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_mouse_look(relative_motion: Vector2) -> void:
	rotate_y(-relative_motion.x * mouse_sensitivity)
	head.rotate_x(-relative_motion.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	burst_speed_timer = maxf(0.0, burst_speed_timer - delta)
	star_power_timer = maxf(0.0, star_power_timer - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)

	var was_grounded := is_on_floor()
	if was_grounded:
		coyote_timer = COYOTE_TIME
		grounded_timer += delta
		mega_jump_active = false
		mega_air_jumps_remaining = 0
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		grounded_timer = 0.0
		velocity.y -= 22.0 * delta

	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		_start_dash()
	if Input.is_action_just_pressed("jump"):
		if was_grounded and Input.is_key_pressed(KEY_SHIFT):
			_perform_long_jump()
		elif was_grounded and Input.is_key_pressed(KEY_CTRL):
			_perform_mega_jump()
		elif not was_grounded and mega_jump_active and mega_air_jumps_remaining > 0:
			_perform_mega_air_jump()
		else:
			jump_buffer = JUMP_BUFFER_TIME

	if jump_buffer > 0.0 and coyote_timer > 0.0:
		_perform_jump()

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	var speed_multiplier := 1.0 + float(hop_chain) / 4.0
	var star_multiplier := 3.0 if is_star_powered() else 1.0
	var target_speed := WALK_SPEED * speed_multiplier * star_multiplier
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if is_dashing():
		horizontal = dash_direction * DASH_SPEED
	elif wish_dir.length_squared() > 0.0:
		var accel := GROUND_ACCEL if was_grounded else AIR_ACCEL
		horizontal = horizontal.move_toward(wish_dir * target_speed, accel * delta)
	elif was_grounded:
		horizontal = horizontal.move_toward(Vector3.ZERO, GROUND_FRICTION * delta)
	# Cap runaway diagonal/air speed while preserving Quake-like momentum.
	var speed_cap := MAX_HOP_SPEED * star_multiplier
	if burst_speed_timer > 0.0:
		speed_cap = maxf(speed_cap, LONG_JUMP_SPEED * star_multiplier)
	if is_dashing():
		speed_cap = DASH_SPEED * star_multiplier
	if horizontal.length() > speed_cap:
		horizontal = horizontal.normalized() * speed_cap
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_handle_enemy_contacts()

	if is_on_floor() and not was_grounded:
		# A buffered early press fires immediately on this landing.
		coyote_timer = COYOTE_TIME
		if jump_buffer > 0.0:
			_perform_jump()
	if is_on_floor() and grounded_timer > CHAIN_GRACE:
		_reset_chain()

	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		fire_cooldown = attack_interval
		fire_requested.emit(muzzle.global_position, -camera.global_transform.basis.z)

func _perform_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer = 0.0
	coyote_timer = 0.0
	hop_chain = mini(hop_chain + 1, 4)
	hop_changed.emit(hop_chain, 1.0 + float(hop_chain) / 4.0)

func _perform_mega_jump() -> void:
	velocity.y = MEGA_JUMP_VELOCITY
	jump_buffer = 0.0
	coyote_timer = 0.0
	mega_jump_active = true
	mega_air_jumps_remaining = 2

func _perform_mega_air_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer = 0.0
	mega_air_jumps_remaining -= 1

func _perform_long_jump() -> void:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	velocity.x = forward.x * LONG_JUMP_SPEED
	velocity.z = forward.z * LONG_JUMP_SPEED
	velocity.y = JUMP_VELOCITY
	burst_speed_timer = 0.7
	jump_buffer = 0.0
	coyote_timer = 0.0

func _start_dash() -> void:
	dash_direction = -global_transform.basis.z
	dash_direction.y = 0.0
	dash_direction = dash_direction.normalized()
	dash_timer = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN
	dash_hit_enemies.clear()

func _handle_enemy_contacts() -> void:
	if not is_dashing() and not is_star_powered():
		return
	var shape := SphereShape3D.new()
	shape.radius = 1.15
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.8)
	query.collision_mask = 4
	query.exclude = [self]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 24):
		var enemy: Node = hit.collider
		if not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
			continue
		if is_star_powered() and enemy.has_method("defeat"):
			enemy.defeat()
		elif is_dashing() and enemy.has_method("apply_knockback"):
			var enemy_id := enemy.get_instance_id()
			if not dash_hit_enemies.has(enemy_id):
				dash_hit_enemies[enemy_id] = true
				enemy.apply_knockback(global_position, 24.0)

func activate_star_power(duration := 5.0) -> void:
	star_power_timer = maxf(star_power_timer, duration)

func is_dashing() -> bool:
	return dash_timer > 0.0

func is_star_powered() -> bool:
	return star_power_timer > 0.0

func is_contact_invulnerable() -> bool:
	return is_dashing() or is_star_powered()

func _reset_chain() -> void:
	if hop_chain != 0:
		hop_chain = 0
		hop_changed.emit(0, 1.0)

func set_attack_speed(multiplier: float) -> void:
	attack_interval = 0.65 / multiplier

func take_damage(amount: float) -> void:
	if alive and not is_contact_invulnerable():
		hurt.emit(amount)

func get_aim_point(distance := 100.0) -> Vector3:
	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else to
