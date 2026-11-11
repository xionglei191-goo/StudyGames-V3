extends Node3D
## Scene geometry and interaction markers come from editable Blender exports.
## Godot owns the characters, lighting and gameplay bindings.

const CREAM := Color("f6e5bd")
const TEAL := Color("397e7c")
const PINK := Color("ee9fa0")
var _materials: Dictionary = {}
var _font: Font
var _imported_scene: Node3D
const InteriorScript = preload("res://scripts/imported_interior.gd")
const BlenderMaterials = preload("res://scripts/blender_materials.gd")
const HomeCatalog = preload("res://scripts/home_catalog.gd")
const DioramaEnvironment = preload("res://world/diorama_environment.gd")
const DioramaBackdrop = preload("res://world/diorama_backdrop.gd")
const ToySurfacePolisher = preload("res://world/toy_surface_polisher.gd")
const HeroSceneDressing = preload("res://world/hero_scene_dressing.gd")
var _backdrop: Node3D
var _polisher: Node3D
var _hero_dressing: Node3D

func build(room: String) -> Dictionary:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_imported_scene = null
	_backdrop = null
	_polisher = null
	_hero_dressing = null
	_lighting(room)
	if room == "village":
		_imported_scene = load("res://scripts/imported_world.gd").new()
		_imported_scene.name = "ImportedIsland"
		add_child(_imported_scene)
		var imported: Dictionary = _imported_scene.build()
		imported["material_stats"] = BlenderMaterials.restore_vertex_colors(_imported_scene)
		_attach_diorama_layers(room, imported)
		_add_imported_npcs(imported)
		return imported
	if InteriorScript.available(room):
		_imported_scene = InteriorScript.new()
		_imported_scene.name = "ImportedInterior"
		add_child(_imported_scene)
		var imported: Dictionary = _imported_scene.build(room, room_plan(room))
		imported["material_stats"] = BlenderMaterials.restore_vertex_colors(_imported_scene)
		_attach_diorama_layers(room, imported)
		_add_imported_npcs(imported)
		return imported
	push_error("Missing Blender scene: " + room)
	return {}

func _attach_diorama_layers(room: String, imported: Dictionary) -> void:
	_backdrop = DioramaBackdrop.new()
	add_child(_backdrop)
	_backdrop.setup(room, imported)

	_polisher = ToySurfacePolisher.new()
	add_child(_polisher)
	imported["toy_polish"] = _polisher.polish_scene(_imported_scene, room, imported)

	_hero_dressing = HeroSceneDressing.new()
	add_child(_hero_dressing)
	_hero_dressing.dress_scene(room, imported)

func set_comfort_mode(reduced: bool) -> void:
	if is_instance_valid(_backdrop) and "reduced_motion" in _backdrop:
		_backdrop.reduced_motion = reduced
	if is_instance_valid(_polisher) and "reduced_motion" in _polisher:
		_polisher.reduced_motion = reduced

func set_day_phase(phase: String) -> void:
	if is_instance_valid(_polisher) and _polisher.has_method("set_day_phase"):
		_polisher.set_day_phase(phase)

func _add_imported_npcs(info: Dictionary) -> void:
	for npc in info.get("npcs", []):
		_npc(str(npc.kind), npc.position, float(npc.get("angle", 0.0)), str(npc.get("name", "邻居")))

func room_plan(room_id: String) -> Dictionary:
	var home_plan: Dictionary = HomeCatalog.room(room_id)
	if not home_plan.is_empty(): return home_plan
	var path := "res://data/landmark_interiors.json"
	if FileAccess.file_exists(path):
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for entry in catalog.get("landmarks", []):
			if str(entry.get("room_id", "")) == room_id:
				return entry
			for area in entry.get("areas", []):
				if area is Dictionary and str(area.get("room_id", "")) == room_id:
					return area
	return {"room_id":room_id,"name":room_id}

func _lighting(room: String) -> void:
	DioramaEnvironment.build_lighting(self, room)

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	_materials[key] = mat
	return mat

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = _mat(color)
	result.position = pos
	parent.add_child(result)
	return result

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, color)

func _ball(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 10
	var result := _mesh(parent, mesh, pos, color)
	result.scale = size
	return result

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 20
	return _mesh(parent, mesh, pos, color)

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2)
	mesh.radial_segments = 16
	mesh.rings = 4
	return _mesh(parent, mesh, pos, color)

func _solid(pos: Vector3, size: Vector3, parent: Node3D = self) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)

func _label(parent: Node3D, text: String, pos: Vector3, size: int = 40, color: Color = CREAM) -> Label3D:
	var label := Label3D.new()
	if _font == null:
		_font = load("res://assets/fonts/IslandSans.otf") as Font
	label.font = _font
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_modulate = Color("594c37")
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _npc(kind: String, pos: Vector3, angle: float, display_name: String) -> void:
	var character: Node3D = make_character(kind)
	character.position = pos
	character.rotation.y = angle
	add_child(character)
	_label(self, display_name, pos + Vector3(0, 3.0, 0), 25, Color("fff6df"))
	_solid(pos + Vector3(0, 0.7, 0), Vector3(0.55, 1.4, 0.55))

func make_character(kind: String) -> Node3D:
	var visual := preload("res://actors/player_visual_v3.gd").new()
	var character_id: String = {"player":"player","bear":"npc_bear_uncle","rabbit":"npc_rabbit_gardener","teacher":"textbook_miss_li"}.get(kind,"player")
	visual.configure(character_id)
	visual.name = kind.capitalize()
	return visual
func set_decoration(id: String, enabled: bool) -> void:
	if is_instance_valid(_imported_scene) and _imported_scene.has_method("set_decoration"):
		_imported_scene.set_decoration(id, enabled)
