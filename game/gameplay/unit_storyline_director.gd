extends RefCounted
## V4 8-Book / 81-Unit Cozy Storyline Engine (`UnitStorylineDirector`).
## Turns all 81 textbook units (`curriculum_arcs_v4.json`) into playable 3-stage
## diegetic island chapters with hands-on 3D activities, 3D Pop-up Book links,
## and persistent 3D world keepsake plaques!

const ARCS_PATH := "res://data/learning/curriculum_arcs_v4.json"

static var _cache: Dictionary = {}

static func load_arcs() -> Dictionary:
	if _cache.is_empty() and FileAccess.file_exists(ARCS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARCS_PATH))
		if parsed is Dictionary:
			_cache = parsed as Dictionary
	return _cache

static func books() -> Array:
	return load_arcs().get("books", []) as Array

static func all_units() -> Array:
	return load_arcs().get("units", []) as Array

static func units_for_book(book_id: String) -> Array:
	var out: Array = []
	for u: Dictionary in all_units():
		if str(u.get("book_id", "")) == book_id:
			out.append(u)
	return out

static func get_chapter(book_id: String, unit_id: String) -> Dictionary:
	for u: Dictionary in all_units():
		if str(u.get("book_id", "")) == book_id and str(u.get("unit_id", "")) == unit_id:
			return u
	var fallback := units_for_book(book_id)
	return fallback[0] if not fallback.is_empty() else {}

static func get_chapter_by_key(chapter_key: String) -> Dictionary:
	for u: Dictionary in all_units():
		if str(u.get("chapter_key", "")) == chapter_key:
			return u
	return {}

static func active_chapter(state: Node) -> Dictionary:
	var j_snap: Dictionary = state.journey_snapshot()
	var book_id := str(j_snap.get("selected_book_id", "xiangshao-g3-1"))
	var v4_dict: Dictionary = state.data.get("v4", {}) if state.data.get("v4") is Dictionary else {}
	var unit_id := str(v4_dict.get("active_unit_id", "unit-1"))
	var chap := get_chapter(book_id, unit_id)
	if chap.is_empty() and not all_units().is_empty():
		chap = all_units()[0]
	return chap

static func completed_count_for_book(state: Node, book_id: String) -> int:
	var count := 0
	for u: Dictionary in units_for_book(book_id):
		if state.v4_chapter_stage(str(u.get("chapter_key", ""))) >= 3:
			count += 1
	return count

static func total_completed_chapters(state: Node) -> int:
	var count := 0
	for u: Dictionary in all_units():
		if state.v4_chapter_stage(str(u.get("chapter_key", ""))) >= 3:
			count += 1
	return count

static func completed_titles_for_room(state: Node, room_id: String) -> Array[String]:
	var titles: Array[String] = []
	for u: Dictionary in all_units():
		if str(u.get("primary_room", "")) == room_id and state.v4_chapter_stage(str(u.get("chapter_key", ""))) >= 3:
			titles.append("U%d · %s" % [int(u.get("unit_number", 1)), str(u.get("event_title", ""))])
	return titles

static func build_stage_dialogue(state: Node, chapter: Dictionary, world_pos: Vector3) -> Dictionary:
	var ckey := str(chapter.get("chapter_key", "xiangshao-g3-1/unit-1"))
	var stage_done := int(state.v4_chapter_stage(ckey))
	var npc_id := str(chapter.get("host_npc_id", "npc_bear_uncle"))
	var speaker := "%s · %s U%d" % [
		str(chapter.get("host_speaker", "小岛伙伴")),
		str(chapter.get("book_title", "三年级上册")),
		int(chapter.get("unit_number", 1))
	]
	var lead_word := str(chapter.get("lead_word", "hello"))
	var lead_zh := str(chapter.get("lead_zh", "你好"))
	var lead_eid := str(chapter.get("lead_entry_id", ""))
	var stages: Array = chapter.get("stages", [])
	var s1_txt := str(stages[0].get("text", "")) if stages.size() > 0 else ""
	var s2_txt := str(stages[1].get("text", "")) if stages.size() > 1 else ""
	var s3_txt := str(stages[2].get("text", "")) if stages.size() > 2 else ""
	var thematic_spec: Dictionary = load("res://gameplay/chapter_thematic_play.gd").classify_chapter(chapter)
	var thematic_title: String = str(thematic_spec.get("title", "★ 奇趣主题百宝箱"))

	if stage_done == 0:
		return {
			"npc_id": npc_id,
			"speaker": speaker,
			"en": "Welcome to \"%s\"! Today let's share \"%s\" together!" % [str(chapter.get("source_title", "Island Story")), lead_word],
			"zh": "【第 1 幕 · 聆听伙伴心愿】%s\n本章关键词：「%s」（%s）\n小目标：%s" % [s1_txt, lead_word, lead_zh, str(chapter.get("player_goal", ""))],
			"world_pos": world_pos,
			"show_zh_immediately": true,
			"auto_speak": true,
			"actions": [
				{"label": " 收下心愿，开启第 2 幕", "id": "v4_chap_step:1:" + ckey, "primary": true},
				{"label": "◈ 主题微玩法 · " + thematic_title, "id": "v4_thematic_open:" + ckey},
				{"label": "◈ 翻开「%s」立体书" % lead_word, "id": "v4_chap_popup:" + ckey + ":" + lead_eid, "disabled": lead_eid.is_empty()},
				{"label": "◈ 八册章节画册", "id": "v4_chapter_atlas"},
				{"label": "稍后再聊", "id": "close"}
			]
		}
	elif stage_done == 1:
		return {
			"npc_id": npc_id,
			"speaker": speaker,
			"en": "Let's create our keepsake with \"%s\"! Try our themed mini-game, the 3D pop-up book, or pick up items nearby!" % lead_word,
			"zh": "【第 2 幕 · 亲手共创体验】%s\n你可以体验本章专属「%s」、翻开「%s」（%s）3D 立体书，或在附近捧起 3D 物件放进工坊台！" % [s2_txt, thematic_title, lead_word, lead_zh],
			"world_pos": world_pos,
			"show_zh_immediately": true,
			"auto_speak": true,
			"actions": [
				{"label": "◈ 体验 " + thematic_title, "id": "v4_thematic_open:" + ckey, "primary": true},
				{"label": "◈ 体验 3D 立体翻翻书", "id": "v4_chap_popup:" + ckey + ":" + lead_eid, "disabled": lead_eid.is_empty()},
				{"label": "直接完成共创进入终幕", "id": "v4_chap_step:2:" + ckey},
				{"label": "稍后再聊", "id": "close"}
			]
		}
	elif stage_done == 2:
		return {
			"npc_id": npc_id,
			"speaker": speaker,
			"en": "Hooray! We finished \"%s\" together! Let's place our keepsake in the island world!" % str(chapter.get("source_title", "")),
			"zh": "【第 3 幕 · 点亮小岛回响】%s\n世界回响：%s" % [s3_txt, str(chapter.get("world_keepsake", ""))],
			"world_pos": world_pos,
			"show_zh_immediately": true,
			"auto_speak": true,
			"actions": [
				{"label": "★ 安放章节纪念牌 (+12 叶币)", "id": "v4_chap_step:3:" + ckey, "primary": true},
				{"label": "◈ 再看一遍立体书", "id": "v4_chap_popup:" + ckey + ":" + lead_eid, "disabled": lead_eid.is_empty()},
				{"label": "稍后再聊", "id": "close"}
			]
		}
	else:
		var next_u := int(chapter.get("unit_number", 1)) + 1
		var book_id := str(chapter.get("book_id", "xiangshao-g3-1"))
		var book_units := units_for_book(book_id).size()
		var actions: Array = []
		if next_u <= book_units:
			actions.append({"label": "▶ 继续下一章 (Unit %d)" % next_u, "id": "v4_chap_go:%s:unit-%d" % [book_id, next_u], "primary": true})
		else:
			actions.append({"label": "◈ 打开八册章节画册选新册", "id": "v4_chapter_atlas", "primary": true})
		actions.append({"label": "◈ 重温 " + thematic_title, "id": "v4_thematic_open:" + ckey})
		if not lead_eid.is_empty():
			actions.append({"label": "◈ 温习「%s」立体书" % lead_word, "id": "open_popup_story:" + lead_eid})
		actions.append({"label": "开心散步", "id": "close"})
		return {
			"npc_id": npc_id,
			"speaker": speaker + " · 已点亮 ★",
			"en": "Look! Our keepsake for \"%s\" is shining brightly here! Thank you, my friend!" % str(chapter.get("source_title", "")),
			"zh": "本章纪念牌已经稳稳立在场景里啦！\n世界回响：%s" % str(chapter.get("world_keepsake", "")),
			"world_pos": world_pos,
			"show_zh_immediately": true,
			"auto_speak": true,
			"actions": actions
		}
