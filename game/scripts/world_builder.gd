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

func build(room: String) -> Dictionary:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_imported_scene = null
	_lighting(room)
	if room == "village":
		_imported_scene = load("res://scripts/imported_world.gd").new()
		_imported_scene.name = "ImportedIsland"
		add_child(_imported_scene)
		var imported: Dictionary = _imported_scene.build()
		imported["material_stats"] = BlenderMaterials.restore_vertex_colors(_imported_scene)
		_add_imported_npcs(imported)
		return imported
	if InteriorScript.available(room):
		_imported_scene = InteriorScript.new()
		_imported_scene.name = "ImportedInterior"
		add_child(_imported_scene)
		var imported: Dictionary = _imported_scene.build(room, room_plan(room))
		imported["material_stats"] = BlenderMaterials.restore_vertex_colors(_imported_scene)
		_add_imported_npcs(imported)
		return imported
	push_error("Missing Blender scene: " + room)
	return {}

func _add_imported_npcs(info: Dictionary) -> void:
	for npc in info.get("npcs", []):
		_npc(str(npc.kind), npc.position, float(npc.get("angle", 0.0)), str(npc.get("name", "邻居")))

func room_plan(room_id: String) -> Dictionary:
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
	# Warm storybook daylight keeps dark foliage readable and pale interiors soft.
	# Distinct indoor/outdoor fill leaves the authored Blender materials editable.
	var is_island := room == "village"
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d5e2d6") if is_island else Color("e7dfca")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff3dd")
	env.ambient_light_energy = 0.80 if is_island else 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78 if is_island else 0.90
	env.adjustment_contrast = 0.92 if is_island else 0.98
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color("fff3dd")
	sun.light_energy = 0.25 if is_island else 0.23
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.32
	sun.directional_shadow_max_distance = 65
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40, 140, 0)
	fill.light_color = Color("e0e9ec")
	fill.light_energy = 0.12 if is_island else 0.08
	add_child(fill)

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
