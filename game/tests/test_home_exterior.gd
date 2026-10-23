extends "res://tests/test_school_hierarchy.gd"
## Exterior-first home: real courtyard walks, front-door input and seven room buttons.

const House = preload("res://scripts/home_catalog.gd")

func _run() -> void:
	root.size = Vector2i(1440, 900)
	_report_name = "home-exterior-report.json"
	_report["coverage"] = "village -> whole-house courtyard -> physical front door -> seven room buttons -> front door courtyard -> village; forty memory points and eight household tasks"
	_report["actual_mouse_dispatch"] = true
	_report["actual_front_door_key_dispatch"] = true
	_report["map_pages"] = []
	_protected_before = _production_signature()
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
	var learning_before: Dictionary = state.data.learning.duplicate(true)
	var units_before: Dictionary = state.data.completed_units.duplicate(true)
	var coins_before: int = state.data.coins
	if not await _walk_to_entry("home_gate", "enter_residence") or not await _transition("home_gate", "home_estate"):
		await _finish()
		return
	_check("residence_level_two", int(_main.metadata.scene_level) == 2 and _main.metadata.parent_room == "village")
	_check("single_front_door_exists", _entry("house_entry").get("marker") == "SG_HOUSE_ENTRY")
	_check("only_seven_courtyard_interactions", _main.interactions.size() == 7)
	for rid: String in House.ROOMS:
		if rid != "home_estate": _check("no_outdoor_room_door/" + rid, _entry(rid + "_gate").is_empty())
	_main.household.show_entry()
	_check("cannot_open_rooms_from_courtyard_gate", _main.ui.current_panel != "home_entry")
	await _main.household.handle_action("home:enter:home")
	_check("cannot_enter_room_before_front_door", _main.room == "home_estate")
	_main.show_map()
	await _layout()
	_check("courtyard_map_has_front_door_exit_and_two_pages", _navigation_labels().size() == 4)
	if await _click_text("小院里的五个生活位置"):
		_check("courtyard_memory_page", _main.ui.current_panel == "home_memories" and _navigation_labels().size() == 6)
		await _click_text("返回住宅导览")
		_check("return_to_courtyard_map", _main.ui.current_panel == "map")
	_main._on_action("close")
	await _test_house_room("home_estate")
	for rid: String in House.ROOMS:
		if rid == "home_estate": continue
		_main.show_map()
		await _layout()
		if not await _choose_and_follow("house_entry"): continue
		await _press_front_door()
		_check("door_opens_entry/" + rid, _main.ui.current_panel == "home_entry")
		_check("entry_keeps_second_level_scene/" + rid, _main.room == "home_estate")
		var room_buttons := 0
		for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
			if str(node.get_meta("action_id", "")).begins_with("home:enter:"): room_buttons += 1
		_check("entry_has_exact_seven_rooms/" + rid, room_buttons == 7)
		if rid == "home":
			await _check_entry_small_window()
			await _click_text("先回小院逛逛")
			_check("entry_cancel_keeps_courtyard", _main.room == "home_estate" and not _main.ui.modal.visible)
			await _press_front_door()
			await _main.household.handle_action("home:enter:school")
			_check("entry_rejects_non_household_room", _main.room == "home_estate")
		var plan: Dictionary = House.room(rid)
		if not await _click_text(str(plan.name) + "\n" + str(plan.task.title)): continue
		var entered: bool = await _wait_for_room(rid)
		_check("room_button_enters/" + rid, entered)
		_report.transitions.append({"from":"home_estate", "interaction":"house_entry", "room_button":"home:enter:" + rid, "to":rid, "passed":entered})
		if not entered: continue
		_check("room_level_three/" + rid, int(_main.metadata.scene_level) == 3 and _main.metadata.parent_room == "home_estate")
		_check("child_return_contract/" + rid, _entry("home_exit").get("destination") == "home_estate" and _entry("home_exit").get("return_id") == "house_entry")
		await _test_house_room(rid)
		if await _walk_to_entry("home_exit", "leave_room"):
			await _transition("home_exit", "home_estate")
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

func _press_front_door() -> void:
	# Real E input exercises the same nearest-door path as ordinary play.
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	await _layout()

func _check_entry_small_window() -> void:
	root.size = Vector2i(960, 640)
	await _layout()
	var panel_rect: Rect2 = _main.ui.panel.get_global_rect()
	_check("entry_panel_fits_960x640", root.get_visible_rect().encloses(panel_rect))
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not str(button.get_meta("action_id", "")).begins_with("home:enter:"): continue
		var ancestor: Node = button.get_parent()
		while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
		_check("entry_room_visible_without_scroll_small/" + str(button.get_meta("action_id")), ancestor is ScrollContainer and (ancestor as ScrollContainer).get_global_rect().encloses(button.get_global_rect()))
		if ancestor is ScrollContainer: (ancestor as ScrollContainer).ensure_control_visible(button)
		await _layout()
		_check("entry_room_button_reachable_small/" + str(button.get_meta("action_id")), root.get_visible_rect().has_point(button.get_global_rect().get_center()))
	root.size = Vector2i(1440, 900)
	await _layout()

func _transition(id: String, destination_room: String) -> bool:
	if id != "home_exit": return await super._transition(id, destination_room)
	var origin: String = _main.room
	var selected: bool = str(_main.nearest.get("id", "")) == id
	_check("transition_selected_" + origin + "/" + id, selected)
	if not selected: return false
	_main.interact_nearest()
	var result: bool = await _wait_for_room(destination_room)
	var entry: Dictionary = _entry("house_entry")
	var remaining: float = _distance_xz(_main.player.position, entry.get("position", Vector3(INF, INF, INF)))
	_check("return_to_front_door/" + origin, result and not entry.is_empty() and remaining < 1.5)
	_report.transitions.append({"from":origin, "interaction":id, "to":destination_room, "return_door":"house_entry", "return_distance":remaining, "passed":result})
	_check("transition_" + origin + "/" + id + "->" + destination_room, result)
	return result

func _test_house_room(rid: String) -> void:
	var plan: Dictionary = House.room(rid)
	_check("all_prop_states_exist/" + rid, _main.world.find_children("HOME_TASK_*", "Node3D", true, false).size() == 3)
	for i in range(1, 6):
		if not await _walk_to_entry("memory_%02d" % i, "household_objects"): continue
		_main.interact_nearest()
		await _layout()
		_check("memory_opened/" + rid + "/" + str(i), _main.ui.current_panel == "memory")
		if i == 1:
			await _click_text("看看课本出处")
			_check("source_page/" + rid, _main.ui.current_panel == "home_source")
			await _click_text("回到生活物品")
			_check("source_returns_to_object/" + rid, _main.ui.current_panel == "memory")
		if i == int(plan.task.anchor):
			await _test_house_task(plan)
		_main._on_action("close")
		await _layout()

func _visible_prop(state: String) -> bool:
	var roots: Array[Node] = _main.world.find_children("HOME_TASK_*", "Node3D", true, false)
	var visible: Array[String] = []
	for node: Node in roots:
		if (node as Node3D).visible: visible.append(str(node.name))
	return visible == ["HOME_TASK_" + state.to_upper()]

func _test_house_task(plan: Dictionary) -> void:
	var state: Node = root.get_node("State")
	var rid := str(plan.room_id)
	var task: Dictionary = plan.task
	_check("initial_prop_state/" + rid, _visible_prop("before"))
	await _click_text(str(task.title))
	_check("task_opened/" + rid, _main.ui.current_panel == "home_task")
	await _click_text(str(task.steps[0]))
	_check("middle_prop_state/" + rid, _visible_prop("middle"))
	await _click_text("先放下，等会儿再做")
	_check("cancel_restores_props/" + rid, _visible_prop("before"))
	_check("cancel_does_not_complete/" + rid, not state.data.life.home_tasks.has(str(task.id)))
	_main.show_memory(int(task.anchor))
	await _layout()
	await _click_text(str(task.title))
	for label: String in task.steps:
		await _click_text(label)
	_check("all_steps_recorded/" + rid, state.data.life.home_tasks.get(str(task.id), false))
	_check("finished_prop_state/" + rid, _visible_prop("after"))
	_check("completion_returns_to_object/" + rid, _main.ui.current_panel == "memory")
	var before: Dictionary = state.snapshot()
	await _main.household.handle_action("home:step")
	_check("extra_step_is_idempotent/" + rid, state.snapshot() == before)
	await _click_text(str(task.title))
	await _click_text(str(task.steps[0]))
	await _click_text("先放下，等会儿再做")
	_check("cancel_replay_restores_saved_result/" + rid, _visible_prop("after"))
