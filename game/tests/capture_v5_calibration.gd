extends SceneTree
## Native RTX 4070 1440x900 Visual Proof Capture for V5 Content & Memory Palace Overhaul.
## Run (graphical, NOT --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path game --script res://tests/capture_v5_calibration.gd -- --test-harness

const StoryContent = preload("res://ui/memory_story_content.gd")

var _main: Node3D
var _out_dir := "f:/LoveStudy/docs/screenshots/v4-showcase"

func _initialize() -> void:
	_run.call_deferred()

func _wait_frames(count: int = 10) -> void:
	for _i in range(count):
		await process_frame

func _wait_seconds(sec: float) -> void:
	await create_timer(sec).timeout
	await _wait_frames(4)

func _wait_room(target_room: String) -> void:
	for _i in range(300):
		await process_frame
		if is_instance_valid(_main) and not _main.loading_room and _main.room == target_room:
			break
	await _wait_seconds(0.55)

func _snap(filename: String) -> void:
	if is_instance_valid(_main) and is_instance_valid(_main.ui) and _main.ui.get("toast_label") != null:
		_main.ui.toast_timer = 0.0
		(_main.ui.toast_label as Control).hide()
	await _wait_frames(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and not img.is_empty():
		var full := _out_dir + "/" + filename
		img.save_png(full)
		print("SAVED_PROOF: ", full, " (", img.get_width(), "x", img.get_height(), ")")

func _find_entry_by_word(word: String) -> Dictionary:
	for hit: Dictionary in StoryContent.list_entries("", "", word):
		if str(hit.get("spelling_display", "")) == word:
			return StoryContent.get_entry(str(hit.entry_id))
	return {}

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

	# Proof 01: Living Room `门厅随身篮` (`SG_MEMORY_01`) — directly replaces `Come in, please.`!
	await _main.change_room("home")
	await _wait_room("home")
	_main.show_memory(1)
	await _wait_seconds(0.35)
	var hint_btn := _main.ui.panel_box.find_child("ChineseHint", true, false) as Button
	if hint_btn != null:
		hint_btn.button_pressed = true
		hint_btn.pressed.emit()
	await _wait_seconds(0.25)
	await _snap("v5_proof_01_living_room_basket.png")
	_main._close()
	await _wait_frames(8)

	# Proof 02: Science Room `磁铁实验台` (`SG_MEMORY_04`) — eliminates blank-source duplicate `Look at the plant.`!
	await _main.change_room("science_room")
	await _wait_room("science_room")
	_main.show_memory(4)
	await _wait_seconds(0.35)
	var hint_btn2 := _main.ui.panel_box.find_child("ChineseHint", true, false) as Button
	if hint_btn2 != null:
		hint_btn2.button_pressed = true
		hint_btn2.pressed.emit()
	await _wait_seconds(0.25)
	await _snap("v5_proof_02_science_magnet_table.png")
	_main._close()
	await _wait_frames(8)

	# Proof 03 & 04: `amazing` in 3D `PopupBookTheater` (Beat 1 & Beat 2) — directly replaces arrow template & missing N!
	await _main.change_room("landmark_X")
	await _wait_room("landmark_X")
	var amazing := _find_entry_by_word("amazing")
	if not amazing.is_empty():
		_main.journey.open_story_from_world(str(amazing.entry_id))
		await _wait_seconds(0.85)
		await _snap("v5_proof_03_amazing_palace_beat1.png")
		if is_instance_valid(_main.journey.current_memory):
			_main.journey.current_memory.navigate_beat(1)
			await _wait_seconds(0.55)
			await _snap("v5_proof_04_amazing_palace_beat2.png")
		_main._close()
		await _wait_frames(8)

	# Proof 05: `umbrella` in 3D `PopupBookTheater` H3 Gap-Recall Mode (`小提示` -> `【？神秘精灵】`)
	await _main.change_room("landmark_U")
	await _wait_room("landmark_U")
	var umbrella := _find_entry_by_word("umbrella")
	if not umbrella.is_empty():
		_main.journey.open_story_from_world(str(umbrella.entry_id))
		await _wait_seconds(0.85)
		if is_instance_valid(_main.journey.current_memory):
			_main.journey.current_memory._on_gentle_hint()
			await _wait_seconds(0.45)
			await _snap("v5_proof_05_umbrella_gap_recall.png")
		_main._close()
		await _wait_frames(8)

	var abs_save := ProjectSettings.globalize_path(str(state.save_path))
	if abs_save.contains("validation-"):
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(abs_save + suffix):
				DirAccess.remove_absolute(abs_save + suffix)

	_main.queue_free()
	await _wait_frames(4)
	quit(0)
