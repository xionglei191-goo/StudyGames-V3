extends SceneTree
## Verify all 35 exported rooms through the production scene and navigation code.
## Godot --headless --fixed-fps 60 --path game --script res://tests/test_blender_world.gd -- --test-harness

const PHYSICAL_ROOMS: Array[String] = [
	"landmark_A", "landmark_B", "landmark_C", "landmark_D", "landmark_E", "landmark_F", "landmark_G",
	"landmark_H", "landmark_I", "landmark_J", "landmark_K", "landmark_L", "landmark_M", "landmark_N",
	"landmark_O", "landmark_P", "landmark_Q", "landmark_R", "landmark_S", "landmark_T", "landmark_U",
	"landmark_V", "landmark_W", "landmark_X", "landmark_Y", "landmark_Z",
	"school", "classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field", "home",
]
const SCHOOL_ROOMS: Array[String] = ["classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field"]
const MAX_WALK_FRAMES := 2400
const PRODUCTION_SAVE := "user://island-save-v1.json"

var _main: Node3D
var _room_filter := ""
var _protected_before: Dictionary = {}
var _report: Dictionary = {"checks": [], "rooms": [], "failures": [], "complete": false, "physical_rooms": PHYSICAL_ROOMS, "coverage": "All 35 rooms: source GLB transforms, fresh import cache, grounded spawn, five-anchor and exit navigation, actual CharacterBody3D traversal to all 175 anchors and 35 exits, scene hierarchy, nearest-interaction activation and return to the corresponding parent-scene door."}


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Blender validation requires -- --test-harness to isolate player progress.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			_room_filter = arg.trim_prefix("--room=")
	call_deferred("_run")


func _run() -> void:
	_protected_before = _production_signature()
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	var ready_ok := await _wait_for_room("village")
	_check("initial_scene_ready", ready_ok)
	if not ready_ok:
		await _finish()
		return
	_main.muted = true
	_main.voice.stop()
	_report["main_map_sha256"] = FileAccess.get_sha256("res://assets/world/island.glb")
	_report["main_import_cache"] = _check_import_cache("res://assets/world/island.glb", "main_map")
	_check("isolated_save", str(root.get_node("State").save_path) == "user://validation-%s.json" % OS.get_process_id())
	_check("main_map_from_blender", str(_main.metadata.get("source_scene", "")) == "res://assets/world/island.glb")
	var terrain := _main.world.find_child("ALPHA_Island_Continuous_Terrain", true, false) as MeshInstance3D
	var terrain_material: Material = terrain.get_active_material(0) if terrain != null else null
	_check("main_terrain_vertex_colors_enabled", terrain_material is BaseMaterial3D and (terrain_material as BaseMaterial3D).vertex_color_use_as_albedo)
	_report["main_material_stats"] = _main.metadata.get("material_stats", {})
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors_manifest.json"))
	var exported: Array = manifest.get("rooms", [])
	var room_ids: Array[String] = []
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		room_ids.append("landmark_" + letter)
	room_ids.append("school")
	room_ids.append_array(SCHOOL_ROOMS)
	room_ids.append("home")
	_check("manifest_has_expected_rooms", exported.size() == room_ids.size())
	if not _room_filter.is_empty():
		var valid_room := room_ids.has(_room_filter)
		_check("focused_room_is_valid", valid_room)
		if not valid_room:
			await _finish()
			return
		room_ids = [_room_filter]
		_report["physical_rooms"] = [_room_filter]
		_report["coverage"] = "Focused validation of " + _room_filter + ": source transforms, spawn, five anchors, exit, actual walking and return."
	for room_id: String in room_ids:
		var asset_record: Dictionary = {}
		for candidate: Dictionary in exported:
			if str(candidate.get("room_id", "")) == room_id:
				asset_record = candidate
		_check(room_id + "/manifest_present", not asset_record.is_empty())
		await _visit_room(room_id, asset_record)
		_write_report()
	await _finish()


func _visit_room(room_id: String, asset_record: Dictionary) -> void:
	var result: Dictionary = {"room": room_id, "source_sha256": asset_record.get("source_sha256", ""), "source_glb": asset_record.get("source_glb", ""), "physical_traversal": _report.physical_rooms.has(room_id), "markers": [], "paths": [], "walks": []}
	_report.rooms.append(result)
	var path := "res://assets/interiors/%s.glb" % room_id
	var available := ResourceLoader.exists(path)
	_check(room_id + "/glb_available", available)
	if not available:
		return
	result["import_cache"] = _check_import_cache(path, room_id)
	if not asset_record.is_empty():
		_check(room_id + "/source_sha256", FileAccess.get_sha256(path) == str(asset_record.get("source_sha256", "")))
	await _main.change_room(room_id)
	var ready_ok := await _wait_for_room(room_id)
	_check(room_id + "/ready", ready_ok)
	if not ready_ok:
		return
	_check(room_id + "/source_is_blender", str(_main.metadata.get("source", "")) == "blender")
	var expected_parent := "school" if room_id in SCHOOL_ROOMS else "village"
	var expected_level := 3 if room_id in SCHOOL_ROOMS else 2
	_check(room_id + "/scene_level", int(_main.metadata.get("scene_level", -1)) == expected_level)
	_check(room_id + "/parent_room", str(_main.metadata.get("parent_room", "")) == expected_parent)
	result["scene_level"] = _main.metadata.get("scene_level")
	result["parent_room"] = _main.metadata.get("parent_room")
	var markers: Dictionary = _main.metadata.get("marker_nodes", {})
	var memory_count := 0
	for key: String in markers:
		if key.begins_with("SG_MEMORY_"):
			memory_count += 1
	_check(room_id + "/exactly_five_memory_markers", memory_count == 5)
	var source := (load(path) as PackedScene).instantiate() as Node3D
	var required: Array[String] = ["SG_SPAWN", "SG_EXIT", "SG_NPC_HOST"]
	for sequence in range(1, 6):
		required.append("SG_MEMORY_%02d" % sequence)
	if room_id == "school":
		for child_room: String in SCHOOL_ROOMS:
			required.append("SG_DOOR_" + child_room.to_upper())
		var child_door_count := 0
		for entry: Dictionary in _main.interactions:
			if str(entry.get("destination", "")) in SCHOOL_ROOMS:
				child_door_count += 1
		_check("school/exact_child_door_count", child_door_count == SCHOOL_ROOMS.size())
		for child_room: String in SCHOOL_ROOMS:
			var gate := _entry(child_room + "_gate")
			_check("school/door_destination/" + child_room, str(gate.get("destination", "")) == child_room and str(gate.get("marker", "")) == "SG_DOOR_" + child_room.to_upper())
	if room_id == "home":
		required.append_array(["SG_BED", "SG_WARDROBE", "SG_DECOR_FLOWER_BOX", "SG_DECOR_PICNIC", "SG_DECOR_LAMP", "SG_DECOR_MODEL_FLOWER_BOX", "SG_DECOR_MODEL_PICNIC", "SG_DECOR_MODEL_LAMP"])
	for key: String in required:
		var original := source.find_child(key, true, false) as Node3D
		var runtime := markers.get(key) as Node3D
		var present := original != null and runtime != null
		_check(room_id + "/marker_present/" + key, present)
		if present:
			var original_transform := _scene_transform(original)
			var equal := runtime.global_transform.is_equal_approx(original_transform)
			_check(room_id + "/source_transform/" + key, equal)
			result.markers.append({"name": key, "source_position": _vector(original_transform.origin), "runtime_position": _vector(runtime.global_position), "transform_matches": equal})
	source.free()
	for entry: Dictionary in _main.interactions:
		if str(entry.get("type",""))=="textbook_actor":
			var actor: Node3D = entry.get("actor_ref")
			_check(room_id + "/dynamic_actor_target/" + str(entry.id),is_instance_valid(actor) and (entry.position as Vector3).is_equal_approx(actor.global_position))
			var host: Node3D = markers.get("SG_NPC_HOST")
			_check(room_id + "/dynamic_actor_uses_safe_marker_area/" + str(entry.id),host!=null and is_instance_valid(actor) and actor.global_position.distance_to(host.global_position)<7.5)
			continue
		var key := str(entry.get("marker", ""))
		var runtime := markers.get(key) as Node3D
		_check(room_id + "/interaction_uses_marker/" + str(entry.id), runtime != null and (entry.position as Vector3).is_equal_approx(runtime.global_position))
	if markers.has("SG_SPAWN"):
		_check(room_id + "/spawn_uses_marker", (_main.metadata.spawn as Vector3).is_equal_approx((markers.SG_SPAWN as Node3D).global_position))
	for frame in range(30):
		await physics_frame
		await process_frame
	var spawn_position: Vector3 = _main.player.position
	var ground_query := PhysicsRayQueryParameters3D.create(spawn_position + Vector3.UP * 1.0, spawn_position - Vector3.UP * 1.5, 4)
	var floor_hit := _main.get_world_3d().direct_space_state.intersect_ray(ground_query)
	result["spawn"] = {"position": _vector(spawn_position), "on_floor": _main.player.is_on_floor(), "has_ground": not floor_hit.is_empty()}
	result.spawn["velocity"] = _vector(_main.player.velocity)
	result.spawn["contacts"] = _contact_summaries()
	if not floor_hit.is_empty():
		result.spawn["ground_position"] = _vector(floor_hit.position)
		result.spawn["ground_normal"] = _vector(floor_hit.normal)
	_check(room_id + "/spawn_grounded", _main.player.is_on_floor() and not floor_hit.is_empty())
	if not _main.player.is_on_floor():
		var samples: Array = []
		for frame in range(60):
			await physics_frame
			await process_frame
			if frame % 10 == 9:
				samples.append({"additional_frames": frame+1, "position": _vector(_main.player.position), "velocity": _vector(_main.player.velocity), "on_floor": _main.player.is_on_floor(), "contacts": _contact_summaries()})
		result.spawn["extended_settling"] = samples
	var destinations: Array[String] = []
	for sequence in range(1, 6):
		destinations.append("memory_%02d" % sequence)
	var exit_id := "school_exit" if room_id in SCHOOL_ROOMS else "village_exit"
	var exit_entry := _entry(exit_id)
	var expected_door: String = room_id + "_gate" if room_id in SCHOOL_ROOMS else str({"school": "school_gate", "home": "home_gate"}.get(room_id, room_id))
	_check(room_id + "/exit_destination", str(exit_entry.get("destination", "")) == expected_parent)
	_check(room_id + "/exit_return_id", str(exit_entry.get("return_id", "")) == expected_door)
	destinations.append(exit_id)
	# Navigation plans start from the real spawn; they do not claim physical traversal.
	for id: String in destinations:
		var entry := _entry(id)
		if entry.is_empty():
			_check(room_id + "/missing_destination/" + id, false)
			continue
		var accepted: bool = _main.navigate_to(entry.position)
		var endpoint: Vector3 = _main.player.path[-1] if not _main.player.path.is_empty() else _main.player.position
		var remaining := _distance_xz(endpoint, entry.position)
		var passed := accepted and remaining < float(entry.radius)
		result.paths.append({"id": id, "accepted": accepted, "waypoints": _main.player.path.size(), "endpoint": _vector(endpoint), "remaining_distance": remaining, "passed": passed})
		_check(room_id + "/spawn_path/" + id, passed)
		_main.player.path.clear()
	if bool(result.physical_traversal):
		for id: String in destinations:
			var reached: bool = await _walk_to(id, result)
			if reached and id.begins_with("memory_"):
				_main.interact_nearest()
				await process_frame
				_check(room_id + "/memory_panel/" + id, _main.ui.modal.visible and _main.ui.current_panel == "memory")
				_main._on_action("close")
				await process_frame
	var expected_room := "school" if exit_id == "school_exit" else "village"
	if bool(result.physical_traversal):
		var exit_selected := str(_main.nearest.get("id", "")) == exit_id
		_check(room_id + "/exit_selected_before_return", exit_selected)
		if not exit_selected:
			result["return"] = {"room": _main.room, "expected_room": expected_room, "door": expected_door, "passed": false, "reason": "The player could not select the exit after physical walking."}
			return
		_main.interact_nearest()
	else:
		await _main.interact_id(exit_id)
	var returned := await _wait_for_room(expected_room)
	_check(room_id + "/return_room", returned)
	var return_entry := _entry(str(expected_door))
	var distance := _distance_xz(_main.player.position, return_entry.get("return_position", return_entry.get("position", Vector3(INF, INF, INF)))) if returned else INF
	result["return"] = {"room": _main.room, "expected_room": expected_room, "door": expected_door, "distance": distance, "passed": returned and not return_entry.is_empty() and distance <= 2.0}
	_check(room_id + "/return_at_own_door", bool(result["return"].passed))
	print("ROOM %s: source=%s physical=%s return=%s distance=%.3f" % [room_id, "blender", result.physical_traversal, _main.room, distance])


func _walk_to(id: String, result: Dictionary) -> bool:
	var entry := _entry(id)
	if entry.is_empty():
		_check(str(_main.room) + "/walk_entry_exists/" + id, false)
		return false
	_main._on_action("close")
	await process_frame
	var start: Vector3 = _main.player.position
	var accepted: bool = _main.navigate_to(entry.position)
	var frames := 0
	var distance_walked := 0.0
	var previous := start
	while accepted and not _main.player.path.is_empty() and frames < MAX_WALK_FRAMES:
		await physics_frame
		await process_frame
		frames += 1
		distance_walked += _distance_xz(previous, _main.player.position)
		previous = _main.player.position
	await process_frame
	await process_frame
	var remaining := _distance_xz(_main.player.position, entry.position)
	var passed := accepted and remaining < float(entry.radius) and frames < MAX_WALK_FRAMES
	result.walks.append({"id": id, "start": _vector(start), "finish": _vector(_main.player.position), "frames": frames, "distance_walked": distance_walked, "remaining_distance": remaining, "nearest": _main.nearest.get("id", ""), "passed": passed})
	_check(str(_main.room) + "/physical_walk/" + id, passed)
	_check(str(_main.room) + "/physical_interaction_available/" + id, passed and str(_main.nearest.get("id", "")) == id)
	print("INTERIOR WALK %s/%s: %s (%.3f remaining, %d frames)" % [_main.room, id, "PASS" if passed else "FAIL", remaining, frames])
	return passed and str(_main.nearest.get("id", "")) == id


func _scene_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


func _contact_summaries() -> Array:
	var contacts: Array = []
	for index in range(_main.player.get_slide_collision_count()):
		var hit: KinematicCollision3D = _main.player.get_slide_collision(index)
		var collider: Object = hit.get_collider()
		contacts.append({"collider": str((collider as Node).get_path()) if collider is Node else str(collider), "normal": _vector(hit.get_normal()), "position": _vector(hit.get_position())})
	return contacts


func _check_import_cache(path: String, label: String) -> Dictionary:
	var config := ConfigFile.new()
	var imported := config.load(path + ".import") == OK
	var cache_path := str(config.get_value("remap", "path", "")) if imported else ""
	var checksum_path := cache_path.get_basename() + ".md5"
	var recorded_md5 := ""
	if not cache_path.is_empty() and FileAccess.file_exists(checksum_path):
		for line: String in FileAccess.get_file_as_string(checksum_path).split("\n"):
			if line.begins_with("source_md5="):
				recorded_md5 = line.get_slice("=", 1).strip_edges().trim_prefix('"').trim_suffix('"')
	var actual_md5 := FileAccess.get_md5(path)
	var passed := imported and FileAccess.file_exists(cache_path) and not recorded_md5.is_empty() and recorded_md5 == actual_md5
	_check(label + "/import_cache_matches_source", passed)
	return {"cache_path": cache_path, "source_md5": actual_md5, "imported_source_md5": recorded_md5, "passed": passed}


func _entry(id: String) -> Dictionary:
	for entry: Dictionary in _main.interactions:
		if str(entry.id) == id:
			return entry
	return {}


func _wait_for_room(expected: String) -> bool:
	var stable := 0
	for frame in range(900):
		await physics_frame
		await process_frame
		if _main.scene_ready and not _main.loading_room and _main.nav_ready and _main.room == expected:
			stable += 1
			if stable >= 3:
				return true
		else:
			stable = 0
	return false


func _check(label: String, passed: bool) -> void:
	_report.checks.append({"name": label, "passed": passed})
	if not passed:
		_report.failures.append(label)
		print("FAIL: " + label)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _production_signature() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak"]:
		var path := PRODUCTION_SAVE + suffix
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result


func _write_report() -> void:
	_report["engine"] = Engine.get_version_info()["string"]
	_report["passed"] = _report.failures.is_empty() and bool(_report.complete)
	_report["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	var directory := ProjectSettings.globalize_path("res://../.local/validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var report_name := "blender-world-report.json" if _room_filter.is_empty() else "blender-world-%s-report.json" % _room_filter
	var file := FileAccess.open(directory.path_join(report_name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	else:
		push_error("Could not write Blender world validation report.")


func _finish() -> void:
	_report["complete"] = true
	_report["production_save_unchanged"] = _production_signature() == _protected_before
	_check("production_save_unchanged", bool(_report.production_save_unchanged))
	_write_report()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	var validation_save := "user://validation-%s.json" % OS.get_process_id()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(validation_save + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(validation_save + suffix))
	if _report.failures.is_empty():
		print("PASS: %d Blender rooms, %d checks, %d rooms physically traversed; player save unchanged" % [_report.rooms.size(), _report.checks.size(), _report.physical_rooms.size()])
		quit(0)
	else:
		print("FAIL: %d Blender world checks failed; see .local/validation/blender-world-report.json" % _report.failures.size())
		quit(1)
