extends RefCounted
## Runtime loader & per-word PBR color tinter for Blender 5.2 authored Layer-2 storybook 3D props (.glb).

const MANIFEST_PATH := "res://assets/props/layer2_storybook_v1/manifest.json"
const WorldArt = preload("res://scripts/world_art.gd")
const FINISH_TILES := {
	"Woodgrain": ["wood",0.15], "Linen": ["cloth",0.22], "Papergrain": ["paper",0.13],
	"Porous": ["plaster",0.21], "Leafskin": ["foliage",0.10],
	"Rubber": ["plaster",0.10], "Felt": ["cloth",0.15],
}

const WORD_MODEL_OVERRIDES := {
	"bee": "bee",
	"sun": "sun",
	"wind": "pinwheel",
	"cloud": "cloud",
	"rain": "rain_jar",
	"gloves": "gloves",
	"sweater": "sweater",
	"chicken": "chicken",
	"hamburger": "hamburger",
	"guitar": "guitar",
	"football": "football",
	"basketball": "basketball",
	"rice": "rice_bowl",
	"noodles": "noodle_bowl",
	"tomato": "tomato",
	"letter": "letter",
	"newspaper": "newspaper",
	"vegetable": "vegetable",
	"chalk": "chalk",
	"juice": "juice_glass",
}

const SHAPE_ALIASES := {
	"bowl_food": "rice_bowl",
}

static var _entries: Dictionary = {}
static var _scenes: Dictionary = {}
static var _tinted_mats: Dictionary = {}


static func entries() -> Dictionary:
	if _entries.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			var raw_assets: Variant = (parsed as Dictionary).get("assets", {})
			if raw_assets is Dictionary:
				_entries = raw_assets as Dictionary
	return _entries


static func resolve_model_id(shape: String, word_key: String = "") -> String:
	var w := word_key.strip_edges().to_lower()
	var sh := shape.strip_edges().to_lower()

	if w == "soup":
		return "pot" if sh == "pot" else "soup_bowl"
	if (w == "red" or w == "blue" or w == "yellow") and sh == "cup":
		return "paint_jar"
	if WORD_MODEL_OVERRIDES.has(w):
		return str(WORD_MODEL_OVERRIDES[w])
	if SHAPE_ALIASES.has(sh):
		return str(SHAPE_ALIASES[sh])

	var lib := entries()
	if lib.has(sh):
		return sh
	if lib.has(w):
		return w
	return "gift_box"


static func has_model(model_id: String) -> bool:
	return entries().has(model_id)


static func create(shape: String, hex_color: String, word_key: String = "", stage_mode: String = "") -> Node3D:
	var model_id := resolve_model_id(shape, word_key)
	var lib := entries()
	if not lib.has(model_id):
		return null

	var row: Dictionary = lib[model_id] as Dictionary
	var rt_path := str(row.get("runtime_path", ""))
	if rt_path.is_empty():
		return null

	if not _scenes.has(model_id):
		_scenes[model_id] = load(rt_path) as PackedScene
	var packed := _scenes[model_id] as PackedScene
	if packed == null:
		return null

	var holder := Node3D.new()
	holder.name = "L2Prop_" + model_id
	holder.set_meta("source_asset", "l2_" + model_id)
	holder.set_meta("glb_path", rt_path)
	holder.set_meta("model_id", model_id)

	var inst := packed.instantiate() as Node3D
	if inst == null:
		holder.free()
		return null
	holder.add_child(inst)

	if stage_mode != "wardrobe":
		var boost := 1.38 if (model_id == "violin" or model_id == "guitar") else 1.26
		inst.scale = Vector3.ONE * boost

	var col := Color.from_string(hex_color, Color("5b9bd5"))
	apply_finishes(inst, col)
	return holder


static func apply_finishes(node: Node, col: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var scount := mi.mesh.get_surface_count()
			for s: int in range(scount):
				var mat := mi.get_active_material(s)
				if mat is BaseMaterial3D:
					var bmat := mat as BaseMaterial3D
					var mname := bmat.resource_name
					var role := ""
					if mname.begins_with("L2_TintPrimary"):
						role = "primary"
					elif mname.begins_with("L2_TintSecondary"):
						role = "secondary"
					elif mname.begins_with("L2_TintDark"):
						role = "dark"
					if not role.is_empty() or FINISH_TILES.has(mname.get_slice("_",2)):
						mi.set_surface_override_material(s, _get_tinted_material(bmat, role, col))
	for ch: Node in node.get_children():
		apply_finishes(ch, col)


static func _get_tinted_material(src: BaseMaterial3D, role: String, col: Color) -> BaseMaterial3D:
	var cache_key := src.resource_name + (col.to_html(false) if not role.is_empty() else "")
	if _tinted_mats.has(cache_key):
		return _tinted_mats[cache_key] as BaseMaterial3D

	var dup := src.duplicate() as BaseMaterial3D
	if role == "primary":
		dup.albedo_color = col
	elif role == "secondary":
		dup.albedo_color = col.lightened(0.22)
	elif role == "dark":
		dup.albedo_color = col.darkened(0.20)
	var finish: Array = FINISH_TILES.get(src.resource_name.get_slice("_",2),[])
	if not finish.is_empty():
		WorldArt.set_surface_detail(dup,str(finish[0]),float(finish[1]))
	_tinted_mats[cache_key] = dup
	return dup
