class_name FloatingOrigin
extends Node

signal rebased(previous_origin: PackedFloat64Array, new_origin: PackedFloat64Array)

@export var planet_radius := 6_000_000.0
@export var shift_threshold := 900.0

var origin_ecef := PackedFloat64Array([0.0, 0.0, 0.0])
var frame_basis := Basis.IDENTITY
var tracked_body: Node3D

func configure(radius: float, latitude_degrees: float = 0.0, longitude_degrees: float = 0.0) -> void:
	planet_radius = radius
	origin_ecef = PlanetMath.lat_lon_to_ecef(
		deg_to_rad(latitude_degrees),
		deg_to_rad(longitude_degrees),
		0.0,
		planet_radius
	)
	frame_basis = PlanetMath.tangent_basis(origin_ecef)

func track(body: Node3D) -> void:
	tracked_body = body

func absolute_position(local_position: Vector3) -> PackedFloat64Array:
	return PlanetMath.local_to_ecef(origin_ecef, frame_basis, local_position)

func local_position(planet_position: PackedFloat64Array) -> Vector3:
	return PlanetMath.ecef_to_local(origin_ecef, frame_basis, planet_position)

func _physics_process(_delta: float) -> void:
	if tracked_body == null or not is_instance_valid(tracked_body):
		return
	var horizontal := Vector2(tracked_body.global_position.x, tracked_body.global_position.z)
	if horizontal.length() >= shift_threshold:
		_rebase()

func _rebase() -> void:
	var previous_origin := origin_ecef.duplicate()
	var old_frame := frame_basis
	var snapshots: Array[Dictionary] = []
	var player_planet_velocity := Vector3.ZERO
	if tracked_body is CharacterBody3D:
		player_planet_velocity = old_frame * (tracked_body as CharacterBody3D).velocity

	for candidate in get_tree().get_nodes_in_group("planet_anchor"):
		if candidate is Node3D and candidate != tracked_body and is_instance_valid(candidate):
			var node := candidate as Node3D
			var planet_velocity := Vector3.ZERO
			var has_velocity := node is CharacterBody3D
			if has_velocity:
				planet_velocity = old_frame * (node as CharacterBody3D).velocity
			snapshots.append({
				"node": node,
				"ecef": PlanetMath.local_to_ecef(previous_origin, old_frame, node.global_position),
				"basis": old_frame * node.global_basis,
				"has_velocity": has_velocity,
				"planet_velocity": planet_velocity,
			})

	var player_ecef := PlanetMath.local_to_ecef(previous_origin, old_frame, tracked_body.global_position)
	var player_planet_basis := old_frame * tracked_body.global_basis

	origin_ecef = PlanetMath.project_to_radius(player_ecef, planet_radius)
	frame_basis = PlanetMath.tangent_basis(origin_ecef)

	tracked_body.global_transform = Transform3D(
		frame_basis.inverse() * player_planet_basis,
		PlanetMath.ecef_to_local(origin_ecef, frame_basis, player_ecef)
	)
	if tracked_body is CharacterBody3D:
		(tracked_body as CharacterBody3D).velocity = frame_basis.inverse() * player_planet_velocity

	for snapshot in snapshots:
		var node: Node3D = snapshot["node"]
		if not is_instance_valid(node):
			continue
		var preserved_ecef: PackedFloat64Array = snapshot["ecef"]
		var preserved_basis: Basis = snapshot["basis"]
		node.global_transform = Transform3D(
			frame_basis.inverse() * preserved_basis,
			PlanetMath.ecef_to_local(origin_ecef, frame_basis, preserved_ecef)
		)
		if bool(snapshot["has_velocity"]) and node is CharacterBody3D:
			(node as CharacterBody3D).velocity = frame_basis.inverse() * (snapshot["planet_velocity"] as Vector3)

	rebased.emit(previous_origin, origin_ecef.duplicate())

func latitude_longitude_degrees() -> Vector2:
	var lat_lon := PlanetMath.ecef_to_lat_lon(origin_ecef)
	return Vector2(rad_to_deg(lat_lon.x), rad_to_deg(lat_lon.y))
