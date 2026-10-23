extends CanvasLayer
## Screen composition. Gameplay state and travel remain in main.gd / State.
signal action(id: String)
const Style = preload("res://ui/island_theme.gd")
const Preview = preload("res://ui/character_preview.tscn")
const MapScene = preload("res://ui/world_map.tscn")
var root: Control
var status: Label
var currency: Label
var objective: Label
var location_label: Label
var prompt: Button
var toast_label: Label
var modal: ColorRect
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
	modal = ColorRect.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.hide()
	root.add_child(modal)
	panel = card(cream,20)
	modal.add_child(panel)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation",14)
	panel.add_child(panel_box)
	modal.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position):
			action.emit("close")
	)
	toast_label = label("",17)
	toast_label.add_theme_font_size_override("font_size",17)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_stylebox_override("normal",Style.box(cream,10,10))
	toast_label.hide()
	root.add_child(toast_label)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.97,0.96,0.90,0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	root.resized.connect(_layout)
	_layout.call_deferred()

func _update_ui_scale() -> void:
	# Keep Chinese body text readable when the desktop window is made smaller.
	var target := Vector2i(1280,800) if get_window().size.x<1200 else Vector2i(1440,900)
	if get_window().content_scale_size != target:
		get_window().content_scale_size = target

func _build_hud() -> void:
	hud.setup(self)

func style(color: Color, radius: int = 16) -> StyleBoxFlat:
	return Style.box(color,radius)

func card(color: Color = Style.PAPER, radius: int = 20) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel",Style.box(color,radius))
	return result

func label(value: String, font_size: int = 19, color: Color = Style.INK) -> Label:
	return Style.text(value,font_size,color)

func icon_view(id: String, pixels: int = 48) -> TextureRect:
	var result := TextureRect.new()
	result.texture = Style.icon(id)
	result.custom_minimum_size = Vector2(pixels,pixels)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func button(value: String, id: String, primary: bool = false, minimum: Vector2 = Vector2(160,50)) -> Button:
	var result := Button.new()
	result.text = value
	result.set_meta("action_id",id)
	result.custom_minimum_size = minimum
	result.theme_type_variation = "PrimaryButton" if primary else "Button"
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(func(): action.emit(id))
	result.button_down.connect(func():
		if not reduced_motion:
			result.pivot_offset = result.size/2
			result.scale = Vector2(0.975,0.975)
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
	modal.color = Color(0.22,0.23,0.17,0.18 if mode in ["center","map","journal","wardrobe","activity"] else 0.02)
	modal.show()
	hud.hide()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.hide()
	navigation_label.hide()
	bubble_panel.hide()
	for node: Node in hud.find_children("*","Button",true,false):
		node.focus_mode = Control.FOCUS_NONE
	_layout()
	panel.modulate.a = 1.0 if reduced_motion else 0.4
	if not reduced_motion:
		panel_tween = create_tween()
		panel_tween.tween_property(panel,"modulate:a",1.0,0.16)

func _heading(title: String, subtitle: String, close_id: String = "close") -> void:
	var row := HBoxContainer.new()
	panel_box.add_child(row)
	row.add_theme_constant_override("separation",18)
	var speaker := ""
	if layout_kind == "dialogue" and speaker_provider.is_valid():
		speaker = str(speaker_provider.call(current_panel))
	if not speaker.is_empty():
		var portrait_frame := card(Color("f0e6d0"),16)
		portrait_frame.add_theme_stylebox_override("panel",Style.box(Color("f0e6d0"),16,0))
		portrait_frame.custom_minimum_size = Vector2(84,84)
		portrait_frame.clip_contents = true
		row.add_child(portrait_frame)
		var portrait := Preview.instantiate()
		portrait_frame.add_child(portrait)
		portrait.setup(speaker,"yellow",true)
		portrait.reduced_motion = reduced_motion
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation",8)
	row.add_child(titles)
	var title_label := label(title,28)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(title_label)
	var caption := label(subtitle,16,muted_ink)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(caption)
	var close_button := button("×",close_id,false,Vector2(48,48))
	close_button.tooltip_text = "关闭 · Esc"
	close_button.add_theme_font_size_override("font_size",24)
	close_button.add_theme_stylebox_override("normal",Style.box(Style.SOFT,12,6))
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(close_button)

func _actions(entries: Array, columns: int = 2) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = clampf(ceilf(float(entries.size())/columns)*62.0,60.0,210.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	var first: Button
	for entry: Dictionary in entries:
		var item := button(str(entry.label),str(entry.id),bool(entry.get("primary",false)),Vector2(0,50))
		item.disabled = bool(entry.get("disabled",false))
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(item)
		if first == null and not item.disabled:
			first = item
	if first:
		_focus_if_current.call_deferred(first.get_instance_id())

func show_panel(id: String, title: String, kicker: String, body: String, actions: Array, footnote: String = "") -> void:
	var dialogue := id in ["baker","gardener","sports","lunch","correct","bed","memory","place","orchard","purchase","welcome","journey_home","journey_u1","journey_talk","journey_name","prologue_result"]
	_begin(id,"dialogue" if dialogue else ("lesson" if id == "question" else "center"))
	_heading(title,kicker)
	var description := label(body,20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing",5)
	panel_box.add_child(description)
	_actions(actions,3 if actions.size() == 3 else 2)
	if not footnote.is_empty() and not dialogue:
		var note := label(footnote,15,muted_ink)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel_box.add_child(note)
	_layout.call_deferred()

func show_travel_book(book_title: String, next_wish: String, visited: int, discoveries: int, entries: Array) -> void:
	preload("res://ui/travel_book_view.gd").build(self,book_title,next_wish,visited,discoveries,entries)

func show_inventory(data: Dictionary) -> void:
	_begin("bag","wardrobe")
	_heading("今天，穿哪一种心情？","我的衣橱 / 随身物品")
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",28)
	panel_box.add_child(body)
	var stage := card(Color("e8eddf"),22)
	stage.custom_minimum_size.x = 300
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	var preview_box := VBoxContainer.new()
	stage.add_child(preview_box)
	wardrobe_preview = Preview.instantiate()
	preview_box.add_child(wardrobe_preview)
	wardrobe_preview.setup("player",str(data.outfit))
	var hint := label("拖动角色，可以看看另一面",15,muted_ink)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(hint)
	var items := VBoxContainer.new()
	items.custom_minimum_size.x = 370
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("separation",16)
	body.add_child(items)
	items.add_child(label("随身带着",18,muted_ink))
	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation",10)
	items.add_child(supplies)
	for supply: Array in [["apple","苹果",data.apples],["cake","蛋糕",data.cakes],["leaf","叶币",data.coins]]:
		var tile := card(Color("f0f1e5"),16)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		supplies.add_child(tile)
		var box := VBoxContainer.new()
		tile.add_child(box)
		box.add_child(icon_view(str(supply[0]),40))
		var count := label("%s × %s" % [supply[1],supply[2]],16)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(count)
	items.add_child(label("换上喜欢的颜色",20))
	for entry: Array in [["yellow","向日葵黄"],["pink","草莓粉"],["blue","晴空蓝"]]:
		var item := button(str(entry[1]),"outfit:"+str(entry[0]),str(data.outfit)==str(entry[0]),Vector2(0,54))
		item.icon = Style.icon("check") if str(data.outfit)==str(entry[0]) else Style.icon("outfit")
		items.add_child(item)
	items.add_child(button("看看我的装饰","decorate",false,Vector2(0,52)))
	_layout.call_deferred()

func update_outfit(id: String) -> void:
	if is_instance_valid(avatar_preview):
		avatar_preview.set_outfit(id)
	if is_instance_valid(wardrobe_preview):
		wardrobe_preview.set_outfit(id)
	for node: Node in panel_box.find_children("*","Button",true,false):
		var key := str(node.get_meta("action_id",""))
		if key.begins_with("outfit:"):
			var selected := key == "outfit:"+id
			node.theme_type_variation = "PrimaryButton" if selected else "Button"
			node.icon = Style.icon("check" if selected else "outfit")

func show_shop(data: Dictionary) -> void:
	_begin("shop")
	_heading("把喜欢的东西带回家","熊叔的杂货架 · %d 叶币" % int(data.coins))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",18)
	panel_box.add_child(row)
	for entry: Array in [["flower_box","窗边花箱",25,"让窗边开满花"],["picnic","野餐角",35,"留一处分享点心的地方"],["lamp","暖光小灯",45,"给小屋添一点暖意"]]:
		var id := str(entry[0])
		var owned: bool = data.decorations_owned.get(id,false)
		var tile := card(Color("f0f1e4"),18)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation",14)
		tile.add_child(box)
		var picture := icon_view(id,100)
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(picture)
		box.add_child(label(str(entry[1]),22))
		var caption := label(str(entry[3]),15,muted_ink)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(caption)
		var buy := button("已拥有" if owned else "%d 叶币 · 看看" % entry[2],"preview_buy:"+id,not owned,Vector2(0,52))
		buy.disabled = owned
		box.add_child(buy)
	panel_box.add_child(button("回家布置","decorate",true))
	_layout.call_deferred()

func show_decoration_tray(data: Dictionary, selected: String, previewing: bool, enabled: bool, can_undo: bool) -> void:
	_begin("decorate","decorate")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	panel_box.add_child(row)
	var title := label("一点点，变成喜欢的家",24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(button("去杂货架挑选","shop",false,Vector2(170,44)))
	row.add_child(button("完成布置","close",true,Vector2(130,44)))
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation",14)
	panel_box.add_child(shelf)
	for entry: Array in [["flower_box","窗边花箱"],["picnic","野餐角"],["lamp","暖光小灯"]]:
		var id := str(entry[0])
		var owned: bool = data.decorations_owned.get(id,false)
		var placed: bool = data.decorations_placed.get(id,false)
		var caption := str(entry[1])+"\n"+("已摆放" if placed else "点击预览") if owned else str(entry[1])+"\n尚未拥有"
		var tile := button(caption,"preview_place:"+id,selected==id,Vector2(0,76))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.icon = Style.icon(id)
		tile.add_theme_constant_override("icon_max_width",42)
		tile.disabled = not owned
		shelf.add_child(tile)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	panel_box.add_child(controls)
	var hint := label(("预览：摆在这里" if enabled else "预览：收起这件装饰") if previewing else "选一件装饰，先看看摆放效果。",17,muted_ink)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(hint)
	if previewing:
		controls.add_child(button("确认摆放" if enabled else "确认收起","confirm_place",true,Vector2(130,46)))
		controls.add_child(button("取消预览","cancel_place",false,Vector2(130,46)))
	var undo := button("撤销上次","undo_place",false,Vector2(130,46))
	undo.disabled = not can_undo
	controls.add_child(undo)
	_layout.call_deferred()

func show_world_map(title: String, world: World3D, bounds: Rect2, entries: Array, origin: Vector3, routes: Dictionary, extra_actions: Array = []) -> void:
	_begin("map","map")
	_heading(title,"小岛导览 · 圆点是你的位置，点击地点步行前往")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",18)
	panel_box.add_child(row)
	map_view = MapScene.instantiate()
	row.add_child(map_view)
	map_view.setup(world,bounds,entries,origin,routes)
	map_view.destination_selected.connect(func(id: String): action.emit("navigate:"+id))
	var directory := VBoxContainer.new()
	directory.custom_minimum_size.x = 250
	directory.add_theme_constant_override("separation",12)
	row.add_child(directory)
	directory.add_child(label("想去哪里走走？",21))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	directory.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",4)
	scroll.add_child(list)
	for entry: Dictionary in entries:
		var item := button(str(entry.label),"navigate:"+str(entry.id),false,Vector2(0,48))
		if str(entry.id).begins_with("memory_"):
			item.text = "%s · %s" % [str(int(str(entry.id).trim_prefix("memory_"))),str(entry.label)]
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.add_theme_font_size_override("font_size",20)
		var surface := Style.box(Color.TRANSPARENT,8,10)
		surface.shadow_size = 0
		surface.set_border_width_all(0)
		surface.border_width_bottom = 1
		item.add_theme_stylebox_override("normal",surface)
		list.add_child(item)
	for entry: Dictionary in extra_actions:
		list.add_child(button(str(entry.label),str(entry.id),false,Vector2(0,48)))
	panel_box.add_child(label("地点与真实场景对应 · 方向键可随时接管 · E 或点击人物互动",15,muted_ink))
	_layout.call_deferred()

func show_activity(kind: String, state: Dictionary) -> Node:
	_begin("activity","activity")
	var titles := {"music":"把小岛的旋律弹出来","art":"画一张属于你的明信片","science":"今天的颜色实验"}
	_heading(str(titles.get(kind,"动手试一试")),"校园工作室 · 随时可以休息")
	activity_board = load("res://ui/activity_board.tscn").instantiate()
	activity_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(activity_board)
	activity_board.setup(kind,state)
	activity_board.action.connect(func(id: String): action.emit(id))
	_layout.call_deferred()
	return activity_board

func show_memory_book(data: Dictionary, places: Array) -> void:
	_begin("journal","wardrobe")
	_heading("把小岛的日子，一页页收好","我的回忆册 · 第 %d 天" % int(data.day))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",14)
	row.add_child(left)
	left.add_child(label("走过的地方",22))
	left.add_child(label("发现 %d 处小岛回忆" % data.life.discoveries.size(),17,muted_ink))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var locations := VBoxContainer.new()
	locations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locations.add_theme_constant_override("separation",10)
	scroll.add_child(locations)
	if places.is_empty():
		var hint := label("走近一件有趣的物品，\n把第一处发现带回来吧。",19,muted_ink)
		locations.add_child(hint)
	for place: Dictionary in places:
		var item := card(Color("eef0e4"),14)
		locations.add_child(item)
		item.add_child(label("%s    %d / 5" % [place.name,place.count],18))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 430
	right.add_theme_constant_override("separation",12)
	row.add_child(right)
	right.add_child(label("亲手做过的事",22))
	var stamps := GridContainer.new()
	stamps.columns = 2
	stamps.add_theme_constant_override("h_separation",12)
	stamps.add_theme_constant_override("v_separation",12)
	right.add_child(stamps)
	for entry: Array in [["music","小岛旋律"],["art","我的明信片"],["science","颜色实验"],["football","射门练习"]]:
		var earned: bool = data.life.activities[entry[0]]
		var tile := card(Color("e4ebd9") if earned else Color("f0efe6"),18)
		tile.custom_minimum_size = Vector2(200,120)
		stamps.add_child(tile)
		var box := VBoxContainer.new()
		tile.add_child(box)
		box.add_child(icon_view(str(entry[0]),40))
		var caption := label(str(entry[1])+(" · 已收集" if earned else " · 待体验"),16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(caption)
	right.add_child(button("看看我的明信片","view_art",true,Vector2(0,50)))
	right.add_child(button("英语学习记录与内容说明","learning_details",false,Vector2(0,50)))
	panel_box.add_child(label("探索和校园体验记录生活足迹；英语答题记录在单独的详情里。",15,muted_ink))
	_layout.call_deferred()

func show_postcard(strokes: Array) -> void:
	_begin("postcard","wardrobe")
	_heading("来自字母岛的明信片","我的作品")
	var canvas := preload("res://ui/art_canvas.gd").new()
	panel_box.add_child(canvas)
	canvas.restore(strokes)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.focus_mode = Control.FOCUS_NONE
	if strokes.is_empty():
		panel_box.add_child(label("去美术教室画一张，保存后就会出现在这里。",18,muted_ink))
	panel_box.add_child(button("返回回忆册","journal",true))
	_layout.call_deferred()

func show_football(practice: Node) -> void:
	_begin("football","decorate")
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	panel_box.add_child(row)
	var score := label("射门练习 · 第 %d / 5 球 · 进球 %d" % [mini(int(practice.attempts)+1,5),practice.goals],24)
	score.name = "FootballScore"
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(score)
	row.add_child(button("结束练习","close",false,Vector2(130,46)))
	var note := label("点击球门瞄准，或拖动方向条。轻重由你决定。",18,muted_ink)
	note.name = "FootballHint"
	panel_box.add_child(note)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",18)
	panel_box.add_child(controls)
	controls.add_child(label("方向",18))
	var direction := HSlider.new()
	direction.name = "AimSlider"
	direction.min_value = -1.25
	direction.max_value = 1.25
	direction.step = 0.025
	direction.value = practice.aim
	direction.custom_minimum_size = Vector2(210,48)
	direction.value_changed.connect(practice.update_aim)
	controls.add_child(direction)
	controls.add_child(label("力度",18))
	var strength := HSlider.new()
	strength.min_value = 0.3
	strength.max_value = 1.0
	strength.step = 0.025
	strength.value = practice.power
	strength.custom_minimum_size = Vector2(210,48)
	strength.value_changed.connect(func(value: float): practice.power=value)
	controls.add_child(strength)
	controls.add_child(button("射门 · 空格","football_shoot",true,Vector2(170,54)))
	controls.add_child(button("再练一轮","football_restart",false,Vector2(130,54)))
	_layout.call_deferred()

func football_feedback(attempts: int, goals: int, message: String) -> void:
	if current_panel!="football":
		return
	var score := panel_box.find_child("FootballScore",true,false) as Label
	var hint := panel_box.find_child("FootballHint",true,false) as Label
	if score:
		score.text = "射门练习 · 已踢 %d / 5 球 · 进球 %d" % [attempts,goals]
	if hint:
		hint.text = message

func _focus_if_current(button_id: int) -> void:
	var node: Object = instance_from_id(button_id)
	if is_instance_valid(node) and node.is_inside_tree() and modal.visible:
		node.grab_focus()

func close_panel() -> void:
	modal.hide()
	hud.show()
	current_panel = ""
	map_view = null
	activity_board = null
	for child: Node in panel_box.get_children():
		panel_box.remove_child(child)
		child.queue_free()
	wardrobe_preview = null
	for node: Node in hud.find_children("*","Button",true,false):
		node.focus_mode = Control.FOCUS_ALL
	_layout.call_deferred()

func notify(message: String) -> void:
	toast_label.text = message
	toast_label.show()
	toast_timer = 3.8
	_layout()

func say(en: String, zh: String, screen_position: Vector2) -> void:
	bubble_label.text = en+"\n"+zh
	bubble_panel.position = screen_position+Vector2(-100,-108)
	bubble_panel.show()
	bubble_timer = 4.2

func show_prompt(value: String, _screen_position: Vector2) -> void:
	prompt.text = value+"   ·   E"
	prompt.size = Vector2.ZERO
	prompt.position = Vector2((root.size.x-prompt.get_combined_minimum_size().x)/2,root.size.y-174)
	prompt.visible = not modal.visible

func navigation(value: String) -> void:
	navigation_label.text = value.replace(" · 右键可停下", "")
	navigation_label.tooltip_text = value
	navigation_label.visible = not value.is_empty() and not modal.visible
	_layout()

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var available := root.size
	if available.x < 1:
		available = Vector2(1440,900)
	hud.arrange(available)
	var width := minf(940,available.x-64)
	var height := minf(570,available.y-96)
	if current_panel == "settings":
		height = minf(650,available.y-72)
	elif layout_kind == "wardrobe":
		width = minf(1000,available.x-64)
		height = minf(650,available.y-70)
	elif layout_kind == "map":
		width = minf(1220,available.x-48)
		height = minf(740,available.y-112)
	elif layout_kind == "journal":
		width = minf(1180,available.x-56)
		height = minf(740,available.y-112)
	elif layout_kind == "activity":
		width = minf(1100,available.x-48)
		height = minf(700,available.y-64)
	elif layout_kind in ["dialogue","lesson"]:
		width = minf(990,available.x-64)
		height = minf(268 if layout_kind == "dialogue" else 420,available.y-80)
		if current_panel == "purchase":
			height = minf(290,available.y-80)
	elif layout_kind == "decorate":
		width = minf(1140,available.x-48)
		height = 255
	panel.size = Vector2(width,height)
	panel.position = (available-panel.size)/2
	if layout_kind in ["dialogue","lesson","decorate"]:
		panel.position.y = available.y-panel.size.y-24
	var toast_width := clampf(toast_label.get_theme_font("font").get_string_size(toast_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+32,260,480)
	toast_label.position = Vector2((available.x-toast_width)/2,12)
	toast_label.size = Vector2(toast_width,0)

func _process(delta: float) -> void:
	if is_instance_valid(avatar_preview): avatar_preview.reduced_motion = reduced_motion
	if is_instance_valid(wardrobe_preview): wardrobe_preview.reduced_motion = reduced_motion
	toast_timer -= delta
	bubble_timer -= delta
	if toast_timer <= 0:
		toast_label.hide()
	if bubble_timer <= 0 or modal.visible:
		bubble_panel.hide()
