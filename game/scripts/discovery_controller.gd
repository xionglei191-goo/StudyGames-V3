extends Node
## Child-owned discovery cards and district pages, with separately saved drafts.
const Progress = preload("res://scripts/discovery_progress.gd")
const Artwork = preload("res://ui/discovery_artwork.gd")
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const THEME_LABELS := {"sunrise":"晨光", "meadow":"草地", "sea":"海边"}
const LAYOUT_LABELS := {"portrait":"大图", "postcard":"明信片"}
var journey: Node
var game: Node3D
var ui: CanvasLayer
var labels: Dictionary = {}
var current_type := "card"
var current_id := ""
var preview: Control
var choices: Dictionary = {}
var display_button: Button
var draft_note: Label

func setup(owner: Node) -> void:
	journey = owner
	game = owner.game
	ui = owner.ui
	var prologue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/prologue.json"))
	for record: Dictionary in prologue.get("letters",[]):
		labels[str(record.letter.uppercase)] = str(record.anchor.chinese_image_name)

func state() -> Dictionary:
	return journey.snapshot().p2.discovery

func commit(event: Dictionary) -> bool:
	event.room = game.room
	return State.journey_p2_event(event)

func _event(kind: String, extra: Dictionary = {}) -> bool:
	var event := {"kind":kind,"item_type":current_type,"item_id":current_id}
	event.merge(extra)
	return commit(event)

func _open(title: String, subtitle: String) -> bool:
	if not game._prepare_screen(): return false
	ui._begin("discovery","map")
	ui._heading(title,subtitle)
	return true

func _text(parent: Node, value: String, font_size: int = 19, muted: bool = false) -> Label:
	var label: Label = ui.label(value,font_size,Style.MUTED if muted else Style.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	return row

func _button(parent: Node, value: String, callback: Callable, primary: bool = false, node_name: String = "") -> Button:
	var button: Button = ui.button(value,"",primary,Vector2(0,44))
	button.name = node_name if not node_name.is_empty() else "DiscoveryButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func show_collection() -> void:
	if not _open("我的发现收藏册","每次发现都在这里 · 选一张做成小屋里的作品"): return
	var snapshot: Dictionary = journey.snapshot()
	var own := state()
	var letters := Progress.eligible_letters(snapshot)
	var pages := Progress.eligible_districts(snapshot)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.panel_box.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	_text(column,"字母发现 · %d 张可制作" % letters.size(),23)
	if letters.is_empty(): _text(column,"先和向导去一处地标，看过图像和字卡，就能做第一张。",20,true)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	column.add_child(grid)
	for letter: String in letters:
		_collection_button(grid,"card",letter,letter+letter.to_lower()+" · "+str(labels.get(letter,"")),own)
	_text(column,"五个街区的旅行页 · %d / 5" % pages.size(),23)
	var districts := GridContainer.new()
	districts.columns = 3
	districts.add_theme_constant_override("h_separation",10)
	districts.add_theme_constant_override("v_separation",10)
	column.add_child(districts)
	for id: String in Progress.DISTRICTS:
		if pages.has(id): _collection_button(districts,"page",id,str(Progress.DISTRICT_NAMES[id]),own)
		else:
			var visited := 0
			for letter: String in str(Progress.DISTRICTS[id]):
				if letters.has(letter): visited += 1
			var waiting := _button(districts,str(Progress.DISTRICT_NAMES[id])+"\n发现 %d / %d" % [visited,str(Progress.DISTRICTS[id]).length()],func(): pass)
			waiting.disabled = true
	var actions := _row(ui.panel_box)
	_button(actions,"回小屋看看",go_home,true,"DiscoveryGoHome")
	_button(actions,"继续我的旅程",journey.continue_journey,false,"DiscoveryContinue")
	_button(actions,"先合上收藏册",game._close,false,"DiscoveryClose")
	_finish("DiscoveryContinue" if letters.is_empty() else "DiscoveryGoHome")

func _collection_button(parent: Node, item_type: String, id: String, title: String, own: Dictionary) -> void:
	var saved := Progress.designs(own,item_type)
	var key := Progress.item_key(item_type,id)
	var status := "接着做" if own.drafts.has(key) else "再看看" if saved.has(id) else "来做一张"
	if own.display[item_type] == id: status = "家里正展示"
	var button := _button(parent,title+"\n"+status,show_item.bind(item_type,id),false,"DiscoveryItem_"+item_type+"_"+id)
	button.custom_minimum_size = Vector2(0,92)
	var letter: String = saved[id].design.image_letter if saved.has(id) else str(Progress.default_design(item_type,id).image_letter)
	button.icon = Content.icon(letter,0.35)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width",44)

func show_item(item_type: String, item_id: String) -> void:
	if not Progress.eligible(journey.snapshot(),item_type,item_id): show_collection(); return
	current_type = item_type
	current_id = item_id
	var saved := Progress.designs(state(),item_type)
	if not saved.has(item_id): begin_edit(item_type,item_id); return
	if not _open("我带回家的发现","这张作品可以一直保留，也可以继续改样式"): return
	preview = Artwork.new()
	preview.name = "DiscoverySavedArtwork"
	ui.panel_box.add_child(preview)
	var design: Dictionary = saved[item_id].design
	preview.setup(item_type,item_id,design,str(labels.get(design.image_letter,"")))
	_text(ui.panel_box,"家里正在展示" if state().display[item_type] == item_id else "好好收在收藏册里",18,true)
	var actions := _row(ui.panel_box)
	_button(actions,"接着上次做" if state().drafts.has(Progress.item_key(item_type,item_id)) else "换个喜欢的样子",begin_edit.bind(item_type,item_id),true,"DiscoveryEdit")
	_button(actions,"回到收藏册",show_collection,false,"DiscoveryBack")
	_finish("DiscoveryEdit")

func show_letter_reward(letter: String) -> void:
	begin_edit("card",letter)

func show_district_reward(district_id: String) -> void:
	begin_edit("page",district_id)

func begin_edit(item_type: String, item_id: String) -> void:
	if not Progress.eligible(journey.snapshot(),item_type,item_id): show_collection(); return
	if not game._prepare_screen(): return
	current_type = item_type
	current_id = item_id
	if _event("discovery_begin"): show_editor()

func show_editor() -> void:
	var key := Progress.item_key(current_type,current_id)
	if not state().drafts.has(key): show_collection(); return
	if not _open("做一张我的发现卡" if current_type == "card" else "做一页我的街区旅行","选择会暂存 · 确认后才放进收藏册和小屋"): return
	choices.clear()
	var body := _row(ui.panel_box)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview = Artwork.new()
	preview.name = "DiscoveryDraftArtwork"
	body.add_child(preview)
	var draft: Dictionary = state().drafts[key]
	preview.setup(current_type,current_id,draft.design,str(labels.get(draft.design.image_letter,"")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 280
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation",8)
	scroll.add_child(sidebar)
	if current_type == "page":
		_text(sidebar,"哪一个发现放大一些？",20)
		var image_grid := GridContainer.new()
		image_grid.columns = 2
		image_grid.add_theme_constant_override("h_separation",6)
		image_grid.add_theme_constant_override("v_separation",6)
		sidebar.add_child(image_grid)
		for letter: String in str(Progress.DISTRICTS[current_id]):
			var button := _choice(image_grid,letter+letter.to_lower(),"image_letter",letter)
			button.icon = Content.icon(letter,0.25)
	else: _text(sidebar,current_id+current_id.to_lower()+" 的固定地标图\n"+str(labels.get(current_id,"")),21)
	_text(sidebar,"选个背景",20)
	var themes := _row(sidebar)
	for theme_name: String in Progress.THEMES: _choice(themes,THEME_LABELS[theme_name],"theme",theme_name)
	_text(sidebar,"喜欢怎样排？",20)
	var layouts := _row(sidebar)
	for layout_name: String in Progress.LAYOUTS: _choice(layouts,LAYOUT_LABELS[layout_name],"layout",layout_name)
	display_button = _button(sidebar,"",_toggle_display,false,"DiscoveryDisplayChoice")
	display_button.toggle_mode = true
	draft_note = _text(sidebar,"",17,true)
	var actions := _row(ui.panel_box)
	_button(actions,"确认收好",confirm_design,true,"DiscoveryConfirm")
	_button(actions,"下次接着做",show_collection,false,"DiscoveryPause")
	_button(actions,"取消这次修改",cancel_design,false,"DiscoveryCancel")
	_refresh_editor()
	_finish("DiscoveryConfirm")

func _choice(parent: Node, title: String, field: String, value: String) -> Button:
	var button := _button(parent,title,_choose.bind(field,value),false,"DiscoveryChoice_"+field+"_"+value)
	button.toggle_mode = true
	choices[field+"/"+value] = button
	return button

func _choose(field: String, value: String) -> void:
	if _event("discovery_image" if field == "image_letter" else "discovery_"+field,{field:value}): _refresh_editor()

func _toggle_display() -> void:
	var draft: Dictionary = state().drafts[Progress.item_key(current_type,current_id)]
	if _event("discovery_display",{"display":not draft.display}): _refresh_editor()

func _refresh_editor() -> void:
	var draft: Dictionary = state().drafts.get(Progress.item_key(current_type,current_id),{})
	if draft.is_empty(): return
	preview.caption = str(labels.get(draft.design.image_letter,""))
	preview.update_design(draft.design)
	for key: String in choices:
		var parts := key.split("/")
		var selected: bool = draft.design[parts[0]] == parts[1]
		var button: Button = choices[key]
		button.set_pressed_no_signal(selected)
		button.theme_type_variation = "PrimaryButton" if selected else "Button"
	display_button.text = "已选：带回小屋展示" if draft.display else "收进册里 · 点这里选展示"
	display_button.set_pressed_no_signal(draft.display)
	display_button.theme_type_variation = "PrimaryButton" if draft.display else "Button"
	draft_note.text = "这次选择已经暂存。\n"+("确认后替换家里的同类作品；原作品仍留在册里。" if draft.display else "先收在册里，以后随时可以挂起来。")

func confirm_design() -> void:
	if not _event("discovery_confirm"): return
	journey._build_story_props()
	show_item(current_type,current_id)
	ui.notify("作品收好啦！回到小屋就能看见。" if state().display[current_type] == current_id else "作品收进收藏册啦！以后可以再选展示。")

func cancel_design() -> void:
	if not _event("discovery_cancel"): return
	show_collection()
	ui.notify("保留原来的作品；这次修改已经放下。")

func go_home() -> void:
	if not game._prepare_screen(): return
	if game.room != "home": await game.change_room("home")
	game._close()
	ui.notify("发现架就在小屋里。走近后可以再打开收藏册。")

func handles_interaction(id: String) -> bool:
	if id != "journey_discoveries": return false
	show_collection()
	return true

func build_world(parent: Node3D, position: Vector3, mount: Vector3) -> void:
	var own := state()
	var display_root := Node3D.new()
	display_root.name = "DiscoveryKeepsakes"
	display_root.set_meta("display",own.display.duplicate(true))
	display_root.set_meta("draft_visible",false)
	parent.add_child(display_root)
	var viewport := SubViewport.new()
	viewport.name = "DiscoveryCanvas"
	viewport.size = Vector2i(1120,600)
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	display_root.add_child(viewport)
	for index: int in Progress.TYPES.size():
		var item_type := Progress.TYPES[index]
		var id: String = own.display[item_type]
		var saved := Progress.designs(own,item_type)
		var design: Dictionary = saved[id].design if saved.has(id) else {}
		var picture := Artwork.new()
		picture.name = "DiscoveryHome_"+item_type
		picture.theme = Style.make_theme()
		viewport.add_child(picture)
		picture.position = Vector2(index*560,35)
		picture.size = Vector2(560,500)
		picture.setup(item_type,id,design,str(labels.get(design.get("image_letter",""),"")))
		picture.set_meta("confirmed",not id.is_empty())
	var sprite := Sprite3D.new()
	sprite.name = "ConfirmedDiscoveries"
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 0.0018
	sprite.position = mount
	# A wall-mounted pair of keepsakes stays in the room's plane rather than
	# rotating across nearby furniture as a full-camera-facing billboard.
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	display_root.add_child(sprite)
	var backing := MeshInstance3D.new()
	backing.name = "DiscoveryWallFrame"
	var shape := BoxMesh.new()
	shape.size = Vector3(2.08,1.04,0.08)
	backing.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("aa8053")
	material.roughness = 0.9
	backing.material_override = material
	backing.position = mount + Vector3(0,0,-0.05)
	display_root.add_child(backing)
	var found := false
	for interaction: Dictionary in game.interactions:
		if interaction.id == "journey_discoveries": found = true; interaction.position = position
	if not found: game.interactions.append({"id":"journey_discoveries","type":"memory","position":position,"radius":1.65,"label":"看看我的发现收藏"})
	game.feedback.bind_interactions(game.interactions)

func _finish(focus_name: String = "") -> void:
	ui._layout.call_deferred()
	var button: Button = ui.panel_box.find_child(focus_name,true,false) as Button
	if button: ui._focus_if_current.call_deferred(button.get_instance_id())
