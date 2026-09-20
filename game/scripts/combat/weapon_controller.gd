class_name WeaponController
extends Node3D

signal weapon_changed(name: String)
signal fired

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
var base_fov := 80.0

func configure(view_camera: Camera3D, body: CharacterBody3D) -> void:
	camera = view_camera
	owner_body = body
	weapons = [WeaponDefinition.pistol(), WeaponDefinition.rifle()]
	rng.seed = 0xF4A20
	camera.add_child(viewmodel)
	viewmodel.add_child(weapon_mesh)
	viewmodel.add_child(muzzle)
	_rebuild_viewmodel()
	camera.fov = base_fov

func current_weapon() -> WeaponDefinition:
	return weapons[current_index]

func set_enabled(value: bool) -> void:
	enabled = value
	viewmodel.visible = value
	if not value:
		aiming = false

func _process(delta: float) -> void:
	if camera == null or weapons.is_empty():
		return
	cooldown = max(0.0, cooldown - delta)

	if enabled:
		if Input.is_action_just_pressed("weapon_1"):
			_select_weapon(0)
		if Input.is_action_just_pressed("weapon_2"):
			_select_weapon(1)

	aiming = enabled and Input.is_action_pressed("aim")
	var weapon := current_weapon()
	var target_fov := weapon.ads_fov if aiming else base_fov
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 15.0))
	var target_offset := weapon.ads_offset if aiming else weapon.viewmodel_offset
	viewmodel.position = viewmodel.position.lerp(target_offset, 1.0 - exp(-delta * 18.0))

	if enabled and Input.is_action_pressed("fire") and cooldown <= 0.0:
		_fire()

func _select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_index:
		return
	current_index = index
	cooldown = 0.12
	_rebuild_viewmodel()
	weapon_changed.emit(current_weapon().display_name)

func _rebuild_viewmodel() -> void:
	if weapons.is_empty():
		return
	var weapon := current_weapon()
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
	muzzle.position = Vector3(0.0, 0.0, -mesh.size.z * 0.58)

func _fire() -> void:
	var weapon := current_weapon()
	cooldown = 1.0 / max(weapon.rounds_per_second, 0.1)

	var direction := -camera.global_basis.z
	var spread_degrees := weapon.ads_spread_degrees if aiming else weapon.hip_spread_degrees
	direction = _apply_spread(direction, deg_to_rad(spread_degrees))

	var bolt := BlasterBolt.new()
	get_tree().current_scene.add_child(bolt)
	bolt.configure(muzzle.global_position, direction, weapon.projectile_speed, weapon.damage, owner_body)

	if owner_body != null and owner_body.has_method("add_recoil"):
		owner_body.add_recoil(
			weapon.recoil_pitch_degrees,
			rng.randf_range(-weapon.recoil_yaw_degrees, weapon.recoil_yaw_degrees)
		)
	fired.emit()

func _apply_spread(direction: Vector3, radians: float) -> Vector3:
	if radians <= 0.00001:
		return direction.normalized()
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var radius := tan(radians) * sqrt(rng.randf())
	var theta := rng.randf_range(0.0, TAU)
	return (direction + right * cos(theta) * radius + up * sin(theta) * radius).normalized()
