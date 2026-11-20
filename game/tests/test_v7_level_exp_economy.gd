extends SceneTree
## V7 Joint Level + EXP & Leaf Coin Economy Verification Suite.
## Run: Godot --headless --path game --script res://tests/test_v7_level_exp_economy.gd -- --test-harness

const STATE_SCRIPT = preload("res://scripts/game_state.gd")
const Progression = preload("res://core/progression_ledger.gd")
const Roleplay = preload("res://gameplay/situational_roleplay.gd")

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

var passed := 0
var failed := 0
var _prod_save_before := ""
var _test_dir := "user://v7-econ-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func():
		push_error("TIMEOUT in test_v7_level_exp_economy.gd")
		quit(1)
	)
	_prod_save_before = _sha("user://island-save-v1.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_dir))

	_test_unit_level_curve_and_gifts()
	_test_unit_antigrind_and_reviews()
	_test_unit_wardrobe_and_furniture_dual_unlock()
	_test_unit_legacy_save_migration()
	await _test_live_main_scene_integration()

	_cleanup_test_dir()
	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_immutable")
	_check(_sha("res://data/learning/prologue.json") == "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f", "prologue_json_immutable")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "production_save_untouched")

	print("V7 Level+EXP & Economy Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_unit_level_curve_and_gifts() -> void:
	_check(Progression.level_for_exp(0) == 1, "exp_0_is_lv1")
	_check(Progression.level_for_exp(59) == 1, "exp_59_is_lv1")
	_check(Progression.level_for_exp(60) == 2, "exp_60_is_lv2")
	_check(Progression.level_for_exp(280) == 4, "exp_280_is_lv4")
	_check(Progression.level_for_exp(3160) == 12, "exp_3160_is_lv12")
	_check(Progression.star_ranks_for_exp(3560) == 1, "exp_3560_grants_star_prestige_1")

	var st = STATE_SCRIPT.new()
	st.save_path = _test_dir + "/curve.json"
	st.load_state()
	_check(st.level() == 1 and st.exp_total() == 0 and int(st.data.coins) == 30, "fresh_state_lv1_30_coins")

	# Multi-level jump: 0 -> 300 EXP crosses Lv.2 (+15), Lv.3 (+18), Lv.4 (+20) = +53 gift coins!
	var res: Dictionary = st.grant_exp({"key": "big_milestone", "mode": "once", "base_exp": 300, "now_sec": 1000})
	_check(bool(res.get("leveled_up", false)) and st.level() == 4, "multi_level_jump_reaches_lv4")
	_check(int(res.get("gift_coins", 0)) == 15 + 18 + 20, "multi_level_jump_sums_all_gift_packs")
	_check(int(st.data.coins) == 30 + 53, "wallet_receives_cumulative_gift_coins")

	# Reaching Lv.12 + 1 Star Rank (3560 EXP total, delta 3260 EXP)
	var res_max: Dictionary = st.grant_exp({"key": "scholar_jump", "mode": "once", "base_exp": 3260, "now_sec": 1010})
	_check(st.level() == 12 and int(res_max.get("new_stars", 0)) == 1, "reaches_lv12_plus_star1")
	var expected_lv5_to_12 := 22 + 25 + 28 + 30 + 35 + 38 + 42 + 50
	_check(int(res_max.get("gift_coins", 0)) == expected_lv5_to_12 + 30, "lv12_and_star_prestige_gift_exact")
	st.free()


func _test_unit_antigrind_and_reviews() -> void:
	var st = STATE_SCRIPT.new()
	st.save_path = _test_dir + "/antigrind.json"
	st.load_state()

	# 1. Word study: first +10, immediate spam +0, due review after 60s +6, cooldown floor after 300s +1
	var w1: Dictionary = st.grant_exp({"key": "word_study:soap", "mode": "word_study", "base_exp": 10, "review_exp": 6, "repeat_exp": 1, "now_sec": 1000})
	_check(int(w1.get("exp_gained", 0)) == 10, "first_word_study_gives_10_exp")
	var w_spam: Dictionary = st.grant_exp({"key": "word_study:soap", "mode": "word_study", "base_exp": 10, "now_sec": 1020})
	_check(int(w_spam.get("exp_gained", 0)) == 0, "rapid_repeat_word_click_gives_zero_exp")
	var w_rev: Dictionary = st.grant_exp({"key": "word_study:soap", "mode": "word_study", "review_exp": 6, "is_due_review": true, "now_sec": 1080})
	_check(int(w_rev.get("exp_gained", 0)) == 6, "due_spaced_review_gives_6_exp")
	var w_floor: Dictionary = st.grant_exp({"key": "word_study:soap", "mode": "word_study", "repeat_exp": 1, "now_sec": 1400})
	_check(int(w_floor.get("exp_gained", 0)) == 1, "post_cooldown_repeat_gives_1_exp_floor")

	# 2. Daily repeat placement: first +18, same day +0, next day +5
	var p1: Dictionary = st.grant_exp({"key": "place:home_bathroom:2", "mode": "daily_repeat", "base_exp": 18, "repeat_exp": 5, "now_sec": 1500})
	var p_same: Dictionary = st.grant_exp({"key": "place:home_bathroom:2", "mode": "daily_repeat", "base_exp": 18, "repeat_exp": 5, "now_sec": 1600})
	_check(int(p1.get("exp_gained", 0)) == 18 and int(p_same.get("exp_gained", 0)) == 0, "placement_same_day_antigrind")
	st.next_day()
	var p_day2: Dictionary = st.grant_exp({"key": "place:home_bathroom:2", "mode": "daily_repeat", "base_exp": 18, "repeat_exp": 5, "now_sec": 2000})
	_check(int(p_day2.get("exp_gained", 0)) == 5, "placement_next_day_grants_5_review_exp")

	# 3. Stage 4 Dialogue at low level: freely playable (no hard lock!), grants base +50 EXP / +14 coins, badge deferred until Lv.9
	var d_early: Dictionary = st.grant_exp({
		"key": "dlg:school_s4_past_and_compare",
		"scenario_id": "school_s4_past_and_compare",
		"mode": "dialogue_clear",
		"stage": 4,
		"now_sec": 2100,
	})
	_check(int(d_early.get("exp_gained", 0)) == 50 and not bool(d_early.get("badge_earned", true)), "stage4_open_at_low_level_base_reward_without_badge")

	# Advance to Lv.9 (1640 EXP) and replay Stage 4 -> earns Mastery Badge (+4 practice + 20 badge = 24 EXP, +8 badge coins)!
	st.grant_exp({"key": "boost_to_lv9", "mode": "once", "base_exp": 1650, "now_sec": 2200})
	_check(st.level() >= 9, "boosted_to_lv9")
	var d_badge: Dictionary = st.grant_exp({
		"key": "dlg:school_s4_past_and_compare",
		"scenario_id": "school_s4_past_and_compare",
		"mode": "dialogue_clear",
		"stage": 4,
		"now_sec": 2300,
	})
	_check(bool(d_badge.get("badge_earned", false)) and int(d_badge.get("exp_gained", 0)) == 24, "replaying_stage4_at_lv9_lights_mastery_badge")
	st.free()


func _test_unit_wardrobe_and_furniture_dual_unlock() -> void:
	var st = STATE_SCRIPT.new()
	st.save_path = _test_dir + "/dual_unlock.json"
	st.load_state()
	st.data["coins"] = 200
	st.save_state()

	# Starter items owned at Lv.1; Lv.1 school_pack (12 coins) can be bought right away!
	_check(st.is_wardrobe_unlocked("outfit", "yellow"), "starter_yellow_owned")
	_check(not st.is_wardrobe_unlocked("bag", "school_pack"), "school_pack_initially_unowned")
	_check(st.unlock_wardrobe_item("bag", "school_pack", true) and int(st.data.coins) == 188, "lv1_school_pack_purchased_for_12_coins")

	# Lv.4 mint outfit (26 coins) rejected at Lv.1 even with 188 coins!
	_check(not st.unlock_wardrobe_item("outfit", "mint", true) and int(st.data.coins) == 188, "lv4_mint_outfit_blocked_at_lv1")

	# Lv.7 courtyard_swing (32 coins) rejected at Lv.1!
	_check(not st.buy_free_decor("courtyard_swing", 32) and int(st.data.coins) == 188, "lv7_swing_blocked_at_lv1")
	# Lv.1 sunflower_rug (12 coins) allowed at Lv.1!
	_check(st.buy_free_decor("sunflower_rug", 12) and int(st.data.coins) == 176, "lv1_sunflower_rug_allowed_at_lv1")

	# Level up to Lv.7 (940 EXP) -> mint outfit & courtyard_swing both unlockable!
	st.grant_exp({"key": "lv7_grant", "mode": "once", "base_exp": 950, "now_sec": 3000})
	_check(st.level() == 7, "reached_lv7")
	var c_before := int(st.data.coins)
	_check(st.unlock_wardrobe_item("outfit", "mint", true) and st.data.outfit == "mint" and int(st.data.coins) == c_before - 26, "lv4_mint_outfit_unlocked_and_equipped_at_lv7")
	_check(st.buy_free_decor("courtyard_swing", 32) and st.free_decor_owned_count("courtyard_swing") == 1, "lv7_swing_purchased_at_lv7")
	st.free()


func _test_unit_legacy_save_migration() -> void:
	var st = STATE_SCRIPT.new()
	st.save_path = _test_dir + "/legacy_v6.json"
	st.set_outfit("lavender")
	st.set_hat("bunny_ears")
	for i in range(1, 6):
		st.discover("home_study", i)
		st.discover("classroom", i)
	st.complete_v4_commission("v6_dlg:home_s1_study_dad", 6)
	st.complete_v4_commission("v6_dlg:school_s2_classroom_miss_li", 6)

	var legacy_snap: Dictionary = st.snapshot()
	var saved_coins := int(legacy_snap["coins"])
	legacy_snap.erase("progression")
	var f := FileAccess.open(st.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy_snap))
	f.close()

	var migrated = STATE_SCRIPT.new()
	migrated.save_path = st.save_path
	migrated.load_state()
	# 10 discoveries * 12 (120) + 2 commissions * 14 (28) = 148 EXP -> Lv.2, coins preserved!
	_check(migrated.exp_total() == 148 and migrated.level() == 2, "legacy_save_retroactive_exp_and_level")
	_check(int(migrated.data.coins) == saved_coins, "legacy_save_preserves_exact_coin_wallet")
	_check(migrated.is_wardrobe_unlocked("outfit", "lavender") and migrated.is_wardrobe_unlocked("hat", "bunny_ears"), "legacy_equipped_items_preserved_as_owned")
	st.free()
	migrated.free()


func _test_live_main_scene_integration() -> void:
	var main_scene := load("res://main.tscn") as PackedScene
	var game: Node3D = main_scene.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for _f: int in range(1200):
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready, "main_scene_ready")

	var state: Node = root.get_node("State")
	state.data = state._default_state()
	game.muted = true
	game.validation_mode = false
	game._refresh()
	_check(is_instance_valid(game.ui.exp_bar) and is_instance_valid(game.ui.level_chip_btn), "hud_has_exp_bar_and_level_badge")
	_check(str(game.ui.level_chip_btn.text).contains("Lv.1"), "hud_starts_at_lv1")

	# Explore home_study anchors 1 & 2 + bathroom anchor 2 -> crosses 60 EXP -> live Level-Up to Lv.2 (+15 gift coins)!
	await game.change_room("home_study")
	await _frames(4)
	game.interact_id("memory_01")
	await _frames(4)
	game.spatial_bench.select_bench_item("pen", true)
	game.spatial_bench.cycle_anchor(1)
	await _frames(3)
	game.spatial_bench.select_bench_item("storybook", true)
	game.spatial_bench.close_workbench()
	await _frames(3)

	_check(state.level() >= 2, "live_study_exploration_levels_up_to_lv2")
	_check(str(game.ui.level_chip_btn.text).contains("Lv.2"), "hud_level_badge_updates_to_lv2")
	_check(game.ui.hud.level_banner.visible, "level_up_celebration_banner_displayed")

	# Open Level & Economy Handbook (`level_guide`)
	game._on_action("level_guide")
	await _frames(2)
	_check(game.ui.current_panel == "level_guide" and game.ui.modal.visible, "level_guide_handbook_opens")
	game._close()
	await _frames(2)

	# Open Wardrobe (`bag`), switch to `hat` tab, unlock `straw_hat` (Lv.2, 16 coins) via UI action!
	game._on_action("bag")
	await _frames(2)
	game._on_action("wardrobe_tab:hat")
	await _frames(2)
	var coins_pre_hat := int(state.data.coins)
	game._on_action("wardrobe_unlock:hat:straw_hat")
	await _frames(2)
	_check(state.is_wardrobe_unlocked("hat", "straw_hat") and str(state.data.wardrobe.hat) == "straw_hat" and int(state.data.coins) == coins_pre_hat - 16, "live_wardrobe_dual_unlock_straw_hat")
	game._close()
	await _frames(2)

	# Verify Stage 4 school grammar dialogue is freely playable right at Lv.2 (soft-guided, not hard-locked!)
	game._on_action("v6_roleplay_stage:school_s4_past_and_compare")
	await _frames(2)
	_check(game.ui.current_panel == "v5_roleplay", "stage4_dialogue_freely_accessible_at_lv2")
	game._close()
	await _frames(2)

	game.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _sha(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<missing>"
	return FileAccess.get_sha256(path)


func _cleanup_test_dir() -> void:
	var abs_dir := ProjectSettings.globalize_path(_test_dir)
	var d := DirAccess.open(abs_dir)
	if d != null:
		for fn: String in d.get_files():
			d.remove(fn)
	DirAccess.remove_absolute(abs_dir)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("V7 ECON FAIL: " + label)
