extends Node3D

var preview: EnemySoldier
var manager: SquadManager
var dummy_player := Node3D.new()
var camera := Camera3D.new()
var selected_animation := "idle"
var label := Label.new()
var status := Label.new()

const ANIMATIONS := [
	"idle",
	"walk_forward",
	"walk_back",
	"strafe_left",
	"strafe_right",
	"run_forward",
	"fire",
]

func _ready() -> void:
	_build_environment()
	_build_ui()

	manager = SquadManager.new()
	add_child(manager)
	add_child(dummy_player)
	dummy_player.position = Vector3(0.0, 0.0, -8.0)

	preview = EnemySoldier.new()
	preview.set_physics_process(false)
	preview.configure(dummy_player, manager, "character_lab", Vector3.ZERO)
	add_child(preview)
	await get_tree().process_frame
	preview._set_animation(selected_animation)
	_refresh_status()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.11, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.64)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	fill.light_energy = 0.38
	add_child(fill)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18.0, 18.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.16, 0.17, 0.19)
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	add_child(floor)

	camera.position = Vector3(0.0, 1.45, 4.8)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 20)
	label.text = "CHARACTER LAB"
	layer.add_child(label)

	status.position = Vector2(18, 54)
	status.add_theme_font_size_override("font_size", 15)
	layer.add_child(status)

	var help := Label.new()
	help.position = Vector2(18, 680)
	help.add_theme_font_size_override("font_size", 14)
	help.text = "1 idle   2 forward   3 back   4 strafe L   5 strafe R   6 run   7 fire   Q/E rotate   Esc quit"
	layer.add_child(help)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_7:
		var index := key - KEY_1
		if index >= 0 and index < ANIMATIONS.size():
			selected_animation = ANIMATIONS[index]
			preview._set_animation(selected_animation, selected_animation != "fire")
			_refresh_status()
	elif key == KEY_Q:
		preview.rotate_y(deg_to_rad(15.0))
	elif key == KEY_E:
		preview.rotate_y(deg_to_rad(-15.0))
	elif key == KEY_ESCAPE:
		get_tree().quit()

func _refresh_status() -> void:
	if preview == null:
		return
	var available: Array[String] = []
	if preview.animation_player != null:
		for animation_name in preview.animation_player.get_animation_list():
			available.append(String(animation_name))
	status.text = "Selected: %s\nweapon hold bone: %d\nfallback wrist: %d\nAvailable clips: %s" % [
		selected_animation,
		preview.weapon_hold_bone,
		preview.fallback_wrist_bone,
		", ".join(available),
	]
