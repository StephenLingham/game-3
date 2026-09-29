extends CharacterBody3D

signal damage_dealt(amount: float)

var direction := Vector3.FORWARD
var speed := 28.0
var damage := 100.0
var explosion_radius := 1.5
var bounces_left := 0
var crit_chance := 0.05
var lifetime := 5.0
var owner_body: Node3D
var already_hit: Dictionary = {}
var homing_target: Node3D
var attack_id := -1

func setup(dir: Vector3, projectile_damage: float, radius: float, bounces: int, crit: float, shooter: Node3D, source_attack_id := -1) -> void:
	direction = dir.normalized()
	damage = projectile_damage
	explosion_radius = radius
	bounces_left = bounces
	crit_chance = crit
	owner_body = shooter
	attack_id = source_attack_id

func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 8
	collision_mask = 1 | 4
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.34
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.38
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff7b24")
	mat.emission_enabled = true
	mat.emission = Color("ff4b13")
	mat.emission_energy_multiplier = 4.0
	mesh.material_override = mat
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color("ff7a30")
	light.light_energy = 2.2
	light.omni_range = 4.0
	add_child(light)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if homing_target != null:
		if not is_instance_valid(homing_target) or homing_target.is_queued_for_deletion():
			homing_target = _find_bounce_target()
			if homing_target == null:
				_finish_impact()
				return
		# Ricochet segments continually correct toward the locked enemy's
		# current centre, so strafing or moving targets cannot evade the chain.
		direction = (_enemy_aim_point(homing_target) - global_position).normalized()
	velocity = direction * speed
	var collision := move_and_collide(velocity * delta)
	rotate_x(delta * 5.0)
	rotate_y(delta * 7.0)
	if collision:
		var collider := collision.get_collider()
		if collider is Node and collider.is_in_group("enemies") and collider.has_method("take_damage"):
			_impact_enemy(collider)
		else:
			_finish_impact()

func _impact_enemy(primary_enemy: Node) -> void:
	homing_target = null
	_damage_enemy(primary_enemy)
	_damage_nearby_enemies()
	_spawn_burst()
	if bounces_left > 0:
		var next_enemy := _find_bounce_target()
		if is_instance_valid(next_enemy):
			bounces_left -= 1
			homing_target = next_enemy
			direction = (_enemy_aim_point(next_enemy) - global_position).normalized()
			# Clear the cube just hit so the redirected projectile cannot collide
			# with the same body again before beginning its next chain segment.
			var clearance: float = 1.0 * float(primary_enemy.scale.x) + 0.35
			global_position = _enemy_aim_point(primary_enemy) + direction * clearance
			lifetime = maxf(lifetime, 2.0)
			return
	queue_free()

func _finish_impact() -> void:
	_damage_nearby_enemies()
	_spawn_burst()
	queue_free()

func _damage_nearby_enemies() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = 4
	params.exclude = [self, owner_body]
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 64)
	for hit in hits:
		var enemy: Object = hit.collider
		if enemy is Node and enemy.is_in_group("enemies") and enemy.has_method("take_damage") and not already_hit.has(enemy.get_instance_id()):
			_damage_enemy(enemy)

func _damage_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy) or already_hit.has(enemy.get_instance_id()):
		return
	already_hit[enemy.get_instance_id()] = true
	var crit := randf() < crit_chance
	var dealt_damage := damage * (2.0 if crit else 1.0)
	enemy.take_damage(dealt_damage, crit, attack_id)
	damage_dealt.emit(dealt_damage)
	_spawn_damage_number(enemy.global_position + Vector3.UP * 1.55, dealt_damage, crit)

func _find_bounce_target() -> Node3D:
	var closest: Node3D
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if already_hit.has(candidate.get_instance_id()):
			continue
		var target_distance: float = global_position.distance_squared_to(candidate.global_position)
		if target_distance < closest_distance:
			closest = candidate
			closest_distance = target_distance
	return closest

func _enemy_aim_point(enemy: Node3D) -> Vector3:
	return enemy.global_position + Vector3.UP * 0.68 * enemy.scale.y

func _spawn_damage_number(world_position: Vector3, amount: float, is_crit: bool) -> void:
	var label := Label3D.new()
	label.add_to_group("damage_numbers")
	label.text = "%d%s" % [int(round(amount)), " Crit!" if is_crit else ""]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 42 if is_crit else 34
	label.pixel_size = 0.012
	label.modulate = Color("ffe269") if is_crit else Color.WHITE
	label.outline_modulate = Color("5b1607")
	label.outline_size = 10
	get_tree().current_scene.add_child(label)
	label.global_position = world_position
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", world_position + Vector3.UP * 1.1, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.72).set_delay(0.2)
	tween.tween_callback(label.queue_free)

func _spawn_burst() -> void:
	var burst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * explosion_radius * 1.6
	burst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.35, 0.05, 0.32)
	mat.emission_enabled = true
	mat.emission = Color("ff5a18")
	mat.emission_energy_multiplier = 2.5
	burst.material_override = mat
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	var tween := burst.create_tween()
	burst.scale = Vector3.ONE * 0.15
	tween.tween_property(burst, "scale", Vector3.ONE, 0.14)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(burst.queue_free)
