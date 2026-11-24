extends SceneTree
## Native RTX 4070 1440x900 Visual Proof Capture for V8 Tactile Drag, Speech & Ebbinghaus Errands.
## Run (graphical, NOT --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path game --script res://tests/capture_v8_showcase.gd -- --test-harness

var _main: Node3D
var _out_dir := "C:/Users/Administrator/.gemini/antigravity/brain/db322f3e-9594-4cdb-af2e-9a87ef01d9d2"


func _initialize() -> void:
	_run.call_deferred()


func _wait_frames(count: int = 10) -> void:
	for _i in range(count):
		await process_frame


func _wait_seconds(sec: float) -> void:
	await create_timer(sec).timeout
	await _wait_frames(6)


func _wait_room(target_room: String) -> void:
	for _i in range(300):
		await process_frame
		if is_instance_valid(_main) and not _main.loading_room and _main.room == target_room:
			break
	await _wait_seconds(0.55)


func _snap(filename: String, hide_toast: bool = true) -> void:
	if hide_toast and is_instance_valid(_main) and is_instance_valid(_main.ui):
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
		print("SAVED_V8_PROOF: ", full, " (", img.get_width(), "x", img.get_height(), ")")


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
	state.data = state._default_state()
	state.set_preference("fixed_day", true)
	_main.validation_mode = false

	# Proof 01: Study Desk (`home_study`, #1) — Multi-step 1/3 Tidy-Up + Glowing Green Drop Halo + Mic Follow-Along Dock
	await _main.change_room("home_study")
	await _wait_room("home_study")
	_main.spatial_bench.open_workbench(_main, "home_study", "pen", 1)
	await _wait_seconds(0.85)
	_main.spatial_bench.select_bench_item("pen", true, false)
	await _wait_seconds(0.25)
	await _snap("v8_proof_01_tactile_drag_and_follow_dock.png")
	_main.spatial_bench.close_workbench()
	await _wait_frames(8)

	# Proof 02: Bathroom Washbasin (`home_bathroom`, #2) — Step 1/3 placed -> Step 2/3 active + Speech Star lit on `soap`
	await _main.change_room("home_bathroom")
	await _wait_room("home_bathroom")
	_main.spatial_bench.open_workbench(_main, "home_bathroom", "soap", 2)
	await _wait_seconds(0.85)
	_main.spatial_bench.drag_item_to_target("soap")
	await _wait_seconds(0.35)
	_main.spatial_bench.select_bench_item("soap", false, false)
	_main.spatial_bench._apply_follow_along_result("soap", false, {
		"ok": true,
		"match_tier": "exact",
		"cheer_badge": "闪耀发音星",
		"reply_zh": "听到了清晰的「soap」！点亮专属发音星！",
	})
	for extra_w: String in ["water", "towel", "cup"]:
		state.v8_record_word_exposure(extra_w, "物", "home_bathroom", 2, 1000)
	state.v8_record_spoken("coat", 3, true, "外套", "home_bedroom", 3, 1000)
	state.v8_start_errand({
		"domain": "home",
		"giver_npc_id": "textbook_role_lingling_mother",
		"giver_name": "妈妈 · Mom",
		"targets": [{"word": "pen", "zh": "钢笔", "room_id": "home_study", "room_zh": "窗边书房", "anchor_order": 1, "anchor_zh": "书桌", "found": false, "hint_tier": 0}],
	})
	for _s: int in range(4):
		state.v8_complete_errand_target("pen", 2000 + _s * 100)
		state.v8_start_errand({
			"domain": "home",
			"giver_npc_id": "textbook_role_lingling_mother",
			"giver_name": "妈妈 · Mom",
			"targets": [{"word": "pen", "zh": "钢笔", "room_id": "home_study", "room_zh": "窗边书房", "anchor_order": 1, "anchor_zh": "书桌", "found": false, "hint_tier": 0}],
		})
	state.data["v8_memory"]["active_errand"] = {}
	await _wait_seconds(0.25)
	await _snap("v8_proof_02_speech_star_feedback.png")
	_main.spatial_bench.close_workbench()
	await _wait_frames(8)

	# Hop rooms (`home_bedroom` -> `home`) so Ebbinghaus short-interval words become due & Mom gets Golden Badge!
	await _main.change_room("home_bedroom")
	await _wait_room("home_bedroom")
	await _main.change_room("home")
	await _wait_room("home")
	_main.errand_director.refresh_visuals()
	await _wait_seconds(0.35)

	# Proof 03: Mom in Living Room with Golden Errand Badge + Errand Dialogue Offer
	_main.interact_id("actor:textbook_role_lingling_mother")
	await _wait_seconds(0.45)
	await _snap("v8_proof_03_npc_errand_badge_and_dialogue.png")
	_main._close()
	await _wait_frames(8)

	# Proof 04: Accept Errand -> Right-Side Sticky Note + Open Target Furniture in Tier-0 Pure 3D Blind Recall (`★ ？`)
	await _main._on_action("v8_accept_errand:home:textbook_role_lingling_mother")
	await _wait_seconds(0.30)
	await _main._on_action("v8_errand_go")
	await _wait_seconds(0.90)
	await _snap("v8_proof_04_sticky_note_and_tier0_blind_recall.png")
	_main.spatial_bench.close_workbench()
	await _wait_frames(8)

	# Proof 05: 16-Room 3D Spatial Memory Almanac (`v8_almanac`) with Live Rotating 3D .glb Turntable
	await _main._on_action("v8_almanac_pick:home_bathroom:soap")
	await _wait_seconds(0.65)
	await _snap("v8_proof_05_3d_spatial_almanac_turntable.png")
	_main._close()
	await _wait_frames(8)

	# Proof 06: Parent AI Observatory (`v4_parent_ai`) with V8 Ebbinghaus Retention Pill & Narrative
	await _main._on_action("v4_parent_ai")
	await _wait_seconds(0.65)
	await _snap("v8_proof_06_parent_portal_v8_retention.png")
	_main._close()
	await _wait_frames(6)

	quit(0)
