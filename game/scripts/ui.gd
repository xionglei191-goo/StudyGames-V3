extends CanvasLayer
## V5 Screen Composition & Modal Choreography.
## Gameplay state and travel remain in main.gd / State.

signal action(id: String)

const Style = preload("res://ui/island_theme.gd")
const Preview = preload("res://ui/character_preview.tscn")
const MapScene = preload("res://ui/world_map.tscn")

const BACKDROP_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 3.0) = 1.35;
uniform vec4 tint_color : source_color = vec4(0.24, 0.21, 0.15, 0.24);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_amount * 2.2;
	vec3 col = textureLod(screen_tex, SCREEN_UV, blur_amount).rgb * 0.36;
	col += textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), blur_amount).rgb * 0.16;
	col += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), blur_amount).rgb * 0.16;
	col += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), blur_amount).rgb * 0.16;
	col += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), blur_amount).rgb * 0.16;
	float vig = smoothstep(0.15, 0.92, length(UV - vec2(0.5)) * 1.35);
	vec3 mixed = mix(col, tint_color.rgb, tint_color.a + vig * 0.12);
	COLOR = vec4(mixed, 1.0);
}
"""

var root: Control
var status: Label
var currency: Label
var objective: Label
var location_label: Label
var prompt: Button
var prompt_cycle: Button
var hover_prompt: Label
var toast_label: Label
var modal: ColorRect
var _backdrop_mat: ShaderMaterial
var panel: PanelContainer
var panel_box: VBoxContainer
var toast_timer := 0.0
var bubble_panel: PanelContainer
var bubble_label: Label
var bubble_timer := 0.0
var ink := Style.INK
var muted_ink := Style.MUTED
var cream := Style.PAPER
var green := Style.SAGE
var current_panel := ""
var layout_kind := "center"
var reduced_motion := false
var panel_tween: Tween
var toast_tween: Tween
var wardrobe_preview: Node
var hud: Control
var navigation_label: Label
var fade: ColorRect
var activity_board: Node
var map_view: Node
var avatar_preview: Node
var nav_controls: HBoxContainer
var controls_hint: Label
var speaker_provider: Callable
var diegetic: Control
var active_wardrobe_tab := "outfit"

func _ready() -> void:
	layer = 10
	get_window().size_changed.connect(_update_ui_scale)
	_update_ui_scale()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.make_theme()
	add_child(root)

	hud = preload("res://ui/island_hud.gd").new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_build_hud()

	diegetic = preload("res://ui_v4/diegetic_dialogue.gd").new()
	diegetic.action_triggered.connect(func(id: String): action.emit(id))
	diegetic.overlay_visibility_changed.connect(func(is_open: bool):
		if is_instance_valid(hud) and hud.has_method("set_dialogue_mode"):
			hud.set_dialogue_mode(is_open)
	)
	root.add_child(diegetic)

	modal = ColorRect.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.hide()
	if DisplayServer.get_name() != "headless":
		var sh := Shader.new()
		sh.code = BACKDROP_SHADER_CODE
		_backdrop_mat = ShaderMaterial.new()
		_backdrop_mat.shader = sh
	root.add_child(modal)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.modal_box(cream, 28, 26))
	modal.add_child(panel)

	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 14)
	panel.add_child(panel_box)

	modal.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position):
			action.emit("close")
	)

	toast_label = label("", 16)
	toast_label.add_theme_font_override("font", Style.heading_font())
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toast_sb := Style.pill(Color(0.998, 0.986, 0.946, 0.97), Color("dfc283"), Color("c8a65e"), 22, 20, 10)
	toast_sb.shadow_size = 12
	toast_label.add_theme_stylebox_override("normal", toast_sb)
	toast_label.hide()
	root.add_child(toast_label)

	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.97, 0.96, 0.90, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	root.resized.connect(_layout)
	_layout.call_deferred()

func _update_ui_scale() -> void:
	var target := Vector2i(1280, 800) if get_window().size.x < 1200 else Vector2i(1440, 900)
	if get_window().content_scale_size != target:
		get_window().content_scale_size = target

func _build_hud() -> void:
	hud.setup(self)

func style(color: Color, radius: int = 16) -> StyleBoxFlat:
	return Style.box(color, radius)

func card(color: Color = Style.PAPER, radius: int = 20) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", Style.box(color, radius))
	return result

func label(value: String, font_size: int = 19, color: Color = Style.INK) -> Label:
	return Style.text(value, font_size, color)

func icon_view(id: String, pixels: int = 48) -> TextureRect:
	var result := TextureRect.new()
	result.texture = Style.icon(id)
	result.custom_minimum_size = Vector2(pixels, pixels)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func button(value: String, id: String, primary: bool = false, minimum: Vector2 = Vector2(160, 50)) -> Button:
	var result := Button.new()
	result.text = value
	result.set_meta("action_id", id)
	result.custom_minimum_size = minimum
	result.theme_type_variation = "PrimaryButton" if primary else "Button"
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(func(): action.emit(id))
	result.button_down.connect(func():
		if not reduced_motion:
			result.pivot_offset = result.size * 0.5
			result.scale = Vector2(0.97, 0.97)
	)
	result.button_up.connect(func(): result.scale = Vector2.ONE)
	result.mouse_exited.connect(func(): result.scale = Vector2.ONE)
	return result

func _begin(id: String, mode: String = "center") -> void:
	if panel_tween and panel_tween.is_valid():
		panel_tween.kill()
	current_panel = id
	layout_kind = mode
	wardrobe_preview = null
	map_view = null
	activity_board = null
	for child: Node in panel_box.get_children():
		panel_box.remove_child(child)
		child.queue_free()
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = Vector2.ZERO
	var use_blur_backdrop := mode in ["center", "map", "journal", "wardrobe", "activity", "creation"]
	if _backdrop_mat != null and use_blur_backdrop and not reduced_motion:
		modal.material = _backdrop_mat
		modal.color = Color.WHITE
	else:
		modal.material = null
		modal.color = Color(0.20, 0.18, 0.13, 0.24 if use_blur_backdrop else 0.03)
	modal.show()
	hud.hide()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	hide_interaction_prompts()
	navigation_label.hide()
	bubble_panel.hide()
	if is_instance_valid(diegetic):
		diegetic.hide()
	for node: Node in hud.find_children("*", "Button", true, false):
		node.focus_mode = Control.FOCUS_NONE
	_layout()
	panel.scale = Vector2.ONE
	if reduced_motion:
		panel.modulate.a = 1.0
	else:
		panel.modulate.a = 0.0
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.965, 0.965)
		panel_tween = create_tween()
		panel_tween.set_parallel(true)
		panel_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
		panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _heading(title: String, subtitle: String, close_id: String = "close") -> void:
	var header_col := VBoxContainer.new()
	header_col.add_theme_constant_override("separation", 10)
	panel_box.add_child(header_col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header_col.add_child(row)

	var speaker := ""
	if layout_kind == "dialogue" and speaker_provider.is_valid():
		speaker = str(speaker_provider.call(current_panel))
	if not speaker.is_empty():
		var portrait_frame := card(Color("f2e8d2"), 20)
		var pf_sb := Style.keycap(Color("f2e8d2"), Color("decda8"), 3, 20, 2, 2)
		pf_sb.shadow_size = 0
		portrait_frame.add_theme_stylebox_override("panel", pf_sb)
		portrait_frame.custom_minimum_size = Vector2(82, 82)
		portrait_frame.clip_contents = true
		row.add_child(portrait_frame)
		var portrait := Preview.instantiate()
		portrait_frame.add_child(portrait)
		portrait.setup(speaker, "yellow", true)
		portrait.reduced_motion = reduced_motion

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 5)
	row.add_child(titles)

	var title_label := label(title, 26)
	title_label.add_theme_font_override("font", Style.heading_font())
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(title_label)

	if not subtitle.is_empty():
		var caption := label(subtitle, 15, muted_ink)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titles.add_child(caption)

	var close_button := button("", close_id, false, Vector2(44, 44))
	close_button.icon = Style.icon("close")
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "关闭 · Esc"
	var cb_norm := Style.keycap(Color("f3eee0"), Color("dcd0b6"), 3, 22, 8, 8)
	cb_norm.shadow_size = 0
	var cb_hov := Style.keycap(Color("fcebc5"), Style.GOLD, 3, 22, 8, 8)
	cb_hov.shadow_size = 0
	var cb_prs := Style.keycap(Color("e8dfc9"), Color("cbb998"), 1, 22, 8, 9)
	cb_prs.shadow_size = 0
	close_button.add_theme_stylebox_override("normal", cb_norm)
	close_button.add_theme_stylebox_override("hover", cb_hov)
	close_button.add_theme_stylebox_override("pressed", cb_prs)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(close_button)

	if layout_kind != "dialogue":
		var divider := ColorRect.new()
		divider.custom_minimum_size.y = 2
		divider.color = Color(0.88, 0.82, 0.71, 0.65)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_col.add_child(divider)

func _actions(entries: Array, columns: int = 2) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = clampf(ceilf(float(entries.size()) / columns) * 62.0, 60.0, 210.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var first: Button
	for entry: Dictionary in entries:
		var item := button(str(entry.label), str(entry.id), bool(entry.get("primary", false)), Vector2(0, 50))
		item.disabled = bool(entry.get("disabled", false))
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if entry.has("icon"):
			item.icon = Style.icon(str(entry.icon))
		grid.add_child(item)
		if first == null and not item.disabled:
			first = item
	if first:
		_focus_if_current.call_deferred(first.get_instance_id())

func show_panel(id: String, title: String, kicker: String, body: String, actions: Array, footnote: String = "") -> void:
	var dialogue := id in ["baker", "gardener", "sports", "lunch", "correct", "bed", "memory", "place", "orchard", "purchase", "welcome", "journey_home", "journey_u1", "journey_talk", "journey_name", "prologue_result"]
	_begin(id, "dialogue" if dialogue else ("lesson" if id == "question" else "center"))
	_heading(title, kicker)
	var description := label(body, 20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing", 6)
	panel_box.add_child(description)
	_actions(actions, 3 if actions.size() == 3 else 2)
	if not footnote.is_empty() and not dialogue:
		var note := label(footnote, 15, muted_ink)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel_box.add_child(note)
	_layout.call_deferred()

func show_interaction_choices(entries: Array[Dictionary]) -> void:
	_begin("interaction_choices", "choices")
	_heading("想先做哪一件？", "选好后自动走过去互动")
	var actions: Array = []
	for entry: Dictionary in entries:
		actions.append({"label": str(entry.label), "id": "interaction_choice:" + str(entry.id)})
	_actions(actions, 1)
	_layout.call_deferred()

func show_travel_book(book_title: String, next_wish: String, visited: int, discoveries: int, entries: Array) -> void:
	preload("res://ui/travel_book_view.gd").build(self, book_title, next_wish, visited, discoveries, entries)

func show_memory_card(game: Node, title: String, subtitle: String, content: Dictionary, actions: Array) -> void:
	_begin("memory", "memory")
	_heading(title, subtitle)
	var view := preload("res://ui/memory_card.gd").new()
	panel_box.add_child(view)
	view.setup(game, content, actions)
	_layout.call_deferred()

func show_inventory(data: Dictionary, tab: String = "") -> void:
	if not tab.is_empty():
		active_wardrobe_tab = tab
	preload("res://ui_v4/cozy_wardrobe_studio.gd").build(self, data, active_wardrobe_tab)

func update_outfit(id: String) -> void:
	if is_instance_valid(avatar_preview):
		avatar_preview.set_outfit(id)
	if is_instance_valid(wardrobe_preview):
		wardrobe_preview.set_outfit(id)
	for node: Node in panel_box.find_children("*", "Button", true, false):
		var key := str(node.get_meta("action_id", ""))
		if key.begins_with("outfit:"):
			var selected := key == "outfit:" + id
			node.theme_type_variation = "PrimaryButton" if selected else "Button"

func update_wardrobe(data: Dictionary) -> void:
	var outfit_id := str(data.get("outfit", "yellow"))
	var w: Dictionary = data.get("wardrobe", {}) if data.get("wardrobe") is Dictionary else {}
	var hat_id := str(w.get("hat", "none"))
	var bag_id := str(w.get("bag", "none"))
	if is_instance_valid(avatar_preview) and avatar_preview.has_method("set_wardrobe"):
		avatar_preview.set_wardrobe(outfit_id, hat_id, bag_id)
	elif is_instance_valid(avatar_preview):
		avatar_preview.set_outfit(outfit_id)
	if is_instance_valid(wardrobe_preview) and wardrobe_preview.has_method("set_wardrobe"):
		wardrobe_preview.set_wardrobe(outfit_id, hat_id, bag_id)
	elif is_instance_valid(wardrobe_preview):
		wardrobe_preview.set_outfit(outfit_id)

func show_shop(data: Dictionary) -> void:
	_begin("shop")
	_heading("把喜欢的东西带回家", "熊叔的暖木杂货架 · 当前 %d 叶币" % int(data.coins))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	panel_box.add_child(row)
	for entry: Array in [["flower_box", "窗边花箱", 25, "让窗边四季开满暖花"], ["picnic", "野餐角", 35, "留一处和朋友分享点心的地方"], ["lamp", "暖光小灯", 45, "给傍晚的小屋添一点暖意"]]:
		var id := str(entry[0])
		var owned: bool = data.decorations_owned.get(id, false)
		var tile := card(Color("f5f2e4"), 20)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 12)
		tile.add_child(box)
		var picture := icon_view(id, 96)
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(picture)
		var t_lbl := label(str(entry[1]), 21)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t_lbl)
		var caption := label(str(entry[3]), 15, muted_ink)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(caption)
		var buy := button("已收入小家" if owned else "%d 叶币 · 预览" % entry[2], "preview_buy:" + id, not owned, Vector2(0, 50))
		buy.disabled = owned
		box.add_child(buy)
	var home_btn := button("回家布置家具", "decorate", true)
	home_btn.icon = Style.icon("home")
	panel_box.add_child(home_btn)
	_layout.call_deferred()

func show_decoration_tray(data: Dictionary, selected: String, previewing: bool, enabled: bool, can_undo: bool) -> void:
	_begin("decorate", "decorate")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel_box.add_child(row)
	var title := label("一点点，变成喜欢的家", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var free_btn := button("自由网格布置", "v4_free_decor", true, Vector2(184, 44))
	free_btn.icon = Style.icon("sparkle")
	row.add_child(free_btn)
	var shop_btn := button("杂货架挑选", "shop", false, Vector2(158, 44))
	shop_btn.icon = Style.icon("home")
	row.add_child(shop_btn)
	row.add_child(button("完成", "close", false, Vector2(108, 44)))
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 14)
	panel_box.add_child(shelf)
	for entry: Array in [["flower_box", "窗边花箱"], ["picnic", "野餐角"], ["lamp", "暖光小灯"]]:
		var id := str(entry[0])
		var owned: bool = data.decorations_owned.get(id, false)
		var placed: bool = data.decorations_placed.get(id, false)
		var caption := str(entry[1]) + "\n" + ("已摆放" if placed else "点击预览") if owned else str(entry[1]) + "\n尚未拥有"
		var tile := button(caption, "preview_place:" + id, selected == id, Vector2(0, 72))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.icon = Style.icon(id)
		tile.add_theme_constant_override("icon_max_width", 38)
		tile.disabled = not owned
		shelf.add_child(tile)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	panel_box.add_child(controls)
	var hint := label(("预览：摆在这里" if enabled else "预览：收起这件装饰") if previewing else "选一件装饰预览，或打开上方「自由网格布置」随心摆放 13 款积木家具。", 16, muted_ink)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(hint)
	if previewing:
		controls.add_child(button("确认摆放" if enabled else "确认收起", "confirm_place", true, Vector2(126, 44)))
		controls.add_child(button("取消预览", "cancel_place", false, Vector2(126, 44)))
	var undo := button("撤销上次", "undo_place", false, Vector2(126, 44))
	undo.icon = Style.icon("undo")
	undo.disabled = not can_undo
	controls.add_child(undo)
	_layout.call_deferred()

func show_world_map(title: String, world: World3D, bounds: Rect2, entries: Array, origin: Vector3, routes: Dictionary, extra_actions: Array = []) -> void:
	_begin("map", "map")
	_heading(title, "手绘小岛导览 · 点击任意地标即可自动沿路前往")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	panel_box.add_child(row)
	map_view = MapScene.instantiate()
	row.add_child(map_view)
	map_view.setup(world, bounds, entries, origin, routes)
	map_view.destination_selected.connect(func(id: String): action.emit("navigate:" + id))
	var directory_card := card(Color("f5f0e2"), 20)
	directory_card.custom_minimum_size.x = 276
	row.add_child(directory_card)
	var directory := VBoxContainer.new()
	directory.add_theme_constant_override("separation", 10)
	directory_card.add_child(directory)
	directory.add_child(label("想去哪里逛逛？", 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	directory.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for entry: Dictionary in entries:
		var item := button(str(entry.label), "navigate:" + str(entry.id), false, Vector2(0, 46))
		if str(entry.id).begins_with("memory_"):
			item.text = "%s · %s" % [str(int(str(entry.id).trim_prefix("memory_"))), str(entry.label)]
		item.icon = Style.icon("pin")
		item.add_theme_constant_override("icon_max_width", 20)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.add_theme_font_size_override("font_size", 18)
		list.add_child(item)
	for entry: Dictionary in extra_actions:
		list.add_child(button(str(entry.label), str(entry.id), false, Vector2(0, 46)))
	panel_box.add_child(label("左键点按或长按地面漫步 · 右键拖动旋转视角 · Shift 轻快小跑 · E 互动", 14, muted_ink))
	_layout.call_deferred()

func show_activity(kind: String, state: Dictionary, at_home: bool = false) -> Node:
	_begin("activity", "activity")
	var titles := {"music": "把小岛的旋律弹出来", "art": "画一张属于你的明信片", "science": "今天的颜色实验"}
	_heading("画一张属于你的贺卡" if at_home and kind == "art" else str(titles.get(kind, "动手试一试")), "窗边书房 · 随时可以休息" if at_home else "校园工作室 · 随时可以休息")
	activity_board = load("res://ui/activity_board.tscn").instantiate()
	activity_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(activity_board)
	activity_board.setup(kind, state)
	activity_board.action.connect(func(id: String): action.emit(id))
	_layout.call_deferred()
	return activity_board

func show_memory_book(data: Dictionary, places: Array) -> void:
	_begin("journal", "wardrobe")
	_heading("把小岛的日子，一页页收好", "我的回忆册 · 第 %d 天" % int(data.day))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)
	left.add_child(label("走过的地方", 22))
	left.add_child(label("发现 %d 处小岛回忆" % data.life.discoveries.size(), 16, muted_ink))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var locations := VBoxContainer.new()
	locations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locations.add_theme_constant_override("separation", 10)
	scroll.add_child(locations)
	if places.is_empty():
		var hint := label("走近一件有趣的物品，\n把第一处发现带回来吧。", 18, muted_ink)
		locations.add_child(hint)
	for place: Dictionary in places:
		var item := card(Color("f2efe2"), 14)
		locations.add_child(item)
		item.add_child(label("%s    %d / 5" % [place.name, place.count], 18))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 430
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	right.add_child(label("亲手做过的事", 22))
	var stamps := GridContainer.new()
	stamps.columns = 2
	stamps.add_theme_constant_override("h_separation", 12)
	stamps.add_theme_constant_override("v_separation", 12)
	right.add_child(stamps)
	for entry: Array in [["music", "小岛旋律"], ["art", "我的明信片"], ["science", "颜色实验"], ["football", "射门练习"]]:
		var earned: bool = data.life.activities[entry[0]]
		var tile := card(Color("e6eedb") if earned else Color("f3f0e5"), 18)
		tile.custom_minimum_size = Vector2(200, 118)
		stamps.add_child(tile)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(box)
		box.add_child(icon_view(str(entry[0]), 40))
		var caption := label(str(entry[1]) + (" · 已收集" if earned else " · 待体验"), 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(caption)
	right.add_child(button("看看我的明信片", "view_art", true, Vector2(0, 50)))
	right.add_child(button("英语学习记录与内容说明", "learning_details", false, Vector2(0, 50)))
	panel_box.add_child(label("探索和校园体验记录生活足迹；英语成长记录在单独详情里。", 14, muted_ink))
	_layout.call_deferred()

func show_postcard(strokes: Array) -> void:
	_begin("postcard", "wardrobe")
	_heading("来自字母岛的明信片", "我的手绘作品")
	var canvas := preload("res://ui/art_canvas.gd").new()
	panel_box.add_child(canvas)
	canvas.restore(strokes)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.focus_mode = Control.FOCUS_NONE
	if strokes.is_empty():
		panel_box.add_child(label("去美术教室画一张，保存后就会出现在这里。", 18, muted_ink))
	panel_box.add_child(button("返回回忆册", "journal", true))
	_layout.call_deferred()

func show_football(practice: Node) -> void:
	_begin("football", "decorate")
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel_box.add_child(row)
	var score := label("射门练习 · 第 %d / 5 球 · 进球 %d" % [mini(int(practice.attempts) + 1, 5), practice.goals], 23)
	score.name = "FootballScore"
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(score)
	row.add_child(button("结束练习", "close", false, Vector2(130, 44)))
	var note := label("点击球门瞄准，或拖动下方滑杆调节方向与力度。", 17, muted_ink)
	note.name = "FootballHint"
	panel_box.add_child(note)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	panel_box.add_child(controls)
	controls.add_child(label("方向", 17))
	var direction := HSlider.new()
	direction.name = "AimSlider"
	direction.min_value = -1.25
	direction.max_value = 1.25
	direction.step = 0.025
	direction.value = practice.aim
	direction.custom_minimum_size = Vector2(210, 44)
	direction.value_changed.connect(practice.update_aim)
	controls.add_child(direction)
	controls.add_child(label("力度", 17))
	var strength := HSlider.new()
	strength.min_value = 0.3
	strength.max_value = 1.0
	strength.step = 0.025
	strength.value = practice.power
	strength.custom_minimum_size = Vector2(210, 44)
	strength.value_changed.connect(func(value: float): practice.power = value)
	controls.add_child(strength)
	controls.add_child(button("射门 · 空格", "football_shoot", true, Vector2(166, 50)))
	controls.add_child(button("再练一轮", "football_restart", false, Vector2(128, 50)))
	_layout.call_deferred()

func football_feedback(attempts: int, goals: int, message: String) -> void:
	if current_panel != "football":
		return
	var score := panel_box.find_child("FootballScore", true, false) as Label
	var hint := panel_box.find_child("FootballHint", true, false) as Label
	if score:
		score.text = "射门练习 · 已踢 %d / 5 球 · 进球 %d" % [attempts, goals]
	if hint:
		hint.text = message

func _focus_if_current(button_id: int) -> void:
	var node: Object = instance_from_id(button_id)
	if is_instance_valid(node) and node.is_inside_tree() and modal.visible:
		node.grab_focus()

func close_panel() -> void:
	modal.hide()
	modal.material = null
	hud.show()
	current_panel = ""
	map_view = null
	activity_board = null
	for child: Node in panel_box.get_children():
		panel_box.remove_child(child)
		child.queue_free()
	wardrobe_preview = null
	for node: Node in hud.find_children("*", "Button", true, false):
		node.focus_mode = Control.FOCUS_ALL
	_layout.call_deferred()

func notify(message: String) -> void:
	toast_label.text = message
	toast_label.show()
	toast_timer = 3.8
	_layout()
	if not reduced_motion:
		if toast_tween and toast_tween.is_valid():
			toast_tween.kill()
		var target_y := toast_label.position.y
		toast_label.position.y = target_y - 12.0
		toast_label.modulate.a = 0.0
		toast_tween = create_tween()
		toast_tween.set_parallel(true)
		toast_tween.tween_property(toast_label, "position:y", target_y, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.16)
	else:
		toast_label.modulate.a = 1.0

func say(en: String, zh: String, screen_position: Vector2) -> void:
	bubble_label.text = en + "\n" + zh
	bubble_panel.reset_size()
	var bsz := bubble_panel.get_combined_minimum_size()
	bubble_panel.position = Vector2(
		clampf(screen_position.x - bsz.x * 0.5, 24.0, maxf(24.0, root.size.x - bsz.x - 24.0)),
		clampf(screen_position.y - bsz.y - 18.0, 24.0, maxf(24.0, root.size.y - bsz.y - 120.0))
	)
	bubble_panel.show()
	bubble_timer = 4.2

func show_prompt(value: String, screen_position: Vector2, count: int = 1, index: int = 0) -> void:
	prompt.text = value + "  [E]"
	prompt.size = Vector2.ZERO
	prompt_cycle.text = "换一个 %d/%d [Q]" % [index + 1, count]
	prompt_cycle.size = Vector2.ZERO
	var width := prompt.get_combined_minimum_size().x
	var height := prompt.get_combined_minimum_size().y
	var cycle_width := prompt_cycle.get_combined_minimum_size().x + 8.0 if count > 1 else 0.0
	var total_w := width + cycle_width

	# Anchor smoothly above the world target while guaranteeing zero overlap with corner/dock HUD!
	var min_x := 348.0 if root.size.x >= 1100.0 else 24.0
	var max_x := maxf(min_x, root.size.x - total_w - 240.0)
	var min_y := 104.0
	var max_y := maxf(min_y, root.size.y - height - 110.0)
	var px := clampf(screen_position.x - total_w * 0.5, min_x, max_x)
	var py := clampf(screen_position.y - height - 16.0, min_y, max_y)

	prompt.position = Vector2(px, py)
	prompt_cycle.position = prompt.position + Vector2(width + 8.0, 0.0)
	prompt.visible = not modal.visible and (not is_instance_valid(diegetic) or not diegetic.visible)
	prompt_cycle.visible = count > 1 and prompt.visible

func show_hover_prompt(value: String, screen_position: Vector2) -> void:
	hover_prompt.text = value
	hover_prompt.size = Vector2.ZERO
	var sz := hover_prompt.get_combined_minimum_size()
	hover_prompt.position = Vector2(
		clampf(screen_position.x - sz.x * 0.5, 16.0, root.size.x - sz.x - 16.0),
		clampf(screen_position.y - sz.y - 16.0, 16.0, root.size.y - sz.y - 112.0)
	)
	hover_prompt.visible = not modal.visible

func hide_interaction_prompts() -> void:
	prompt.hide()
	prompt_cycle.hide()
	hover_prompt.hide()

func navigation(value: String) -> void:
	navigation_label.text = value.replace(" · 右键可停下", "").replace(" · 右键停下 / 方向键接着走", "")
	navigation_label.tooltip_text = value
	navigation_label.visible = not value.is_empty() and not modal.visible
	_layout()

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var available := root.size
	if available.x < 1:
		available = Vector2(1440, 900)
	hud.arrange(available)
	var width := minf(960, available.x - 64)
	var height := minf(580, available.y - 96)
	if current_panel == "settings":
		height = minf(660, available.y - 72)
	elif layout_kind == "creation":
		width = minf(1280, available.x - 40)
		height = minf(820, available.y - 40)
	elif layout_kind == "choices":
		width = minf(520, available.x - 64)
		height = minf(320, available.y - 120)
	elif layout_kind == "memory":
		width = minf(900, available.x - 64)
		height = panel.get_combined_minimum_size().y
	elif current_panel == "creation_editor":
		width = minf(1180, available.x - 56)
		height = minf(820, available.y - 48)
	elif current_panel == "review_task":
		width = minf(1020, available.x - 64)
		height = minf(580, available.y - 96)
	elif layout_kind == "wardrobe":
		width = minf(1040, available.x - 64)
		height = minf(660, available.y - 68)
	elif layout_kind == "map":
		width = minf(1240, available.x - 48)
		height = minf(760, available.y - 96)
	elif layout_kind == "journal":
		width = minf(1200, available.x - 56)
		height = minf(750, available.y - 100)
	elif layout_kind == "activity":
		width = minf(1100, available.x - 48)
		height = minf(700, available.y - 64)
	elif layout_kind in ["dialogue", "lesson"]:
		width = minf(1000, available.x - 64)
		height = minf(276 if layout_kind == "dialogue" else 430, available.y - 80)
		if current_panel == "purchase":
			height = minf(300, available.y - 80)
	elif layout_kind == "decorate":
		width = minf(1160, available.x - 48)
		height = 262
	panel.size = Vector2(width, height)
	panel.position = (available - panel.size) * 0.5
	if layout_kind in ["dialogue", "lesson", "decorate", "memory", "choices"]:
		panel.position.y = available.y - panel.size.y - 24
	var toast_width := clampf(toast_label.get_theme_font("font").get_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 48, 260, 560)
	toast_label.position = Vector2((available.x - toast_width) * 0.5, 18)
	toast_label.size = Vector2(toast_width, 0)

func _process(delta: float) -> void:
	if not prompt.visible:
		prompt_cycle.hide()
	if is_instance_valid(avatar_preview):
		avatar_preview.reduced_motion = reduced_motion
	if is_instance_valid(wardrobe_preview):
		wardrobe_preview.reduced_motion = reduced_motion
	toast_timer -= delta
	bubble_timer -= delta
	if toast_timer <= 0:
		toast_label.hide()
	if bubble_timer <= 0 or modal.visible:
		bubble_panel.hide()
