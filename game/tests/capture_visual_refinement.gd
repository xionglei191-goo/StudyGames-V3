extends SceneTree
## Native art comparison, with separate production and explicit review cameras.
## Run with -- --test-harness --refinement-stage=before (or after).
## This capture enters rooms directly. It does not prove door circulation.

const OUTPUT_ROOT := "res://../docs/verification/visual-refinement"
const ROOMS: Array[String] = ["home_estate", "home"]
const SOURCE_PATHS: Array[String] = [
	"res://project.godot", "res://scripts/world_builder.gd", "res://scripts/world_art.gd",
	"res://scripts/living_world.gd", "res://scripts/home_visual_refinement.gd",
	"res://assets/interiors/home_estate.glb", "res://assets/interiors/home.glb"
]
var game: Node3D
var stage := "before"
var output_dir := ""
var save_path := ""
var protected_before: Dictionary = {}
var source_before: Dictionary = {}
var baseline: Dictionary = {}
var captures: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var performance_samples: Array[Dictionary] = []
var measure_performance := false
var finishing := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, id: String, detail: Variant = null) -> void:
	checks.append({"id":id, "passed":ok, "detail":detail})
	if not ok:
		push_error("VISUAL_REFINEMENT " + id)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Capture requires -- --test-harness to isolate the player's save.")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--refinement-stage="):
			stage = argument.trim_prefix("--refinement-stage=")
		elif argument == "--refinement-performance":
			measure_performance = true
	if stage not in ["before", "after"]:
		push_error("Refinement stage must be before or after.")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	output_dir = ProjectSettings.globalize_path(OUTPUT_ROOT).path_join(stage)
	DirAccess.make_dir_recursive_absolute(output_dir)
	if stage == "after":
		var baseline_path := OUTPUT_ROOT + "/before/report.json"
		if not FileAccess.file_exists(baseline_path):
			push_error("Capture after requires the original before/report.json camera record.")
			quit(2)
			return
		baseline = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	protected_before = production_signature()
	source_before = source_signature()
	create_timer(180.0).timeout.connect(func(): check(false, "capture_timeout"); finish())
	check(DisplayServer.get_name() != "headless", "native_display_server", DisplayServer.get_name())
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
	check(save_path == "user://validation-%d.json" % OS.get_process_id(), "isolated_save", save_path)
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
	for room_id: String in ROOMS:
		await game.change_room(room_id)
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
		check(game.living.get_status().weather == "clear" and game.living.get_status().day_phase == "day", "fixed_day_clear/" + room_id)
		await capture(room_id + "-production", "production_gameplay_camera_at_default_room_spawn")
		await review_view(room_id, "overview")
		await review_view(room_id, "detail")
		if measure_performance:
			await sample_performance(room_id)
	await finish()

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func wait_for_room(room_id: String) -> bool:
	for index: int in 900:
		await frames(1)
		if game.scene_ready and not game.loading_room and game.nav_ready and game.room == room_id:
			return true
	return false

func review_view(room_id: String, kind: String) -> void:
	var old_transform: Transform3D = game.camera.transform
	var old_size: float = game.camera.size
	var id := room_id + "-" + kind
	game.capturing_photo = true
	game.ui.hide()
	var recorded := baseline_capture(id)
	if not recorded.is_empty():
		apply_camera(recorded.camera)
	else:
		var bounds: Rect2 = game.metadata.bounds
		var center := Vector3(bounds.get_center().x, 0.5, bounds.get_center().y)
		var offset := Vector3(18, 25, 24)
		var size_value := 44.0 if room_id == "home_estate" else 25.0
		if kind == "detail":
			var target := "house_entry" if room_id == "home_estate" else "memory_03"
			for entry: Dictionary in game.interactions:
				if str(entry.id) == target:
					center = entry.position + (Vector3(0, 2.0, -1.0) if room_id == "home_estate" else Vector3(0, 0.8, 0))
					break
			offset = Vector3(14, 13, 18) if room_id == "home_estate" else Vector3(12, 17, 19)
			size_value = 18.0 if room_id == "home_estate" else 11.0
		game.camera.position = center + offset
		game.camera.look_at(center, Vector3.UP)
		game.camera.size = size_value
	await capture(id, "explicit_fixed_review_camera_" + kind + "_hud_hidden")
	game.camera.transform = old_transform
	game.camera.size = old_size
	game.ui.show()
	game.capturing_photo = false

func capture(id: String, kind: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := output_dir.path_join(id + ".png")
	check(picture.save_png(path) == OK, "image_saved/" + id)
	check(picture.get_size() == Vector2i(1440, 900), "native_image_size/" + id, [picture.get_width(), picture.get_height()])
	var camera := camera_record()
	var previous := baseline_capture(id)
	if not previous.is_empty():
		check(cameras_match(previous.camera, camera), "same_camera_as_before/" + id, {"before":previous.camera, "after":camera})
	captures.append({
		"id":id, "kind":kind, "image":path, "room":game.room,
		"image_size":[picture.get_width(), picture.get_height()], "window_size":[root.size.x, root.size.y],
		"camera":camera, "player_position":vector(game.player.position), "hud_visible":game.ui.visible,
		"panel":game.ui.current_panel, "weather":game.living.get_status(), "scene_source":str(game.metadata.get("source", ""))
	})
	print("VISUAL_REFINEMENT_CAPTURE " + stage + "/" + id)

func camera_record() -> Dictionary:
	return {"position":vector(game.camera.position), "basis_x":vector(game.camera.basis.x), "basis_y":vector(game.camera.basis.y), "basis_z":vector(game.camera.basis.z), "size":game.camera.size, "projection":game.camera.projection}

func apply_camera(data: Dictionary) -> void:
	game.camera.transform = Transform3D(Basis(from_vector(data.basis_x), from_vector(data.basis_y), from_vector(data.basis_z)), from_vector(data.position))
	game.camera.size = float(data.size)

func cameras_match(first: Dictionary, second: Dictionary) -> bool:
	for key: String in ["position", "basis_x", "basis_y", "basis_z"]:
		if from_vector(first[key]).distance_to(from_vector(second[key])) > 0.001:
			return false
	return absf(float(first.size) - float(second.size)) < 0.001 and first.projection == second.projection

func baseline_capture(id: String) -> Dictionary:
	for item: Dictionary in baseline.get("captures", []):
		if str(item.id) == id:
			return item
	return {}

func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func from_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func production_signature() -> Dictionary:
	var result: Dictionary = {}
	for filename: String in DirAccess.get_files_at("user://"):
		if not filename.begins_with("validation-"):
			result[filename] = FileAccess.get_sha256("user://" + filename)
	return result

func sample_performance(room_id: String) -> void:
	# Wall intervals include GPU/presentation pacing. Godot monitors update coarsely;
	# their process value is not an OS CPU-exclusive duration. Let PNG-save frames age out.
	# Simulation delta is reported separately, especially if --fixed-fps was used.
	await frames(60)
	await create_timer(3.0).timeout
	var wall_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var simulation_ms: Array[float] = []
	var measured_fps: Array[float] = []
	var previous := Time.get_ticks_usec()
	var started := previous
	var drawn_before := Engine.get_frames_drawn()
	for index: int in 300:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall_ms.append(float(now - previous) / 1000.0)
		previous = now
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		simulation_ms.append(game.get_process_delta_time() * 1000.0)
		measured_fps.append(float(Engine.get_frames_per_second()))
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	var drawn_frames := Engine.get_frames_drawn() - drawn_before
	check(drawn_frames >= 295, "native_frames_rendered/" + room_id, drawn_frames)
	performance_samples.append({
		"room":room_id, "warmup_physics_frames":60, "additional_warmup_seconds":3.0, "sample_process_frames":300,
		"sample_drawn_frames":drawn_frames, "window_focused":DisplayServer.window_is_focused(), "window_mode":DisplayServer.window_get_mode(),
		"wall_elapsed_seconds":elapsed, "wall_effective_fps":float(drawn_frames) / maxf(elapsed, 0.000001),
		"wall_frame_ms":distribution(wall_ms), "engine_process_monitor_ms":distribution(process_ms),
		"engine_physics_monitor_ms":distribution(physics_ms), "simulation_delta_ms":distribution(simulation_ms),
		"engine_smoothed_fps":distribution(measured_fps), "camera":camera_record(),
		"draw_calls_last_frame":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_objects_last_frame":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"scope":"One local native 1440x900 sample scene, fixed sunny daytime and reduced motion at default spawn. Not a device minimum, broad gameplay benchmark, or GPU-only timing. Wall frame intervals include presentation pacing. Godot process/physics monitors update coarsely and are not OS CPU-exclusive durations; simulation delta is separate."
	})
	print("VISUAL_REFINEMENT_PERFORMANCE " + room_id + " fps=" + str(float(drawn_frames) / maxf(elapsed, 0.000001)) + " drawn=" + str(drawn_frames))

func distribution(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total := 0.0
	for value: float in ordered:
		total += value
	return {"min":ordered[0], "mean":total / float(ordered.size()), "p50":ordered[roundi(float(ordered.size() - 1) * 0.5)], "p95":ordered[roundi(float(ordered.size() - 1) * 0.95)], "max":ordered[-1]}

func source_signature() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCE_PATHS:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func finish() -> void:
	if finishing:
		return
	finishing = true
	var protected_after := production_signature()
	check(protected_before == protected_after, "production_files_unchanged")
	check(source_before == source_signature(), "capture_sources_stable_during_run")
	check(captures.size() == 6, "all_six_views_captured", captures.size())
	if measure_performance:
		check(performance_samples.size() == ROOMS.size(), "performance_sampled_both_rooms", performance_samples.size())
	var failures := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var report := {
		"stage":stage, "result":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "captures":captures,
		"renderer":RenderingServer.get_current_rendering_method(), "display_server":DisplayServer.get_name(),
		"production_before":protected_before, "production_after":protected_after, "source_sha256":source_before,
		"isolated_save":save_path, "audio":"master_bus_muted_and_game_voice_effects_disabled",
		"performance_samples":performance_samples, "engine_arguments":OS.get_cmdline_args(),
		"scope":"Native art comparison at 1440x900. Rooms are entered directly for visual evidence; door circulation is not claimed. Each room includes the unmodified production camera at default spawn, plus fixed overview and detail review cameras. After review cameras reuse the recorded before transforms; production camera equality is checked, not forced."
	}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	if save_path == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(save_path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("VISUAL_REFINEMENT_RESULT " + JSON.stringify({"stage":stage, "checks":checks.size(), "failures":failures.size(), "captures":captures.size()}))
	quit(0 if failures.is_empty() else 1)
