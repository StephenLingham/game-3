extends Node3D

const PULL_RADIUS := 200.0
const PULL_FORCE := 38.0
const TRAVEL_SPEED := 24.0
const TRAVEL_TIME := 0.65
const ACTIVE_TIME := 5.0

var direction := Vector3.FORWARD
var travel_timer := TRAVEL_TIME
var life_timer := ACTIVE_TIME

func setup(fire_direction: Vector3) -> void:
	direction = fire_direction.normalized()

func _ready() -> void:
	add_to_group("vortices")
	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.35
	sphere_mesh.height = 2.7
	sphere.mesh = sphere_mesh
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("030208")
	black.metallic = 0.75
	black.roughness = 0.18
	black.emission_enabled = true
	black.emission = Color("17072b")
	black.emission_energy_multiplier = 1.8
	sphere.material_override = black
	add_child(sphere)

	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.55
	halo_mesh.outer_radius = 1.78
	halo.mesh = halo_mesh
	halo.rotation_degrees.x = 72.0
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color("873dff")
	halo_mat.emission_enabled = true
	halo_mat.emission = Color("873dff")
	halo_mat.emission_energy_multiplier = 3.0
	halo.material_override = halo_mat
	add_child(halo)

	var light := OmniLight3D.new()
	light.light_color = Color("6e32c9")
	light.light_energy = 4.0
	light.omni_range = 9.0
	add_child(light)

func _physics_process(delta: float) -> void:
	life_timer -= delta
	travel_timer -= delta
	if travel_timer > 0.0:
		global_position += direction * TRAVEL_SPEED * delta
	rotate_y(delta * 4.5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("pull_toward"):
			continue
		var distance: float = enemy.global_position.distance_to(global_position)
		if distance < PULL_RADIUS:
			enemy.pull_toward(global_position, PULL_FORCE, delta, self)
	if life_timer <= 0.0:
		queue_free()

func _exit_tree() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("release_vortex"):
			enemy.release_vortex(self)
