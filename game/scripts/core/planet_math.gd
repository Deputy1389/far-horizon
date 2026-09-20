class_name PlanetMath
extends RefCounted

const EPSILON := 0.0000001

static func length64(value: PackedFloat64Array) -> float:
	if value.size() < 3:
		return 0.0
	return sqrt(value[0] * value[0] + value[1] * value[1] + value[2] * value[2])

static func normalize64(value: PackedFloat64Array) -> PackedFloat64Array:
	var magnitude := length64(value)
	if magnitude <= EPSILON:
		return PackedFloat64Array([0.0, 1.0, 0.0])
	return PackedFloat64Array([
		value[0] / magnitude,
		value[1] / magnitude,
		value[2] / magnitude,
	])

static func lat_lon_to_ecef(latitude_radians: float, longitude_radians: float, altitude: float, radius: float) -> PackedFloat64Array:
	var r := radius + altitude
	var cos_lat := cos(latitude_radians)
	return PackedFloat64Array([
		r * cos_lat * cos(longitude_radians),
		r * sin(latitude_radians),
		r * cos_lat * sin(longitude_radians),
	])

static func project_to_radius(value: PackedFloat64Array, radius: float) -> PackedFloat64Array:
	var direction := normalize64(value)
	return PackedFloat64Array([
		direction[0] * radius,
		direction[1] * radius,
		direction[2] * radius,
	])

static func tangent_basis(origin_ecef: PackedFloat64Array) -> Basis:
	var up64 := normalize64(origin_ecef)
	var up := Vector3(float(up64[0]), float(up64[1]), float(up64[2])).normalized()
	var reference := Vector3.UP
	if abs(up.dot(reference)) > 0.98:
		reference = Vector3.FORWARD
	var east := reference.cross(up).normalized()
	var north := up.cross(east).normalized()
	return Basis(east, up, north).orthonormalized()

static func local_to_ecef(origin_ecef: PackedFloat64Array, frame_basis: Basis, local_position: Vector3) -> PackedFloat64Array:
	var x_axis := frame_basis.x
	var y_axis := frame_basis.y
	var z_axis := frame_basis.z
	return PackedFloat64Array([
		origin_ecef[0] + float(x_axis.x) * local_position.x + float(y_axis.x) * local_position.y + float(z_axis.x) * local_position.z,
		origin_ecef[1] + float(x_axis.y) * local_position.x + float(y_axis.y) * local_position.y + float(z_axis.y) * local_position.z,
		origin_ecef[2] + float(x_axis.z) * local_position.x + float(y_axis.z) * local_position.y + float(z_axis.z) * local_position.z,
	])

static func ecef_to_local(origin_ecef: PackedFloat64Array, frame_basis: Basis, planet_position: PackedFloat64Array) -> Vector3:
	var dx := planet_position[0] - origin_ecef[0]
	var dy := planet_position[1] - origin_ecef[1]
	var dz := planet_position[2] - origin_ecef[2]
	var x_axis := frame_basis.x
	var y_axis := frame_basis.y
	var z_axis := frame_basis.z
	return Vector3(
		float(dx * x_axis.x + dy * x_axis.y + dz * x_axis.z),
		float(dx * y_axis.x + dy * y_axis.y + dz * y_axis.z),
		float(dx * z_axis.x + dy * z_axis.y + dz * z_axis.z)
	)

static func tangent_surface_point(
	origin_ecef: PackedFloat64Array,
	frame_basis: Basis,
	local_x: float,
	local_z: float,
	radius: float,
	altitude: float = 0.0
) -> PackedFloat64Array:
	var tangent_point := local_to_ecef(origin_ecef, frame_basis, Vector3(local_x, 0.0, local_z))
	var direction := normalize64(tangent_point)
	var r := radius + altitude
	return PackedFloat64Array([
		direction[0] * r,
		direction[1] * r,
		direction[2] * r,
	])

static func ecef_to_lat_lon(value: PackedFloat64Array) -> Vector2:
	var r: float = maxf(length64(value), EPSILON)
	var latitude: float = asin(clampf(float(value[1] / r), -1.0, 1.0))
	var longitude: float = atan2(float(value[2]), float(value[0]))
	return Vector2(latitude, longitude)

static func interpolate_on_sphere(a: PackedFloat64Array, b: PackedFloat64Array, t: float, radius: float) -> PackedFloat64Array:
	var clamped: float = clampf(t, 0.0, 1.0)
	var blended := PackedFloat64Array([
		lerpf(a[0], b[0], clamped),
		lerpf(a[1], b[1], clamped),
		lerpf(a[2], b[2], clamped),
	])
	return project_to_radius(blended, radius)
