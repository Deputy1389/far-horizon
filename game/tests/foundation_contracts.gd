extends SceneTree

func _init() -> void:
	_test_planet_coordinates()
	_test_floating_origin_rebase()
	_test_strategy_state()
	_test_weapon_contracts()
	print("FOUNDATION_CONTRACTS_OK")
	quit(0)

func _test_planet_coordinates() -> void:
	var radius := 6_000_000.0
	var latitude := deg_to_rad(11.0)
	var longitude := deg_to_rad(42.0)
	var ecef := PlanetMath.lat_lon_to_ecef(latitude, longitude, 125.0, radius)
	var length := PlanetMath.length64(ecef)
	assert(absf(length - (radius + 125.0)) < 0.01)

	var lat_lon := PlanetMath.ecef_to_lat_lon(ecef)
	assert(absf(lat_lon.x - latitude) < 0.000001)
	assert(absf(lat_lon.y - longitude) < 0.000001)

	var origin := PlanetMath.lat_lon_to_ecef(latitude, longitude, 0.0, radius)
	var basis := PlanetMath.tangent_basis(origin)
	var local := Vector3(321.0, 17.0, -445.0)
	var absolute := PlanetMath.local_to_ecef(origin, basis, local)
	var roundtrip := PlanetMath.ecef_to_local(origin, basis, absolute)
	assert(roundtrip.distance_to(local) < 0.001)

	var surface := PlanetMath.tangent_surface_point(origin, basis, 900.0, -700.0, radius, 0.0)
	assert(absf(PlanetMath.length64(surface) - radius) < 0.01)

func _test_floating_origin_rebase() -> void:
	var origin := FloatingOrigin.new()
	get_root().add_child(origin)
	origin.configure(6_000_000.0, 11.0, 42.0)

	var tracked := Node3D.new()
	get_root().add_child(tracked)
	tracked.global_position = Vector3(1025.0, 12.0, -340.0)
	origin.track(tracked)

	var anchor := Node3D.new()
	get_root().add_child(anchor)
	anchor.add_to_group("planet_anchor")
	anchor.global_position = Vector3(1260.0, 7.0, 180.0)

	var before := origin.absolute_position(anchor.global_position)
	origin._rebase()
	var after := origin.absolute_position(anchor.global_position)
	var error := sqrt(
		pow(before[0] - after[0], 2.0)
		+ pow(before[1] - after[1], 2.0)
		+ pow(before[2] - after[2], 2.0)
	)
	assert(error < 0.01)
	assert(Vector2(tracked.global_position.x, tracked.global_position.z).length() < 0.2)

	anchor.free()
	tracked.free()
	origin.free()

func _test_strategy_state() -> void:
	var origin := FloatingOrigin.new()
	origin.configure(6_000_000.0, 11.0, 42.0)
	var sim := StrategicSim.new()
	sim.configure(origin)
	sim.initialize_default_war()

	assert(sim.nodes.size() == 4)
	assert(sim.routes.size() == 3)
	assert(sim.forces.size() >= 2)
	assert(String((sim.nodes["rebel_outpost"] as Dictionary)["owner"]) == "rebel")
	assert(String((sim.nodes["mos_eisley"] as Dictionary)["owner"]) == "imperial")

	var force: Dictionary = sim.forces[0]
	var force_id := String(force["id"])
	var before := float(force["strength"])
	var after := sim.damage_force(force_id, 7.0)
	assert(absf(after - (before - 7.0)) < 0.001)

	var city_before: Dictionary = sim.nodes["mos_eisley"]
	var imperial_before := float(city_before["imperial"])
	sim.apply_casualties("mos_eisley", "imperial", 3.0)
	var city_after_casualty: Dictionary = sim.nodes["mos_eisley"]
	assert(absf(float(city_after_casualty["imperial"]) - (imperial_before - 3.0)) < 0.001)

	sim.apply_local_result("mos_eisley", "rebel", 145.0)
	var city: Dictionary = sim.nodes["mos_eisley"]
	assert(float(city["rebel"]) > float(city["imperial"]))

	sim.free()
	origin.free()

func _test_weapon_contracts() -> void:
	var pistol := WeaponDefinition.pistol()
	var rifle := WeaponDefinition.rifle()
	assert(pistol.projectile_speed > 100.0)
	assert(rifle.projectile_speed > pistol.projectile_speed)
	assert(pistol.damage > rifle.damage)
	assert(rifle.rounds_per_second > pistol.rounds_per_second)
	assert(pistol.ads_spread_degrees < pistol.hip_spread_degrees)
	assert(rifle.ads_spread_degrees < rifle.hip_spread_degrees)
