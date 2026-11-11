extends "res://tests/drive_model_sync/test_home_indoor.gd"
## Own16 native import evidence: 44 direct-load views plus a physical home route.
## Dedicated output; never rewrites historical refinement reports.

const CAPTURE_DIR := "res://../docs/verification/drive-model-sync-own16-20261027/native"
const LEDGER_PATH := "res://../.local/imports/drive-own16-20261027/metadata/SCENE-LEDGER44.json"
var _captures: Array[Dictionary] = []
var _scene_resources: Array[Dictionary] = []
var _rooms: Array[String] = ["village"]
var _capture_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
var _source_before: Dictionary = {}
var _native_finishing := false
var _save_path := ""
var _started_usec := 0

func _run() -> void:
	root.size = Vector2i(1440, 900)
	_started_usec = Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors_manifest.json"))
	for row: Dictionary in manifest.get("rooms", []): _rooms.append(str(row.room_id))
	_check("exactly_44_runtime_scenes", _rooms.size() == 44)
	_check("native_display_server", DisplayServer.get_name() != "headless")
	_protected_before = _production_signature()
	_source_before = _source_signature()
	if DisplayServer.get_name() == "headless":
		await _finish()
		return
	create_timer(1800.0).timeout.connect(func(): _check("native_capture_timeout", false); _finish())
	AudioServer.set_bus_mute(0, true)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready", false)
		await _finish()
		return
	var state: Node = root.get_node("State")
	_save_path = str(state.save_path)
	_check("isolated_save", _save_path == "user://validation-%d.json" % OS.get_process_id())
	if _save_path != "user://validation-%d.json" % OS.get_process_id():
		await _finish()
		return
	_main.muted = true
	_main.voice.stop()
	_main.sounds.enabled = false
	_main.ui.reduced_motion = true
	_main.player.reduced_motion = true
	_main.application_backgrounded = false
	state.set_preference("fixed_day", true)
	state.set_preference("effects", false)
	state.set_preference("voice", false)
	state.set_preference("reduced_motion", true)
	_main._close()
	for room_id: String in _rooms:
		if _main.room != room_id: await _main.change_room(room_id)
		var ready_ok: bool = await _wait_for_room(room_id)
		_check("scene_ready/" + room_id, ready_ok)
		if not ready_ok: continue
		_main._close()
		_set_fixed_weather()
		await _frames(24)
		_check_scene_resources(room_id)
		await _capture(room_id + "-play", "unmodified_production_camera_at_default_room_spawn", "direct_room_visual_load")
		await _overview(room_id)
	await _physical_home_route()
	await _finish()

func _set_fixed_weather() -> void:
	_main.living.set_day_phase("day", true)
	_main.living.set_weather("clear", true)
	_main.living.set_context({"fixed_day":true, "fixed_weather":true, "reduced_motion":true})
	_main.ui.toast_timer = 0
	_main.ui.toast_label.hide()
	_main.ui.bubble_panel.hide()

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _layout() -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw

func _overview(room_id: String) -> void:
	var previous: Transform3D = _main.camera.transform
	var previous_size: float = _main.camera.size
	_main.capturing_photo = true
	_main.ui.hide()
	var bounds: Rect2 = _main.metadata.bounds
	var center := Vector3(bounds.get_center().x, 0.6, bounds.get_center().y)
	var span := maxf(bounds.size.x, bounds.size.y)
	if room_id == "village": center.y = 5.3
	_main.camera.position = center + Vector3(18, 30, 28) * maxf(1.0, span / 26.0)
	_main.camera.look_at(center, Vector3.UP)
	_main.camera.size = span * 1.22
	await _capture(room_id + "-overview", "explicit_fixed_overview_camera_hud_hidden", "direct_room_visual_load")
	_main.camera.transform = previous
	_main.camera.size = previous_size
	_main.ui.show()
	_main.capturing_photo = false

func _capture(id: String, kind: String, entry_mode: String) -> void:
	await _layout()
	var picture: Image = root.get_texture().get_image()
	var image_path := _capture_dir.path_join(id + ".png")
	_check("capture_saved/" + id, picture.save_png(image_path) == OK)
	_check("native_1440x900/" + id, picture.get_size() == Vector2i(1440, 900))
	_check("no_room_selection_menu/" + id, _main.ui.current_panel != "home_entry")
	_captures.append({"id":id, "room":_main.room, "kind":kind, "entry_mode":entry_mode,
		"image":image_path, "image_size":[picture.get_width(),picture.get_height()],
		"window_size":[root.size.x,root.size.y], "camera":_camera_record(),
		"player_position":_vector(_main.player.position), "hud_visible":_main.ui.visible,
		"panel":_main.ui.current_panel, "weather":_main.living.get_status(),
		"scene_source":str(_main.metadata.get("source", _main.metadata.get("source_scene", "")))})
	print("OWN16_NATIVE_CAPTURE " + id)
	_write_progress()

func _camera_record() -> Dictionary:
	return {"position":_vector(_main.camera.position), "basis_x":_vector(_main.camera.basis.x),
		"basis_y":_vector(_main.camera.basis.y), "basis_z":_vector(_main.camera.basis.z),
		"size":_main.camera.size, "projection":_main.camera.projection}

func _check_scene_resources(room_id: String) -> void:
	var meshes: Array[Node] = _main.world.find_children("*", "MeshInstance3D", true, false)
	var material_count := 0
	var surface_count := 0
	var missing_meshes: Array[String] = []
	var missing_materials: Array[String] = []
	var invalid_textures: Array[String] = []
	var textures: Dictionary = {}
	var colliders: Array[Dictionary] = []
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		if str(mesh.name).begins_with("SG_COLLIDER_"):
			colliders.append({"name":str(mesh.name), "visible":mesh.visible, "visible_in_tree":mesh.is_visible_in_tree()})
			_check("collider_proxy_hidden/" + room_id + "/" + str(mesh.name), not mesh.visible and not mesh.is_visible_in_tree())
		if mesh.mesh == null:
			missing_meshes.append(str(mesh.get_path()))
			continue
		for surface: int in mesh.mesh.get_surface_count():
			surface_count += 1
			var material: Material = mesh.get_active_material(surface)
			if material == null:
				missing_materials.append(str(mesh.get_path()) + "/surface_" + str(surface))
				continue
			material_count += 1
			if material is BaseMaterial3D:
				for slot: int in BaseMaterial3D.TEXTURE_MAX:
					var texture: Texture2D = (material as BaseMaterial3D).get_texture(slot)
					if texture == null: continue
					var key := str(texture.get_instance_id())
					textures[key] = {"path":texture.resource_path, "width":texture.get_width(), "height":texture.get_height()}
					if texture.get_width() <= 0 or texture.get_height() <= 0: invalid_textures.append(texture.resource_path)
	_check("mesh_resources_present/" + room_id, not meshes.is_empty() and missing_meshes.is_empty())
	_check("surface_materials_present/" + room_id, surface_count > 0 and missing_materials.is_empty())
	_check("referenced_texture_dimensions_valid/" + room_id, invalid_textures.is_empty())
	_scene_resources.append({"room":room_id, "mesh_instances":meshes.size(), "mesh_surfaces":surface_count,
		"active_material_surfaces":material_count, "missing_meshes":missing_meshes,
		"missing_materials":missing_materials, "textures":textures.values(), "invalid_textures":invalid_textures,
		"collider_proxies":colliders, "scope":"All instantiated world mesh resources and active surface materials checked. Existing BaseMaterial3D texture references have nonzero dimensions; intentionally untextured materials are allowed."})

func _physical_home_route() -> void:
	await _main.change_room("home_estate")
	if not await _wait_for_room("home_estate"):
		_check("physical_route_initial_courtyard_ready", false)
		return
	_main._close()
	_set_fixed_weather()
	if not await _walk_to_entry("house_entry", "native_front_door"): return
	await _capture("route-01-courtyard-front-door", "production_camera_after_actual_courtyard_walk", "physical_walk_after_direct_courtyard_start")
	if not await _transition("house_entry", "home_hall"): return
	await _check_hall_contract("native_route_initial_hall")
	await _capture("route-02-hall-entry", "production_camera_after_physical_E_front_door", "physical_door_transition")
	for rid: String in ["home_bedroom", "home_kitchen"]:
		_main.show_map()
		await _layout()
		if not await _choose_and_follow(rid + "_gate"): return
		await _capture("route-" + rid + "-hall-door", "production_camera_after_actual_map_button_walk_to_room_door", "physical_walk_from_map_button")
		if not await _transition(rid + "_gate", rid): return
		await _capture("route-" + rid + "-entered", "production_camera_after_physical_E_room_entry", "physical_door_transition")
		if not await _walk_to_entry("home_exit", "native_return_to_hall_" + rid): return
		if not await _transition("home_exit", "home_hall"): return
		await _capture("route-" + rid + "-returned-hall", "production_camera_after_return_to_corresponding_hall_door", "physical_door_transition")
	_main.show_map()
	await _layout()
	if not await _choose_and_follow("courtyard_exit"): return
	if not await _transition("courtyard_exit", "home_estate"): return
	await _capture("route-09-returned-courtyard", "production_camera_after_physical_hall_exit", "physical_door_transition")
	_check("native_physical_home_route_completed", _main.room == "home_estate" and _report.transitions.size() == 6)

func _production_signature() -> Dictionary:
	var result: Dictionary = {}
	for filename: String in DirAccess.get_files_at("user://"):
		if not filename.begins_with("validation-"): result["user://" + filename] = FileAccess.get_sha256("user://" + filename)
	_hash_tree(ProjectSettings.globalize_path("res://../.local/shared-profiles"), result)
	return result

func _hash_tree(path: String, result: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for filename: String in DirAccess.get_files_at(path):
		result[path.path_join(filename)] = FileAccess.get_sha256(path.path_join(filename))
	for directory: String in DirAccess.get_directories_at(path): _hash_tree(path.path_join(directory), result)

func _source_signature() -> Dictionary:
	var result: Dictionary = {}
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEDGER_PATH))
	for row: Dictionary in ledger.get("rows", []):
		var path := "res://../" + str(row.runtime_path)
		result[path] = FileAccess.get_sha256(path)
	for path: String in ["res://project.godot", "res://data/interiors_manifest.json", "res://assets/world/manifest.json", "res://scripts/imported_world.gd", "res://scripts/imported_interior.gd", "res://data/home_hierarchy.json"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func _write_progress() -> void:
	var file := FileAccess.open(_capture_dir.path_join("progress.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"captures":_captures.size(), "last_capture":_captures[-1].id if not _captures.is_empty() else "", "scenes_checked":_scene_resources.size(), "failures":_report.failures}, "  "))
		file.close()

func _finish() -> void:
	if _native_finishing: return
	_native_finishing = true
	var protected_after := _production_signature()
	_check("production_save_photos_shared_profiles_unchanged", _protected_before == protected_after)
	_check("runtime_sources_stable_during_capture", _source_before == _source_signature())
	_check("all_44_scene_resources_checked", _scene_resources.size() == 44)
	var standard_captures := _captures.filter(func(item: Dictionary) -> bool: return item.entry_mode == "direct_room_visual_load")
	_check("all_88_production_overview_images", standard_captures.size() == 88)
	_check("all_9_physical_home_route_images", _captures.size() - standard_captures.size() == 9)
	_report["captures"] = _captures
	_report["scene_resources"] = _scene_resources
	_report["rooms"] = _rooms
	_report["result"] = "PASS" if _report.failures.is_empty() else "FAIL"
	_report["engine"] = Engine.get_version_info()["string"]
	_report["renderer"] = RenderingServer.get_current_rendering_method()
	_report["display_server"] = DisplayServer.get_name()
	_report["gpu"] = RenderingServer.get_video_adapter_name()
	_report["engine_arguments"] = OS.get_cmdline_args()
	_report["isolated_save"] = _save_path
	_report["production_before"] = _protected_before
	_report["production_after"] = protected_after
	_report["source_sha256"] = _source_before
	_report["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	_report["elapsed_seconds"] = float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	_report["scope"] = "44 native 1440x900 direct scene loads, each with unchanged production camera at default spawn and explicit review overview. Nine additional screenshots follow actual walking/map-button navigation and physical E doors from courtyard to hall, bedroom, kitchen and back. No general gameplay, learning-efficacy, or performance claim. Separate stdout/stderr logs document engine diagnostics."
	var file := FileAccess.open(_capture_dir.path_join("report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_report, "  "))
		file.close()
	else:
		push_error("Could not write native report")
		_report.failures.append("report_write_failed")
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	if _save_path == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(_save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path + suffix))
	print("OWN16_NATIVE_RESULT " + JSON.stringify({"result":_report.result,"captures":_captures.size(),"scenes":_scene_resources.size(),"checks":_report.checks.size(),"failures":_report.failures}))
	quit(0 if _report.failures.is_empty() else 1)
