extends Node3D
## Editable Blender rooms. Geometry and marker transforms belong to the GLB.

var _scene: Node3D
var _decorations: Dictionary = {}
var _markers: Dictionary = {}
var _interactions: Array[Dictionary] = []
const HomeCatalog = preload("res://scripts/home_catalog.gd")

static func available(room_id: String) -> bool:
	return ResourceLoader.exists("res://assets/interiors/%s.glb" % room_id)

func build(room_id: String, plan: Dictionary) -> Dictionary:
	var path := "res://assets/interiors/%s.glb" % room_id
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Blender room could not be loaded: " + path)
		return {}
	_scene = packed.instantiate() as Node3D
	_scene.name = "BlenderRoom"
	add_child(_scene)
	var meshes := _scene.find_children("*", "MeshInstance3D", true, false)
	var scene_bounds := AABB()
	var first := true
	for mesh_node in meshes:
		var mesh := mesh_node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if first:
			scene_bounds = box
			first = false
		else:
			scene_bounds = scene_bounds.merge(box)
		if str(mesh.name).begins_with("SG_FLOOR_"):
			_add_collision(mesh, 4, false)
		elif str(mesh.name).begins_with("SG_COLLIDER_"):
			_add_collision(mesh, 1, true)
			mesh.visible = false
	for node in _scene.find_children("SG_*", "Node3D", true, false):
		_markers[str(node.name)] = node
	var spawn := _position("SG_SPAWN")
	var bounds := Rect2(scene_bounds.position.x, scene_bounds.position.z, scene_bounds.size.x, scene_bounds.size.z)
	var manifest_path := "res://data/interiors_manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for entry in manifest.get("rooms", []):
			if str(entry.get("room_id", "")) == room_id and entry.get("bounds", []).size() == 4:
				var b: Array = entry.bounds
				bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	var return_to: Dictionary = plan.get("return_to", {})
	var parent_room := str(return_to.get("room_id", "village"))
	var exit_id := {"school":"school_exit", "home_hall":"home_exit"}.get(parent_room, "village_exit") as String
	var return_id := room_id + "_gate" if parent_room in ["school", "home_hall"] else ("school_gate" if room_id == "school" else (room_id if room_id.begins_with("landmark_") else "home_gate"))
	return_id = str(return_to.get("interaction_id", return_id))
	if room_id == "home_hall":
		exit_id = "courtyard_exit"
		return_id = "house_entry"
	var exit_label: String = {"school":"回到校园", "home_hall":"回到家里的走廊", "home_estate":"走出家门 · 回到小院"}.get(parent_room, "回到字母岛")
	_bind_travel(exit_id, exit_label, "SG_EXIT", parent_room, return_id)
	var memory_count := 0 if room_id in HomeCatalog.HOME_NAV_ROOMS else 5
	for i in range(1, memory_count + 1):
		var key := "SG_MEMORY_%02d" % i
		var title := "探索这里"
		var anchors: Array = plan.get("anchors", [])
		if anchors.size() >= i:
			title = str(anchors[i-1].get("label", title))
		_bind("memory_%02d" % i, title, key, "memory", 1.65)
	var npcs: Array[Dictionary] = []
	var host_id := "host"
	var host_name := "邻居"
	var host_kind := "rabbit"
	match room_id:
		"landmark_A":
			host_id = "gardener"
			host_name = "兔兔"
			_bind("orchard", "采一颗苹果", "SG_MEMORY_02", "action", 2.1)
		"landmark_C":
			host_id = "baker"
			host_name = "熊叔"
			host_kind = "bear"
		"school":
			host_name = "老师"
			host_kind = "teacher"
			var doors: Dictionary = plan.get("model_bindings", {}).get("doors", {})
			for area in plan.get("areas", []):
				var destination := str(area.get("room_id", ""))
				if area.get("separate_scene", false) and doors.has(destination):
					_bind_travel(destination + "_gate", "走进" + str(area.get("name", destination)), str(doors[destination]), destination)
		"classroom":
			host_id = "teacher"
			host_name = "老师"
			host_kind = "teacher"
		"canteen":
			host_id = "lunch"
			host_name = "食堂阿姨"
			host_kind = "bear"
		"playground":
			host_id = "sports"
			host_name = "小伙伴"
		"football_field":
			host_name = "足球教练"
			host_kind = "teacher"
		"music_room", "art_room", "science_room":
			host_name = {"music_room":"音乐老师", "art_room":"美术老师", "science_room":"科学老师"}[room_id]
			host_kind = "teacher"
		"home":
			_bind("decorate", "装扮我的小屋", "SG_WARDROBE", "decorate", 2.0)
			for id in ["flower_box", "picnic", "lamp"]:
				var model_key: String = "SG_DECOR_MODEL_" + str(id).to_upper()
				if _markers.has(model_key):
					_decorations[id] = _markers[model_key]
		"home_estate":
			_bind_travel("house_entry", "走进家门", "SG_HOUSE_ENTRY", "home_hall")
			if _markers.has("SG_HOUSE_ENTRY"): _interactions.back()["radius"] = 1.5
		"home_hall":
			var doors: Dictionary = plan.get("model_bindings", {}).get("doors", {})
			for area: Dictionary in plan.get("areas", []):
				var destination := str(area.get("room_id", ""))
				if destination in HomeCatalog.CHILD_ROOMS and area.get("separate_scene", false) and doors.has(destination):
					_bind_travel(destination + "_gate", "走进" + str(area.get("name", destination)), str(doors[destination]), destination)
		"home_bedroom":
			_bind("bed", "休息，迎接新的一天", "SG_BED", "rest", 2.0)
	var is_household := HomeCatalog.is_home_space(room_id)
	if not is_household and _markers.has("SG_NPC_HOST"):
		_bind(host_id, "和%s聊一聊" % host_name, "SG_NPC_HOST", "npc", 2.3, "good_morning")
		npcs.append({"kind":host_kind,"position":_position("SG_NPC_HOST"),"name":host_name,"angle":0.0})
	var camera_size := 34.0 if room_id == "football_field" else (31.0 if room_id == "school" else (21.5 if room_id == "playground" else 18.5))
	camera_size = float(plan.get("camera_size", camera_size))
	return {"spawn":spawn,"bounds":bounds,"interactions":_interactions,"camera_size":camera_size,"landmarks":[],"terrain":true,"room_label":str(plan.get("name", room_id)),"npcs":npcs,"source":"blender","marker_count":_markers.size(),"marker_nodes":_markers,"parent_room":parent_room,"scene_level":int(plan.get("scene_level",2))}

func _add_collision(mesh: MeshInstance3D, layer: int, convex: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = mesh.mesh.create_convex_shape() if convex else mesh.mesh.create_trimesh_shape()
	mesh.add_child(body)
	body.add_child(collision)

func _position(key: String) -> Vector3:
	if _markers.has(key):
		return (_markers[key] as Node3D).global_position
	push_error("Missing Blender interaction marker: " + key)
	return Vector3.ZERO

func _bind(id: String, label: String, key: String, type: String, radius: float, greeting: String = "") -> void:
	if _markers.has(key):
		_interactions.append({"id":id,"label":label,"position":_position(key),"type":type,"radius":radius,"greeting":greeting,"marker":key})

func set_decoration(id: String, enabled: bool) -> void:
	if _decorations.has(id):
		(_decorations[id] as Node3D).visible = enabled

func _bind_travel(id: String, label: String, key: String, destination: String, return_id: String = "") -> void:
	if not _markers.has(key):
		push_error("Missing Blender travel marker: " + key)
		return
	_bind(id, label, key, "travel", 1.7)
	_interactions.back()["destination"] = destination
	_interactions.back()["return_id"] = return_id
