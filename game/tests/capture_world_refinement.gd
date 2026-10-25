extends "res://tests/capture_visual_refinement.gd"
## All 44 scenes, batched native captures, immutable before-camera records.
var rooms: Array[String] = []
var batch := "all"
const WORLD_PROOF := "res://../docs/verification/world-refinement"

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--refinement-stage="): stage = arg.trim_prefix("--refinement-stage=")
		elif arg.begins_with("--rooms="): rooms.assign(arg.trim_prefix("--rooms=").split(","))
		elif arg.begins_with("--batch="): batch = arg.trim_prefix("--batch=")
		elif arg == "--refinement-performance": measure_performance = true
	if rooms.is_empty() or stage not in ["before", "after"]:
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	output_dir = ProjectSettings.globalize_path(WORLD_PROOF).path_join("performance" if measure_performance else stage).path_join(batch)
	DirAccess.make_dir_recursive_absolute(output_dir)
	if stage == "after":
		var path := WORLD_PROOF + "/before/" + batch + "/report.json"
		if not FileAccess.file_exists(path):
			quit(2)
			return
		baseline = JSON.parse_string(FileAccess.get_file_as_string(path))
	protected_before = production_signature()
	source_before = source_signature()
	create_timer(900.0).timeout.connect(func(): check(false, "capture_timeout"); finish())
	check(DisplayServer.get_name() != "headless", "native_display_server")
	if DisplayServer.get_name() == "headless":
		await finish()
		return
	AudioServer.set_bus_mute(0, true)
	game = load("res://main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	if not await wait_for_room("village"):
		check(false, "initial_scene_ready")
		await finish()
		return
	var state: Node = root.get_node("State")
	save_path = str(state.save_path)
	check(save_path == "user://validation-%d.json" % OS.get_process_id(), "isolated_save")
	if save_path != "user://validation-%d.json" % OS.get_process_id():
		await finish()
		return
	game.muted = true
	game.voice.stop()
	game.sounds.enabled = false
	game.ui.reduced_motion = true
	game.player.reduced_motion = true
	game.application_backgrounded = false
	state.set_preference("fixed_day", true)
	state.set_preference("effects", false)
	state.set_preference("voice", false)
	state.set_preference("reduced_motion", true)
	game._close()
	for room_id: String in rooms:
		if game.room != room_id: await game.change_room(room_id)
		if not await wait_for_room(room_id):
			check(false, "room_ready/" + room_id)
			continue
		game._close()
		game.living.set_day_phase("day", true)
		game.living.set_weather("clear", true)
		game.living.set_context({"fixed_day":true, "fixed_weather":true, "reduced_motion":true})
		game.ui.toast_timer = 0
		game.ui.toast_label.hide()
		game.ui.bubble_panel.hide()
		await frames(30)
		await capture(room_id + "-production", "production_camera_default_spawn")
		await review_view(room_id, "overview")
		if measure_performance: await sample_performance(room_id)
	await finish()

func review_view(room_id: String, _kind: String) -> void:
	var old_transform: Transform3D = game.camera.transform
	var old_size: float = game.camera.size
	game.capturing_photo = true
	game.ui.hide()
	var recorded := baseline_capture(room_id + "-overview")
	if not recorded.is_empty():
		apply_camera(recorded.camera)
	else:
		var bounds: Rect2 = game.metadata.bounds
		var center := Vector3(bounds.get_center().x, 0.6, bounds.get_center().y)
		var span := maxf(bounds.size.x, bounds.size.y)
		if room_id == "village": center.y = 5.3
		game.camera.position = center + Vector3(18, 30, 28) * maxf(1.0, span / 26.0)
		game.camera.look_at(center, Vector3.UP)
		game.camera.size = span * 1.22
	await capture(room_id + "-overview", "fixed_overview_camera_hud_hidden")
	game.camera.transform = old_transform
	game.camera.size = old_size
	game.ui.show()
	game.capturing_photo = false

func source_signature() -> Dictionary:
	var result := super.source_signature()
	for room_id: String in rooms:
		var path := "res://assets/world/island.glb" if room_id == "village" else "res://assets/interiors/" + room_id + ".glb"
		result[path] = FileAccess.get_sha256(path)
	return result

func finish() -> void:
	if finishing: return
	finishing = true
	check(protected_before == production_signature(), "production_files_unchanged")
	check(source_before == source_signature(), "capture_sources_stable_during_run")
	check(captures.size() == rooms.size() * 2, "all_views_captured", captures.size())
	var failures := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var report := {"stage":stage,"batch":batch,"rooms":rooms,"result":"PASS" if failures.is_empty() else "FAIL",
		"checks":checks,"captures":captures,"performance_samples":performance_samples,
		"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),
		"production_before":protected_before,"production_after":production_signature(),"source_sha256":source_before,
		"isolated_save":save_path,"engine_arguments":OS.get_cmdline_args(),
		"scope":"Native 1440x900 production and fixed overview cameras. Direct room entry proves visual loading only; independent physical-route tests cover gameplay."}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	if save_path == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("WORLD_REFINEMENT_RESULT " + JSON.stringify({"batch":batch,"stage":stage,"checks":checks.size(),"failures":failures.size(),"captures":captures.size()}))
	quit(0 if failures.is_empty() else 1)
