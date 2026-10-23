extends RefCounted
## Original v3 DCC props and neutral surface details. Never edits gameplay geometry.
## Units: metres / Y up. Apple/card pivots are centred; basket/cake/book pivots are at the base.
## invitation/nameplate: 0.32 x 0.23 m, origin at card centre, front +Z.

const REVISION := "world-refresh-v3"
const ROOT := "res://assets/world_refresh_v3/"
const PROP_PATHS := {
	"apple":ROOT + "apple.glb", "basket":ROOT + "basket.glb",
	"cake":ROOT + "cake.glb", "book":ROOT + "book.glb",
	"invitation":ROOT + "invitation.glb", "nameplate":ROOT + "nameplate.glb",
}
static var _scenes: Dictionary = {}
static var _textures: Dictionary = {}
static var _bounds: Dictionary = {}
static var _vertex_materials: Dictionary = {}

static func create_prop(kind: String) -> Node3D:
	if not PROP_PATHS.has(kind):
		return null
	if not _scenes.has(kind):
		_scenes[kind] = load(str(PROP_PATHS[kind])) as PackedScene
	var packed := _scenes[kind] as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	instance.name = "WorldArt_" + kind
	instance.set_meta("world_art_revision", REVISION)
	instance.set_meta("world_art_kind", kind)
	for node: Node in instance.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var array_mesh := mesh.mesh as ArrayMesh
		if array_mesh == null: continue
		for surface in range(array_mesh.get_surface_count()):
			if array_mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR == 0:
				continue
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null: continue
			var key := original.get_instance_id()
			if not _vertex_materials.has(key):
				var colored := original.duplicate() as BaseMaterial3D
				colored.vertex_color_use_as_albedo = true
				colored.vertex_color_is_srgb = false
				_vertex_materials[key] = colored
			mesh.set_surface_override_material(surface,_vertex_materials[key])
	return instance

static func _asset_bounds(kind: String) -> AABB:
	if _bounds.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
		for entry: Dictionary in data.get("assets", []):
			var low: Array = entry.aabb_godot_min
			var size: Array = entry.aabb_godot_size
			_bounds[str(entry.id)] = AABB(Vector3(low[0],low[1],low[2]),Vector3(size[0],size[1],size[2]))
	return _bounds.get(kind, AABB(Vector3.ZERO,Vector3.ONE))

static func _fit(instance: Node3D, kind: String, target: AABB, body_only: bool = false) -> void:
	var source := _asset_bounds(kind)
	# Fit the fruit body / wicker bowl; the authored stem and handles extend above it.
	if body_only and kind == "apple":
		source = AABB(Vector3(-0.30,-0.265,-0.30),Vector3(0.60,0.53,0.60))
	elif body_only and kind == "basket":
		source = AABB(Vector3(-0.43,0,-0.43),Vector3(0.86,0.48,0.86))
	var factor := target.size / source.size
	instance.scale = factor
	instance.position = target.position - source.position * factor

static func _replace_single(source: MeshInstance3D, kind: String, body_only: bool = false) -> bool:
	if source.has_meta("world_art_replacement"):
		return false
	var visual := create_prop(kind)
	if visual == null:
		return false
	# Child attachment preserves source visibility, decoration toggles and transforms.
	# layers=0 suppresses only the old render mesh; its AABB and authored name survive.
	source.add_child(visual)
	_fit(visual,kind,source.get_aabb(),body_only)
	source.layers = 0
	source.set_meta("world_art_replacement", kind)
	return true

static func _hide_related(source: MeshInstance3D, tokens: Array[String]) -> void:
	# Blender .NNN suffix belongs to the instance, after the component's name.
	var source_name := str(source.name)
	var stem := source_name.get_slice(".",0)
	var suffix := source_name.trim_prefix(stem)
	for token: String in tokens:
		var sibling := source.get_parent().get_node_or_null(NodePath(stem + token + suffix)) as MeshInstance3D
		if sibling != null:
			sibling.layers = 0
			sibling.set_meta("world_art_component_replaced", true)

static func _replace_basket(source: MeshInstance3D) -> bool:
	if not _replace_single(source,"basket",true):
		return false
	var prefix := str(source.name).trim_suffix("_Wicker")
	for node: Node in source.get_parent().get_children():
		if node is MeshInstance3D:
			var n := str(node.name)
			if n.begins_with(prefix + "_Handle") or n.begins_with(prefix + "_Weave"):
				node.layers = 0
				node.set_meta("world_art_component_replaced",true)
	return true

static func _replace_cake(source: MeshInstance3D) -> bool:
	if source.has_meta("world_art_replacement"):
		return false
	var prefix := str(source.name).trim_suffix("_Layer")
	var members: Array[MeshInstance3D] = []
	var bounds := AABB()
	for node: Node in source.get_parent().get_children():
		if node is MeshInstance3D and str(node.name).begins_with(prefix + "_"):
			var part := node as MeshInstance3D
			var box: AABB = source.transform.affine_inverse() * part.transform * part.get_aabb()
			bounds = box if members.is_empty() else bounds.merge(box)
			members.append(part)
	var visual := create_prop("cake")
	if visual == null or members.is_empty():
		if visual != null: visual.free()
		return false
	source.add_child(visual)
	_fit(visual,"cake",bounds)
	for member: MeshInstance3D in members:
		member.layers = 0
		member.set_meta("world_art_component_replaced",true)
	source.set_meta("world_art_replacement","cake")
	return true

static func _family(material: BaseMaterial3D, node_name: String) -> String:
	var key := material.resource_name.to_lower()
	var n := node_name.to_lower()
	if "bark" in key or "trunk" in n or "branch" in n: return "bark"
	if "wood" in key or "oak" in key: return "wood"
	if "leaf" in key or "leaves" in key or "grass" in key: return "foliage"
	if "paper" in key: return "paper"
	if "quilt" in n or "cushion" in n or "pillow" in n or "rug" in n: return "cloth"
	if "wall" in n and ("cream" in key or "ivory" in key): return "plaster"
	return ""

static func _texture(family: String, kind: String) -> Texture2D:
	var key := family + "_" + kind
	if not _textures.has(key):
		_textures[key] = load(ROOT + key + ".png") as Texture2D
	return _textures[key] as Texture2D

static func apply_to_scene(root: Node3D) -> Dictionary:
	if root.has_meta("world_art_stats"):
		return root.get_meta("world_art_stats")
	var stats := {"revision":REVISION,"props":0,"prop_kinds":{},"surface_details":0,"materials":0,"families":{}}
	var materials: Dictionary = {}
	# Snapshot before adding visuals: a new authored prop must never be processed twice.
	var nodes := root.find_children("*","MeshInstance3D",true,false)
	for node: Node in nodes:
		var mesh := node as MeshInstance3D
		var n := str(mesh.name)
		if mesh.mesh == null or n.begins_with("SG_"):
			continue
		var plain := n.get_slice(".",0)
		var kind := ""
		if ("_Fruit_" in plain and not plain.ends_with("_Stem") and not plain.ends_with("_Leaf")) or plain.ends_with("_Apple"):
			if _replace_single(mesh,"apple",true):
				_hide_related(mesh,["_Stem","_Leaf"])
				kind = "apple"
		elif n == "A_Entrance_Basket" or plain.ends_with("_Basket_Wicker"):
			if _replace_basket(mesh): kind = "basket"
		elif (plain.ends_with("_Cake_Layer") and not "." in n) or n == "Cake_In_Progress_Layer":
			if _replace_cake(mesh): kind = "cake"
		elif plain in ["Pupil_Book","Desk_Journal","Bird_Journal","Teacher_Book"]:
			if _replace_single(mesh,"book"): kind = "book"
		if not kind.is_empty():
			stats.props += 1
			stats.prop_kinds[kind] = int(stats.prop_kinds.get(kind,0)) + 1
		if mesh.layers == 0:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			# Preserve embedded Tripo/artist texture work and transparent/water surfaces.
			if original == null or original.albedo_texture != null or original.normal_texture != null or original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var family := _family(original,n)
			if family.is_empty(): continue
			var key := str(original.get_instance_id()) + ":" + family
			if not materials.has(key):
				var detailed := original.duplicate() as BaseMaterial3D
				detailed.albedo_texture = _texture(family,"detail")
				detailed.normal_enabled = true
				detailed.normal_texture = _texture(family,"normal")
				detailed.normal_scale = {"wood":0.085,"bark":0.16,"foliage":0.08,"cloth":0.045,"paper":0.035,"plaster":0.04}.get(family,0.06)
				detailed.uv1_triplanar = true
				detailed.uv1_world_triplanar = true
				detailed.uv1_scale = Vector3.ONE * (1.6 if family in ["wood","bark"] else 2.5)
				detailed.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				detailed.texture_repeat = true
				detailed.set_meta("world_art_family",family)
				materials[key] = detailed
			mesh.set_surface_override_material(surface,materials[key])
			stats.surface_details += 1
			stats.families[family] = int(stats.families.get(family,0)) + 1
	stats.materials = materials.size()
	root.set_meta("world_art_stats",stats)
	return stats
