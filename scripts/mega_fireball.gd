extends Node3D

const SPEED := 28.0
const LIFETIME := 4.0
const KILL_RADIUS := 1.65

var direction := Vector3.FORWARD
var lifetime := LIFETIME
var already_hit := {}
var attack_id := -1

func setup(fire_direction: Vector3, source_attack_id := -1) -> void:
	direction = fire_direction.normalized()
	attack_id = source_attack_id

func _ready() -> void:
	add_to_group("mega_fireballs")
	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.45
	sphere_mesh.height = 2.9
	sphere.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff7b18")
	mat.emission_enabled = true
	mat.emission = Color("ff2d05")
	mat.emission_energy_multiplier = 5.5
	sphere.material_override = mat
	add_child(sphere)

	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 1.75
	halo_mesh.height = 3.5
	halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(1.0, 0.25, 0.02, 0.22)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color("ff681f")
	halo_mat.emission_energy_multiplier = 3.0
	halo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	halo.material_override = halo_mat
	add_child(halo)

	var light := OmniLight3D.new()
	light.light_color = Color("ff551b")
	light.light_energy = 8.0
	light.omni_range = 11.0
	add_child(light)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position += direction * SPEED * delta
	rotate_x(delta * 3.0)
	rotate_y(delta * 4.5)
	var shape := SphereShape3D.new()
	shape.radius = KILL_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 4
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var enemy: Node = hit.collider
		if not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
			continue
		var enemy_id := enemy.get_instance_id()
		if already_hit.has(enemy_id):
			continue
		already_hit[enemy_id] = true
		if enemy.has_method("defeat"):
			enemy.defeat(attack_id, enemy.health)
