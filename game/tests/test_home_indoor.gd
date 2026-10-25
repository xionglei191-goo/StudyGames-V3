extends "res://tests/test_home_exterior.gd"
## Real indoor circulation: courtyard -> entrance hall -> physical room doors.
## Reuses the forty household-point/eight-task checks without giving the hall tasks.

const INDOOR_REPORT_DIR := "res://../docs/verification/home-indoor-v3"
const CHILD_ROOMS: Array[String] = ["home", "home_bedroom", "home_kitchen", "home_dining", "home_bathroom", "home_study", "home_balcony"]
var _forbidden_menu_frames := 0
var _indoor_finished := false

func _run() -> void:
	root.size = Vector2i(1440, 900)
	_report_name = "home-indoor-report.json"
	_report["coverage"] = "Physical village gate, courtyard front door, walkable hall, seven physical room doors, forty existing memory points and eight household tasks, corresponding indoor return doors, courtyard and island exits."
	_report["actual_mouse_dispatch"] = true
	_report["actual_door_key_dispatch"] = true
	_report["map_pages"] = []
	_protected_before = _production_signature()
	create_timer(600).timeout.connect(func(): _check("indoor_timeout", false); _finish())
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready", false)
		await _finish()
		return
	var state: Node = root.get_node("State")
	_check("save_isolation", str(state.save_path) == "user://validation-%s.json" % OS.get_process_id())
	_main.muted = true
	_main.voice.stop()
	var learning_before: Dictionary = state.data.learning.duplicate(true)
	var units_before: Dictionary = state.data.completed_units.duplicate(true)
	var coins_before: int = state.data.coins
	if not await _walk_to_entry("home_gate", "enter_residence") or not await _transition("home_gate", "home_estate"):
		await _finish()
		return
	_check("residence_level_two", int(_main.metadata.scene_level) == 2 and _main.metadata.parent_room == "village")
	_check("front_door_is_physical_hall_transition", _entry("house_entry").get("destination") == "home_hall")
	_check("courtyard_has_seven_existing_interactions", _main.interactions.size() == 7)
	for rid: String in CHILD_ROOMS:
		_check("no_outdoor_room_door/" + rid, _entry(rid + "_gate").is_empty())
	await _test_house_room("home_estate")
	_main.show_map()
	await _layout()
	_check("courtyard_map_has_front_door_exit_and_existing_pages", _navigation_labels().size() == 4)
	if not await _choose_and_follow("house_entry") or not await _transition("house_entry", "home_hall"):
		await _finish()
		return
	await _check_hall_contract("initial_entry")
	await _check_hall_map()
	for rid: String in CHILD_ROOMS:
		if _main.room != "home_hall":
			_check("hall_before_room/" + rid, false)
			break
		var door_id := rid + "_gate"
		_main.show_map()
		await _layout()
		if not await _choose_and_follow(door_id): continue
		_check("room_map_only_walks_to_door/" + rid, _main.room == "home_hall" and not _main.ui.modal.visible)
		if not await _transition(door_id, rid): continue
		_check("child_scene_hierarchy/" + rid, int(_main.metadata.scene_level) == 3 and _main.metadata.parent_room == "home_hall")
		_check("child_exit_to_own_hall_door/" + rid, _entry("home_exit").get("destination") == "home_hall" and _entry("home_exit").get("return_id") == door_id)
		await _test_house_room(rid)
		if rid == "home":
			if not await _check_living_to_bedroom_shortcut(): break
			if await _walk_to_entry("home_exit", "return_after_bedroom_shortcut"):
				await _transition("home_exit", "home_hall")
			continue
		if rid == "home_bedroom":
			await _check_bedroom_local_actions()
		if await _walk_to_entry("home_exit", "leave_room"):
			if await _transition("home_exit", "home_hall"):
				await _check_hall_contract("return_" + rid)
	if _main.room == "home_hall":
		_main.show_map()
		await _layout()
		if await _choose_and_follow("courtyard_exit"):
			await _transition("courtyard_exit", "home_estate")
	if _main.room == "home_estate" and await _walk_to_entry("village_exit", "leave_residence"):
		await _transition("village_exit", "village")
	_check("complete_journey_returns_to_island", _main.room == "village")
	_check("all_eight_household_tasks_persisted", state.data.life.home_tasks.size() == 8)
	_check("all_forty_household_points_discovered", state.data.life.discoveries.size() == 40)
	_check("no_language_grade_from_housework", state.data.learning == learning_before and state.data.completed_units == units_before)
	_check("no_extra_economy_rewards", int(state.data.coins) == coins_before)
	var experiences: Dictionary = state.data.life.home_tasks.duplicate(true)
	state.load_state()
	_check("tasks_survive_reload", state.data.life.home_tasks == experiences)
	await _finish()

func _check_living_to_bedroom_shortcut() -> bool:
	if not await _walk_to_entry("memory_04", "living_room_rest_shortcut"): return false
	_main.interact_nearest()
	await _layout()
	var observed_rooms: Array[String] = ["home"]
	var moved: Dictionary = {"home":0.0, "home_hall":0.0}
	var previous: Vector3 = _main.player.position
	var previous_room: String = _main.room
	if not await _click_text("去卧室休息"): return false
	_check("bedroom_shortcut_starts_walking_in_living_room", _main.room == "home" and not _main.player.path.is_empty() and not _main.ui.modal.visible)
	var frames := 0
	var stable := 0
	while frames < MAX_WALK_FRAMES and stable < 3:
		await physics_frame
		await process_frame
		frames += 1
		if _main.ui.current_panel == "home_entry": _forbidden_menu_frames += 1
		var live_room: String = _main.room
		if _main.scene_ready and not _main.loading_room and _main.nav_ready:
			if live_room == previous_room:
				moved[live_room] = float(moved.get(live_room, 0.0)) + _distance_xz(previous, _main.player.position)
			if observed_rooms[-1] != live_room:
				var old_room: String = observed_rooms[-1]
				observed_rooms.append(live_room)
				var item: Dictionary = {"from":old_room, "to":live_room, "input":"actual_rest_button_continued_physical_walk", "passed":true}
				if live_room == "home_hall":
					var own_door := _entry("home_gate")
					var distance := _distance_xz(_main.player.position, own_door.get("position", Vector3(INF, INF, INF)))
					item["return_door"] = "home_gate"
					item["return_distance"] = distance
					_check("rest_shortcut_exits_beside_living_room_door", not own_door.is_empty() and distance <= 1.8)
				_report.transitions.append(item)
			stable = stable + 1 if live_room == "home_bedroom" else 0
		previous = _main.player.position
		previous_room = live_room
	var result := observed_rooms == ["home", "home_hall", "home_bedroom"] and stable >= 3
	_check("rest_shortcut_visits_actual_hall_before_bedroom", result)
	_check("rest_shortcut_walks_inside_both_scenes", float(moved.get("home", 0.0)) > 0.5 and float(moved.get("home_hall", 0.0)) > 0.5)
	_report.routes.append({"label":"actual_living_room_rest_shortcut", "navigation_source":"actual_memory_panel_button", "rooms":observed_rooms, "distance_walked_by_room":moved, "physics_frames":frames, "passed":result})
	return result

func _check_bedroom_local_actions() -> void:
	if await _walk_to_entry("memory_03", "bedroom_wardrobe"):
		_main.interact_nearest()
		await _layout()
		await _click_text("挑选今天的穿搭")
		_check("wardrobe_opens_inside_bedroom", _main.room == "home_bedroom" and _main.ui.modal.visible and _main.ui.current_panel != "home_entry")
		_main._on_action("close")
		await _layout()
	if await _walk_to_entry("memory_05", "bedroom_rest"):
		_main.interact_nearest()
		await _layout()
		var day_before := int(root.get_node("State").data.day)
		await _click_text("睡到明天")
		_check("sleep_stays_in_bedroom", _main.room == "home_bedroom" and not _main.ui.modal.visible)
		_check("sleep_advances_one_day", int(root.get_node("State").data.day) == day_before + 1)

func _wait_for_room(expected: String) -> bool:
	var stable := 0
	for frame: int in range(600):
		await physics_frame
		await process_frame
		if is_instance_valid(_main.ui) and _main.ui.current_panel == "home_entry":
			_forbidden_menu_frames += 1
		if _main.scene_ready and not _main.loading_room and _main.nav_ready and _main.room == expected:
			stable += 1
			if stable >= 3: return true
		else:
			stable = 0
	return false

func _transition(id: String, destination_room: String) -> bool:
	var origin: String = _main.room
	var original_entry: Dictionary = _entry(id)
	var selected := str(_main.nearest.get("id", "")) == id
	_check("transition_selected_" + origin + "/" + id, selected)
	if not selected: return false
	_check("no_room_menu_before_transition/" + origin + "/" + id, _main.ui.current_panel != "home_entry" and not _main.ui.modal.visible)
	await _press_front_door()
	var result := await _wait_for_room(destination_room)
	var item: Dictionary = {"from":origin, "interaction":id, "input":"physical_E_key", "to":destination_room, "passed":result}
	if result:
		_check("no_room_menu_after_transition/" + origin + "/" + id, _main.ui.current_panel != "home_entry" and not _main.ui.modal.visible)
		if destination_room != "village":
			_check("transition_blender_source/" + destination_room, str(_main.metadata.get("source", "")) == "blender")
		if id in ["home_exit", "courtyard_exit", "village_exit"]:
			var return_id := str(original_entry.get("return_id", "home_gate" if origin == "home_estate" else ""))
			var target: Dictionary = _entry(return_id)
			var distance := _distance_xz(_main.player.position, target.get("return_position", target.get("position", Vector3(INF, INF, INF))))
			item["return_door"] = return_id
			item["return_distance"] = distance
			_check("return_at_corresponding_door/" + origin, not target.is_empty() and distance <= 1.6)
	_report.transitions.append(item)
	_check("transition_" + origin + "/" + id + "->" + destination_room, result)
	return result

func _check_hall_contract(context: String) -> void:
	await _layout()
	_check("hall_is_real_second_level_scene/" + context, _main.room == "home_hall" and int(_main.metadata.get("scene_level", -1)) == 2 and _main.metadata.get("parent_room") == "home_estate")
	_check("hall_has_no_room_menu/" + context, not _main.ui.modal.visible and _main.ui.current_panel != "home_entry")
	_check("hall_has_eight_physical_destinations/" + context, _main.interactions.size() == 8)
	_check("hall_not_added_as_household_task_room/" + context, "home_hall" not in House.ROOMS and _main.world.find_children("HOME_TASK_*", "Node3D", true, false).is_empty())
	var bounds: Rect2 = _main.metadata.bounds
	var position: Vector3 = _main.player.position
	_check("player_inside_hall_floor_bounds/" + context, bounds.has_point(Vector2(position.x, position.z)))
	_check("player_on_indoor_floor/" + context, _main.player.is_on_floor() and absf(position.y) < 0.5)
	var positions: Array[Vector3] = []
	for rid: String in CHILD_ROOMS:
		var door: Dictionary = _entry(rid + "_gate")
		_check("hall_room_door_binding/" + context + "/" + rid, door.get("destination") == rid and door.get("marker") == "SG_DOOR_" + rid.to_upper())
		var door_position: Vector3 = door.get("position", Vector3(INF, INF, INF))
		for previous: Vector3 in positions:
			_check("hall_doors_spatially_separate/" + context + "/" + rid + "/" + str(positions.find(previous)), _distance_xz(previous, door_position) >= 3.0)
		positions.append(door_position)
	for entry: Dictionary in _main.interactions:
		_check("hall_navigation_only/" + context + "/" + str(entry.id), not str(entry.id).begins_with("memory_"))
	_check("hall_exit_returns_to_courtyard_front_door/" + context, _entry("courtyard_exit").get("destination") == "home_estate" and _entry("courtyard_exit").get("return_id") == "house_entry")

func _check_hall_map() -> void:
	_main.show_map()
	await _layout()
	var labels: Array[String] = _navigation_labels()
	var expected: Array[String] = []
	for rid: String in CHILD_ROOMS: expected.append(str(_entry(rid + "_gate").get("label", "missing")))
	expected.append(str(_entry("courtyard_exit").get("label", "missing")))
	var same := labels.size() == expected.size()
	for label: String in expected: same = same and labels.count(label) == 1
	_check("hall_map_has_seven_room_doors_and_courtyard_exit", same)
	_report.map_pages.append({"room":"home_hall", "labels":labels, "passed":same})
	_check("hall_map_is_navigation_not_room_menu", _main.ui.current_panel == "map")
	root.size = Vector2i(960, 640)
	await _layout()
	_check("hall_map_panel_fits_small_window", root.get_visible_rect().encloses(_main.ui.panel.get_global_rect()))
	_main._on_action("close")
	await _layout()
	_check("small_window_hall_is_walkable", _main.room == "home_hall" and not _main.player.locked and not _main.ui.modal.visible)
	root.size = Vector2i(1440, 900)
	await _layout()

func _click_text(text: String) -> bool:
	# Viewport-local dispatch also works when a native 960px window is scaled.
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
	if _indoor_finished: return
	_indoor_finished = true
	_check("no_room_selection_menu_seen_during_transitions", _forbidden_menu_frames == 0)
	_check("production_save_unchanged", _production_signature() == _protected_before)
	_report["engine"] = Engine.get_version_info()["string"]
	_report["passed"] = _report.failures.is_empty()
	_report["complete"] = true
	_report["actual_physics_movement"] = true
	_report["production_save_unchanged"] = _production_signature() == _protected_before
	_report["forbidden_room_menu_frames"] = _forbidden_menu_frames
	_report["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	var report_directory := ProjectSettings.globalize_path(INDOOR_REPORT_DIR)
	DirAccess.make_dir_recursive_absolute(report_directory)
	var file := FileAccess.open(report_directory.path_join(_report_name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	else:
		_report.failures.append("write_indoor_report")
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := "user://validation-%d.json%s" % [OS.get_process_id(), suffix]
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HOME_INDOOR " + JSON.stringify({"passed":_report.failures.is_empty(),"checks":_report.checks.size(),"routes":_report.routes.size(),"transitions":_report.transitions.size(),"failures":_report.failures}))
	quit(0 if _report.failures.is_empty() else 1)
