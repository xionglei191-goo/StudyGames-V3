extends SceneTree
## Native static-camera profiling. Run through scripts/verify_p1.py for process RSS.

var _main: Node
var _state: Node
var _output: String = ""
var _duration: float = 60.0
var _warmup: float = 10.0
var _repeats: int = 2
var _width: int = 1440
var _height: int = 900
var _rooms: Array[String] = ["landmark_A", "village", "school"]
var _weather: String = "clear"
var _phase: String = "day"
var _validate_only: bool = false
var _motion_seconds: float = 0.0
var _motion_fps: float = 4.0
var _allow_background: bool = false
var _failures: Array[String] = []
var _stages: Array[Dictionary] = []
var _motion_clips: Array[Dictionary] = []
var _protected: Dictionary = {}
var _hardware: Dictionary = {}
var _started_utc: float = 0.0
var _stage_number: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	if not OS.get_cmdline_user_args().has("--test-harness"):
		_failures.append("Requires --test-harness to isolate the player's save.")
	if _output.is_empty() or _duration < 0.25 or _duration > 300.0 or _warmup < 0.0 or _warmup > 120.0 or _repeats < 1 or _repeats > 4 or _width < 960 or _height < 640 or _motion_seconds < 0.0 or _motion_seconds > 30.0 or _motion_fps < 1.0 or _motion_fps > 12.0:
		_failures.append("Invalid output, sampling interval, repeat count or resolution.")
	if _rooms.is_empty() or _weather not in ["clear", "cloudy", "light_rain", "mist"] or _phase not in ["dawn", "day", "dusk", "night"]:
		_failures.append("Invalid room, weather or day-phase selection.")
	if _validate_only:
		print("P1_PERFORMANCE_CONFIGURATION ", JSON.stringify({"valid": _failures.is_empty(), "performance_run": false, "failures": _failures, "duration": _duration, "warmup": _warmup, "rooms": _rooms}))
		quit(0 if _failures.is_empty() else 2)
		return
	for argument: String in OS.get_cmdline_args():
		if argument == "--headless" or argument.begins_with("--fixed-fps") or argument.begins_with("--frame-delay") or argument == "--disable-render-loop":
			_failures.append("Artificial or disabled render timing is not performance evidence: " + argument)
	if DisplayServer.get_name() == "headless" or RenderingServer.get_video_adapter_name().is_empty():
		_failures.append("A native GPU rendering window is required.")
	if not _failures.is_empty():
		print("P1_PERFORMANCE_REJECTED ", JSON.stringify(_failures))
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	_started_utc = Time.get_unix_time_from_system()
	_protected = _production_signature()
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(_width, _height))
	if _allow_background:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_title("P1 native background render measurement")
	root.size = Vector2i(_width, _height)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_hardware = {"process_id": OS.get_process_id(), "cpu": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "os": OS.get_name(), "os_version": OS.get_version(),
		"gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(), "graphics_api": RenderingServer.get_video_adapter_api_version(),
		"engine": Engine.get_version_info(), "project_version": ProjectSettings.get_setting("application/config/version", "unknown"), "display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "requested_window": [_width, _height],
		"focus_policy": "native_background_NO_FOCUS_fixture_keeps_world_running" if _allow_background else "foreground_required_no_automatic_focus_takeover",
		"window_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second, "msaa_3d": root.msaa_3d,
		"system_memory": OS.get_memory_info(), "quality_scope": "current_runtime_settings_only_no_low_high_preset_claim", "debug_build": OS.is_debug_build()}
	_write_progress("loading", "")
	var scene: PackedScene = load("res://main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	if _allow_background:
		process_frame.connect(_keep_benchmark_running)
	_state = root.get_node("State")
	var ready_deadline: int = Time.get_ticks_msec() + 120_000
	while not bool(_main.scene_ready) and Time.get_ticks_msec() < ready_deadline:
		await process_frame
	if not bool(_main.scene_ready):
		_failures.append("Main scene did not become ready within 120 seconds.")
	elif not _main.living.has_method("set_environment_effects_enabled"):
		_failures.append("Living-world environment toggle is unavailable; a pause is not an off baseline.")
	else:
		for room: String in _rooms:
			for repetition: int in _repeats:
				var order: Array[bool] = [false, true]
				if repetition % 2 == 1:
					order.reverse()
				for enabled: bool in order:
					await _sample_stage(room, repetition, enabled)
			if _motion_seconds > 0.0:
				# Finish both complete off/on pairs before any sequence readback.
				_main.living.set_environment_effects_enabled(true)
				await RenderingServer.frame_post_draw
				await _capture_motion(room + "-after-pairs-on")
	_write_progress("finishing", "")
	var unchanged: bool = _production_signature() == _protected
	if not unchanged:
		_failures.append("Protected production save signature changed.")
	var report: Dictionary = {"schema_version": 1, "kind": "p1_native_render_raw", "started_utc": _started_utc, "ended_utc": Time.get_unix_time_from_system(),
		"hardware": _hardware, "sample_seconds_requested": _duration, "warmup_seconds_requested": _warmup, "repetitions": _repeats, "stages": _stages,
		"motion_clips": _motion_clips,
		"failures": _failures, "production_save_unchanged": unchanged, "complete": _failures.is_empty() and _stages.size() == _rooms.size() * _repeats * 2,
		"scope": "native static-camera world rendering with actual map and resident actors; player movement disabled; background fixture, if selected, is not a foreground user-experience measurement; no claim for story-animation rendering, other hardware or quality presets"}
	_write_json(_output.path_join("raw-report.json"), report)
	_cleanup_validation_save()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	print("P1_NATIVE_RENDER_RESULT ", JSON.stringify({"stages": _stages.size(), "failures": _failures, "output": _output, "production_save_unchanged": unchanged}))
	quit(0 if _failures.is_empty() else 1)


func _sample_stage(room: String, repetition: int, enabled: bool) -> void:
	_stage_number += 1
	var id: String = "%02d-%s-r%d-%s" % [_stage_number, room, repetition + 1, "on" if enabled else "off"]
	_write_progress("preparing", id)
	_main._close()
	_main.player.set_physics_process(false)
	seed(1729)
	await _main.change_room(room)
	if str(_main.room) != room:
		_failures.append(id + ": room transition failed")
		return
	_main.journey_phase = "p1_performance_fixture"
	_main.player.set_physics_process(false)
	_main.player.path.clear()
	_main.player.velocity = Vector3.ZERO
	_main.ui.reduced_motion = false
	_state.data.preferences.fixed_day = false
	_main.living.set_context({"auto_cycle": false, "guided_prologue": false, "fixed_day": false, "fixed_weather": false, "dialogue_open": false, "memory_open": false, "learning_open": false, "paused": false, "reduced_motion": false})
	_main.living.world_time = 0.0
	_main.living.performance_time = 0.0
	_main.living.set_weather(_weather, true)
	_main.living.set_day_phase(_phase, true)
	_main.living.set_environment_effects_enabled(enabled)
	_write_progress("warmup", id)
	var warmup_end: int = Time.get_ticks_usec() + int(_warmup * 1_000_000.0)
	while Time.get_ticks_usec() < warmup_end:
		await RenderingServer.frame_post_draw
	var starting_state: Dictionary = _main.living.get_status()
	var geometry: Dictionary = _geometry_summary()
	var actors_before: Array[Dictionary] = _actor_layout()
	var camera_before: Transform3D = _main.camera.global_transform
	var size_before: float = _main.camera.size
	var structural_before: String = _structure_signature()
	await RenderingServer.frame_post_draw
	var screenshot: String = id + ".png"
	var pixels: Image = root.get_texture().get_image()
	var screenshot_ok: bool = pixels != null and pixels.save_png(_output.path_join(screenshot)) == OK
	var rows: Array[PackedFloat64Array] = []
	_write_progress("sampling", id)
	var begin_ticks: int = Time.get_ticks_usec()
	var begin_epoch: float = Time.get_unix_time_from_system()
	var last_ticks: int = begin_ticks
	var stop_ticks: int = begin_ticks + int(_duration * 1_000_000.0)
	var focus_lost: int = 0
	var minimized_frames: int = 0
	var paused_frames: int = 0
	while Time.get_ticks_usec() < stop_ticks:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var focused: bool = DisplayServer.window_is_focused()
		var minimized: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
		var world_running: bool = _main.living._world_running
		var performance_running: bool = _main.living._performance_running
		if not focused:
			focus_lost += 1
		if minimized: minimized_frames += 1
		if not world_running or not performance_running: paused_frames += 1
		rows.append(PackedFloat64Array([float(now - begin_ticks) / 1_000_000.0, float(now - last_ticks) / 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			RenderingServer.get_frame_setup_time_cpu(), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.MEMORY_STATIC), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			float(focused), float(minimized), float(world_running), float(performance_running)]))
		last_ticks = now
	var end_epoch: float = Time.get_unix_time_from_system()
	var ending_state: Dictionary = _main.living.get_status()
	var structure_same: bool = structural_before == _structure_signature()
	var camera_same: bool = _main.camera.global_transform.is_equal_approx(camera_before) and is_equal_approx(_main.camera.size, size_before)
	var native_size: Vector2i = DisplayServer.window_get_size()
	var texture_size: Vector2i = Vector2i(root.get_texture().get_size())
	var stage_errors: Array[String] = []
	if rows.size() < 10: stage_errors.append("fewer_than_ten_rendered_frames")
	if focus_lost > 0 and not _allow_background: stage_errors.append("focus_lost_during_sample")
	if minimized_frames > 0: stage_errors.append("window_minimized_during_sample")
	if paused_frames > 0: stage_errors.append("world_or_performance_paused_during_sample")
	if not camera_same: stage_errors.append("camera_changed_during_sample")
	if not structure_same: stage_errors.append("static_collision_or_marker_transform_changed")
	if native_size != Vector2i(_width, _height): stage_errors.append("window_size_does_not_match_requested_size")
	if not screenshot_ok: stage_errors.append("native_screenshot_failed")
	if not (starting_state.get("spawn_failures", []) as Array).is_empty() or not (ending_state.get("spawn_failures", []) as Array).is_empty(): stage_errors.append("resident_actor_spawn_failed")
	if bool(starting_state.get("environment_effects_enabled", not enabled)) != enabled: stage_errors.append("requested_environment_mode_not_applied")
	if not bool(starting_state.get("world_running", false)) or not bool(ending_state.get("world_running", false)): stage_errors.append("world_paused_at_sample_boundary")
	if str(starting_state.get("weather", "")) != _weather or str(ending_state.get("weather", "")) != _weather: stage_errors.append("weather_mismatch")
	if str(starting_state.get("day_phase", "")) != _phase or str(ending_state.get("day_phase", "")) != _phase: stage_errors.append("day_phase_mismatch")
	for error: String in stage_errors:
		_failures.append(id + ": " + error)
	var filename: String = id + ".csv"
	var file: FileAccess = FileAccess.open(_output.path_join(filename), FileAccess.WRITE)
	if file == null:
		_failures.append(id + ": frame samples could not be written")
	else:
		file.store_csv_line(PackedStringArray(["elapsed_s", "wall_frame_ms", "engine_process_ms", "engine_physics_ms", "viewport_render_cpu_ms", "viewport_render_gpu_ms", "frame_setup_cpu_ms", "rendered_objects", "rendered_vertices_or_indices", "draw_calls", "engine_static_memory_bytes", "video_memory_bytes", "window_focused", "window_minimized", "world_running", "performance_running"]))
		for row: PackedFloat64Array in rows:
			var columns: PackedStringArray = []
			for value: float in row:
				columns.append("%.6f" % value)
			file.store_csv_line(columns)
		file.close()
	_stages.append({"id": id, "room": room, "repetition": repetition + 1, "environment_enabled": enabled, "weather": _weather, "day_phase": _phase,
		"sample_started_utc": begin_epoch, "sample_ended_utc": end_epoch, "elapsed_seconds": float(last_ticks - begin_ticks) / 1_000_000.0, "sample_count": rows.size(),
		"warmup_seconds": _warmup, "window_size": [native_size.x, native_size.y], "render_texture_size": [texture_size.x, texture_size.y],
		"logical_viewport_size": [root.get_visible_rect().size.x, root.get_visible_rect().size.y], "frame_csv": filename, "screenshot": screenshot,
		"camera_transform": var_to_str(camera_before), "camera_size": size_before, "camera_unchanged": camera_same, "static_structure_signature": structural_before, "paired_structure_signature": _structure_signature(true),
		"background_fixture": _allow_background, "unfocused_frames": focus_lost, "minimized_frames": minimized_frames, "paused_frames": paused_frames,
		"static_structure_unchanged": structure_same, "geometry": geometry, "actor_layout_before": actors_before, "actor_layout_after": _actor_layout(), "start_world_status": starting_state, "end_world_status": ending_state, "failures": stage_errors})
	_write_json(_output.path_join("partial-report.json"), {"hardware": _hardware, "stages": _stages, "failures": _failures})
	print("P1_STAGE_COMPLETE ", JSON.stringify({"id": id, "frames": rows.size(), "elapsed_s": float(last_ticks - begin_ticks) / 1_000_000.0, "failures": stage_errors}))


func _capture_motion(stage_id: String) -> void:
	# GPU image readback deliberately occurs outside every performance sample.
	var folder: String = stage_id + "-motion"
	DirAccess.make_dir_recursive_absolute(_output.path_join(folder))
	_write_progress("visual_motion_capture_outside_performance_sample", stage_id)
	var frames: Array[Dictionary] = []
	var began: int = Time.get_ticks_usec()
	var structure_before: String = _structure_signature()
	var start_status: Dictionary = _main.living.get_status()
	var focus_lost: bool = false
	var last_capture: int = -1
	var frame_total: int = maxi(2, ceili(_motion_seconds * _motion_fps) + 1)
	for index: int in frame_total:
		var target: int = began + int(float(index) / _motion_fps * 1_000_000.0)
		while Time.get_ticks_usec() < target:
			await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		focus_lost = focus_lost or not DisplayServer.window_is_focused()
		var now: int = Time.get_ticks_usec()
		var filename: String = folder + "/%04d.png" % index
		var pixels: Image = root.get_texture().get_image()
		if pixels == null or pixels.save_png(_output.path_join(filename)) != OK:
			_failures.append(stage_id + ": motion_frame_capture_failed")
			break
		frames.append({"file": filename, "elapsed_s": float(now - began) / 1_000_000.0, "world_time": _main.living.world_time})
		last_capture = now
	var clip: Dictionary = {"stage_id": stage_id, "room": _main.room, "weather": _weather, "day_phase": _phase,
		"requested_seconds": _motion_seconds, "requested_fps": _motion_fps, "frames": frames,
		"elapsed_seconds": float(last_capture - began) / 1_000_000.0, "focus_lost": focus_lost,
		"static_structure_unchanged": structure_before == _structure_signature(),
		"world_status_before": start_status, "world_status_after": _main.living.get_status(),
		"scope": "native frame sequence for visual review; image readback overhead means this is not performance or continuous video evidence"}
	clip["background_fixture"] = _allow_background
	if focus_lost and not _allow_background: _failures.append(stage_id + ": motion_capture_lost_focus")
	if not bool(clip.static_structure_unchanged): _failures.append(stage_id + ": motion_capture_changed_static_structure")
	_motion_clips.append(clip)
	_write_json(_output.path_join(folder + "/clip.json"), clip)
	print("P1_MOTION_CLIP ", JSON.stringify({"stage_id": stage_id, "frames": frames.size(), "focus_lost": focus_lost}))


func _keep_benchmark_running() -> void:
	# Fixture only: production focus notifications and pause behavior are untouched.
	# Both environment modes use the same override; focus itself is still recorded.
	if not is_instance_valid(_main) or not is_instance_valid(_main.living):
		return
	_main.application_backgrounded = false
	_main.living._focus_backgrounded = false


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--p1-output="): _output = argument.trim_prefix("--p1-output=")
		elif argument.begins_with("--p1-duration="): _duration = argument.trim_prefix("--p1-duration=").to_float()
		elif argument.begins_with("--p1-warmup="): _warmup = argument.trim_prefix("--p1-warmup=").to_float()
		elif argument.begins_with("--p1-repeats="): _repeats = argument.trim_prefix("--p1-repeats=").to_int()
		elif argument.begins_with("--p1-width="): _width = argument.trim_prefix("--p1-width=").to_int()
		elif argument.begins_with("--p1-height="): _height = argument.trim_prefix("--p1-height=").to_int()
		elif argument.begins_with("--p1-rooms="):
			_rooms.clear()
			for room: String in argument.trim_prefix("--p1-rooms=").split(",", false): _rooms.append(room)
		elif argument.begins_with("--p1-weather="): _weather = argument.trim_prefix("--p1-weather=")
		elif argument.begins_with("--p1-day-phase="): _phase = argument.trim_prefix("--p1-day-phase=")
		elif argument.begins_with("--p1-motion-seconds="): _motion_seconds = argument.trim_prefix("--p1-motion-seconds=").to_float()
		elif argument.begins_with("--p1-motion-fps="): _motion_fps = argument.trim_prefix("--p1-motion-fps=").to_float()
		elif argument == "--p1-allow-background": _allow_background = true
		elif argument == "--p1-validate-only": _validate_only = true


func _geometry_summary() -> Dictionary:
	var triangle_count: int = 0
	var mesh_count: int = 0
	var empty_or_non_triangle_meshes: int = 0
	for node: Node in _main.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if not mesh_node.is_visible_in_tree() or mesh_node.mesh == null:
			continue
		mesh_count += 1
		# Mesh.get_faces() works on both imported ArrayMesh and built-in PrimitiveMesh.
		# Its returned vertices are expanded triangle faces, not the GPU monitor.
		var face_vertices: PackedVector3Array = mesh_node.mesh.get_faces()
		triangle_count += face_vertices.size() / 3
		if face_vertices.is_empty():
			empty_or_non_triangle_meshes += 1
	return {"visible_tree_mesh_instances": mesh_count, "scene_mesh_triangles": triangle_count, "empty_or_non_triangle_meshes": empty_or_non_triangle_meshes,
		"scope": "visible-in-tree MeshInstance3D geometry including off-camera meshes; excludes MultiMesh particles and render-pass duplication; not a GPU triangle counter"}


func _actor_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = _main.living._actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Node3D = _main.living._actors[id] as Node3D
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		var state: Dictionary = actor.get_status()
		var transform: Transform3D = actor.global_transform
		result.append({"id": id, "kind": state.get("kind", ""), "action": state.get("action", ""), "visible": actor.is_visible_in_tree(),
			"transform": [transform.basis.x.x, transform.basis.x.y, transform.basis.x.z, transform.basis.y.x, transform.basis.y.y, transform.basis.y.z, transform.basis.z.x, transform.basis.z.y, transform.basis.z.z, transform.origin.x, transform.origin.y, transform.origin.z]})
	return result


func _structure_signature(stable_paths: bool = false) -> String:
	var records: Array[String] = []
	var automatic_name: RegEx = RegEx.new()
	automatic_name.compile("@[0-9]+")
	for node: Node in _main.world.find_children("*", "CollisionShape3D", true, false):
		var path: String = str(_main.world.get_path_to(node))
		if stable_paths: path = automatic_name.sub(path, "", true)
		var collider: CollisionShape3D = node as CollisionShape3D
		var shape_signature: String = "none"
		if collider.shape != null:
			shape_signature = collider.shape.get_class() + ":" + str(collider.shape.get_debug_mesh().get_aabb())
		var body: CollisionObject3D = collider.get_parent() as CollisionObject3D
		var flags: String = str(collider.disabled) + ":" + str(body.collision_layer if body else 0) + ":" + str(body.collision_mask if body else 0)
		records.append(path + ":" + var_to_str(collider.global_transform) + ":" + shape_signature + ":" + flags)
	for node: Node in _main.world.find_children("SG_*", "Node3D", true, false):
		var path: String = str(_main.world.get_path_to(node))
		if stable_paths: path = automatic_name.sub(path, "", true)
		records.append(path + ":" + var_to_str((node as Node3D).global_transform))
	records.sort()
	return "\n".join(records).sha256_text()


func _production_signature() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = "user://island-save-v1.json" + suffix
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result


func _cleanup_validation_save() -> void:
	if not is_instance_valid(_state): return
	var expected: String = "user://validation-%s.json" % OS.get_process_id()
	if str(_state.save_path) != expected: return
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(expected + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(expected + suffix))


func _write_progress(phase: String, stage: String) -> void:
	_write_json(_output.path_join("progress.json"), {"phase": phase, "stage": stage, "pid": OS.get_process_id(), "epoch": Time.get_unix_time_from_system()})


func _write_json(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload, "\t", true, true))
		file.close()
