extends "res://tests/test_home_indoor.gd"
## Native evidence reached through real walks and E; only overview moves the camera.

var capture_dir := ProjectSettings.globalize_path(INDOOR_REPORT_DIR).path_join("native")
var captures: Array[Dictionary] = []

func _run() -> void:
	root.size = Vector2i(1440, 900)
	_report_name = "native/report.json"
	_report["coverage"] = "Native physical courtyard entrance, hall exploration, three distinct indoor doors, bedroom return, 960px hall/map, and courtyard return. No room selection menu."
	_report["map_pages"] = []
	_protected_before = _production_signature()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	create_timer(360).timeout.connect(func(): _check("capture_timeout", false); _finish())
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready", false)
		await _finish()
		return
	_check("native_renderer", DisplayServer.get_name() != "headless")
	_check("isolated_capture_save", str(root.get_node("State").save_path) == "user://validation-%s.json" % OS.get_process_id())
	_main.muted = true
	_main.voice.stop()
	_main.ui.reduced_motion = true
	_main.application_backgrounded = false
	root.get_node("State").set_preference("fixed_day", true)
	if not await _walk_to_entry("home_gate", "native_enter_residence") or not await _transition("home_gate", "home_estate"):
		await _finish()
		return
	_main.living.set_day_phase("day", true)
	_main.living.set_weather("clear", true)
	_main.show_map()
	await _layout()
	if not await _choose_and_follow("house_entry"):
		await _finish()
		return
	await _capture("01-yard-front-door", "production_camera_after_actual_courtyard_walk")
	if not await _transition("house_entry", "home_hall"):
		await _finish()
		return
	await _check_hall_contract("native_initial_entry")
	await _capture("02-hall-entry-play", "production_camera_after_E_entered_indoor_hall")
	await _overview()
	_main.show_map()
	await _capture("04-hall-map-1440", "production_navigation_map_seven_physical_room_doors")
	if await _choose_and_follow("home_gate"):
		await _capture("05-hall-living-door", "production_camera_after_actual_walk_to_living_room_door")
	_main.show_map()
	await _layout()
	if await _choose_and_follow("home_bedroom_gate"):
		await _capture("06-hall-bedroom-door", "production_camera_after_actual_walk_to_bedroom_door")
		if await _transition("home_bedroom_gate", "home_bedroom"):
			await _capture("07-bedroom-entered", "production_camera_after_E_at_bedroom_door")
			if await _walk_to_entry("home_exit", "native_return_from_bedroom"):
				if await _transition("home_exit", "home_hall"):
					await _capture("08-hall-return-from-bedroom", "production_camera_beside_corresponding_bedroom_door_after_return")
	if _main.room != "home_hall":
		_check("native_room_route_returns_to_hall", false)
		await _finish()
		return
	_main.show_map()
	await _layout()
	if await _choose_and_follow("home_kitchen_gate"):
		await _capture("09-hall-kitchen-door", "production_camera_after_actual_walk_to_kitchen_door")
	root.size = Vector2i(960, 640)
	await _frames(8)
	await _capture("10-hall-play-960", "production_hall_gameplay_at_minimum_window")
	_main.show_map()
	await _capture("11-hall-map-960", "production_hall_navigation_at_minimum_window")
	if await _choose_and_follow("courtyard_exit"):
		await _capture("12-hall-courtyard-door-960", "production_camera_after_small_window_map_walk_to_courtyard_exit")
		if await _transition("courtyard_exit", "home_estate"):
			await _capture("13-yard-return-960", "production_camera_at_front_door_after_indoor_exit")
	await _finish()

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _layout() -> void:
	# Native nested containers need a drawn frame before screen-position input.
	# Headless checks use their own short layout wait; this changes no production UI.
	await _frames(6)
	await RenderingServer.frame_post_draw

func _overview() -> void:
	var old: Transform3D = _main.camera.transform
	var old_size: float = _main.camera.size
	_main.capturing_photo = true
	_main.ui.hide()
	var bounds: Rect2 = _main.metadata.bounds
	var center := Vector3(bounds.get_center().x, 0.5, bounds.get_center().y)
	_main.camera.position = center + Vector3(18, 25, 24)
	_main.camera.look_at(center, Vector3.UP)
	_main.camera.size = 34.0
	await _capture("03-hall-overview", "native_review_camera_entire_hall_hud_hidden")
	_main.camera.transform = old
	_main.camera.size = old_size
	_main.ui.show()
	_main.capturing_photo = false

func _capture(id: String, kind: String) -> void:
	await _frames(6)
	_check("capture_has_no_room_selection_menu/" + id, _main.ui.current_panel != "home_entry")
	if _main.ui.visible and _main.ui.modal.visible:
		_check("panel_in_viewport/" + id, root.get_visible_rect().encloses(_main.ui.panel.get_global_rect()))
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join(id + ".png"))
	_check("capture_saved/" + id, error == OK)
	captures.append({"id":id, "kind":kind, "room":_main.room, "window":[root.size.x,root.size.y], "image":[picture.get_width(),picture.get_height()], "panel":_main.ui.current_panel, "player_position":_vector(_main.player.position)})
	print("HOME_INDOOR_CAPTURE " + id)

func _finish() -> void:
	_report["captures"] = captures
	_report["renderer"] = RenderingServer.get_current_rendering_method()
	_report["native_capture_scope"] = "Production cameras and UI after real walking and physical E input; 03-hall-overview alone uses explicit review camera. Forty-point/eight-task checks are in the separate headless indoor report."
	await super._finish()
