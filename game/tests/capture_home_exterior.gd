extends "res://tests/capture_home_hierarchy.gd"
## Native exterior v2 evidence; old v1 captures remain unchanged.

func _run() -> void:
	root.size = Vector2i(1440, 900)
	capture_dir = ProjectSettings.globalize_path("res://../docs/verification/home-exterior-v2/native")
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
	if not await _walk_to_entry("home_gate", "native_enter_residence") or not await _transition("home_gate", "home_estate"):
		await _finish()
		return
	_main.living.set_day_phase("day", true)
	_main.living.set_weather("clear", true)
	await _frames(8)
	await _capture("home_estate-play", "production_gameplay_camera_at_courtyard_gate")
	await _measure_native_performance()
	await _overview("home_estate")
	_main.show_map()
	await _capture("home-estate-map-1440", "production_exterior_map_single_front_door")
	if not await _choose_and_follow("house_entry"):
		await _finish()
		return
	await _capture("home-estate-front-door", "production_gameplay_camera_after_actual_front_door_walk")
	_main.interact_nearest()
	_check("front_door_opens_entry", _main.ui.current_panel == "home_entry")
	await _capture("home-entry-1440", "production_seven_room_entry_panel")
	root.size = Vector2i(960, 640)
	await _frames(8)
	await _capture("home-entry-960", "production_seven_room_entry_panel_minimum_window")
	var plan: Dictionary = House.room("home_balcony")
	if await _click_text(str(plan.name) + "\n" + str(plan.task.title)):
		_check("small_window_room_choice", await _wait_for_room("home_balcony"))
		await _capture("home-balcony-from-entry-960", "production_room_after_small_window_button")
		if await _walk_to_entry("home_exit", "native_return_front_door"):
			_main.interact_nearest()
			_check("return_from_room", await _wait_for_room("home_estate"))
			_check("return_to_front_door", _distance_xz(_main.player.position, _entry("house_entry").get("position", Vector3(INF, INF, INF))) < 1.5)
			await _capture("home-estate-return-960", "production_gameplay_camera_after_room_return")
	await _finish()

func _measure_native_performance() -> void:
	# Run this renderer script without --fixed-fps. This is a short local sample,
	# not target-hardware performance certification or a headless timing result.
	await _frames(30)
	var samples: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	var previous := started
	for frame: int in range(120):
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append({"frame_ms":float(now - previous) / 1000.0, "engine_fps":Engine.get_frames_per_second(), "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)})
		previous = now
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	_report["native_performance_sample"] = {"room":_main.room, "camera":"production_gameplay_at_courtyard_gate", "viewport":[root.size.x,root.size.y], "renderer":RenderingServer.get_current_rendering_method(), "video_adapter":RenderingServer.get_video_adapter_name(), "display":DisplayServer.get_name(), "vsync_mode":DisplayServer.window_get_vsync_mode(), "process_fixed_fps_argument":OS.get_cmdline_args().has("--fixed-fps"), "elapsed_seconds":elapsed, "measured_average_fps":120.0 / maxf(elapsed, 0.001), "samples":samples, "scope":"Short local native-renderer sample; includes this machine and window settings. Not target-device certification."}

func _click_text(text: String) -> bool:
	# Control rectangles are in the scaled viewport's local coordinates. Sending
	# these as OS-window coordinates would miss when the minimum window is scaled.
	var button: Button = null
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			button = node as Button
			break
	var available: bool = button != null and not button.disabled and button.is_visible_in_tree()
	_check("mouse_button_available/" + text, available)
	if not available: return false
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(button)
			break
		ancestor = ancestor.get_parent()
	await _layout()
	var center := button.get_global_rect().get_center()
	var inside := root.get_visible_rect().has_point(center)
	if ancestor is ScrollContainer: inside = inside and (ancestor as ScrollContainer).get_global_rect().has_point(center)
	_check("mouse_button_inside_viewport/" + text, inside)
	if not inside: return false
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = center
		event.global_position = center
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _layout()
	return true

func _finish() -> void:
	_check("production_save_unchanged", _production_signature() == _protected_before)
	_report["passed"] = _report.failures.is_empty()
	_report["captures"] = captures
	_report["renderer"] = RenderingServer.get_current_rendering_method()
	_report["production_save_unchanged"] = _production_signature() == _protected_before
	_report["scope"] = "Native exterior v2 captures after actual village entry and map-button courtyard walk. Seven-room panel uses production UI. Overview alone uses the same explicit size-44 review camera as v1. Full household navigation/activity coverage is in home-exterior-report.json."
	var file := FileAccess.open(capture_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := "user://validation-%d.json%s" % [OS.get_process_id(), suffix]
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HOME_EXTERIOR_NATIVE_CAPTURE " + JSON.stringify({"passed":_report.passed,"captures":captures.size(),"failures":_report.failures}))
	quit(0 if _report.passed else 1)
