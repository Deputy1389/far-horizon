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
var dead := false
var death_timer := 0.0
var death_roll := 1.0
var hit_stun := 0.0
var combat_action_timer := 0.0
var combat_move_mode := 0
var strafe_sign := 1.0
var burst_remaining := 0
var cover_target := Vector3.ZERO

var visual_root := Node3D.new()
var muzzle := Marker3D.new()
var animation_player: AnimationPlayer
var active_animation := ""
var fire_audio := AudioStreamPlayer3D.new()
var muzzle_flash_mesh := MeshInstance3D.new()
var muzzle_flash_light := OmniLight3D.new()
var muzzle_flash_time := 0.0

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
	_build_combat_fx()
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

	var weapon := SwgAssetBridge.instantiate_weapon("blasterRifle")
	if weapon != null:
		weapon.position = Vector3(0.22, 1.22, -0.30)
		weapon.rotation.x += deg_to_rad(-8.0)
		visual_root.add_child(weapon)

	muzzle.position = Vector3(0.23, 1.32, -0.62)
	add_child(muzzle)

func _build_combat_fx() -> void:
	fire_audio.stream = SwgAssetBridge.audio_for_role("blasterRifle")
	fire_audio.unit_size = 9.0
	fire_audio.max_distance = 95.0
	fire_audio.volume_db = -10.0
	add_child(fire_audio)

	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.045
	flash_mesh.height = 0.09
	flash_mesh.radial_segments = 6
	muzzle_flash_mesh.mesh = flash_mesh
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.18, 0.03)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.03, 0.01)
	flash_material.emission_energy_multiplier = 9.0
	muzzle_flash_mesh.material_override = flash_material
	muzzle_flash_mesh.visible = false
	muzzle.add_child(muzzle_flash_mesh)

	muzzle_flash_light.light_color = Color(1.0, 0.12, 0.02)
	muzzle_flash_light.light_energy = 1.6
	muzzle_flash_light.omni_range = 2.8
	muzzle_flash_light.visible = false
	muzzle.add_child(muzzle_flash_light)


func _physics_process(delta: float) -> void:
	muzzle_flash_time = maxf(0.0, muzzle_flash_time - delta)
	if muzzle_flash_time <= 0.0:
		muzzle_flash_mesh.visible = false
		muzzle_flash_light.visible = false

	if dead:
		_update_death(delta)
		return

	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	hit_stun = maxf(0.0, hit_stun - delta)
	perception_timer -= delta
	repath_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	if perception_timer <= 0.0:
		perception_timer = 0.14 + rng.randf_range(0.0, 0.08)
		_update_perception()

	if hit_stun > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 12.0 * delta)
	elif target != null and is_instance_valid(target):
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
	var distance: float = maxf(offset.length(), 0.001)
	var away := offset / distance
	var side := Vector3.UP.cross(away).normalized()

	combat_action_timer -= delta
	if combat_action_timer <= 0.0:
		combat_action_timer = rng.randf_range(0.75, 1.6)
		if health < maximum_health * 0.48 and rng.randf() < 0.55:
			cover_target = _find_cover_target()
			combat_move_mode = 4 if cover_target != Vector3.ZERO else rng.randi_range(0, 3)
		elif distance > preferred_distance + 12.0:
			combat_move_mode = 3
		else:
			combat_move_mode = rng.randi_range(0, 3)
		strafe_sign = -1.0 if rng.randf() < 0.5 else 1.0

	var desired := global_position
	match combat_move_mode:
		0:
			desired = global_position
		1:
			desired = global_position + side * 7.5 * strafe_sign
		2:
			desired = target_position + away * (preferred_distance + rng.randf_range(-3.0, 4.0)) + side * 5.0 * strafe_sign
		3:
			desired = target_position + away * maxf(11.0, preferred_distance - 5.0)
		_:
			desired = cover_target

	if squad_role == "flank_left":
		desired += side * 8.0
	elif squad_role == "flank_right":
		desired -= side * 8.0
	elif squad_role == "suppress":
		desired = target_position + away * (preferred_distance + 6.0)

	var move_direction := desired - global_position
	move_direction.y = 0.0
	if move_direction.length() > 1.4:
		move_direction = _avoid_obstacle(move_direction.normalized())
		var combat_speed := move_speed * (1.12 if distance > preferred_distance + 10.0 else 0.82)
		velocity.x = move_toward(velocity.x, move_direction.x * combat_speed, move_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * combat_speed, move_speed * 7.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 9.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 9.0 * delta)

	var face := target_position - global_position
	face.y = 0.0
	if face.length_squared() > 0.1:
		var desired_yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 10.0))

	if distance < engage_distance and fire_cooldown <= 0.0 and _has_line_of_sight(target):
		_fire_at_target(distance)

func _fire_at_target(distance: float) -> void:
	if burst_remaining <= 0:
		burst_remaining = rng.randi_range(2, 4)
	burst_remaining -= 1
	fire_cooldown = rng.randf_range(0.13, 0.22) if burst_remaining > 0 else rng.randf_range(0.72, 1.18)
	var aim_point := target.global_position + Vector3.UP * 1.05
	var direction := (aim_point - muzzle.global_position).normalized()
	var inaccuracy: float = lerpf(0.012, 0.032, clampf(distance / engage_distance, 0.0, 1.0))
	direction = (direction
		+ global_basis.x * rng.randf_range(-inaccuracy, inaccuracy)
		+ global_basis.y * rng.randf_range(-inaccuracy, inaccuracy)
	).normalized()
	var bolt := BlasterBolt.new()
	get_tree().current_scene.add_child(bolt)
	bolt.configure(muzzle.global_position, direction, 185.0, 16.0, self)
	muzzle_flash_time = 0.045
	muzzle_flash_mesh.visible = true
	muzzle_flash_light.visible = true
	if fire_audio.stream != null:
		fire_audio.stop()
		fire_audio.pitch_scale = rng.randf_range(0.94, 1.04)
		fire_audio.play()

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

func apply_damage(amount: float, _hit_position := Vector3.ZERO, direction := Vector3.ZERO, source = null) -> void:
	if dead:
		return
	if source is Node and (source as Node).is_in_group("enemy"):
		return
	health -= amount
	hit_stun = 0.11
	visual_root.rotation.x = deg_to_rad(-5.0)
	if source is Node3D:
		target = source
		squad_manager.alert_squad(squad_id, source)
	if health <= 0.0:
		_begin_death(direction)

func _begin_death(direction: Vector3) -> void:
	dead = true
	death_timer = 2.2
	death_roll = -1.0 if rng.randf() < 0.5 else 1.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if animation_player != null:
		animation_player.stop()
	squad_manager.member_died(self, squad_id)
	killed.emit(self)

func _update_death(delta: float) -> void:
	death_timer -= delta
	visual_root.rotation.z = lerpf(visual_root.rotation.z, death_roll * 1.28, 1.0 - exp(-delta * 7.0))
	visual_root.rotation.x = lerpf(visual_root.rotation.x, deg_to_rad(12.0), 1.0 - exp(-delta * 5.0))
	visual_root.position.y = lerpf(visual_root.position.y, -0.22, 1.0 - exp(-delta * 5.0))
	if death_timer <= 0.0:
		queue_free()

func _find_cover_target() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("combat_cover"):
		if not candidate is Node3D:
			continue
		var cover := candidate as Node3D
		var distance := global_position.distance_to(cover.global_position)
		if distance < 2.5 or distance > 22.0:
			continue
		var from_player := cover.global_position - target.global_position
		from_player.y = 0.0
		if from_player.length_squared() < 0.01:
			continue
		var hide_position := cover.global_position + from_player.normalized() * 1.4
		var score := distance + target.global_position.distance_to(hide_position) * 0.04
		if score < best_score:
			best_score = score
			best = hide_position
	return best


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
	visual_root.rotation.x = lerpf(visual_root.rotation.x, 0.0, 0.22)
	if animation_player == null:
		return
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed < 0.25:
		_set_animation("idle")
		animation_player.speed_scale = 1.0
	elif target != null and is_instance_valid(target):
		_set_animation("run")
		animation_player.speed_scale = clampf(planar_speed / maxf(move_speed, 0.1), 0.8, 1.25)
	else:
		_set_animation("walk")
		animation_player.speed_scale = clampf(planar_speed / maxf(move_speed * 0.55, 0.1), 0.75, 1.2)

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
	var clip := animation_player.get_animation(selected)
	if clip != null:
		clip.loop_mode = Animation.LOOP_LINEAR
	active_animation = requested
	animation_player.play(selected, 0.12)
	if clip != null and clip.length > 0.2:
		# Desynchronize squads so they do not all march in the same frame.
		animation_player.seek(rng.randf_range(0.0, clip.length), true)
