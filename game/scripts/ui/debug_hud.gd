class_name DebugHud
extends CanvasLayer

var player: FPSController
var floating_origin: FloatingOrigin
var strategy: StrategicSim

var health_label := Label.new()
var weapon_label := Label.new()
var heat_label := Label.new()
var status_label := Label.new()
var strategy_label := Label.new()
var event_label := Label.new()
var objective_label := Label.new()
var interaction_label := Label.new()
var crosshair := Label.new()
var damage_overlay := ColorRect.new()
var redeploy_overlay := ColorRect.new()
var redeploy_label := Label.new()

var event_timer := 0.0
var hit_marker_timer := 0.0
var kill_marker_timer := 0.0
var damage_flash_timer := 0.0
var debug_visible := false
var controls_label := Label.new()
var capture_ratio := 0.0
var capture_contested := false
var objective_captured := false

func configure(player_ref: FPSController, origin_ref: FloatingOrigin, strategy_ref: StrategicSim) -> void:
	player = player_ref
	floating_origin = origin_ref
	strategy = strategy_ref
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_player_damaged)
	player.stance_changed.connect(_on_stance_changed)
	player.weapons.weapon_changed.connect(_on_weapon_changed)
	player.weapons.hit_confirmed.connect(_on_hit_confirmed)
	player.weapons.heat_changed.connect(_on_heat_changed)
	strategy.event_logged.connect(_on_event)
	_on_health_changed(player.health, player.maximum_health)
	_on_weapon_changed(player.weapons.current_weapon().display_name)
	_on_heat_changed(player.weapons.heat, player.weapons.is_overheated())

func _ready() -> void:
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.color = Color(0.42, 0.0, 0.0, 0.0)
	add_child(damage_overlay)

	redeploy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	redeploy_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	redeploy_overlay.color = Color(0.02, 0.015, 0.012, 0.82)
	redeploy_overlay.visible = false
	add_child(redeploy_overlay)

	redeploy_label.text = "DEFEATED\nREDEPLOYING..."
	redeploy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	redeploy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	redeploy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	redeploy_label.add_theme_font_size_override("font_size", 30)
	redeploy_label.visible = false
	add_child(redeploy_label)

	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-7.0, -13.0)
	crosshair.add_theme_font_size_override("font_size", 24)
	add_child(crosshair)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(20, 18)
	top_left.add_theme_constant_override("separation", 3)
	add_child(top_left)
	top_left.add_child(health_label)
	top_left.add_child(weapon_label)
	top_left.add_child(heat_label)
	top_left.add_child(status_label)
	status_label.visible = debug_visible

	strategy_label.position = Vector2(20, 104)
	strategy_label.add_theme_font_size_override("font_size", 15)
	strategy_label.visible = debug_visible
	add_child(strategy_label)

	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-430, 118)
	objective_label.size = Vector2(410, 90)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_font_size_override("font_size", 17)
	add_child(objective_label)

	interaction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_label.position = Vector2(-150, -92)
	interaction_label.size = Vector2(300, 30)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 18)
	add_child(interaction_label)

	controls_label.text = "WASD move   Shift sprint   Space jump/mantle   C crouch   Z prone   RMB ADS   LMB fire   R vent   1/2 weapons   E interact   F3 debug"
	controls_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls_label.position = Vector2(20, -38)
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.visible = debug_visible
	add_child(controls_label)

	event_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	event_label.position = Vector2(-430, 20)
	event_label.size = Vector2(410, 80)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(event_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F3:
		debug_visible = not debug_visible
		status_label.visible = debug_visible
		strategy_label.visible = debug_visible
		controls_label.visible = debug_visible


func _process(delta: float) -> void:
	if player == null:
		return

	var lat_lon := floating_origin.latitude_longitude_degrees()
	var display_velocity := player.velocity
	if player.active_vehicle is CharacterBody3D:
		display_velocity = (player.active_vehicle as CharacterBody3D).velocity
	status_label.text = "STANCE %s   SPEED %.1f m/s   FPS %d   TICK %d   INPUT %.1f,%.1f   Y %.1f   FLOOR %s   LAT %.4f  LON %.4f" % [
		player.stance.to_upper(),
		Vector2(display_velocity.x, display_velocity.z).length(),
		Engine.get_frames_per_second(),
		player.physics_tick_count,
		player.last_move_input.x,
		player.last_move_input.y,
		player.global_position.y,
		"YES" if player.is_on_floor() else "NO",
		lat_lon.x,
		lat_lon.y,
	]
	if strategy != null:
		strategy_label.text = "\n".join(strategy.summary_lines())

	_update_objective()
	_update_interaction_prompt()
	event_timer = maxf(0.0, event_timer - delta)
	hit_marker_timer = maxf(0.0, hit_marker_timer - delta)
	kill_marker_timer = maxf(0.0, kill_marker_timer - delta)
	damage_flash_timer = maxf(0.0, damage_flash_timer - delta)

	if kill_marker_timer > 0.0:
		crosshair.text = "✕"
		crosshair.modulate = Color(1.0, 0.25, 0.12)
	elif hit_marker_timer > 0.0:
		crosshair.text = "×"
		crosshair.modulate = Color(1.0, 0.82, 0.56)
	else:
		crosshair.text = "+"
		crosshair.modulate = Color.WHITE

	var damage_alpha := clampf(damage_flash_timer / 0.22, 0.0, 1.0) * 0.24
	damage_overlay.color = Color(0.42, 0.0, 0.0, damage_alpha)

	if event_timer <= 0.0:
		event_label.text = "OBJECTIVE\nEnter the city, break the Imperial garrison, then take the speeder back into the desert."

func _update_objective() -> void:
	if objective_captured:
		objective_label.text = "GARRISON SECURED\nReturn to the speeder and push back into the desert."
		return
	if strategy == null or floating_origin == null:
		return

	var city_node: Dictionary = strategy.nodes.get("mos_eisley", {})
	if city_node.is_empty():
		return
	var planet_position: PackedFloat64Array = city_node["planet_position"]
	var city_local := floating_origin.local_position(planet_position)
	var distance := Vector2(
		city_local.x - player.global_position.x,
		city_local.z - player.global_position.z
	).length()

	if capture_ratio > 0.0 or distance < 60.0:
		var state := "CONTESTED — CLEAR NEARBY IMPERIALS" if capture_contested else "SECURING"
		objective_label.text = "IMPERIAL GARRISON  %.0f m\n%s  %d%%" % [
			distance,
			state,
			int(round(capture_ratio * 100.0)),
		]
	else:
		objective_label.text = "IMPERIAL GARRISON  %.0f m\nFollow the road into the city." % distance

func _update_interaction_prompt() -> void:
	var nearest_distance := 4.0
	var prompt := ""
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate is Node3D:
			continue
		var node := candidate as Node3D
		var distance := player.global_position.distance_to(node.global_position)
		if distance > nearest_distance or not node.has_method("interaction_text"):
			continue
		var candidate_prompt := String(node.interaction_text())
		if candidate_prompt.is_empty():
			continue
		nearest_distance = distance
		prompt = candidate_prompt
	interaction_label.text = prompt

func show_redeploy() -> void:
	redeploy_overlay.visible = true
	redeploy_label.visible = true
	crosshair.visible = false

func hide_redeploy() -> void:
	redeploy_overlay.visible = false
	redeploy_label.visible = false
	crosshair.visible = true


func confirm_kill() -> void:
	kill_marker_timer = 0.18
	hit_marker_timer = 0.0


func set_capture_progress(ratio: float, contested: bool) -> void:
	capture_ratio = clampf(ratio, 0.0, 1.0)
	capture_contested = contested

func mark_objective_captured() -> void:
	objective_captured = true
	capture_ratio = 1.0
	capture_contested = false

func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HEALTH  %.0f / %.0f" % [current, maximum]

func _on_weapon_changed(display_name: String) -> void:
	weapon_label.text = display_name.to_upper()

func _on_heat_changed(value: float, overheated: bool) -> void:
	var bars := int(round(clampf(value, 0.0, 1.0) * 10.0))
	var meter := "[" + "#".repeat(bars) + "-".repeat(10 - bars) + "]"
	heat_label.text = ("OVERHEATED  " if overheated else "BLASTER  ") + meter
	heat_label.modulate = Color(1.0, 0.45, 0.25) if overheated else Color(0.9, 0.88, 0.78)

func _on_stance_changed(_new_stance: String) -> void:
	pass

func _on_hit_confirmed() -> void:
	hit_marker_timer = 0.09

func _on_player_damaged(_amount: float) -> void:
	damage_flash_timer = 0.22

func _on_event(text: String) -> void:
	event_label.text = text
	event_timer = 5.0
