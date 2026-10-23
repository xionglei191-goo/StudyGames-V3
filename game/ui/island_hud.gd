extends Control
## A quiet frame around the world: place, current wish, and one shared belongings tray.
const Style = preload("res://ui/island_theme.gd")
const Preview = preload("res://ui/character_preview.tscn")
var ui: CanvasLayer
var identity: PanelContainer
var wish: Button
var utilities: PanelContainer
var dock: PanelContainer

func setup(owner_ui: CanvasLayer) -> void:
	ui = owner_ui
	name = "IslandHUD"
	identity = _paper("PlaceAndPlayer",12,10)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	identity.add_child(header)
	var avatar: Button = ui.button("","bag",false,Vector2(54,54))
	avatar.name = "PlayerWardrobe"
	avatar.tooltip_text = "我的衣橱 · B"
	_flat(avatar)
	avatar.clip_contents = true
	header.add_child(avatar)
	ui.avatar_preview = Preview.instantiate()
	avatar.add_child(ui.avatar_preview)
	ui.avatar_preview.setup("player","yellow",true)
	ui.avatar_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.avatar_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation",5)
	header.add_child(titles)
	ui.location_label = _text("我的小岛",22,true)
	ui.location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.location_label.custom_minimum_size.x = 224
	ui.status = _text("第 1 天 · 晴",16)
	ui.status.add_theme_color_override("font_color",Style.MUTED)
	titles.add_child(ui.location_label)
	titles.add_child(ui.status)
	wish = ui.button("","quest",false,Vector2(318,88))
	wish.name = "TodayWish"
	wish.tooltip_text = "接着今天的小心愿 · 点击带路"
	add_child(wish)
	var normal := Style.box(Style.PAPER,12,12)
	normal.border_width_left = 4
	normal.border_color = Style.GOLD
	normal.shadow_size = 3
	wish.add_theme_stylebox_override("normal",normal)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16
	content.offset_right = -14
	content.offset_top = 12
	content.offset_bottom = -12
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",12)
	wish.add_child(content)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation",5)
	content.add_child(words)
	var caption := _text("今天的小心愿",15)
	caption.add_theme_color_override("font_color",Style.MUTED)
	words.add_child(caption)
	ui.objective = _text("和熊叔打个招呼",19,true)
	ui.objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.objective.max_lines_visible = 2
	ui.objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(ui.objective)
	content.add_child(ui.icon_view("arrow",18))
	utilities = _paper("WalletAndSettings",12,7)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",10)
	utilities.add_child(tools)
	tools.add_child(ui.icon_view("leaf",24))
	ui.currency = _text("30",20,true)
	ui.currency.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.currency.custom_minimum_size.x = 40
	tools.add_child(ui.currency)
	var rule := VSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(rule)
	var settings: Button = ui.button("","settings",false,Vector2(44,44))
	settings.name = "HUDSettings"
	settings.icon = Style.icon("settings")
	settings.tooltip_text = "设置 · Esc"
	_flat(settings)
	tools.add_child(settings)
	dock = _paper("BelongingsTray",18,8)
	ui.nav_controls = HBoxContainer.new()
	ui.nav_controls.add_theme_constant_override("separation",6)
	dock.add_child(ui.nav_controls)
	for entry: Array in [["地图","map","map"],["背包","bag","bag"],["旅行册","journey:hub","journal"]]:
		var primary: bool = entry[1] == "journey:hub"
		var item: Button = ui.button(str(entry[0]),str(entry[1]),primary,Vector2(130,60))
		item.name = "HUD_"+str(entry[2])
		item.icon = Style.icon(str(entry[2]))
		item.tooltip_text = str(entry[0])
		item.add_theme_font_size_override("font_size",20)
		item.add_theme_constant_override("icon_max_width",34)
		if not primary: _flat(item)
		ui.nav_controls.add_child(item)
	ui.controls_hint = _text("点地面走走\n右键停下 · 滚轮拉近",16)
	ui.controls_hint.name = "MovementHint"
	ui.controls_hint.add_theme_constant_override("line_spacing",4)
	ui.controls_hint.add_theme_stylebox_override("normal",_quiet_box())
	ui.controls_hint.tooltip_text = "WASD / 方向键走动 · E 互动 · M 地图 · B 背包 · J 回忆 · Esc 返回"
	add_child(ui.controls_hint)
	ui.prompt = ui.button("聊一聊   ·   E","interact",true,Vector2(180,46))
	ui.prompt.name = "ContextAction"
	ui.prompt.add_theme_font_size_override("font_size",20)
	for state: String in ["normal","hover","pressed"]:
		var fill := Style.box(Style.SAGE.lightened(0.04) if state == "hover" else Style.SAGE,12,9)
		ui.prompt.add_theme_stylebox_override(state,fill)
	ui.prompt.hide()
	add_child(ui.prompt)
	ui.navigation_label = _text("",16)
	ui.navigation_label.name = "RouteStatus"
	ui.navigation_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.navigation_label.add_theme_stylebox_override("normal",_quiet_box())
	ui.navigation_label.hide()
	add_child(ui.navigation_label)
	ui.bubble_panel = ui.card(Style.PAPER,14)
	ui.bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.bubble_label = _text("",18)
	ui.bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.bubble_panel.add_child(ui.bubble_label)
	ui.bubble_panel.hide()
	add_child(ui.bubble_panel)

func arrange(available: Vector2) -> void:
	if not is_instance_valid(identity): return
	identity.position = Vector2(24,24)
	identity.size = Vector2(318,74)
	wish.position = Vector2(24,identity.position.y+identity.size.y+12)
	wish.size = Vector2(318,88)
	utilities.size = utilities.get_combined_minimum_size()
	utilities.position = Vector2(available.x-utilities.size.x-24,24)
	dock.size = dock.get_combined_minimum_size()
	dock.position = Vector2((available.x-dock.size.x)/2,available.y-dock.size.y-24)
	ui.controls_hint.size = Vector2(210,52)
	ui.controls_hint.position = Vector2(24,available.y-ui.controls_hint.size.y-24)
	ui.navigation_label.position = Vector2(24,wish.position.y+wish.size.y+10)
	ui.navigation_label.size = Vector2(318,36)

func _paper(node_name: String, radius: int, padding: int) -> PanelContainer:
	var result := PanelContainer.new()
	result.name = node_name
	var fill := Style.box(Style.PAPER,radius,padding)
	fill.shadow_size = 4
	fill.shadow_offset = Vector2(0,2)
	result.add_theme_stylebox_override("panel",fill)
	add_child(result)
	return result

func _quiet_box() -> StyleBoxFlat:
	var fill := Style.box(Color("fffaf0de"),8,8)
	fill.shadow_size = 0
	fill.set_border_width_all(0)
	return fill

func _text(value: String, pixels: int, bold: bool = false) -> Label:
	var result := Style.text(value,pixels,Style.INK)
	result.add_theme_font_size_override("font_size",pixels)
	if bold: result.add_theme_font_override("font",Style.heading_font())
	return result

func _flat(item: Button) -> void:
	for state: String in ["normal","hover","pressed"]:
		var fill := Style.box(Color.TRANSPARENT if state == "normal" else Style.SOFT,10,8)
		fill.shadow_size = 0
		fill.set_border_width_all(0)
		item.add_theme_stylebox_override(state,fill)
