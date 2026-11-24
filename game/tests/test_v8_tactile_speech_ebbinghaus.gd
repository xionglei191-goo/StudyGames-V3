extends SceneTree
## V8 Tactile 3D Drag, Mic Follow-Along, Dual-Track Ebbinghaus Errands & 16-Room Almanac Test Suite.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_v8_tactile_speech_ebbinghaus.gd -- --test-harness

const STATE_SCRIPT = preload("res://scripts/game_state.gd")
const SpatialBench = preload("res://gameplay/spatial_cluster_bench_3d.gd")
const V8Memory = preload("res://core/v8_memory_ledger.gd")
const ErrandDirector = preload("res://gameplay/ebbinghaus_errand_director.gd")

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

var passed := 0
var failed := 0
var _prod_save_before := ""
var _test_dir := "user://v8_test_tmp"


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("V8 FAIL: " + label)


func _frames(count: int = 3) -> void:
	for _i: int in range(count):
		await process_frame


func _sha(path: String) -> String:
	return FileAccess.get_sha256(path).to_lower() if FileAccess.file_exists(path) else ""


func _run() -> void:
	await process_frame
	var watchdog := Timer.new()
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func():
		_check(false, "bounded_timeout")
		quit(1)
	)
	watchdog.start(180.0)

	_prod_save_before = _sha("user://island-save-v1.json")
	_cleanup_test_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_dir))
	root.size = Vector2i(1440, 900)

	_test_v8_multi_step_cluster_schema()
	_test_unit_ebbinghaus_dual_track_and_speech()
	await _test_live_in_scene_v8_loop()

	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_untouched")
	_check(_sha("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA, "prologue_json_untouched")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "user_save_untouched")

	_cleanup_test_dir()
	print("V8 Tactile+Speech+Ebbinghaus Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_v8_multi_step_cluster_schema() -> void:
	var rooms: Array = ["home_estate", "home", "home_bedroom", "home_kitchen", "home_dining", "home_bathroom", "home_study", "home_balcony", "school", "classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field"]
	var total_steps := 0
	var valid_anchors := 0
	for rid: String in rooms:
		var cl := SpatialBench.cluster_for_room(rid)
		for mv: Variant in cl.get("macro_items", []):
			var md: Dictionary = mv as Dictionary
			var steps: Array = md.get("placement_steps", []) if md.get("placement_steps") is Array else []
			if steps.size() >= 2 and steps.size() <= 3:
				valid_anchors += 1
			total_steps += steps.size()
	_check(valid_anchors == 80, "all_80_anchors_have_2_to_3_tidy_steps")
	_check(total_steps >= 180, "total_tidy_steps_populated")


func _test_unit_ebbinghaus_dual_track_and_speech() -> void:
	var st = STATE_SCRIPT.new()
	st.save_path = _test_dir + "/v8_unit.json"
	st.load_state()

	st.v8_record_room_visit("home_bathroom")
	st.v8_record_word_exposure("soap", "香皂", "home_bathroom", 2, 1000)
	st.v8_record_word_exposure("towel", "擦手巾", "home_bathroom", 2, 1005)
	st.v8_record_word_exposure("coat", "外套", "home_bedroom", 3, 1010)
	st.v8_record_word_exposure("pen", "钢笔", "home_study", 1, 1015)
	st.v8_record_word_exposure("globe", "地球仪", "home_study", 2, 1020)

	# Immediately after seeing 5 words in same room visit: not yet due (< 2 room hops and < 480s)
	_check(st.v8_due_words("home", 1030).is_empty(), "newly_seen_words_not_due_before_room_hops")

	# Hop across 2 rooms -> triggers same-session short-interval recall!
	st.v8_record_room_visit("home_bedroom")
	st.v8_record_room_visit("home")
	var due_now: Array[Dictionary] = st.v8_due_words("home", 1050)
	_check(due_now.size() == 5, "five_words_plus_two_room_hops_triggers_same_session_recall")

	# Record speech stars (word + sentence)
	var sp_w: Dictionary = st.v8_record_spoken("soap", 3, false, "香皂", "home_bathroom", 2, 1060)
	var sp_s: Dictionary = st.v8_record_spoken("soap", 3, true, "香皂", "home_bathroom", 2, 1065)
	_check(int(sp_w.get("exp_gained", 0)) == 12 and int(sp_s.get("exp_gained", 0)) == 20, "word_and_sentence_speech_grant_12_and_20_exp")

	# Start a 2-target errand (`soap` + `coat`)
	var prop := ErrandDirector.build_errand_proposal(st, "home", "textbook_role_lingling_mother", "妈妈 · Mom", 1070)
	_check(not prop.is_empty() and not str(prop.get("prompt_zh", "")).contains("香皂"), "errand_prompt_does_not_spoil_chinese_meaning")
	_check(st.v8_start_errand(prop), "v8_start_errand_commits")

	var t_words: Array = prop.get("targets", [])
	var w0 := str((t_words[0] as Dictionary).get("word", ""))
	var w1 := str((t_words[1] as Dictionary).get("word", ""))

	# Target 0: Tier-0 pure 3D blind recall -> +32 EXP, +4 coins, stage 1 -> 2
	var coins_b0 := int(st.data.coins)
	var r0: Dictionary = st.v8_complete_errand_target(w0, 1100)
	_check(bool(r0.get("ok", false)) and int(r0.get("new_stage", 0)) == 2 and int(r0.get("exp_reward", 0)) == 32, "tier0_blind_recall_advances_stage_and_grants_2x_exp")
	_check(int(st.data.coins) >= coins_b0 + 4, "tier0_blind_recall_grants_4_coins")

	# Target 1: Advance hint once (Tier 1) -> +24 EXP, +3 (+3 errand completion) coins, stage 1 -> 2
	var h_tier: int = st.v8_advance_errand_hint(w1)
	_check(h_tier == 1, "advance_errand_hint_reaches_tier_1")
	var r1: Dictionary = st.v8_complete_errand_target(w1, 1120)
	_check(bool(r1.get("errand_completed", false)) and int(r1.get("exp_reward", 0)) == 24, "tier1_hint_completes_errand_with_1_5x_exp")

	# Progress `w0` through Stage 2 -> 3 (1 day), Stage 3 -> 4 (3 days), Stage 4 -> 5 Gold Star (7 days)!
	_check(not V8Memory.is_word_due(st.data, w0, 1200), "stage2_word_not_immediately_due")
	st.next_day() # day 1 -> 2
	_check(V8Memory.is_word_due(st.data, w0, 1200), "sleeping_next_day_makes_stage2_word_due")

	for target_stage: int in [3, 4, 5]:
		st.v8_start_errand({
			"domain": "home",
			"giver_npc_id": "textbook_role_lingling_mother",
			"giver_name": "妈妈 · Mom",
			"targets": [{"word": w0, "zh": "物", "room_id": "home_bathroom", "room_zh": "洗手间", "anchor_order": 2, "anchor_zh": "洗手台", "found": false, "hint_tier": 0}],
		})
		var rs: Dictionary = st.v8_complete_errand_target(w0, 2000 + target_stage * 100)
		_check(int(rs.get("new_stage", 0)) == target_stage, "word_reaches_stage_%d" % target_stage)
		for _d: int in range(7):
			st.next_day()

	_check(not V8Memory.is_word_due(st.data, w0, 99999999), "stage5_gold_star_word_permanently_graduated")

	# Verify save & reload persistence
	var reloaded = STATE_SCRIPT.new()
	reloaded.save_path = st.save_path
	reloaded.load_state()
	var sum: Dictionary = reloaded.v8_summary(99999999)
	_check(int(sum.get("gold_words", 0)) == 1 and int(sum.get("spoken_words", 0)) == 1, "v8_memory_persists_across_save_and_load")
	st.free()
	reloaded.free()


func _test_live_in_scene_v8_loop() -> void:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for _f: int in range(1200):
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready, "live_main_scene_ready")

	var state: Node = root.get_node("State")
	state.data = state._default_state()
	game.muted = true
	game.validation_mode = false

	# 1. Open Study Desk (`home_study`, anchor 1): test decoupled single-click vs step-by-step drag + follow-along!
	await game.change_room("home_study")
	await _frames(4)
	game.interact_id("memory_01")
	await _frames(5)

	var total_steps: int = game.spatial_bench._placement_steps.size()
	_check(total_steps == 3 and game.spatial_bench._target_drop_halo.visible, "study_desk_loads_3_steps_with_visible_drop_halo")

	# Single-click (`auto_place_on_select = false`) ONLY selects & pronounces without auto-completing!
	var click_res: Dictionary = game.spatial_bench.select_bench_item("pen", true, false)
	_check(not bool(click_res.get("placed", true)) and game.spatial_bench.task_index == 0, "single_click_selects_without_accidental_auto_fly")

	# Drag step 1 (`pen`) -> task_index becomes 1, tasks_completed still false!
	var step1_item := str(game.spatial_bench._current_step_dict().get("item", ""))
	var drag1: Dictionary = game.spatial_bench.drag_item_to_target(step1_item)
	_check(bool(drag1.get("placed", false)) and game.spatial_bench.task_index == 1 and not game.spatial_bench.tasks_completed, "drag_step_1_advances_to_step_2")

	# Complete remaining steps via `assist_place_current_step()` fallback!
	while not game.spatial_bench.tasks_completed:
		var a_res: Dictionary = game.spatial_bench.assist_place_current_step()
		_check(bool(a_res.get("placed", false)), "assist_place_step_succeeds")
	_check(game.spatial_bench.tasks_completed and not game.spatial_bench._target_drop_halo.visible, "all_3_steps_completed_hides_drop_halo")

	# Trigger Follow-Along on `pencil` (word mode + sentence mode + shy mode)
	game.spatial_bench.select_bench_item("pencil", true, false)
	var sp1: Dictionary = await game.spatial_bench.trigger_follow_along("voice", "", 0.045, 950)
	_check(bool(sp1.get("ok", false)) and int(sp1.get("star_tier", 0)) >= 2, "bench_follow_along_voice_awards_star")
	game.spatial_bench._toggle_follow_sentence_mode()
	var sp2: Dictionary = await game.spatial_bench.trigger_follow_along("shy")
	_check(bool(sp2.get("ok", false)) and int(sp2.get("star_tier", 0)) == 1, "bench_follow_along_shy_mode_awards_heart_star")

	# Expose 3 more words (`book`, `ruler`, `pencil-box`) so >= 5 words are known
	for extra_w: String in ["book", "ruler", "pencil-box"]:
		game.spatial_bench.select_bench_item(extra_w, true, false)
	game.spatial_bench.close_workbench()
	await _frames(3)

	# 2. Hop through `home_bedroom` -> `home` (2 room hops) so Mom's golden errand badge activates!
	await game.change_room("home_bedroom")
	await _frames(3)
	await game.change_room("home")
	await _frames(4)

	_check(is_instance_valid(game.errand_director._npc_badge) and game.errand_director._npc_badge.visible, "mom_displays_floating_golden_errand_badge_when_due")

	# Accept errand via UI action (`v8_accept_errand:home:textbook_role_lingling_mother`)
	await game._on_action("v8_accept_errand:home:textbook_role_lingling_mother")
	await _frames(4)
	_check(is_instance_valid(game.errand_director._sticky_panel) and game.errand_director._sticky_panel.visible, "hud_sticky_errand_note_displays_on_accept")

	# Jump to target furniture via `v8_errand_go` -> verify 3-tier anti-spoiler blind recall!
	await game._on_action("v8_errand_go")
	await _frames(6)
	var target_w := str(game.spatial_bench._active_errand_word)
	_check(game.spatial_bench.bench_open and not target_w.is_empty(), "errand_go_opens_target_furniture_in_blind_recall_mode")

	var target_chip: Button = game.spatial_bench._callout_buttons.get(target_w, null)
	_check(target_chip != null and target_chip.text == "★ ？" and game.spatial_bench._speak_zh_btn.disabled, "tier0_masks_callout_chip_and_disables_chinese_spoiler")

	# Request Tier-1 hint -> reveals initial/final letter skeleton!
	var h1: int = game.spatial_bench.request_errand_hint()
	_check(h1 == 1 and target_chip.text.contains("_"), "tier1_hint_shows_letter_skeleton")

	# Pick the target 3D prop -> completes recall and unmasks bilingual callouts!
	var recall_res: Dictionary = game.spatial_bench._handle_errand_guess(target_w)
	_check(bool(recall_res.get("ok", false)) and game.spatial_bench._active_errand_word.is_empty(), "picking_target_prop_resolves_errand_target")
	_check(target_chip.text.contains("✓") and not target_chip.text.contains("？"), "resolved_errand_unmasks_bilingual_callout")
	game.spatial_bench.close_workbench()
	await _frames(3)

	# 3. Open 16-Room 3D Spatial Memory Almanac (`v8_almanac`) & Parent AI Portal (`v4_parent_ai`)
	await game._on_action("v8_almanac")
	await _frames(4)
	_check(game.ui.current_panel == "v8_almanac" and game.ui.modal.visible, "v8_3d_spatial_almanac_opens")
	var turntable: Node = game.ui.panel_box.find_child("Almanac3DTurntable", true, false)
	_check(turntable != null, "almanac_embeds_live_3d_glb_turntable")
	await game._on_action("v8_almanac_room:home_bathroom")
	await _frames(3)
	_check(game.ui.current_panel == "v8_almanac", "almanac_switches_room_tabs_cleanly")

	await game._on_action("v4_parent_ai")
	await _frames(3)
	var v8_pill: Node = game.ui.panel_box.find_child("V8RetentionMetricsPill", true, false)
	_check(game.ui.current_panel == "v4_parent_ai" and v8_pill != null, "parent_portal_displays_v8_ebbinghaus_metrics")
	game._close()
	await _frames(2)

	game.queue_free()
	await process_frame


func _cleanup_test_dir() -> void:
	var abs_dir := ProjectSettings.globalize_path(_test_dir)
	var d := DirAccess.open(abs_dir)
	if d != null:
		for fn: String in d.get_files():
			d.remove(fn)
	DirAccess.remove_absolute(abs_dir)
