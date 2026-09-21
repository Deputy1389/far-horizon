class_name WeaponController
extends Node3D

signal weapon_changed(name: String)
signal fired
signal hit_confirmed
signal heat_changed(value: float, overheated: bool)
signal aiming_changed(value: bool, scoped: bool)

var camera: Camera3D
var owner_body: CharacterBody3D
var weapons: Array[WeaponDefinition] = []
var current_index := 1
var cooldown := 0.0
var aiming := false
var enabled := true
var rng := RandomNumberGenerator.new()
var heat := 0.0
var overheated := false
var motion_time := 0.0
var last_aiming := false
var aim_blend := 0.0

var viewmodel := Node3D.new()
var arms_root := Node3D.new()
var first_person_rig: Node3D
var first_person_animation: AnimationPlayer
var first_person_skeleton: Skeleton3D
var first_person_hold_bone := -1
var first_person_active_animation := ""
var first_person_fire_timer := 0.0
var first_person_weapon_mount := Node3D.new()
var scope_layer := CanvasLayer.new()
var scope_rect := ColorRect.new()
var muzzle := Marker3D.new()
var weapon_mesh := MeshInstance3D.new()
var imported_weapon: Node3D
var muzzle_flash_mesh := MeshInstance3D.new()
var muzzle_flash_light := OmniLight3D.new()
var fire_audio := AudioStreamPlayer.new()
var muzzle_flash_time := 0.0
var viewmodel_kick := 0.0
var viewmodel_recoil_pitch := 0.0
var viewmodel_recoil_yaw := 0.0
var base_fov := 80.0

func configure(view_camera: Camera3D, body: CharacterBody3D) -> void:
	camera = view_camera
	owner_body = body
	weapons = [WeaponDefinition.pistol(), WeaponDefinition.rifle()]
	rng.seed = 0xF4A20
	camera.add_child(viewmodel)
	viewmodel.add_child(arms_root)
	viewmodel.add_child(first_person_weapon_mount)
	viewmodel.add_child(weapon_mesh)
	viewmodel.add_child(muzzle)
	viewmodel.add_child(fire_audio)
	fire_audio.volume_db = -7.0
	_build_muzzle_flash()
	_build_first_person_arms()
	_build_scope_overlay()
	_rebuild_viewmodel()
	camera.fov = base_fov
	heat_changed.emit(heat, overheated)

func current_weapon() -> WeaponDefinition:
	return weapons[current_index]

func is_aiming() -> bool:
	return aiming

func is_overheated() -> bool:
	return overheated

func set_enabled(value: bool) -> void:
	enabled = value
	viewmodel.visible = value
	if not value:
		aiming = false
		scope_layer.visible = false

func _build_first_person_arms() -> void:
	# Use a real SWG skinned hand mesh on the all_b skeleton. The previous
	# primitive boxes/cylinders were intentionally removed; this rig can now
	# play the same rifle poses as the third-person character.
	first_person_rig = SwgAssetBridge.instantiate_character("firstPersonHands")
	if first_person_rig == null:
		arms_root.visible = false
		return

	arms_root.add_child(first_person_rig)
	# Body-space offset: the hand-only mesh is authored on a full humanoid
	# skeleton, so move its unseen root below the camera while keeping the
	# animated hands in the lower-center view.
	first_person_rig.position = Vector3(0.0, -1.34, 0.10)

	var players := first_person_rig.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		first_person_animation = players[0] as AnimationPlayer

	var skeletons := first_person_rig.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		first_person_skeleton = skeletons[0] as Skeleton3D
		first_person_hold_bone = _find_first_person_bone(first_person_skeleton, ["hold_r"])

	_set_first_person_animation("idle")
	arms_root.visible = true


func _find_first_person_bone(skeleton: Skeleton3D, candidates: Array[String]) -> int:
	for candidate in candidates:
		var index := skeleton.find_bone(candidate)
		if index >= 0:
			return index
	for index in range(skeleton.get_bone_count()):
		var actual := skeleton.get_bone_name(index).to_lower()
		for candidate in candidates:
			if actual == candidate.to_lower():
				return index
	return -1


func _set_first_person_animation(requested: String, loop: bool = true) -> void:
	if first_person_animation == null or first_person_active_animation == requested:
		return
	var selected := requested
	if not first_person_animation.has_animation(selected):
		for candidate in first_person_animation.get_animation_list():
			if String(candidate).to_lower().contains(requested):
				selected = String(candidate)
				break
	if not first_person_animation.has_animation(selected):
		return
	var clip := first_person_animation.get_animation(selected)
	if clip != null:
		clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	first_person_active_animation = requested
	first_person_animation.play(selected, 0.08)


func _update_first_person_rig(delta: float) -> void:
	first_person_fire_timer = maxf(0.0, first_person_fire_timer - delta)
	if first_person_animation != null:
		if first_person_fire_timer > 0.0 and first_person_animation.has_animation("fire"):
			_set_first_person_animation("fire", false)
		elif first_person_fire_timer <= 0.0:
			_set_first_person_animation("idle")

	if first_person_skeleton != null and first_person_hold_bone >= 0:
		first_person_weapon_mount.global_transform = (
			first_person_skeleton.global_transform
			* first_person_skeleton.get_bone_global_pose(first_person_hold_bone)
		)
		if imported_weapon != null and is_instance_valid(imported_weapon):
			var barrel_forward := -first_person_weapon_mount.global_basis.z.normalized()
			muzzle.global_position = first_person_weapon_mount.global_position + barrel_forward * 0.68
			muzzle.global_basis = first_person_weapon_mount.global_basis.orthonormalized()


func _build_scope_overlay() -> void:
	scope_layer.layer = 40
	scope_layer.visible = false
	add_child(scope_layer)

	scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float radius = 0.305;
	float d = length(p);

	float outside = smoothstep(radius - 0.004, radius + 0.004, d);
	float ring = 1.0 - smoothstep(0.006, 0.014, abs(d - radius));
	float vertical = 1.0 - smoothstep(0.0008, 0.0018, abs(p.x));
	float horizontal = 1.0 - smoothstep(0.0008, 0.0018, abs(p.y));
	float reticle = max(vertical, horizontal) * (1.0 - smoothstep(radius * 0.72, radius * 0.78, d));
	float center_dot = 1.0 - smoothstep(0.002, 0.006, d);

	vec3 color = vec3(0.005);
	float alpha = outside * 0.96;
	alpha = max(alpha, ring * 0.88);
	if (reticle > 0.01 || center_dot > 0.01) {
		color = vec3(0.55, 0.08, 0.04);
		alpha = max(alpha, max(reticle * 0.42, center_dot * 0.7));
	}
	COLOR = vec4(color, alpha);
}
"""
	material.shader = shader
	scope_rect.material = material
	scope_layer.add_child(scope_rect)

func _build_muzzle_flash() -> void:
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.055
	flash_mesh.height = 0.11
	muzzle_flash_mesh.mesh = flash_mesh

	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.28, 0.03, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.08, 0.01, 1.0)
	flash_material.emission_energy_multiplier = 10.0
	muzzle_flash_mesh.material_override = flash_material
	muzzle_flash_mesh.visible = false
	muzzle.add_child(muzzle_flash_mesh)

	muzzle_flash_light.light_color = Color(1.0, 0.18, 0.03)
	muzzle_flash_light.light_energy = 2.4
	muzzle_flash_light.omni_range = 3.5
	muzzle_flash_light.visible = false
	muzzle.add_child(muzzle_flash_light)

func _process(delta: float) -> void:
	if camera == null or weapons.is_empty():
		return
	cooldown = maxf(0.0, cooldown - delta)
	muzzle_flash_time = maxf(0.0, muzzle_flash_time - delta)
	var weapon := current_weapon()
	var venting := enabled and Input.is_action_pressed("vent")
	var cooling_multiplier := 3.2 if venting else (1.7 if overheated else 1.0)
	if heat > 0.0 and (not Input.is_action_pressed("fire") or overheated or venting):
		var previous_heat := heat
		heat = maxf(0.0, heat - weapon.cooling_rate * cooling_multiplier * delta)
		if overheated and heat <= 0.18:
			overheated = false
		if absf(previous_heat - heat) > 0.001:
			heat_changed.emit(heat, overheated)
	if muzzle_flash_time <= 0.0:
		muzzle_flash_mesh.visible = false
		muzzle_flash_light.visible = false
	_update_first_person_rig(delta)

	if enabled:
		if Input.is_action_just_pressed("weapon_1"):
			_select_weapon(0)
		if Input.is_action_just_pressed("weapon_2"):
			_select_weapon(1)

	aiming = enabled and Input.is_action_pressed("aim")
	var scoped_ads := aiming and current_index == 1
	var target_aim_blend := 1.0 if aiming else 0.0
	aim_blend = lerpf(aim_blend, target_aim_blend, 1.0 - exp(-delta * 12.0))
	scope_layer.visible = current_index == 1 and aim_blend > 0.01
	scope_rect.modulate.a = smoothstep(0.52, 0.96, aim_blend) if current_index == 1 else 0.0

	var hide_viewmodel_for_scope := current_index == 1 and aim_blend > 0.82
	arms_root.visible = enabled and first_person_rig != null and not hide_viewmodel_for_scope
	if imported_weapon != null and is_instance_valid(imported_weapon):
		imported_weapon.visible = enabled and not hide_viewmodel_for_scope
	weapon_mesh.visible = enabled and imported_weapon == null and not hide_viewmodel_for_scope
	if aiming != last_aiming:
		last_aiming = aiming
		aiming_changed.emit(aiming, scoped_ads)

	var planar_speed := Vector2(owner_body.velocity.x, owner_body.velocity.z).length() if owner_body != null else 0.0
	var sprint_presented := (
		enabled
		and not aiming
		and Input.is_action_pressed("sprint")
		and planar_speed > 7.0
		and not Input.is_action_pressed("fire")
	)
	var hip_fov := base_fov + 3.0 if sprint_presented else base_fov
	var target_fov := lerpf(hip_fov, weapon.ads_fov, aim_blend)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 16.0))

	viewmodel_kick = lerpf(viewmodel_kick, 0.0, 1.0 - exp(-delta * 18.0))
	viewmodel_recoil_pitch = lerpf(viewmodel_recoil_pitch, 0.0, 1.0 - exp(-delta * 17.0))
	viewmodel_recoil_yaw = lerpf(viewmodel_recoil_yaw, 0.0, 1.0 - exp(-delta * 19.0))
	motion_time += delta * (2.1 + planar_speed * 0.85)
	var target_offset := weapon.viewmodel_offset.lerp(weapon.ads_offset, aim_blend)
	if current_index == 1:
		var pre_scope_offset := weapon.viewmodel_offset + Vector3(0.0, -0.045, -0.015)
		target_offset = weapon.viewmodel_offset.lerp(pre_scope_offset, aim_blend)
	var sway_amount := 0.003 if aiming else 0.008
	target_offset += Vector3(
		sin(motion_time) * sway_amount,
		cos(motion_time * 0.55) * sway_amount * 0.7,
		0.0
	)
	if planar_speed > 0.35 and not aiming:
		target_offset += Vector3(
			sin(motion_time * 2.2) * 0.008,
			absf(cos(motion_time * 2.2)) * 0.01,
			0.0
		)
	if sprint_presented:
		target_offset += Vector3(0.0, -0.09, 0.09)
	target_offset += Vector3(0.0, 0.0, viewmodel_kick)
	viewmodel.position = viewmodel.position.lerp(target_offset, 1.0 - exp(-delta * 18.0))
	var target_roll := deg_to_rad(-8.0) if sprint_presented else 0.0
	var target_pitch := (deg_to_rad(10.0) if sprint_presented else 0.0) + viewmodel_recoil_pitch
	viewmodel.rotation.z = lerpf(viewmodel.rotation.z, target_roll, 1.0 - exp(-delta * 12.0))
	viewmodel.rotation.x = lerpf(viewmodel.rotation.x, target_pitch, 1.0 - exp(-delta * 15.0))
	viewmodel.rotation.y = lerpf(viewmodel.rotation.y, viewmodel_recoil_yaw, 1.0 - exp(-delta * 17.0))
	arms_root.rotation.z = lerpf(arms_root.rotation.z, target_roll * 0.45, 1.0 - exp(-delta * 10.0))

	if enabled and Input.is_action_pressed("fire") and cooldown <= 0.0 and not overheated and not venting:
		_fire()

func _select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_index:
		return
	current_index = index
	cooldown = 0.12
	viewmodel_kick = 0.0
	_rebuild_viewmodel()
	weapon_changed.emit(current_weapon().display_name)

func _rebuild_viewmodel() -> void:
	if weapons.is_empty():
		return
	var weapon := current_weapon()
	if imported_weapon != null and is_instance_valid(imported_weapon):
		imported_weapon.queue_free()
		imported_weapon = null

	var role := "blasterPistol" if current_index == 0 else "blasterRifle"
	var use_rig_attachment := first_person_rig != null and first_person_skeleton != null and first_person_hold_bone >= 0
	imported_weapon = SwgAssetBridge.instantiate_weapon(role, not use_rig_attachment)
	if imported_weapon != null:
		if use_rig_attachment:
			first_person_weapon_mount.add_child(imported_weapon)
		else:
			viewmodel.add_child(imported_weapon)
		imported_weapon.position = Vector3.ZERO
		imported_weapon.rotation = Vector3.ZERO if use_rig_attachment else imported_weapon.rotation
		weapon_mesh.visible = false
	else:
		weapon_mesh.visible = true
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.13, 0.12, 0.46 if current_index == 0 else 0.72)
		weapon_mesh.mesh = mesh

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.08, 0.09, 0.1)
		material.metallic = 0.72
		material.roughness = 0.33
		weapon_mesh.material_override = material
		weapon_mesh.position = Vector3.ZERO

	viewmodel.position = weapon.viewmodel_offset
	viewmodel.scale = weapon.viewmodel_scale
	arms_root.visible = first_person_rig != null
	muzzle.position = Vector3(0.0, 0.0, -0.44 if current_index == 0 else -0.72)
	fire_audio.stream = SwgAssetBridge.audio_for_role(role)
	_update_first_person_rig(0.0)


func _fire() -> void:
	var weapon := current_weapon()
	cooldown = 1.0 / maxf(weapon.rounds_per_second, 0.1)

	# Spread is evaluated from the camera/reticle, then the physical bolt leaves
	# the muzzle toward that camera-space aim point. This makes hip fire and ADS
	# converge on the center reticle instead of landing low-right because the
	# muzzle is offset from the camera.
	var camera_direction := -camera.global_basis.z
	var spread_degrees := weapon.ads_spread_degrees if aiming else weapon.hip_spread_degrees
	spread_degrees += heat * (0.18 if aiming else 0.42)
	camera_direction = _apply_spread(camera_direction, deg_to_rad(spread_degrees))
	var aim_point := _camera_aim_point(camera_direction)
	var direction := (aim_point - muzzle.global_position).normalized()

	var bolt := BlasterBolt.new()
	get_tree().current_scene.add_child(bolt)
	bolt.damaged_target.connect(_on_bolt_damaged_target)
	bolt.configure(muzzle.global_position, direction, weapon.projectile_speed, weapon.damage, owner_body)

	heat = minf(1.0, heat + weapon.heat_per_shot)
	if heat >= 0.999:
		overheated = true
	heat_changed.emit(heat, overheated)

	first_person_fire_timer = 0.24
	first_person_active_animation = ""
	viewmodel_kick = minf(viewmodel_kick + (0.018 if aiming else 0.032), 0.07)
	viewmodel_recoil_pitch = clampf(
		viewmodel_recoil_pitch + deg_to_rad(1.15 if aiming else 1.75),
		0.0,
		deg_to_rad(6.0)
	)
	viewmodel_recoil_yaw = clampf(
		viewmodel_recoil_yaw + deg_to_rad(rng.randf_range(-0.45, 0.45)),
		deg_to_rad(-2.0),
		deg_to_rad(2.0)
	)
	muzzle_flash_time = 0.045
	muzzle_flash_mesh.visible = true
	muzzle_flash_light.visible = true
	if fire_audio.stream != null:
		fire_audio.stop()
		fire_audio.play()

	if owner_body != null and owner_body.has_method("add_recoil"):
		owner_body.add_recoil(
			weapon.recoil_pitch_degrees,
			rng.randf_range(-weapon.recoil_yaw_degrees, weapon.recoil_yaw_degrees)
		)
	fired.emit()


func _camera_aim_point(direction: Vector3) -> Vector3:
	var origin := camera.global_position
	var endpoint := origin + direction.normalized() * 650.0
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	if owner_body is CollisionObject3D:
		query.exclude = [(owner_body as CollisionObject3D).get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"] as Vector3
	return endpoint


func _on_bolt_damaged_target() -> void:
	hit_confirmed.emit()

func _apply_spread(direction: Vector3, radians: float) -> Vector3:
	if radians <= 0.00001:
		return direction.normalized()
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var radius := tan(radians) * sqrt(rng.randf())
	var theta := rng.randf_range(0.0, TAU)
	return (direction + right * cos(theta) * radius + up * sin(theta) * radius).normalized()
