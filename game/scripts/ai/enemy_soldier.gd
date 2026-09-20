class_name EnemySoldier
extends CharacterBody3D

signal killed(soldier: EnemySoldier)

@export var maximum_health := 100.0
@export var move_speed := 4.8
@export var engage_distance := 62.0
@export var preferred_distance := 22.0

var health := 100.0
var target: Node3D
var player: Node3D
var squad_manager: SquadManager
var squad_id := "alpha"
var squad_role := "advance"
var patrol_origin := Vector3.ZERO
var patrol_target := Vector3.ZERO
var perception_timer := 0.0
var fire_cooldown := 0.0
var repath_timer := 0.0
var rng := RandomNumberGenerator.new()
var gravity := 18.0

var visual_root := Node3D.new()
var muzzle := Marker3D.new()
var animation_player: AnimationPlayer
var active_animation := ""

func configure(player_ref: Node3D, manager: SquadManager, id: String, spawn_position: Vector3) -> void:
	player = player_ref
	squad_manager = manager
	squad_id = id
	patrol_origin = spawn_position
	global_position = spawn_position
	rng.seed = hash("%s:%s" % [id, str(spawn_position)])
	squad_role = squad_manager.register_member(self, squad_id)
	_choose_patrol_target()

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("planet_anchor")
	health = maximum_health
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	floor_snap_length = 0.32
	floor_max_angle = deg_to_rad(50.0)
	_build_collision()
	_build_visual()
	_choose_patrol_target()

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

func _build_visual() -> void:
	add_child(visual_root)
	var imported := SwgAssetBridge.instantiate_stormtrooper()
	if imported != null:
		visual_root.add_child(imported)
		var animation_players := imported.find_children("*", "AnimationPlayer", true, false)
		if not animation_players.is_empty():
			animation_player = animation_players[0] as AnimationPlayer
			_set_animation("idle")
	else:
		var mesh_instance := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		mesh_instance.mesh = capsule
		mesh_instance.position.y = 0.9
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.84, 0.84)
		material.roughness = 0.55
		mesh_instance.material_override = material
		visual_root.add_child(mesh_instance)

	muzzle.position = Vector3(0.23, 1.32, -0.55)
	add_child(muzzle)

func _physics_process(delta: float) -> void:
	fire_cooldown = max(0.0, fire_cooldown - delta)
	perception_timer -= delta
	repath_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	if perception_timer <= 0.0:
		perception_timer = 0.14 + rng.randf_range(0.0, 0.08)
		_update_perception()

	if target != null and is_instance_valid(target):
		_combat_update(delta)
	else:
		_patrol_update(delta)

	move_and_slide()
	_update_animation()

func _update_perception() -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position + Vector3.UP - (global_position + Vector3.UP * 1.35)
	var distance := to_player.length()
	if distance > engage_distance:
		return
	var forward := -global_basis.z
	if distance > 13.0 and forward.dot(to_player.normalized()) < -0.2:
		return
	if _has_line_of_sight(player):
		target = player
		squad_manager.alert_squad(squad_id, player)

func _has_line_of_sight(candidate: Node3D) -> bool:
	var from := global_position + Vector3.UP * 1.35
	var to := candidate.global_position + Vector3.UP * 1.05
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == candidate

func _combat_update(delta: float) -> void:
	var target_position := target.global_position
	var offset := global_position - target_position
	offset.y = 0.0
	var distance := max(offset.length(), 0.001)
	var away := offset / distance
	var side := Vector3.UP.cross(away).normalized()
	var desired := target_position + away * preferred_distance

	if squad_role == "flank_left":
		desired += side * 13.0
	elif squad_role == "flank_right":
		desired -= side * 13.0
	elif squad_role == "advance":
		desired = target_position + away * max(12.0, preferred_distance - 6.0)
	elif squad_role == "suppress":
		desired = target_position + away * (preferred_distance + 5.0)

	var move_direction := desired - global_position
	move_direction.y = 0.0
	if move_direction.length() > 2.0:
		move_direction = _avoid_obstacle(move_direction.normalized())
		velocity.x = move_toward(velocity.x, move_direction.x * move_speed, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * move_speed, move_speed * 5.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 7.0 * delta)

	var face := target_position - global_position
	face.y = 0.0
	if face.length_squared() > 0.1:
		var desired_yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 8.0))

	if distance < engage_distance and fire_cooldown <= 0.0 and _has_line_of_sight(target):
		_fire_at_target(distance)

func _fire_at_target(distance: float) -> void:
	fire_cooldown = rng.randf_range(0.42, 0.72)
	var aim_point := target.global_position + Vector3.UP * 1.05
	var direction := (aim_point - muzzle.global_position).normalized()
	var inaccuracy := lerpf(0.012, 0.032, clamp(distance / engage_distance, 0.0, 1.0))
	direction = (direction
		+ global_basis.x * rng.randf_range(-inaccuracy, inaccuracy)
		+ global_basis.y * rng.randf_range(-inaccuracy, inaccuracy)
	).normalized()
	var bolt := BlasterBolt.new()
	get_tree().current_scene.add_child(bolt)
	bolt.configure(muzzle.global_position, direction, 185.0, 16.0, self)

func _patrol_update(delta: float) -> void:
	var delta_to_target := patrol_target - global_position
	delta_to_target.y = 0.0
	if delta_to_target.length() < 1.6:
		_choose_patrol_target()
		return
	var direction := _avoid_obstacle(delta_to_target.normalized())
	velocity.x = move_toward(velocity.x, direction.x * move_speed * 0.55, move_speed * 3.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed * 0.55, move_speed * 3.0 * delta)
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 5.0))

func _choose_patrol_target() -> void:
	patrol_target = patrol_origin + Vector3(
		rng.randf_range(-12.0, 12.0),
		0.0,
		rng.randf_range(-12.0, 12.0)
	)

func receive_squad_alert(new_target: Node3D) -> void:
	target = new_target

func apply_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO, source = null) -> void:
	health -= amount
	if source is Node3D:
		target = source
		squad_manager.alert_squad(squad_id, source)
	if health <= 0.0:
		squad_manager.member_died(self, squad_id)
		killed.emit(self)
		queue_free()

func _avoid_obstacle(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.001:
		return direction
	var from := global_position + Vector3.UP * 0.85
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 1.55)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direction
	var side := Vector3.UP.cross(direction).normalized()
	if squad_role == "flank_right":
		side = -side
	elif squad_role == "suppress" and rng.randf() > 0.5:
		side = -side
	return (direction * 0.35 + side).normalized()

func _update_animation() -> void:
	if animation_player == null:
		return
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed < 0.25:
		_set_animation("idle")
	elif target != null and is_instance_valid(target):
		_set_animation("run")
	else:
		_set_animation("walk")

func _set_animation(requested: String) -> void:
	if animation_player == null or active_animation == requested:
		return
	var selected := requested
	if not animation_player.has_animation(selected):
		for candidate in animation_player.get_animation_list():
			if String(candidate).to_lower().contains(requested):
				selected = String(candidate)
				break
	if not animation_player.has_animation(selected):
		return
	active_animation = requested
	animation_player.play(selected, 0.15)
