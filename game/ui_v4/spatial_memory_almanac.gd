extends RefCounted
## V8 16-Room 287-Item 3D Spatial Memory Almanac (`SpatialMemoryAlmanac`).
## Displays live rotating Blender/Tripo `.glb` 3D prop previews, 5-stage Ebbinghaus
## retention badges (Unexplored / Copper Leaf / Dewdrop Due / Consolidating / Gold Star),
## spoken pronunciation stars, and 1-click jump to any furniture anchor.

const Style = preload("res://ui/island_theme.gd")
const SpatialBench = preload("res://gameplay/spatial_cluster_bench_3d.gd")
const CastDirector = preload("res://gameplay/home_school_cast_director.gd")
const V8Memory = preload("res://core/v8_memory_ledger.gd")


class PropTurntable extends SubViewportContainer:
	var _vp: SubViewport
	var _pivot: Node3D
	var _bench_helper: Node3D

	func _ready() -> void:
		stretch = true
		custom_minimum_size = Vector2(206, 152)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.size = Vector2i(206, 152)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vp)

		var root3d := Node3D.new()
		_vp.add_child(root3d)

		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("fff8ec")
		env.ambient_light_energy = 0.88
		var we := WorldEnvironment.new()
		we.environment = env
		root3d.add_child(we)

		var key_light := DirectionalLight3D.new()
		key_light.light_color = Color("fff5df")
		key_light.light_energy = 1.15
		key_light.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
		root3d.add_child(key_light)

		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.62
		cam.position = Vector3(0.0, 0.46, 0.88)
		cam.look_at_from_position(cam.position, Vector3(0.0, 0.16, 0.0), Vector3.UP)
		root3d.add_child(cam)

		_pivot = Node3D.new()
		root3d.add_child(_pivot)

		_bench_helper = SpatialBench.new()
		add_child(_bench_helper)

	func show_prop(shape: String, color_hex: String, word_key: String) -> void:
		if not is_instance_valid(_pivot) or not is_instance_valid(_bench_helper):
			return
		for ch: Node in _pivot.get_children():
			_pivot.remove_child(ch)
			ch.queue_free()
		var prop: Node3D = _bench_helper._build_layer2_prop(shape, color_hex, word_key, "surface")
		if prop != null:
			_pivot.add_child(prop)

	func _process(delta: float) -> void:
		if is_instance_valid(_pivot):
			_pivot.rotation.y += delta * 0.85


static func build(ui: Node, state: Node, bridge: Node, selected_room: String = "", selected_word: String = "") -> void:
	ui._begin("v8_almanac", "journal")
	var now_sec := int(Time.get_unix_time_from_system())
	var sum := V8Memory.summary(state.data, now_sec)

	ui._heading(
		"16 房间 3D 实物记忆图鉴",
		"已点亮 %d / 287 处空间实物（%d 词） · ★ 金星永固 %d · ◈ 待温故 %d · ♪ 发音星 %d" % [
			int(sum.get("visited_placements", 0)),
			int(sum.get("discovered_words", 0)),
			int(sum.get("gold_words", 0)),
			int(sum.get("due_words", 0)),
			int(sum.get("spoken_words", 0)),
		]
	)

	var all_rooms: Array = CastDirector.HOME_ROOMS + CastDirector.SCHOOL_ROOMS
	var active_r := selected_room if (not selected_room.is_empty() and all_rooms.has(selected_room)) else str(all_rooms[0])

	var body := HBoxContainer.new()
	body.name = "AlmanacBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	ui.panel_box.add_child(body)

	# Left Column: 16 Room Tabs with Exploration & Due Badges
	var left_card: PanelContainer = ui.card(Color("f5efe0"), 18)
	left_card.custom_minimum_size.x = 248
	body.add_child(left_card)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_card.add_child(left_scroll)

	var room_col := VBoxContainer.new()
	room_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_col.add_theme_constant_override("separation", 6)
	left_scroll.add_child(room_col)

	var mem := V8Memory.ensure(state.data)
	var visited_slots: Dictionary = mem.get("visited_slots", {})
	var items_ledger: Dictionary = mem.get("items", {})

	for rid_v: Variant in all_rooms:
		var rid := str(rid_v)
		var cl := SpatialBench.cluster_for_room(rid)
		var r_zh := str(cl.get("room_name_zh", rid))
		var total_in_r := 0
		var seen_in_r := 0
		var due_in_r := 0
		for m_v: Variant in cl.get("macro_items", []):
			if not (m_v is Dictionary):
				continue
			var md := m_v as Dictionary
			var a_ord := int(md.get("anchor_order", 1))
			for it_v: Variant in md.get("layer2_items", []):
				if not (it_v is Dictionary):
					continue
				total_in_r += 1
				var wk := str((it_v as Dictionary).get("word", "")).to_lower()
				if visited_slots.has("%s:%d:%s" % [rid, a_ord, wk]) or items_ledger.has(wk):
					seen_in_r += 1
				if V8Memory.is_word_due(state.data, wk, now_sec) and str((items_ledger.get(wk, {}) as Dictionary).get("room_id", "")) == rid:
					due_in_r += 1

		var due_tag := (" ◈%d" % due_in_r) if due_in_r > 0 else ""
		var tab_btn: Button = ui.button(
			"%s (%d/%d)%s" % [r_zh, seen_in_r, total_in_r, due_tag],
			"v8_almanac_room:" + rid,
			rid == active_r,
			Vector2(0, 40)
		)
		tab_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.add_theme_font_size_override("font_size", 14)
		room_col.add_child(tab_btn)

	# Right Column: Live 3D Turntable Inspector + Room's Layer-2 Grid
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 12)
	body.add_child(right_col)

	var active_cl := SpatialBench.cluster_for_room(active_r)
	var flat_items: Array[Dictionary] = []
	for m_v2: Variant in active_cl.get("macro_items", []):
		if not (m_v2 is Dictionary):
			continue
		var md2 := m_v2 as Dictionary
		var a_ord2 := int(md2.get("anchor_order", 1))
		var a_zh2 := str(md2.get("zh", "家具"))
		var a_en2 := str(md2.get("word", "furniture"))
		for it_v2: Variant in md2.get("layer2_items", []):
			if not (it_v2 is Dictionary):
				continue
			var entry := (it_v2 as Dictionary).duplicate(true)
			entry["anchor_order"] = a_ord2
			entry["anchor_zh"] = a_zh2
			entry["anchor_en"] = a_en2
			flat_items.append(entry)

	var focus_entry: Dictionary = flat_items[0] if not flat_items.is_empty() else {}
	var target_w := selected_word.strip_edges().to_lower()
	if not target_w.is_empty():
		for cand: Dictionary in flat_items:
			if str(cand.get("word", "")).to_lower() == target_w:
				focus_entry = cand
				break

	# Top Inspector Card with Live 3D .glb Turntable
	var insp_card: PanelContainer = ui.card(Color("faf6ea"), 18)
	right_col.add_child(insp_card)

	var insp_row := HBoxContainer.new()
	insp_row.add_theme_constant_override("separation", 16)
	insp_card.add_child(insp_row)

	var stage_frame: PanelContainer = ui.card(Color("efe7d2"), 14)
	insp_row.add_child(stage_frame)

	var turntable := PropTurntable.new()
	turntable.name = "Almanac3DTurntable"
	stage_frame.add_child(turntable)

	var detail_col := VBoxContainer.new()
	detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_col.add_theme_constant_override("separation", 6)
	insp_row.add_child(detail_col)

	var f_word := str(focus_entry.get("word", "book"))
	var f_key := f_word.to_lower()
	var f_zh := str(focus_entry.get("zh", "书本"))
	var f_order := int(focus_entry.get("anchor_order", 1))
	var f_anchor_zh := str(focus_entry.get("anchor_zh", "书桌"))
	var f_status := _status_badge_for(state.data, active_r, f_order, f_key, now_sec)

	var title_lbl: Label = ui.label("%s · %s   [%s]" % [f_word, f_zh, str(f_status["label"])], 21, Style.INK)
	title_lbl.add_theme_font_override("font", Style.heading_font())
	detail_col.add_child(title_lbl)

	var loc_lbl: Label = ui.label(
		"所在位置：%s › 第 %d 处「%s（%s）」  ·  口语星标：%s" % [
			str(active_cl.get("room_name_zh", active_r)),
			f_order,
			str(focus_entry.get("anchor_en", "")),
			f_anchor_zh,
			str(f_status["spoken_label"]),
		],
		14,
		Style.SAGE
	)
	detail_col.add_child(loc_lbl)

	var sent_lbl: Label = ui.label(
		"%s  /  %s" % [str(focus_entry.get("sentence_en", "")), str(focus_entry.get("sentence_zh", ""))],
		15,
		Style.MUTED
	)
	sent_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_col.add_child(sent_lbl)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	detail_col.add_child(act_row)

	var listen_btn: Button = ui.button("♪ 听标准发音", "", false, Vector2(138, 38))
	listen_btn.pressed.connect(func():
		if is_instance_valid(bridge):
			bridge.speak_text("%s. %s" % [f_word, str(focus_entry.get("sentence_en", ""))], "en", str(active_cl.get("companion_npc_id", "warm")))
	)
	act_row.add_child(listen_btn)

	var goto_btn: Button = ui.button("▷ 去「%s」实地摆放跟读" % f_anchor_zh, "v6_bench_open:%s:%d" % [active_r, f_order], true, Vector2(226, 38))
	act_row.add_child(goto_btn)

	turntable.call_deferred(
		"show_prop",
		str(focus_entry.get("shape", "book")),
		str(focus_entry.get("color", "5b9bd5")),
		f_key
	)

	# Grid of all Layer-2 items in this room
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(grid_scroll)

	var item_grid := GridContainer.new()
	item_grid.name = "AlmanacItemGrid"
	item_grid.columns = 3
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 10)
	item_grid.add_theme_constant_override("v_separation", 8)
	grid_scroll.add_child(item_grid)

	for it_d: Dictionary in flat_items:
		var iw := str(it_d.get("word", ""))
		var ik := iw.to_lower()
		var izh := str(it_d.get("zh", ""))
		var iord := int(it_d.get("anchor_order", 1))
		var st_info := _status_badge_for(state.data, active_r, iord, ik, now_sec)
		var sp_mark := " · ♪" if int(st_info["spoken_tier"]) >= 2 else ""
		var ibtn: Button = ui.button(
			"%s %s · %s\n%s · %s%s" % [
				str(st_info["glyph"]),
				iw,
				izh,
				str(it_d.get("anchor_zh", "")),
				str(st_info["label"]),
				sp_mark,
			],
			"v8_almanac_pick:%s:%s" % [active_r, ik],
			ik == f_key,
			Vector2(0, 62)
		)
		ibtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ibtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ibtn.add_theme_font_size_override("font_size", 14)
		item_grid.add_child(ibtn)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	ui.panel_box.add_child(footer)
	footer.add_child(ui.button("家长 AI 成长观察室", "v4_parent_ai", false, Vector2(196, 44)))
	footer.add_child(ui.button("返回旅行册", "journey:hub", false, Vector2(150, 44)))

	ui._layout.call_deferred()


static func _status_badge_for(data: Dictionary, room_id: String, anchor_order: int, word_key: String, now_sec: int) -> Dictionary:
	var mem := V8Memory.ensure(data)
	var items: Dictionary = mem.get("items", {})
	var visited_slots: Dictionary = mem.get("visited_slots", {})
	if not items.has(word_key) and not visited_slots.has("%s:%d:%s" % [room_id, anchor_order, word_key]):
		return {"glyph": "◇", "label": "未探索", "spoken_tier": 0, "spoken_label": "未跟读"}

	var rec: Dictionary = items.get(word_key, {})
	var stg := int(rec.get("stage", 1))
	var sp_tier := int(rec.get("spoken_tier", 0))
	var sp_lbl := str(V8Memory.SPOKEN_LABELS.get(sp_tier, "未跟读"))

	if V8Memory.is_word_due(data, word_key, now_sec):
		return {"glyph": "◈", "label": "露珠待温故", "spoken_tier": sp_tier, "spoken_label": sp_lbl}
	if stg >= 5:
		return {"glyph": "★", "label": "金星永固", "spoken_tier": sp_tier, "spoken_label": sp_lbl}
	if stg >= 2:
		return {"glyph": "◈", "label": str(V8Memory.STAGE_LABELS.get(stg, "巩固中")), "spoken_tier": sp_tier, "spoken_label": sp_lbl}
	return {"glyph": "·", "label": "铜叶初识", "spoken_tier": sp_tier, "spoken_label": sp_lbl}
