extends SceneTree
## V6 Home & School Dual-Core English Immersion Verification Suite.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_v6_home_school_immersion.gd -- --test-harness

const CastDirector = preload("res://gameplay/home_school_cast_director.gd")
const SpatialBench = preload("res://gameplay/spatial_cluster_bench_3d.gd")
const Layer2Props = preload("res://actors/layer2_prop_library.gd")
const Roleplay = preload("res://gameplay/situational_roleplay.gd")
const CharacterVoices = preload("res://core/character_voices.gd")

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

var passed := 0
var failed := 0
var _prod_save_before := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func _frames(count: int = 3) -> void:
	for _i: int in range(count):
		await process_frame

func _sha(path: String) -> String:
	return FileAccess.get_sha256(path).to_lower() if FileAccess.file_exists(path) else ""

func _run() -> void:
	create_timer(180.0).timeout.connect(func():
		_check(false, "bounded_timeout")
		quit(1)
	)
	_prod_save_before = _sha("user://island-save-v1.json")
	root.size = Vector2i(1440, 900)

	# 1. Pure data & greeting diversity checks
	_verify_greetings_and_voices()
	_verify_cluster_and_dialogue_schemas()

	# 2. Live-mode integration checks inside full Main scene (isolated save via --test-harness)
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for _f: int in range(1200):
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready, "scene_ready")
	var state: Node = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-"), "isolated_validation_save")
	state.data = state._default_state()
	game.muted = true
	# Switch from harness validation_mode to live player sandbox mode!
	game.validation_mode = false

	# 2A. Verify Home cast: Mom in living room/kitchen, Dad in study, Doggie in yard, ZERO Uncle Bear!
	await game.change_room("home")
	await _frames(4)
	_check(game.living.get_actor("npc_bear_uncle") == null, "home_living_room_has_zero_bear_uncle")
	var mom_home: Node3D = game.living.get_actor("textbook_role_lingling_mother")
	_check(mom_home != null, "home_living_room_spawns_mom")
	if mom_home != null:
		_check(str(mom_home.get("display_name")).contains("妈妈"), "mom_displays_localized_parent_name")
	_check(game.spatial_bench.macro_plaques.size() == 5, "home_living_room_has_5_macro_furniture_plaques")

	# Click Mom in Home -> must open Mom's V6 conversation, NOT Uncle Bear's journey_home!
	game.interact_id("actor:textbook_role_lingling_mother")
	await _frames(3)
	_check(game.ui.diegetic.visible and str(game.ui.diegetic.current_npc_id) == "textbook_role_lingling_mother", "clicking_mom_opens_mom_diegetic_dialogue")
	game._close()

	# 2B. Study Room: Click Layer-1 `desk` (`memory_01`) -> Expand In-Room Layer-2 Close-Up (NO opaque modal!)
	await game.change_room("home_study")
	await _frames(4)
	_check(game.living.get_actor("npc_bear_uncle") == null, "study_has_zero_bear_uncle")
	var dad_study: Node3D = game.living.get_actor("textbook_role_lingling_father")
	_check(dad_study != null, "study_spawns_dad")
	if dad_study != null:
		_check(str(dad_study.get("display_name")).contains("爸爸"), "dad_displays_localized_parent_name")
	_check(game.spatial_bench.macro_plaques.size() == 5, "study_has_5_macro_furniture_plaques")
	var plaque_texts := ""
	for lbl: Label3D in game.spatial_bench.macro_plaques:
		plaque_texts += lbl.text + " | "
	_check(plaque_texts.contains("desk") and plaque_texts.contains("chair") and plaque_texts.contains("stool"), "study_plaques_teach_desk_chair_stool")

	var coins_before := int(state.data.coins)
	game.interact_id("memory_01")
	await _frames(6)
	_check(game.spatial_bench.bench_open and game.spatial_bench.bench_anchor_order == 1, "clicking_study_desk_opens_anchor_1_closeup")
	_check(not game.ui.modal.visible, "study_closeup_does_not_cover_room_with_modal")
	_check(game.spatial_bench.camera_size < 7.0, "study_closeup_zooms_real_room_camera")
	var r1: Dictionary = game.spatial_bench.select_bench_item("pen", true)
	_check(bool(r1.get("placed", false)) and game.spatial_bench.tasks_completed, "study_desk_pen_placement_succeeds")
	_check(int(state.data.coins) == coins_before + 4, "study_first_anchor_awards_4_leaf_coins")

	# Cycle to next Layer-1 furniture (`bookcase`, anchor 2) right inside the room!
	game.spatial_bench.cycle_anchor(1)
	await _frames(4)
	_check(game.spatial_bench.bench_anchor_order == 2, "cycle_anchor_moves_to_bookcase")
	var r2: Dictionary = game.spatial_bench.select_bench_item("storybook", true)
	_check(bool(r2.get("placed", false)) and int(state.data.coins) >= coins_before + 6, "study_second_anchor_bookcase_awards_bonus_coins_and_levelup")
	game.spatial_bench.close_workbench()
	await _frames(2)
	_check(not game.spatial_bench.bench_open and game.ui.hud.visible and game.player.visual.visible, "closing_closeup_restores_hud_and_player")

	# 2B-2. Bathroom (`home_bathroom`): Click Layer-1 `washbasin` (`memory_02`) -> Unfolds DIRECTLY on the real washbasin (zero fake table)!
	await game.change_room("home_bathroom")
	await _frames(4)
	game.interact_id("memory_02")
	await _frames(6)
	_check(game.spatial_bench.bench_open and game.spatial_bench.bench_anchor_order == 2 and not game.ui.modal.visible, "bathroom_washbasin_expands_in_place")
	_check(game.spatial_bench.camera_size <= 4.5, "bathroom_washbasin_tight_closeup_camera")
	var soap_node: Node3D = game.spatial_bench._prop_nodes.get("soap", null)
	var water_node: Node3D = game.spatial_bench._prop_nodes.get("water", null)
	_check(soap_node != null and water_node != null and soap_node.global_position.y >= 1.05 and water_node.global_position.y >= 1.05, "bathroom_washbasin_layer2_sits_on_real_sink")
	var r_soap: Dictionary = game.spatial_bench.select_bench_item("soap", true)
	_check(bool(r_soap.get("placed", false)), "bathroom_washbasin_soap_placement_succeeds")
	game.spatial_bench.close_workbench()
	await _frames(2)

	# 2B-3. Bedroom (`home_bedroom`): Click Layer-1 `wardrobe` (`memory_03`) -> Doors swing open, clothes hang inside!
	await game.change_room("home_bedroom")
	await _frames(4)
	game.interact_id("memory_03")
	await _frames(6)
	_check(game.spatial_bench.bench_open and game.spatial_bench.bench_anchor_order == 3 and not game.ui.modal.visible, "bedroom_wardrobe_expands_in_room_layer2")
	_check(game.spatial_bench._hidden_anchor_meshes.size() >= 2, "bedroom_wardrobe_hides_closed_door_panels")
	_check(game.spatial_bench._stage_root.get_node_or_null("OpenWardrobeCarcass") != null, "bedroom_wardrobe_builds_open_carcass")
	var r_coat: Dictionary = game.spatial_bench.select_bench_item("coat", true)
	_check(bool(r_coat.get("placed", false)), "bedroom_wardrobe_coat_placement_succeeds")
	game.spatial_bench.close_workbench()
	await _frames(2)
	_check(game.spatial_bench._hidden_anchor_meshes.is_empty(), "closing_wardrobe_restores_original_door_panels")

	# 2C. Kitchen, Dining, Yard, Classroom, Science, Playground Cast Checks
	for pair: Array in [
		["home_kitchen", "textbook_role_lingling_mother"],
		["home_dining", "textbook_role_lingling_father"],
		["home_estate", "textbook_doggie"],
		["classroom", "textbook_miss_li"],
		["music_room", "textbook_miss_lin"],
		["science_room", "textbook_mr_chen"],
		["playground", "textbook_peter"],
		["football_field", "textbook_mr_wang"],
	]:
		var rid: String = pair[0]
		var expected_actor: String = pair[1]
		await game.change_room(rid)
		await _frames(4)
		_check(game.living.get_actor(expected_actor) != null, "cast_present_%s_%s" % [rid, expected_actor])
		if rid.begins_with("home"):
			_check(game.living.get_actor("npc_bear_uncle") == null, "no_bear_in_" + rid)

	# 2D. 4-Stage Progressive Textbook Grammar & Tense Dialogues (Home & School)
	await game.change_room("home_study")
	await _frames(2)
	var rec1 := Roleplay.recommended_v6_scenario(game, "home_study", "textbook_role_lingling_father")
	_check(str(rec1.get("id", "")) == "home_s1_study_dad" and int(rec1.get("stage", 0)) == 1, "study_starts_at_stage_1_with_dad")

	await _play_v6_scenario_to_completion(game, "home_s1_study_dad")
	await _play_v6_scenario_to_completion(game, "home_s2_continuous_mom")
	await _play_v6_scenario_to_completion(game, "school_s3_plan_and_canteen")
	await _play_v6_scenario_to_completion(game, "school_s4_past_and_compare")

	var done_ids := Roleplay.completed_v6_ids(state)
	_check(done_ids.has("home_s1_study_dad") and done_ids.has("home_s2_continuous_mom") and done_ids.has("school_s3_plan_and_canteen") and done_ids.has("school_s4_past_and_compare"), "v6_stage_completions_persisted")
	var rec_after := Roleplay.recommended_v6_scenario(game, "home_study", "textbook_role_lingling_father")
	_check(int(rec_after.get("stage", 0)) == 3, "study_recommendation_progresses_to_stage_3_future_tense")

	# Open 4-Stage Grammar Ladder Selector modal
	game._on_action("v6_ladder_open:school")
	await _frames(3)
	_check(game.ui.current_panel == "v6_grammar_ladder" and game.ui.modal.visible, "school_4_stage_grammar_ladder_opens")
	game._close()

	# 3. Immutable file integrity guard
	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_immutable")
	_check(_sha("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA, "prologue_json_immutable")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "production_save_untouched")

	game.queue_free()
	await process_frame
	print("V6 Home & School Immersion Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _verify_greetings_and_voices() -> void:
	var probes := [
		["home", {"character_id": "textbook_role_lingling_mother"}],
		["home_kitchen", {"character_id": "textbook_role_lingling_mother"}],
		["home_study", {"character_id": "textbook_role_lingling_father"}],
		["classroom", {"character_id": "textbook_miss_li"}],
		["school", {"character_id": "textbook_lingling"}],
		["playground", {"character_id": "textbook_peter"}],
		["science_room", {"character_id": "textbook_mr_chen"}],
		["football_field", {"character_id": "textbook_mr_wang"}],
		["village", {"id": "baker"}],
		["landmark_A", {"resident_id": "resident_a"}],
		["landmark_Z", {"resident_id": "resident_z"}],
	]
	var seen_en: Dictionary = {}
	for p: Array in probes:
		var g := CastDirector.pick_proximity_greeting(str(p[0]), p[1] as Dictionary, 0)
		var en := str(g.get("en", ""))
		_check(not en.is_empty() and not seen_en.has(en), "unique_contextual_greeting_" + str(p[0]))
		seen_en[en] = true

	_check(CharacterVoices.archetype_for("textbook_role_lingling_mother") != CharacterVoices.archetype_for("textbook_role_lingling_father"), "mom_and_dad_have_distinct_voice_archetypes")
	_check(CharacterVoices.archetype_for("textbook_miss_li") != CharacterVoices.archetype_for("textbook_peter"), "teacher_and_boy_classmate_have_distinct_voices")
	_check(CharacterVoices.archetype_for("textbook_mr_chen") != CharacterVoices.archetype_for("textbook_lingling"), "science_teacher_and_girl_classmate_have_distinct_voices")

func _verify_cluster_and_dialogue_schemas() -> void:
	var expected_16 := CastDirector.HOME_ROOMS + CastDirector.SCHOOL_ROOMS
	_check(expected_16.size() == 16, "16_home_and_school_rooms_defined")
	for rid: String in expected_16:
		var cl := SpatialBench.cluster_for_room(rid)
		_check(not cl.is_empty(), "cluster_exists_" + rid)
		var macros: Array = cl.get("macro_items", [])
		_check(macros.size() == 5, "5_macro_anchors_populated_" + rid)
		for m_v: Variant in macros:
			var md: Dictionary = m_v as Dictionary
			var l2: Array = md.get("layer2_items", [])
			var sspec: Dictionary = md.get("stage_spec", {}) if md.get("stage_spec") is Dictionary else {}
			var sslots: Array = sspec.get("slots", []) if sspec.get("slots") is Array else []
			_check(l2.size() >= 3, "anchor_has_layer2_%s_%s" % [rid, str(md.get("word", ""))])
			_check(sslots.size() >= l2.size() and float(sspec.get("camera_size", 99.0)) <= 6.0, "anchor_has_real_scene_stage_spec_%s_%s" % [rid, str(md.get("word", ""))])
			_check((md.get("placement_task", {}) as Dictionary).has("item"), "anchor_has_placement_%s_%s" % [rid, str(md.get("word", ""))])

	# Verify Blender 5.2 GLB Layer-2 library + 100% GLB instantiation across all 287 Layer-2 items
	_check(Layer2Props.entries().size() == 92, "layer2_blender_manifest_has_92_glbs")
	_check(Layer2Props.resolve_model_id("tripo_bread", "chicken") == "chicken", "chicken_resolves_to_chicken_glb")
	_check(Layer2Props.resolve_model_id("star", "bee") == "bee", "bee_resolves_to_bee_glb")
	_check(Layer2Props.resolve_model_id("star", "wind") == "pinwheel", "wind_resolves_to_pinwheel_glb")
	_check(Layer2Props.resolve_model_id("cake", "hamburger") == "hamburger", "hamburger_resolves_to_hamburger_glb")
	_check(Layer2Props.resolve_model_id("violin", "guitar") == "guitar", "guitar_resolves_to_guitar_glb")
	_check(Layer2Props.resolve_model_id("ball", "football") == "football", "football_resolves_to_football_glb")
	_check(Layer2Props.resolve_model_id("ball", "basketball") == "basketball", "basketball_resolves_to_basketball_glb")
	_check(Layer2Props.resolve_model_id("quilt", "sweater") == "sweater", "sweater_resolves_to_sweater_glb")
	_check(Layer2Props.resolve_model_id("cup", "red") == "paint_jar", "art_paint_pot_resolves_to_paint_jar_glb")

	var probe_bench := SpatialBench.new()
	var total_l2 := 0
	var glb_backed := 0
	for rid2: String in expected_16:
		var cl2 := SpatialBench.cluster_for_room(rid2)
		for m_v2: Variant in cl2.get("macro_items", []):
			var md2: Dictionary = m_v2 as Dictionary
			var smode := str((md2.get("stage_spec", {}) as Dictionary).get("mode", "surface"))
			for it_v: Variant in md2.get("layer2_items", []):
				var it_d: Dictionary = it_v as Dictionary
				total_l2 += 1
				var w2 := str(it_d.get("word", "")).to_lower()
				var node3d := probe_bench._build_layer2_prop(str(it_d.get("shape", "book")), str(it_d.get("color", "5b9bd5")), w2, smode)
				var src_meta := str(node3d.get_meta("source_asset", ""))
				if src_meta.begins_with("l2_") or src_meta.begins_with("prop_"):
					glb_backed += 1
				node3d.free()
	probe_bench.free()
	_check(total_l2 == 287 and glb_backed == 287, "all_287_layer2_items_backed_by_real_glb_meshes")

	var all_sc := Roleplay.all_v6_scenarios()
	_check(all_sc.size() >= 12, "at_least_12_v6_scenarios")
	for dom: String in ["home", "school"]:
		var stages_seen: Dictionary = {}
		for sc: Dictionary in Roleplay.v6_scenarios_for_domain(dom):
			stages_seen[int(sc.get("stage", 0))] = true
		_check(stages_seen.has(1) and stages_seen.has(2) and stages_seen.has(3) and stages_seen.has(4), "all_4_stages_covered_" + dom)

func _play_v6_scenario_to_completion(game: Node3D, scenario_id: String) -> void:
	game._on_action("v6_roleplay_stage:" + scenario_id)
	await _frames(2)
	var scen := Roleplay.get_scenario(scenario_id, game)
	var turns: Array = scen.get("turns", [])
	for t_idx: int in range(turns.size()):
		var choices: Array = (turns[t_idx] as Dictionary).get("choices", [])
		# On turn 0, test picking a wrong option first to verify gentle grammar scaffold!
		if t_idx == 0:
			for c_idx: int in range(choices.size()):
				if not bool((choices[c_idx] as Dictionary).get("ok", false)):
					Roleplay.handle_pick(game, "%s:%d:%d" % [scenario_id, t_idx, c_idx])
					await _frames(1)
					_check(game.ui.current_panel == "v5_roleplay", "distractor_keeps_turn_open_" + scenario_id)
					break
		var picked_ok := false
		for c_idx: int in range(choices.size()):
			if bool((choices[c_idx] as Dictionary).get("ok", false)):
				Roleplay.handle_pick(game, "%s:%d:%d" % [scenario_id, t_idx, c_idx])
				picked_ok = true
				await _frames(1)
				break
		_check(picked_ok, "picked_correct_choice_%s_t%d" % [scenario_id, t_idx])
	_check(game.ui.current_panel == "v5_roleplay_done", "scenario_completed_" + scenario_id)
	game._close()
