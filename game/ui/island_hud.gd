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

	ui.location_label = _text("我的小岛", 21, true)
	ui.location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.location_label.custom_minimum_size.x = 204
	ui.status = _text("第 1 天 · 晴", 14)
	ui.status.add_theme_color_override("font_color", Style.MUTED)
	titles.add_child(ui.location_label)
	titles.add_child(ui.status)

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

	# 3. Top-Right Leaf Wallet & Settings Pill
	utilities = _floating_pill("WalletAndSettings", Color(0.996, 0.984, 0.948, 0.95), Color("dfd1b5"), 24, 14, 8)
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 10)
	utilities.add_child(tools)

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
	identity.size = Vector2(308, 74)
	wish.position = Vector2(20, identity.position.y + identity.size.y + 10)
	wish.size = Vector2(308, 82)
	utilities.size = utilities.get_combined_minimum_size()
	utilities.position = Vector2(available.x - utilities.size.x - 20, 20)
	dock.size = dock.get_combined_minimum_size()
	dock.position = Vector2((available.x - dock.size.x) * 0.5, available.y - dock.size.y - 20)
	var hint_min: Vector2 = (ui.controls_hint as Control).get_combined_minimum_size()
	ui.controls_hint.size = Vector2(maxf(250.0, hint_min.x), maxf(34.0, hint_min.y))
	ui.controls_hint.position = Vector2(20, available.y - ui.controls_hint.size.y - 22)
	ui.navigation_label.position = Vector2(20, wish.position.y + wish.size.y + 8)
	ui.navigation_label.size = Vector2(308, 34)
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
