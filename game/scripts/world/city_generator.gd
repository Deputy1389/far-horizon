class_name CityGenerator
extends Node3D

@export var seed := 44117
@export var road_spacing := 62.0
@export var grid_radius := 4
@export var city_half_extent := 330.0

var planet: ProceduralPlanet
var center_tangent := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var combat_spawns: Array[Vector3] = []
var garrison_local := Vector3.ZERO

var wall_material := StandardMaterial3D.new()
var roof_material := StandardMaterial3D.new()
var road_material := StandardMaterial3D.new()
var accent_material := StandardMaterial3D.new()
var landmark_material := StandardMaterial3D.new()

func configure(planet_ref: ProceduralPlanet, center_xz: Vector2) -> void:
	planet = planet_ref
	center_tangent = center_xz
	rng.seed = seed
	_setup_materials()
	var center_surface := planet.surface_point(center_tangent.x, center_tangent.y)
	global_position = center_surface
	add_to_group("planet_anchor")
	_generate()

func _setup_materials() -> void:
	wall_material.albedo_color = Color(0.46, 0.34, 0.24)
	wall_material.roughness = 0.95
	roof_material.albedo_color = Color(0.30, 0.27, 0.23)
	roof_material.roughness = 0.88
	road_material.albedo_color = Color(0.19, 0.18, 0.16)
	road_material.roughness = 1.0
	accent_material.albedo_color = Color(0.22, 0.25, 0.25)
	accent_material.metallic = 0.35
	accent_material.roughness = 0.62
	landmark_material.albedo_color = Color(0.52, 0.42, 0.31)
	landmark_material.roughness = 0.9

	var capital_texture := SwgAssetBridge.texture_for_role("capitalWall")
	if capital_texture != null:
		landmark_material.albedo_texture = capital_texture
		landmark_material.albedo_color = Color.WHITE
	var wall_texture := SwgAssetBridge.texture_for_role("wall")
	if wall_texture != null:
		wall_material.albedo_texture = wall_texture
		wall_material.albedo_color = Color.WHITE
	var roof_texture := SwgAssetBridge.texture_for_role("floor")
	if roof_texture != null:
		roof_material.albedo_texture = roof_texture
		roof_material.albedo_color = Color.WHITE
	var road_texture := SwgAssetBridge.texture_for_role("road")
	if road_texture != null:
		road_material.albedo_texture = road_texture
		road_material.albedo_color = Color.WHITE
	var metal_texture := SwgAssetBridge.texture_for_role("metal")
	if metal_texture != null:
		accent_material.albedo_texture = metal_texture
		accent_material.albedo_color = Color.WHITE

func _generate() -> void:
	_generate_roads()
	_generate_blocks()
	_generate_landmark()
	_generate_garrison()
	_generate_cover()
	_place_imported_environment_proof()

func _generate_roads() -> void:
	var span := city_half_extent * 2.0 + road_spacing
	for index in range(-grid_radius, grid_radius + 1):
		var axis := float(index) * road_spacing
		_add_road(Vector2(axis, 0.0), Vector2(10.0, span))
		_add_road(Vector2(0.0, axis), Vector2(span, 10.0))

func _add_road(offset: Vector2, size_xz: Vector2) -> void:
	var surface := _surface_local(offset.x, offset.y)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_xz.x, 0.16, size_xz.y)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = road_material
	mesh_instance.position = surface + Vector3.UP * 0.04
	add_child(mesh_instance)

func _generate_blocks() -> void:
	for gx in range(-grid_radius, grid_radius):
		for gz in range(-grid_radius, grid_radius):
			var block_center := Vector2(
				(float(gx) + 0.5) * road_spacing,
				(float(gz) + 0.5) * road_spacing
			)
			if block_center.length() < 82.0:
				continue
			if rng.randf() < 0.14 and block_center.length() > 170.0:
				continue
			var building_count := 1 + int(rng.randf() > 0.42)
			for building_index in range(building_count):
				var jitter := Vector2(
					rng.randf_range(-16.0, 16.0),
					rng.randf_range(-16.0, 16.0)
				)
				var width := rng.randf_range(18.0, 32.0)
				var depth := rng.randf_range(16.0, 30.0)
				var height := rng.randf_range(7.0, 15.0)
				if block_center.length() < 155.0:
					height *= rng.randf_range(1.15, 1.6)
				_add_building(block_center + jitter, Vector3(width, height, depth))

func _add_building(offset: Vector2, size: Vector3) -> void:
	var root := Node3D.new()
	root.position = _surface_local(offset.x, offset.y)
	add_child(root)

	var body_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body_mesh.mesh = box
	body_mesh.position.y = size.y * 0.5
	body_mesh.material_override = wall_material
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(body_mesh)

	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	static_body.add_child(collision)
	root.add_child(static_body)

	if rng.randf() > 0.5:
		var roof := MeshInstance3D.new()
		var roof_box := BoxMesh.new()
		roof_box.size = Vector3(size.x * 0.5, rng.randf_range(1.4, 2.8), size.z * 0.48)
		roof.mesh = roof_box
		roof.position = Vector3(
			rng.randf_range(-size.x * 0.12, size.x * 0.12),
			size.y + roof_box.size.y * 0.5,
			rng.randf_range(-size.z * 0.12, size.z * 0.12)
		)
		roof.material_override = roof_material
		root.add_child(roof)

	if rng.randf() > 0.70:
		var dome := MeshInstance3D.new()
		var dome_mesh := SphereMesh.new()
		var dome_radius := rng.randf_range(2.4, minf(size.x, size.z) * 0.22)
		dome_mesh.radius = dome_radius
		dome_mesh.height = dome_radius * 2.0
		dome_mesh.radial_segments = 12
		dome_mesh.rings = 6
		dome.mesh = dome_mesh
		dome.scale = Vector3(1.0, 0.46, 1.0)
		dome.position = Vector3(
			rng.randf_range(-size.x * 0.18, size.x * 0.18),
			size.y + dome_radius * 0.08,
			rng.randf_range(-size.z * 0.18, size.z * 0.18)
		)
		dome.material_override = wall_material
		root.add_child(dome)

	if rng.randf() > 0.74:
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.12
		mast_mesh.bottom_radius = 0.16
		mast_mesh.height = rng.randf_range(3.5, 7.5)
		mast_mesh.radial_segments = 6
		mast.mesh = mast_mesh
		mast.position = Vector3(
			rng.randf_range(-size.x * 0.28, size.x * 0.28),
			size.y + mast_mesh.height * 0.5,
			rng.randf_range(-size.z * 0.28, size.z * 0.28)
		)
		mast.material_override = accent_material
		root.add_child(mast)

	if rng.randf() > 0.66:
		var awning := MeshInstance3D.new()
		var awning_mesh := BoxMesh.new()
		awning_mesh.size = Vector3(size.x * 0.6, 0.18, 2.4)
		awning.mesh = awning_mesh
		awning.position = Vector3(0.0, min(3.1, size.y * 0.55), -size.z * 0.5 - 1.15)
		awning.material_override = accent_material
		root.add_child(awning)

func _generate_landmark() -> void:
	var offset := Vector2(118.0, -92.0)
	var root := Node3D.new()
	root.name = "StarportLandmark"
	root.position = _surface_local(offset.x, offset.y)
	add_child(root)

	var base_body := StaticBody3D.new()
	root.add_child(base_body)

	var base_mesh_instance := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(54.0, 10.0, 46.0)
	base_mesh_instance.mesh = base_mesh
	base_mesh_instance.position.y = 5.0
	base_mesh_instance.material_override = landmark_material
	base_body.add_child(base_mesh_instance)

	var base_collision := CollisionShape3D.new()
	var base_shape := BoxShape3D.new()
	base_shape.size = base_mesh.size
	base_collision.shape = base_shape
	base_collision.position = base_mesh_instance.position
	base_body.add_child(base_collision)

	var tower_body := StaticBody3D.new()
	tower_body.position = Vector3(7.0, 0.0, -2.0)
	root.add_child(tower_body)

	var tower_mesh_instance := MeshInstance3D.new()
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 5.2
	tower_mesh.bottom_radius = 7.8
	tower_mesh.height = 42.0
	tower_mesh.radial_segments = 12
	tower_mesh_instance.mesh = tower_mesh
	tower_mesh_instance.position.y = 26.0
	tower_mesh_instance.material_override = landmark_material
	tower_body.add_child(tower_mesh_instance)

	var tower_collision := CollisionShape3D.new()
	var tower_shape := CylinderShape3D.new()
	tower_shape.radius = 7.8
	tower_shape.height = 42.0
	tower_collision.shape = tower_shape
	tower_collision.position = tower_mesh_instance.position
	tower_body.add_child(tower_collision)

	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.22
	spire_mesh.bottom_radius = 0.42
	spire_mesh.height = 14.0
	spire_mesh.radial_segments = 6
	spire.mesh = spire_mesh
	spire.position = Vector3(7.0, 54.0, -2.0)
	spire.material_override = accent_material
	root.add_child(spire)

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 38.0
	pad_mesh.bottom_radius = 38.0
	pad_mesh.height = 0.18
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.position = Vector3(-34.0, 0.12, 9.0)
	pad.material_override = road_material
	root.add_child(pad)

func _generate_garrison() -> void:
	garrison_local = _surface_local(0.0, 0.0)
	var root := Node3D.new()
	root.name = "ImperialGarrison"
	root.position = garrison_local
	add_child(root)

	var main := MeshInstance3D.new()
	var main_mesh := BoxMesh.new()
	main_mesh.size = Vector3(46.0, 13.0, 34.0)
	main.mesh = main_mesh
	# Keep the objective courtyard at the compound center open and put the
	# command building on the north side instead of making the capture point
	# live inside a solid collision box.
	main.position = Vector3(0.0, 6.5, -30.0)
	main.material_override = wall_material
	root.add_child(main)

	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = main_mesh.size
	collision.shape = shape
	collision.position = Vector3(0.0, 6.5, -30.0)
	static_body.add_child(collision)
	root.add_child(static_body)

	for x in [-29.0, 29.0]:
		for z in [-23.0, 23.0]:
			_add_guard_tower(Vector3(x, 0.0, z), root)

	for index in range(8):
		var angle := float(index) / 8.0 * TAU
		combat_spawns.append(root.global_position + Vector3(cos(angle) * 46.0, 1.0, sin(angle) * 38.0))

func _add_guard_tower(local_position: Vector3, parent: Node3D) -> void:
	var tower := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.6
	mesh.bottom_radius = 4.2
	mesh.height = 11.0
	tower.mesh = mesh
	tower.position = local_position + Vector3.UP * 5.5
	tower.material_override = accent_material
	parent.add_child(tower)

func _generate_cover() -> void:
	for index in range(54):
		var offset := Vector2(
			rng.randf_range(-city_half_extent, city_half_extent),
			rng.randf_range(-city_half_extent, city_half_extent)
		)
		if abs(fmod(abs(offset.x), road_spacing) - road_spacing * 0.5) < 12.0:
			continue
		var surface := _surface_local(offset.x, offset.y)
		var cover := StaticBody3D.new()
		cover.position = surface
		add_child(cover)

		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(1.5, 3.5), rng.randf_range(0.8, 1.35), rng.randf_range(1.4, 3.2))
		mesh_instance.mesh = mesh
		mesh_instance.position.y = mesh.size.y * 0.5
		mesh_instance.material_override = accent_material
		cover.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		collision.position = mesh_instance.position
		cover.add_child(collision)

func _surface_local(offset_x: float, offset_z: float) -> Vector3:
	var world_surface := planet.surface_point(
		center_tangent.x + offset_x,
		center_tangent.y + offset_z
	)
	return to_local(world_surface)

func garrison_global_position() -> Vector3:
	return to_global(garrison_local)

func _place_imported_environment_proof() -> void:
	var proof := SwgAssetBridge.instantiate_mesh_proof()
	if proof == null:
		return
	proof.position = _surface_local(-74.0, 92.0)
	proof.scale = Vector3.ONE * 1.15
	add_child(proof)
