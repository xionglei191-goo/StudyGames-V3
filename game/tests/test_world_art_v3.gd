extends SceneTree
## Focused visual-only integration invariant check. Never run without --test-harness.
## --room=landmark_A,classroom,home,landmark_C --capture (capture needs a renderer)
const WorldArt = preload("res://scripts/world_art.gd")
const BlenderMaterials = preload("res://scripts/blender_materials.gd")
const Interior = preload("res://scripts/imported_interior.gd")
const ImportedWorld = preload("res://scripts/imported_world.gd")
const WorldBuilder = preload("res://scripts/world_builder.gd")
var report: Dictionary = {"revision":"world-refresh-v3","status":"RUNNING","rooms":[],"failures":[],"screenshots":[]}
var output := ""
var room_filter := ""
var capture := false
var art_width := 960
var art_height := 640
var capture_dir := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("World art verification requires -- --test-harness to isolate saves.")
		quit(2)
		return
	output = ProjectSettings.globalize_path("res://").path_join("../assets/art/world_refresh_v3/runtime-qa.json").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--room="): room_filter = argument.trim_prefix("--room=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--art-width="): art_width = int(argument.trim_prefix("--art-width="))
		if argument.begins_with("--art-height="): art_height = int(argument.trim_prefix("--art-height="))
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
		if argument == "--capture": capture = true
	report["requested_window"] = [art_width,art_height]
	report["capture_metadata"] = []
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		report.failures.append(label)
		push_error(label)

func _original_snapshot(nodes: Array[Node]) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		var row: Dictionary = {}
		if node is Node3D:
			row["transform"] = node.transform
			row["global_transform"] = node.global_transform
			row["visible"] = node.visible
		if node is MeshInstance3D:
			row["aabb"] = node.get_aabb()
			row["mesh_id"] = node.mesh.get_instance_id() if node.mesh != null else 0
		if node is CollisionObject3D:
			row["collision_layer"] = node.collision_layer
			row["collision_mask"] = node.collision_mask
		if node is CollisionShape3D:
			row["disabled"] = node.disabled
			row["shape_id"] = node.shape.get_instance_id() if node.shape != null else 0
			if node.shape is ConcavePolygonShape3D: row["shape_data"] = node.shape.get_faces().duplicate()
			elif node.shape is ConvexPolygonShape3D: row["shape_data"] = node.shape.points.duplicate()
			elif node.shape is BoxShape3D: row["shape_data"] = node.shape.size
		result[str(node.get_instance_id())] = row
	return result

func _run() -> void:
	var protected := "user://island-save-v1.json"
	var save_before := FileAccess.get_sha256(protected) if FileAccess.file_exists(protected) else "absent"
	var rooms: Array[String] = ["village"]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors_manifest.json"))
	for entry: Dictionary in manifest.get("rooms",[]): rooms.append(str(entry.room_id))
	if not room_filter.is_empty():
		var filtered: Array[String] = []
		for room: String in room_filter.split(","):
			_check(rooms.has(room),"valid_room/" + room)
			if rooms.has(room): filtered.append(room)
		rooms = filtered
	for room: String in rooms:
		var stage := WorldBuilder.new()
		root.add_child(stage)
		stage._lighting(room)
		var imported: Node3D = ImportedWorld.new() if room == "village" else Interior.new()
		stage.add_child(imported)
		if room == "village": imported.build()
		else: imported.build(room,{"room_id":room,"name":room})
		var original_nodes: Array[Node] = imported.find_children("*","",true,false)
		var before := _original_snapshot(original_nodes)
		var collisions_before := imported.find_children("*","CollisionObject3D",true,false).size()
		var shape_count_before := imported.find_children("*","CollisionShape3D",true,false).size()
		BlenderMaterials.restore_vertex_colors(imported)
		var stats: Dictionary = imported.get_meta("world_art_stats",{})
		_check(not stats.is_empty(),room + "/has_art_stats")
		_check(before == _original_snapshot(original_nodes),room + "/original_transforms_aabbs_visibility_collisions_unchanged")
		_check(collisions_before == imported.find_children("*","CollisionObject3D",true,false).size(),room + "/no_new_collision_objects")
		_check(shape_count_before == imported.find_children("*","CollisionShape3D",true,false).size(),room + "/no_new_collision_shapes")
		var replacements: Array[Dictionary] = []
		for node: Node in original_nodes:
			if not node.has_meta("world_art_replacement"): continue
			var visual: Node3D = node.get_node_or_null("WorldArt_" + str(node.get_meta("world_art_replacement")))
			_check(visual != null,room + "/replacement_child/" + str(node.name))
			_check(node.layers == 0,room + "/original_render_suppressed/" + str(node.name))
			if visual != null:
				var real_meshes := visual.find_children("*","MeshInstance3D",true,false)
				_check(not real_meshes.is_empty(),room + "/replacement_real_mesh/" + str(node.name))
				for mesh: MeshInstance3D in real_meshes:
					_check(mesh.visible and mesh.layers != 0 and mesh.mesh != null,room + "/replacement_renderable/" + str(node.name))
				_check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),room + "/visual_has_no_colliders/" + str(node.name))
			replacements.append({"source_node":str(node.name),"kind":str(node.get_meta("world_art_replacement"))})
		_check(replacements.size() == int(stats.get("props",-1)),room + "/stats_match_entities")
		var nodes_after := imported.find_children("*","",true,false).size()
		var second := WorldArt.apply_to_scene(imported)
		_check(second == stats and imported.find_children("*","",true,false).size() == nodes_after,room + "/idempotent_apply")
		report.rooms.append({"room":room,"original_nodes":original_nodes.size(),"collision_objects":collisions_before,"collision_shapes":shape_count_before,"stats":stats,"replacements":replacements})
		if capture and room in ["landmark_A","landmark_C","classroom","home"]:
			await _capture(stage,imported,room)
		stage.queue_free()
		await process_frame
	var save_after := FileAccess.get_sha256(protected) if FileAccess.file_exists(protected) else "absent"
	_check(save_before == save_after,"formal_save_unchanged")
	report["formal_save_unchanged"] = save_before == save_after
	report.status = "PASS" if report.failures.is_empty() else "FAIL"
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t"))
	print("WORLD_ART_V3 ",report.status," rooms=",rooms.size()," failures=",report.failures.size()," output=",output)
	quit(0 if report.failures.is_empty() else 1)

func _capture(stage: Node3D, imported: Node3D, room: String) -> void:
	var focuses: Dictionary = {"landmark_A":["A_Entrance_Basket","A_Tree_3_Fruit_0"],"landmark_C":["Pickup_Cake_Layer"],"classroom":["Pupil_Book"],"home":["Desk_Journal"]}
	root.size = Vector2i(art_width,art_height)
	var destination := output.get_base_dir() if capture_dir.is_empty() else capture_dir
	DirAccess.make_dir_recursive_absolute(destination)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	stage.add_child(camera)
	camera.make_current()
	for node_name: String in focuses.get(room,[]):
		var source := imported.find_child(node_name,true,false) as MeshInstance3D
		_check(source != null,"capture_source/" + room + "/" + node_name)
		if source == null: continue
		var focus := source.global_transform * source.get_aabb().get_center()
		camera.global_position = focus + Vector3(4,5,6)
		camera.look_at(focus,Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := destination.path_join(room + "-" + node_name + ".png")
		var picture := root.get_texture().get_image()
		var error := picture.save_png(path)
		_check(error == OK,"capture/" + room + "/" + node_name)
		report.screenshots.append(path)
		report.capture_metadata.append({"room":room,"node":node_name,"path":path,"sha256":FileAccess.get_sha256(path),"requested_window":[art_width,art_height],"actual_window":[root.size.x,root.size.y],"viewport":[picture.get_width(),picture.get_height()]})
