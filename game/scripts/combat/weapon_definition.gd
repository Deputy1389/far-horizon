class_name WeaponDefinition
extends Resource

@export var display_name := "Blaster"
@export var damage := 30.0
@export var projectile_speed := 220.0
@export var rounds_per_second := 6.0
@export var hip_spread_degrees := 0.9
@export var ads_spread_degrees := 0.18
@export var recoil_pitch_degrees := 0.65
@export var recoil_yaw_degrees := 0.18
@export var ads_fov := 58.0
@export var heat_per_shot := 0.12
@export var cooling_rate := 0.34
@export var viewmodel_scale := Vector3.ONE
@export var viewmodel_offset := Vector3(0.28, -0.22, -0.55)
@export var ads_offset := Vector3(0.0, -0.17, -0.42)

static func pistol() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.display_name = "Blaster Pistol"
	weapon.damage = 38.0
	weapon.projectile_speed = 205.0
	weapon.rounds_per_second = 3.8
	weapon.hip_spread_degrees = 0.8
	weapon.ads_spread_degrees = 0.14
	weapon.recoil_pitch_degrees = 0.9
	weapon.recoil_yaw_degrees = 0.24
	weapon.heat_per_shot = 0.19
	weapon.cooling_rate = 0.42
	weapon.viewmodel_offset = Vector3(0.27, -0.24, -0.5)
	weapon.ads_offset = Vector3(0.0, -0.19, -0.36)
	return weapon

static func rifle() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.display_name = "Blaster Rifle"
	weapon.damage = 28.0
	weapon.projectile_speed = 235.0
	weapon.rounds_per_second = 8.0
	weapon.hip_spread_degrees = 0.62
	weapon.ads_spread_degrees = 0.1
	weapon.recoil_pitch_degrees = 0.42
	weapon.recoil_yaw_degrees = 0.12
	weapon.heat_per_shot = 0.105
	weapon.cooling_rate = 0.31
	weapon.viewmodel_offset = Vector3(0.31, -0.25, -0.68)
	weapon.ads_offset = Vector3(0.0, -0.18, -0.51)
	return weapon
