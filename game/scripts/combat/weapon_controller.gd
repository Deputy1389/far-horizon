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
	var cuff_material := StandardMaterial3D.new()
	cuff_material.albedo_color = Color(0.13, 0.12, 0.105)
	cuff_material.roughness = 0.94

	var glove_material := StandardMaterial3D.new()
	glove_material.albedo_color = Color(0.025, 0.025, 0.024)
	glove_material.roughness = 0.72

	# Until we have a real first-person body rig, keep the surrogate anatomy
	# extremely restrained: two gloves and short cuffs placed around the weapon.
	# Long primitive forearms read worse than a mostly-hidden body.
	_add_hand(Vector3(0.105, -0.085, -0.13), Vector3(0.09, 0.07, 0.13), glove_material)
	_add_hand(Vector3(-0.072, -0.065, -0.25), Vector3(0.085, 0.065, 0.12), glove_material)

	var right_cuff := MeshInstance3D.new()
	var right_cuff_mesh := BoxMesh.new()
	right_cuff_mesh.size = Vector3(0.11, 0.09, 0.12)
	right_cuff.mesh = right_cuff_mesh
	right_cuff.position = Vector3(0.13, -0.13, -0.02)
	right_cuff.rotation = Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(-7.0))
	right_cuff.material_override = cuff_material
	arms_root.add_child(right_cuff)

	var left_cuff := MeshInstance3D.new()
	var left_cuff_mesh := BoxMesh.new()
	left_cuff_mesh.size = Vector3(0.10, 0.085, 0.11)
	left_cuff.mesh = left_cuff_mesh
	left_cuff.position = Vector3(-0.105, -0.105, -0.16)
	left_cuff.rotation = Vector3(deg_to_rad(-5.0), 0.0, deg_to_rad(6.0))
	left_cuff.material_override = cuff_material
	arms_root.add_child(left_cuff)

func _add_arm_segment(from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var direction := to - from
	var length := direction.length()
	if length <= 0.001:
		return
	var segment := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	segment.mesh = mesh
	segment.position = (from + to) * 0.5
	segment.rotation = Quaternion(Vector3.UP, direction.normalized()).get_euler()
	segment.material_override = material
	arms_root.add_child(segment)


func _add_hand(position: Vector3, size: Vector3, material: Material) -> void:
	var hand := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	hand.mesh = mesh
	hand.position = position
	hand.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(4.0), deg_to_rad(-5.0))
	hand.material_override = material
	arms_root.add_child(hand)

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
	arms_root.visible = enabled and not hide_viewmodel_for_scope
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
	imported_weapon = SwgAssetBridge.instantiate_weapon(role)
	if imported_weapon != null:
		viewmodel.add_child(imported_weapon)
		imported_weapon.position = Vector3.ZERO
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
	arms_root.visible = true
	muzzle.position = Vector3(0.0, 0.0, -0.44 if current_index == 0 else -0.72)
	fire_audio.stream = SwgAssetBridge.audio_for_role(role)

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
