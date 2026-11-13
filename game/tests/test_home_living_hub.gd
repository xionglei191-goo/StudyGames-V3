extends "res://tests/test_school_hierarchy.gd"
## Physical entrance, six room round trips, map clicks, collision and legacy routing.
## Requires -- --test-harness; --hub-capture additionally writes native screenshots.

const House = preload("res://scripts/home_catalog.gd")
const OUTPUT := "F:/LoveStudy/docs/verification/home-living-hub-20261113"
var captures := false
var images: Array[Dictionary] = []
var finished := false
var observed_rooms: Array[String] = []

func _process(_delta: float) -> bool:
	if is_instance_valid(_main):
		_main.application_backgrounded = false
		if observed_rooms.is_empty() or observed_rooms[-1] != _main.room:
			observed_rooms.append(_main.room)
	return false

func _run() -> void:
	captures = OS.get_cmdline_user_args().has("--hub-capture")
	root.size = Vector2i(1440, 900)
	_protected_before = _production_signature()
	create_timer(600).timeout.connect(func(): _check("bounded_test_timeout", false); _finish())
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready", false)
		await _finish()
		return
	var state: Node = root.get_node("State")
	_check("isolated_validation_save", str(state.save_path) == "user://validation-%s.json" % OS.get_process_id())
	var learning: Dictionary = state.data.learning.duplicate(true)
	var completed: Dictionary = state.data.completed_units.duplicate(true)
	_main.muted = true
	_main.voice.stop()
	if not await _walk_to_entry("home_gate", "island_entry") or not await _press_travel("home_gate", "home_estate"):
		await _finish()
		return
	_check("front_door_directly_targets_living_room", _entry("house_entry").get("destination") == "home")
	if not await _walk_to_entry("house_entry", "front_door") or not await _press_travel("house_entry", "home"):
		await _finish()
		return
	_check("seven_functional_rooms", House.CHILD_ROOMS.size() == 7 and House.DESTINATION_ROOMS.size() == 6)
	_check("living_room_exits_to_courtyard", _entry("courtyard_exit").get("destination") == "home_estate")
	_check("rectangular_room_bounds", _main.metadata.bounds.size.is_equal_approx(Vector2(20.4,15.6)))
	_check("exactly_six_doors_and_one_front_exit", _main.interactions.filter(func(e: Dictionary): return e.get("type") == "travel").size() == 7)
	_check("living_room_still_has_five_memories", _main.interactions.filter(func(e: Dictionary): return str(e.id).begins_with("memory_")).size() == 5)
	await _capture("entry", "production_camera_after_physical_front_door")
	await _overview()
	for rid: String in House.DESTINATION_ROOMS:
		var id := rid + "_gate"
		_check("door_targets_original_room/"+rid, _entry(id).get("destination") == rid)
		_main.show_map()
		await _layout()
		if rid == "home_study": await _capture("map-1440", "production_map")
		if not await _choose_and_follow(id): break
		await _capture("door-"+rid, "production_camera_at_physical_door")
		if rid == "home_balcony": await _door_collision_probe()
		if not await _press_travel(id, rid): break
		_check("child_returns_to_living_room/"+rid, _main.metadata.parent_room == "home" and _entry("home_exit").get("destination") == "home")
		_check("child_return_matches_own_door/"+rid, _entry("home_exit").get("return_id") == id)
		if not await _walk_to_entry("home_exit", "child_return") or not await _press_travel("home_exit", "home"): break
		var doorway := _entry(id)
		_check("return_lands_by_same_door/"+rid, _distance_xz(_main.player.position, doorway.position) < 1.8)
	if _main.room != "home":
		await _finish()
		return
	for i in range(1,6):
		var id := "memory_%02d" % i
		if not await _walk_to_entry(id, "retained_learning_anchor"): continue
		_main.interact_nearest()
		await _layout()
		_check("retained_memory_opens/"+id, _main.ui.current_panel == "memory" and _main.ui.modal.visible)
		_main._on_action("close")
		await _layout()
	# The existing rest shortcut must walk straight from the living room to the bedroom.
	var room_start := observed_rooms.size()
	_main.household.handle_action("home:bedroom")
	_check("rest_shortcut_starts_a_real_walk", not _main.player.path.is_empty() and _main.room == "home")
	_check("rest_shortcut_arrives_in_bedroom", await _wait_for_room("home_bedroom"))
	_check("rest_shortcut_has_no_hall", not observed_rooms.slice(room_start).has("home_hall"))
	# Cross-room navigation uses the living room as its intermediate physical scene.
	room_start = observed_rooms.size()
	_main._navigate_to_id("home_kitchen_gate", true)
	_check("cross_room_route_arrives", await _wait_long("home_kitchen"))
	_check("cross_room_route_passes_living_room", observed_rooms.slice(room_start).has("home"))
	if _main.room == "home_kitchen":
		if await _walk_to_entry("home_exit", "cross_route_return"): await _press_travel("home_exit", "home")
	# Compatibility is tested explicitly; this direct fixture is not counted as a walked route.
	await _main.change_room("home_hall", "home_gate")
	_check("legacy_hall_reference_resolves_to_home", await _wait_for_room("home"))
	root.size = Vector2i(960,640)
	await _layout()
	_main.show_map()
	await _layout()
	_check("small_map_fits_viewport", root.get_visible_rect().encloses(_main.ui.panel.get_global_rect()))
	await _capture("map-960", "production_map_minimum_window")
	if await _choose_and_follow("home_bedroom_gate"):
		await _capture("bedroom-door-960", "production_camera_minimum_window")
		if await _press_travel("home_bedroom_gate", "home_bedroom"):
			if await _walk_to_entry("home_exit", "small_window_return"): await _press_travel("home_exit", "home")
	root.size = Vector2i(1440,900)
	if await _walk_to_entry("courtyard_exit", "leave_living_room"):
		if await _press_travel("courtyard_exit", "home_estate"):
			if await _walk_to_entry("village_exit", "leave_home"): await _press_travel("village_exit", "village")
	_check("journey_returns_to_island", _main.room == "village")
	_check("no_hall_scene_entered", not observed_rooms.has("home_hall"))
	_check("learning_scores_unchanged", state.data.learning == learning and state.data.completed_units == completed)
	await _finish()

func _press_travel(id: String, destination: String) -> bool:
	var origin: String = _main.room
	var original := _entry(id)
	var selected := str(_main.nearest.get("id", "")) == id
	_check("door_is_nearest/"+origin+"/"+id, selected)
	if not selected: return false
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	release.keycode = KEY_E
	Input.parse_input_event(release)
	var arrived := await _wait_for_room(destination)
	_check("physical_E_transition/"+origin+"->"+destination, arrived)
	_report.transitions.append({"from":origin,"to":destination,"interaction":id,"input":"Input.parse_input_event E","passed":arrived})
	if arrived and not str(original.get("return_id", "")).is_empty():
		var target := _entry(str(original.return_id))
		_check("physical_return_anchor/"+origin, not target.is_empty() and _distance_xz(_main.player.position,target.get("return_position",target.position)) < 2.0)
	return arrived

func _door_collision_probe() -> void:
	_main._cancel_navigation()
	await _walk_to_point("closed_door_center", _entry("home_balcony_gate").position, .45)
	var start: Vector3 = _main.player.position
	var hits := 0
	for frame in range(55):
		_main.player.touch_axis = _world_direction_to_touch_axis(Vector3.RIGHT)
		await physics_frame
		await process_frame
		for index in _main.player.get_slide_collision_count():
			var body := _main.player.get_slide_collision(index).get_collider() as Node
			if body and "ClosedLeaf" in str(body.get_path()): hits += 1
	_main.player.touch_axis = Vector2.ZERO
	var end: Vector3 = _main.player.position
	var ok := hits > 5 and end.x < 10.0 and end.x > start.x+.25
	_check("closed_door_has_real_collision", ok)
	_report.collisions.append({"door":"home_balcony","contacts":hits,"start":_vector(start),"finish":_vector(end),"passed":ok})
	await _walk_to_entry("home_balcony_gate", "after_collision_probe")

func _wait_long(room_id: String) -> bool:
	var stable := 0
	for i in range(2400):
		await physics_frame
		await process_frame
		var ready: bool = _main.room == room_id and _main.nav_ready and not _main.loading_room and _main.ui.fade.color.a < .01
		stable = stable + 1 if ready else 0
		if stable >= 3: return true
	return false

func _wait_for_room(room_id: String) -> bool:
	return await _wait_long(room_id)

func _click_text(text: String) -> bool:
	# Control rectangles use viewport coordinates, including after a window resize.
	var button: Button = null
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			button = node as Button
			break
	var available := button != null and not button.disabled and button.is_visible_in_tree()
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
	for pressed: bool in [true,false]:
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

func _layout() -> void:
	for i in range(6):
		await physics_frame
		await process_frame
	if captures: await RenderingServer.frame_post_draw

func _overview() -> void:
	if not captures: return
	var old_transform: Transform3D = _main.camera.transform
	var old_size: float = _main.camera.size
	_main.capturing_photo = true
	_main.ui.hide()
	var center := Vector3(0,.5,.7)
	_main.camera.position = center + Vector3(9,25,26)
	_main.camera.look_at(center,Vector3.UP)
	_main.camera.size = 24.0
	await _capture("overview", "review_camera_hud_hidden")
	_main.camera.transform = old_transform
	_main.camera.size = old_size
	_main.ui.show()
	_main.capturing_photo = false

func _capture(id: String, kind: String) -> void:
	if not captures: return
	await _layout()
	var error := root.get_texture().get_image().save_png(OUTPUT.path_join(id+".png"))
	_check("capture/"+id,error == OK)
	images.append({"image":id+".png","kind":kind,"room":_main.room,"window":[root.size.x,root.size.y],"position":_vector(_main.player.position)})

func _finish() -> void:
	if finished: return
	finished = true
	_check("production_save_unchanged", _production_signature() == _protected_before)
	_report["passed"] = _report.failures.is_empty()
	_report["complete"] = true
	_report["engine"] = Engine.get_version_info()["string"]
	_report["renderer"] = RenderingServer.get_current_rendering_method()
	_report["actual_map_mouse_input"] = true
	_report["actual_door_key_input"] = true
	_report["observed_rooms"] = observed_rooms
	_report["captures"] = images
	var file := FileAccess.open(OUTPUT.path_join("native-report.json" if captures else "runtime-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(_report,"  "))
	file.close()
	if is_instance_valid(_main): _main.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := "user://validation-%s.json%s" % [OS.get_process_id(),suffix]
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LIVING_HUB_RESULT ",JSON.stringify({"passed":_report.passed,"checks":_report.checks.size(),"routes":_report.routes.size(),"transitions":_report.transitions.size(),"failures":_report.failures}))
	quit(0 if _report.passed else 1)
