extends "res://tests/capture_visual_refinement.gd"
## Isolated native A/B evidence; never writes production lighting or materials.

var probe_captures: Array[Dictionary] = []
var frozen_state: Dictionary = {}

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness") or DisplayServer.get_name() == "headless":
		push_error("SSAO probe requires native rendering and -- --test-harness.")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	output_dir = ProjectSettings.globalize_path(probe_root()).path_join(probe_name())
	DirAccess.make_dir_recursive_absolute(output_dir)
	baseline = JSON.parse_string(FileAccess.get_file_as_string(probe_baseline_path()))
	protected_before = production_signature()
	source_before = source_signature()
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
	await game.change_room(probe_room())
	check(await wait_for_room(probe_room()), "target_room_ready")
	game._close()
	game.living.set_day_phase("day", true)
	game.living.set_weather("clear", true)
	game.living.set_context({"fixed_day":true, "fixed_weather":true, "reduced_motion":true})
	await frames(30)
	if not probe_camera_id().ends_with("-production"):
		game.capturing_photo = true
		game.ui.hide()
		apply_camera(baseline_capture(probe_camera_id()).camera)
	else:
		game.ui.toast_timer = 0
		game.ui.toast_label.hide()
		game.ui.bubble_panel.hide()
	await frames(6)
	check(cameras_match(baseline_capture(probe_camera_id()).camera, camera_record()), "camera_matches_original_baseline")
	freeze_subtree(game)
	var environment: Environment = game.living._environment
	var sun: DirectionalLight3D = game.living._sun
	frozen_state = {"camera":camera_record(), "world_time":game.living.world_time, "game_process_mode":game.process_mode,
		"radius":environment.ssao_radius, "power":environment.ssao_power, "detail":environment.ssao_detail,
		"light_affect":environment.ssao_light_affect, "shadow_enabled":sun.shadow_enabled, "shadow_bias":sun.shadow_bias,
		"shadow_normal_bias":sun.shadow_normal_bias, "shadow_mode":sun.directional_shadow_mode,
		"camera_id":probe_camera_id(), "room":probe_room(), "frozen_scope":"Entire game node subtree processing disabled after fixed day, clear weather and reduced motion at recorded camera. SceneTree renderer remains active."}
	for variant: Dictionary in probe_variants():
		environment.ssao_enabled = variant.enabled
		environment.ssao_intensity = variant.intensity
		sun.shadow_enabled = bool(variant.get("shadow_enabled", frozen_state.shadow_enabled))
		sun.shadow_bias = float(variant.get("shadow_bias", frozen_state.shadow_bias))
		sun.shadow_normal_bias = float(variant.get("shadow_normal_bias", frozen_state.shadow_normal_bias))
		sun.directional_shadow_mode = int(variant.get("shadow_mode", frozen_state.shadow_mode))
		await frames(12)
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var path := output_dir.path_join(probe_camera_id() + "-" + str(variant.id) + ".png")
		check(picture.save_png(path) == OK, "saved/" + str(variant.id))
		check(cameras_match(frozen_state.camera, camera_record()), "camera_frozen/" + str(variant.id))
		check(float(game.living.world_time) == float(frozen_state.world_time), "world_clock_frozen/" + str(variant.id))
		probe_captures.append({"id":variant.id, "image":path, "enabled":environment.ssao_enabled, "intensity":environment.ssao_intensity,
			"camera":camera_record(), "world_time":game.living.world_time, "image_sha256":FileAccess.get_sha256(path),
			"shadow_enabled":sun.shadow_enabled, "shadow_bias":sun.shadow_bias, "shadow_normal_bias":sun.shadow_normal_bias,
			"shadow_mode":sun.directional_shadow_mode})
		print("SSAO_PROBE_CAPTURE " + str(variant.id))
		if probe_measures_performance():
			await sample_performance(probe_room())
			performance_samples[-1]["variant"] = variant.id
	await finish()

func probe_name() -> String:
	return "ssao-probe"

func probe_root() -> String:
	return OUTPUT_ROOT

func probe_baseline_path() -> String:
	return OUTPUT_ROOT + "/before/report.json"

func probe_room() -> String:
	return "home"

func probe_camera_id() -> String:
	return "home-detail"

func probe_measures_performance() -> bool:
	return false

func probe_variants() -> Array[Dictionary]:
	return [
		{"id":"on-1.15-a", "enabled":true, "intensity":1.15},
		{"id":"on-1.15-b", "enabled":true, "intensity":1.15},
		{"id":"off", "enabled":false, "intensity":1.15},
		{"id":"on-0.5", "enabled":true, "intensity":0.5}
	]

func freeze_subtree(node: Node) -> void:
	# LivingWorld/actors can explicitly use ALWAYS, overriding a disabled parent.
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		freeze_subtree(child)

func finish() -> void:
	if finishing:
		return
	finishing = true
	check(protected_before == production_signature(), "production_files_unchanged")
	check(source_before == source_signature(), "production_sources_unchanged")
	check(probe_captures.size() == probe_variants().size(), "all_variants_captured", probe_captures.size())
	if probe_measures_performance():
		check(performance_samples.size() == probe_variants().size(), "performance_sampled_all_variants")
	var failures := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var report := {"result":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "captures":probe_captures,
		"renderer":RenderingServer.get_current_rendering_method(), "display_server":DisplayServer.get_name(), "frozen_state":frozen_state,
		"production_before":protected_before, "production_after":production_signature(), "source_sha256":source_before, "isolated_save":save_path,
		"performance_samples":performance_samples, "engine_arguments":OS.get_cmdline_args()}
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
	print("SSAO_PROBE_RESULT " + JSON.stringify({"checks":checks.size(), "failures":failures.size(), "captures":probe_captures.size()}))
	quit(0 if failures.is_empty() else 1)
