extends "res://tests/test_movement.gd"
## Walk village -> full campus -> seven third-level rooms -> campus -> village.
## Campus navigation is selected by actual mouse input, without replacing its path.
## Godot --headless --fixed-fps 60 --path game --script res://tests/test_school_hierarchy.gd -- --test-harness


func _run() -> void:
	root.size = Vector2i(1440, 900)
	_report_name = "school-hierarchy-report.json"
	_report["coverage"] = "Actual village entry, all %d campus map navigation buttons, five-point page and return, all %d third-level doors, %d memory points, nearest interactions, and each return to its corresponding parent door." % [SCHOOL_ROOMS.size() + 2, SCHOOL_ROOMS.size(), (SCHOOL_ROOMS.size() + 1) * 5]
	_report["expected_school_children"] = SCHOOL_ROOMS.size()
	_report["expected_campus_navigation_buttons"] = SCHOOL_ROOMS.size() + 2
	_report["expected_memory_points"] = (SCHOOL_ROOMS.size() + 1) * 5
	_report["actual_mouse_dispatch"] = true
	_report["map_pages"] = []
	_protected_before = _production_signature()
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	var ready_ok: bool = await _wait_for_room("village")
	_check("initial_scene_ready", ready_ok)
	if not ready_ok:
		await _finish()
		return
	_main.muted = true
	_main.voice.stop()
	var state: Node = root.get_node("State")
	_check("isolated_validation_save", str(state.save_path) == "user://validation-%s.json" % OS.get_process_id())
	var learning_before: Variant = state.data.get("learning", {}).duplicate(true)
	var completed_before: Variant = state.data.get("completed_units", {}).duplicate(true)
	if not await _walk_to_entry("school_gate", "village_to_campus") or not await _transition("school_gate", "school"):
		await _finish()
		return
	_check("campus_is_second_level", int(_main.metadata.get("scene_level", -1)) == 2 and str(_main.metadata.get("parent_room", "")) == "village")
	var school_plan: Dictionary = _main.world.room_plan("school")
	var areas: Array = school_plan.get("areas", [])
	_check("plan_contains_expected_third_level_rooms", areas.size() == SCHOOL_ROOMS.size())
	for child_room: String in SCHOOL_ROOMS:
		var area_matches: Array = areas.filter(func(area: Dictionary) -> bool: return str(area.get("room_id", "")) == child_room)
		_check("plan_child_present/" + child_room, area_matches.size() == 1)
		if area_matches.size() == 1:
			var area: Dictionary = area_matches[0]
			_check("plan_child_hierarchy/" + child_room, bool(area.get("separate_scene", false)) and int(area.get("scene_level", -1)) == 3 and str(area.get("parent_room", "")) == "school")
		var door: Dictionary = _entry(child_room + "_gate")
		_check("campus_door_binding/" + child_room, str(door.get("destination", "")) == child_room and str(door.get("marker", "")) == "SG_DOOR_" + child_room.to_upper())
	await _check_campus_pages()
	for sequence: int in range(1, 6):
		var id: String = "memory_%02d" % sequence
		_main.show_map()
		await _layout()
		if await _click_text("校园里的五个探索位置"):
			_check("campus_memory_page/" + id, _main.ui.current_panel == "campus_memories")
			if await _choose_and_follow(id):
				await _open_memory(id)
	for child_room: String in SCHOOL_ROOMS:
		if _main.room != "school":
			_check("campus_parent_before_child/" + child_room, false)
			break
		var door_id: String = child_room + "_gate"
		_main.show_map()
		await _layout()
		if not await _choose_and_follow(door_id):
			continue
		if not await _transition(door_id, child_room):
			continue
		_check("third_level_metadata/" + child_room, int(_main.metadata.get("scene_level", -1)) == 3 and str(_main.metadata.get("parent_room", "")) == "school")
		var exit_entry: Dictionary = _entry("school_exit")
		_check("child_exit_binding/" + child_room, str(exit_entry.get("destination", "")) == "school" and str(exit_entry.get("return_id", "")) == door_id)
		for sequence: int in range(1, 6):
			var id: String = "memory_%02d" % sequence
			if await _walk_to_entry(id, "third_level_memory"):
				await _open_memory(id)
		if await _walk_to_entry("school_exit", "return_to_campus"):
			await _transition("school_exit", "school")
	if _main.room == "school":
		_main.show_map()
		await _layout()
		if await _choose_and_follow("village_exit"):
			await _transition("village_exit", "village")
	_check("hierarchy_journey_returns_to_village", _main.room == "village")
	_check("free_exploration_does_not_change_learning", state.data.get("learning", {}) == learning_before)
	_check("free_exploration_does_not_complete_units", state.data.get("completed_units", {}) == completed_before)
	await _finish()


func _check_campus_pages() -> void:
	_main.show_map()
	await _layout()
	var labels: Array[String] = _navigation_labels()
	var expected: Array[String] = []
	for child_room: String in SCHOOL_ROOMS:
		expected.append(str(_entry(child_room + "_gate").get("label", "missing")))
	expected.append(str(_entry("village_exit").get("label", "missing")))
	expected.append("校园里的五个探索位置")
	var same: bool = labels.size() == expected.size()
	for label: String in expected:
		same = same and labels.count(label) == 1
	_check("campus_map_has_exact_navigation_buttons", same)
	_report.map_pages.append({"panel": "map", "navigation_button_count": labels.size(), "labels": labels, "passed": same})
	if await _click_text("校园里的五个探索位置"):
		_check("campus_map_opens_five_point_page", _main.ui.current_panel == "campus_memories")
		labels = _navigation_labels()
		same = labels.size() == 6 and labels.count("返回校园导览") == 1
		for sequence: int in range(1, 6):
			same = same and labels.count(str(_entry("memory_%02d" % sequence).get("label", "missing"))) == 1
		_check("campus_five_point_page_has_five_destinations_and_return", same)
		_report.map_pages.append({"panel": "campus_memories", "navigation_button_count": labels.size(), "labels": labels, "passed": same})
		if await _click_text("返回校园导览"):
			_check("five_point_page_returns_to_campus_map", _main.ui.current_panel == "map" and _navigation_labels().size() == expected.size())
	_main._on_action("close")
	await _layout()


func _open_memory(id: String) -> void:
	var selected: bool = str(_main.nearest.get("id", "")) == id
	_check("memory_selected/" + str(_main.room) + "/" + id, selected)
	if not selected:
		return
	_main.interact_nearest()
	await _layout()
	_check("memory_panel_from_nearest/" + str(_main.room) + "/" + id, _main.ui.modal.visible and _main.ui.current_panel == "memory")
	_main._on_action("close")
	await _layout()


func _choose_and_follow(id: String) -> bool:
	var entry: Dictionary = _entry(id)
	_check("map_destination_exists/" + id, not entry.is_empty())
	if entry.is_empty():
		return false
	var origin: String = _main.room
	var start: Vector3 = _main.player.position
	if not await _click_text(str(entry.label)):
		return false
	var accepted: bool = not _main.ui.modal.visible and _main.room == origin and (not _main.player.path.is_empty() or _distance_xz(_main.player.position, entry.position) < float(entry.radius))
	_check("map_button_started_walk/" + id, accepted)
	var frames: int = 0
	var moved: float = _distance_xz(start, _main.player.position)
	var previous: Vector3 = _main.player.position
	var contacts: Dictionary = {}
	while accepted and not _main.player.path.is_empty() and frames < MAX_WALK_FRAMES:
		await physics_frame
		await process_frame
		frames += 1
		moved += _distance_xz(previous, _main.player.position)
		previous = _main.player.position
		for index: int in range(_main.player.get_slide_collision_count()):
			var hit: KinematicCollision3D = _main.player.get_slide_collision(index)
			var collider: Object = hit.get_collider()
			var key: String = str((collider as Node).get_path()) if collider is Node else str(collider)
			contacts[key] = {"frame": frames, "normal": _vector(hit.get_normal()), "position": _vector(hit.get_position())}
	await _layout()
	var remaining: float = _distance_xz(_main.player.position, entry.position)
	var selected: bool = str(_main.nearest.get("id", "")) == id
	var passed: bool = accepted and _main.room == origin and remaining < float(entry.radius) and frames < MAX_WALK_FRAMES and selected
	var route: Dictionary = {"room": origin, "target_interaction": id, "navigation_source": "actual_map_button", "start": _vector(start), "finish": _vector(_main.player.position), "destination": _vector(entry.position), "physics_frames": frames, "distance_walked": moved, "remaining_distance": remaining, "allowed_distance": entry.radius, "nearest_interaction": _main.nearest.get("id", ""), "passed": passed}
	if not passed:
		route["last_contacts_by_collider"] = contacts
	_report.routes.append(route)
	_check("actual_map_walk/" + origin + "/" + id, passed)
	print("CAMPUS MAP WALK %s: %s (%.3f remaining, %d frames)" % [id, "PASS" if passed else "FAIL", remaining, frames])
	return passed


func _navigation_labels() -> Array[String]:
	var labels: Array[String] = []
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.has_meta("action_id") and str(button.get_meta("action_id")) != "close":
			labels.append(button.text)
	return labels


func _click_text(text: String) -> bool:
	var button: Button = null
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			button = node as Button
			break
	var available: bool = button != null and not button.disabled and button.is_visible_in_tree()
	_check("mouse_button_available/" + text, available)
	if not available:
		return false
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(button)
			break
		ancestor = ancestor.get_parent()
	await _layout()
	var center: Vector2 = button.get_global_rect().get_center()
	var inside: bool = root.get_visible_rect().has_point(center)
	if ancestor is ScrollContainer:
		inside = inside and (ancestor as ScrollContainer).get_global_rect().has_point(center)
	_check("mouse_button_inside_viewport/" + text, inside)
	if not inside:
		return false
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = center
	press.global_position = center
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	Input.parse_input_event(release)
	await _layout()
	return true


func _layout() -> void:
	await process_frame
	await process_frame
