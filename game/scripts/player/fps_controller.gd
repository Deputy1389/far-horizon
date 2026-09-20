class_name FPSController
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal damaged(amount: float)
signal stance_changed(stance: String)

const STAND := "stand"
const CROUCH := "crouch"
const PRONE := "prone"

@export var walk_speed := 6.2
@export var sprint_speed := 10.5
@export var crouch_speed := 3.4
@export var prone_speed := 1.65
@export var ground_acceleration := 34.0
@export var ground_deceleration := 40.0
@export var air_acceleration := 5.5
@export var jump_velocity := 6.2
@export var jump_buffer_window := 0.12
@export var mouse_sensitivity := 0.00175
@export var step_height := 0.42
@export var mantle_reach := 0.95
@export var mantle_height := 1.45

var maximum_health := 100.0
var health := 100.0
var stance := STAND
var pitch := 0.0
var gravity := 18.0
var coyote_time := 0.0
var jump_cooldown := 0.0
var jump_buffer := 0.0
var mantle_active := false
var mantle_elapsed := 0.0
var mantle_duration := 0.2
var mantle_start := Vector3.ZERO
var mantle_end := Vector3.ZERO
var active_vehicle: Node3D
var vehicle_look_yaw := 0.0

var stand_collision := CollisionShape3D.new()
var crouch_collision := CollisionShape3D.new()
var prone_collision := CollisionShape3D.new()
var head := Node3D.new()
var camera := Camera3D.new()
var weapons := WeaponController.new()

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_snap_length = 0.38
	floor_max_angle = deg_to_rad(50.0)
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_collision()
	_build_camera()
	weapons.configure(camera, self)
	add_child(weapons)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, maximum_health)

func _build_collision() -> void:
	var stand_shape := CapsuleShape3D.new()
	stand_shape.radius = 0.35
	stand_shape.height = 1.8
	stand_collision.shape = stand_shape
	stand_collision.position.y = 0.9
	add_child(stand_collision)

	var crouch_shape := CapsuleShape3D.new()
	crouch_shape.radius = 0.35
	crouch_shape.height = 1.18
	crouch_collision.shape = crouch_shape
	crouch_collision.position.y = 0.59
	crouch_collision.disabled = true
	add_child(crouch_collision)

	var prone_shape := BoxShape3D.new()
	prone_shape.size = Vector3(0.7, 0.5, 1.55)
	prone_collision.shape = prone_shape
	prone_collision.position = Vector3(0.0, 0.25, -0.2)
	prone_collision.disabled = true
	add_child(prone_collision)

func _build_camera() -> void:
	head.position.y = 1.62
	add_child(head)
	camera.fov = 80.0
	camera.near = 0.05
	camera.current = true
	head.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse := event as InputEventMouseMotion
		if active_vehicle != null and is_instance_valid(active_vehicle):
			vehicle_look_yaw = clamp(vehicle_look_yaw - mouse.relative.x * mouse_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))
			head.rotation.y = vehicle_look_yaw
		else:
			rotate_y(-mouse.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - mouse.relative.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
		head.rotation.x = pitch
	elif event.is_action_pressed("pause_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)

	if active_vehicle != null and is_instance_valid(active_vehicle):
		_update_vehicle_mode()
		if Input.is_action_just_pressed("interact") and active_vehicle.has_method("exit_driver"):
			active_vehicle.exit_driver(self)
		return

	if mantle_active:
		_update_mantle(delta)
		return

	if Input.is_action_just_pressed("crouch"):
		if stance == PRONE:
			_request_stance(CROUCH)
		elif stance == CROUCH:
			_request_stance(STAND)
		else:
			_request_stance(CROUCH)

	if Input.is_action_just_pressed("prone"):
		_request_stance(STAND if stance == PRONE else PRONE)

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_direction := (global_basis * Vector3(input_vector.x, 0.0, input_vector.y))
	wish_direction.y = 0.0
	wish_direction = wish_direction.normalized()

	var sprinting := (
		stance == STAND
		and Input.is_action_pressed("sprint")
		and input_vector.y < -0.15
		and not weapons.is_aiming()
		and not Input.is_action_pressed("fire")
	)
	var target_speed := _stance_speed(sprinting)
	if weapons.is_aiming():
		target_speed *= 0.76
	var target_velocity := wish_direction * target_speed
	var grounded := is_on_floor()

	if grounded:
		coyote_time = 0.11
	else:
		coyote_time = maxf(0.0, coyote_time - delta)
		velocity.y -= gravity * delta

	var acceleration := ground_acceleration if grounded else air_acceleration
	if grounded and wish_direction.is_zero_approx():
		acceleration = ground_deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if Input.is_action_just_pressed("jump"):
		if _try_begin_mantle():
			return
		jump_buffer = jump_buffer_window

	if jump_buffer > 0.0 and (grounded or coyote_time > 0.0):
		if jump_cooldown <= 0.0 and stance != PRONE:
			velocity.y = jump_velocity
			jump_cooldown = 0.2
			jump_buffer = 0.0
			coyote_time = 0.0

	_try_step(delta)
	move_and_slide()

	var target_head_height := 1.62
	if stance == CROUCH:
		target_head_height = 1.02
	elif stance == PRONE:
		target_head_height = 0.48
	head.position.y = lerpf(head.position.y, target_head_height, 1.0 - exp(-delta * 14.0))

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _stance_speed(sprinting: bool) -> float:
	if stance == PRONE:
		return prone_speed
	if stance == CROUCH:
		return crouch_speed
	return sprint_speed if sprinting else walk_speed

func _request_stance(next_stance: String) -> void:
	if next_stance == stance:
		return
	if next_stance == STAND and not _shape_clear(stand_collision.shape, stand_collision.position):
		return
	if next_stance == CROUCH and not _shape_clear(crouch_collision.shape, crouch_collision.position):
		return

	stance = next_stance
	stand_collision.disabled = stance != STAND
	crouch_collision.disabled = stance != CROUCH
	prone_collision.disabled = stance != PRONE
	stance_changed.emit(stance)

func _shape_clear(shape: Shape3D, local_offset: Vector3) -> bool:
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = shape
	parameters.transform = Transform3D(global_basis, global_position + global_basis * local_offset)
	parameters.exclude = [get_rid()]
	parameters.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(parameters, 1).is_empty()

func _try_step(delta: float) -> void:
	if not is_on_floor() or velocity.length_squared() < 0.01:
		return
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if horizontal_motion.length() < 0.001:
		return
	if not test_move(global_transform, horizontal_motion):
		return

	var up_motion := Vector3.UP * step_height
	if test_move(global_transform, up_motion):
		return
	var raised := global_transform
	raised.origin += up_motion
	if test_move(raised, horizontal_motion):
		return
	global_position += up_motion

func _try_begin_mantle() -> bool:
	if stance == PRONE:
		return false
	var forward := -global_basis.z
	var space := get_world_3d().direct_space_state
	var low_from := global_position + Vector3.UP * 0.78
	var low_query := PhysicsRayQueryParameters3D.create(low_from, low_from + forward * mantle_reach)
	low_query.exclude = [get_rid()]
	var wall_hit := space.intersect_ray(low_query)
	if wall_hit.is_empty():
		return false

	var high_from := global_position + Vector3.UP * (mantle_height + 0.45)
	var high_query := PhysicsRayQueryParameters3D.create(high_from, high_from + forward * (mantle_reach + 0.15))
	high_query.exclude = [get_rid()]
	if not space.intersect_ray(high_query).is_empty():
		return false

	var ledge_probe: Vector3 = (wall_hit["position"] as Vector3) + forward * 0.42 + Vector3.UP * (mantle_height + 0.55)
	var down_query := PhysicsRayQueryParameters3D.create(ledge_probe, ledge_probe + Vector3.DOWN * (mantle_height + 0.8))
	down_query.exclude = [get_rid()]
	var top_hit := space.intersect_ray(down_query)
	if top_hit.is_empty() or (top_hit["normal"] as Vector3).dot(Vector3.UP) < 0.65:
		return false

	var ledge_height := float((top_hit["position"] as Vector3).y - global_position.y)
	if ledge_height < 0.35 or ledge_height > mantle_height:
		return false

	mantle_active = true
	mantle_elapsed = 0.0
	mantle_start = global_position
	mantle_end = (top_hit["position"] as Vector3) + forward * 0.45 + Vector3.UP * 0.04
	velocity = Vector3.ZERO
	return true

func _update_mantle(delta: float) -> void:
	mantle_elapsed += delta
	var t: float = clampf(mantle_elapsed / mantle_duration, 0.0, 1.0)
	var smooth: float = t * t * (3.0 - 2.0 * t)
	global_position = mantle_start.lerp(mantle_end, smooth)
	if t >= 1.0:
		mantle_active = false
		velocity = Vector3.ZERO

func _try_interact() -> void:
	var nearest: Node3D
	var nearest_distance := 4.0
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate is Node3D:
			continue
		var node := candidate as Node3D
		var distance := global_position.distance_to(node.global_position)
		if distance < nearest_distance and node.has_method("interact"):
			nearest = node
			nearest_distance = distance
	if nearest != null:
		nearest.interact(self)

func enter_vehicle(vehicle: Node3D) -> void:
	active_vehicle = vehicle
	vehicle_look_yaw = 0.0
	head.rotation.y = 0.0
	stand_collision.disabled = true
	crouch_collision.disabled = true
	prone_collision.disabled = true
	collision_layer = 0
	weapons.set_enabled(false)
	velocity = Vector3.ZERO

func leave_vehicle(exit_position: Vector3) -> void:
	active_vehicle = null
	vehicle_look_yaw = 0.0
	head.rotation.y = 0.0
	global_position = exit_position
	collision_layer = 1
	_request_stance(STAND)
	stand_collision.disabled = false
	weapons.set_enabled(true)

func _update_vehicle_mode() -> void:
	if active_vehicle.has_method("driver_transform"):
		var seat: Transform3D = active_vehicle.driver_transform()
		global_position = seat.origin
		rotation.y = active_vehicle.global_rotation.y
		head.position.y = lerpf(head.position.y, 0.12, 0.35)

func add_recoil(pitch_degrees: float, yaw_degrees: float) -> void:
	pitch = clampf(pitch - deg_to_rad(pitch_degrees), deg_to_rad(-88.0), deg_to_rad(88.0))
	head.rotation.x = pitch
	rotate_y(deg_to_rad(yaw_degrees))

func apply_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO, _source = null) -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health, maximum_health)
	damaged.emit(amount)
	if health <= 0.0:
		died.emit()

func restore_full_health() -> void:
	health = maximum_health
	health_changed.emit(health, maximum_health)
