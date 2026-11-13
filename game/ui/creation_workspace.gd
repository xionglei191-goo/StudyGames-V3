extends RefCounted
## Bounded workspace layouts. Game transactions remain in CreationController.
const Style = preload("res://ui/island_theme.gd")
const C = preload("res://gameplay/creation_catalog.gd")
const Preview = preload("res://ui/creation_preview.gd")
const Painter = preload("res://ui/creation_canvas.gd")
const PAINTABLE := ["sign","frame","rug","table","stand","cake","plate"]
const COLOR_NAMES := ["奶油白","浅麦黄","蜂蜜木","可可棕","浅杏粉","珊瑚粉","莓果红","向日葵黄","嫩叶绿","森林绿","薄荷青","晴空蓝","鸢尾紫","丁香紫","雾蓝灰","深墨色"]
const WISHES := {
	"reading":{"title":"布置自己的阅读角","description":"做一张小桌、一个座位，给喜欢的书留一个舒服的位置。","icon":"journal"},
	"collection":{"title":"做一套自己的作品","description":"把喜欢的颜色和图案，变成属于你的手作收藏。","icon":"art"},
	"stall":{"title":"试开苹果点心摊","description":"学做点心，布置小摊，把第一份心意送到客人手里。","icon":"cake"}
}
var host: Node3D
var ui: CanvasLayer
var body: Control
var scroll: ScrollContainer
var save_status: Label
var section := "心愿"
var recipe_grid: GridContainer
var _reflow_queued := false

func setup(controller: Node3D) -> void:
	host = controller
	ui = host.ui
	ui.root.resized.connect(_arrange)
	ui.panel.minimum_size_changed.connect(_queue_reflow)

func _queue_reflow() -> void:
	if _reflow_queued or ui.layout_kind!="creation": return
	_reflow_queued = true
	call_deferred("_settle_layout")

func _settle_layout() -> void:
	var tree := ui.get_tree()
	# Container minimum sizes and wrapped text settle on the following frames.
	await tree.process_frame
	await tree.process_frame
	_reflow_queued = false
	if is_instance_valid(ui) and ui.layout_kind=="creation": ui._layout()

func _arrange() -> void:
	if is_instance_valid(recipe_grid): recipe_grid.columns = 4 if ui.root.size.x>=1380 else 3
	_queue_reflow()

func screen(title: String, subtitle: String, editor: bool = false, active_section: String = "") -> void:
	if not active_section.is_empty(): section = active_section
	ui._begin("creation_editor" if editor else "creation","creation")
	var header := hbox(ui.panel_box,16)
	if editor:
		action(header,"‹ 返回工坊",host.show_recipes,"quiet")
	else:
		header.add_child(ui.icon_view("art" if section=="工坊" else "journal",44))
	var titles := vbox(header,4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(titles,title,28)
	if not subtitle.is_empty(): text(titles,subtitle,16,Style.MUTED)
	if editor:
		save_status = text(header,"草稿已保留",16,Style.SAGE)
		save_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		var balance := text(header,"第 %d 天   ·   %d 叶币" % [int(host.state.data.day),int(host.state.data.coins)],16,Style.MUTED)
		balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close := action(header,"×",host.game._request_close,"quiet")
	close.custom_minimum_size = Vector2(44,44)
	close.tooltip_text = "关闭 · Esc"
	close.name = "CreationClose"
	if not editor: navigation()
	body = Control.new()
	body.name = "CreationBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(body)
	scroll = ScrollContainer.new()
	scroll.name = "PageScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.content = vbox(scroll,16)
	host.content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._layout.call_deferred()
	_queue_reflow()

func navigation() -> void:
	var bar := hbox(ui.panel_box,8)
	bar.name = "CreationNavigation"
	for entry: Array in [["心愿",host.show_home],["工坊",host.show_recipes],["作品册",host.show_designs],["仓库",host.show_inventory],["材料",host.show_materials]]:
		var b := action(bar,entry[0],entry[1],"selected" if section==entry[0] else "tab")
		b.custom_minimum_size.x = 96
	var more := MenuButton.new()
	more.name = "MoreLifePages"
	more.text = section+" ▼" if section in ["订单","小摊","回忆"] else "更多生活 ▼"
	style_button(more,"selected" if section in ["订单","小摊","回忆"] else "tab")
	bar.add_child(more)
	for label_value: String in ["订单","小摊","回忆"]: more.get_popup().add_item(label_value)
	more.get_popup().id_pressed.connect(func(index: int): [host.show_orders,host.show_stall,host.show_memories][index].call())
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(space)
	var hint := text(bar,"慢慢做，也很好",16,Style.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func home() -> void:
	var snapshot: Dictionary = host.snapshot()
	var wish: String = str(snapshot.wish)
	var available: bool = C.available(host.state.data)
	var started: bool = bool(snapshot.started)
	var main := hbox(host.content,20)
	var hero := surface(main,Style.SOFT,20)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 1.85
	hero.name = "CurrentWish"
	var hero_box := vbox(hero,12)
	var top := hbox(hero_box,16)
	var words := vbox(top,12)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(words,"正在实现的小心愿" if started else "从一个小想法开始",16,Style.SAGE)
	text(words,WISHES[wish].title if started else "把喜欢的生活，亲手做出来",28)
	text(words,WISHES[wish].description if started else "画一个图案，做一件小物，再把它放进自己的家。",18)
	var illustration := vbox(top,4)
	illustration.custom_minimum_size.x = 240
	var stage := Preview.new()
	stage.custom_minimum_size = Vector2(240,230)
	illustration.add_child(stage)
	stage.show_wish(wish)
	var caption := text(illustration,"灵感一角",14,Style.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not available:
		text(hero_box,"先跟熊叔熟悉家园，就可以来这里自由创作。",18)
		action(hero_box,"继续家园介绍",host.game.journey.show_home,"primary")
	elif not started:
		text(hero_box,"画画与试色免费。领取一份木料和纤维，就能开始第一件作品。",18)
		action(hero_box,"领取材料，开始创作",func():
			if host.transact("start").ok: host.show_home()
		,"primary")
	else:
		var progress := wish_progress(wish)
		var steps := hbox(hero_box,12)
		for index: int in range(progress.labels.size()):
			var done: bool = progress.done[index]
			var step := text(steps,("✓ " if done else str(index+1)+"  ")+str(progress.labels[index]),16,Style.SAGE if done else Style.MUTED)
			step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bottom := hbox(hero_box,12)
		var next_button := action(bottom,progress.action,progress.callback,"primary")
		next_button.name = "WishNextStep"
		text(bottom,progress.hint,16,Style.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var side := surface(main,Style.PAPER,18)
	side.custom_minimum_size.x = 270
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side_box := vbox(side,14)
	text(side_box,"在岛上走一走",22)
	shortcut(side_box,"home","回家布置","让刚做好的作品有个位置",host.travel.bind("home",host.show_inventory))
	shortcut(side_box,"flower_box","去小院","采些材料，看看自己的小摊",host.travel.bind("home_estate",host.show_materials))
	shortcut(side_box,"picnic","邀请朋友","一起坐坐，留一张合照",host.show_visitors)
	if started:
		var alternatives := hbox(host.content,16)
		for other: String in WISHES:
			if other == wish: continue
			var panel := surface(alternatives,Style.PAPER,16)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var line := hbox(panel,14)
			line.add_child(ui.icon_view(WISHES[other].icon,52))
			var info := vbox(line,6)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text(info,WISHES[other].title,20)
			action(info,"换个小心愿 →",func():
				if host.transact("wish",{"id":other}).ok: host.show_home()
			,"link")
		var rest := hbox(host.content,12)
		action(rest,"去邻里作品角",host.travel.bind("landmark_F",host.show_community),"link")
		action(rest,"回家休息，开始新的一天",func():
			await host.travel("home",host.show_home)
			if host.state.next_day(): host.show_home()
		,"link")

func wish_progress(wish: String) -> Dictionary:
	var s: Dictionary = host.snapshot()
	var designs: bool = s.designs.size()>0
	var made: bool = s.items.size()>0
	var placed := false
	for item: Dictionary in s.items.values(): placed = placed or item.where=="placed"
	var progress := {"labels":["画好设计","制作实物","摆进家里"],"done":[designs,made,placed],"action":"去设计第一件作品","callback":host.show_recipes,"hint":"先从一张小凳开始"}
	if designs and not made: progress.merge({"action":"选一件设计来制作","callback":host.show_designs,"hint":"确认材料后再动手"},true)
	elif made and not placed: progress.merge({"action":"把作品摆进家里","callback":host.show_inventory,"hint":"作品已经在仓库等你"},true)
	elif placed: progress.merge({"action":"邀请朋友来坐坐","callback":host.show_visitors,"hint":"一起看看你布置的小角落"},true)
	if wish=="collection":
		var grouped := false
		for design: Dictionary in s.designs.values(): grouped = grouped or not str(design.series).is_empty()
		progress.labels = ["保存设计","制作作品","给系列起名"]
		progress.done = [designs,made,grouped]
		if made: progress.merge({"action":"整理我的作品册","callback":host.show_designs,"hint":"给喜欢的作品取个系列名字"},true)
	elif wish=="stall":
		var learned: bool = s.recipes.has("cake")
		var food := false
		for item: Dictionary in s.items.values(): food = food or item.design.recipe in ["cake","plate"]
		progress.labels = ["学做点心","做一份点心","完成第一单"]
		progress.done = [learned,food,int(s.stall.total)>0]
		progress.merge({"action":"找米洛学做点心","callback":host.travel.bind("landmark_C",host.show_materials),"hint":"去烘焙坊认识新手艺"},true)
		if learned: progress.merge({"action":"设计一份苹果点心","callback":host.edit.bind("",C.blank_design("cake")),"hint":"做成以后就能陈列到小摊"},true)
		if food: progress.merge({"action":"去看看我的小摊","callback":host.show_stall,"hint":"挑好作品，再开始营业"},true)
	return progress

func shortcut(parent: Node, icon: String, title: String, hint: String, callback: Callable) -> void:
	var line := hbox(parent,12)
	line.add_child(ui.icon_view(icon,40))
	var info := vbox(line,2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action(info,title+" →",callback,"link")
	text(info,hint,15,Style.MUTED)

func recipes() -> void:
	var s: Dictionary = host.snapshot()
	if not s.draft.is_empty():
		var draft := surface(host.content,Style.SOFT,14)
		var line := hbox(draft,16)
		var draft_name := text(line,"上次的灵感还在 · "+str(s.draft.name),18)
		draft_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var source := str(s.draft.get("source_design",""))
		action(line,"继续上次草稿",host.edit.bind(source if s.designs.has(source) else "",s.draft.duplicate(true)),"primary")
	recipe_grid = GridContainer.new()
	recipe_grid.name = "RecipeGallery"
	recipe_grid.columns = 4 if ui.root.size.x>=1380 else 3
	recipe_grid.add_theme_constant_override("h_separation",16)
	recipe_grid.add_theme_constant_override("v_separation",16)
	host.content.add_child(recipe_grid)
	for id: String in C.RECIPES:
		var unlocked: bool = s.recipes.has(id)
		var panel := surface(recipe_grid,Style.PAPER,14)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := vbox(panel,10)
		var preview := Preview.new()
		preview.custom_minimum_size = Vector2(0,150)
		box.add_child(preview)
		preview.show_design(C.blank_design(id))
		text(box,C.RECIPES[id].name,22)
		text(box,C.cost_text(id),16,Style.MUTED)
		if unlocked:
			action(box,"设计这件作品",host.edit.bind("",C.blank_design(id)),"primary")
		else:
			var hint := "做成第一件作品后开放" if id in ["rug","basket"] else "招待朋友或借展后开放"
			if id in ["cake","plate"]: hint = "去烘焙坊向米洛学习"
			if id=="vase": hint = "去花园向花婆婆学习"
			text(box,hint,15,Style.MUTED)
			var locked := action(box,"还没学会",func(): pass,"quiet")
			locked.disabled = true
	var links := hbox(host.content,12)
	action(links,"找米洛学烘焙",host.travel.bind("landmark_C",host.show_materials),"link")
	action(links,"找花婆婆学花艺",host.travel.bind("landmark_F",host.show_materials),"link")

func editor() -> void:
	body.remove_child(scroll)
	scroll.queue_free()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",20)
	body.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := surface(columns,Style.SOFT,16)
	left.name = "CreativeStage"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.65
	var board := vbox(left,10)
	var paintable: bool = PAINTABLE.has(str(host._draft.recipe))
	var board_header := hbox(board,12)
	text(board_header,"画下你的图案" if paintable else "先挑一种喜欢的颜色",20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not paintable:
		action(board_header,"转一转",host.turn_preview,"quiet")
	host._painter = Painter.new()
	host._painter.name = "DesignCanvas"
	host._painter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host._painter.pattern = host._draft.pattern
	if paintable:
		var tool_row := hbox(board,8)
		var group := ButtonGroup.new()
		var stamps := OptionButton.new()
		for key: String in host.snapshot().stamps: stamps.add_item(C.STAMPS[key])
		host._painter.stamp = host.snapshot().stamps[0]
		for entry: Array in [["画笔","brush"],["填色","fill"],["橡皮","erase"],["印章","stamp"]]:
			var tool := action(tool_row,entry[0],func():
				host._painter.tool = entry[1]
				stamps.visible = entry[1]=="stamp"
			,"toggle")
			tool.button_group = group
			tool.toggle_mode = true
			tool.button_pressed = entry[1]=="brush"
			tool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_id(tool,"tool:"+str(entry[1]))
		action(tool_row,"撤销",host._painter.undo,"quiet").tooltip_text = "撤销这一次笔画 · Ctrl+Z"
		style_button(stamps,"quiet")
		stamps.name = "StampSelector"
		stamps.item_selected.connect(func(index: int): host._painter.stamp=host.snapshot().stamps[index])
		stamps.hide()
		board_header.add_child(stamps)
		var painting_area := hbox(board,12)
		painting_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var canvas_area := AspectRatioContainer.new()
		canvas_area.name = "CanvasArea"
		canvas_area.ratio = 1.0
		canvas_area.stretch_mode = AspectRatioContainer.STRETCH_FIT
		canvas_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		canvas_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		painting_area.add_child(canvas_area)
		canvas_area.add_child(host._painter)
		var ink_box := vbox(painting_area,8)
		ink_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text(ink_box,"颜色",16,Style.MUTED)
		palette(ink_box,false,2)
	else:
		board.add_child(host._painter)
		host._painter.hide()
		host.build_preview(board)
		text(board,"配色和造型会直接用在做好的实物上。",16,Style.MUTED)
		palette(board,true)
	host._painter.edited.connect(host._mark_dirty)
	var right := vbox(columns,12)
	right.custom_minimum_size.x = 340
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if paintable:
		var preview_frame := surface(right,Style.SOFT,12)
		preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview_frame.size_flags_stretch_ratio = 1.1
		var preview_box := vbox(preview_frame,4)
		var preview_header := hbox(preview_box,8)
		text(preview_header,"做出来的样子",18).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action(preview_header,"转一转",host.turn_preview,"link")
		host.build_preview(preview_box)
	else:
		text(right,"让小物件有自己的名字",22)
		text(right,"挑个造型，再给这件小作品取个名字。",17,Style.MUTED)
	var settings := Control.new()
	settings.name = "DesignSettings"
	settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(settings)
	var settings_box := vbox(settings,8)
	settings_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tabs := hbox(settings_box,8)
	var panes := Control.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_box.add_child(panes)
	var appearance := settings_page(panes)
	var naming := settings_page(panes)
	naming.hide()
	var tab_group := ButtonGroup.new()
	if paintable:
		for entry: Array in [["外观",appearance],["名字与文字",naming]]:
			var tab := action(tabs,entry[0],func():
				appearance.visible = entry[1]==appearance
				naming.visible = entry[1]==naming
			,"toggle")
			tab.toggle_mode = true
			tab.button_group = tab_group
			tab.button_pressed = entry[1]==appearance
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		tabs.hide()
	var appearance_box: VBoxContainer = appearance.get_child(0)
	if paintable:
		text(appearance_box,"实物配色",16,Style.MUTED)
		var color := option(appearance_box,COLOR_NAMES,int(host._draft.color))
		color.item_selected.connect(func(index: int): host._draft.color=index; host._mark_dirty())
	if host._draft.recipe in ["stool","table","vase","cake","plate"]:
		text(appearance_box,"造型",16,Style.MUTED)
		var shapes := hbox(appearance_box,8)
		var shape_group := ButtonGroup.new()
		for index: int in range(2):
			var title: String = ["圆形","方形"][index] if host._draft.recipe in ["stool","table"] else ["款式一","款式二"][index]
			var shape := action(shapes,title,func():
				host._draft.shape=index
				host._mark_dirty()
			,"toggle")
			shape.toggle_mode = true
			shape.button_group = shape_group
			shape.button_pressed = int(host._draft.shape)==index
			shape.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(appearance_box,"小装饰",16,Style.MUTED)
	var trim := option(appearance_box,["素面部件","金色装饰","青色装饰"],int(host._draft.trim))
	trim.item_selected.connect(func(index: int): host._draft.trim=index; host._mark_dirty())
	if paintable:
		var repeat_box := CheckBox.new()
		repeat_box.text = "把图案平铺成四格"
		style_button(repeat_box,"link")
		repeat_box.button_pressed = bool(host._draft.repeat)
		repeat_box.toggled.connect(func(value: bool): host._draft.repeat=value; host._mark_dirty())
		appearance_box.add_child(repeat_box)
	var naming_box: VBoxContainer = naming.get_child(0) if paintable else appearance_box
	host._name_field = host.field(naming_box,"作品名字",host._draft.name)
	var text_fields: VBoxContainer = naming_box if paintable else naming.get_child(0)
	host._text_field = host.field(text_fields,"写在作品上的文字",host._draft.text)
	host._series_field = host.field(naming_box,"系列名字 · 可留空",host._draft.series)
	if not paintable:
		host._text_field.editable = false
		host._text_field.tooltip_text = "文字可用在招牌、画框、桌面和地毯上；已有文字仍保留在设计里。"
		text(naming_box,"想把画画进作品里？试试招牌、画框或小桌。",16,Style.MUTED)
		action(naming_box,"换个作品试试 →",host.show_surface_choices,"link")
	if host._draft.recipe=="frame":
		var photo_path := str(host.state.data.journey.u1.photo.details.get("image_path",""))
		if not photo_path.is_empty() and FileAccess.file_exists(photo_path):
			action(naming_box,"装入我们的第一张合照",func(): host._draft.keepsake=photo_path; host._mark_dirty(),"quiet")
		action(naming_box,"使用自己的绘画",func(): host._draft.keepsake=""; host._mark_dirty(),"quiet")
	var footer := hbox(ui.panel_box,12)
	footer.name = "WorkshopFooter"
	var materials := vbox(footer,4)
	materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(materials,"制作需要",14,Style.MUTED)
	text(materials,C.cost_text(host._draft.recipe,host.state.data),17)
	var more := MenuButton.new()
	more.text = "更多 ▼"
	style_button(more,"quiet")
	footer.add_child(more)
	more.get_popup().add_item("另存一份")
	more.get_popup().add_item("预览其他表面")
	more.get_popup().id_pressed.connect(func(index: int):
		if index==0: host.save_design(true)
		else: host.show_surface_choices()
	)
	action(footer,"保存设计",host.save_design.bind(false),"quiet").name = "SaveDesign"
	action(footer,"保存后确认制作",func():
		var saved: String = host.save_design(false)
		if not saved.is_empty(): host.craft_confirm(saved)
	,"primary").name = "SaveAndCraft"

func settings_page(parent: Node) -> ScrollContainer:
	var page := ScrollContainer.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := vbox(page,8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return page

func palette(parent: Node, object_color: bool, columns: int = 8) -> void:
	var group := ButtonGroup.new()
	var grid := GridContainer.new()
	grid.name = "ObjectColors" if object_color else "PaintColors"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	parent.add_child(grid)
	for index: int in range(16):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(44,44)
		swatch.tooltip_text = COLOR_NAMES[index]
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.button_pressed = index==int(host._draft.color if object_color else host._painter.ink)
		for state_name: String in ["normal","hover","pressed","hover_pressed","focus"]:
			var fill := flat(Color(C.PALETTE[index]),10,4)
			fill.border_color = Style.INK if state_name in ["pressed","hover_pressed","focus"] else Style.LINE
			fill.set_border_width_all(3 if state_name in ["pressed","hover_pressed","focus"] else 1)
			swatch.add_theme_stylebox_override(state_name,fill)
		swatch.pressed.connect(func():
			if object_color: host._draft.color=index; host._mark_dirty()
			else: host._painter.ink=index
		)
		grid.add_child(swatch)

func option(parent: Node, values: Array, selected: int) -> OptionButton:
	var result := OptionButton.new()
	for item: String in values: result.add_item(item)
	result.select(selected)
	style_button(result,"quiet")
	parent.add_child(result)
	return result

func status(dirty: bool) -> void:
	if is_instance_valid(save_status): save_status.text = "正在保留草稿…" if dirty else "草稿已保留"

static func flat(color: Color, radius: int = 12, padding: int = 12) -> StyleBoxFlat:
	var fill := Style.box(color,radius,padding)
	fill.shadow_size = 0
	fill.border_color = Style.LINE
	return fill

static func surface(parent: Node, color: Color, padding: int = 16) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",flat(color,16,padding))
	parent.add_child(panel)
	return panel

static func hbox(parent: Node, gap: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	parent.add_child(box)
	return box

static func vbox(parent: Node, gap: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	parent.add_child(box)
	return box

static func text(parent: Node, value: String, size: int = 18, color: Color = Style.INK) -> Label:
	var label := Style.text(value,size,color)
	label.add_theme_font_size_override("font_size",size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

static func action(parent: Node, value: String, callback: Callable, kind: String = "quiet") -> Button:
	var button := Button.new()
	button.text = value
	style_button(button,kind)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

static func action_id(button: Button, value: String) -> void:
	button.set_meta("creation_action",value)

static func style_button(button: Button, kind: String) -> void:
	button.custom_minimum_size.y = 44
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",17)
	var selected := kind in ["primary","selected"]
	for state_name: String in ["normal","hover","pressed","hover_pressed","disabled"]:
		var active := selected or (kind=="toggle" and state_name in ["pressed","hover_pressed"])
		var color := Style.SAGE if active else (Color.TRANSPARENT if kind in ["link","tab"] else Style.PAPER)
		if state_name=="hover" and not selected: color = Style.SOFT
		var fill := flat(color,10,10)
		if kind in ["link","tab"]: fill.set_border_width_all(0)
		button.add_theme_stylebox_override(state_name,fill)
		button.add_theme_color_override("font_"+state_name+"_color" if state_name!="normal" else "font_color",Style.PAPER if active else Style.INK)
	var focus := flat(Color.TRANSPARENT,10,0)
	focus.border_color = Style.GOLD
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	if kind=="link": button.alignment=HORIZONTAL_ALIGNMENT_LEFT
