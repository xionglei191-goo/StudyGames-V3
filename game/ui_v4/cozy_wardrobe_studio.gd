extends RefCounted
## V4 Cozy 3D Wardrobe & Styling Studio.
## Provides a sunlit dressing-room turntable with 6 storybook outfits, 5 3D hats,
## and 4 3D back accessories, plus clickable bilingual pronunciation badges.

const Style = preload("res://ui/island_theme.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const PreviewScene = preload("res://ui/character_preview.tscn")

static func build(ui: Node, data: Dictionary, active_tab: String = "outfit") -> void:
	ui._begin("bag", "wardrobe")
	ui._heading("今天，穿哪一种好心情出门？", "阳光换装镜台 · 自由混搭套装、头饰与小背包")

	var w_state: Dictionary = data.get("wardrobe", {}) if data.get("wardrobe") is Dictionary else {}
	var cur_outfit := str(data.get("outfit", "yellow"))
	var cur_hat := str(w_state.get("hat", "none"))
	var cur_bag := str(w_state.get("bag", "none"))

	var body := HBoxContainer.new()
	body.name = "WardrobeBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	ui.panel_box.add_child(body)

	# Left: Sunlit 3D Turntable Mirror Stage + Bilingual Word Tag + Pocket Supplies
	var stage_card: PanelContainer = ui.card(Color("f5efe1"), 18)
	stage_card.custom_minimum_size.x = 340
	stage_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage_card)

	var stage_col := VBoxContainer.new()
	stage_col.add_theme_constant_override("separation", 10)
	stage_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_card.add_child(stage_col)

	ui.wardrobe_preview = PreviewScene.instantiate()
	ui.wardrobe_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_col.add_child(ui.wardrobe_preview)
	ui.wardrobe_preview.setup("player", cur_outfit)
	if ui.wardrobe_preview.has_method("set_wardrobe"):
		ui.wardrobe_preview.set_wardrobe(cur_outfit, cur_hat, cur_bag)

	var outfit_meta := Wardrobe.outfit_info(cur_outfit)
	var hat_meta := Wardrobe.hat_info(cur_hat)
	var bag_meta := Wardrobe.bag_info(cur_bag)
	var look_summary := "%s · %s" % [str(outfit_meta.zh), str(hat_meta.zh) if cur_hat != "none" else str(bag_meta.zh)]
	var en_phrase := "%s%s" % [
		str(outfit_meta.en),
		(" with " + str(hat_meta.en)) if cur_hat != "none" else ((" with " + str(bag_meta.en)) if cur_bag != "none" else "")
	]

	var speak_btn: Button = ui.button("🔊  %s  ·  %s" % [en_phrase, look_summary], "wardrobe_speak:" + en_phrase, false, Vector2(0, 44))
	speak_btn.add_theme_font_size_override("font_size", 16)
	stage_col.add_child(speak_btn)

	var drag_hint: Label = ui.label("按住小人左右拖动旋转 · 随身小口袋：", 14, ui.muted_ink)
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_col.add_child(drag_hint)

	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 8)
	stage_col.add_child(supplies)
	for supply: Array in [["apple", "苹果", data.get("apples", 0)], ["cake", "蛋糕", data.get("cakes", 0)], ["leaf", "叶币", data.get("coins", 0)]]:
		var pill: PanelContainer = ui.card(Color("fbf8ef"), 10)
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		supplies.add_child(pill)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		pill.add_child(row)
		row.add_child(ui.icon_view(str(supply[0]), 24))
		row.add_child(ui.label("%s %s" % [supply[1], str(supply[2])], 15))

	# Right: Category Tabs + Rich Swatch Grid + Home Decoration Shortcut
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size.x = 460
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 12)
	body.add_child(right_col)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	right_col.add_child(tabs)
	for tab_def: Array in [["outfit", "👗 主题穿搭 (6)"], ["hat", "👒 头饰发箍 (5)"], ["bag", "🎒 随身背饰 (4)"]]:
		var tid := str(tab_def[0])
		var tbtn: Button = ui.button(str(tab_def[1]), "wardrobe_tab:" + tid, active_tab == tid, Vector2(0, 46))
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var item_btn: Button = ui.button(caption, prefix + id, selected, Vector2(0, 74))
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_btn.icon = _swatch_icon(Color(str(entry.get("swatch", "#e6b946"))), selected)
		item_btn.add_theme_constant_override("h_separation", 12)
		grid.add_child(item_btn)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	right_col.add_child(footer)
	var dec_btn: Button = ui.button("🏡 回家布置家具与纪念角", "decorate", false, Vector2(0, 48))
	dec_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(dec_btn)
	var done_btn: Button = ui.button("✨ 穿这一身去玩", "close", true, Vector2(170, 48))
	footer.add_child(done_btn)

	ui._layout.call_deferred()

static func _swatch_icon(col: Color, checked: bool) -> ImageTexture:
	var img := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(18.0, 18.0)
	for y in range(36):
		for x in range(36):
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if d <= 14.5:
				img.set_pixel(x, y, col)
			elif d <= 16.8:
				img.set_pixel(x, y, Color("5a4b38") if checked else Color("fffaf0"))
	return ImageTexture.create_from_image(img)
