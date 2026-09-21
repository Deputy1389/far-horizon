class_name EnemySoldier
extends CharacterBody3D

signal killed(soldier: EnemySoldier)

@export var maximum_health := 100.0
@export var move_speed := 3.35
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
var reaction_timer := 0.0
var lost_sight_timer := 0.0
var last_seen_position := Vector3.ZERO
var aim_settle_timer := 0.0
var under_fire_timer := 0.0
var post_burst_reposition_timer := 0.0
var flank_commit_timer := 0.0
var fire_animation_timer := 0.0

var visual_root := Node3D.new()
var muzzle := Marker3D.new()
var animation_player: AnimationPlayer
var active_animation := ""
var animation_phase_seeded: Dictionary = {}
var character_skeleton: Skeleton3D
var weapon_hold_bone := -1
var fallback_wrist_bone := -1
var weapon_mount := Node3D.new()
var weapon_visual: Node3D
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
	visual_root.add_child(weapon_mount)
	weapon_mount.name = "WeaponMount"

	var imported := SwgAssetBridge.instantiate_stormtrooper()
	if imported != null:
		visual_root.add_child(imported)
		var animation_players := imported.find_children("*", "AnimationPlayer", true, false)
		if not animation_players.is_empty():
			animation_player = animation_players[0] as AnimationPlayer
			_set_animation("idle")

		var skeletons := imported.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			character_skeleton = skeletons[0] as Skeleton3D
			# SWG equips held weapons into the skeleton's hold_r slot. Using mesh
			# hardpoints or inferring a transform from both wrists produces the
			# twisted/sideways rifle pose seen in the prototype.
			weapon_hold_bone = _find_bone(character_skeleton, ["hold_r"])
			fallback_wrist_bone = _find_bone(character_skeleton, ["rwrist", "r_wrist", "rhand", "r_hand"])
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

	weapon_visual = SwgAssetBridge.instantiate_weapon("blasterRifle", false)
	if weapon_visual != null:
		weapon_mount.add_child(weapon_visual)
		weapon_visual.position = Vector3.ZERO
		weapon_visual.rotation = Vector3.ZERO

	muzzle.position = Vector3(0.23, 1.32, -0.62)
	add_child(muzzle)
	_update_weapon_mount()


func _find_bone(skeleton: Skeleton3D, candidates: Array[String]) -> int:
	for candidate in candidates:
		var index := skeleton.find_bone(candidate)
		if index >= 0:
			return index
	# Restoration/SWG names are generally compact (rwrist/lwrist), but keep a
	# case-insensitive fallback for converted variants.
	for index in range(skeleton.get_bone_count()):
		var actual := skeleton.get_bone_name(index).to_lower()
		for candidate in candidates:
			if actual == candidate.to_lower():
				return index
	return -1


func _bone_world_transform(bone_index: int) -> Transform3D:
	if character_skeleton == null or bone_index < 0:
		return Transform3D.IDENTITY
	return character_skeleton.global_transform * character_skeleton.get_bone_global_pose(bone_index)


func _update_weapon_mount() -> void:
	if weapon_visual == null or not is_instance_valid(weapon_visual):
		return

	var attachment_bone := weapon_hold_bone if weapon_hold_bone >= 0 else fallback_wrist_bone
	if character_skeleton != null and attachment_bone >= 0:
		weapon_mount.global_transform = _bone_world_transform(attachment_bone)
	else:
		weapon_mount.position = Vector3(0.22, 1.22, -0.30)
		weapon_mount.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)

	# Projectile direction is still solved against the target, so this transform
	# only governs the visible rifle/muzzle presentation.
	var barrel_forward := -weapon_mount.global_basis.z.normalized()
	muzzle.global_position = weapon_mount.global_position + barrel_forward * 0.64
	muzzle.global_basis = weapon_mount.global_basis.orthonormalized()


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
		_update_weapon_mount()
		return

	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	hit_stun = maxf(0.0, hit_stun - delta)
	under_fire_timer = maxf(0.0, under_fire_timer - delta)
	post_burst_reposition_timer = maxf(0.0, post_burst_reposition_timer - delta)
	flank_commit_timer = maxf(0.0, flank_commit_timer - delta)
	fire_animation_timer = maxf(0.0, fire_animation_timer - delta)
	reaction_timer = maxf(0.0, reaction_timer - delta)
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
	_update_animation(delta)
	_update_weapon_mount()

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
		if target == null or not is_instance_valid(target):
			reaction_timer = rng.randf_range(0.28, 0.52)
		target = player
		last_seen_position = player.global_position
		lost_sight_timer = 0.0
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
	var has_los := _has_line_of_sight(target)

	if has_los:
		last_seen_position = target_position
		lost_sight_timer = 0.0
	else:
		lost_sight_timer += delta

	combat_action_timer -= delta

	# Shooter-first behavior: when a trooper has a clean shot at useful range,
	# its default action is to STOP, AIM, and FIRE. Movement is a short action
	# between bursts, not a permanent state. This avoids the old "sprint at the
	# player forever and never become settled enough to shoot" failure mode.
	var useful_firing_range := has_los and distance >= 8.0 and distance <= 50.0
	if burst_remaining > 0 and useful_firing_range:
		combat_move_mode = 0
	elif combat_action_timer <= 0.0:
		squad_manager.release_cover(self)
		strafe_sign = -1.0 if rng.randf() < 0.5 else 1.0

		if not has_los:
			combat_move_mode = 5
			combat_action_timer = rng.randf_range(0.9, 1.4)
		elif distance < 8.0:
			combat_move_mode = 6
			combat_action_timer = rng.randf_range(0.55, 0.9)
		elif under_fire_timer > 0.0:
			cover_target = _find_cover_target()
			if cover_target != Vector3.ZERO:
				combat_move_mode = 4
				combat_action_timer = rng.randf_range(0.7, 1.15)
			else:
				# If there is no meaningful cover, return fire instead of doing
				# a pointless sideways dodge every time a bolt lands.
				combat_move_mode = 0
				combat_action_timer = rng.randf_range(0.45, 0.75)
		elif post_burst_reposition_timer > 0.0:
			if squad_role == "flank_left":
				combat_move_mode = 7
			elif squad_role == "flank_right":
				combat_move_mode = 8
			else:
				combat_move_mode = 1
			combat_action_timer = rng.randf_range(0.55, 0.95)
		elif useful_firing_range:
			combat_move_mode = 0
			combat_action_timer = rng.randf_range(0.55, 0.95)
		elif distance > 50.0:
			combat_move_mode = 3
			combat_action_timer = rng.randf_range(0.7, 1.15)
		else:
			combat_move_mode = 0
			combat_action_timer = rng.randf_range(0.5, 0.9)

	var desired := global_position
	match combat_move_mode:
		0:
			desired = global_position
		1:
			desired = global_position + side * 4.5 * strafe_sign
		2:
			desired = target_position + away * preferred_distance + side * 4.0 * strafe_sign
		3:
			desired = target_position + away * 38.0 + side * 2.0 * strafe_sign
		4:
			desired = cover_target
		5:
			desired = last_seen_position + side * 3.5 * strafe_sign
		6:
			desired = global_position + away * 7.0
		7:
			desired = target_position + away * 26.0 + side * 8.0
		8:
			desired = target_position + away * 26.0 - side * 8.0

	desired += _squad_separation() * 2.0
	var move_direction := desired - global_position
	move_direction.y = 0.0
	var wants_to_move := combat_move_mode != 0 and move_direction.length() > 1.15 and burst_remaining <= 0

	if wants_to_move:
		move_direction = _avoid_obstacle(move_direction.normalized())
		var combat_speed := move_speed * 0.72
		if combat_move_mode in [3, 5]:
			combat_speed = move_speed
		elif combat_move_mode in [7, 8]:
			combat_speed = move_speed * 0.84
		elif combat_move_mode == 6:
			combat_speed = move_speed * 0.92
		velocity.x = move_toward(velocity.x, move_direction.x * combat_speed, move_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * combat_speed, move_speed * 7.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 12.0 * delta)
		if combat_move_mode != 0 and move_direction.length() <= 1.15:
			combat_move_mode = 0
			combat_action_timer = 0.0

	var face_position := target_position if has_los else last_seen_position
	var face := face_position - global_position
	face.y = 0.0
	if face.length_squared() > 0.1:
		var desired_yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 11.0))

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if useful_firing_range and combat_move_mode == 0 and planar_speed < 0.6:
		aim_settle_timer += delta
	else:
		aim_settle_timer = 0.0

	if (
		useful_firing_range
		and reaction_timer <= 0.0
		and combat_move_mode == 0
		and planar_speed < 0.65
		and absf(wrapf(visual_root.rotation.y, -PI, PI)) < deg_to_rad(20.0)
		and aim_settle_timer >= 0.10
		and fire_cooldown <= 0.0
	):
		_fire_at_target(distance)

	if not has_los and lost_sight_timer > 4.0:
		target = null
		burst_remaining = 0
		squad_manager.release_fire_slot(self)
		_choose_patrol_target()

func _fire_at_target(distance: float) -> void:
	if burst_remaining <= 0:
		if not squad_manager.request_fire_slot(self):
			fire_cooldown = rng.randf_range(0.18, 0.34)
			return
		burst_remaining = rng.randi_range(2, 4)
	burst_remaining -= 1
	fire_cooldown = rng.randf_range(0.13, 0.22) if burst_remaining > 0 else rng.randf_range(0.72, 1.18)
	if burst_remaining <= 0:
		squad_manager.release_fire_slot(self)
		post_burst_reposition_timer = rng.randf_range(0.8, 1.5)
		combat_action_timer = minf(combat_action_timer, rng.randf_range(0.15, 0.35))
	var aim_point := target.global_position + Vector3.UP * 1.05
	var direction := (aim_point - muzzle.global_position).normalized()
	var inaccuracy: float = lerpf(0.012, 0.032, clampf(distance / engage_distance, 0.0, 1.0))
	direction = (direction
		+ global_basis.x * rng.randf_range(-inaccuracy, inaccuracy)
		+ global_basis.y * rng.randf_range(-inaccuracy, inaccuracy)
	).normalized()
	fire_animation_timer = 0.24
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
	if target == null or not is_instance_valid(target):
		reaction_timer = rng.randf_range(0.18, 0.42)
	target = new_target
	last_seen_position = new_target.global_position

func apply_damage(amount: float, _hit_position := Vector3.ZERO, direction := Vector3.ZERO, source = null) -> void:
	if dead:
		return
	if source is Node and (source as Node).is_in_group("enemy"):
		return
	health -= amount
	hit_stun = 0.11
	under_fire_timer = 0.8
	combat_action_timer = 0.0
	visual_root.rotation.x = deg_to_rad(-5.0)
	if source is Node3D:
		target = source
		squad_manager.alert_squad(squad_id, source)
	if health <= 0.0:
		_begin_death(direction)

func _begin_death(direction: Vector3) -> void:
	dead = true
	fire_animation_timer = 0.0
	squad_manager.release_fire_slot(self)
	squad_manager.release_cover(self)
	death_timer = 1.9
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
	# Controlled fall until a verified SWG transition/ragdoll is available.
	# Do not play static incapacitated/death poses as animations: they snap the
	# character horizontal in mid-air.
	visual_root.rotation.z = lerpf(visual_root.rotation.z, death_roll * 1.18, 1.0 - exp(-delta * 6.5))
	visual_root.rotation.x = lerpf(visual_root.rotation.x, deg_to_rad(10.0), 1.0 - exp(-delta * 5.0))
	visual_root.position.y = lerpf(visual_root.position.y, -0.28, 1.0 - exp(-delta * 4.5))
	if death_timer <= 0.0:
		queue_free()


func _squad_separation() -> Vector3:
	var separation := Vector3.ZERO
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemy"):
		if candidate == self or not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var other := candidate as Node3D
		var offset := global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.001 or distance > 4.5:
			continue
		var strength := (4.5 - distance) / 4.5
		separation += offset.normalized() * strength
		count += 1
	if count > 0:
		separation /= float(count)
	return separation


func _find_cover_target() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_score := INF
	var player_eye := target.global_position + Vector3.UP * 1.1
	for candidate in get_tree().get_nodes_in_group("combat_cover"):
		if not candidate is Node3D:
			continue
		var cover := candidate as Node3D
		var distance := global_position.distance_to(cover.global_position)
		if distance < 2.5 or distance > 24.0:
			continue
		var from_player := cover.global_position - target.global_position
		from_player.y = 0.0
		if from_player.length_squared() < 0.01:
			continue
		var hide_position := cover.global_position + from_player.normalized() * 1.55
		hide_position.y = global_position.y

		var query := PhysicsRayQueryParameters3D.create(player_eye, hide_position + Vector3.UP * 1.0)
		query.exclude = [target.get_rid()] if target is CollisionObject3D else []
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") != cover:
			continue

		var travel_cost := distance
		var exposure_cost := target.global_position.distance_to(hide_position) * 0.025
		var score := travel_cost + exposure_cost
		if score < best_score:
			best_score = score
			best = hide_position
	if best != Vector3.ZERO and squad_manager.reserve_cover(self, best):
		return best
	return Vector3.ZERO


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

func _update_animation(delta: float) -> void:
	visual_root.rotation.x = lerpf(visual_root.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, 0.0, 1.0 - exp(-delta * 12.0))

	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var planar_speed := planar_velocity.length()
	var local_velocity := global_basis.inverse() * planar_velocity

	var lean := clampf(-local_velocity.x / maxf(move_speed, 0.1), -1.0, 1.0) * 0.035
	visual_root.rotation.z = lerpf(visual_root.rotation.z, lean, 1.0 - exp(-delta * 9.0))

	if animation_player == null:
		return

	if fire_animation_timer > 0.0 and _animation_exists("fire"):
		_set_animation("fire", false)
		animation_player.speed_scale = 1.0
		return

	if planar_speed < 0.22:
		_set_animation("idle")
		animation_player.speed_scale = 1.0
		return

	var requested := "walk_forward"
	var fallback_speed := move_speed * 0.62

	# Godot local -Z is forward. Pick the actual SWG directional rifle clip
	# instead of playing one forward run animation for every velocity vector.
	if absf(local_velocity.x) > absf(local_velocity.z) * 0.75:
		requested = "strafe_right" if local_velocity.x > 0.0 else "strafe_left"
		fallback_speed = move_speed * 0.58
	elif local_velocity.z > 0.15:
		requested = "walk_back"
		fallback_speed = move_speed * 0.55
	elif planar_speed > move_speed * 0.82:
		requested = "run_forward"
		fallback_speed = move_speed
	else:
		requested = "walk_forward"

	_set_animation(requested)
	var authored_speed := SwgAssetBridge.stormtrooper_animation_speed(requested)
	if authored_speed <= 0.1:
		authored_speed = fallback_speed
	animation_player.speed_scale = clampf(planar_speed / maxf(authored_speed, 0.1), 0.72, 1.18)


func _animation_exists(requested: String) -> bool:
	if animation_player == null:
		return false
	if animation_player.has_animation(requested):
		return true
	for candidate in animation_player.get_animation_list():
		if String(candidate).to_lower().contains(requested):
			return true
	return false


func _set_animation(requested: String, loop: bool = true) -> void:
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
		clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	active_animation = requested
	animation_player.play(selected, 0.10)

	# Randomize each looping clip only the first time this soldier enters it.
	# Re-randomizing every state transition caused visible pops and broken foot
	# phases even though it kept squads out of perfect sync.
	if loop and clip != null and clip.length > 0.2 and not animation_phase_seeded.has(requested):
		animation_phase_seeded[requested] = true
		animation_player.seek(rng.randf_range(0.0, clip.length), true)

