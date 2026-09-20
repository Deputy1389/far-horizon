extends Node3D

var floating_origin: FloatingOrigin
var planet: ProceduralPlanet
var player: FPSController
var city: CityGenerator
var roads: RoadNetwork
var rebel_outpost: RebelOutpost
var squads: SquadManager
var strategy: StrategicSim
var capture_point: CapturePoint
var hud: DebugHud
var convoy_proxies: Dictionary = {}

func _ready() -> void:
	_install_input_map()
	_build_environment()
	_build_foundation_world()

func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.36, 0.22, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.66, 0.5)
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.69, 0.47, 0.31)
	environment.fog_density = 0.00045
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.83, 0.67)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

func _build_foundation_world() -> void:
	floating_origin = FloatingOrigin.new()
	floating_origin.name = "FloatingOrigin"
	add_child(floating_origin)
	floating_origin.configure(6_000_000.0, 11.0, 42.0)

	player = FPSController.new()
	add_child(player)
	player.global_position = Vector3(0.0, 6.0, 180.0)
	floating_origin.track(player)

	planet = ProceduralPlanet.new()
	planet.name = "ProceduralPlanet"
	add_child(planet)
	planet.configure(floating_origin, player)
	planet.generate_initial()
	player.global_position = planet.surface_point(0.0, 180.0) + Vector3.UP * 0.08

	rebel_outpost = RebelOutpost.new()
	rebel_outpost.name = "RebelOutpost"
	add_child(rebel_outpost)
	rebel_outpost.configure(planet, Vector2(0.0, 180.0))

	city = CityGenerator.new()
	city.name = "MosEisleyPrototype"
	add_child(city)
	city.configure(planet, Vector2(0.0, -260.0))

	squads = SquadManager.new()
	add_child(squads)

	strategy = StrategicSim.new()
	add_child(strategy)
	strategy.configure(floating_origin)
	strategy.force_updated.connect(_on_force_updated)
	strategy.force_destroyed.connect(_on_force_destroyed)
	strategy.initialize_default_war()

	roads = RoadNetwork.new()
	add_child(roads)
	roads.configure(planet, strategy)

	_spawn_enemies()
	_spawn_capture_point()
	_spawn_speeder()

	hud = DebugHud.new()
	add_child(hud)
	hud.configure(player, floating_origin, strategy)
	if capture_point != null:
		capture_point.progress_changed.connect(hud.set_capture_progress)
		hud.set_capture_progress(capture_point.progress / maxf(capture_point.capture_seconds, 0.001), false)

	player.died.connect(_respawn_player)

func _spawn_enemies() -> void:
	var positions := city.combat_spawns
	for index in range(min(positions.size(), 8)):
		var soldier := EnemySoldier.new()
		var squad_id := "garrison_a" if index < 4 else "garrison_b"
		add_child(soldier)
		var spawn := positions[index]
		spawn.y += 0.15
		soldier.configure(player, squads, squad_id, spawn)

func _spawn_capture_point() -> void:
	capture_point = CapturePoint.new()
	add_child(capture_point)
	capture_point.global_position = city.garrison_global_position() + Vector3(0.0, 0.2, 0.0)
	capture_point.configure(strategy, "mos_eisley")
	capture_point.captured.connect(_on_capture_completed)

func _spawn_speeder() -> void:
	var speeder := Speeder.new()
	add_child(speeder)
	var point := planet.surface_point(11.0, 165.0)
	speeder.global_position = point + Vector3.UP * 1.5
	speeder.rotation.y = PI

func _respawn_player() -> void:
	player.restore_full_health()
	player.velocity = Vector3.ZERO
	var rebel_node: Dictionary = strategy.nodes.get("rebel_outpost", {})
	if not rebel_node.is_empty():
		var base_ecef: PackedFloat64Array = rebel_node["planet_position"]
		var base_local := floating_origin.local_position(base_ecef)
		base_local.y = planet.surface_y(base_local.x, base_local.z)
		player.global_position = base_local + Vector3.UP * 0.08
	else:
		player.global_position = planet.surface_point(0.0, 180.0) + Vector3.UP * 0.08
	strategy.apply_local_result("rebel_outpost", "imperial", 4.0)
	strategy.event_logged.emit("You redeployed at the Rebel outpost. The failed assault cost local strength.")

func _install_input_map() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("jump", KEY_SPACE)
	_bind_key("crouch", KEY_C)
	_bind_key("prone", KEY_Z)
	_bind_key("interact", KEY_E)
	_bind_key("weapon_1", KEY_1)
	_bind_key("weapon_2", KEY_2)
	_bind_key("pause_mouse", KEY_ESCAPE)
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)

func _bind_key(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)

func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _on_capture_completed(_faction: String) -> void:
	if hud != null:
		hud.mark_objective_captured()
	strategy.event_logged.emit("Mos Eisley garrison objective secured. Strategic balance shifted toward the Rebels.")

func _on_force_updated(force_id: String, planet_position: PackedFloat64Array, faction: String, strength: float) -> void:
	var local_position := floating_origin.local_position(planet_position)
	local_position.y = planet.surface_y(local_position.x, local_position.z)
	var horizontal_distance := Vector2(
		local_position.x - player.global_position.x,
		local_position.z - player.global_position.z
	).length()

	if horizontal_distance > 680.0 or strength <= 0.0:
		if convoy_proxies.has(force_id):
			var stale = convoy_proxies[force_id]
			if is_instance_valid(stale):
				stale.queue_free()
			convoy_proxies.erase(force_id)
		return

	var proxy: StrategicConvoyProxy
	if convoy_proxies.has(force_id) and is_instance_valid(convoy_proxies[force_id]):
		proxy = convoy_proxies[force_id]
	else:
		proxy = StrategicConvoyProxy.new()
		add_child(proxy)
		proxy.configure(strategy, force_id, faction, strength, local_position + Vector3.UP * 1.2)
		convoy_proxies[force_id] = proxy
	proxy.set_target(local_position + Vector3.UP * 1.2, strength)

func _on_force_destroyed(force_id: String) -> void:
	if convoy_proxies.has(force_id):
		var proxy = convoy_proxies[force_id]
		if is_instance_valid(proxy):
			proxy.queue_free()
		convoy_proxies.erase(force_id)
