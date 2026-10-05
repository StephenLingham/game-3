extends CharacterBody3D

signal fire_requested(origin: Vector3, direction: Vector3)
signal hop_changed(chain: int, speed_multiplier: float)
signal hurt(amount: float)

const GameConsts = preload("res://scripts/consts.gd")

const WALK_SPEED := GameConsts.PLAYER_WALK_SPEED
const MAX_HOP_SPEED := GameConsts.PLAYER_MAX_HOP_SPEED
const JUMP_VELOCITY := GameConsts.PLAYER_JUMP_VELOCITY
const MEGA_JUMP_VELOCITY := GameConsts.PLAYER_MEGA_JUMP_VELOCITY
const LONG_JUMP_SPEED := GameConsts.PLAYER_LONG_JUMP_SPEED
const DASH_SPEED := GameConsts.DASH_DISTANCE / GameConsts.DASH_DURATION
const DASH_DURATION := GameConsts.DASH_DURATION
const DASH_COOLDOWN := GameConsts.DASH_COOLDOWN
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
var attack_interval := GameConsts.BASE_ATTACK_INTERVAL
var alive := true
var hurt_cooldown := 0.0
var mouse_sensitivity := 0.0022
var mega_jump_active := false
var mega_air_jumps_remaining := 0
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.ZERO
var dash_hit_enemies := {}
var burst_speed_timer := 0.0
var star_power_timer := 0.0
var star_overlay: ColorRect
var star_label: Label

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	_build_body()
	_build_star_effect()
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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not get_tree().paused and alive and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_mouse_look(relative_motion: Vector2) -> void:
	rotate_y(-relative_motion.x * mouse_sensitivity)
	head.rotate_x(-relative_motion.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	burst_speed_timer = maxf(0.0, burst_speed_timer - delta)
	star_power_timer = maxf(0.0, star_power_timer - delta)
	_update_star_effect()
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
	var star_multiplier := GameConsts.STAR_SPEED_MULTIPLIER if is_star_powered() else 1.0
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
	if is_dashing():
		var start := global_position
		var motion := dash_direction * DASH_SPEED * minf(delta, dash_timer)
		motion.y = 0.0
		# Pass through enemies while retaining arena collision.
		var previous_mask := collision_mask
		collision_mask = 1
		var wall_hit := move_and_collide(motion)
		_split_dash_crowd(start, global_position)
		var dash_velocity := velocity
		velocity = Vector3(0.0, velocity.y, 0.0)
		move_and_slide()
		collision_mask = previous_mask
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
		dash_timer = maxf(0.0, dash_timer - delta)
		if (wall_hit != null and absf(wall_hit.get_normal().y) < 0.5) or dash_timer <= 0.0:
			dash_timer = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
	else:
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

func _split_dash_crowd(start: Vector3, end: Vector3) -> void:
	var side := dash_direction.cross(Vector3.UP).normalized()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.defeated or dash_hit_enemies.has(enemy.get_instance_id()):
			continue
		var center: Vector3 = enemy.global_position + Vector3.UP * 0.68 * enemy.scale.y
		var closest := Geometry3D.get_closest_point_to_segment(center, start + Vector3.UP * 0.8, end + Vector3.UP * 0.8)
		if center.distance_to(closest) > GameConsts.DASH_CONTACT_RADIUS + 0.96 * enemy.scale.x:
			continue
		dash_hit_enemies[enemy.get_instance_id()] = true
		if is_star_powered():
			enemy.defeat()
		else:
			var side_offset := (center - closest).dot(side)
			var sign_side := 1.0 if side_offset > 0.0 else -1.0
			# Centerline enemies alternate sides.
			if is_zero_approx(side_offset):
				sign_side = 1.0 if dash_hit_enemies.size() % 2 == 0 else -1.0
			enemy.apply_directional_knockback(side * sign_side, GameConsts.DASH_KNOCKBACK_FORCE)

func activate_star_power(duration := GameConsts.STAR_DURATION) -> void:
	star_power_timer = maxf(star_power_timer, duration)
	_update_star_effect()

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
	attack_interval = GameConsts.BASE_ATTACK_INTERVAL / multiplier

func take_damage(amount: float) -> void:
	if alive and hurt_cooldown <= 0.0 and not is_contact_invulnerable():
		hurt_cooldown = GameConsts.PLAYER_HIT_GRACE
		hurt.emit(amount)

func get_aim_point(distance := 100.0) -> Vector3:
	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else to

func _build_star_effect() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 2
	add_child(canvas)
	star_overlay = ColorRect.new()
	star_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec2 p = UV * 2.0 - 1.0; float edge = smoothstep(0.45, 1.0, max(abs(p.x), abs(p.y))); vec3 rainbow = 0.5 + 0.5 * cos(TIME * 5.0 + vec3(0.0, 2.0, 4.0) + UV.x * 4.0); COLOR = vec4(rainbow, edge * 0.32); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	star_overlay.material = mat
	canvas.add_child(star_overlay)
	star_label = Label.new()
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	star_label.position = Vector2(-180, -110)
	star_label.size = Vector2(360, 40)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.add_theme_font_size_override("font_size", 26)
	star_label.add_theme_color_override("font_color", Color("fff34d"))
	canvas.add_child(star_label)
	_update_star_effect()

func _update_star_effect() -> void:
	if is_instance_valid(star_overlay):
		star_overlay.visible = is_star_powered()
		star_label.visible = is_star_powered()
		star_label.text = "★ STAR POWER  %.1fs ★" % star_power_timer
