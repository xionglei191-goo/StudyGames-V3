extends "res://tests/test_home_indoor.gd"
## Focused art-change regression: real doors, two rooms, ten objects and decorations.
## Reuses physical movement helpers; writes only visual-refinement/gameplay-report.json.

const REFINEMENT_REPORT_ROOT := "res://../docs/verification/visual-refinement"
const DECORATION_IDS: Array[String] = ["flower_box", "picnic", "lamp"]
var refinement_baseline: Dictionary = {}
var refinement_source_before: Dictionary = {}

func _run() -> void:
	root.size = Vector2i(1440, 900)
	_report_name = "gameplay-report.json"
	_report["coverage"] = "Physical village gate -> courtyard front door -> hall living-room door -> living room -> matching hall door -> courtyard -> village. Ten household points, two household task cancel/finish/replay lifecycles and all three living-room decoration preview/cancel/place/remove/undo paths."
	_report["scope_limit"] = "Focused regression for the two refined sample scenes; does not run other household rooms or the complete world suite. Headless results do not claim visual quality or GPU performance."
	_report["map_pages"] = []
	_report["actual_mouse_dispatch"] = true
	_report["actual_door_key_dispatch"] = true
	_report["fixture"] = "Isolated fresh save with the three existing decorations already owned. Ownership is a test fixture, not a purchase or reward. No coins are added or spent."
	_protected_before = _production_signature()
	refinement_source_before = _source_signature()
	create_timer(300.0).timeout.connect(func(): _check("refinement_timeout", false); _finish())
	AudioServer.set_bus_mute(0, true)
	_main = load("res://main.tscn").instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready", false)
		await _finish()
		return
	var state: Node = root.get_node("State")
	var isolated := str(state.save_path) == "user://validation-%d.json" % OS.get_process_id()
	_check("isolated_save", isolated)
	if not isolated:
		await _finish()
		return
	_main.muted = true
	_main.voice.stop()
	_main.sounds.enabled = false
	_main.ui.reduced_motion = true
	_main.application_backgrounded = false
	state.set_preference("fixed_day", true)
	state.set_preference("effects", false)
	state.set_preference("voice", false)
	state.set_preference("reduced_motion", true)
	for id: String in DECORATION_IDS:
		state.data.decorations_owned[id] = true
		state.data.decorations_placed[id] = false
	_check("decoration_fixture_saved", state.save_state())
	refinement_baseline = {"learning":state.data.learning.duplicate(true), "completed_units":state.data.completed_units.duplicate(true), "coins":state.data.coins, "day":state.data.day}
	if not await _walk_to_entry("home_gate", "refinement_enter_residence") or not await _transition("home_gate", "home_estate"):
		await _finish()
		return
	_check("courtyard_front_door_enters_hall", _entry("house_entry").get("destination") == "home_hall")
	_check("courtyard_has_seven_interactions", _main.interactions.size() == 7)
	_test_refined_foliage()
	await _test_house_room("home_estate")
	_main.show_map()
	await _layout()
	if not await _choose_and_follow("house_entry") or not await _transition("house_entry", "home_hall"):
		await _finish()
		return
	_check("hall_has_physical_living_room_door", _entry("home_gate").get("destination") == "home")
	_main.show_map()
	await _layout()
	if not await _choose_and_follow("home_gate") or not await _transition("home_gate", "home"):
		await _finish()
		return
	_check("living_room_exit_returns_to_matching_hall_door", _entry("home_exit").get("destination") == "home_hall" and _entry("home_exit").get("return_id") == "home_gate")
	await _test_house_room("home")
	await _test_refined_decorations()
	if not await _walk_to_entry("home_exit", "refinement_leave_living_room") or not await _transition("home_exit", "home_hall"):
		await _finish()
		return
	_main.show_map()
	await _layout()
	if not await _choose_and_follow("courtyard_exit") or not await _transition("courtyard_exit", "home_estate"):
		await _finish()
		return
	if not await _walk_to_entry("village_exit", "refinement_leave_residence") or not await _transition("village_exit", "village"):
		await _finish()
		return
	_check("journey_returns_to_village", _main.room == "village")
	_check("ten_household_points_recorded", state.data.life.discoveries.size() == 10)
	_check("two_household_tasks_recorded", state.data.life.home_tasks.size() == 2)
	var task_state: Dictionary = state.data.life.home_tasks.duplicate(true)
	var discovery_state: Dictionary = state.data.life.discoveries.duplicate(true)
	var decoration_state: Dictionary = state.data.decorations_placed.duplicate(true)
	state.load_state()
	_check("two_tasks_survive_reload", state.data.life.home_tasks == task_state)
	_check("ten_points_survive_reload", state.data.life.discoveries == discovery_state)
	_check("decoration_result_survives_reload", state.data.decorations_placed == decoration_state)
	var order: Array[String] = []
	for transition: Dictionary in _report.transitions:
		order.append(str(transition.get("to", "")))
	_check("exact_physical_round_trip", order == ["home_estate", "home_hall", "home", "home_hall", "home_estate", "village"])
	await _finish()

func _test_refined_decorations() -> void:
	var state: Node = root.get_node("State")
	await _main.show_decorate()
	await _layout()
	_check("decoration_screen_keeps_living_room", _main.room == "home" and _main.ui.current_panel == "decorate")
	for id: String in DECORATION_IDS:
		var model: Node3D = _main.world.find_child("SG_DECOR_MODEL_" + id.to_upper(), true, false) as Node3D
		_check("decor_model_retained/" + id, is_instance_valid(model))
		if not is_instance_valid(model):
			continue
		_check("decor_initially_hidden/" + id, not model.is_visible_in_tree() and not bool(state.data.decorations_placed[id]))
		var saved: Dictionary = state.snapshot()
		if not await _click_action("preview_place:" + id): continue
		_check("decor_preview_visible_without_commit/" + id, model.is_visible_in_tree() and state.snapshot() == saved)
		await _click_action("cancel_place")
		_check("decor_cancel_restores_model_and_state/" + id, not model.is_visible_in_tree() and state.snapshot() == saved)
		await _click_action("preview_place:" + id)
		await _click_action("confirm_place")
		_check("decor_place_commits_visual_and_state/" + id, model.is_visible_in_tree() and bool(state.data.decorations_placed[id]))
		await _click_action("preview_place:" + id)
		await _click_action("confirm_place")
		_check("decor_remove_commits_visual_and_state/" + id, not model.is_visible_in_tree() and not bool(state.data.decorations_placed[id]))
		await _click_action("undo_place")
		_check("decor_undo_removal_restores_model/" + id, model.is_visible_in_tree() and bool(state.data.decorations_placed[id]))
		await _click_action("undo_place")
		_check("decor_undo_returns_to_initial_model_and_state/" + id, not model.is_visible_in_tree() and not bool(state.data.decorations_placed[id]))
	_main._on_action("close")
	await _layout()

func _click_action(id: String) -> bool:
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		if str(node.get_meta("action_id", "")) == id:
			return await _click_text((node as Button).text)
	_check("action_button_exists/" + id, false)
	return false

func _test_refined_foliage() -> void:
	var living: Node3D = _main.living
	var original_context: Dictionary = living.context.duplicate(true)
	var original_focus: bool = living._focus_backgrounded
	var original_process: bool = living.is_processing()
	var original_effects: bool = living.environment_effects_enabled
	living.set_process(false)
	living._focus_backgrounded = false
	living.environment_effects_enabled = true
	living.set_context({"reduced_motion":true, "dialogue_open":false, "learning_open":false, "memory_open":false, "paused":false, "backgrounded":false, "auto_cycle":false, "fixed_day":true, "fixed_weather":true})
	var protected_geometry := _protected_geometry_signature()
	var groups: Dictionary = {}
	var refined: Array[Dictionary] = []
	for item: Dictionary in living._foliage:
		var node := item.node as MeshInstance3D
		var label := str(node.name)
		if "Tree_Foliage_Boughs_" not in label and "Tree_Leaf_Sprays_" not in label:
			continue
		refined.append(item)
		var tree := label.get_slice("_Foliage_Boughs_", 0).get_slice("_Leaf_Sprays_", 0)
		if not groups.has(tree): groups[tree] = []
		groups[tree].append(item)
		var original: Transform3D = item.transform
		_check("foliage_source_origin_zero/" + label, original.origin.is_zero_approx())
		_check("foliage_begins_at_source_transform/" + label, node.transform.is_equal_approx(original))
	_check("all_sixteen_refined_foliage_batches_captured", refined.size() == 16 and living._foliage.size() == 16)
	_check("two_refined_trees_registered", groups.size() == 2 and groups.has("West_Apple_Tree") and groups.has("East_Shade_Tree"))
	var group_report: Array[Dictionary] = []
	for tree: String in groups:
		var batches: Array = groups[tree]
		_check("eight_batches_for_tree/" + tree, batches.size() == 8)
		var first: Dictionary = batches[0]
		var first_node := first.node as MeshInstance3D
		var trunk := _main.world.find_child(tree + "_Curved_Trunk_Top", true, false) as MeshInstance3D
		_check("common_trunk_pivot_source_exists/" + tree, is_instance_valid(trunk))
		if not is_instance_valid(trunk): continue
		var trunk_box := trunk.get_aabb()
		var trunk_base := Vector3(trunk_box.get_center().x, trunk_box.position.y, trunk_box.get_center().z)
		var expected_world_pivot := trunk.to_global(trunk_base)
		var names: Array[String] = []
		for item: Dictionary in batches:
			var node := item.node as MeshInstance3D
			names.append(str(node.name))
			_check("shared_tree_pivot/" + str(node.name), node.to_global(item.pivot).is_equal_approx(expected_world_pivot))
			_check("shared_tree_phase_axis_and_source/" + str(node.name), is_equal_approx(float(item.phase), float(first.phase)) and (item.axis as Vector3).is_equal_approx(first.axis) and (item.transform as Transform3D).is_equal_approx(first.transform))
		group_report.append({"tree":tree, "batches":names, "common_world_pivot":_vector(expected_world_pivot), "first_local_pivot":_vector(first.pivot), "phase":first.phase, "source_origin":_vector(first_node.transform.origin)})
	living.set_context({"reduced_motion":false})
	for index: int in 35:
		living.tick(0.1)
	for item: Dictionary in refined:
		var node := item.node as MeshInstance3D
		_check("normal_wind_tick_moves_batch/" + str(node.name), not node.transform.is_equal_approx(item.transform))
	for tree: String in groups:
		var batches: Array = groups[tree]
		var first_node := batches[0].node as MeshInstance3D
		for item: Dictionary in batches:
			var node := item.node as MeshInstance3D
			_check("tree_batches_move_together/" + str(node.name), node.transform.is_equal_approx(first_node.transform))
	_check("wind_preserves_sg_floor_and_colliders", _protected_geometry_signature() == protected_geometry)
	living.set_context({"reduced_motion":true})
	living.tick(0.1)
	for item: Dictionary in refined:
		var node := item.node as MeshInstance3D
		_check("reduced_motion_restores_source_batch/" + str(node.name), node.transform.is_equal_approx(item.transform))
	_check("reduced_motion_preserves_sg_floor_and_colliders", _protected_geometry_signature() == protected_geometry)
	_report["refined_foliage"] = {"captured_batches":refined.size(), "groups":group_report, "normal_ticks":35, "tick_delta":0.1, "protected_floor_collider_nodes":protected_geometry.size(), "scope":"Actual imported courtyard mesh batches, common runtime trunk pivots and the real LivingWorld.tick function; no source vertices or collision geometry are changed."}
	living.context = original_context
	living._focus_backgrounded = original_focus
	living.environment_effects_enabled = original_effects
	living.set_context({"reduced_motion":bool(original_context.get("reduced_motion", true))})
	living.set_process(original_process)

func _protected_geometry_signature() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _main.world.find_children("*", "Node3D", true, false):
		var label := str(node.name)
		if not label.begins_with("SG_FLOOR_") and not label.begins_with("SG_COLLIDER_"):
			continue
		var item: Dictionary = {"transform":(node as Node3D).transform}
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			var geometry: Array[String] = []
			if mesh:
				for surface: int in mesh.get_surface_count():
					geometry.append(var_to_bytes(mesh.surface_get_arrays(surface)).hex_encode().sha256_text())
			item["geometry_hashes"] = geometry
		result[str(node.get_path())] = item
	return result

func _production_signature() -> Dictionary:
	var result: Dictionary = {}
	for filename: String in DirAccess.get_files_at("user://"):
		if not filename.begins_with("validation-"):
			result[filename] = FileAccess.get_sha256("user://" + filename)
	return result

func _source_signature() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://assets/interiors/home_estate.glb", "res://assets/interiors/home.glb", "res://scripts/home_visual_refinement.gd", "res://scripts/living_world.gd", "res://data/interiors_manifest.json"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func _finish() -> void:
	if _indoor_finished:
		return
	_indoor_finished = true
	var protected_after := _production_signature()
	_check("production_save_and_photos_unchanged", protected_after == _protected_before)
	_check("source_assets_stable_during_test", _source_signature() == refinement_source_before)
	_check("no_room_selection_menu_seen", _forbidden_menu_frames == 0)
	if not refinement_baseline.is_empty():
		var state: Node = root.get_node("State")
		_check("learning_unchanged", state.data.learning == refinement_baseline.learning)
		_check("completed_units_unchanged", state.data.completed_units == refinement_baseline.completed_units)
		_check("coins_unchanged", state.data.coins == refinement_baseline.coins)
		_check("day_unchanged", state.data.day == refinement_baseline.day)
	_report["engine"] = Engine.get_version_info()["string"]
	_report["passed"] = _report.failures.is_empty()
	_report["complete"] = true
	_report["actual_physics_movement"] = true
	_report["production_before"] = _protected_before
	_report["production_after"] = protected_after
	_report["source_sha256"] = refinement_source_before
	_report["forbidden_room_menu_frames"] = _forbidden_menu_frames
	_report["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	var directory := ProjectSettings.globalize_path(REFINEMENT_REPORT_ROOT)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("gameplay-report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_report, "  "))
		file.close()
	else:
		_report.failures.append("write_refinement_report")
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := "user://validation-%d.json%s" % [OS.get_process_id(), suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("VISUAL_REFINEMENT_GAMEPLAY " + JSON.stringify({"passed":_report.failures.is_empty(), "checks":_report.checks.size(), "routes":_report.routes.size(), "transitions":_report.transitions.size(), "failures":_report.failures}))
	quit(0 if _report.failures.is_empty() else 1)
