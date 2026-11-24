extends SceneTree
## Native RTX 4070 1440x900 Visual Proof Capture for V9 Warm Voices, Animal Soundbank & Zero-Overlap Labels.
## Run (graphical Vulkan, NOT --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path game --script res://tests/capture_v9_voice_showcase.gd -- --test-harness
##   (Pass `--clean-only` after `--` to capture the 4 V9 label de-overlap proof screenshots.)

const CastDirector = preload("res://gameplay/home_school_cast_director.gd")

var _main: Node3D
var _out_dirs := [
	"C:/Users/Administrator/.gemini/antigravity/brain/f7e0d45e-82d7-4d32-8b0c-18b556481f15",
	"C:/Users/Administrator/.gemini/antigravity/brain/db322f3e-9594-4cdb-af2e-9a87ef01d9d2",
]


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
	await _wait_frames(12)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and not img.is_empty():
		for dir_path: String in _out_dirs:
			DirAccess.make_dir_recursive_absolute(dir_path)
			var full := dir_path + "/" + filename
			img.save_png(full)
			print("SAVED_V9_PROOF: ", full, " (", img.get_width(), "x", img.get_height(), ")")


func _place_player_near(actor: Node3D, offset: Vector3) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(_main) or not is_instance_valid(_main.player):
		return
	var target := actor.position + offset
	target.y = _main.player.position.y
	_main.player.path.clear()
	_main.player.position = target
	_main.player.face(actor.position)
	if actor.has_method("face"):
		actor.face(_main.player.position)


func _run() -> void:
	var watchdog := Timer.new()
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func():
		push_error("V9 capture timed out")
		quit(1)
	)
	watchdog.start(150.0)

	var clean_only := OS.get_cmdline_user_args().has("--clean-only")
	var prop_only := OS.get_cmdline_user_args().has("--prop-only")
	var porch_only := OS.get_cmdline_user_args().has("--porch-only")

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
	_main.ai_bridge.muted = true

	if porch_only:
		await _capture_porch_and_43room_proofs(state)
		quit(0)
		return

	if prop_only:
		await _capture_prop_depenetration_proofs()
		quit(0)
		return

	if not clean_only:
		await _capture_voice_proofs()
	await _capture_label_deoverlap_proofs(state)

	quit(0)


func _capture_voice_proofs() -> void:
	await _main.change_room("home")
	await _wait_room("home")
	_main.ai_bridge.set_speech_speed_mode("natural")
	var kitty: Node3D = _main.living.get_actor("textbook_kitty") as Node3D
	if is_instance_valid(kitty):
		_place_player_near(kitty, Vector3(-1.35, 0.0, 1.05))
		_main.conversation_position = kitty.position
	await _wait_seconds(0.35)
	_main.interact_id("actor:textbook_kitty")
	await _wait_seconds(0.35)
	if not _main.ui.diegetic.zh_visible:
		_main.ui.diegetic._hint_btn.pressed.emit()
	await _wait_seconds(0.25)
	await _snap("v9_proof_01_kitty_animal_voice_dialogue.png")
	_main._close()
	await _wait_frames(8)

	var mom: Node3D = _main.living.get_actor("textbook_role_lingling_mother") as Node3D
	if is_instance_valid(mom):
		_place_player_near(mom, Vector3(1.35, 0.0, 1.05))
		_main.conversation_position = mom.position
	await _wait_seconds(0.35)
	_main.interact_id("actor:textbook_role_lingling_mother")
	await _wait_seconds(0.30)
	if _main.ai_bridge.speech_speed_mode != "slow":
		_main.ui.diegetic._speed_btn.pressed.emit()
	if not _main.ui.diegetic.zh_visible:
		_main.ui.diegetic._hint_btn.pressed.emit()
	await _wait_seconds(0.30)
	await _snap("v9_proof_02_mom_affectionate_slow_mode.png")
	_main._close()
	await _wait_frames(8)

	await _main.change_room("home_study")
	await _wait_room("home_study")
	_main.ai_bridge.set_speech_speed_mode("natural")
	_main.spatial_bench.open_workbench(_main, "home_study", "pen", 1)
	await _wait_seconds(0.85)
	_main.spatial_bench.select_bench_item("pen", false, false)
	await _wait_seconds(0.20)
	_main.spatial_bench._speed_mode_btn.pressed.emit()
	await _wait_seconds(0.35)
	await _snap("v9_proof_03_bench_slow_follow_toggle.png")
	_main.spatial_bench.close_workbench()
	await _wait_frames(8)

	await _main.change_room("classroom")
	await _wait_room("classroom")
	_main.ai_bridge.set_speech_speed_mode("natural")
	var dino_pos: Vector3 = (_main.player.position as Vector3) + Vector3(1.55, 0.0, -0.55)
	var dino: Node3D = _main.living.spawn_actor("textbook_dino", dino_pos, {
		"display_name": "小恐龙 · Dino",
		"validate_position": false,
	}) as Node3D
	_main.living.refresh_interactions(_main.interactions)
	if is_instance_valid(dino):
		_place_player_near(dino, Vector3(-1.45, 0.0, 0.85))
		_main.conversation_position = dino.position
		_main.living.play_actor_action("textbook_dino", "wave")
	await _wait_seconds(0.35)
	var dino_conv := CastDirector.build_actor_conversation(_main, "textbook_dino", "classroom", _main.conversation_position)
	dino_conv["npc_id"] = "textbook_dino"
	dino_conv["speaker"] = "小恐龙 Dino · 奇幻伙伴"
	dino_conv["en"] = "Hello, friend! Let's count bright stars and read English words together!"
	dino_conv["zh"] = "嗨好朋友！先听小恐龙欢快叫一声，再用奇幻小恐龙音陪你慢慢读英语吧！"
	dino_conv["show_zh_immediately"] = true
	_main.ui.diegetic.open_conversation(dino_conv)
	await _wait_seconds(0.35)
	await _snap("v9_proof_04_dino_mascot_voice.png")
	_main._close()
	await _wait_frames(6)


func _capture_label_deoverlap_proofs(state: Node) -> void:
	# Seed 5 due V8 words + 2 room hops so Mom's unified `◈ 温故寻物委托 + 妈妈 · Mom` header activates in `home`!
	state.data = state._default_state()
	state.set_preference("fixed_day", true)
	state.v8_record_room_visit("home_bathroom")
	state.v8_record_word_exposure("soap", "香皂", "home_bathroom", 2, 1000)
	state.v8_record_word_exposure("towel", "擦手巾", "home_bathroom", 2, 1005)
	state.v8_record_word_exposure("coat", "外套", "home_bedroom", 3, 1010)
	state.v8_record_word_exposure("pen", "钢笔", "home_study", 1, 1015)
	state.v8_record_word_exposure("globe", "地球仪", "home_study", 2, 1020)

	await _main.change_room("home_bedroom")
	await _wait_room("home_bedroom")
	await _main.change_room("home")
	await _wait_room("home")
	_main.errand_director.refresh_visuals()

	# Clean 01: Living room overview with Mom's unified `◈ 温故寻物委托 / 妈妈 · Mom` header, Kitty, 5 plaques & Memory Palace badge
	_main.greeting_clock = 20.0
	_main.ui.bubble_panel.hide()
	_main.ui.hide_interaction_prompts()
	var mom: Node3D = _main.living.get_actor("textbook_role_lingling_mother") as Node3D
	if is_instance_valid(mom):
		_main.player.path.clear()
		_main.player.position = Vector3(2.4, _main.player.position.y, 4.2)
		_main.player.face(mom.position)
	await _wait_seconds(0.45)
	_main.ui.bubble_panel.hide()
	_main.ui.hide_interaction_prompts()
	if _main.get("world_label_layout") != null:
		_main.world_label_layout.solve_now(0.016, true)
	await _snap("v9_clean_01_mom_errand_overhead_no_overlap.png")

	# Clean 03: Open dialogue in Living Room -> ZERO background 3D labels bleeding behind the speech bubble!
	var kitty: Node3D = _main.living.get_actor("textbook_kitty") as Node3D
	if is_instance_valid(kitty):
		_place_player_near(kitty, Vector3(-1.35, 0.0, 1.05))
		_main.conversation_position = kitty.position
	await _wait_seconds(0.30)
	_main.interact_id("actor:textbook_kitty")
	await _wait_seconds(0.35)
	if not _main.ui.diegetic.zh_visible:
		_main.ui.diegetic._hint_btn.pressed.emit()
	await _wait_seconds(0.25)
	await _snap("v9_clean_03_dialogue_hides_bg_labels.png")
	_main._close()
	await _wait_frames(10)

	# Clean 04: Player standing right next to Kitty with `[E]` prompt + proximity speech bubble + room 3D labels active!
	if is_instance_valid(kitty):
		_place_player_near(kitty, Vector3(-0.95, 0.0, 0.72))
		await _wait_seconds(0.35)
		_main.bubble_world_position = kitty.global_position + Vector3(0.0, 1.85, 0.0)
		var sp: Vector2 = _main.camera.unproject_position(_main.bubble_world_position)
		_main.ui.say("Meow! Kitty is resting on the soft warm sofa!", "喵～小猫正窝在柔软温暖的沙发上休息呢！", sp)
		_main.greeting_clock = 15.0
	await _wait_frames(8)
	if _main.get("world_label_layout") != null:
		_main.world_label_layout.solve_now(0.016, true)
	await _snap("v9_clean_04_proximity_prompt_and_bubble.png")
	_main.ui.bubble_panel.hide()
	_main.ui.hide_interaction_prompts()

	# Clean 02: Crowded Classroom overview (Miss Li, Dino, Amy, Mingming, Tim, 5 furniture plaques & shrine)
	await _main.change_room("classroom")
	await _wait_room("classroom")
	_main.greeting_clock = 20.0
	_main.ui.bubble_panel.hide()
	_main.ui.hide_interaction_prompts()
	_main.player.path.clear()
	_main.player.position = Vector3(2.6, _main.player.position.y, 2.8)
	var dino_p: Vector3 = Vector3(-0.3, _main.player.position.y, 3.9)
	_main.living.spawn_actor("textbook_dino", dino_p, {
		"display_name": "小恐龙 · Dino",
		"validate_position": false,
	})
	_main.living.refresh_interactions(_main.interactions)
	_main.player.face(dino_p)
	await _wait_seconds(0.45)
	_main.ui.bubble_panel.hide()
	_main.ui.hide_interaction_prompts()
	if _main.get("world_label_layout") != null:
		_main.world_label_layout.solve_now(0.016, true)
	await _snap("v9_clean_02_classroom_crowded_labels_clean.png")


func _snap_closeup(filename: String, focus: Vector3, cam_offset: Vector3, ortho_size: float, show_pills: bool = true) -> void:
	_main.greeting_clock = 25.0
	_main.ui.bubble_panel.hide()
	_main.ui.hide_interaction_prompts()
	if _main.ui.get("toast_label") != null:
		_main.ui.toast_timer = 0.0
		(_main.ui.toast_label as Control).hide()
	await _wait_frames(10)
	var cam: Camera3D = _main.camera as Camera3D
	cam.position = focus + cam_offset
	cam.look_at(focus, Vector3.UP)
	cam.size = ortho_size
	if _main.get("world_label_layout") != null:
		if show_pills:
			_main.world_label_layout.solve_now(0.016, true)
		else:
			_main.world_label_layout._hide_overlay_pills()
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and not img.is_empty():
		for dir_path: String in _out_dirs:
			DirAccess.make_dir_recursive_absolute(dir_path)
			var full := dir_path + "/" + filename
			img.save_png(full)
			print("SAVED_V9_PROP_PROOF: ", full, " (", img.get_width(), "x", img.get_height(), ")")


func _capture_prop_depenetration_proofs() -> void:
	# 1 & 2. `home_estate`: Courtyard `Welcome_Letter_Table` + `Welcome_Parcel_Basket` close-up & overview
	await _main.change_room("home_estate")
	await _wait_room("home_estate")
	_main.player.path.clear()
	_main.player.position = Vector3(-4.2, _main.player.position.y, 10.6)
	await _wait_seconds(0.40)

	# Close-up of Welcome_Letter_Table + Welcome_Parcel_Basket from courtyard isometric angle
	await _snap_closeup(
		"v9_prop_01_courtyard_basket_closeup.png",
		Vector3(-9.35, 0.48, 11.85),
		Vector3(14.0, 17.5, 19.0),
		5.2,
		false
	)

	# Courtyard overview showing mail corner, Porch_Geranium clear of flower box, Doggie & crisp 2D pills
	await _snap_closeup(
		"v9_prop_02_courtyard_overview.png",
		Vector3(-4.5, 0.65, 10.0),
		Vector3(18.0, 25.0, 24.0),
		17.5,
		true
	)

	# 3. `home_balcony`: `OWN07_Watering_can` cleanly on floor clear of `Balcony_Plants_Box` & `Window_Cleaning_Stand`
	await _main.change_room("home_balcony")
	await _wait_room("home_balcony")
	_main.player.path.clear()
	_main.player.position = Vector3(-1.4, _main.player.position.y, -2.0)
	await _wait_seconds(0.35)
	await _snap_closeup(
		"v9_prop_03_balcony_watering_can_clean.png",
		Vector3(1.55, 0.55, -3.55),
		Vector3(12.0, 16.5, 16.5),
		5.8,
		true
	)

	# 4. `canteen`: `Back_Greenery` pot & herbs cleanly clear of `Kitchen_Back_Counter`
	await _main.change_room("canteen")
	await _wait_room("canteen")
	_main.player.path.clear()
	_main.player.position = Vector3(2.5, _main.player.position.y, -2.2)
	await _wait_seconds(0.35)
	await _snap_closeup(
		"v9_prop_04_canteen_greenery_clean.png",
		Vector3(5.85, 0.70, -5.55),
		Vector3(12.0, 16.5, 16.5),
		6.4,
		true
	)


func _mesh_center_in_world(pattern: String, fallback: Vector3) -> Vector3:
	if not is_instance_valid(_main) or not is_instance_valid(_main.get("world")):
		return fallback
	for n: Node in _main.world.find_children(pattern, "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null and not str(mi.name).begins_with("SG_"):
			return mi.global_transform * mi.get_aabb().get_center()
	return fallback


func _capture_porch_and_43room_proofs(state: Node) -> void:
	if not (state.data.get("v4") is Dictionary):
		state.data["v4"] = {}
	state.data["v4"]["landmark_crafts"] = {
		"home_estate": 4,
		"school": 4,
		"landmark_A": 4,
	}

	# 1. `home_estate`: Porch_Ready_Basket + Porch_Timber_Column + Porch_Column_Foot + Main_Front wall + CozyCraftStation (4 crafts)
	await _main.change_room("home_estate")
	await _wait_room("home_estate")
	_main.player.path.clear()
	_main.player.position = Vector3(-3.2, _main.player.position.y, 9.8)
	await _wait_seconds(0.40)

	await _snap_closeup(
		"v10_porch_01_basket_and_pillar_closeup.png",
		Vector3(-6.05, 0.55, 8.65),
		Vector3(14.0, 17.5, 19.0),
		5.6,
		true
	)

	# 2. `home_estate` Anchor #3 (`basket · 门廊随身篮`) Layer-2 Close-Up centered cleanly on moved Porch_Ready_Basket!
	_main.spatial_bench.open_workbench(_main, "home_estate", "", 3)
	await _wait_seconds(0.85)
	await _snap("v10_porch_02_basket_layer2_closeup.png")
	_main.spatial_bench.close_workbench()
	await _wait_frames(8)

	# 3. `school`: Art_Outdoor_Easel & Canvas shifted cleanly clear of Art_Building wall/window
	await _main.change_room("school")
	await _wait_room("school")
	_main.player.path.clear()
	var easel_center := _mesh_center_in_world("Art_Outdoor_Easel*", Vector3(-16.0, 0.6, 4.0))
	_main.player.position = easel_center + Vector3(2.8, 0.0, 2.2)
	_main.player.position.y = 0.2
	await _wait_seconds(0.35)
	await _snap_closeup(
		"v10_porch_03_school_art_easel_clean.png",
		easel_center,
		Vector3(14.0, 17.5, 19.0),
		6.4,
		true
	)

	# 4. `landmark_A`: A_Entrance_Basket + A_Spare_Crate cleanly separated from A_Bench and A_SortTable_Leg_001
	await _main.change_room("landmark_A")
	await _wait_room("landmark_A")
	_main.player.path.clear()
	var lm_basket_center := _mesh_center_in_world("A_Entrance_Basket*", Vector3(-2.5, 0.5, 1.26))
	_main.player.position = lm_basket_center + Vector3(2.4, 0.0, 1.6)
	_main.player.position.y = 0.2
	await _wait_seconds(0.35)
	await _snap_closeup(
		"v10_porch_04_landmark_a_orchard_basket_clean.png",
		lm_basket_center + Vector3(0.4, 0.2, -0.3),
		Vector3(12.0, 16.5, 16.5),
		5.8,
		true
	)
