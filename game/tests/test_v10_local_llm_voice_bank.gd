extends SceneTree
## V10 Local GPU Voice-Designed Offline Bank (`assets/voice_bank_v10/`) Verification Suite.
## Verifies 26 bilingual VoiceDesign anchors, 3,180 manifest keys, high hit rate across
## Mom, Dad, Miss Li, Kitty/Doggie (`storyteller` + stripped interjection), Dino, Parrot,
## 34 Landmark & Campus Residents, V6/V5 Roleplay scenarios, and all 16-room Spatial Word
## Clusters in BOTH `"natural"` and `"slow"` modes, plus `AudioStreamOggVorbis` decoding.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_v10_local_llm_voice_bank.gd -- --test-harness

const AICompanionBridgeScript = preload("res://core/ai_companion_bridge.gd")
const CharacterVoices = preload("res://core/character_voices.gd")
const CastDirector = preload("res://gameplay/home_school_cast_director.gd")
const Residents = preload("res://actors/building_resident_catalog.gd")
const SpatialBench = preload("res://gameplay/spatial_cluster_bench_3d.gd")
const Roleplay = preload("res://gameplay/situational_roleplay.gd")

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

const ALL_13_ARCHETYPES := [
	"mother_affectionate",
	"father_warm",
	"teacher_gentle",
	"storyteller",
	"boy_sunny",
	"girl_bright",
	"uncle_warm",
	"elder_wise",
	"grandma_warm",
	"artisan_male",
	"artisan_female",
	"mascot_dino",
	"mascot_parrot",
]

const ALL_16_ROOMS := [
	"home_estate",
	"home",
	"home_bedroom",
	"home_kitchen",
	"home_dining",
	"home_bathroom",
	"home_study",
	"home_balcony",
	"school",
	"classroom",
	"music_room",
	"art_room",
	"science_room",
	"canteen",
	"playground",
	"football_field",
]

var passed := 0
var failed := 0
var _prod_save_before := ""
var _total_queries := 0
var _hit_queries := 0
var _sample_pairs: Dictionary = {} # key -> {"nat": path, "slow": path, "arch": arch}


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("V10_VOICE_BANK FAIL: " + label)


func _sha(path: String) -> String:
	return FileAccess.get_sha256(path).to_lower() if FileAccess.file_exists(path) else ""


func _probe_both_speeds(bridge: Node, text: String, lang: String, voice_hint: String) -> bool:
	if text.strip_edges().is_empty():
		return true
	_total_queries += 2
	var r_nat: Dictionary = bridge.find_prebaked_voice_clip(text, lang, voice_hint, "natural")
	var r_slow: Dictionary = bridge.find_prebaked_voice_clip(text, lang, voice_hint, "slow")
	var hit_nat := bool(r_nat.get("hit", false))
	var hit_slow := bool(r_slow.get("hit", false))
	if hit_nat:
		_hit_queries += 1
	if hit_slow:
		_hit_queries += 1
	if hit_nat and hit_slow:
		var arch := str(r_nat.get("archetype", ""))
		var bucket_key := arch + "|" + lang
		if not _sample_pairs.has(bucket_key) or _sample_pairs.size() < 120:
			var pair_id := str(r_nat.get("path", ""))
			if not _sample_pairs.has(pair_id):
				_sample_pairs[pair_id] = {
					"nat": str(r_nat.get("path", "")),
					"slow": str(r_slow.get("path", "")),
					"arch": arch,
				}
	return hit_nat and hit_slow


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

	var bridge := AICompanionBridgeScript.new()
	root.add_child(bridge)
	await process_frame

	bridge.reload_voice_bank_manifest(true)
	var bank_dir: String = bridge._voice_bank_dir_resolved
	_check(not bank_dir.is_empty() and FileAccess.file_exists(bank_dir.path_join("manifest.json")), "voice_bank_v10_manifest_found")
	_check(bridge._voice_bank_entries.size() >= 3000, "voice_bank_v10_has_over_3000_keys")

	# 1. Verify all 26 Golden VoiceDesign Master Anchors exist and are non-empty WAVs
	var anchor_count := 0
	for arch: String in ALL_13_ARCHETYPES:
		for lang: String in ["en", "zh"]:
			var apath := bank_dir.path_join("anchors/%s_%s.wav" % [arch, lang])
			var exists := FileAccess.file_exists(apath)
			var fsize := FileAccess.get_file_as_bytes(apath).size() if exists else 0
			if exists and fsize > 10000:
				anchor_count += 1
	_check(anchor_count == 26, "all_26_bilingual_voice_design_anchors_exist")

	# 2. Explicit Cast, Animal (Kitty/Doggie stripped -> storyteller), and Mascot (Dino/Parrot) assertions
	_check(_probe_both_speeds(bridge, "Welcome home, sweetie! Come and sit on the soft sofa!", "en", "textbook_role_lingling_mother"), "mom_greeting_en_hits_bank")
	_check(_probe_both_speeds(bridge, "欢迎回家呀宝贝！过来坐到松软的沙发上歇一歇吧！", "zh", "textbook_role_lingling_mother"), "mom_greeting_zh_hits_bank")
	_check(_probe_both_speeds(bridge, "Look at this sunny wooden desk! Ready to read an English book together?", "en", "textbook_role_lingling_father"), "dad_greeting_en_hits_bank")
	_check(_probe_both_speeds(bridge, "Good morning, class! Please sit down and open your English books!", "en", "textbook_miss_li"), "miss_li_greeting_en_hits_bank")

	# Kitty & Doggie: verify BOTH raw interjection + pet id AND stripped sentence + `storyteller` hit `storyteller` bank!
	var kitty_raw: Dictionary = bridge.find_prebaked_voice_clip("Meow! Kitty is resting on the soft warm sofa!", "en", "textbook_kitty", "natural")
	var kitty_stripped: Dictionary = bridge.find_prebaked_voice_clip("Kitty is resting on the soft warm sofa!", "en", "storyteller", "slow")
	_check(bool(kitty_raw.get("hit", false)) and str(kitty_raw.get("archetype", "")) == "storyteller", "kitty_raw_meow_hits_storyteller_bank")
	_check(bool(kitty_stripped.get("hit", false)) and str(kitty_stripped.get("archetype", "")) == "storyteller", "kitty_stripped_sentence_hits_storyteller_slow_bank")

	var doggie_raw: Dictionary = bridge.find_prebaked_voice_clip("Woof woof! Look, Doggie loves running in the sunny garden!", "en", "textbook_doggie", "natural")
	var doggie_zh: Dictionary = bridge.find_prebaked_voice_clip("汪汪！快看，小狗最喜欢在阳光花园里奔跑啦！", "zh", "textbook_doggie", "slow")
	_check(bool(doggie_raw.get("hit", false)) and str(doggie_raw.get("archetype", "")) == "storyteller", "doggie_raw_woof_hits_storyteller_bank")
	_check(bool(doggie_zh.get("hit", false)) and str(doggie_zh.get("archetype", "")) == "storyteller", "doggie_zh_hits_storyteller_slow_bank")

	# Dino & Parrot talking mascots
	var dino_hit: Dictionary = bridge.find_prebaked_voice_clip("Hello, friend! Let's count bright stars and read English words together!", "en", "textbook_dino", "natural")
	var parrot_hit: Dictionary = bridge.find_prebaked_voice_clip("Hello! Nice sunny hat!", "en", "textbook_role_xiaoxiao_parrot", "slow")
	_check(bool(dino_hit.get("hit", false)) and str(dino_hit.get("archetype", "")) == "mascot_dino", "dino_hits_mascot_dino_bank")
	_check(bool(parrot_hit.get("hit", false)) and str(parrot_hit.get("archetype", "")) == "mascot_parrot", "parrot_hits_mascot_parrot_bank")

	# Sweep all CastDirector PROXIMITY_GREETINGS & ACTOR_PERSONAS
	var cast_misses := 0
	for k: String in CastDirector.PROXIMITY_GREETINGS.keys():
		var speaker_id := k.split("@")[0]
		for row_v: Variant in CastDirector.PROXIMITY_GREETINGS[k]:
			var row := row_v as Dictionary
			if not _probe_both_speeds(bridge, str(row.get("en", "")), "en", speaker_id):
				cast_misses += 1
			if not _probe_both_speeds(bridge, str(row.get("zh", "")), "zh", speaker_id):
				cast_misses += 1
	for actor_id: String in CastDirector.ACTOR_PERSONAS.keys():
		var p: Dictionary = CastDirector.ACTOR_PERSONAS[actor_id]
		if not _probe_both_speeds(bridge, str(p.get("open_en", "")), "en", actor_id):
			cast_misses += 1
		if not _probe_both_speeds(bridge, str(p.get("open_zh", "")), "zh", actor_id):
			cast_misses += 1
	_check(cast_misses == 0, "all_cast_greetings_and_personas_hit_100pct")

	# 3. Sweep all 34 Building & Campus Landmark Residents (`resident_opening` + `pick_proximity_greeting`)
	var resident_misses := 0
	var all_res := Residents.all()
	_check(all_res.size() == 34, "catalog_has_34_residents")
	for res_id: String in all_res.keys():
		var prof: Dictionary = all_res[res_id]
		var r_room := str(prof.get("room_id", "village"))
		var opening := CastDirector.resident_opening(r_room, res_id, prof)
		if not _probe_both_speeds(bridge, str(opening.get("en", "")), "en", res_id):
			resident_misses += 1
		if not _probe_both_speeds(bridge, str(opening.get("zh", "")), "zh", res_id):
			resident_misses += 1
		for turn_idx: int in [0, 1]:
			var pg := CastDirector.pick_proximity_greeting(r_room, {"resident_id": res_id}, turn_idx)
			if not _probe_both_speeds(bridge, str(pg.get("en", "")), "en", res_id):
				resident_misses += 1
			if not _probe_both_speeds(bridge, str(pg.get("zh", "")), "zh", res_id):
				resident_misses += 1
	_check(resident_misses == 0, "all_34_landmark_and_campus_residents_hit_100pct")

	# 4. Sweep all V6 (`home_school_dialogues_v6.json`) & V5 (`Roleplay.SCENARIOS`) Roleplay Scenarios
	var roleplay_misses := 0
	var v6_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/home_school_dialogues_v6.json"))
	if v6_raw is Dictionary:
		var scen_map: Dictionary = (v6_raw as Dictionary).get("scenarios", {})
		for sid: String in scen_map.keys():
			var sc: Dictionary = scen_map[sid]
			var npc_id := str(sc.get("npc_id", "warm"))
			for tv: Variant in sc.get("turns", []):
				var td := tv as Dictionary
				if not _probe_both_speeds(bridge, str(td.get("npc_en", "")), "en", npc_id):
					roleplay_misses += 1
				if not _probe_both_speeds(bridge, str(td.get("npc_zh", "")), "zh", npc_id):
					roleplay_misses += 1
			if sc.has("finale_en") and not _probe_both_speeds(bridge, str(sc.get("finale_en", "")), "en", npc_id):
				roleplay_misses += 1
			if sc.has("finale_zh") and not _probe_both_speeds(bridge, str(sc.get("finale_zh", "")), "zh", npc_id):
				roleplay_misses += 1
	for v5_id: String in Roleplay.SCENARIOS.keys():
		var sc5: Dictionary = Roleplay.SCENARIOS[v5_id]
		var npc5 := str(sc5.get("npc_id", "warm"))
		for tv5: Variant in sc5.get("turns", []):
			var td5 := tv5 as Dictionary
			if not _probe_both_speeds(bridge, str(td5.get("en", "")), "en", npc5):
				roleplay_misses += 1
			if not _probe_both_speeds(bridge, str(td5.get("zh", "")), "zh", npc5):
				roleplay_misses += 1
		if not _probe_both_speeds(bridge, str(sc5.get("finale_en", "")), "en", npc5):
			roleplay_misses += 1
		if not _probe_both_speeds(bridge, str(sc5.get("finale_zh", "")), "zh", npc5):
			roleplay_misses += 1
	_check(roleplay_misses == 0, "all_v6_and_v5_roleplay_scenarios_hit_100pct")

	# 5. Sweep ALL 16-Room Spatial Word Clusters (Layer-1 + Layer-2 words, `...` & `.` sentences, ZH explanations, tidy prompts, errand prompts)
	var cluster_misses := 0
	for rid: String in ALL_16_ROOMS:
		var cl := SpatialBench.cluster_for_room(rid)
		var comp_id := str(cl.get("companion_npc_id", "warm"))
		for mv: Variant in cl.get("macro_items", []):
			var md := mv as Dictionary
			var mw := str(md.get("word", ""))
			var mzh := str(md.get("zh", ""))
			var m_en := str(md.get("sentence_en", ""))
			var m_szh := str(md.get("sentence_zh", ""))
			if not _probe_both_speeds(bridge, mw, "en", comp_id): cluster_misses += 1
			if not _probe_both_speeds(bridge, "%s... %s" % [mw, m_en], "en", comp_id): cluster_misses += 1
			if not _probe_both_speeds(bridge, "%s. %s" % [mw, m_en], "en", comp_id): cluster_misses += 1
			if not _probe_both_speeds(bridge, "%s，意思是%s。%s" % [mw, mzh, m_szh], "zh", comp_id): cluster_misses += 1
			for sv: Variant in md.get("placement_steps", []):
				var sd := sv as Dictionary
				if not _probe_both_speeds(bridge, str(sd.get("prompt_en", "")), "en", comp_id):
					cluster_misses += 1
			for lv: Variant in md.get("layer2_items", []):
				var ld := lv as Dictionary
				var lw := str(ld.get("word", ""))
				var lzh := str(ld.get("zh", ""))
				var l_en := str(ld.get("sentence_en", ""))
				var l_szh := str(ld.get("sentence_zh", ""))
				if not _probe_both_speeds(bridge, lw, "en", comp_id): cluster_misses += 1
				if not _probe_both_speeds(bridge, "%s... %s" % [lw, l_en], "en", comp_id): cluster_misses += 1
				if not _probe_both_speeds(bridge, "%s. %s" % [lw, l_en], "en", comp_id): cluster_misses += 1
				if not _probe_both_speeds(bridge, "%s，意思是%s。%s" % [lw, lzh, l_szh], "zh", comp_id): cluster_misses += 1
				if not _probe_both_speeds(bridge, "Can you find the %s here?" % lw.to_lower(), "en", comp_id): cluster_misses += 1
	_check(cluster_misses == 0, "all_16_room_spatial_clusters_hit_100pct")

	var hit_rate_pct := (100.0 * float(_hit_queries)) / float(maxi(1, _total_queries))
	print("V10_HIT_RATE: %d / %d (%.2f%%)" % [_hit_queries, _total_queries, hit_rate_pct])
	_check(hit_rate_pct >= 99.5, "overall_prebaked_hit_rate_above_99_5_pct")

	# 6. Decode 120+ distinct `.ogg` pairs via `AudioStreamOggVorbis.load_from_file` & verify `slow >= 1.15x natural`
	_check(_sample_pairs.size() >= 80, "sampled_at_least_80_distinct_ogg_pairs")
	var decode_ok := 0
	var ratio_ok := 0
	var min_ratio := 999.0
	for pair_v: Variant in _sample_pairs.values():
		var pair := pair_v as Dictionary
		var nat_stream := AudioStreamOggVorbis.load_from_file(str(pair["nat"]))
		var slow_stream := AudioStreamOggVorbis.load_from_file(str(pair["slow"]))
		if nat_stream != null and slow_stream != null and nat_stream.get_length() > 0.25:
			decode_ok += 1
			var r := slow_stream.get_length() / nat_stream.get_length()
			min_ratio = minf(min_ratio, r)
			if r >= 1.15:
				ratio_ok += 1
	_check(decode_ok == _sample_pairs.size(), "all_sampled_ogg_streams_decode_validly_in_godot")
	_check(ratio_ok == _sample_pairs.size(), "all_sampled_slow_ogg_streams_at_least_1_15x_natural")
	print("V10_OGG_DECODE: %d/%d decoded, min_slow_ratio=%.3fx" % [decode_ok, _sample_pairs.size(), min_ratio])

	# 7. Immutable SHA-256 checks
	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_untouched")
	_check(_sha("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA, "prologue_json_untouched")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "user_save_untouched")

	bridge.queue_free()
	await process_frame
	print("V10 Local LLM Voice Bank Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
