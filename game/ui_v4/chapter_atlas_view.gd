extends RefCounted
## V5 8-Book × 81-Unit Illustrated Cozy Chapter Atlas (`ChapterAtlasView`).
## Tactile storybook chapter directory with clean book tabs, 2-column unit cards,
## visual 3-act step cards, and crisp vector/painted icons with zero raw OS emojis.

const Style = preload("res://ui/island_theme.gd")
const StoryDirector = preload("res://gameplay/unit_storyline_director.gd")
const ThematicPlay = preload("res://gameplay/chapter_thematic_play.gd")

const ROOM_NAMES := {
	"village": "字母岛广场",
	"home": "温馨客厅",
	"home_estate": "阳光小院",
	"school": "山丘学园",
	"classroom": "阳光故事教室",
	"music_room": "音乐工坊",
	"art_room": "美术画室",
	"science_room": "科学观察室",
	"canteen": "校园暖香餐厅",
	"playground": "青草操场",
	"football_field": "绿茵球场",
}

const GRADE_CN := {3: "三", 4: "四", 5: "五", 6: "六"}

static func _room_title(rid: String) -> String:
	if ROOM_NAMES.has(rid):
		return str(ROOM_NAMES[rid])
	if rid.begins_with("landmark_"):
		return rid.trim_prefix("landmark_") + " 字母地标馆"
	return rid

static func build(ui: Node, state: Node) -> void:
	ui._begin("v4_chapter_atlas", "map")
	var current_chap: Dictionary = StoryDirector.active_chapter(state)
	var books: Array = StoryDirector.books()
	var active_book_id := str(current_chap.get("book_id", "xiangshao-g3-1"))
	var active_unit_id := str(current_chap.get("unit_id", "unit-1"))
	var total_done := StoryDirector.total_completed_chapters(state)
	var book_done := StoryDirector.completed_count_for_book(state, active_book_id)
	var book_units: Array = StoryDirector.units_for_book(active_book_id)

	ui._heading(
		"八册 81 章 · 小岛生活主线画册",
		"%s · %s · 本册已点亮 %d / %d 章（全岛 %d / 81 章）" % [
			str(current_chap.get("book_title", "三年级上册")),
			str(current_chap.get("arc_title", "小岛故事")),
			book_done,
			book_units.size(),
			total_done
		]
	)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	ui.panel_box.add_child(top_bar)

	for b: Dictionary in books:
		var bid := str(b.get("book_id", ""))
		var g_num := int(b.get("grade", 3))
		var g_str := str(GRADE_CN.get(g_num, str(g_num)))
		var short_title := "%s%s" % [g_str, "上" if int(b.get("volume", 1)) == 1 else "下"]
		var b_done := StoryDirector.completed_count_for_book(state, bid)
		var b_total := int(b.get("unit_count", 10))
		var is_cur_book := (bid == active_book_id)
		var tab_btn: Button = ui.button(
			"%s  %d/%d" % [short_title, b_done, b_total],
			"v4_atlas_book:" + bid,
			is_cur_book,
			Vector2(0, 42)
		)
		if is_cur_book:
			tab_btn.icon = Style.icon("book")
			tab_btn.add_theme_constant_override("icon_max_width", 18)
			tab_btn.add_theme_constant_override("h_separation", 6)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.add_theme_font_size_override("font_size", 15)
		top_bar.add_child(tab_btn)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	ui.panel_box.add_child(columns)

	# Left Column: Unit Cards Grid for Selected Book
	var left_card: PanelContainer = ui.card(Color("f5f0e2"), 18)
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_card)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_card.add_child(left_scroll)

	var unit_grid := GridContainer.new()
	unit_grid.columns = 2
	unit_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_grid.add_theme_constant_override("h_separation", 10)
	unit_grid.add_theme_constant_override("v_separation", 10)
	left_scroll.add_child(unit_grid)

	for u: Dictionary in book_units:
		var uid := str(u.get("unit_id", "unit-1"))
		var st := int(state.v4_chapter_stage(str(u.get("chapter_key", ""))))
		var stars: String = ["☆☆☆", "★☆☆", "★★☆", "★★★"][clampi(st, 0, 3)]
		var caption := "U%d · %s  %s\n%s · %s" % [
			int(u.get("unit_number", 1)),
			str(u.get("source_title", "")).left(19),
			stars,
			str(u.get("event_title", "")).left(13),
			_room_title(str(u.get("primary_room", "village")))
		]
		var u_btn: Button = ui.button(
			caption,
			"v4_atlas_unit:%s:%s" % [active_book_id, uid],
			uid == active_unit_id,
			Vector2(0, 74)
		)
		u_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		u_btn.add_theme_font_size_override("font_size", 15)
		unit_grid.add_child(u_btn)

	# Right Column: Active Chapter 3-Act Illustrated Storybook Card & Launch
	var right_card: PanelContainer = ui.card(Color("f1f4e8"), 20)
	right_card.custom_minimum_size.x = 472
	columns.add_child(right_card)

	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 8)
	right_card.add_child(rcol)

	var chap_stage := int(state.v4_chapter_stage(str(current_chap.get("chapter_key", ""))))
	var chap_title := ui.label(
		"Unit %d · %s" % [int(current_chap.get("unit_number", 1)), str(current_chap.get("source_title", ""))],
		22
	) as Label
	chap_title.add_theme_font_override("font", Style.heading_font())
	rcol.add_child(chap_title)

	var loc_row := HBoxContainer.new()
	loc_row.add_theme_constant_override("separation", 6)
	rcol.add_child(loc_row)
	loc_row.add_child(ui.icon_view("pin", 18))
	loc_row.add_child(ui.label(
		"%s  ·  %s  ·  %s" % [
			str(current_chap.get("event_title", "")),
			_room_title(str(current_chap.get("primary_room", "village"))),
			str(current_chap.get("host_speaker", "小岛伙伴"))
		],
		15,
		Style.SAGE
	))

	var goal_lbl: Label = ui.label("心愿目标：" + str(current_chap.get("player_goal", "")), 15, Style.INK)
	goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rcol.add_child(goal_lbl)

	var stages_arr: Array = current_chap.get("stages", [])
	for idx in range(stages_arr.size()):
		var st_item: Dictionary = stages_arr[idx]
		var is_done := chap_stage >= idx + 1
		var is_cur := chap_stage == idx
		var step_bg := Color("e2edd7") if is_done else (Color("fff8e0") if is_cur else Color("f8f5eb"))
		var step_bd := Color("9dc08b") if is_done else (Style.GOLD if is_cur else Color("dfd5c0"))
		var step_box := PanelContainer.new()
		var s_sb := StyleBoxFlat.new()
		s_sb.bg_color = step_bg
		s_sb.set_corner_radius_all(12)
		s_sb.border_color = step_bd
		s_sb.set_border_width_all(1 if not is_cur else 2)
		s_sb.content_margin_left = 10
		s_sb.content_margin_right = 10
		s_sb.content_margin_top = 6
		s_sb.content_margin_bottom = 6
		step_box.add_theme_stylebox_override("panel", s_sb)
		rcol.add_child(step_box)

		var done_mark := "✓" if is_done else ("▶" if is_cur else "○")
		var st_lbl: Label = ui.label(
			"%s 第 %d 幕 · %s：%s" % [done_mark, idx + 1, str(st_item.get("title", "")), str(st_item.get("text", ""))],
			14,
			Style.INK if (is_done or is_cur) else Style.MUTED
		)
		st_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_box.add_child(st_lbl)

	var echo_row := HBoxContainer.new()
	echo_row.add_theme_constant_override("separation", 6)
	rcol.add_child(echo_row)
	echo_row.add_child(ui.icon_view("star", 18))
	var echo_lbl: Label = ui.label("世界回响：" + str(current_chap.get("world_keepsake", "")), 14, Color("6f5a38"))
	echo_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	echo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	echo_row.add_child(echo_lbl)

	var fwords: Array = current_chap.get("featured_words", [])
	if not fwords.is_empty():
		var wrow := HBoxContainer.new()
		wrow.add_theme_constant_override("separation", 8)
		rcol.add_child(wrow)
		for fw: Dictionary in fwords.slice(0, 3):
			var feid := str(fw.get("entry_id", ""))
			var fbtn: Button = ui.button(str(fw.get("word", "")), "open_popup_story:" + feid, false, Vector2(0, 36))
			fbtn.icon = Style.icon("book")
			fbtn.add_theme_constant_override("icon_max_width", 18)
			fbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fbtn.add_theme_font_size_override("font_size", 14)
			wrow.add_child(fbtn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rcol.add_child(spacer)

	var t_spec: Dictionary = ThematicPlay.classify_chapter(current_chap)
	var play_btn: Button = ui.button(
		"体验本章主题微玩法 · " + str(t_spec.get("title", "奇趣主题百宝箱")),
		"v4_thematic_open:" + str(current_chap.get("chapter_key", "")),
		false,
		Vector2(0, 44)
	)
	play_btn.icon = Style.icon("play")
	play_btn.add_theme_constant_override("icon_max_width", 20)
	rcol.add_child(play_btn)

	var go_label := "前往【%s】开启本章生活故事" % _room_title(str(current_chap.get("primary_room", "village")))
	if chap_stage >= 3:
		go_label = "前往【%s】重温本章纪念与伙伴" % _room_title(str(current_chap.get("primary_room", "village")))
	var go_btn: Button = ui.button(
		go_label,
		"v4_chap_go:%s:%s" % [active_book_id, active_unit_id],
		true,
		Vector2(0, 48)
	)
	go_btn.icon = Style.icon("sparkle" if chap_stage >= 3 else "compass")
	go_btn.add_theme_constant_override("icon_max_width", 22)
	rcol.add_child(go_btn)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	ui.panel_box.add_child(bottom)
	var lib_btn: Button = ui.button("全八册 1,314 词立体书架", "journey:library", false, Vector2(226, 44))
	lib_btn.icon = Style.icon("book")
	lib_btn.add_theme_constant_override("icon_max_width", 20)
	bottom.add_child(lib_btn)
	var wake_btn: Button = ui.button("猫头鹰晨间温故信", "v5_wake_mailbox", false, Vector2(184, 44))
	wake_btn.icon = Style.icon("compass")
	wake_btn.add_theme_constant_override("icon_max_width", 20)
	bottom.add_child(wake_btn)
	var ai_btn: Button = ui.button("家长 AI 观察室", "v4_parent_ai", false, Vector2(174, 44))
	ai_btn.icon = Style.icon("leaf")
	ai_btn.add_theme_constant_override("icon_max_width", 22)
	bottom.add_child(ai_btn)
	var back_btn: Button = ui.button("返回旅行册", "journey:hub", false, Vector2(148, 44))
	back_btn.icon = Style.icon("journal")
	back_btn.add_theme_constant_override("icon_max_width", 22)
	bottom.add_child(back_btn)

	ui._layout.call_deferred()
