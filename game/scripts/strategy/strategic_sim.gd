class_name StrategicSim
extends Node

signal event_logged(text: String)
signal control_changed(node_id: String, owner: String)
signal force_updated(force_id: String, planet_position: PackedFloat64Array, faction: String, strength: float)
signal force_destroyed(force_id: String)

@export var simulation_tick_seconds := 1.0

var origin_service: FloatingOrigin
var nodes: Dictionary = {}
var routes: Array[Dictionary] = []
var forces: Array[Dictionary] = []
var accumulator := 0.0
var campaign_time := 0.0
var next_convoy_time := 35.0
var force_serial := 0

func configure(origin: FloatingOrigin) -> void:
	origin_service = origin

func initialize_default_war() -> void:
	nodes = {
		"rebel_outpost": _node("Rebel Outpost", Vector2(0.0, 180.0), "rebel", 85.0, 12.0),
		"mos_eisley": _node("Mos Eisley", Vector2(0.0, -260.0), "imperial", 125.0, 35.0),
		"south_checkpoint": _node("South Checkpoint", Vector2(35.0, -35.0), "imperial", 42.0, 8.0),
		"imperial_garrison": _node("Imperial Garrison", Vector2(420.0, -650.0), "imperial", 180.0, 5.0),
	}
	routes = [
		{"a": "rebel_outpost", "b": "south_checkpoint"},
		{"a": "south_checkpoint", "b": "mos_eisley"},
		{"a": "mos_eisley", "b": "imperial_garrison"},
	]
	_spawn_force("rebel", 58.0, "rebel_outpost", "south_checkpoint", 4.8)
	_spawn_force("imperial", 72.0, "imperial_garrison", "mos_eisley", 5.4)
	event_logged.emit("Planetary war initialized: Mos Eisley is Imperial-held and contested from the south.")

func _node(display_name: String, map_position: Vector2, owner: String, imperial: float, rebel: float) -> Dictionary:
	var planet_position := PackedFloat64Array([0.0, 0.0, 0.0])
	if origin_service != null:
		planet_position = PlanetMath.tangent_surface_point(
			origin_service.origin_ecef,
			origin_service.frame_basis,
			map_position.x,
			map_position.y,
			origin_service.planet_radius,
			0.0
		)
	return {
		"name": display_name,
		"map_position": map_position,
		"planet_position": planet_position,
		"owner": owner,
		"imperial": imperial,
		"rebel": rebel,
		"supply": 1.0,
	}

func _process(delta: float) -> void:
	accumulator += delta
	while accumulator >= simulation_tick_seconds:
		accumulator -= simulation_tick_seconds
		_tick(simulation_tick_seconds)

func _tick(delta: float) -> void:
	campaign_time += delta
	for force in forces:
		if bool(force.get("arrived", false)) or bool(force.get("destroyed", false)):
			continue
		var from_node: Dictionary = nodes[force["from"]]
		var to_node: Dictionary = nodes[force["to"]]
		var a: Vector2 = from_node["map_position"]
		var b: Vector2 = to_node["map_position"]
		var distance: float = maxf(a.distance_to(b), 1.0)
		force["progress"] = minf(1.0, float(force["progress"]) + float(force["speed"]) * delta / distance)
		var planet_position := _force_planet_position(force)
		force_updated.emit(String(force["id"]), planet_position, String(force["faction"]), float(force["strength"]))
		if float(force["progress"]) >= 1.0:
			force["arrived"] = true
			_resolve_arrival(force)

	if campaign_time >= next_convoy_time:
		next_convoy_time += 70.0
		_spawn_force("imperial", 45.0, "imperial_garrison", "mos_eisley", 5.7)
		event_logged.emit("Imperial reinforcement convoy departed for Mos Eisley.")

func _spawn_force(faction: String, strength: float, from_id: String, to_id: String, speed: float) -> void:
	force_serial += 1
	forces.append({
		"id": "force_%03d" % force_serial,
		"faction": faction,
		"strength": strength,
		"from": from_id,
		"to": to_id,
		"speed": speed,
		"progress": 0.0,
		"arrived": false,
		"destroyed": false,
	})

func _force_planet_position(force: Dictionary) -> PackedFloat64Array:
	var from_node: Dictionary = nodes[force["from"]]
	var to_node: Dictionary = nodes[force["to"]]
	var from_ecef: PackedFloat64Array = from_node["planet_position"]
	var to_ecef: PackedFloat64Array = to_node["planet_position"]
	var radius := origin_service.planet_radius if origin_service != null else 6_000_000.0
	return PlanetMath.interpolate_on_sphere(from_ecef, to_ecef, float(force["progress"]), radius)

func _resolve_arrival(force: Dictionary) -> void:
	var node: Dictionary = nodes[force["to"]]
	var faction := String(force["faction"])
	node[faction] = float(node.get(faction, 0.0)) + float(force["strength"])
	nodes[force["to"]] = node
	event_logged.emit("%s force reached %s." % [faction.capitalize(), String(node["name"])])
	_evaluate_control(String(force["to"]))

func apply_local_result(node_id: String, faction: String, impact: float) -> void:
	if not nodes.has(node_id):
		return
	var node: Dictionary = nodes[node_id]
	node[faction] = float(node.get(faction, 0.0)) + maxf(impact, 0.0)
	var opponent := "imperial" if faction == "rebel" else "rebel"
	node[opponent] = maxf(0.0, float(node.get(opponent, 0.0)) - impact * 0.55)
	nodes[node_id] = node
	event_logged.emit("Local action changed the balance at %s." % String(node["name"]))
	_evaluate_control(node_id)

func apply_casualties(node_id: String, faction: String, amount: float) -> void:
	if not nodes.has(node_id) or faction not in ["imperial", "rebel"]:
		return
	var node: Dictionary = nodes[node_id]
	node[faction] = maxf(0.0, float(node.get(faction, 0.0)) - maxf(amount, 0.0))
	nodes[node_id] = node
	_evaluate_control(node_id)

func damage_force(force_id: String, amount: float) -> float:
	for force in forces:
		if String(force["id"]) != force_id:
			continue
		if bool(force.get("destroyed", false)) or bool(force.get("arrived", false)):
			return 0.0
		force["strength"] = maxf(0.0, float(force["strength"]) - maxf(amount, 0.0))
		if float(force["strength"]) <= 0.0:
			force["destroyed"] = true
			event_logged.emit("%s was destroyed before reaching its destination." % force_id)
			force_destroyed.emit(force_id)
		return float(force["strength"])
	return 0.0

func _evaluate_control(node_id: String) -> void:
	var node: Dictionary = nodes[node_id]
	var imperial := float(node["imperial"])
	var rebel := float(node["rebel"])
	var previous := String(node["owner"])
	var next := previous
	if rebel > imperial * 1.18 and rebel - imperial > 18.0:
		next = "rebel"
	elif imperial > rebel * 1.18 and imperial - rebel > 18.0:
		next = "imperial"
	if next != previous:
		node["owner"] = next
		nodes[node_id] = node
		control_changed.emit(node_id, next)
		event_logged.emit("%s changed control to %s." % [String(node["name"]), next.capitalize()])

func summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id in ["rebel_outpost", "south_checkpoint", "mos_eisley", "imperial_garrison"]:
		var node: Dictionary = nodes.get(id, {})
		if node.is_empty():
			continue
		lines.append("%s: %s  I %.0f / R %.0f" % [
			String(node["name"]),
			String(node["owner"]).to_upper(),
			float(node["imperial"]),
			float(node["rebel"]),
		])
	return lines
