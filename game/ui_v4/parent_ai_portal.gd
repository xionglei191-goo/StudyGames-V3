extends RefCounted
## V5 Parent AI Observatory & 8-Book 81-Unit Curriculum Switcher (`ParentAIPortal`).
## Presents warm, non-judgmental IRT stealth learning insights, active textbook/unit
## synchronization across all 8 primary school books, and zero raw OS emojis.

const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const CurriculumDirector = preload("res://gameplay/curriculum_quest_director.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")

static func build(ui: Node, state: Node, bridge: Node) -> void:
	ui._begin("v4_parent_ai", "map")
	var info: Dictionary = CurriculumDirector.active_book_and_unit(state)
	ui._heading("家长 AI 成长观察室 & 八册教材同步台", "%s · Unit %d · 无考卷隐性素养追踪" % [str(info.book_title), int(info.unit_number)])

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	ui.panel_box.add_child(top_bar)

	top_bar.add_child(ui.label("同步教材册次：", 17, ui.muted_ink))

	var book_select := OptionButton.new()
	book_select.custom_minimum_size = Vector2(256, 44)
	var books: Array = Content.load_catalog().get("books", [])
	var sel_b_idx := 0
	for i in range(books.size()):
		var b: Dictionary = books[i]
		book_select.add_item(str(b.get("title_zh", b.get("title", b.get("book_id", "")))), i)
		book_select.set_item_metadata(i, str(b.get("book_id", "")))
		if str(b.get("book_id", "")) == str(info.book_id):
			sel_b_idx = i
	book_select.select(sel_b_idx)
	top_bar.add_child(book_select)

	top_bar.add_child(ui.label("生活委托单元：", 17, ui.muted_ink))
	var unit_select := OptionButton.new()
	unit_select.custom_minimum_size = Vector2(150, 44)
	for u in range(1, int(info.unit_count) + 1):
		unit_select.add_item("Unit " + str(u), u - 1)
	unit_select.select(clampi(int(info.unit_number) - 1, 0, maxi(0, int(info.unit_count) - 1)))
	top_bar.add_child(unit_select)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	ui.panel_box.add_child(body)

	# Left Column: IRT Stealth Growth Cards
	var left_card: PanelContainer = ui.card(Color("f5f0e2"), 20)
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left_card)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 10)
	left_card.add_child(left_col)

	var lh_row := HBoxContainer.new()
	lh_row.add_theme_constant_override("separation", 8)
	left_col.add_child(lh_row)
	lh_row.add_child(ui.icon_view("leaf", 26))
	var lh_lbl := ui.label("AI 隐性掌握度周报（3PL IRT + H0-H5 支架识别）", 20) as Label
	lh_lbl.add_theme_font_override("font", Style.heading_font())
	lh_row.add_child(lh_lbl)

	var report_label: Label = ui.label("正在汇总小岛生活足迹与立体翻翻书观察记录……", 17, Style.INK)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.add_theme_constant_override("line_spacing", 6)
	report_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(report_label)

	var metrics_pill := PanelContainer.new()
	var m_sb := Style.keycap(Color("faf6eb"), Color("ded2b8"), 2, 14, 12, 8)
	m_sb.shadow_size = 0
	metrics_pill.add_theme_stylebox_override("panel", m_sb)
	left_col.add_child(metrics_pill)

	var metrics_label: Label = ui.label("", 15, Style.SAGE)
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metrics_pill.add_child(metrics_label)

	# Right Column: Current Unit Words -> Jump straight into 3D Pop-up Book Theater!
	var right_card: PanelContainer = ui.card(Color("eef3e7"), 20)
	right_card.custom_minimum_size.x = 432
	body.add_child(right_card)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	right_card.add_child(right_col)

	var rh_row := HBoxContainer.new()
	rh_row.add_theme_constant_override("separation", 8)
	right_col.add_child(rh_row)
	rh_row.add_child(ui.icon_view("book", 24))
	var rh_lbl := ui.label("本单元重点词 · 点一下打开 3D 立体翻翻书", 19) as Label
	rh_lbl.add_theme_font_override("font", Style.heading_font())
	rh_row.add_child(rh_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	var word_grid := GridContainer.new()
	word_grid.columns = 2
	word_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_grid.add_theme_constant_override("h_separation", 10)
	word_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(word_grid)

	for rec: Dictionary in CurriculumDirector.unit_entries(str(info.book_id), str(info.unit_id)).slice(0, 12):
		var eid := str(rec.get("entry_id", ""))
		var wbtn: Button = ui.button("%s\n%s" % [str(rec.get("spelling_display", "")), str(rec.get("meaning_zh", ""))], "open_popup_story:" + eid, false, Vector2(0, 62))
		wbtn.icon = Style.icon("book")
		wbtn.add_theme_constant_override("icon_max_width", 18)
		wbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		wbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wbtn.add_theme_font_size_override("font_size", 16)
		word_grid.add_child(wbtn)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	ui.panel_box.add_child(bottom)

	var b_atlas: Button = ui.button("八册 81 章故事画册", "v4_chapter_atlas", true, Vector2(226, 46))
	b_atlas.icon = Style.icon("compass")
	b_atlas.add_theme_constant_override("icon_max_width", 20)
	bottom.add_child(b_atlas)

	var b_lib: Button = ui.button("1,314 词立体书架", "journey:library", false, Vector2(210, 46))
	b_lib.icon = Style.icon("book")
	b_lib.add_theme_constant_override("icon_max_width", 20)
	bottom.add_child(b_lib)

	var b_raw: Button = ui.button("原始明细档案", "journey:parent", false, Vector2(184, 46))
	b_raw.icon = Style.icon("journal")
	b_raw.add_theme_constant_override("icon_max_width", 22)
	bottom.add_child(b_raw)

	bottom.add_child(ui.button("返回旅行册", "journey:hub", false, Vector2(150, 46)))

	book_select.item_selected.connect(func(idx: int):
		var bid := str(book_select.get_item_metadata(idx))
		if state.journey_select_book(bid):
			state.set_active_unit("unit-1")
			ui.action.emit("v4_parent_ai")
	)
	unit_select.item_selected.connect(func(idx: int):
		if state.set_active_unit("unit-" + str(idx + 1)):
			ui.action.emit("v4_parent_ai")
	)

	if is_instance_valid(bridge):
		var j_snap: Dictionary = state.journey_snapshot()
		var visited := 0
		for lv: Dictionary in j_snap.get("letters", {}).values():
			if bool(lv.get("visited", false)):
				visited += 1
		var v4_dict: Dictionary = state.data.get("v4", {}) if state.data.get("v4") is Dictionary else {}
		var outfit_zh := str(Wardrobe.outfit_info(str(state.data.get("outfit", "yellow"))).get("zh", "晨光柠檬背带装"))
		var req_payload := {
			"book_title": str(info.book_title),
			"unit_id": str(info.unit_id),
			"visited_landmarks": visited,
			"outfit_zh": outfit_zh,
			"stealth_events": v4_dict.get("stealth_events", [])
		}
		var apply_rep := func(rep: Dictionary):
			if not is_instance_valid(report_label):
				return
			report_label.text = str(rep.get("narrative_zh", ""))
			var sum: Dictionary = rep.get("summary", {})
			metrics_label.text = "◈ 综合成长活力指数：%s / 100   ·   IRT 潜能 θ = %s   ·   已追踪词条：%s 个" % [
				str(sum.get("flourish_index", 52)),
				str(sum.get("theta", 0.0)),
				str(sum.get("tracked_word_count", 0))
			]
		if bridge.has_method("_local_fallback_report"):
			apply_rep.call(bridge._local_fallback_report(req_payload))
		bridge.parent_report_ready.connect(apply_rep, Object.CONNECT_ONE_SHOT)
		bridge.request_parent_report(req_payload)

	ui._layout.call_deferred()
