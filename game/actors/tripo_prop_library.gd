extends RefCounted
## Shared runtime entry for carry items, furniture, hats and backpacks.
const MANIFEST := "res://assets/props/tripo_expansion_v1/manifest.json"
static var _entries: Dictionary = {}
static var _scenes: Dictionary = {}

static func entries() -> Dictionary:
	if _entries.is_empty() and FileAccess.file_exists(MANIFEST):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if data is Dictionary:
			for row: Dictionary in data.get("assets",[]): _entries[str(row.id).trim_prefix("prop_")] = row
	return _entries

static func create(id: String, usage: String = "display") -> Node3D:
	var key := id.trim_prefix("prop_")
	if not entries().has(key): return null
	if not _scenes.has(key): _scenes[key] = load(str(_entries[key].path)) as PackedScene
	var packed := _scenes[key] as PackedScene
	if packed == null: return null
	var holder := Node3D.new()
	holder.name = "TripoProp_"+key
	holder.set_meta("source_asset",str(_entries[key].id))
	holder.set_meta("source_sha256",str(_entries[key].source_sha256))
	var mesh := packed.instantiate() as Node3D
	holder.add_child(mesh)
	var size: Array = _entries[key].bounds_size
	if usage == "carry":
		mesh.position.y = -float(size[1])*.5
	elif usage == "hat":
		mesh.position.y = -.06
		mesh.rotation_degrees.z = -4.0 if key == "star_beret" else 3.0
	elif usage == "bag":
		mesh.rotation.y = PI
		mesh.position = Vector3(0,-float(size[1])*.52,-.04)
	return holder
