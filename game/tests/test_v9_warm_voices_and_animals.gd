extends SceneTree
## V9 Warm Character Voices, Dedicated Animal Soundbank, Cast Pet Routing & Child Speed Toggle Test Suite.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_v9_warm_voices_and_animals.gd -- --test-harness

const CharacterVoices = preload("res://core/character_voices.gd")
const AudioDirectorScript = preload("res://core/audio_director.gd")
const CastDirector = preload("res://gameplay/home_school_cast_director.gd")

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

const ANIMAL_WAV_KEYS := [
	"kitty_meow",
	"puppy_woof",
	"bunny_chirp",
	"bird_tweet",
	"elephant_toot",
	"dino_chirp",
	"parrot_squawk",
]

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
		push_error("V9 FAIL: " + label)


func _frames(count: int = 4) -> void:
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
	root.size = Vector2i(1440, 900)

	_test_character_voice_archetypes_and_helpers()
	_test_seven_animal_wavs_decode_cleanly()
	_test_cast_director_pet_speaker_preservation()
	await _test_live_pet_audio_speed_toggle_and_bounds()

	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_untouched")
	_check(_sha("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA, "prologue_json_untouched")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "user_save_untouched")

	print("V9 Warm Voices + Animal Soundbank Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_character_voice_archetypes_and_helpers() -> void:
	var required_archetypes := [
		"mother_affectionate",
		"father_warm",
		"teacher_gentle",
		"storyteller",
		"boy_sunny",
		"girl_bright",
		"mascot_dino",
		"mascot_parrot",
	]
	for arch: String in required_archetypes:
		_check(CharacterVoices.ARCHETYPES.has(arch), "has_archetype_" + arch)

	_check(CharacterVoices.archetype_for("textbook_role_lingling_mother") == "mother_affectionate", "mom_maps_to_mother_affectionate")
	_check(CharacterVoices.label_zh_for("textbook_role_lingling_mother") == "温柔妈妈音", "mom_label_zh")
	_check(CharacterVoices.archetype_for("textbook_role_lingling_father") == "father_warm", "dad_maps_to_father_warm")
	_check(CharacterVoices.label_zh_for("textbook_role_lingling_father") == "暖心爸爸音", "dad_label_zh")
	_check(CharacterVoices.archetype_for("textbook_miss_li") == "teacher_gentle", "miss_li_maps_to_teacher_gentle")
	_check(CharacterVoices.archetype_for("textbook_miss_lin") == "teacher_gentle", "miss_lin_maps_to_teacher_gentle")
	_check(CharacterVoices.archetype_for("textbook_peter") == "boy_sunny", "peter_maps_to_boy_sunny")
	_check(CharacterVoices.archetype_for("textbook_lingling") == "girl_bright", "lingling_maps_to_girl_bright")
	_check(CharacterVoices.archetype_for("textbook_peter") != CharacterVoices.archetype_for("textbook_lingling"), "boy_distinct_from_girl")
	_check(not is_equal_approx(CharacterVoices.fallback_pitch_scale("textbook_peter"), CharacterVoices.fallback_pitch_scale("textbook_lingling")), "boy_fallback_pitch_distinct_from_girl")
	_check(CharacterVoices.archetype_for("textbook_dino") == "mascot_dino", "dino_maps_to_mascot_dino")
	_check(CharacterVoices.label_zh_for("textbook_dino") == "奇幻小恐龙音", "dino_label_zh")
	_check(CharacterVoices.archetype_for("textbook_role_xiaoxiao_parrot") == "mascot_parrot", "parrot_maps_to_mascot_parrot")
	_check(CharacterVoices.label_zh_for("textbook_role_xiaoxiao_parrot") == "俏皮小鹦鹉音", "parrot_label_zh")

	var pure_animals := [
		"textbook_kitty",
		"textbook_doggie",
		"textbook_spot",
		"textbook_bunny",
		"textbook_baker_bird",
		"textbook_elephant_ella",
		"textbook_fendi",
	]
	for pet_id: String in pure_animals:
		_check(CharacterVoices.is_pure_animal(pet_id), "is_pure_animal_" + pet_id)
		_check(not CharacterVoices.is_talking_mascot(pet_id), "pure_animal_not_mascot_" + pet_id)
		_check(CharacterVoices.archetype_for(pet_id) == "storyteller", "pure_animal_routes_to_storyteller_" + pet_id)
		_check(CharacterVoices.speaker_badge_label_zh(pet_id) == "萌宠原声 · 绘本姐姐慢读", "pure_animal_badge_" + pet_id)
		_check(not CharacterVoices.animal_sound_key(pet_id).is_empty(), "pure_animal_has_sfx_" + pet_id)

	_check(CharacterVoices.is_talking_mascot("textbook_dino") and CharacterVoices.animal_sound_key("textbook_dino") == "dino_chirp", "dino_is_talking_mascot_with_chirp")
	_check(CharacterVoices.is_talking_mascot("textbook_role_xiaoxiao_parrot") and CharacterVoices.animal_sound_key("textbook_role_xiaoxiao_parrot") == "parrot_squawk", "parrot_is_talking_mascot_with_squawk")
	_check(not CharacterVoices.is_pure_animal("textbook_role_lingling_mother") and CharacterVoices.animal_sound_key("textbook_role_lingling_mother") == "", "human_has_no_animal_sfx")
	_check(CharacterVoices.speaker_badge_label_zh("textbook_role_lingling_mother") == "温柔妈妈音", "mom_speaker_badge_label")
	_check(CharacterVoices.speaker_badge_label_zh("textbook_dino") == "奇幻小恐龙音", "dino_speaker_badge_label")

	# Interjection stripping (EN + ZH)
	_check(CharacterVoices.strip_animal_interjection("Meow! Kitty is resting on the soft warm sofa!", "en") == "Kitty is resting on the soft warm sofa!", "strip_en_meow")
	_check(CharacterVoices.strip_animal_interjection("Woof woof! Look, Doggie loves running in the sunny garden!", "en") == "Look, Doggie loves running in the sunny garden!", "strip_en_woof_woof")
	_check(CharacterVoices.strip_animal_interjection("喵～小猫正窝在柔软温暖的沙发上休息呢！", "zh") == "小猫正窝在柔软温暖的沙发上休息呢！", "strip_zh_miao")
	_check(CharacterVoices.strip_animal_interjection("汪汪！快看，小狗最喜欢在阳光花园里奔跑啦！", "zh") == "快看，小狗最喜欢在阳光花园里奔跑啦！", "strip_zh_wangwang")
	_check(CharacterVoices.strip_animal_interjection("Welcome home, sweetie!", "en") == "Welcome home, sweetie!", "human_text_unchanged_by_strip")


func _test_seven_animal_wavs_decode_cleanly() -> void:
	for key: String in ANIMAL_WAV_KEYS:
		var path := "res://assets/audio/animals/%s.wav" % key
		_check(FileAccess.file_exists(path), "wav_file_exists_" + key)
		var stream: AudioStreamWAV = AudioDirectorScript.load_animal_wav(key)
		_check(stream != null, "wav_decodes_" + key)
		if stream == null:
			continue
		_check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "wav_is_16bit_" + key)
		_check(stream.mix_rate == 22050, "wav_is_22050hz_" + key)
		_check(not stream.stereo, "wav_is_mono_" + key)
		var sample_count := int(stream.data.size() / 2)
		var dur_sec := float(sample_count) / float(maxi(1, stream.mix_rate))
		_check(dur_sec >= 0.40 and dur_sec <= 0.78, "wav_duration_in_bounds_" + key)
		var peak := 0
		for i: int in range(0, stream.data.size() - 1, 2):
			var s := absi(stream.data.decode_s16(i))
			if s > peak:
				peak = s
		_check(peak >= 2500, "wav_has_audible_signal_" + key)


func _test_cast_director_pet_speaker_preservation() -> void:
	var g_kitty := CastDirector.pick_proximity_greeting("home", {"id": "actor:textbook_kitty"}, 0)
	_check(str(g_kitty.get("speaker_id", "")) == "textbook_kitty", "proximity_greeting_kitty_keeps_kitty_id")
	var g_doggie := CastDirector.pick_proximity_greeting("home_estate", {"id": "actor:textbook_doggie"}, 0)
	_check(str(g_doggie.get("speaker_id", "")) == "textbook_doggie", "proximity_greeting_doggie_keeps_doggie_id")

	var c_kitty := CastDirector.build_actor_conversation(null, "textbook_kitty", "home", Vector3.ZERO)
	_check(str(c_kitty.get("npc_id", "")) == "textbook_kitty", "build_actor_conversation_kitty_keeps_kitty_id")
	var c_doggie := CastDirector.build_actor_conversation(null, "textbook_doggie", "home_estate", Vector3.ZERO)
	_check(str(c_doggie.get("npc_id", "")) == "textbook_doggie", "build_actor_conversation_doggie_keeps_doggie_id")


func _assert_visible_buttons_fit_viewport(container: Control, context_label: String, parent_bounds: Rect2 = Rect2()) -> void:
	var bad_buttons: Array[String] = []
	for node: Node in container.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn == null or not btn.is_visible_in_tree():
			continue
		var r := btn.get_global_rect()
		if r.position.x < -1.0 or r.end.x > 1441.0 or r.position.y < -1.0 or r.end.y > 901.0:
			bad_buttons.append("%s(%.1f..%.1f, %.1f..%.1f)" % [btn.text, r.position.x, r.end.x, r.position.y, r.end.y])
		elif parent_bounds.size.x > 0.0 and (r.position.x < parent_bounds.position.x - 2.0 or r.end.x > parent_bounds.end.x + 2.0):
			bad_buttons.append("%s_overflows_card(%.1f..%.1f vs %.1f..%.1f)" % [btn.text, r.position.x, r.end.x, parent_bounds.position.x, parent_bounds.end.x])
	if not bad_buttons.is_empty():
		push_error("V9 CLIPPING [" + context_label + "]: " + ", ".join(bad_buttons))
	_check(bad_buttons.is_empty(), "zero_button_clipping_" + context_label)


func _test_live_pet_audio_speed_toggle_and_bounds() -> void:
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
	game.validation_mode = false
	game.muted = false
	game.ai_bridge.muted = false

	# 1. Living Room (`home`): interact with Kitty -> must stay `textbook_kitty`, show `萌宠原声`, play `kitty_meow`, zero clipping!
	await game.change_room("home")
	await _frames(5)
	_check(game.living.get_actor("textbook_kitty") != null, "home_living_room_spawns_kitty")
	game.audio_director.last_animal_sound_key = ""
	game.interact_id("actor:textbook_kitty")
	await _frames(4)

	var dlg: Control = game.ui.diegetic
	_check(dlg.visible and str(dlg.current_npc_id) == "textbook_kitty", "clicking_kitty_keeps_npc_id_textbook_kitty")
	_check(dlg._speaker_badge.text.contains("萌宠原声") and dlg._speaker_badge.text.contains("绘本姐姐慢读"), "kitty_badge_displays_animal_and_storyteller_tag")
	_check(game.audio_director.last_animal_sound_key == "kitty_meow", "clicking_kitty_triggers_kitty_meow_sfx")

	# Verify speed toggle inside DiegeticDialogue (`natural` -> `slow` -> `natural`) + 1440x900 bounds
	_check(game.ai_bridge.speech_speed_mode == "natural" and dlg._speed_btn.text == "语速:亲切", "diegetic_starts_in_natural_speed_mode")
	_assert_visible_buttons_fit_viewport(dlg._bubble_card, "diegetic_kitty_natural", dlg._bubble_card.get_global_rect())
	_assert_visible_buttons_fit_viewport(dlg._ribbon_panel, "diegetic_ribbon_kitty")

	var re_emitted: Array[String] = []
	var cb := func(_txt: String, _lang: String, vh: String): re_emitted.append(vh)
	dlg.speak_requested.connect(cb)
	dlg._speed_btn.pressed.emit()
	await _frames(3)
	_check(game.ai_bridge.speech_speed_mode == "slow" and dlg._speed_btn.text == "语速:慢读", "diegetic_speed_chip_switches_to_slow")
	_check(re_emitted.size() == 1 and re_emitted[0] == "textbook_kitty", "diegetic_speed_chip_re_speaks_active_line")
	_assert_visible_buttons_fit_viewport(dlg._bubble_card, "diegetic_kitty_slow", dlg._bubble_card.get_global_rect())

	dlg._speed_btn.pressed.emit()
	await _frames(3)
	_check(game.ai_bridge.speech_speed_mode == "natural" and dlg._speed_btn.text == "语速:亲切", "diegetic_speed_chip_switches_back_to_natural")
	dlg.speak_requested.disconnect(cb)
	game._close()
	await _frames(2)

	# Also verify Mom in `home` displays `温柔妈妈音`
	game.interact_id("actor:textbook_role_lingling_mother")
	await _frames(3)
	_check(dlg.visible and str(dlg.current_npc_id) == "textbook_role_lingling_mother" and dlg._speaker_badge.text.contains("温柔妈妈音"), "mom_dialogue_displays_affectionate_mother_badge")
	game._close()
	await _frames(2)

	# 2. Sunny Garden (`home_estate`): interact with Doggie -> must stay `textbook_doggie`, show `萌宠原声`, play `puppy_woof`!
	await game.change_room("home_estate")
	await _frames(5)
	_check(game.living.get_actor("textbook_doggie") != null, "home_estate_spawns_doggie")
	game.audio_director.last_animal_sound_key = ""
	game.interact_id("actor:textbook_doggie")
	await _frames(4)
	_check(dlg.visible and str(dlg.current_npc_id) == "textbook_doggie", "clicking_doggie_keeps_npc_id_textbook_doggie")
	_check(dlg._speaker_badge.text.contains("萌宠原声") and dlg._speaker_badge.text.contains("绘本姐姐慢读"), "doggie_badge_displays_animal_and_storyteller_tag")
	_check(game.audio_director.last_animal_sound_key == "puppy_woof", "clicking_doggie_triggers_puppy_woof_sfx")
	_assert_visible_buttons_fit_viewport(dlg._bubble_card, "diegetic_doggie_natural", dlg._bubble_card.get_global_rect())
	game._close()
	await _frames(2)

	# Verify talking mascot SFX triggers for Dino & Parrot
	game.audio_director.last_animal_sound_key = ""
	game.ai_bridge.speak_text("Hello! Let's count stars together!", "en", "textbook_dino")
	_check(game.audio_director.last_animal_sound_key == "dino_chirp", "dino_triggers_dino_chirp_sfx")
	game.ai_bridge.speak_text("Hello! Nice sunny hat!", "en", "textbook_role_xiaoxiao_parrot")
	_check(game.audio_director.last_animal_sound_key == "parrot_squawk", "parrot_triggers_parrot_squawk_sfx")

	# 3. SpatialClusterBench3D (`home` #1 sofa + `home_study` #1 desk): speed toggle & 1440x900 bounds!
	await game.change_room("home")
	await _frames(4)
	game.interact_id("memory_01")
	await _frames(5)
	_check(game.spatial_bench.bench_open, "home_sofa_bench_opens")

	var overlay_root: Control = game.spatial_bench._overlay_root
	var top_bar := overlay_root.find_child("TopFloatingBar", true, false) as Control
	var bottom_dock := overlay_root.find_child("BottomFloatingDock", true, false) as Control
	var bench_speed_btn: Button = game.spatial_bench._speed_mode_btn
	_check(top_bar != null and bottom_dock != null and bench_speed_btn != null, "bench_top_dock_and_speed_button_present")

	if top_bar != null and bottom_dock != null and bench_speed_btn != null:
		var dock_rect := bottom_dock.get_global_rect()
		_check(dock_rect.position.x >= 0.0 and dock_rect.end.x <= 1440.0, "bottom_dock_fits_inside_1440_width")
		_check(bench_speed_btn.text == "♪ 慢速" and game.ai_bridge.speech_speed_mode == "natural", "bench_speed_btn_starts_in_natural")
		_assert_visible_buttons_fit_viewport(top_bar, "bench_top_bar_home")
		_assert_visible_buttons_fit_viewport(bottom_dock, "bench_bottom_dock_natural", dock_rect)

		bench_speed_btn.pressed.emit()
		await _frames(3)
		_check(game.ai_bridge.speech_speed_mode == "slow" and bench_speed_btn.text == "★ 慢读中", "bench_speed_btn_toggles_to_slow")
		_check(game.spatial_bench._task_feedback_lbl.text.contains("慢速清晰跟读"), "bench_feedback_confirms_slow_mode")
		_assert_visible_buttons_fit_viewport(bottom_dock, "bench_bottom_dock_slow", bottom_dock.get_global_rect())

		bench_speed_btn.pressed.emit()
		await _frames(3)
		_check(game.ai_bridge.speech_speed_mode == "natural" and bench_speed_btn.text == "♪ 慢速", "bench_speed_btn_toggles_back_to_natural")
		_check(game.spatial_bench._task_feedback_lbl.text.contains("亲切绘本语速"), "bench_feedback_confirms_natural_mode")

	game.spatial_bench.close_workbench()
	await _frames(2)

	game.queue_free()
	await process_frame
