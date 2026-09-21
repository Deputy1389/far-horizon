class_name CapturePoint
extends Area3D

signal captured(faction: String)
signal progress_changed(ratio: float, contested: bool)

@export var node_id := "mos_eisley"
@export var capture_seconds := 7.0
@export var radius := 11.0

var strategy: StrategicSim
var progress := 0.0
var completed := false
var last_ratio := -1.0
var last_contested := false

func configure(sim: StrategicSim, strategic_node_id: String) -> void:
	strategy = sim
	node_id = strategic_node_id

func _ready() -> void:
	add_to_group("planet_anchor")
	collision_layer = 0
	collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 3.0
	shape_node.shape = shape
	shape_node.position.y = 1.5
	add_child(shape_node)

	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.6
	mesh.bottom_radius = 1.6
	mesh.height = 0.12
	marker.mesh = mesh
	marker.position.y = 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.15, 0.08, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.8, 0.05, 0.02)
	marker.material_override = material
	add_child(marker)

	_emit_progress(false, true)

func _physics_process(delta: float) -> void:
	if completed or strategy == null:
		return

	var player_inside := false
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_inside = true
			break

	if not player_inside:
		progress = maxf(0.0, progress - delta * 0.5)
		_emit_progress(false)
		return

	var contested := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node3D and global_position.distance_to((enemy as Node3D).global_position) < radius * 3.2:
			contested = true
			break

	if contested:
		progress = maxf(0.0, progress - delta * 0.35)
		_emit_progress(true)
		return

	progress = minf(capture_seconds, progress + delta)
	_emit_progress(false)
	if progress >= capture_seconds:
		completed = true
		strategy.apply_local_result(node_id, "rebel", 145.0)
		captured.emit("rebel")

func _emit_progress(contested: bool, force: bool = false) -> void:
	var ratio := clampf(progress / maxf(capture_seconds, 0.001), 0.0, 1.0)
	if force or absf(ratio - last_ratio) >= 0.01 or contested != last_contested:
		last_ratio = ratio
		last_contested = contested
		progress_changed.emit(ratio, contested)
