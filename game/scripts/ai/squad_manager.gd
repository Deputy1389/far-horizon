class_name SquadManager
extends Node

signal combat_started(squad_id: String)
signal squad_cleared(squad_id: String)

@export var reinforcement_radius := 38.0
@export var max_simultaneous_shooters := 3

var squads: Dictionary = {}
var combat_announced: Dictionary = {}
var firing_slots: Dictionary = {}

func register_member(member: Node, squad_id: String) -> String:
	if not squads.has(squad_id):
		squads[squad_id] = []
	var members: Array = squads[squad_id]
	if not members.has(member):
		members.append(member)
	squads[squad_id] = members

	var index := members.find(member)
	match index % 4:
		0:
			return "suppress"
		1:
			return "flank_left"
		2:
			return "flank_right"
		_:
			return "advance"

func alert_squad(squad_id: String, target: Node3D) -> void:
	_alert_members(squad_id, target)

	# Nearby squads can hear/observe the same fight and join without a magical
	# city-wide aggro switch. This keeps local combat connected while preserving
	# room for genuinely separate encounters in a larger settlement.
	for id_value in squads.keys():
		var other_id := String(id_value)
		if other_id == squad_id or bool(combat_announced.get(other_id, false)):
			continue
		var should_reinforce := false
		var members: Array = squads.get(other_id, [])
		for member in members:
			if not member is Node3D or not is_instance_valid(member):
				continue
			if (member as Node3D).global_position.distance_to(target.global_position) <= reinforcement_radius:
				should_reinforce = true
				break
		if should_reinforce:
			_alert_members(other_id, target)

func _alert_members(squad_id: String, target: Node3D) -> void:
	if not bool(combat_announced.get(squad_id, false)):
		combat_announced[squad_id] = true
		combat_started.emit(squad_id)
	var members: Array = squads.get(squad_id, [])
	for member in members:
		if is_instance_valid(member) and member.has_method("receive_squad_alert"):
			member.receive_squad_alert(target)

func request_fire_slot(member: Node) -> bool:
	var now := Time.get_ticks_msec()
	var stale: Array = []
	for key in firing_slots.keys():
		var holder = key
		var expires := int(firing_slots[key])
		if not is_instance_valid(holder) or expires <= now:
			stale.append(key)
	for key in stale:
		firing_slots.erase(key)

	if firing_slots.has(member):
		firing_slots[member] = now + 1300
		return true
	if firing_slots.size() >= max_simultaneous_shooters:
		return false
	firing_slots[member] = now + 1300
	return true

func release_fire_slot(member: Node) -> void:
	firing_slots.erase(member)


func member_died(member: Node, squad_id: String) -> void:
	if not squads.has(squad_id):
		return
	var members: Array = squads[squad_id]
	members.erase(member)
	squads[squad_id] = members
	release_fire_slot(member)
	var alive := 0
	for candidate in members:
		if is_instance_valid(candidate):
			alive += 1
	if alive == 0:
		squad_cleared.emit(squad_id)

func active_member_count() -> int:
	var total := 0
	for members_value in squads.values():
		var members: Array = members_value
		for member in members:
			if is_instance_valid(member):
				total += 1
	return total
