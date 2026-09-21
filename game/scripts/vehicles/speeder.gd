class_name Speeder
extends CharacterBody3D

@export var hover_height := 1.35
@export var acceleration := 34.0
@export var reverse_acceleration := 20.0
@export var max_speed := 38.0
@export var max_reverse_speed := 10.0
@export var yaw_rate := 2.55
@export var lateral_grip := 9.0

var driver: FPSController
var gravity := 18.0
var visual := Node3D.new()
var seat := Marker3D.new()
var engine_audio := AudioStreamPlayer3D.new()
var hover_velocity := 0.0
var bank := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("planet_anchor")
	floor_max_angle = deg_to_rad(55.0)
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_body()
	_setup_audio()

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

func _setup_audio() -> void:
	engine_audio.stream = SwgAssetBridge.audio_for_role("speederLoop")
	engine_audio.unit_size = 8.0
	engine_audio.max_distance = 90.0
	engine_audio.volume_db = -14.0
	engine_audio.finished.connect(_on_engine_audio_finished)
	add_child(engine_audio)

func _on_engine_audio_finished() -> void:
	if driver != null and is_instance_valid(driver) and engine_audio.stream != null:
		engine_audio.play()

func interaction_text() -> String:
	if driver == null:
		return "E  ENTER SPEEDER"
	return "E  EXIT SPEEDER" if driver.is_in_group("player") else ""

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
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := horizontal_velocity.dot(forward)

	if throttle > 0.0:
		forward_speed = move_toward(forward_speed, max_speed, acceleration * throttle * delta)
	elif throttle < 0.0:
		forward_speed = move_toward(forward_speed, -max_reverse_speed, reverse_acceleration * -throttle * delta)
	else:
		# Hover bikes should coast a little instead of feeling like a car with
		# strong engine braking.
		forward_speed = move_toward(forward_speed, 0.0, 4.0 * delta)

	var speed_ratio := clampf(absf(forward_speed) / maxf(max_speed, 0.1), 0.0, 1.0)
	if absf(steer) > 0.001:
		# Keep substantial authority at speed and even allow useful low-speed
		# pivoting. The previous setup reduced yaw while preserving old velocity,
		# which made the bike feel like a boat.
		var steering_authority := lerpf(1.15, 0.72, speed_ratio)
		var drive_sign := signf(forward_speed) if absf(forward_speed) > 0.4 else 1.0
		rotate_y(-steer * yaw_rate * steering_authority * delta * drive_sign)

	forward = -global_basis.z
	right = global_basis.x

	# Rapidly realign momentum toward the bike's new heading while retaining a
	# small amount of hovercraft drift. This is the core arcade handling change.
	var desired_horizontal := forward * forward_speed
	var grip_blend := 1.0 - exp(-lateral_grip * delta)
	horizontal_velocity = horizontal_velocity.lerp(desired_horizontal, grip_blend)
	if absf(forward_speed) < 0.2 and absf(throttle) < 0.01:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * delta))

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	_update_hover(delta)
	move_and_slide()

	_update_engine_audio(speed_ratio)
	var target_bank: float = -steer * speed_ratio * 0.22
	bank = lerpf(bank, target_bank, 1.0 - exp(-delta * 8.5))
	visual.rotation.z = bank
	var terrain_pitch := _terrain_pitch()
	var target_pitch := terrain_pitch - throttle * 0.028
	visual.rotation.x = lerpf(visual.rotation.x, target_pitch, 1.0 - exp(-delta * 7.0))

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


func _terrain_pitch() -> float:
	var forward := -global_basis.z
	var front_height := _ground_height(global_position + forward * 1.25)
	var rear_height := _ground_height(global_position - forward * 1.25)
	if is_nan(front_height) or is_nan(rear_height):
		return 0.0
	return clampf(atan2(front_height - rear_height, 2.5), deg_to_rad(-18.0), deg_to_rad(18.0))

func _ground_height(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.5, point + Vector3.DOWN * 7.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return float((hit["position"] as Vector3).y)


func _update_engine_audio(speed_ratio: float) -> void:
	if engine_audio.stream == null:
		return
	if driver == null or not is_instance_valid(driver):
		if engine_audio.playing:
			engine_audio.stop()
		return
	if not engine_audio.playing:
		engine_audio.play()
	engine_audio.pitch_scale = lerpf(0.78, 1.22, speed_ratio)
	engine_audio.volume_db = lerpf(-15.0, -5.0, speed_ratio)
