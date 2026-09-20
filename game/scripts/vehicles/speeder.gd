class_name Speeder
extends CharacterBody3D

@export var hover_height := 1.35
@export var acceleration := 30.0
@export var reverse_acceleration := 15.0
@export var max_speed := 44.0
@export var max_reverse_speed := 12.0
@export var yaw_rate := 1.65
@export var lateral_grip := 4.0

var driver: FPSController
var gravity := 18.0
var visual := Node3D.new()
var seat := Marker3D.new()
var hover_velocity := 0.0
var bank := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("planet_anchor")
	floor_max_angle = deg_to_rad(55.0)
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_body()

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.25, 0.55, 3.2)
	collision.shape = shape
	collision.position.y = 0.45
	add_child(collision)

	add_child(visual)
	var chassis := MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(1.05, 0.42, 3.0)
	chassis.mesh = chassis_mesh
	chassis.position.y = 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.19, 0.19)
	material.metallic = 0.7
	material.roughness = 0.34
	chassis.material_override = material
	visual.add_child(chassis)

	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.62, 0.28, 1.6)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 0.57, -1.75)
	nose.material_override = material
	visual.add_child(nose)

	seat.position = Vector3(0.0, 1.05, 0.15)
	add_child(seat)

func interact(player: FPSController) -> void:
	if driver == null:
		driver = player
		player.enter_vehicle(self)

func exit_driver(player: FPSController) -> void:
	if driver != player:
		return
	var exit_position := global_position + global_basis.x * 1.5 + Vector3.UP * 0.5
	driver = null
	player.leave_vehicle(exit_position)

func driver_transform() -> Transform3D:
	return seat.global_transform

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	if driver != null and is_instance_valid(driver):
		throttle = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		steer = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	var forward := -global_basis.z
	var right := global_basis.x
	var forward_speed := velocity.dot(forward)
	var lateral_speed := velocity.dot(right)

	if throttle > 0.0:
		forward_speed = move_toward(forward_speed, max_speed, acceleration * throttle * delta)
	elif throttle < 0.0:
		forward_speed = move_toward(forward_speed, -max_reverse_speed, reverse_acceleration * -throttle * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, 6.0 * delta)

	lateral_speed = move_toward(lateral_speed, 0.0, lateral_grip * delta * max(1.0, abs(lateral_speed)))
	var steering_authority := clamp(abs(forward_speed) / 9.0, 0.22, 1.0)
	if abs(steer) > 0.001:
		rotate_y(-steer * yaw_rate * steering_authority * delta * sign(forward_speed if abs(forward_speed) > 0.5 else 1.0))
		forward = -global_basis.z
		right = global_basis.x

	velocity.x = (forward * forward_speed + right * lateral_speed).x
	velocity.z = (forward * forward_speed + right * lateral_speed).z
	_update_hover(delta)

	move_and_slide()

	var target_bank := -steer * clamp(abs(forward_speed) / max_speed, 0.0, 1.0) * 0.28
	bank = lerpf(bank, target_bank, 1.0 - exp(-delta * 7.0))
	visual.rotation.z = bank
	visual.rotation.x = lerpf(visual.rotation.x, -throttle * 0.035, 1.0 - exp(-delta * 5.0))

func _update_hover(delta: float) -> void:
	var from := global_position + Vector3.UP * 2.2
	var to := global_position + Vector3.DOWN * 5.5
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		velocity.y -= gravity * delta
		return
	var ground_y := float((hit["position"] as Vector3).y)
	var current_height := global_position.y - ground_y
	var error := hover_height - current_height
	var spring_acceleration := error * 42.0 - velocity.y * 8.0
	velocity.y += spring_acceleration * delta
