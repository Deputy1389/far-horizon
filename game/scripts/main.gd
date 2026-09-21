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
var infantry_spawn_map := Vector2.ZERO
var reinforcement_waves_remaining := 2
var reinforcement_serial := 0
var ambience_audio := AudioStreamPlayer.new()
@onready var startup_overlay: CanvasLayer = $StartupOverlay
@onready var startup_status: Label = $StartupOverlay/Status

func _ready() -> void:
	_stage("Installing input map...")
	_install_input_map()
	_stage("Creating desert sky and lighting...")
	_build_environment()
	await get_tree().process_frame
	await _build_foundation_world()

func _stage(text: String) -> void:
	print("FOUNDATION_STAGE " + text)
	if startup_status != null:
		startup_status.text = text

func _build_environment() -> void:
	var ambience := SwgAssetBridge.audio_for_role("tatooineAmbience")
	if ambience != null:
		ambience_audio.stream = ambience
		ambience_audio.volume_db = -18.0
		ambience_audio.finished.connect(_restart_ambience)
		add_child(ambience_audio)
		ambience_audio.play()

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.39, 0.62)
	sky_material.sky_horizon_color = Color(0.88, 0.58, 0.34)
	sky_material.ground_horizon_color = Color(0.49, 0.31, 0.20)
	sky_material.ground_bottom_color = Color(0.17, 0.11, 0.08)
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.57, 0.50)
	environment.ambient_light_energy = 0.42
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.58, 0.43, 0.34)
	environment.fog_density = 0.00032
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.80)
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	add_child(sun)

	var second_sun := DirectionalLight3D.new()
	second_sun.rotation_degrees = Vector3(-28.0, 34.0, 0.0)
	second_sun.light_color = Color(1.0, 0.56, 0.32)
	second_sun.light_energy = 0.10
	second_sun.shadow_enabled = false
	add_child(second_sun)

func _restart_ambience() -> void:
	if ambience_audio.stream != null:
		ambience_audio.play()


func _build_foundation_world() -> void:
	_stage("Initializing spherical planet coordinates...")
	floating_origin = FloatingOrigin.new()
	floating_origin.name = "FloatingOrigin"
	add_child(floating_origin)
	floating_origin.configure(6_000_000.0, 11.0, 42.0)

	_stage("Creating first-person controller...")
	player = FPSController.new()
	add_child(player)
	player.global_position = Vector3(0.0, 6.0, 0.0)
	floating_origin.track(player)

	# Strategic data owns the meaningful map coordinates. The physical world is
	# projected from those coordinates instead of duplicating city/base numbers
	# in the scene bootstrap.
	_stage("Starting planetary war simulation...")
	strategy = StrategicSim.new()
	add_child(strategy)
	strategy.configure(floating_origin)
	strategy.force_updated.connect(_on_force_updated)
	strategy.force_destroyed.connect(_on_force_destroyed)
	strategy.initialize_default_war()

	# Put a real camera/HUD on screen before doing procedural mesh/collision work.
	# This prevents a long-looking gray window while the first terrain ring builds.
	_stage("Bringing HUD online...")
	hud = DebugHud.new()
	add_child(hud)
	hud.configure(player, floating_origin, strategy)
	strategy.event_logged.emit("Preparing Tatooine surface and Mos Eisley combat space...")
	await get_tree().process_frame

	var rebel_node: Dictionary = strategy.nodes["rebel_outpost"]
	var city_node: Dictionary = strategy.nodes["mos_eisley"]
	var rebel_map: Vector2 = rebel_node["map_position"]
	var city_map: Vector2 = city_node["map_position"]
	# For the infantry prototype, spawn at a forward staging point close enough
	# to reach combat immediately. The full strategic outpost still exists
	# behind the player and remains the regional control node.
	infantry_spawn_map = city_map.lerp(rebel_map, 0.30)

	_stage("Generating nearby spherical terrain...")
	planet = ProceduralPlanet.new()
	planet.name = "ProceduralPlanet"
	add_child(planet)
	planet.configure(floating_origin, player)
	planet.add_dressing_exclusion(rebel_map, 65.0)
	planet.add_dressing_exclusion(city_map, 390.0)
	planet.generate_initial()
	player.global_position = planet.surface_point(infantry_spawn_map.x, infantry_spawn_map.y) + Vector3.UP * 0.18
	print("FOUNDATION_SPAWN player=%s terrain_y=%.3f" % [str(player.global_position), planet.surface_y(player.global_position.x, player.global_position.z)])

	_stage("Building Rebel staging area...")
	rebel_outpost = RebelOutpost.new()
	rebel_outpost.name = "RebelOutpost"
	add_child(rebel_outpost)
	rebel_outpost.configure(planet, rebel_map)

	_stage("Generating Mos Eisley combat district...")
	city = CityGenerator.new()
	city.name = "MosEisleyPrototype"
	add_child(city)
	city.configure(planet, city_map)

	_stage("Spawning tactical AI...")
	squads = SquadManager.new()
	add_child(squads)
	squads.squad_cleared.connect(_on_squad_cleared)

	_stage("Connecting strategic road network...")
	roads = RoadNetwork.new()
	add_child(roads)
	roads.configure(planet, strategy)

	_stage("Materializing Imperial garrison...")
	_spawn_enemies()
	_stage("Creating objective and speeder...")
	_spawn_capture_point()
	_spawn_speeder(infantry_spawn_map)

	if capture_point != null:
		capture_point.progress_changed.connect(hud.set_capture_progress)
		hud.set_capture_progress(capture_point.progress / maxf(capture_point.capture_seconds, 0.001), false)

	_stage("Finalizing playable foundation...")
	player.died.connect(_respawn_player)
	strategy.event_logged.emit("Foundation ready. Follow the road south to the Imperial garrison.")
	print("FOUNDATION_READY chunks=%d enemies=%d" % [planet.chunks.size(), squads.active_member_count()])
	if startup_overlay != null:
		startup_overlay.visible = false

func _spawn_enemies() -> void:
	var positions := city.combat_spawns
	for index in range(min(positions.size(), 8)):
		var squad_id := "garrison_a" if index < 4 else "garrison_b"
		_spawn_enemy(positions[index], squad_id)

	# Guarantee an obvious first contact on the approach to the objective.
	# The garrison ring can be hidden behind procedural buildings, so a small
	# patrol is placed directly between the forward spawn and the city center.
	var garrison := city.garrison_global_position()
	var forward := garrison - player.global_position
	forward.y = 0.0
	if forward.length_squared() > 1.0:
		forward = forward.normalized()
		var side := Vector3.UP.cross(forward).normalized()
		var distances := [48.0, 58.0, 68.0]
		var lateral := [-5.0, 4.0, 0.0]
		for index in range(distances.size()):
			var patrol_distance: float = float(distances[index])
			var lateral_offset: float = float(lateral[index])
			var patrol_position: Vector3 = player.global_position + forward * patrol_distance + side * lateral_offset
			patrol_position.y = planet.surface_y(patrol_position.x, patrol_position.z) + 0.15
			_spawn_enemy(patrol_position, "approach_patrol")

func _spawn_enemy(spawn_position: Vector3, squad_id: String) -> void:
	var soldier := EnemySoldier.new()
	add_child(soldier)
	var spawn := spawn_position
	spawn.y += 0.15
	soldier.configure(player, squads, squad_id, spawn)
	soldier.killed.connect(_on_imperial_soldier_killed)

func _spawn_capture_point() -> void:
	capture_point = CapturePoint.new()
	add_child(capture_point)
	capture_point.global_position = city.garrison_global_position() + Vector3(0.0, 0.2, 0.0)
	capture_point.configure(strategy, "mos_eisley")
	capture_point.captured.connect(_on_capture_completed)

func _spawn_speeder(spawn_map: Vector2) -> void:
	var speeder := Speeder.new()
	add_child(speeder)
	var speeder_map := spawn_map + Vector2(8.0, -9.0)
	var point := planet.surface_point(speeder_map.x, speeder_map.y)
	speeder.global_position = point + Vector3.UP * 1.5
	speeder.rotation.y = PI

func _respawn_player() -> void:
	player.set_physics_process(false)
	player.weapons.set_enabled(false)
	player.velocity = Vector3.ZERO
	if hud != null:
		hud.show_redeploy()
	await get_tree().create_timer(1.6).timeout
	player.restore_full_health()
	player.global_position = planet.surface_point(infantry_spawn_map.x, infantry_spawn_map.y) + Vector3.UP * 0.12
	player.set_physics_process(true)
	player.weapons.set_enabled(true)
	if hud != null:
		hud.hide_redeploy()
	strategy.apply_local_result("rebel_outpost", "imperial", 4.0)
	strategy.event_logged.emit("Redeployed at the forward staging point. Get back into the fight.")

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
	_bind_key("vent", KEY_R)
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

func _on_squad_cleared(_squad_id: String) -> void:
	if reinforcement_waves_remaining <= 0 or capture_point == null or capture_point.completed:
		return
	reinforcement_waves_remaining -= 1
	reinforcement_serial += 1
	var wave_id := "reinforcement_%d" % reinforcement_serial
	strategy.event_logged.emit("Imperial reinforcements inbound.")
	await get_tree().create_timer(2.8).timeout
	if capture_point == null or capture_point.completed:
		return
	var positions := city.combat_spawns
	if positions.is_empty():
		return
	var start := (reinforcement_serial * 3) % positions.size()
	for offset in range(min(4, positions.size())):
		var index := (start + offset * 2) % positions.size()
		_spawn_enemy(positions[index], wave_id)


func _on_imperial_soldier_killed(_soldier: EnemySoldier) -> void:
	strategy.apply_casualties("mos_eisley", "imperial", 3.0)
	if hud != null:
		hud.confirm_kill()

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
