class_name StrategicConvoyProxy
extends AnimatableBody3D

var strategy: StrategicSim
var force_id := ""
var faction := "imperial"
var strength := 0.0
var target_position := Vector3.ZERO
var initialized := false

func configure(sim: StrategicSim, id: String, faction_name: String, initial_strength: float, local_position: Vector3) -> void:
	strategy = sim
	force_id = id
	faction = faction_name
	strength = initial_strength
	global_position = local_position
	target_position = local_position
	initialized = true
	add_to_group("planet_anchor")
	_build_visual()

func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.3, 5.0)
	collision.shape = box
	collision.position.y = 1.0
	add_child(collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.14, 0.15) if faction == "imperial" else Color(0.28, 0.22, 0.16)
	material.metallic = 0.58
	material.roughness = 0.42

	for index in range(3):
		var vehicle := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.1, 0.9, 4.3)
		vehicle.mesh = mesh
		vehicle.position = Vector3(0.0, 1.0, float(index - 1) * 6.5)
		vehicle.material_override = material
		add_child(vehicle)

func set_target(local_position: Vector3, current_strength: float) -> void:
	target_position = local_position
	strength = current_strength

func _physics_process(delta: float) -> void:
	if not initialized:
		return
	var previous := global_position
	global_position = global_position.lerp(target_position, 1.0 - exp(-delta * 5.0))
	var movement := global_position - previous
	movement.y = 0.0
	if movement.length_squared() > 0.001:
		var yaw := atan2(-movement.x, -movement.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 7.0))

func apply_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO, _source = null) -> void:
	if strategy == null:
		return
	strength = strategy.damage_force(force_id, amount)
	if strength <= 0.0:
		queue_free()
