class_name RebelOutpost
extends Node3D

var planet: ProceduralPlanet
var center_tangent := Vector2.ZERO
var sandbag_material := StandardMaterial3D.new()
var metal_material := StandardMaterial3D.new()
var floor_material := StandardMaterial3D.new()

func configure(planet_ref: ProceduralPlanet, center_xz: Vector2) -> void:
	planet = planet_ref
	center_tangent = center_xz
	global_position = planet.surface_point(center_tangent.x, center_tangent.y)
	add_to_group("planet_anchor")
	_setup_materials()
	_build_outpost()

func _setup_materials() -> void:
	sandbag_material.albedo_color = Color(0.39, 0.30, 0.22)
	sandbag_material.roughness = 1.0
	metal_material.albedo_color = Color(0.16, 0.18, 0.18)
	metal_material.metallic = 0.55
	metal_material.roughness = 0.45
	floor_material.albedo_color = Color(0.31, 0.27, 0.22)
	floor_material.roughness = 0.94

	var wall_texture := SwgAssetBridge.texture_for_role("wall")
	if wall_texture != null:
		sandbag_material.albedo_texture = wall_texture
		sandbag_material.albedo_color = Color.WHITE
	var metal_texture := SwgAssetBridge.texture_for_role("metal")
	if metal_texture != null:
		metal_material.albedo_texture = metal_texture
		metal_material.albedo_color = Color.WHITE
	var floor_texture := SwgAssetBridge.texture_for_role("floor")
	if floor_texture != null:
		floor_material.albedo_texture = floor_texture
		floor_material.albedo_color = Color.WHITE

func _build_outpost() -> void:
	# Keep the center open as the player/speeder staging area.
	_add_box(Vector2(-13.0, 1.0), Vector3(8.0, 0.85, 1.2), sandbag_material)
	_add_box(Vector2(-18.5, -5.0), Vector3(1.3, 1.2, 7.0), sandbag_material)
	_add_box(Vector2(-6.0, -13.0), Vector3(8.0, 1.05, 1.2), sandbag_material)

	# Four readable step heights into a firing platform.
	for index in range(4):
		var height := 0.22 * float(index + 1)
		_add_box(
			Vector2(-16.0 + float(index) * 1.15, 11.0),
			Vector3(1.25, height, 4.2),
			floor_material
		)
	_add_box(Vector2(-10.8, 11.0), Vector3(5.0, 0.88, 5.5), floor_material)

	# A chest-high obstacle intended for the mantle test.
	_add_box(Vector2(1.0, 14.5), Vector3(6.0, 1.25, 1.0), metal_material)

	# Crouch tunnel: standing will not fit, crouched capsule will.
	_add_tunnel(Vector2(15.0, 8.0), 1.42, 5.8)

	# Prone crawl: crouched capsule will not fit.
	_add_tunnel(Vector2(23.0, 8.0), 0.68, 5.8)

	# Small bunker shell behind the spawn gives the outpost a recognizable base.
	_add_box(Vector2(0.0, 27.0), Vector3(15.0, 3.4, 8.0), sandbag_material)
	_add_box(Vector2(0.0, 22.7), Vector3(5.0, 0.35, 1.1), metal_material)

func _add_tunnel(offset: Vector2, clearance: float, length: float) -> void:
	var width := 2.0
	var wall_thickness := 0.22
	var roof_thickness := 0.25
	_add_box(
		offset + Vector2(-width * 0.5, 0.0),
		Vector3(wall_thickness, clearance + roof_thickness, length),
		metal_material
	)
	_add_box(
		offset + Vector2(width * 0.5, 0.0),
		Vector3(wall_thickness, clearance + roof_thickness, length),
		metal_material
	)
	var roof_offset := offset
	var surface := _surface_local(roof_offset.x, roof_offset.y)
	var body := StaticBody3D.new()
	body.position = surface
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width + wall_thickness * 2.0, roof_thickness, length)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = clearance + roof_thickness * 0.5
	mesh_instance.material_override = metal_material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position = mesh_instance.position
	body.add_child(collision)

func _add_box(offset: Vector2, size: Vector3, material: Material) -> void:
	var surface := _surface_local(offset.x, offset.y)
	var body := StaticBody3D.new()
	body.position = surface
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = size.y * 0.5
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = mesh_instance.position
	body.add_child(collision)

func _surface_local(offset_x: float, offset_z: float) -> Vector3:
	var world_surface := planet.surface_point(
		center_tangent.x + offset_x,
		center_tangent.y + offset_z
	)
	return to_local(world_surface)
