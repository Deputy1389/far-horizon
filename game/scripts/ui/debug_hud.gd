class_name DebugHud
extends CanvasLayer

var player: FPSController
var floating_origin: FloatingOrigin
var strategy: StrategicSim

var health_label := Label.new()
var weapon_label := Label.new()
var status_label := Label.new()
var strategy_label := Label.new()
var event_label := Label.new()
var event_timer := 0.0

func configure(player_ref: FPSController, origin_ref: FloatingOrigin, strategy_ref: StrategicSim) -> void:
	player = player_ref
	floating_origin = origin_ref
	strategy = strategy_ref
	player.health_changed.connect(_on_health_changed)
	player.stance_changed.connect(_on_stance_changed)
	player.weapons.weapon_changed.connect(_on_weapon_changed)
	strategy.event_logged.connect(_on_event)
	_on_health_changed(player.health, player.maximum_health)
	_on_weapon_changed(player.weapons.current_weapon().display_name)

func _ready() -> void:
	var crosshair := Label.new()
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
	top_left.add_child(status_label)

	strategy_label.position = Vector2(20, 104)
	strategy_label.add_theme_font_size_override("font_size", 15)
	add_child(strategy_label)

	var controls := Label.new()
	controls.text = "WASD move   Shift sprint   Space jump/mantle   C crouch   Z prone   RMB ADS   LMB fire   1/2 weapons   E interact"
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(20, -38)
	controls.add_theme_font_size_override("font_size", 14)
	add_child(controls)

	event_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	event_label.position = Vector2(-430, 20)
	event_label.size = Vector2(410, 80)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(event_label)

func _process(delta: float) -> void:
	if player == null:
		return
	var lat_lon := floating_origin.latitude_longitude_degrees()
	status_label.text = "STANCE %s   SPEED %.1f m/s   LAT %.4f  LON %.4f" % [
		player.stance.to_upper(),
		Vector2(player.velocity.x, player.velocity.z).length(),
		lat_lon.x,
		lat_lon.y,
	]
	if strategy != null:
		strategy_label.text = "\n".join(strategy.summary_lines())

	event_timer = max(0.0, event_timer - delta)
	if event_timer <= 0.0:
		event_label.text = "OBJECTIVE\nEnter the city, break the Imperial garrison, then take the speeder back into the desert."

func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HEALTH  %.0f / %.0f" % [current, maximum]

func _on_weapon_changed(display_name: String) -> void:
	weapon_label.text = "WEAPON  " + display_name

func _on_stance_changed(_new_stance: String) -> void:
	pass

func _on_event(text: String) -> void:
	event_label.text = text
	event_timer = 5.0
