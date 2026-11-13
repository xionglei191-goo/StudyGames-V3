extends RefCounted
## V5 Cozy 3D Wardrobe & Styling Studio.
## Sunlit wooden turntable mirror stage with 6 storybook outfits, 5 3D hats,
## 4 3D back accessories, tactile enamel color tokens, and zero raw OS emojis.

const Style = preload("res://ui/island_theme.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const PreviewScene = preload("res://ui/character_preview.tscn")

static func build(ui: Node, data: Dictionary, active_tab: String = "outfit") -> void:
	ui._begin("bag", "wardrobe")
	ui._heading("今天，穿哪一种好心情出门？", "阳光换装镜台 · 自由混搭套装、头饰与随身背饰")

	var w_state: Dictionary = data.get("wardrobe", {}) if data.get("wardrobe") is Dictionary else {}
	var cur_outfit := str(data.get("outfit", "yellow"))
	var cur_hat := str(w_state.get("hat", "none"))
	var cur_bag := str(w_state.get("bag", "none"))

	var body := HBoxContainer.new()
	body.name = "WardrobeBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	ui.panel_box.add_child(body)

	# Left: Sunlit 3D Turntable Mirror Stage + Spin Controls + Pocket Supplies
	var stage_card: PanelContainer = ui.card(Color("f5efe0"), 22)
	stage_card.custom_minimum_size.x = 356
	stage_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage_card)

	var stage_col := VBoxContainer.new()
	stage_col.add_theme_constant_override("separation", 10)
	stage_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_card.add_child(stage_col)

	var stage_well := PanelContainer.new()
	stage_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var well_sb := StyleBoxFlat.new()
	well_sb.bg_color = Color("f4efe1")
	well_sb.set_corner_radius_all(18)
	well_sb.border_color = Color("dfd2b8")
	well_sb.set_border_width_all(2)
	stage_well.add_theme_stylebox_override("panel", well_sb)
	stage_col.add_child(stage_well)

	ui.wardrobe_preview = PreviewScene.instantiate()
	ui.wardrobe_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_well.add_child(ui.wardrobe_preview)
	ui.wardrobe_preview.setup("player", cur_outfit)
	if ui.wardrobe_preview.has_method("set_wardrobe"):
		ui.wardrobe_preview.set_wardrobe(cur_outfit, cur_hat, cur_bag)

	# Turntable Left/Right Spin Overlay inside the 3D Stage Well
	var spin_margin := MarginContainer.new()
	spin_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spin_margin.add_theme_constant_override("margin_left", 10)
	spin_margin.add_theme_constant_override("margin_right", 10)
	spin_margin.add_theme_constant_override("margin_bottom", 10)
	spin_margin.size_flags_vertical = Control.SIZE_SHRINK_END
	stage_well.add_child(spin_margin)

	var spin_row := HBoxContainer.new()
	spin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spin_margin.add_child(spin_row)

	var spin_l: Button = ui.button("", "wardrobe_spin:left", false, Vector2(40, 40))
	spin_l.icon = Style.icon("undo")
	spin_l.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin_l.tooltip_text = "向左转一圈看看侧面"
	spin_row.add_child(spin_l)

	var spin_spacer := Control.new()
	spin_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spin_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_row.add_child(spin_spacer)

	var spin_r: Button = ui.button("", "wardrobe_spin:right", false, Vector2(40, 40))
	spin_r.icon = Style.icon("rotate")
	spin_r.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin_r.tooltip_text = "向右转一圈看看背面小书包"
	spin_row.add_child(spin_r)

	var outfit_meta: Dictionary = Wardrobe.outfit_info(cur_outfit)
	var hat_meta: Dictionary = Wardrobe.hat_info(cur_hat)
	var bag_meta: Dictionary = Wardrobe.bag_info(cur_bag)
	var look_summary := "%s · %s" % [str(outfit_meta.zh), str(hat_meta.zh) if cur_hat != "none" else str(bag_meta.zh)]
	var en_phrase := "%s%s" % [
		str(outfit_meta.en),
		(" with " + str(hat_meta.en)) if cur_hat != "none" else ((" with " + str(bag_meta.en)) if cur_bag != "none" else "")
	]

	var speak_btn: Button = ui.button("%s\n%s" % [en_phrase, look_summary], "wardrobe_speak:" + en_phrase, false, Vector2(0, 52))
	speak_btn.icon = Style.icon("speaker")
	speak_btn.add_theme_constant_override("icon_max_width", 22)
	speak_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speak_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	speak_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speak_btn.add_theme_font_size_override("font_size", 14)
	stage_col.add_child(speak_btn)

	var drag_hint: Label = ui.label("按住小人左右拖动或点旋转键欣赏全身 · 随身小口袋", 13, ui.muted_ink)
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_col.add_child(drag_hint)

	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 8)
	stage_col.add_child(supplies)
	for supply: Array in [["apple", "苹果", data.get("apples", 0)], ["cake", "蛋糕", data.get("cakes", 0)], ["leaf", "叶币", data.get("coins", 0)]]:
		var pill: PanelContainer = ui.card(Color("fbf8ef"), 14)
		var psb := Style.keycap(Color("fbf8ef"), Color("e2d5bc"), 2, 14, 10, 7)
		psb.shadow_size = 0
		pill.add_theme_stylebox_override("panel", psb)
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		supplies.add_child(pill)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		pill.add_child(row)
		row.add_child(ui.icon_view(str(supply[0]), 22))
		row.add_child(ui.label("%s %s" % [supply[1], str(supply[2])], 15))

	# Right: Category Tabs + Tactile Enamel Swatch Grid + Home Studio Shortcut
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size.x = 468
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 12)
	body.add_child(right_col)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	right_col.add_child(tabs)
	for tab_def: Array in [["outfit", "主题穿搭 (6)", "outfit"], ["hat", "头饰发箍 (5)", "sun"], ["bag", "随身背饰 (4)", "bag"]]:
		var tid := str(tab_def[0])
		var tbtn: Button = ui.button(str(tab_def[1]), "wardrobe_tab:" + tid, active_tab == tid, Vector2(0, 46))
		tbtn.icon = Style.icon(str(tab_def[2]))
		tbtn.add_theme_constant_override("icon_max_width", 24)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.add_theme_font_size_override("font_size", 16)
		tabs.add_child(tbtn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var catalog_items: Array = Wardrobe.OUTFIT_CATALOG if active_tab == "outfit" else (Wardrobe.HAT_CATALOG if active_tab == "hat" else Wardrobe.BAG_CATALOG)
	var current_id := cur_outfit if active_tab == "outfit" else (cur_hat if active_tab == "hat" else cur_bag)
	var prefix := "outfit:" if active_tab == "outfit" else ("hat:" if active_tab == "hat" else "bag:")

	for entry: Dictionary in catalog_items:
		var id := str(entry.id)
		var selected := (id == current_id)
		var caption := "%s\n%s" % [str(entry.zh), str(entry.en)]
		var item_btn: Button = ui.button(caption, prefix + id, selected, Vector2(0, 76))
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_btn.icon = _swatch_icon(Color(str(entry.get("swatch", "#e6b946"))), selected)
		item_btn.add_theme_constant_override("icon_max_width", 42)
		item_btn.add_theme_constant_override("h_separation", 12)
		item_btn.add_theme_font_size_override("font_size", 17)
		grid.add_child(item_btn)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	right_col.add_child(footer)
	var dec_btn: Button = ui.button("回家布置家具与纪念角", "decorate", false, Vector2(0, 48))
	dec_btn.icon = Style.icon("home")
	dec_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(dec_btn)
	var done_btn: Button = ui.button("穿这一身去玩", "close", true, Vector2(184, 48))
	done_btn.icon = Style.icon("sparkle")
	done_btn.add_theme_constant_override("icon_max_width", 22)
	footer.add_child(done_btn)

	ui._layout.call_deferred()

static func _swatch_icon(col: Color, checked: bool) -> ImageTexture:
	var sz := 44
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(22.0, 22.0)
	var spec_center := Vector2(16.5, 15.5)
	for y in range(sz):
		for x in range(sz):
			var pt := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d := pt.distance_to(center)
			if d > 20.6:
				continue
			var px := col
			if d >= 18.0:
				px = Color("fffdf8") if checked else Color("cdbda0")
			elif d >= 16.2:
				px = Color("43684b") if checked else Color("fffaf0")
			else:
				if pt.distance_to(spec_center) < 5.0:
					px = col.lightened(0.22)
				if checked and d < 4.2:
					px = Color("fffdf8")
			var alpha := clampf(20.6 - d, 0.0, 1.0)
			px.a = alpha
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)
