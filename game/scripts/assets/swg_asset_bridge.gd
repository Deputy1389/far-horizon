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
	var scale_factor := 6.0
	visual.scale = Vector3.ONE * scale_factor
	# The converted SWG character faces +Z; Godot gameplay convention is -Z forward.
	visual.rotation.y = PI
	var ground_offset := float(descriptor.get("groundOffset", 0.0))
	visual.position.y = -ground_offset * scale_factor
	return visual

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
		url = String(descriptor.get("url", ""))
	if url.is_empty():
		return null
	var path := local_url_to_resource(url)
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	return resource as Texture2D if resource is Texture2D else null

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
