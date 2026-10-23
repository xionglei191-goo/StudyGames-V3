extends Node3D
## Complete Blender island, with gameplay locations resolved from imported SG_* nodes.
## Collision layers: 1 = obstacles/water volumes; 4 = actual walkable surfaces.

const MAP_PATH := "res://assets/world/island.glb"
const MANIFEST_PATH := "res://assets/world/manifest.json"

var _model: Node3D
var _manifest: Dictionary = {}
var _marker_records: Dictionary = {}
var _nodes: Dictionary = {}
var _stats: Dictionary = {}
var _ground_faces := PackedVector3Array()

func build(_room: String = "village") -> Dictionary:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_nodes.clear()
	_marker_records.clear()
	_ground_faces.clear()
	_stats = {"ground_meshes": 0, "ground_triangles": 0, "buildings": 0, "trunks": 0, "barriers": 0, "props": 0, "water_meshes": 0, "water_shapes": 0, "ignored_decorative_meshes": 0}
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if decoded is Dictionary:
		_manifest = decoded as Dictionary
	else:
		push_error("Blender world manifest is missing or invalid; run the Blender sync command.")
		return {}
	for record: Dictionary in _manifest.get("markers", []):
		_marker_records[str(record.get("name", ""))] = record
	var packed: PackedScene = load(MAP_PATH) as PackedScene
	if packed == null:
		push_error("Blender island.glb could not be loaded.")
		return {}
	_model = packed.instantiate() as Node3D
	_model.name = "BlenderIsland"
	add_child(_model)
	_index_nodes(_model)
	var bounds := Rect2(-74, -64, 148, 128)
	for node_name: String in _nodes:
		var node: Node3D = _nodes[node_name] as Node3D
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			var kind: String = _collision_kind(mesh_node)
			match kind:
				"ground":
					_add_ground(mesh_node)
				"building":
					_add_box_obstacle(mesh_node, Vector3(0.86, 1.0, 0.82), "Building")
					_stats.buildings += 1
				"trunk":
					_add_box_obstacle(mesh_node, Vector3(0.86, 1.0, 0.86), "TreeTrunk")
					_stats.trunks += 1
				"barrier":
					_add_box_obstacle(mesh_node, Vector3.ONE, "Fence")
					_stats.barriers += 1
				"fountain":
					_add_box_obstacle(mesh_node, Vector3(0.9, 4.2, 0.9), "Fountain")
					_stats.props += 1
				"water":
					_add_water_obstacle(mesh_node)
				_:
					_stats.ignored_decorative_meshes += 1
			if node_name == "ALPHA_Island_Continuous_Terrain":
				var box: AABB = _world_aabb(mesh_node)
				bounds = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	_finish_ground()
	var interactions: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	var npcs: Array[Dictionary] = []
	var markers: Dictionary = {}
	var spawn := Vector3.ZERO
	var spawn_found := false
	for marker_name: String in _marker_records:
		if not _nodes.has(marker_name):
			push_error("Imported Blender marker is missing: " + marker_name)
			continue
		var marker: Node3D = _nodes[marker_name] as Node3D
		var record: Dictionary = _marker_records[marker_name]
		var properties: Dictionary = record.get("properties", {})
		var imported_extras: Variant = marker.get_meta("extras", {})
		if imported_extras is Dictionary:
			properties.merge(imported_extras as Dictionary, true)
		var point: Vector3 = to_local(marker.global_position)
		var kind: String = str(properties.get("sg_kind", ""))
		markers[marker_name] = {"position": point, "node_path": str(get_path_to(marker)), "parent": str(marker.get_parent().name)}
		if kind == "spawn":
			spawn = point
			spawn_found = true
			continue
		var id: String = str(properties.get("sg_id", ""))
		if id.is_empty():
			continue
		var entry := {"id": id, "label": str(properties.get("sg_label", marker_name)), "position": point, "type": "landmark" if id.begins_with("landmark_") else "travel" if kind == "door" else "talk" if kind == "npc" else kind, "radius": float(properties.get("sg_radius", 2.6)), "marker": marker_name}
		if properties.has("sg_destination"):
			entry.destination = str(properties.sg_destination)
		# The preserved island marker used to open the single living room. Household
		# navigation now enters its second-level residence without moving island art.
		if id == "home_gate":
			entry.destination = "home_estate"
			entry.label = "回到我的家 · 小院与住宅"
		if properties.has("sg_greeting"):
			entry.greeting = str(properties.sg_greeting)
		interactions.append(entry)
		if kind == "door":
			landmarks.append({"id": id, "label": entry.label, "position": point, "destination": entry.get("destination", "")})
		if kind == "npc":
			npcs.append({"kind": str(properties.get("sg_npc", "bear")), "position": point, "name": str(properties.get("sg_name", "")), "angle": marker.global_rotation.y})
	if not spawn_found:
		push_error("SG_SPAWN is required in the exported Blender map.")
	_stats.marker_count = markers.size()
	_stats.visual_meshes = _model.find_children("*", "MeshInstance3D", true, false).size()
	return {"spawn": spawn, "bounds": bounds, "interactions": interactions, "camera_size": 24.0, "landmarks": landmarks, "npcs": npcs, "terrain": true, "room_label": "字母岛", "collision_stats": _stats.duplicate(true), "marker_nodes": markers, "source_scene": MAP_PATH}

func _index_nodes(node: Node3D) -> void:
	_nodes[str(node.name)] = node
	for child: Node in node.get_children():
		if child is Node3D:
			_index_nodes(child as Node3D)

func _collision_kind(mesh_node: MeshInstance3D) -> String:
	# Exported metadata has priority; manifest supplies semantics if importer omits extras.
	if mesh_node.has_meta("sg_collision"):
		return str(mesh_node.get_meta("sg_collision"))
	var extras: Variant = mesh_node.get_meta("extras", {})
	if extras is Dictionary and (extras as Dictionary).has("sg_collision"):
		return str((extras as Dictionary).sg_collision)
	var classification: Dictionary = _manifest.get("collision_by_node", {})
	if classification.has(str(mesh_node.name)):
		return str(classification[str(mesh_node.name)])
	for source_name: String in classification:
		if source_name.replace(".", "_") == str(mesh_node.name):
			return str(classification[source_name])
	return "none"

func _add_ground(mesh_node: MeshInstance3D) -> void:
	var faces: PackedVector3Array = mesh_node.mesh.get_faces()
	var transform_to_world: Transform3D = global_transform.affine_inverse() * mesh_node.global_transform
	var first: int = _ground_faces.size()
	_ground_faces.resize(first + faces.size())
	for index: int in range(faces.size()):
		_ground_faces[first + index] = transform_to_world * faces[index]
	_stats.ground_meshes += 1
	_stats.ground_triangles += faces.size() / 3

func _finish_ground() -> void:
	if _ground_faces.is_empty():
		push_error("No walkable terrain was exported from Blender.")
		return
	var body := StaticBody3D.new()
	body.name = "BlenderGroundCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_ground_faces)
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_ground_faces.clear()

func _world_aabb(mesh_node: MeshInstance3D) -> AABB:
	var local_bounds: AABB = mesh_node.get_aabb()
	var transform_to_world: Transform3D = global_transform.affine_inverse() * mesh_node.global_transform
	var result := AABB(transform_to_world * local_bounds.get_endpoint(0), Vector3.ZERO)
	for index: int in range(1, 8):
		result = result.expand(transform_to_world * local_bounds.get_endpoint(index))
	return result

func _add_box_obstacle(mesh_node: MeshInstance3D, size_factor: Vector3, prefix: String) -> void:
	var box: AABB = mesh_node.get_aabb()
	var world_scale: Vector3 = mesh_node.global_transform.basis.get_scale().abs()
	var size: Vector3 = box.size * world_scale * size_factor
	if size.x < 0.015 or size.y < 0.015 or size.z < 0.015:
		return
	var body := StaticBody3D.new()
	body.name = prefix + "_" + str(mesh_node.name)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.global_position = mesh_node.to_global(box.get_center())
	body.global_rotation = mesh_node.global_rotation
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _add_water_obstacle(mesh_node: MeshInstance3D) -> void:
	_stats.water_meshes += 1
	var body := StaticBody3D.new()
	body.name = "WaterVolume_" + str(mesh_node.name)
	# The character controller treats water contact as an unsafe landing and
	# returns to the last dry position; upper bridge decks remain traversable.
	body.set_meta("sg_water", true)
	body.collision_layer = 9
	body.collision_mask = 0
	add_child(body)
	var transform_to_world: Transform3D = global_transform.affine_inverse() * mesh_node.global_transform
	var faces: PackedVector3Array = mesh_node.mesh.get_faces()
	if "Lake" in str(mesh_node.name) or "lake" in str(mesh_node.name):
		# One convex ellipse volume; pier/islet surfaces sit above its upper plane.
		var box: AABB = _world_aabb(mesh_node)
		var points := PackedVector3Array()
		for index: int in range(32):
			var angle: float = TAU * float(index) / 32.0
			var x: float = box.get_center().x + cos(angle) * box.size.x * 0.5
			var z: float = box.get_center().z + sin(angle) * box.size.z * 0.5
			points.append(Vector3(x, box.end.y + 0.035, z))
			points.append(Vector3(x, box.end.y - 20.0, z))
		_add_convex(body, points)
	else:
		# Follow each river surface triangle, so bends do not block nearby roads.
		for first: int in range(0, faces.size(), 3):
			var a: Vector3 = transform_to_world * faces[first]
			var b: Vector3 = transform_to_world * faces[first + 1]
			var c: Vector3 = transform_to_world * faces[first + 2]
			if absf((b - a).cross(c - a).y) < 0.001:
				continue
			var points := PackedVector3Array([a + Vector3.UP * 0.025, b + Vector3.UP * 0.025, c + Vector3.UP * 0.025, a + Vector3.DOWN * 20, b + Vector3.DOWN * 20, c + Vector3.DOWN * 20])
			_add_convex(body, points)

func _add_convex(body: StaticBody3D, points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_stats.water_shapes += 1
