class_name WeaponController
extends Node3D

signal weapon_changed(name: String)
signal fired
signal hit_confirmed

var camera: Camera3D
var owner_body: CharacterBody3D
var weapons: Array[WeaponDefinition] = []
var current_index := 1
var cooldown := 0.0
var aiming := false
var enabled := true
var rng := RandomNumberGenerator.new()

var viewmodel := Node3D.new()
var muzzle := Marker3D.new()
var weapon_mesh := MeshInstance3D.new()
var imported_weapon: Node3D
var muzzle_flash_mesh := MeshInstance3D.new()
var muzzle_flash_light := OmniLight3D.new()
var fire_audio := AudioStreamPlayer.new()
var muzzle_flash_time := 0.0
var viewmodel_kick := 0.0
var base_fov := 80.0

func configure(view_camera: Camera3D, body: CharacterBody3D) -> void:
	camera = view_camera
	owner_body = body
	weapons = [WeaponDefinition.pistol(), WeaponDefinition.rifle()]
	rng.seed = 0xF4A20
	camera.add_child(viewmodel)
	viewmodel.add_child(weapon_mesh)
	viewmodel.add_child(muzzle)
	viewmodel.add_child(fire_audio)
	fire_audio.volume_db = -7.0
	_build_muzzle_flash()
	_rebuild_viewmodel()
	camera.fov = base_fov

func current_weapon() -> WeaponDefinition:
	return weapons[current_index]

func is_aiming() -> bool:
	return aiming

func set_enabled(value: bool) -> void:
	enabled = value
	viewmodel.visible = value
	if not value:
		aiming = false

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
	if muzzle_flash_time <= 0.0:
		muzzle_flash_mesh.visible = false
		muzzle_flash_light.visible = false

	if enabled:
		if Input.is_action_just_pressed("weapon_1"):
			_select_weapon(0)
		if Input.is_action_just_pressed("weapon_2"):
			_select_weapon(1)

	aiming = enabled and Input.is_action_pressed("aim")
	var weapon := current_weapon()
	var planar_speed := Vector2(owner_body.velocity.x, owner_body.velocity.z).length() if owner_body != null else 0.0
	var sprint_presented := (
		enabled
		and not aiming
		and Input.is_action_pressed("sprint")
		and planar_speed > 7.0
		and not Input.is_action_pressed("fire")
	)
	var target_fov := weapon.ads_fov if aiming else (base_fov + 4.0 if sprint_presented else base_fov)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 15.0))

	viewmodel_kick = lerpf(viewmodel_kick, 0.0, 1.0 - exp(-delta * 18.0))
	var target_offset := weapon.ads_offset if aiming else weapon.viewmodel_offset
	if sprint_presented:
		target_offset += Vector3(0.0, -0.09, 0.09)
	target_offset += Vector3(0.0, 0.0, viewmodel_kick)
	viewmodel.position = viewmodel.position.lerp(target_offset, 1.0 - exp(-delta * 18.0))
	var target_roll := deg_to_rad(-8.0) if sprint_presented else 0.0
	var target_pitch := deg_to_rad(10.0) if sprint_presented else 0.0
	viewmodel.rotation.z = lerpf(viewmodel.rotation.z, target_roll, 1.0 - exp(-delta * 12.0))
	viewmodel.rotation.x = lerpf(viewmodel.rotation.x, target_pitch, 1.0 - exp(-delta * 12.0))

	if enabled and Input.is_action_pressed("fire") and cooldown <= 0.0:
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
	muzzle.position = Vector3(0.0, 0.0, -0.44 if current_index == 0 else -0.72)
	fire_audio.stream = SwgAssetBridge.audio_for_role(role)

func _fire() -> void:
	var weapon := current_weapon()
	cooldown = 1.0 / maxf(weapon.rounds_per_second, 0.1)

	var direction := -camera.global_basis.z
	var spread_degrees := weapon.ads_spread_degrees if aiming else weapon.hip_spread_degrees
	direction = _apply_spread(direction, deg_to_rad(spread_degrees))

	var bolt := BlasterBolt.new()
	get_tree().current_scene.add_child(bolt)
	bolt.damaged_target.connect(_on_bolt_damaged_target)
	bolt.configure(muzzle.global_position, direction, weapon.projectile_speed, weapon.damage, owner_body)

	viewmodel_kick = minf(viewmodel_kick + (0.022 if aiming else 0.038), 0.08)
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
