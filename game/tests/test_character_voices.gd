extends SceneTree
## Automated Verification Suite for V5 Multi-Character Voice Timbres (`test_character_voices.gd`).
## Verifies all 10 voice archetypes, 34 building/campus residents, textbook cast,
## `DiegeticDialogueOverlay` EN + ZH character-voice routing, and `ActivityBoard` host routing.

const CharacterVoices = preload("res://core/character_voices.gd")
const Residents = preload("res://actors/building_resident_catalog.gd")
const DiegeticOverlay = preload("res://ui_v4/diegetic_dialogue.gd")
const ActivityBoard = preload("res://ui/activity_board.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	await _run()
	print("CHARACTER_VOICES_SUMMARY: passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _assert(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("CHAR_VOICE_FAIL: " + label)

func _run() -> void:
	await process_frame
	# 1. Verify all 10 archetypes and distinct fallback pitches
	_assert(CharacterVoices.ARCHETYPES.size() == 10, "ten_voice_archetypes")
	_assert(CharacterVoices.archetype_for("npc_bear_uncle") == "uncle_warm", "bear_uncle_archetype")
	_assert(CharacterVoices.archetype_for("textbook_miss_li") == "teacher_gentle", "miss_li_archetype")
	_assert(CharacterVoices.archetype_for("textbook_lingling") == "girl_bright", "lingling_archetype")
	_assert(CharacterVoices.archetype_for("textbook_peter") == "boy_sunny", "peter_archetype")
	_assert(CharacterVoices.archetype_for("textbook_dino") == "mascot_dino", "dino_archetype")
	_assert(CharacterVoices.archetype_for("npc_owl_tutor") == "elder_wise", "owl_tutor_archetype")
	_assert(CharacterVoices.archetype_for("storyteller") == "storyteller", "storyteller_archetype")
	_assert(CharacterVoices.fallback_pitch_scale("npc_bear_uncle") < CharacterVoices.fallback_pitch_scale("textbook_miss_li"), "bear_deeper_than_teacher")
	_assert(CharacterVoices.fallback_pitch_scale("textbook_lingling") > CharacterVoices.fallback_pitch_scale("textbook_miss_li"), "girl_brighter_than_teacher")
	_assert(CharacterVoices.fallback_pitch_scale("textbook_dino") > CharacterVoices.fallback_pitch_scale("textbook_peter"), "dino_higher_than_boy")

	# 2. Verify all 34 building & campus residents map cleanly in CHARACTER_ARCHETYPE
	var all_residents := Residents.all()
	_assert(all_residents.size() == 34, "catalog_has_34_residents")
	for res_id: String in all_residents.keys():
		_assert(CharacterVoices.CHARACTER_ARCHETYPE.has(res_id), "mapped_resident_" + res_id)
		_assert(not CharacterVoices.label_zh_for(res_id).is_empty(), "label_zh_resident_" + res_id)

	# 3. Verify DiegeticDialogueOverlay routes both EN and ZH with exact character npc_id
	var emitted: Array[Dictionary] = []
	var dlg := DiegeticOverlay.new()
	root.add_child(dlg)
	await process_frame
	dlg.speak_requested.connect(func(txt: String, lang: String, vh: String):
		emitted.append({"text": txt, "lang": lang, "vh": vh})
	)

	dlg.open_conversation({
		"npc_id": "npc_bear_uncle",
		"speaker": "熊叔 · 暖香蛋糕坊",
		"en": "Good morning! Welcome to Alphabet Island!",
		"zh": "早上好！欢迎来到字母岛！",
		"auto_speak": true,
		"actions": [{"label": "好的", "id": "close"}]
	})
	_assert(dlg._speaker_badge.text.contains("暖厚大叔音"), "speaker_badge_shows_voice_tag")
	_assert(emitted.size() == 1 and emitted[0]["lang"] == "en" and emitted[0]["vh"] == "npc_bear_uncle", "auto_speak_routes_bear_uncle")

	dlg._listen_zh_btn.pressed.emit()
	_assert(emitted.size() == 2 and emitted[1]["lang"] == "zh" and emitted[1]["vh"] == "npc_bear_uncle", "zh_button_routes_bear_uncle")

	dlg.open_conversation({
		"npc_id": "textbook_peter",
		"speaker": "彼得 · 操场伙伴",
		"en": "Hi friend! Let's play football!",
		"zh": "嗨伙伴！我们一起踢足球吧！",
		"auto_speak": true,
		"actions": [{"label": "好的", "id": "close"}]
	})
	_assert(dlg._speaker_badge.text.contains("阳光小男孩音"), "peter_badge_shows_boy_voice_tag")
	_assert(emitted.size() == 3 and emitted[2]["vh"] == "textbook_peter", "auto_speak_routes_peter")
	dlg.queue_free()

	# 4. Verify ActivityBoard routes campus subject rooms to their distinct subject teachers
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		var bus_events: Array[Dictionary] = []
		bus.tts_speak_requested.connect(func(txt: String, lang: String, vh: String):
			bus_events.append({"text": txt, "lang": lang, "vh": vh})
		)
		for pair: Array in [["music", "resident_music_room"], ["art", "resident_art_room"], ["science", "resident_science_room"]]:
			var board := ActivityBoard.new()
			root.add_child(board)
			board.setup(str(pair[0]), {"art_pixels": []})
			bus_events.clear()
			board._speak_bilingual("Hello studio!")
			_assert(bus_events.size() == 1 and bus_events[0]["vh"] == str(pair[1]), "activity_routes_" + str(pair[1]))
			board.queue_free()
