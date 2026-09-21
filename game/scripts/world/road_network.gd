class_name RoadNetwork
extends Node3D

@export var road_width := 8.5
@export var samples_per_route := 28

var planet: ProceduralPlanet
var strategy: StrategicSim
var road_material := StandardMaterial3D.new()

func configure(planet_ref: ProceduralPlanet, strategy_ref: StrategicSim) -> void:
	planet = planet_ref
	strategy = strategy_ref
	add_to_group("planet_anchor")
	_setup_material()
	_build_all_routes()

func _setup_material() -> void:
	road_material.albedo_color = Color(0.22, 0.19, 0.16)
	road_material.roughness = 1.0
	var texture := SwgAssetBridge.texture_for_role("road")
	if texture != null:
		road_material.albedo_texture = texture
		road_material.albedo_color = Color.WHITE

func _build_all_routes() -> void:
	for route in strategy.routes:
		var a: Dictionary = strategy.nodes[route["a"]]
		var b: Dictionary = strategy.nodes[route["b"]]
		_build_route(a["map_position"], b["map_position"])

func _build_route(a: Vector2, b: Vector2) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left_points: Array[Vector3] = []
	var right_points: Array[Vector3] = []

	var direction2 := (b - a).normalized()
	var side2 := Vector2(-direction2.y, direction2.x) * road_width * 0.5
	for index in range(samples_per_route + 1):
		var t := float(index) / float(samples_per_route)
		var center := a.lerp(b, t)
		var left2 := center + side2
		var right2 := center - side2
		left_points.append(planet.surface_point(left2.x, left2.y) + Vector3.UP * 0.055)
		right_points.append(planet.surface_point(right2.x, right2.y) + Vector3.UP * 0.055)

	for index in range(samples_per_route):
		var uv0 := float(index) * 0.7
		var uv1 := float(index + 1) * 0.7
		_add_vertex(surface, left_points[index], Vector2(0.0, uv0))
		_add_vertex(surface, left_points[index + 1], Vector2(0.0, uv1))
		_add_vertex(surface, right_points[index], Vector2(1.0, uv0))
		_add_vertex(surface, right_points[index], Vector2(1.0, uv0))
		_add_vertex(surface, left_points[index + 1], Vector2(0.0, uv1))
		_add_vertex(surface, right_points[index + 1], Vector2(1.0, uv1))

	surface.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = road_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

func _add_vertex(surface: SurfaceTool, position: Vector3, uv: Vector2) -> void:
	surface.set_uv(uv)
	surface.add_vertex(position)
