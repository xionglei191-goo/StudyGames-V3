extends SceneTree
## Real Vulkan GPU 1440x900 Close-Up Visual Proof Capture for Blender 5.2 Layer-2 GLB Props.
## Run (graphical, NOT --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path game --script res://tests/capture_layer2_blender_showcase.gd -- --test-harness

var _main: Node3D
var _out_dir := "C:/Users/Administrator/.gemini/antigravity/brain/db322f3e-9594-4cdb-af2e-9a87ef01d9d2"

func _initialize() -> void:
	_run.call_deferred()

func _wait_frames(count: int = 10) -> void:
	for _i: int in range(count):
		await process_frame

func _wait_seconds(sec: float) -> void:
	await create_timer(sec).timeout
	await _wait_frames(6)

func _wait_room(target_room: String) -> void:
	for _i: int in range(300):
		await process_frame
		if is_instance_valid(_main) and not _main.loading_room and _main.room == target_room:
			break
	await _wait_seconds(0.55)

func _snap(filename: String) -> void:
	if is_instance_valid(_main) and is_instance_valid(_main.ui):
		if _main.ui.get("toast_label") != null:
			_main.ui.toast_timer = 0.0
			(_main.ui.toast_label as Control).hide()
		if _main.ui.get("hud") != null and _main.ui.hud.get("level_banner") != null:
			(_main.ui.hud.level_banner as Control).hide()
	await _wait_frames(10)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and not img.is_empty():
		var full := _out_dir + "/" + filename
		img.save_png(full)
		print("SAVED_L2_PROOF: ", full, " (", img.get_width(), "x", img.get_height(), ")")

func _capture_anchor(room_id: String, anchor_order: int, pick_word: String, out_name: String) -> void:
	if _main.room != room_id:
		await _main.change_room(room_id)
		await _wait_room(room_id)
	_main.spatial_bench.open_workbench(_main, room_id, pick_word, anchor_order)
	await _wait_seconds(0.95)
	if not pick_word.is_empty():
		_main.spatial_bench.select_bench_item(pick_word, false)
		await _wait_seconds(0.20)
	await _snap(out_name)
	_main.spatial_bench.close_workbench()
	await _wait_frames(10)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)
	AudioServer.set_bus_mute(0, true)

	_main = load("res://main.tscn").instantiate() as Node3D
	_main.muted = true
	root.add_child(_main)
	current_scene = _main
	await _wait_room("village")

	var state: Node = root.get_node("State")
	state.set_preference("fixed_day", true)

	await _capture_anchor("home_bathroom", 2, "soap", "l2_proof_01_bathroom_washbasin.png")
	await _capture_anchor("home_bedroom", 3, "coat", "l2_proof_02_bedroom_wardrobe.png")
	await _capture_anchor("home_study", 1, "pencil", "l2_proof_03_study_desk.png")
	await _capture_anchor("canteen", 3, "hamburger", "l2_proof_04_canteen_window.png")
	await _capture_anchor("music_room", 4, "guitar", "l2_proof_05_music_rack.png")
	await _capture_anchor("science_room", 5, "globe", "l2_proof_06_science_shelf.png")

	quit(0)
