extends SceneTree
## Native Graphical Forward+ Showcase Screenshot Capture Runner.
## Run (graphical, NOT --headless):
##   Godot_v4.7.2-stable_win64.exe --path game --script res://tests/capture_v4_showcase.gd -- --test-harness

const Content = preload("res://ui/memory_story_content.gd")

var _main: Node3D
var _out_dir := "f:/LoveStudy/docs/screenshots/v4-showcase"

func _initialize() -> void:
	call_deferred("_run")

func _wait_frames(count: int = 8) -> void:
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

func _snap_camera(focus: Vector3, cam_size: float) -> void:
	_main.camera_base_size = cam_size
	_main.camera.size = cam_size
	_main.camera.position = focus + _main.camera_offset
	_main.camera.look_at(_main.camera.position - _main.camera_offset + Vector3(0, 0.5, 0), Vector3.UP)
	await _wait_frames(6)

func _save_shot(filename: String) -> void:
	if is_instance_valid(_main) and is_instance_valid(_main.ui) and _main.ui.get("toast_label") != null:
		_main.ui.toast_timer = 0.0
		(_main.ui.toast_label as Control).hide()
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path := _out_dir + "/" + filename
	img.save_png(path)
	print("CAPTURED: ", path, " (", img.get_width(), "x", img.get_height(), ")")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)
	AudioServer.set_bus_mute(0, true)

	_main = load("res://main.tscn").instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	await _wait_room("village")

	var state: Node = root.get_node("State")
	state.set_preference("fixed_day", true)

	# Shot 01: Village Diorama (Forward+ Sky, AgX, SSAO, Shoreline Foam Water, Fairy Lights, Straw Hat + Mint Outfit)
	state.set_outfit("mint")
	state.set_hat("straw_hat")
	state.set_bag("picnic_basket")
	_main.player.apply_wardrobe(state.data)
	_main.ui.update_wardrobe(state.data)
	_main.ui.close_panel()
	for entry: Dictionary in _main.interactions:
		if str(entry.id) == "baker":
			_main.player.global_position = entry.position + Vector3(-2.4, 0.0, 2.6)
			_main.player.face(entry.position)
			break
	await _snap_camera(_main.player.global_position + Vector3(1.5, 0.0, -1.5), 20.5)
	await _wait_seconds(0.45)
	await _save_shot("01_village_diorama.png")

	# Shot 02: Home Estate Courtyard (Walnut Miniature Diorama Plinth + Rolling Hills/Clouds + Zero Gray Void!)
	state.set_outfit("pink")
	state.set_hat("bunny_ears")
	state.set_bag("star_wings")
	_main.player.apply_wardrobe(state.data)
	_main.ui.update_wardrobe(state.data)
	await _main.change_room("home_estate")
	await _wait_room("home_estate")
	_main.ui.close_panel()
	await _snap_camera(_main.player.global_position + Vector3(0.0, 0.0, -1.2), 21.0)
	await _wait_seconds(0.45)
	await _save_shot("02_home_estate_courtyard.png")

	# Shot 03: Sunlit Indoor Living Room (Dollhouse Plinth, Window Sunbeam, Placed Furniture & Storybook)
	for dec_id: String in ["flower_box", "picnic", "lamp"]:
		state.data.decorations_owned[dec_id] = true
		state.data.decorations_placed[dec_id] = true
	state.set_outfit("lavender")
	state.set_hat("star_beret")
	state.set_bag("none")
	await _main.change_room("home")
	await _wait_room("home")
	_main._refresh()
	_main.ui.close_panel()
	await _snap_camera(_main.player.global_position, 15.5)
	await _wait_seconds(0.45)
	await _save_shot("03_home_living_room.png")

	# Shot 04: Landmark A Tactile Orchard + Carried 3D Apple + World-Anchored Diegetic Speech Bubble!
	state.set_outfit("yellow")
	state.set_hat("straw_hat")
	state.set_bag("school_pack")
	await _main.change_room("landmark_A")
	await _wait_room("landmark_A")
	_main.player.apply_wardrobe(state.data)
	_main.player.set_carried_item("apple")
	var gardener_pos: Vector3 = _main.player.global_position + Vector3(2.0, 0, -1.5)
	for entry: Dictionary in _main.interactions:
		if str(entry.id) == "gardener":
			gardener_pos = entry.position
			_main.player.global_position = gardener_pos + Vector3(-1.8, 0.0, 1.5)
			_main.player.face(gardener_pos)
			break
	await _snap_camera((gardener_pos + _main.player.global_position) * 0.5, 16.5)
	_main.conversation_position = gardener_pos
	_main.ui.diegetic.open_conversation({
		"npc_id": "npc_rabbit_gardener",
		"speaker": "兔兔园丁 · A 苹果果园",
		"en": "Hello! You are holding a shiny red apple! Place it in my glowing wicker basket or pick a cozy sticker!",
		"zh": "你好呀！你手里正捧着香甜的红苹果呢！快放进发光藤篮，或者接一张今日单元贴纸委托吧！",
		"world_pos": gardener_pos,
		"show_zh_immediately": true,
		"auto_speak": false,
		"actions": [
			{"label": "🌟 今日单元小委托", "id": "v4_commission:npc_rabbit_gardener", "primary": true},
			{"label": "🔊 听听 apple", "id": "audio:apple"},
			{"label": "📖 翻开 3D 立体翻翻书", "id": "close"},
			{"label": "继续逛果园", "id": "close"}
		]
	})
	await _wait_seconds(0.45)
	await _save_shot("04_landmark_A_tactile_orchard.png")
	_main.ui.diegetic.dismiss()
	_main.player.set_carried_item("")

	# Shot 05: Cozy 3D Sunlit Wardrobe Studio (Turntable with Outfit + 3D Bunny Ears + Star Wings)
	state.set_outfit("pink")
	state.set_hat("bunny_ears")
	state.set_bag("star_wings")
	_main.player.apply_wardrobe(state.data)
	_main.ui.show_inventory(state.data, "hat")
	await _wait_seconds(0.55)
	await _save_shot("05_cozy_wardrobe_studio.png")
	_main._close()

	# Shot 06: 3D Interactive Pop-up Book Mnemonic Theater (Walnut Desk + Hardcover Book + 3D Standee Puppets!)
	var apple_entries := Content.list_entries("xiangshao-g3-1", "", "apple")
	var story_eid := str(apple_entries[0].entry_id) if not apple_entries.is_empty() else str(Content.list_entries("xiangshao-g3-1", "unit-1", "")[0].entry_id)
	_main.journey.open_story(story_eid, false)
	await _wait_seconds(0.85)
	await _save_shot("06_popup_book_theater_3d.png")
	_main._close()

	# Shot 07: Parent AI Growth Observatory & 8-Book 81-Unit Curriculum Switcher
	state.record_stealth_evidence({"word": "apple", "support_level": 0, "correct": true, "context": "tactile_orchard_basket"})
	state.record_stealth_evidence({"word": "morning", "support_level": 0, "correct": true, "context": "diegetic_commission"})
	state.record_stealth_evidence({"word": "hello", "support_level": 1, "correct": true, "context": "popup_book_theater"})
	state.record_stealth_evidence({"word": "cake", "support_level": 2, "correct": true, "context": "bakery"})
	_main._on_action("v4_parent_ai")
	await _wait_seconds(0.95)
	await _save_shot("07_parent_ai_observatory.png")
	_main._close()

	# Shot 08: 8-Book × 81-Unit Illustrated Cozy Chapter Atlas (`ChapterAtlasView`)
	state.advance_v4_chapter("xiangshao-g3-1/unit-1", 3, 0)
	state.advance_v4_chapter("xiangshao-g3-1/unit-2", 3, 0)
	state.advance_v4_chapter("xiangshao-g3-1/unit-4", 2, 0)
	state.journey_select_book("xiangshao-g3-1")
	state.set_active_unit("unit-4")
	_main._on_action("v4_chapter_atlas")
	await _wait_seconds(0.65)
	await _save_shot("08_chapter_atlas_81_units.png")
	_main._close()

	# Shot 09: Landmark B Boat Tactile Workshop + Two-Hand Carried 3D Wooden Boat + CozyCraftStation + Chapter Plaque!
	state.set_outfit("blue")
	state.set_hat("straw_hat")
	state.set_bag("picnic_basket")
	state.record_landmark_craft("landmark_B", 0)
	await _main.change_room("landmark_B")
	await _wait_room("landmark_B")
	_main.player.apply_wardrobe(state.data)
	_main.player.set_carried_item("boat")
	var station_pos: Vector3 = _main.tactile_quests._basket_pos
	_main.player.global_position = station_pos + Vector3(-1.35, 0.0, 1.15)
	_main.player.face(station_pos)
	await _snap_camera((station_pos + _main.player.global_position) * 0.5, 15.0)
	_main.ui.diegetic.open_conversation({
		"npc_id": "npc_bear_uncle",
		"speaker": "B 馆主理人 · 小船拼装台",
		"en": "Welcome to Landmark B! \"Boat\" starts with B! Place your handcrafted boat on our dock table!",
		"zh": "欢迎来到 B 字母船坞工坊！双手捧着 3D 小木船走近发光拼装台，就能留下永久小岛手作纪念哦！",
		"world_pos": station_pos,
		"show_zh_immediately": true,
		"auto_speak": false,
		"actions": [
			{"label": "🃏 收集 B 字母发现卡", "id": "close", "primary": true},
			{"label": "🚀 本章三幕共创", "id": "close"},
			{"label": "去安放 3D 小木船", "id": "close"}
		]
	})
	await _wait_seconds(0.55)
	await _save_shot("09_landmark_B_boat_tactile_workshop.png")
	_main.ui.diegetic.dismiss()
	_main.player.set_carried_item("")

	# Shot 10: Sunlit Classroom Diegetic Story Circle (Zero Exam Modals + Tolerant Voice Follow-Along Pills!)
	state.set_outfit("mint")
	state.set_hat("star_beret")
	state.set_bag("school_pack")
	await _main.change_room("classroom")
	await _wait_room("classroom")
	_main.player.apply_wardrobe(state.data)
	_main.validation_mode = false
	for entry: Dictionary in _main.interactions:
		if str(entry.id) == "teacher":
			_main.player.global_position = entry.position + Vector3(-1.5, 0.0, 1.4)
			_main.player.face(entry.position)
			await _snap_camera((entry.position + _main.player.global_position) * 0.5, 15.5)
			break
	await _main.interact_id("teacher")
	await _wait_seconds(0.55)
	await _save_shot("10_classroom_diegetic_story_circle.png")
	_main._close()

	# Shot 11: Animal-Crossing 0.5m Free-Grid 3D Home & Courtyard Studio (`FreeGridDecorStudio`)
	state.data.coins = 300
	state.set_outfit("lavender")
	state.set_hat("bunny_ears")
	state.set_bag("none")
	await _main.change_room("home")
	await _wait_room("home")
	_main.player.apply_wardrobe(state.data)
	await _main.free_decor_studio.open_studio()
	await _wait_frames(4)
	_main.free_decor_studio.cursor_pos = _main.free_decor_studio._clamp_and_snap(Vector3(-1.5, 0.0, 0.5))
	_main.free_decor_studio.select_furniture("sunflower_rug")
	_main.free_decor_studio.place_at_cursor()
	_main.free_decor_studio.cursor_pos = _main.free_decor_studio._clamp_and_snap(Vector3(-1.5, 0.0, -0.5))
	_main.free_decor_studio.select_furniture("reading_sofa")
	_main.free_decor_studio.place_at_cursor()
	_main.free_decor_studio.cursor_pos = _main.free_decor_studio._clamp_and_snap(Vector3(0.5, 0.0, 0.5))
	_main.free_decor_studio.select_furniture("tea_table")
	_main.free_decor_studio.place_at_cursor()
	_main.free_decor_studio.cursor_pos = _main.free_decor_studio._clamp_and_snap(Vector3(1.5, 0.0, -0.5))
	_main.free_decor_studio.select_furniture("star_floor_lamp")
	_main.free_decor_studio.rotate_ghost(90)
	_main.free_decor_studio._rebuild_ghost()
	await _wait_seconds(0.65)
	await _save_shot("11_free_grid_home_studio.png")
	_main.free_decor_studio.close_studio()

	# Shot 12: Differentiated Thematic Chapter Mini-Game (`ChapterThematicPlay` · 🍰 暖香点餐配盘)
	_main.open_v4_thematic_play("xiangshao-g3-1/unit-9")
	await _wait_frames(4)
	var u9_chap: Dictionary = preload("res://gameplay/unit_storyline_director.gd").get_chapter_by_key("xiangshao-g3-1/unit-9")
	var u9_targets: Array[Dictionary] = preload("res://gameplay/chapter_thematic_play.gd").target_cards_for_chapter(u9_chap)
	if not u9_targets.is_empty():
		_main._handle_v4_thematic_pick("xiangshao-g3-1/unit-9:" + str(u9_targets[0].get("word", "apple")))
	await _wait_seconds(0.55)
	await _save_shot("12_thematic_chapter_minigame.png")
	_main._close()
	_main.validation_mode = true

	# Clean up isolated validation save files
	var abs_save := ProjectSettings.globalize_path(str(state.save_path))
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(abs_save + suffix):
			DirAccess.remove_absolute(abs_save + suffix)

	_main.queue_free()
	await _wait_frames(2)
	quit(0)
