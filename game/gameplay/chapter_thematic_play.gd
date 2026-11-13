extends RefCounted
## V5 Differentiated Thematic Chapter Mini-Games (`ChapterThematicPlay`).
## Classifies all 81 textbook units (`curriculum_arcs_v4.json`) into 5 hands-on
## situational play boards with tactile cream-wood flashcards, 1–5 keyboard support,
## zero red-X penalties, neural TTS prompts, and zero raw OS emojis.

const Style = preload("res://ui/island_theme.gd")
const StoryDirector = preload("res://gameplay/unit_storyline_director.gd")

const MODE_SPECS := {
	"cafe_order": {
		"id": "cafe_order",
		"icon": "cake",
		"title": "暖香点餐配盘",
		"subtitle": "小岛暖香餐台 · 按伙伴的点单心愿，把美食英文卡端上三格木托盘",
		"card_bg": "f8f1e4",
		"slot_prefix": ["1 号 · 前菜木碟", "2 号 · 主餐圆盘", "3 号 · 甜点小盏"],
		"clue_template": "餐台心愿：请帮伙伴把【%s】端上「%s」吧！",
	},
	"weather_dress": {
		"id": "weather_dress",
		"icon": "outfit",
		"title": "天气穿搭造型台",
		"subtitle": "晴雨衣帽间 · 看看窗外天气与色彩心愿，为小模特搭好今日三件套",
		"card_bg": "eef3f5",
		"slot_prefix": ["1 号 · 天气晴雨牌", "2 号 · 主搭衣衫", "3 号 · 色彩配饰"],
		"clue_template": "造型心愿：请把代表【%s】的造型卡挂到「%s」上吧！",
	},
	"island_compass": {
		"id": "island_compass",
		"icon": "compass",
		"title": "小岛问路寻宝图",
		"subtitle": "手绘航海罗盘 · 顺着问路线索，在路线图上依次点亮三处目的地路标",
		"card_bg": "eef4e8",
		"slot_prefix": ["1 号 · 出发第一站", "2 号 · 途中打卡点", "3 号 · 寻宝终点站"],
		"clue_template": "寻宝线索：下一站要去【%s】，请把它贴在「%s」吧！",
	},
	"clock_planner": {
		"id": "clock_planner",
		"icon": "sun",
		"title": "阳光作息时钟盘",
		"subtitle": "滴答木刻日程钟 · 把时间、数字与日常安排按顺序摆进晨午暮刻度格",
		"card_bg": "f7f2e1",
		"slot_prefix": ["1 号 · 晨光第一格", "2 号 · 暖阳第二格", "3 号 · 星夜第三格"],
		"clue_template": "日程心愿：请把【%s】排进时钟盘的「%s」吧！",
	},
	"kaleidoscope_sort": {
		"id": "kaleidoscope_sort",
		"icon": "sparkle",
		"title": "奇趣主题百宝箱",
		"subtitle": "森系木工收藏匣 · 听听伙伴介绍，把三件宝贝收纳进对应的绒布展格",
		"card_bg": "f4eff6",
		"slot_prefix": ["1 号 · 一号绒布格", "2 号 · 二号展示格", "3 号 · 三号珍藏格"],
		"clue_template": "收藏心愿：请帮伙伴找出【%s】，轻轻放进「%s」吧！",
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
			str(spec.get("title", "奇趣主题百宝箱")),
			str(chapter.get("book_title", "三年级上册")),
			int(chapter.get("unit_number", 1))
		],
		"%s  |  单元主题：%s（%s）" % [
			str(spec.get("subtitle", "")),
			str(chapter.get("source_title", "")),
			str(chapter.get("event_title", ""))
		]
	)

	var board_card: PanelContainer = ui.card(Color(str(spec.get("card_bg", "f4f1e4"))), 22)
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
		var slot_bg := Color("e2edd7") if slot_done else (Color("fffaf0") if is_current else Color("f3efe5"))
		var slot_bd := Color("8fb577") if slot_done else (Style.GOLD if is_current else Color("ddd2bd"))
		var slot_card := PanelContainer.new()
		var sc_sb := Style.keycap(slot_bg, slot_bd, 4 if is_current else 3, 18, 16, 14)
		slot_card.add_theme_stylebox_override("panel", sc_sb)
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_card.custom_minimum_size = Vector2(0, 128)
		slots_row.add_child(slot_card)

		var scol := VBoxContainer.new()
		scol.add_theme_constant_override("separation", 6)
		slot_card.add_child(scol)

		var p_label: String = str(prefixes[i % prefixes.size()])
		scol.add_child(ui.label(p_label, 14, Style.MUTED))
		if slot_done:
			var done_w := ui.label("✓  %s" % str(t_item.get("word", "")), 23, Color("38663a")) as Label
			done_w.add_theme_font_override("font", Style.heading_font())
			scol.add_child(done_w)
			scol.add_child(ui.label("「%s」已稳稳摆好" % str(t_item.get("zh", "")), 15, Style.INK))
		elif is_current:
			var hint_str: String = "（首字母：%s…）" % str(t_item.get("word", "")).left(1) if hint_on else ""
			var cur_w := ui.label("▶  待放入：【%s】%s" % [str(t_item.get("zh", "")), hint_str], 19, Style.INK) as Label
			cur_w.add_theme_font_override("font", Style.heading_font())
			scol.add_child(cur_w)
			scol.add_child(ui.label("点击下方英文木卡或按数字键 [1]–[5] 放入", 14, Style.SAGE))
		else:
			scol.add_child(ui.label("○  稍后揭晓：【%s】" % str(t_item.get("zh", "")), 17, Style.MUTED))

	# 2. Active Situational Clue Banner + Audio / Gentle Hint Controls
	var clue_card := PanelContainer.new()
	var cl_sb := Style.keycap(Color("fdfaf2"), Color("e2d6be"), 2, 16, 14, 10)
	cl_sb.shadow_size = 0
	clue_card.add_theme_stylebox_override("panel", cl_sb)
	board_col.add_child(clue_card)

	var clue_bar := HBoxContainer.new()
	clue_bar.add_theme_constant_override("separation", 12)
	clue_card.add_child(clue_bar)

	if not all_done:
		clue_bar.add_child(ui.icon_view(str(spec.get("icon", "sparkle")), 28))
		var cur_target: Dictionary = targets[filled_count]
		var cur_prefix: String = str(prefixes[filled_count % prefixes.size()])
		var clue_txt: String = str(spec.get("clue_template", "请找出【%s】放进 %s！")) % [
			str(cur_target.get("zh", "")),
			cur_prefix
		]
		var clue_lbl: Label = ui.label(clue_txt, 18, Style.INK)
		clue_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clue_bar.add_child(clue_lbl)

		var spk_btn: Button = ui.button("听英文读音", "v4_thematic_speak:" + str(cur_target.get("word", "")), false, Vector2(158, 42))
		spk_btn.icon = Style.icon("speaker")
		spk_btn.add_theme_constant_override("icon_max_width", 20)
		clue_bar.add_child(spk_btn)

		var hnt_btn: Button = ui.button("首字母贴士" if not hint_on else "贴士已开启", "v4_thematic_hint:" + ckey, false, Vector2(152, 42))
		hnt_btn.icon = Style.icon("bulb")
		hnt_btn.add_theme_constant_override("icon_max_width", 18)
		clue_bar.add_child(hnt_btn)
	else:
		clue_bar.add_child(ui.icon_view("sparkle", 26))
		var win_lbl: Label = ui.label(
			"太棒啦！「%s」三格全部搭配完成，伙伴笑得合不拢嘴！" % str(spec.get("title", "")),
			19,
			Color("38663a")
		)
		win_lbl.add_theme_font_override("font", Style.heading_font())
		win_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_bar.add_child(win_lbl)

	# 3. Tactile Cream-and-Honey Wooden Word Flashcards Pool
	var cards_row := HBoxContainer.new()
	cards_row.name = "ThematicChoiceCardsRow"
	cards_row.add_theme_constant_override("separation", 12)
	board_col.add_child(cards_row)

	var placed_words: Dictionary = {}
	for j in range(filled_count):
		placed_words[str(targets[j].get("word", "")).to_lower()] = true

	for idx_c in range(pool.size()):
		var item: Dictionary = pool[idx_c]
		var w: String = str(item.get("word", ""))
		var used: bool = placed_words.has(w.to_lower())
		var is_hint_match: bool = hint_on and not used and not all_done and w.to_lower() == str(targets[filled_count].get("word", "")).to_lower()
		var btn_caption: String = ("✓ %s\n%s" % [w, str(item.get("zh", ""))]) if (used or all_done) else ("%s\n[%d] 点选放入" % [w, idx_c + 1])
		if is_hint_match:
			btn_caption = "★ %s\n[%d] %s" % [w, idx_c + 1, str(item.get("zh", ""))]

		var cbtn: Button = ui.button(
			btn_caption,
			"v4_thematic_pick:%s:%s" % [ckey, w],
			false,
			Vector2(0, 96)
		)
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.disabled = used or all_done
		cbtn.add_theme_font_override("font", Style.heading_font())
		cbtn.add_theme_font_size_override("font_size", 19)

		if used or all_done:
			var done_sb := Style.keycap(Color("e3edd9"), Color("a6c293"), 2, 18, 12, 12)
			done_sb.shadow_size = 0
			cbtn.add_theme_stylebox_override("disabled", done_sb)
			cbtn.add_theme_color_override("font_disabled_color", Color("456944"))
		elif is_hint_match:
			cbtn.add_theme_stylebox_override("normal", Style.keycap(Color("fff6d6"), Style.GOLD, 5, 18, 12, 12))
			cbtn.add_theme_stylebox_override("hover", Style.keycap(Color("ffefbd"), Style.GOLD, 5, 18, 12, 12))
		else:
			cbtn.add_theme_stylebox_override("normal", Style.keycap(Color("fffdf7"), Color("d7c5a3"), 5, 18, 12, 12))
			cbtn.add_theme_stylebox_override("hover", Style.keycap(Color("fdf2d6"), Style.GOLD, 5, 18, 12, 12))
			cbtn.add_theme_stylebox_override("pressed", Style.keycap(Color("f2e8ce"), Color("c6b28d"), 2, 18, 12, 14))
		cards_row.add_child(cbtn)

	if not gentle_note.is_empty():
		var clean_note := gentle_note.replace("★", "★").replace("◇", "◈").replace("", "")
		var note_lbl: Label = ui.label(clean_note.strip_edges(), 16, Color("4d6b45"))
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		board_col.add_child(note_lbl)

	# 4. Bottom Action Ribbon
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	ui.panel_box.add_child(bottom)

	if all_done:
		var finish_btn: Button = ui.button(
			"收下共创奖励 (+6 叶币) · 回伙伴身边点亮纪念牌",
			"v4_thematic_done:" + ckey,
			true,
			Vector2(410, 48)
		)
		finish_btn.icon = Style.icon("star")
		finish_btn.add_theme_constant_override("icon_max_width", 20)
		bottom.add_child(finish_btn)
	var lead_eid: String = str(chapter.get("lead_entry_id", ""))
	if not lead_eid.is_empty():
		var pop_btn: Button = ui.button("翻开本章 3D 立体书", "v4_chap_popup:%s:%s" % [ckey, lead_eid], false, Vector2(216, 46))
		pop_btn.icon = Style.icon("book")
		pop_btn.add_theme_constant_override("icon_max_width", 20)
		bottom.add_child(pop_btn)
	var atlas_btn: Button = ui.button("返回八册章节画册", "v4_chapter_atlas", false, Vector2(200, 46))
	atlas_btn.icon = Style.icon("compass")
	atlas_btn.add_theme_constant_override("icon_max_width", 20)
	bottom.add_child(atlas_btn)
	bottom.add_child(ui.button("回到场景", "close", false, Vector2(130, 46)))

	ui._layout.call_deferred()
