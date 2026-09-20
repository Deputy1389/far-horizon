class_name ProceduralPlanet
extends Node3D

@export var seed := 1389
@export var planet_radius := 6_000_000.0
@export var chunk_size := 220.0
@export var chunk_resolution := 17
@export var chunk_radius := 5

var origin_service: FloatingOrigin
var player: Node3D
var chunks: Dictionary = {}
var last_chunk_center := Vector2i(999999, 999999)
var update_accumulator := 0.0

var broad_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var dune_noise := FastNoiseLite.new()
var sand_material := StandardMaterial3D.new()
var rock_material := StandardMaterial3D.new()
var dressing_exclusions: Array[Vector3] = []

func configure(floating_origin: FloatingOrigin, tracked_player: Node3D) -> void:
	origin_service = floating_origin
	player = tracked_player
	planet_radius = floating_origin.planet_radius
	_setup_noise()
	_setup_material()
	origin_service.rebased.connect(_on_rebased)

func _ready() -> void:
	if broad_noise.seed == 0:
		_setup_noise()
		_setup_material()

func _setup_noise() -> void:
	broad_noise.seed = seed
	broad_noise.frequency = 0.0024
	broad_noise.fractal_octaves = 5
	broad_noise.fractal_gain = 0.52
	broad_noise.fractal_lacunarity = 2.0

	detail_noise.seed = seed + 771
	detail_noise.frequency = 0.014
	detail_noise.fractal_octaves = 3
	detail_noise.fractal_gain = 0.48

	dune_noise.seed = seed + 1907
	dune_noise.frequency = 0.052
	dune_noise.fractal_octaves = 2

func _setup_material() -> void:
	sand_material.albedo_color = Color(0.56, 0.36, 0.2)
	sand_material.roughness = 0.96
	rock_material.albedo_color = Color(0.31, 0.19, 0.12)
	rock_material.roughness = 0.98
	var imported_concrete := SwgAssetBridge.texture_for_role("concrete")
	if imported_concrete != null:
		rock_material.albedo_texture = imported_concrete
		rock_material.albedo_color = Color(0.42, 0.31, 0.23)
	var imported_sand := SwgAssetBridge.texture_for_role("sand")
	if imported_sand != null:
		sand_material.albedo_texture = imported_sand
		sand_material.albedo_color = Color.WHITE
	var imported_normal := SwgAssetBridge.texture_for_role("sandNormal")
	if imported_normal != null:
		sand_material.normal_enabled = true
		sand_material.normal_texture = imported_normal
		sand_material.normal_scale = 0.55

func add_dressing_exclusion(center: Vector2, radius: float) -> void:
	dressing_exclusions.append(Vector3(center.x, center.y, maxf(radius, 0.0)))

func generate_initial() -> void:
	_update_chunks(true)

func _process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < 0.18:
		return
	update_accumulator = 0.0
	_update_chunks(false)

func _update_chunks(force: bool) -> void:
	if player == null or origin_service == null:
		return
	var center := Vector2i(
		floori(player.global_position.x / chunk_size),
		floori(player.global_position.z / chunk_size)
	)
	if not force and center == last_chunk_center:
		return
	last_chunk_center = center

	var wanted: Dictionary = {}
	for z in range(center.y - chunk_radius, center.y + chunk_radius + 1):
		for x in range(center.x - chunk_radius, center.x + chunk_radius + 1):
			var key := Vector2i(x, z)
			wanted[key] = true
			if not chunks.has(key):
				chunks[key] = _build_chunk(key)

	for key in chunks.keys():
		if not wanted.has(key):
			var node: Node = chunks[key]
			if is_instance_valid(node):
				node.queue_free()
			chunks.erase(key)

func _build_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain_%d_%d" % [key.x, key.y]
	add_child(root)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_grid: Array[Vector3] = []
	var uv_grid: Array[Vector2] = []
	var steps: int = maxi(chunk_resolution - 1, 1)
	var start_x := float(key.x) * chunk_size
	var start_z := float(key.y) * chunk_size

	for z_index in range(chunk_resolution):
		for x_index in range(chunk_resolution):
			var fx := float(x_index) / float(steps)
			var fz := float(z_index) / float(steps)
			var local_x := start_x + fx * chunk_size
			var local_z := start_z + fz * chunk_size
			vertex_grid.append(surface_point(local_x, local_z))
			uv_grid.append(Vector2(local_x, local_z) / 18.0)

	for z_index in range(steps):
		for x_index in range(steps):
			var a := z_index * chunk_resolution + x_index
			var b := a + 1
			var c := a + chunk_resolution
			var d := c + 1
			_add_triangle(surface, vertex_grid, uv_grid, a, c, b)
			_add_triangle(surface, vertex_grid, uv_grid, b, c, d)

	surface.generate_normals()
	var mesh := surface.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = sand_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	root.add_child(body)
	_add_chunk_dressing(root, key, start_x, start_z)
	return root

func _add_chunk_dressing(root: Node3D, key: Vector2i, start_x: float, start_z: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [seed, key.x, key.y])

	var transforms: Array[Transform3D] = []
	for index in range(9):
		var local_x := start_x + rng.randf_range(8.0, chunk_size - 8.0)
		var local_z := start_z + rng.randf_range(8.0, chunk_size - 8.0)
		if _is_dressing_excluded(local_x, local_z):
			continue
		var position := surface_point(local_x, local_z)
		var yaw := rng.randf_range(0.0, TAU)
		var scale := Vector3(
			rng.randf_range(0.45, 1.7),
			rng.randf_range(0.35, 1.25),
			rng.randf_range(0.45, 1.7)
		)
		var basis := Basis(Vector3.UP, yaw).scaled(scale)
		transforms.append(Transform3D(basis, position))

	if transforms.is_empty():
		return

	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.72
	rock_mesh.height = 1.25
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4
	rock_mesh.material = rock_material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rock_mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(instance)

func _is_dressing_excluded(local_x: float, local_z: float) -> bool:
	var point := Vector2(local_x, local_z)
	for exclusion in dressing_exclusions:
		if point.distance_to(Vector2(exclusion.x, exclusion.y)) <= exclusion.z:
			return true
	return false

func _add_triangle(surface: SurfaceTool, vertices: Array[Vector3], uvs: Array[Vector2], a: int, b: int, c: int) -> void:
	for index in [a, b, c]:
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])

func surface_point(local_x: float, local_z: float) -> Vector3:
	if origin_service == null:
		return Vector3(local_x, 0.0, local_z)
	var base_ecef := PlanetMath.tangent_surface_point(
		origin_service.origin_ecef,
		origin_service.frame_basis,
		local_x,
		local_z,
		planet_radius,
		0.0
	)
	var height := _height_for_ecef(base_ecef)
	var point_ecef := PlanetMath.project_to_radius(base_ecef, planet_radius + height)
	return PlanetMath.ecef_to_local(origin_service.origin_ecef, origin_service.frame_basis, point_ecef)

func surface_y(local_x: float, local_z: float) -> float:
	return surface_point(local_x, local_z).y

func _height_for_ecef(ecef: PackedFloat64Array) -> float:
	var direction := PlanetMath.normalize64(ecef)
	var broad := broad_noise.get_noise_3d(
		float(direction[0] * 900.0),
		float(direction[1] * 900.0),
		float(direction[2] * 900.0)
	)
	var detail := detail_noise.get_noise_3d(
		float(direction[0] * 4200.0),
		float(direction[1] * 4200.0),
		float(direction[2] * 4200.0)
	)
	var dune: float = absf(dune_noise.get_noise_3d(
		float(direction[0] * 13000.0),
		float(direction[1] * 13000.0),
		float(direction[2] * 13000.0)
	))
	return broad * 28.0 + detail * 7.5 + dune * 2.5

func _on_rebased(_previous_origin: PackedFloat64Array, _new_origin: PackedFloat64Array) -> void:
	for node in chunks.values():
		if is_instance_valid(node):
			node.queue_free()
	chunks.clear()
	last_chunk_center = Vector2i(999999, 999999)
	call_deferred("_update_chunks", true)
