extends "res://tests/test_school_hierarchy.gd"
## Native rendered evidence. Overview/prop cameras are explicitly review framing;
## gameplay frames retain the production camera. Only the validation save is used.

const House = preload("res://scripts/home_catalog.gd")
var capture_dir := ProjectSettings.globalize_path("res://../docs/verification/home-hierarchy-v1/native")
var captures: Array[Dictionary] = []

func _run() -> void:
	root.size = Vector2i(1440, 900)
	_protected_before = _production_signature()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	create_timer(240).timeout.connect(func(): _check("capture_timeout", false); _finish())
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready", false)
		await _finish()
		return
	_check("native_renderer", DisplayServer.get_name() != "headless")
	_main.muted = true
	_main.ui.reduced_motion = true
	_main.application_backgrounded = false
	root.get_node("State").set_preference("fixed_day", true)
	for rid: String in House.ROOMS:
		await _main.change_room(rid)
		await _wait_for_room(rid)
		_main.living.set_day_phase("day", true)
		_main.living.set_weather("clear", true)
		await _frames(8)
		await _capture(rid + "-play", "production_gameplay_camera")
		await _overview(rid)
		if rid == "home_estate":
			_main.show_map()
			await _capture("home-estate-map-1440", "production_map_panel")
			await _click_text("在家的一天")
			await _capture("home-day-1440", "production_household_day_panel")
			_main._on_action("close")
		if rid == "home_bedroom":
			await _task_captures(rid)
		if rid == "home_bathroom":
			await _walk_to_entry("memory_02", "native_source_panel")
			_main.interact_nearest()
			await _capture("home-memory-1440", "production_memory_panel")
			await _click_text("看看课本出处")
			await _capture("home-source-1440", "production_textbook_source_panel")
			_main._on_action("close")
	root.size = Vector2i(960, 640)
	await _frames(6)
	await _main.change_room("home_estate")
	await _wait_for_room("home_estate")
	_main.show_map()
	await _capture("home-estate-map-960", "production_map_panel_minimum_window")
	await _click_text("小院里的五个生活位置")
	await _capture("home-courtyard-points-960", "production_courtyard_points_minimum_window")
	_main._on_action("close")
	await _main.change_room("home_bathroom")
	await _wait_for_room("home_bathroom")
	await _walk_to_entry("memory_02", "native_small_window_task")
	_main.interact_nearest()
	await _capture("home-memory-960", "production_memory_panel_minimum_window")
	await _click_text("洗手后关好水龙头")
	await _capture("home-task-960", "production_household_task_minimum_window")
	_main._on_action("close")
	await _finish()

func _overview(rid: String) -> void:
	var old: Transform3D = _main.camera.transform
	var old_size: float = _main.camera.size
	_main.capturing_photo = true
	_main.ui.hide()
	var bounds: Rect2 = _main.metadata.bounds
	var center := Vector3(bounds.get_center().x, 0.5, bounds.get_center().y)
	_main.camera.position = center + Vector3(18, 25, 24)
	_main.camera.look_at(center, Vector3.UP)
	_main.camera.size = 44.0 if rid == "home_estate" else 25.0
	await _capture(rid + "-overview", "native_review_camera_whole_room_hud_hidden")
	_main.camera.transform = old
	_main.camera.size = old_size
	_main.ui.show()
	_main.capturing_photo = false

func _task_captures(rid: String) -> void:
	var plan: Dictionary = House.room(rid)
	await _walk_to_entry("memory_%02d" % int(plan.task.anchor), "native_bed_activity")
	_main.interact_nearest()
	await _click_text(str(plan.task.title))
	await _capture("home-bedroom-task", "production_household_task_panel")
	await _prop_capture("bed-before")
	await _click_text(str(plan.task.steps[0]))
	await _prop_capture("bed-middle")
	await _click_text(str(plan.task.steps[1]))
	await _click_text(str(plan.task.steps[2]))
	await _prop_capture("bed-after")
	_main._on_action("close")

func _prop_capture(id: String) -> void:
	var old: Transform3D = _main.camera.transform
	var old_size: float = _main.camera.size
	_main.capturing_photo = true
	_main.ui.hide()
	var center: Vector3 = _entry("memory_01").position + Vector3(0, 0.4, -1)
	_main.camera.position = center + Vector3(12, 18, 17)
	_main.camera.look_at(center, Vector3.UP)
	_main.camera.size = 9.5
	await _capture(id, "native_review_camera_task_props_hud_hidden")
	_main.camera.transform = old
	_main.camera.size = old_size
	_main.ui.show()
	_main.capturing_photo = false

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _capture(id: String, kind: String) -> void:
	await _frames(5)
	if _main.ui.visible and _main.ui.modal.visible:
		_check("panel_in_viewport/" + id, root.get_visible_rect().encloses(_main.ui.panel.get_global_rect()))
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join(id + ".png"))
	_check("capture_saved/" + id, error == OK)
	captures.append({"id":id, "kind":kind, "room":_main.room, "window":[root.size.x,root.size.y], "image":[picture.get_width(),picture.get_height()], "panel":_main.ui.current_panel})
	print("HOME_CAPTURE " + id)

func _finish() -> void:
	_check("production_save_unchanged", _production_signature() == _protected_before)
	_report["passed"] = _report.failures.is_empty()
	_report["captures"] = captures
	_report["renderer"] = RenderingServer.get_current_rendering_method()
	_report["production_save_unchanged"] = _production_signature() == _protected_before
	_report["scope"] = "Native rendered captures and limited UI clicks/walks; full navigation evidence is in home-hierarchy-report.json. Whole-room and prop views use explicit review cameras. Gameplay and panels use the production camera."
	var file := FileAccess.open(capture_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := "user://validation-%d.json%s" % [OS.get_process_id(), suffix]
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HOME_NATIVE_CAPTURE " + JSON.stringify({"passed":_report.passed,"captures":captures.size(),"failures":_report.failures}))
	quit(0 if _report.passed else 1)
