extends Control
## V5 Tactile Storybook HUD Frame.
## Airy floating pills around the 3D Toy Diorama: sunlit avatar & place badge,
## honey bookmark wish pill, leaf-coin wallet, and a balanced 3-pill belongings dock.

const Style = preload("res://ui/island_theme.gd")
const Preview = preload("res://ui/character_preview.tscn")

var ui: CanvasLayer
var identity: PanelContainer
var wish: Button
var utilities: PanelContainer
var dock: PanelContainer
var level_banner: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _dialogue_open := false

func setup(owner_ui: CanvasLayer) -> void:
	ui = owner_ui
	name = "IslandHUD"

	# 1. Top-Left Sunlit Identity Pill (Avatar Ring + Location + Weather/Day)
	identity = _floating_pill("PlaceAndPlayer", Color(0.996, 0.984, 0.948, 0.95), Color("dfd1b5"), 24, 14, 10)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	identity.add_child(header)

	var avatar: Button = ui.button("", "bag", false, Vector2(54, 54))
	avatar.name = "PlayerWardrobe"
	avatar.tooltip_text = "阳光换装镜台 · B"
	_avatar_badge_style(avatar)
	avatar.clip_contents = true
	header.add_child(avatar)

	ui.avatar_preview = Preview.instantiate()
	avatar.add_child(ui.avatar_preview)
	ui.avatar_preview.setup("player", "yellow", true)
	ui.avatar_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.avatar_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 3)
	header.add_child(titles)

	ui.location_label = _text("我的小岛", 20, true)
	ui.location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.location_label.custom_minimum_size.x = 220
	ui.status = _text("第 1 天 · 晴", 13)
	ui.status.add_theme_color_override("font_color", Style.MUTED)
	titles.add_child(ui.location_label)
	titles.add_child(ui.status)

	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 6)
	titles.add_child(exp_row)

	ui.exp_bar = ProgressBar.new()
	ui.exp_bar.name = "HUDExpBar"
	ui.exp_bar.show_percentage = false
	ui.exp_bar.min_value = 0.0
	ui.exp_bar.max_value = 100.0
	ui.exp_bar.value = 0.0
	ui.exp_bar.custom_minimum_size = Vector2(96, 8)
	ui.exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("efe5cd")
	bar_bg.set_corner_radius_all(4)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = Color("e3ad44")
	bar_fg.set_corner_radius_all(4)
	ui.exp_bar.add_theme_stylebox_override("background", bar_bg)
	ui.exp_bar.add_theme_stylebox_override("fill", bar_fg)
	exp_row.add_child(ui.exp_bar)

	ui.exp_caption = _text("0/60 EXP", 12, true)
	ui.exp_caption.name = "HUDExpCaption"
	ui.exp_caption.add_theme_color_override("font_color", Color("856428"))
	exp_row.add_child(ui.exp_caption)

	# 2. Honey Bookmark Wish Pill (Click to auto-guide)
	wish = ui.button("", "quest", false, Vector2(308, 80))
	wish.name = "TodayWish"
	wish.tooltip_text = "接着今天的小心愿 · 点击自动引路"
	add_child(wish)
	_style_wish_button(wish)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_right = -14
	content.offset_top = 10
	content.offset_bottom = -12
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	wish.add_child(content)

	var star_wrap := CenterContainer.new()
	star_wrap.custom_minimum_size = Vector2(34, 34)
	star_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(star_wrap)
	var star_chip := PanelContainer.new()
	star_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc_sb := StyleBoxFlat.new()
	sc_sb.bg_color = Color("faecc6")
	sc_sb.set_corner_radius_all(17)
	sc_sb.set_content_margin_all(6)
	star_chip.add_theme_stylebox_override("panel", sc_sb)
	star_wrap.add_child(star_chip)
	star_chip.add_child(ui.icon_view("sparkle", 20))

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 3)
	content.add_child(words)

	var caption := _text("今天的小心愿", 13)
	caption.add_theme_color_override("font_color", Color("8a6d35"))
	words.add_child(caption)

	ui.objective = _text("和熊叔打个招呼", 18, true)
	ui.objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.objective.max_lines_visible = 2
	ui.objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(ui.objective)

	var go_wrap := CenterContainer.new()
	go_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(go_wrap)
	go_wrap.add_child(ui.icon_view("arrow", 18))

	# 3. Top-Right Joint Level Badge + Leaf Wallet & Settings Pill
	utilities = _floating_pill("WalletAndSettings", Color(0.996, 0.984, 0.948, 0.95), Color("dfd1b5"), 24, 14, 8)
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 10)
	utilities.add_child(tools)

	ui.level_chip_btn = ui.button("★ Lv.1 · 启蒙小芽", "level_guide", false, Vector2(0, 38))
	ui.level_chip_btn.name = "HUDLevelBadge"
	ui.level_chip_btn.tooltip_text = "查看成长等级、经验进度与升级叶币礼袋"
	ui.level_chip_btn.add_theme_font_size_override("font_size", 15)
	_style_level_chip(ui.level_chip_btn)
	tools.add_child(ui.level_chip_btn)

	var coin_chip := PanelContainer.new()
	coin_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc_sb := StyleBoxFlat.new()
	cc_sb.bg_color = Color("eff4e6")
	cc_sb.set_corner_radius_all(16)
	cc_sb.content_margin_left = 10
	cc_sb.content_margin_right = 12
	cc_sb.content_margin_top = 5
	cc_sb.content_margin_bottom = 5
	coin_chip.add_theme_stylebox_override("panel", cc_sb)
	tools.add_child(coin_chip)

	var coin_row := HBoxContainer.new()
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_theme_constant_override("separation", 6)
	coin_chip.add_child(coin_row)
	coin_row.add_child(ui.icon_view("leaf", 24))
	ui.currency = _text("30", 19, true)
	ui.currency.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.currency.custom_minimum_size.x = 32
	coin_row.add_child(ui.currency)

	var settings: Button = ui.button("", "settings", false, Vector2(44, 44))
	settings.name = "HUDSettings"
	settings.icon = Style.icon("settings")
	settings.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.tooltip_text = "设置与家园入口 · Esc"
	_round_icon_button(settings)
	tools.add_child(settings)

	# 4. Balanced Bottom-Center 3-Pill Toy Dock
	dock = _floating_pill("BelongingsTray", Color(0.992, 0.978, 0.938, 0.94), Color("dcd0b4"), 28, 10, 8)
	ui.nav_controls = HBoxContainer.new()
	ui.nav_controls.add_theme_constant_override("separation", 10)
	dock.add_child(ui.nav_controls)

	for entry: Array in [
		["地图", "map", "map", "导览地图 · M"],
		["换装", "bag", "bag", "换装与随身小包 · B"],
		["旅行册", "journey:hub", "journal", "故事与八册画册 · J"]
	]:
		var primary: bool = entry[1] == "journey:hub"
		var item: Button = ui.button(str(entry[0]), str(entry[1]), primary, Vector2(138, 54))
		item.name = "HUD_" + str(entry[2])
		item.icon = Style.icon(str(entry[2]))
		item.tooltip_text = str(entry[3])
		item.add_theme_font_size_override("font_size", 19)
		item.add_theme_constant_override("icon_max_width", 32)
		item.add_theme_constant_override("h_separation", 8)
		_style_dock_item(item, primary)
		ui.nav_controls.add_child(item)

	# 5. Whisper-Quiet Controls Hint Pill (Bottom-Left)
	ui.controls_hint = _text("左键点按或长按漫步 · 右键转视角 · Shift 小跑", 13)
	ui.controls_hint.name = "MovementHint"
	ui.controls_hint.add_theme_color_override("font_color", Color("5e5949"))
	ui.controls_hint.add_theme_stylebox_override("normal", _whisper_pill())
	ui.controls_hint.tooltip_text = "左键点按/长按漫步 · 右键拖动旋转视角 · 滚轮缩放 · Shift 小跑 · E 互动 · M 地图 · B 换装 · J 旅行册"
	add_child(ui.controls_hint)

	# 6. World-Anchored Tactile Interaction Callout Pill (`E` / `Q`)
	ui.prompt = ui.button("聊一聊  [E]", "interact", true, Vector2(168, 46))
	ui.prompt.name = "ContextAction"
	ui.prompt.add_theme_font_size_override("font_size", 18)
	_style_prompt_pill(ui.prompt, true)
	ui.prompt.hide()
	add_child(ui.prompt)

	ui.prompt_cycle = ui.button("切换 [Q]", "cycle_interaction", false, Vector2(132, 46))
	ui.prompt_cycle.name = "CycleNearbyAction"
	ui.prompt_cycle.add_theme_font_size_override("font_size", 16)
	_style_prompt_pill(ui.prompt_cycle, false)
	ui.prompt_cycle.hide()
	add_child(ui.prompt_cycle)

	# 7. Hover Callout Tag
	ui.hover_prompt = ui.label("", 15)
	ui.hover_prompt.name = "HoveredInteractionName"
	ui.hover_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hp_sb := Style.pill(Color(0.998, 0.988, 0.955, 0.96), Color("dec798"), Color("cbb17d"), 16, 14, 8)
	ui.hover_prompt.add_theme_stylebox_override("normal", hp_sb)
	ui.hover_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.hover_prompt.hide()
	add_child(ui.hover_prompt)

	# 8. Active Route Whisper Pill
	ui.navigation_label = _text("", 14)
	ui.navigation_label.name = "RouteStatus"
	ui.navigation_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.navigation_label.add_theme_color_override("font_color", Style.SAGE_DEEP)
	ui.navigation_label.add_theme_stylebox_override("normal", _whisper_pill(Color(0.94, 0.97, 0.91, 0.92)))
	ui.navigation_label.hide()
	add_child(ui.navigation_label)

	# 9. Ambient Greeting Mini-Cloud
	ui.bubble_panel = PanelContainer.new()
	ui.bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bp_sb := Style.pill(Color(1.0, 0.99, 0.96, 0.96), Color("dfd2b7"), Color("cbbba0"), 18, 16, 10)
	ui.bubble_panel.add_theme_stylebox_override("panel", bp_sb)
	ui.bubble_label = _text("", 16)
	ui.bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.bubble_panel.add_child(ui.bubble_label)
	ui.bubble_panel.hide()
	add_child(ui.bubble_panel)

	# 10. Top-Center Sunlit Level-Up Celebration Banner
	level_banner = PanelContainer.new()
	level_banner.name = "LevelUpCelebration"
	level_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb_sb := Style.pill(Color(0.998, 0.982, 0.918, 0.98), Color("dfb24f"), Color("c69635"), 22, 22, 12)
	lb_sb.shadow_size = 10
	level_banner.add_theme_stylebox_override("panel", lb_sb)
	var lb_col := VBoxContainer.new()
	lb_col.alignment = BoxContainer.ALIGNMENT_CENTER
	lb_col.add_theme_constant_override("separation", 4)
	lb_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_banner.add_child(lb_col)
	_banner_title = _text("★ 升级啦！Lv.2 · 好奇认物生", 20, true)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_color_override("font_color", Color("6e4a12"))
	lb_col.add_child(_banner_title)
	_banner_sub = _text("获赠升级奖学金礼袋 +15 叶币", 14)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_color_override("font_color", Color("466847"))
	lb_col.add_child(_banner_sub)
	level_banner.hide()
	add_child(level_banner)

func show_celebration(payload: Dictionary, reduced: bool = false) -> void:
	if not is_instance_valid(level_banner):
		return
	var nlv := int(payload.get("new_level", 1))
	var tzh := str(payload.get("title_zh", ""))
	var ten := str(payload.get("title_en", ""))
	var gift := int(payload.get("gift_coins", 0))
	var unlock_zh := str(payload.get("unlock_zh", ""))
	_banner_title.text = "★ 升级啦！Lv.%d · %s（%s）" % [nlv, tzh, ten]
	_banner_sub.text = "升级礼袋 +%d 叶币  ｜  %s" % [gift, unlock_zh]
	level_banner.show()
	arrange(size if size.x > 10.0 else Vector2(1440, 900))
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	level_banner.modulate = Color(1, 1, 1, 1)
	if not reduced:
		var target_y := level_banner.position.y
		level_banner.position.y = target_y - 24.0
		level_banner.modulate.a = 0.0
		_banner_tween = create_tween()
		_banner_tween.set_parallel(true)
		_banner_tween.tween_property(level_banner, "position:y", target_y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_banner_tween.tween_property(level_banner, "modulate:a", 1.0, 0.20)
		_banner_tween.set_parallel(false)
		_banner_tween.tween_interval(3.8)
		_banner_tween.tween_property(level_banner, "modulate:a", 0.0, 0.35)
		_banner_tween.tween_callback(level_banner.hide)
	else:
		_banner_tween = create_tween()
		_banner_tween.tween_interval(3.8)
		_banner_tween.tween_callback(level_banner.hide)

func set_dialogue_mode(open: bool) -> void:
	_dialogue_open = open
	if is_instance_valid(dock):
		dock.visible = not open
	if is_instance_valid(ui) and is_instance_valid(ui.controls_hint):
		ui.controls_hint.visible = not open
	if open and is_instance_valid(ui):
		ui.hide_interaction_prompts()

func arrange(available: Vector2) -> void:
	if not is_instance_valid(identity):
		return
	identity.position = Vector2(20, 20)
	identity.size = Vector2(328, 92)
	wish.position = Vector2(20, identity.position.y + identity.size.y + 10)
	wish.size = Vector2(328, 82)
	utilities.size = utilities.get_combined_minimum_size()
	utilities.position = Vector2(available.x - utilities.size.x - 20, 20)
	if is_instance_valid(level_banner) and level_banner.visible:
		var b_min := level_banner.get_combined_minimum_size()
		level_banner.size = Vector2(maxf(440.0, b_min.x), maxf(68.0, b_min.y))
		level_banner.position = Vector2((available.x - level_banner.size.x) * 0.5, 20.0)
	dock.size = dock.get_combined_minimum_size()
	dock.position = Vector2((available.x - dock.size.x) * 0.5, available.y - dock.size.y - 20)
	var hint_min: Vector2 = (ui.controls_hint as Control).get_combined_minimum_size()
	ui.controls_hint.size = Vector2(maxf(250.0, hint_min.x), maxf(34.0, hint_min.y))
	ui.controls_hint.position = Vector2(20, available.y - ui.controls_hint.size.y - 22)
	ui.navigation_label.position = Vector2(20, wish.position.y + wish.size.y + 8)
	ui.navigation_label.size = Vector2(328, 34)
	dock.visible = not _dialogue_open
	ui.controls_hint.visible = not _dialogue_open

func _floating_pill(node_name: String, bg: Color, rim: Color, radius: int, pad_h: int, pad_v: int) -> PanelContainer:
	var result := PanelContainer.new()
	result.name = node_name
	var fill := Style.pill(bg, rim, rim.darkened(0.08), radius, pad_h, pad_v)
	result.add_theme_stylebox_override("panel", fill)
	add_child(result)
	return result

func _whisper_pill(bg: Color = Color(0.996, 0.984, 0.945, 0.84)) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = bg
	fill.set_corner_radius_all(16)
	fill.content_margin_left = 14
	fill.content_margin_right = 14
	fill.content_margin_top = 7
	fill.content_margin_bottom = 7
	fill.border_color = Color(0.84, 0.78, 0.66, 0.55)
	fill.set_border_width_all(1)
	return fill

func _text(value: String, pixels: int, bold: bool = false) -> Label:
	var result := Style.text(value, pixels, Style.INK)
	result.add_theme_font_size_override("font_size", pixels)
	if bold:
		result.add_theme_font_override("font", Style.heading_font())
	return result

func _avatar_badge_style(item: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("f4ecd8") if state == "normal" else Color("fbeec9")
		fill.set_corner_radius_all(27)
		fill.set_content_margin_all(2)
		fill.border_color = Style.GOLD if state == "hover" else Color("decda8")
		fill.set_border_width_all(2)
		item.add_theme_stylebox_override(state, fill)

func _style_wish_button(item: Button) -> void:
	var normal := Style.keycap(Color(0.998, 0.986, 0.946, 0.96), Color("e2cca0"), 4, 22, 14, 10)
	normal.border_width_left = 5
	normal.border_color = Color("dfb660")
	var hover := Style.keycap(Color("fff8e3"), Style.GOLD, 4, 22, 14, 10)
	hover.border_width_left = 5
	var pressed := Style.keycap(Color("f7edd1"), Color("c8983d"), 2, 22, 14, 11)
	pressed.border_width_left = 5
	item.add_theme_stylebox_override("normal", normal)
	item.add_theme_stylebox_override("hover", hover)
	item.add_theme_stylebox_override("pressed", pressed)

func _style_level_chip(item: Button) -> void:
	var normal := Style.keycap(Color("fdf3d7"), Color("dfb65d"), 2, 16, 12, 5)
	normal.shadow_size = 0
	var hover := Style.keycap(Color("fff8e4"), Style.GOLD, 2, 16, 12, 5)
	hover.shadow_size = 0
	var pressed := Style.keycap(Color("f5e5bd"), Color("c8983d"), 1, 16, 12, 6)
	pressed.shadow_size = 0
	item.add_theme_stylebox_override("normal", normal)
	item.add_theme_stylebox_override("hover", hover)
	item.add_theme_stylebox_override("pressed", pressed)
	item.add_theme_color_override("font_color", Color("6b4c16"))
	item.add_theme_color_override("font_hover_color", Color("573b0c"))
	item.add_theme_color_override("font_pressed_color", Color("573b0c"))
	item.add_theme_font_override("font", Style.heading_font())

func _round_icon_button(item: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var bg := Color("f6f1e2") if state == "normal" else (Color("fcedc8") if state == "hover" else Color("ebe2cc"))
		var bd := Color("dfd3b9") if state == "normal" else Style.GOLD
		var fill := Style.keycap(bg, bd, 3 if state != "pressed" else 1, 22, 8, 8)
		fill.shadow_size = 0
		item.add_theme_stylebox_override(state, fill)

func _style_dock_item(item: Button, primary: bool) -> void:
	if primary:
		item.add_theme_stylebox_override("normal", Style.keycap(Style.SAGE, Style.SAGE_DEEP, 4, 20, 16, 10))
		item.add_theme_stylebox_override("hover", Style.keycap(Style.SAGE.lightened(0.08), Style.SAGE_DEEP, 4, 20, 16, 10))
		item.add_theme_stylebox_override("pressed", Style.keycap(Style.SAGE.darkened(0.06), Style.SAGE_DEEP, 2, 20, 16, 11))
	else:
		item.add_theme_stylebox_override("normal", Style.keycap(Color("fffdf7"), Color("dfd1b6"), 3, 20, 16, 10))
		item.add_theme_stylebox_override("hover", Style.keycap(Color("fdf2d6"), Style.GOLD, 3, 20, 16, 10))
		item.add_theme_stylebox_override("pressed", Style.keycap(Color("f3e8ce"), Color("cbb894"), 1, 20, 16, 11))

func _style_prompt_pill(item: Button, primary: bool) -> void:
	if primary:
		item.add_theme_stylebox_override("normal", Style.keycap(Style.SAGE, Style.SAGE_DEEP, 4, 22, 18, 9))
		item.add_theme_stylebox_override("hover", Style.keycap(Style.SAGE.lightened(0.08), Style.SAGE_DEEP, 4, 22, 18, 9))
		item.add_theme_stylebox_override("pressed", Style.keycap(Style.SAGE.darkened(0.06), Style.SAGE_DEEP, 2, 22, 18, 10))
	else:
		item.add_theme_stylebox_override("normal", Style.keycap(Color("fffaf0"), Color("d8c8ab"), 4, 22, 14, 9))
		item.add_theme_stylebox_override("hover", Style.keycap(Color("fdf3dc"), Style.GOLD, 4, 22, 14, 9))
		item.add_theme_stylebox_override("pressed", Style.keycap(Color("f3ead4"), Color("cbb998"), 2, 22, 14, 10))
