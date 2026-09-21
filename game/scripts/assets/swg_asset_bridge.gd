class_name SwgAssetBridge
extends RefCounted

const MANIFEST_PATH := "res://assets/local-swg/manifest.json"

static func manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if parsed is Dictionary else {}

static func stormtrooper_descriptor() -> Dictionary:
	var data := manifest()
	var characters = data.get("characters", {})
	if not characters is Dictionary:
		return {}
	var descriptor = characters.get("stormtrooper", {})
	return descriptor if descriptor is Dictionary else {}

static func local_url_to_resource(url: String) -> String:
	var clean := url.strip_edges()
	if clean.begins_with("./"):
		clean = clean.substr(2)
	return "res://" + clean

static func instantiate_stormtrooper() -> Node3D:
	var descriptor := stormtrooper_descriptor()
	var url := String(descriptor.get("url", ""))
	if url.is_empty():
		return null
	var path := local_url_to_resource(url)
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not resource is PackedScene:
		return null
	var scene := (resource as PackedScene).instantiate()
	if not scene is Node3D:
		scene.queue_free()
		return null

	var visual := scene as Node3D
	# Fit the imported character to an actual human-scale target instead of
	# relying on the old proof-of-concept magic multiplier. The previous 6x
	# scale is why Stormtroopers towered over buildings.
	var scale_factor := _fit_visual_height(visual, 1.82)
	visual.scale = Vector3.ONE * scale_factor
	# The converted SWG character faces +Z; Godot gameplay convention is -Z forward.
	visual.rotation.y = PI
	var ground_offset := float(descriptor.get("groundOffset", 0.0))
	visual.position.y = -ground_offset * scale_factor
	_apply_character_texture(visual, "stormtrooper")
	return visual

static func _fit_visual_height(root: Node3D, target_height: float) -> float:
	var minimum_y := INF
	var maximum_y := -INF
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.get_aabb()
		var relative := root.global_transform.affine_inverse() * mesh_instance.global_transform
		for x_bit in range(2):
			for y_bit in range(2):
				for z_bit in range(2):
					var point := Vector3(
						aabb.position.x + (aabb.size.x if x_bit == 1 else 0.0),
						aabb.position.y + (aabb.size.y if y_bit == 1 else 0.0),
						aabb.position.z + (aabb.size.z if z_bit == 1 else 0.0)
					)
					var transformed := relative * point
					minimum_y = minf(minimum_y, transformed.y)
					maximum_y = maxf(maximum_y, transformed.y)
					found = true
	if not found:
		return 1.0
	var height := maximum_y - minimum_y
	if height <= 0.001:
		return 1.0
	return target_height / height


static func texture_for_role(role: String) -> Texture2D:
	var data := manifest()
	var assets = data.get("assets", {})
	if not assets is Dictionary:
		return null
	var descriptor = assets.get(role)
	var url := ""
	if descriptor is String:
		url = descriptor
	elif descriptor is Dictionary:
		url = String(descriptor.get("godotUrl", descriptor.get("url", "")))
	if url.is_empty():
		return null
	var path := local_url_to_resource(url)
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	return resource as Texture2D if resource is Texture2D else null

static func audio_for_role(role: String) -> AudioStream:
	var data: Dictionary = manifest()
	var audio_value: Variant = data.get("audio", {})
	if not audio_value is Dictionary:
		return null
	var audio: Dictionary = audio_value
	var descriptor_value: Variant = audio.get(role, {})
	if not descriptor_value is Dictionary:
		return null
	var descriptor: Dictionary = descriptor_value
	var url := String(descriptor.get("url", ""))
	if url.is_empty():
		return null
	var path := local_url_to_resource(url)
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	return resource as AudioStream if resource is AudioStream else null


static func instantiate_mesh_proof() -> Node3D:
	var data := manifest()
	var descriptor = data.get("meshProof", {})
	if not descriptor is Dictionary:
		return null
	var url := String(descriptor.get("url", ""))
	if url.is_empty():
		return null
	var path := local_url_to_resource(url)
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not resource is PackedScene:
		return null
	var scene := (resource as PackedScene).instantiate()
	return scene as Node3D if scene is Node3D else null


static func _character_texture_descriptor(role: String) -> Dictionary:
	var data: Dictionary = manifest()
	var characters_value: Variant = data.get("characters", {})
	if not characters_value is Dictionary:
		return {}
	var characters: Dictionary = characters_value
	var descriptor_value: Variant = characters.get(role, {})
	if not descriptor_value is Dictionary:
		return {}
	var descriptor: Dictionary = descriptor_value
	var textures_value: Variant = descriptor.get("textures", {})
	if not textures_value is Dictionary:
		return {}
	var textures: Dictionary = textures_value

	var candidates: Array[Dictionary] = []
	for key in textures.keys():
		var value: Variant = textures[key]
		if not value is Dictionary:
			continue
		var path := String(key).to_lower()
		var penalty := 0
		if "spec" in path:
			penalty += 100
		if "_n." in path or "normal" in path or "_cn." in path:
			penalty += 90
		if "weapon" in path:
			penalty += 60
		if "base" in path:
			penalty += 5
		candidates.append({"penalty": penalty, "value": value})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["penalty"]) < int(b["penalty"])
	)
	if candidates.is_empty():
		return {}
	var selected: Dictionary = candidates[0]["value"]
	return selected


static func _texture_from_descriptor(descriptor: Dictionary) -> Texture2D:
	if descriptor.is_empty():
		return null
	var url := String(descriptor.get("godotUrl", descriptor.get("url", "")))
	if url.is_empty():
		return null
	var path := local_url_to_resource(url)
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	return resource as Texture2D if resource is Texture2D else null


static func _apply_character_texture(root: Node3D, role: String) -> void:
	var texture := _texture_from_descriptor(_character_texture_descriptor(role))
	if texture == null:
		return

	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D:
			continue

		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var original: Material = mesh_instance.get_active_material(surface_index)
			var material: StandardMaterial3D
			if original is StandardMaterial3D:
				material = (original as StandardMaterial3D).duplicate()
			else:
				material = StandardMaterial3D.new()
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE
			mesh_instance.set_surface_override_material(surface_index, material)
