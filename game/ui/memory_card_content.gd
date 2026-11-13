extends RefCounted
## V5 Object-Grounded Semantic Content Builder (`memory_card_content.gd`).
## Ensures every single one of the 210 fixed 3D scene objects across Home (40),
## Alphabet Landmarks (130), and School Campus (40) teaches:
##   1. Exact physical object English noun(s) (`object_en` / `object_zh`)
##   2. Authentic situational sentence right at that object (`phrase_en` / `phrase_zh`)
##   3. Direct 1-click link into `PopupBookTheater` (`palace_word` / `palace_entry_id`)

const SEMANTICS_V5_PATH := "res://data/learning/world_object_semantics_v5.json"

static var _translations: Dictionary = {}
static var _semantics_v5: Dictionary = {}

static func _ensure_loaded() -> void:
	if _translations.is_empty() and FileAccess.file_exists("res://data/memory_card_hints.json"):
		var parsed_h: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/memory_card_hints.json"))
		if parsed_h is Dictionary:
			_translations = parsed_h as Dictionary
	if _semantics_v5.is_empty() and FileAccess.file_exists(SEMANTICS_V5_PATH):
		var parsed_s: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEMANTICS_V5_PATH))
		if parsed_s is Dictionary:
			var anchors_val: Variant = (parsed_s as Dictionary).get("anchors", {})
			if anchors_val is Dictionary:
				_semantics_v5 = anchors_val as Dictionary

static func build(plan: Dictionary, anchor: Dictionary) -> Dictionary:
	_ensure_loaded()
	var room_id := str(anchor.get("room_id", plan.get("room_id", "")))
	var order := int(anchor.get("order", 0))
	if order <= 0:
		var anchors_arr: Array = plan.get("anchors", [])
		var found_idx := anchors_arr.find(anchor)
		if found_idx >= 0:
			order = found_idx + 1
	var key := "%s:%d" % [room_id, order]
	var source: Dictionary = anchor.get("source", {})

	if _semantics_v5.has(key) and _semantics_v5[key] is Dictionary:
		var spec: Dictionary = _semantics_v5[key]
		var obj_en := str(spec.get("object_en", "")).strip_edges()
		var obj_zh := str(spec.get("object_zh", "")).strip_edges()
		var phrase_en := str(spec.get("phrase_en", "")).strip_edges()
		var phrase_zh := str(spec.get("phrase_zh", "")).strip_edges()
		var activity := str(anchor.get("activity", spec.get("activity_zh", ""))).strip_edges()
		var p_word := str(spec.get("palace_word", "")).strip_edges()
		var p_eid := str(spec.get("palace_entry_id", "")).strip_edges()
		var p_mzh := str(spec.get("palace_meaning_zh", "")).strip_edges()

		var hint_parts: PackedStringArray = []
		if not phrase_zh.is_empty():
			hint_parts.append(phrase_zh)
		if not activity.is_empty() and activity != phrase_zh:
			hint_parts.append("互动贴士：" + activity)

		var room_disp := str(plan.get("name", spec.get("room_name", "小岛生活")))
		var attribution := "实物锚定 · %s · 记忆宫殿词「%s（%s）」" % [room_disp, p_word, p_mzh]
		if not source.is_empty() and str(source.get("book_title", "")) != "":
			var unit_lbl := str(source.get("unit_id", "")).replace("unit-", "Unit ")
			attribution = "%s · %s（实物情境校准）" % [str(source.get("book_title", "英语")), unit_lbl]

		# Only reuse old MP3 if its exact text matches `phrase_en`; otherwise let neural TTS speak calibrated English!
		var audio_file := ""
		if str(source.get("text", "")).strip_edges() == phrase_en:
			audio_file = str(source.get("audio", ""))

		var lead_noun := obj_en.split("/")[0].strip_edges()
		var spoken := (lead_noun + ". " + phrase_en) if not lead_noun.is_empty() else phrase_en

		return {
			"object_en": obj_en,
			"object_zh": obj_zh,
			"english": phrase_en,
			"spoken_english": spoken,
			"hint": "\n".join(hint_parts),
			"source": attribution,
			"audio": audio_file,
			"palace_word": p_word,
			"palace_entry_id": p_eid,
			"palace_meaning_zh": p_mzh,
		}

	# Legacy fallback if custom dynamic anchor is ever passed
	var lines: PackedStringArray = []
	if not str(source.get("text", "")).is_empty():
		lines.append(str(source.text))
	else:
		for phrase: String in plan.get("english_focus", []).slice(0, 2):
			lines.append(phrase)
	var hints: PackedStringArray = []
	for phrase: String in lines:
		if _translations.has(phrase):
			hints.append(str(_translations[phrase]))
	var fallback_act := str(anchor.get("activity", ""))
	if not fallback_act.is_empty():
		hints.append(fallback_act)
	var fallback_attr := "字母岛原创情境 · " + str(plan.get("name", "小岛生活"))
	return {
		"object_en": "",
		"object_zh": "",
		"english": "\n".join(lines),
		"spoken_english": "\n".join(lines),
		"hint": "\n".join(hints),
		"source": fallback_attr,
		"audio": str(source.get("audio", "")),
		"palace_word": "",
		"palace_entry_id": "",
		"palace_meaning_zh": "",
	}
