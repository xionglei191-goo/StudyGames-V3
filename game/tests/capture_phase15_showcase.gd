extends SceneTree
## Native RTX 4070 1440x900 Screenshot Showcase for Phase 15 (`capture_phase15_showcase.gd`).
## Captures 5 crisp visual proof PNGs into the conversation artifact directory and cleans up isolated save files.

const PalaceLoci = preload("res://gameplay/memory_palace_loci_3d.gd")

const OUT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/db322f3e-9594-4cdb-af2e-9a87ef01d9d2"

func _initialize() -> void:
	_run.call_deferred()

func _wait_frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _clear_toast(game: Node3D) -> void:
	game.ui.toast_timer = 0.0
	if is_instance_valid(game.ui.toast_label):
		game.ui.toast_label.hide()

func _snap(filename: String) -> void:
	await _wait_frames(22)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var full_path := OUT_DIR.path_join(filename)
	img.save_png(full_path)
	print("CAPTURED: ", full_path, " size=", img.get_size())

func _find_entry_for_room_theme(room_prefix: String) -> String:
	for it: Dictionary in PalaceLoci.all_palace_items():
		var rid := str(it.get("palace_room_id", ""))
		var w := str(it.get("word", ""))
		if rid == room_prefix and w.length() >= 4 and w.length() <= 7 and not w.contains(" "):
			var eid := str(it.get("entry_id", "")).strip_edges()
			if not eid.is_empty():
				return eid
	return "occ-5605ac34c5f2"

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)

	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for _f in range(600):
		await process_frame
		if game.scene_ready:
			break

	var state: Node = root.get_node("State")
	state.data = state._default_state()
	game.muted = true
	game.validation_mode = false

	# Seed illuminated words & one fragile word for rich visual context
	state.record_stealth_evidence({"word": "good", "support_level": 0, "correct": true, "context": "showcase"})
	state.record_stealth_evidence({"word": "teacher", "support_level": 0, "correct": true, "context": "showcase"})
	state.record_stealth_evidence({"word": "book", "support_level": 0, "correct": true, "context": "showcase"})
	state.record_stealth_evidence({"word": "umbrella", "support_level": 3, "correct": false, "context": "showcase"})

	# 1. 3D Room Memory Palace Shrine + Diegetic Spatial Corner Tour inside `classroom`
	await game.change_room("classroom")
	await _wait_frames(15)
	if is_instance_valid(game.palace_loci) and game.palace_loci.has_shrine:
		var sp: Vector3 = game.palace_loci.shrine_pos
		game.player.position = sp + Vector3(-1.35, 0.0, 0.95)
		game.player.velocity = Vector3.ZERO
		game.player.face(sp)
	await _wait_frames(15)
	_clear_toast(game)
	game.palace_loci.open_room_palace_tour(0)
	await _snap("v5_phase15_01_room_palace_shrine.png")
	game._close()

	# 2. PopupBookTheater with 3D Stage Curtain Scenery (`landmark_X`) + `讲故事` & `跟读`
	await game.change_room("landmark_X")
	await _wait_frames(12)
	_clear_toast(game)
	var stage_eid := _find_entry_for_room_theme("landmark_X")
	game.journey.open_story_from_world(stage_eid)
	await _wait_frames(38)
	await _snap("v5_phase15_02_popup_stage_scenery.png")
	game._close()

	# 3. Multi-Turn Situational Roleplay Dialogue (`bakery` in `landmark_C`)
	await game.change_room("landmark_C")
	await _wait_frames(15)
	for entry: Dictionary in game.interactions:
		if str(entry.get("id", "")) in ["baker", "host"]:
			var bp: Vector3 = entry.position
			game.player.position = bp + Vector3(-0.95, 0.0, 1.35)
			game.player.velocity = Vector3.ZERO
			game.player.face(bp)
			game.conversation_position = bp
			break
	await _wait_frames(15)
	_clear_toast(game)
	await game._on_action("v5_roleplay_start:bakery")
	_clear_toast(game)
	await _snap("v5_phase15_03_situational_roleplay.png")
	game._close()

	# 4. Morning Memory Wake-Up Mailbox (`v5_wake_mailbox`) in front yard (`home_estate`)
	await game.change_room("home_estate")
	await _wait_frames(15)
	if is_instance_valid(game.tactile_quests) and game.tactile_quests.has_method("drop_held_item"):
		game.tactile_quests.drop_held_item()
	_clear_toast(game)
	for entry: Dictionary in game.interactions:
		if str(entry.get("id", "")) == "memory_01":
			var mp: Vector3 = entry.position
			game.player.position = mp + Vector3(0.95, 0.0, 1.05)
			game.player.velocity = Vector3.ZERO
			game.player.face(mp)
			break
	await _wait_frames(12)
	_clear_toast(game)
	await game._on_action("v5_wake_mailbox")
	await _snap("v5_phase15_04_morning_wake_mailbox.png")
	game._close()

	# 5. Bilingual Science Studio (`Yellow + Blue = Green` + tactile keycap bottles)
	await game.change_room("science_room")
	await _wait_frames(12)
	_clear_toast(game)
	game.start_activity("science")
	await _wait_frames(6)
	var sboard: Node = game.ui.activity_board
	if is_instance_valid(sboard):
		sboard.choose_pigment(1)
		sboard.choose_pigment(2)
		sboard.mix()
	_clear_toast(game)
	await _snap("v5_phase15_05_bilingual_science_studio.png")
	game._close()

	# Clean up isolated validation save files
	for suffix: String in ["", ".bak", ".tmp"]:
		var p: String = str(state.save_path) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	quit(0)
