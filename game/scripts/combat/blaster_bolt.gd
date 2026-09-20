class_name BlasterBolt
extends Node3D

signal damaged_target

var velocity := Vector3.ZERO
var damage := 25.0
var lifetime := 3.0
var source: CollisionObject3D

func configure(origin: Vector3, direction: Vector3, speed: float, amount: float, owner_body: CollisionObject3D = null) -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	damage = amount
	source = owner_body
	_build_visual()
	look_at(global_position + velocity.normalized(), Vector3.UP)

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	mesh.height = 0.75
	mesh.radial_segments = 6
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.08, 0.025, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.015, 0.005, 1.0)
	material.emission_energy_multiplier = 7.0
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if source != null and is_instance_valid(source):
		query.exclude = [source.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_spawn_impact(hit["position"] as Vector3, hit["normal"] as Vector3)
		var collider: Variant = hit.get("collider")
		if collider != null and collider.has_method("apply_damage"):
			collider.apply_damage(damage, hit["position"], velocity.normalized(), source)
			damaged_target.emit()
		queue_free()
		return

	global_position = to


func _spawn_impact(position: Vector3, normal: Vector3) -> void:
	var impact := Node3D.new()
	get_tree().current_scene.add_child(impact)
	impact.global_position = position + normal * 0.025

	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	spark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.45, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.09, 0.01)
	material.emission_energy_multiplier = 12.0
	spark.material_override = material
	impact.add_child(spark)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.18, 0.03)
	light.light_energy = 1.8
	light.omni_range = 2.2
	impact.add_child(light)

	var timer := get_tree().create_timer(0.075)
	timer.timeout.connect(impact.queue_free)
