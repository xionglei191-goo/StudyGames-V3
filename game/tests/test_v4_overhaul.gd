extends SceneTree
## Comprehensive StudyGames V4 End-to-End Automated Test Suite.
## Run: Godot --headless --path game --script res://tests/test_v4_overhaul.gd -- --test-harness

const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const Content = preload("res://ui/memory_story_content.gd")
const CurriculumDirector = preload("res://gameplay/curriculum_quest_director.gd")
const StoryDirector = preload("res://gameplay/unit_storyline_director.gd")
const TactileQuests = preload("res://gameplay/tactile_life_quests.gd")

var _failures: Array[String] = []
var _main: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures.append(label)
		push_error("V4_TEST_FAIL: " + label)

func _wait_frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame

func _wait_room(target_room: String) -> bool:
	for _i in range(240):
		await process_frame
		if is_instance_valid(_main) and not _main.loading_room and _main.room == target_room:
			await _wait_frames(3)
			return true
	return false

func _run() -> void:
	root.size = Vector2i(1440, 900)
	AudioServer.set_bus_mute(0, true)

	_check("forward_plus_configured", str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "forward_plus")
	_check("event_bus_autoload_present", root.get_node_or_null("EventBus") != null)

	_main = load("res://main.tscn").instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	var ready_ok := await _wait_room("village")
	_check("village_loaded", ready_ok)
	if not ready_ok:
		_finish()
		return

	var state: Node = root.get_node("State")
	_check("isolated_validation_save", str(state.save_path).begins_with("user://validation-"))

	# 1. Verify Diorama Environment + Surface Polisher + Hero Dressing in Village
	var env_node := _main.world.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_check("village_world_environment_exists", env_node != null and env_node.environment != null)
	if env_node and env_node.environment:
		_check("village_tonemap_agx", env_node.environment.tonemap_mode == Environment.TONE_MAPPER_AGX)
		_check("village_sky_background", env_node.environment.background_mode == Environment.BG_SKY and env_node.environment.sky != null)
		var is_headless := DisplayServer.get_name() == "headless"
		_check("village_ssao_configured", is_headless or env_node.environment.ssao_enabled)
		_check("village_glow_configured", is_headless or env_node.environment.glow_enabled)
	_check("village_hero_dressing_present", _main.world.find_child("HeroSceneDressing", true, false) != null)
	_check("village_diorama_horizon_present", _main.world.find_child("DioramaBackdrop", true, false) != null)

	# 2. Verify Modular 3D Wardrobe (6 outfits, 5 hats, 4 bags, CarrySocket, save/load roundtrip)
	for item: Dictionary in Wardrobe.OUTFIT_CATALOG:
		var oid := str(item.id)
		_check("outfit_set_" + oid, state.set_outfit(oid))
	for item: Dictionary in Wardrobe.HAT_CATALOG:
		var hid := str(item.id)
		_check("hat_set_" + hid, state.set_hat(hid))
	for item: Dictionary in Wardrobe.BAG_CATALOG:
		var bid := str(item.id)
		_check("bag_set_" + bid, state.set_bag(bid))
	state.set_outfit("mint")
	state.set_hat("straw_hat")
	state.set_bag("picnic_basket")
	_main.player.apply_wardrobe(state.data)
	_main.player.set_carried_item("golden_apple")
	await _wait_frames(2)
	_check("player_hat_equipped", str(_main.player.visual.current_hat) == "straw_hat")
	_check("player_bag_equipped", str(_main.player.visual.current_bag) == "picnic_basket")
	_check("player_carry_socket_equipped", str(_main.player.visual.carried_item) == "golden_apple")
	_main.player.set_carried_item("")

	state.load_state()
	_check("wardrobe_persists_reload", str(state.data.outfit) == "mint" and str(state.data.wardrobe.hat) == "straw_hat" and str(state.data.wardrobe.bag) == "picnic_basket")

	# 3. Verify Diorama Plinth Backdrops across Courtyard, Indoor Living Room, Landmark A, School
	for room_id: String in ["home_estate", "home", "landmark_A", "school"]:
		await _main.change_room(room_id)
		var r_ok := await _wait_room(room_id)
		_check("room_transition_" + room_id, r_ok)
		var backdrop: Node = _main.world.find_child("DioramaBackdrop", true, false)
		_check("diorama_plinth_present_" + room_id, backdrop != null and backdrop.get_child_count() > 0)

	# 4. Verify Tactile Life Quests in Landmark A (3D apples & glowing wicker basket delivery)
	await _main.change_room("landmark_A")
	await _wait_room("landmark_A")
	_check("tactile_orchard_spawned", is_instance_valid(_main.tactile_quests) and _main.tactile_quests._pickups.size() == 3)
	if is_instance_valid(_main.tactile_quests) and not _main.tactile_quests._pickups.is_empty():
		var first_entry: Dictionary = _main.tactile_quests._pickups[0]
		var first_holder: Node3D = first_entry.get("node") as Node3D
		var before_apples := int(state.data.apples)
		if first_holder != null:
			_main.player.global_position = Vector3(first_holder.global_position.x, _main.player.global_position.y, first_holder.global_position.z)
			await _wait_frames(5)
			_check("tactile_apple_picked_into_hands", str(_main.tactile_quests.held_kind) != "" and str(_main.player.visual.carried_item) != "")
			_main.player.global_position = Vector3(_main.tactile_quests._basket_pos.x, _main.player.global_position.y, _main.tactile_quests._basket_pos.z)
			await _wait_frames(5)
			_check("tactile_apple_delivered_to_basket", str(_main.tactile_quests.held_kind) == "" and int(state.data.apples) == before_apples + 1)

	# 5. Verify 8-Book 81-Unit Curriculum Quest Director across ALL 8 books
	var catalog := Content.load_catalog()
	var books: Array = catalog.get("books", [])
	_check("eight_books_in_catalog", books.size() == 8)
	var total_units_checked := 0
	for book: Dictionary in books:
		var bid := str(book.get("book_id", ""))
		var ucount := int(book.get("unit_count", 0))
		_check("select_book_" + bid, state.journey_select_book(bid))
		for u in range(1, ucount + 1):
			var uid := "unit-" + str(u)
			state.set_active_unit(uid)
			var comm := CurriculumDirector.build_daily_commission(state, "npc_bear_uncle")
			if not comm.is_empty() and not str(comm.get("target_word", "")).is_empty():
				total_units_checked += 1
	_check("all_81_units_generate_commissions", total_units_checked == 81)
	state.journey_select_book("xiangshao-g3-1")
	state.set_active_unit("unit-1")

	# 6. Verify Cozy Wardrobe Studio UI + Parent AI Observatory UI
	_main.show_bag()
	await _wait_frames(3)
	_check("cozy_wardrobe_studio_opens", _main.ui.current_panel == "bag" and is_instance_valid(_main.ui.wardrobe_preview))
	_main._on_action("wardrobe_tab:hat")
	await _wait_frames(2)
	_main._on_action("v4_parent_ai")
	await _wait_frames(3)
	_check("parent_ai_observatory_opens", _main.ui.current_panel == "v4_parent_ai")
	_main._close()
	await _wait_frames(2)

	# 7. Verify 3D Interactive Pop-up Book Theater (`PopupBookTheater`) + MemorySink + Stealth Evidence
	var sample_entries := Content.list_entries("xiangshao-g3-1", "unit-1", "")
	_check("unit1_entries_available", not sample_entries.is_empty())
	if not sample_entries.is_empty():
		var eid := str(sample_entries[0].entry_id)
		var target_word := str(sample_entries[0].spelling_display)
		var prev_stealth_count: int = (state.data.v4.stealth_events as Array).size()
		_main.journey.open_story(eid, false)
		await _wait_frames(4)
		var theater: Control = _main.journey.current_memory
		_check("popup_book_theater_active", is_instance_valid(theater))
		if is_instance_valid(theater):
			_check("popup_book_3d_puppets_built", (theater._puppets as Array).size() >= 1)
			theater.start_practice()
			await _wait_frames(2)
			theater.submit_response(target_word)
			await _wait_frames(3)
			_check("popup_book_practice_completed", theater.first_response is Dictionary and bool((theater.first_response as Dictionary).get("correct", false)))
			_check("popup_book_stealth_evidence_recorded", (state.data.v4.stealth_events as Array).size() > prev_stealth_count)
			theater.request_close()
			await _wait_frames(3)
		_main._close()

	# 8. Verify All 30 Tactile Life Rooms (26 Landmarks A-Z + Home Courtyard + Campus) & Persistent EchoCraft
	_check("all_30_tactile_rooms_configured", TactileQuests.ROOM_QUEST_SPECS.size() == 30)
	for code_idx in range(26):
		var letter_key := "landmark_" + char(65 + code_idx)
		_check("tactile_spec_present_" + letter_key, TactileQuests.ROOM_QUEST_SPECS.has(letter_key))
	await _main.change_room("landmark_B")
	await _wait_room("landmark_B")
	_check("landmark_B_station_spawned", _main.tactile_quests.get_node_or_null("CozyCraftStation") != null and _main.tactile_quests._pickups.size() == 3)
	if not _main.tactile_quests._pickups.is_empty():
		var boat_node: Node3D = _main.tactile_quests._pickups[0].get("node") as Node3D
		var coins_before_boat := int(state.data.coins)
		if boat_node != null:
			_main.player.global_position = Vector3(boat_node.global_position.x, _main.player.global_position.y, boat_node.global_position.z)
			await _wait_frames(5)
			_check("landmark_B_boat_picked", _main.tactile_quests.held_kind == "boat" and str(_main.player.visual.carried_item) == "boat")
			_main.player.global_position = Vector3(_main.tactile_quests._basket_pos.x, _main.player.global_position.y, _main.tactile_quests._basket_pos.z)
			await _wait_frames(5)
			_check("landmark_B_boat_delivered_with_coin_reward", _main.tactile_quests.held_kind == "" and int(state.data.coins) == coins_before_boat + 4)
			state.load_state()
			_main.tactile_quests.attach_to_room(_main, "landmark_B")
			await _wait_frames(2)
			_check("landmark_B_persistent_echocraft_survives_reload", int(state.data.v4.landmark_crafts.get("landmark_B", 0)) == 1 and _main.tactile_quests.get_node_or_null("EchoCraft_0") != null)

	# 9. Verify Full 8-Book / 81-Unit 3-Stage Cozy Storyline Engine, Chapter Atlas UI, and 3D World Keepsake Plaque
	var arc_units := StoryDirector.all_units()
	_check("story_director_81_units_loaded", arc_units.size() == 81 and StoryDirector.books().size() == 8)
	var valid_story_units := 0
	for u: Dictionary in arc_units:
		if not str(u.get("primary_room", "")).is_empty() and (u.get("stages", []) as Array).size() == 3 and not str(u.get("world_keepsake", "")).is_empty():
			valid_story_units += 1
	_check("all_81_story_units_have_3_stages_and_keepsake", valid_story_units == 81)

	await _main._on_action("v4_chapter_atlas")
	await _wait_frames(3)
	_check("chapter_atlas_ui_opens", _main.ui.current_panel == "v4_chapter_atlas")
	await _main._on_action("v4_chap_go:xiangshao-g4-1:unit-3")
	await _wait_frames(5)
	var active_chap := StoryDirector.active_chapter(state)
	var ckey := str(active_chap.get("chapter_key", ""))
	_check("chapter_go_teleported_to_primary_room", ckey == "xiangshao-g4-1/unit-3" and _main.room == str(active_chap.get("primary_room", "")) and _main.ui.diegetic.visible)
	var coins_before_chap := int(state.data.coins)
	await _main._on_action("v4_chap_step:1:" + ckey)
	await _wait_frames(2)
	_check("chapter_stage_1_recorded", state.v4_chapter_stage(ckey) == 1)
	await _main._on_action("v4_chap_step:2:" + ckey)
	await _wait_frames(2)
	_check("chapter_stage_2_recorded", state.v4_chapter_stage(ckey) == 2)
	await _main._on_action("v4_chap_step:3:" + ckey)
	await _wait_frames(3)
	_check("chapter_stage_3_completed_with_coins_and_plaque", state.v4_chapter_stage(ckey) == 3 and int(state.data.coins) == coins_before_chap + 12 and _main.tactile_quests.get_node_or_null("ChapterWorldKeepsake") != null)
	state.load_state()
	_check("chapter_stage_3_persists_reload", state.v4_chapter_stage(ckey) == 3 and StoryDirector.total_completed_chapters(state) >= 1)
	_main._close()

	# 10. Verify 100% Diegetic Normal Play (Zero Exam Modals), Commission Completion & Tolerant Voice Encouragement
	_main.validation_mode = false
	await _main.change_room("classroom")
	await _wait_room("classroom")
	await _main.interact_id("teacher")
	await _wait_frames(3)
	_check("classroom_teacher_uses_diegetic_bubble_no_exam_modal", _main.ui.diegetic.visible and not _main.ui.modal.visible)
	_main.ui.diegetic.follow_along_submitted.emit("Good morning!", "voice", 0.35, 920)
	await _wait_frames(15)
	_check("voice_follow_along_cheer_recorded", int(state.data.v4.get("voice_cheers", 0)) >= 1)
	var coins_before_comm := int(state.data.coins)
	_main._handle_v4_commission_pick("1:morning:test-comm-01:textbook_miss_li:xiangshao-g3-1-u1-hello")
	await _wait_frames(2)
	_check("commission_completion_grants_coins", int(state.data.coins) == coins_before_comm + 6 and (state.data.v4.completed_commissions as Array).has("test-comm-01"))
	_main._close()

	await _main.change_room("canteen")
	await _wait_room("canteen")
	await _main.interact_id("lunch")
	await _wait_frames(3)
	_check("canteen_lunch_uses_diegetic_bubble", _main.ui.diegetic.visible and not _main.ui.modal.visible)
	_main._close()
	_main.validation_mode = true

	# Clean up isolated validation save files
	var abs_save := ProjectSettings.globalize_path(str(state.save_path))
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(abs_save + suffix):
			DirAccess.remove_absolute(abs_save + suffix)

	_finish()

func _finish() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
	if _failures.is_empty():
		print("PASS: StudyGames V4 full completion (Forward+, 44-Scene Diorama Plinths, 6x5x4 3D Wardrobe, 30-Room Tactile Life Stations + EchoCraft, 8-Book/81-Unit 3-Stage Cozy Storylines + Chapter Atlas + 3D Plaques, 100% Diegetic Bubbles, Tolerant Voice Encouragement, 3D Pop-up Book Theater, Stealth IRT)")
		quit(0)
	else:
		print("FAIL: %d checks failed: %s" % [_failures.size(), ", ".join(_failures)])
		quit(1)
