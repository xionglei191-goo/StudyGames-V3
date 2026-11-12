extends RefCounted
## V4.5 Differentiated Thematic Chapter Mini-Games (`ChapterThematicPlay`).
## Classifies all 81 textbook units (`curriculum_arcs_v4.json`) into 5 hands-on
## situational play boards with zero red-X penalties, neural TTS prompts, and
## seamless Stage 2 storyline progression!

const Style = preload("res://ui/island_theme.gd")
const StoryDirector = preload("res://gameplay/unit_storyline_director.gd")

const MODE_SPECS := {
	"cafe_order": {
		"id": "cafe_order",
		"title": "🍰 暖香点餐配盘",
		"subtitle": "小岛暖香餐台 · 按伙伴的点单心愿，把美食英文卡端上三格木托盘",
		"card_bg": "f8efe2",
		"slot_prefix": ["🥨 前菜木碟", "🍵 主餐圆盘", "🍓 甜点小盏"],
		"clue_template": "餐台心愿：请帮伙伴把【%s】端上 %s 吧！",
	},
	"weather_dress": {
		"id": "weather_dress",
		"title": "🌦️ 天气穿搭造型台",
		"subtitle": "晴雨衣帽间 · 看看窗外天气与色彩心愿，为小模特搭好今日三件套",
		"card_bg": "eaf2f6",
		"slot_prefix": ["🌤️ 天气晴雨牌", "🧥 主搭衣衫", "🧣 色彩配饰"],
		"clue_template": "造型心愿：请把代表【%s】的造型卡挂到 %s 上吧！",
	},
	"island_compass": {
		"id": "island_compass",
		"title": "🧭 小岛问路寻宝图",
		"subtitle": "手绘航海罗盘 · 顺着问路线索，在路线图上依次点亮三处目的地路标",
		"card_bg": "ebf3e6",
		"slot_prefix": ["🚩 出发第一站", "🌉 途中打卡点", "🏝️ 寻宝终点站"],
		"clue_template": "寻宝线索：下一站要去【%s】，请把它贴在 %s 吧！",
	},
	"clock_planner": {
		"id": "clock_planner",
		"title": "🕰️ 阳光作息时钟盘",
		"subtitle": "滴答木刻日程钟 · 把时间、数字与日常安排按顺序摆进晨午暮刻度格",
		"card_bg": "f6f1df",
		"slot_prefix": ["🌅 晨光第一格", "☀️ 暖阳第二格", "🌇 星夜第三格"],
		"clue_template": "日程心愿：请把【%s】排进时钟盘的 %s 吧！",
	},
	"kaleidoscope_sort": {
		"id": "kaleidoscope_sort",
		"title": "🎁 奇趣主题百宝箱",
		"subtitle": "森系木工收藏匣 · 听听伙伴介绍，把三件宝贝收纳进对应的绒布展格",
		"card_bg": "f2ebf6",
		"slot_prefix": ["🎀 一号绒布格", "🌟 二号展示格", "🏅 三号珍藏格"],
		"clue_template": "收藏心愿：请帮伙伴找出【%s】，轻轻放进 %s 吧！",
	},
}

static func classify_chapter(chapter: Dictionary) -> Dictionary:
	var haystack: String = (
		str(chapter.get("source_title", "")) + " " +
		str(chapter.get("event_title", "")) + " " +
		str(chapter.get("player_goal", "")) + " " +
		str(chapter.get("lead_word", "")) + " " +
		str(chapter.get("lead_zh", ""))
	).to_lower()

	var cafe_kw: Array[String] = [
		"food", "fruit", "apple", "banana", "cake", "milk", "rice", "noodle",
		"dumpling", "lunch", "dinner", "breakfast", "eat", "drink", "tea",
		"juice", "ice cream", "sweet", "cook", "pie", "hamburger", "canteen",
		"美味", "苹果", "蛋糕", "早餐", "午餐", "晚餐", "水果", "点心", "野餐", "生日"
	]
	for kw: String in cafe_kw:
		if haystack.contains(kw):
			return MODE_SPECS["cafe_order"]

	var weather_kw: Array[String] = [
		"weather", "season", "spring", "summer", "autumn", "winter", "cold",
		"hot", "warm", "cool", "rain", "snow", "sunny", "wind", "cloud",
		"coat", "shirt", "dress", "shoe", "trousers", "clothes", "colour",
		"color", "red", "blue", "yellow", "green", "umbrella", "wear",
		"天气", "季节", "春", "夏", "秋", "冬", "穿", "衣", "颜色", "雨"
	]
	for kw: String in weather_kw:
		if haystack.contains(kw):
			return MODE_SPECS["weather_dress"]

	var compass_kw: Array[String] = [
		"where", "country", "china", "australia", "place", "park", "zoo",
		"cinema", "library", "hospital", "shop", "museum", "beach", "mountain",
		"forest", "river", "earth", "world", "travel", "trip", "holiday",
		"by bus", "train", "ship", "plane", "turn", "left", "right", "go to",
		"路线", "地图", "国家", "旅行", "出发", "方向", "去哪", "参观", "地球"
	]
	for kw: String in compass_kw:
		if haystack.contains(kw):
			return MODE_SPECS["island_compass"]

	var clock_kw: Array[String] = [
		"time", "clock", "day", "monday", "tuesday", "sunday", "week", "month",
		"year", "old", "one", "two", "three", "five", "ten", "number", "count",
		"get up", "bed", "schedule", "timetable", "subject", "rule", "must", "do not",
		"时间", "几点", "星期", "日程", "作息", "年龄", "几岁", "数字", "规则", "课程表"
	]
	for kw: String in clock_kw:
		if haystack.contains(kw):
			return MODE_SPECS["clock_planner"]

	return MODE_SPECS["kaleidoscope_sort"]

static func target_cards_for_chapter(chapter: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var seen: Dictionary = {}
	var raw_fw: Array = chapter.get("featured_words", [])
	for item: Variant in raw_fw:
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			var w: String = str(d.get("word", "")).strip_edges()
			if not w.is_empty() and not seen.has(w.to_lower()):
				seen[w.to_lower()] = true
				targets.append({
					"word": w,
					"zh": str(d.get("zh", w)),
					"entry_id": str(d.get("entry_id", ""))
				})
				if targets.size() >= 3:
					break

	if targets.size() < 3:
		var book_id: String = str(chapter.get("book_id", "xiangshao-g3-1"))
		for u: Dictionary in StoryDirector.units_for_book(book_id):
			for item2: Variant in u.get("featured_words", []):
				if item2 is Dictionary:
					var d2: Dictionary = item2 as Dictionary
					var w2: String = str(d2.get("word", "")).strip_edges()
					if not w2.is_empty() and not seen.has(w2.to_lower()):
						seen[w2.to_lower()] = true
						targets.append({
							"word": w2,
							"zh": str(d2.get("zh", w2)),
							"entry_id": str(d2.get("entry_id", ""))
						})
						if targets.size() >= 3:
							break
			if targets.size() >= 3:
				break
	return targets

static func choice_pool_for_chapter(chapter: Dictionary, targets: Array[Dictionary]) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var seen: Dictionary = {}
	for t: Dictionary in targets:
		var k: String = str(t.get("word", "")).to_lower()
		seen[k] = true
		pool.append(t.duplicate(true))

	var all_u: Array = StoryDirector.all_units()
	var seed_idx: int = absi(str(chapter.get("chapter_key", "u1")).hash()) % maxi(1, all_u.size())
	for offset in range(all_u.size()):
		if pool.size() >= 5:
			break
		var u: Dictionary = all_u[(seed_idx + offset * 3 + 1) % all_u.size()]
		var lw: String = str(u.get("lead_word", "")).strip_edges()
		if not lw.is_empty() and not seen.has(lw.to_lower()):
			seen[lw.to_lower()] = true
			pool.append({
				"word": lw,
				"zh": str(u.get("lead_zh", lw)),
				"entry_id": str(u.get("lead_entry_id", ""))
			})

	# Deterministic shuffle so layout stays rock-solid during interaction
	var h: int = absi((str(chapter.get("chapter_key", "")) + "_v45").hash())
	for i in range(pool.size()):
		var swap_i: int = (h + i * 11) % pool.size()
		var tmp: Dictionary = pool[i]
		pool[i] = pool[swap_i]
		pool[swap_i] = tmp
	return pool

static func build(ui: Node, _state: Node, chapter: Dictionary, session: Dictionary) -> void:
	ui._begin("v4_thematic_play", "map")
	var ckey: String = str(chapter.get("chapter_key", "xiangshao-g3-1/unit-1"))
	var spec: Dictionary = classify_chapter(chapter)
	var targets: Array[Dictionary] = target_cards_for_chapter(chapter)
	var pool: Array[Dictionary] = choice_pool_for_chapter(chapter, targets)
	var filled_count: int = clampi(int(session.get("filled", 0)), 0, targets.size())
	var hint_on: bool = bool(session.get("hint", false))
	var gentle_note: String = str(session.get("note", ""))
	var all_done: bool = filled_count >= targets.size()

	ui._heading(
		"%s  ·  %s U%d" % [
			str(spec.get("title", "🎁 奇趣主题百宝箱")),
			str(chapter.get("book_title", "三年级上册")),
			int(chapter.get("unit_number", 1))
		],
		"%s  |  单元主题：%s（%s）" % [
			str(spec.get("subtitle", "")),
			str(chapter.get("source_title", "")),
			str(chapter.get("event_title", ""))
		]
	)

	var board_card: PanelContainer = ui.card(Color(str(spec.get("card_bg", "f4f1e4"))), 18)
	board_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(board_card)

	var board_col := VBoxContainer.new()
	board_col.add_theme_constant_override("separation", 14)
	board_card.add_child(board_col)

	# 1. Three Situational Tray Slots
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 14)
	board_col.add_child(slots_row)

	var prefixes: Array = spec.get("slot_prefix", ["1 号格", "2 号格", "3 号格"])
	for i in range(targets.size()):
		var t_item: Dictionary = targets[i]
		var slot_done: bool = i < filled_count
		var is_current: bool = (i == filled_count)
		var slot_bg := Color("dfead5") if slot_done else (Color("fff8e3") if is_current else Color("efeae0"))
		var slot_card: PanelContainer = ui.card(slot_bg, 14)
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_card.custom_minimum_size = Vector2(0, 118)
		slots_row.add_child(slot_card)

		var scol := VBoxContainer.new()
		scol.add_theme_constant_override("separation", 6)
		slot_card.add_child(scol)

		var p_label: String = str(prefixes[i % prefixes.size()])
		scol.add_child(ui.label(p_label, 15, Style.MUTED))
		if slot_done:
			scol.add_child(ui.label("✓ %s" % str(t_item.get("word", "")), 22, Color("3c6e37")))
			scol.add_child(ui.label("「%s」已稳稳放好 ✨" % str(t_item.get("zh", "")), 15, Style.INK))
		elif is_current:
			var hint_str: String = "（首字母提示：%s…）" % str(t_item.get("word", "")).left(1) if hint_on else ""
			scol.add_child(ui.label("▶ 待放入：【%s】%s" % [str(t_item.get("zh", "")), hint_str], 18, Style.INK))
			scol.add_child(ui.label("从下方选出对应的英文卡放进来吧", 14, Style.SAGE))
		else:
			scol.add_child(ui.label("○ 稍后揭晓：【%s】" % str(t_item.get("zh", "")), 17, Style.MUTED))

	# 2. Active Situational Clue Banner + Audio / Gentle Hint Controls
	var clue_bar := HBoxContainer.new()
	clue_bar.add_theme_constant_override("separation", 12)
	board_col.add_child(clue_bar)

	if not all_done:
		var cur_target: Dictionary = targets[filled_count]
		var cur_prefix: String = str(prefixes[filled_count % prefixes.size()])
		var clue_txt: String = str(spec.get("clue_template", "请找出【%s】放进 %s！")) % [
			str(cur_target.get("zh", "")),
			cur_prefix
		]
		var clue_lbl: Label = ui.label("💬 " + clue_txt, 19, Style.INK)
		clue_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clue_bar.add_child(clue_lbl)

		clue_bar.add_child(ui.button("🔊 听英文读音", "v4_thematic_speak:" + str(cur_target.get("word", "")), false, Vector2(165, 44)))
		clue_bar.add_child(ui.button("💡 首字母贴士" if not hint_on else "💡 贴士已开", "v4_thematic_hint:" + ckey, false, Vector2(155, 44)))
	else:
		var win_lbl: Label = ui.label(
			"🎉 太棒啦！「%s」三格全部搭配完成，伙伴笑得合不拢嘴！" % str(spec.get("title", "")),
			20,
			Color("3c6e37")
		)
		win_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_bar.add_child(win_lbl)

	# 3. Interactive Illustrated Word Cards Pool
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	board_col.add_child(cards_row)

	var placed_words: Dictionary = {}
	for j in range(filled_count):
		placed_words[str(targets[j].get("word", "")).to_lower()] = true

	for item: Dictionary in pool:
		var w: String = str(item.get("word", ""))
		var used: bool = placed_words.has(w.to_lower())
		var btn_caption: String = ("✓ %s\n%s" % [w, str(item.get("zh", ""))]) if (used or all_done) else ("🃏 %s\n点此放入托盘" % w)
		if hint_on and not used and not all_done and w.to_lower() == str(targets[filled_count].get("word", "")).to_lower():
			btn_caption = "✨ %s\n%s" % [w, str(item.get("zh", ""))]
		var cbtn: Button = ui.button(
			btn_caption,
			"v4_thematic_pick:%s:%s" % [ckey, w],
			not used and not all_done,
			Vector2(0, 88)
		)
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.disabled = used or all_done
		cards_row.add_child(cbtn)

	if not gentle_note.is_empty():
		var note_lbl: Label = ui.label(gentle_note, 16, Color("5a6b47"))
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		board_col.add_child(note_lbl)

	# 4. Bottom Action Ribbon
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	ui.panel_box.add_child(bottom)

	if all_done:
		var finish_btn: Button = ui.button(
			"🏅 收下共创奖励 (+6 叶币) · 回伙伴身边点亮纪念牌",
			"v4_thematic_done:" + ckey,
			true,
			Vector2(420, 50)
		)
		bottom.add_child(finish_btn)
	var lead_eid: String = str(chapter.get("lead_entry_id", ""))
	if not lead_eid.is_empty():
		bottom.add_child(ui.button("📖 翻开本章 3D 立体书", "v4_chap_popup:%s:%s" % [ckey, lead_eid], false, Vector2(220, 46)))
	bottom.add_child(ui.button("🗺️ 返回八册章节画册", "v4_chapter_atlas", false, Vector2(200, 46)))
	bottom.add_child(ui.button("回到场景", "close", false, Vector2(130, 46)))

	ui._layout.call_deferred()
