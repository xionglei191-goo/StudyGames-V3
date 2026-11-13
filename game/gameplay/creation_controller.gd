extends Node3D
## The workshop is shared by home life, collecting and optional sales.
const C = preload("res://gameplay/creation_catalog.gd")
const Model = preload("res://gameplay/creation_state.gd")
const Visual = preload("res://gameplay/creation_visuals.gd")
const Canvas = preload("res://ui/creation_canvas.gd")
const Style = preload("res://ui/island_theme.gd")
const Memories = preload("res://scripts/friend_memories_controller.gd")
const Workspace = preload("res://ui/creation_workspace.gd")
const CraftPreview = preload("res://ui/creation_preview.gd")
var game: Node3D
var state: Node
var ui: CanvasLayer
var content: VBoxContainer
var world_items: Node3D
var active := false
var cursor_pos := Vector3.ZERO
var _placement_id := ""
var _rotation := 0
var _ghost: Node3D
var _place_hint: Label
var _editing := false
var _dirty := false
var _draft: Dictionary = {}
var _design_id := ""
var _painter: Control
var _name_field: LineEdit
var _text_field: LineEdit
var _series_field: LineEdit
var _preview_root: Node3D
var _preview_model: Node3D
var _preview_view: SubViewportContainer
var _workspace: RefCounted
var _save_timer: Timer
var _visit_actor: Node3D
var _visit_target := ""
var _visit_elapsed := 0.0
var _visitor_owned := false
var _visitor_origin := Transform3D.IDENTITY
var _visit_front := Vector3.ZERO
var _customer: Node3D
var _customer_owned := false
var _customer_origin := Transform3D.IDENTITY
var _refresh_queued := false
var _last_world_signature := ""

func setup(host: Node3D) -> void:
	game = host
	state = game.get_node("/root/State")
	ui = game.ui
	_workspace = Workspace.new()
	_workspace.setup(self)
	name = "LifeCreation"
	world_items = Node3D.new()
	world_items.name = "CraftedWorks"
	add_child(world_items)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	add_child(_save_timer)
	_save_timer.timeout.connect(_stash)
	state.changed.connect(_state_changed)

func snapshot() -> Dictionary:
	return state.data.get("creation", Model.fresh())

func transact(action: String, args: Dictionary = {}, revision: int = -1) -> Dictionary:
	var result: Dictionary = state.creation_action(action,args,revision)
	if not result.ok: ui.notify(str(result.message))
	if result.ok and action == "eat" and is_instance_valid(_visit_actor): _visit_actor.play_action("take_item")
	return result

func before_close() -> bool:
	if not _stash(): return false
	_editing = false
	close_placement()
	return true

func _stash() -> bool:
	if not _dirty or not _editing: return true
	if is_instance_valid(_name_field): _draft.name = _name_field.text.left(64)
	if is_instance_valid(_text_field): _draft.text = _text_field.text.left(64)
	if is_instance_valid(_series_field): _draft.series = _series_field.text.left(64)
	if is_instance_valid(_painter): _draft.pattern = _painter.pattern
	_draft["source_design"] = _design_id
	var result := transact("draft",{"design":_draft})
	if result.ok:
		_dirty = false
		_workspace.status(false)
	return bool(result.ok)

func _mark_dirty(_value: Variant = null) -> void:
	_dirty = true
	_workspace.status(true)
	_save_timer.start()
	if is_instance_valid(_name_field): _draft.name = _name_field.text.left(64)
	if is_instance_valid(_text_field): _draft.text = _text_field.text.left(64)
	if is_instance_valid(_series_field): _draft.series = _series_field.text.left(64)
	if is_instance_valid(_painter): _draft.pattern = _painter.pattern
	refresh_preview()

func screen(title: String, subtitle: String = "", section: String = "", editor: bool = false) -> bool:
	if not before_close() or not game._prepare_screen(): return false
	_workspace.screen(title,subtitle,editor,section)
	return true

func label(parent: Node, text: String, size: int = 20) -> Label:
	var value: Label = ui.label(text,size)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(value)
	return value

func button(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
	var value := Button.new()
	value.text = text
	value.custom_minimum_size.y = 42
	value.add_theme_font_size_override("font_size",18)
	value.disabled = disabled
	value.pressed.connect(callback)
	parent.add_child(value)
	return value

func row(parent: Node = null) -> HFlowContainer:
	var value := HFlowContainer.new()
	value.add_theme_constant_override("h_separation",10)
	value.add_theme_constant_override("v_separation",10)
	(parent if parent else content).add_child(value)
	return value

func card(title: String, description: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",Style.box(Style.PAPER,14,16))
	content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	label(box,title,23)
	if not description.is_empty(): label(box,description,17)
	return box

func confirm(title: String, body: String, action: String, args: Dictionary, after: Callable) -> void:
	if not screen(title,body): return
	var revision: int = int(snapshot().revision)
	label(content,"确认后保存本次结果。")
	var r := row()
	button(r,"确认",func():
		var result := transact(action,args,revision)
		if result.ok:
			ui.notify(str(result.message))
			after.call()
	)
	button(r,"取消",after)

func show_home() -> void:
	if not screen("我的生活心愿","把小小的喜欢，慢慢变成生活。","心愿"): return
	_workspace.home()

func travel(room_id: String, after: Callable) -> void:
	if not before_close(): return
	await game.change_room(room_id)
	after.call()

func show_recipes() -> void:
	if not snapshot().started: show_home(); return
	if not screen("今天，想做点什么？","选一件小物，从喜欢的颜色开始。","工坊"): return
	_workspace.recipes()

func edit(id: String, design: Dictionary) -> void:
	if not screen("设计 · "+str(C.RECIPES[design.recipe].name),"试色和修改免费，草稿会自动保留。","工坊",true): return
	_editing = true
	_draft = design.duplicate(true)
	_design_id = id
	_dirty = true
	_workspace.editor()
	_workspace.status(true)
	_save_timer.start()

func field(parent: Node, title: String, value: String) -> LineEdit:
	label(parent,title,16)
	var input := LineEdit.new()
	input.max_length = 64
	input.custom_minimum_size.y = 44
	input.add_theme_font_size_override("font_size",18)
	input.add_theme_stylebox_override("normal",Workspace.flat(Style.PAPER,8,8))
	var focus := Workspace.flat(Color.TRANSPARENT,8,0)
	focus.border_color = Style.GOLD
	focus.set_border_width_all(2)
	input.add_theme_stylebox_override("focus",focus)
	input.add_theme_stylebox_override("read_only",Workspace.flat(Style.SOFT,8,8))
	input.text = value
	input.text_changed.connect(_mark_dirty)
	parent.add_child(input)
	return input

func build_preview(parent: Node) -> void:
	_preview_view = CraftPreview.new()
	_preview_view.name = "CraftPreview"
	_preview_view.custom_minimum_size = Vector2(0,160)
	parent.add_child(_preview_view)
	_preview_root = _preview_view.stage
	refresh_preview()

func turn_preview() -> void:
	if is_instance_valid(_preview_view): _preview_view.turn()

func refresh_preview() -> void:
	if not is_instance_valid(_preview_view) or _draft.is_empty(): return
	_preview_model = _preview_view.show_design(_draft)

func save_design(copy: bool) -> String:
	if not _stash(): return ""
	var result := transact("design",{"id":"" if copy else _design_id,"design":_draft})
	if not result.ok: return ""
	_design_id = result.id
	_draft = snapshot().designs[_design_id].duplicate(true)
	ui.notify("「%s」第 %d 版已保存。" % [_draft.name,int(_draft.version)])
	return _design_id

func show_surface_choices() -> void:
	if not _stash(): return
	var source := _draft.duplicate(true)
	if not screen("同一幅画，放在不同地方"): return
	for id: String in ["sign","table","rug","frame"]:
		button(content,C.RECIPES[id].name,func():
			var next := source.duplicate(true)
			next.recipe=id
			next.keepsake=""
			next.name=str(source.name)+" · "+str(C.RECIPES[id].name)
			next.name=next.name.left(64)
			next.version=1
			edit("",next)
		,not snapshot().recipes.has(id))

func craft_confirm(id: String) -> void:
	if not snapshot().designs.has(id): return
	var d: Dictionary = snapshot().designs[id]
	confirm("制作「%s」" % d.name,C.cost_text(d.recipe,state.data),"craft",{"id":id},show_inventory)

func thumbnail(parent: Node, d: Dictionary) -> void:
	var texture := TextureRect.new()
	texture.texture = Canvas.texture_for(d.pattern,d.repeat)
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.custom_minimum_size = Vector2(72,72)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(texture)

func show_designs() -> void:
	if not snapshot().started: show_home(); return
	if not screen("我的作品册","设计一直保留；改版后可选择应用到自己拥有的实物。","作品册"): return
	if snapshot().designs.is_empty(): button(content,"去设计第一件作品",show_recipes)
	for id: String in snapshot().designs:
		var d: Dictionary = snapshot().designs[id]
		var box := card("%s · 第 %d 版%s" % [d.name,int(d.version)," · "+str(d.series) if not d.series.is_empty() else ""],C.cost_text(d.recipe,state.data))
		var actions := row(box)
		thumbnail(actions,d)
		button(actions,"继续编辑",edit.bind(id,d.duplicate(true)))
		button(actions,"制作一件",craft_confirm.bind(id))
		button(actions,"删除设计",confirm.bind("删除设计？","已经做出的实物会保留原来的外观。","delete_design",{"id":id},show_designs))

func show_inventory() -> void:
	if not snapshot().started: show_home(); return
	if not screen("我的作品 · 实物仓库","把做好的作品摆进家里，也可以赠给朋友。","仓库"): return
	var where_names := {"inventory":"仓库", "placed":"家园", "stall":"小摊陈列", "community":"邻里借展", "gifted":"已赠送", "sold":"已售出", "consumed":"已品尝", "recycled":"已回收", "delivered":"已送达"}
	if snapshot().items.is_empty(): button(content,"去工坊做第一件作品",show_recipes)
	var legacy := int(state.data.cakes) - Model.owned_cakes(state.data)
	if legacy > 0: label(content,"原有蛋糕 %d 份，仍可从原背包／商店使用和出售。" % legacy,17)
	for id: String in snapshot().items:
		var item: Dictionary = snapshot().items[id]
		if item.where not in Model.OWNED: continue
		var box := card("%s · %s" % [item.design.name,where_names[item.where]],"%s · 第 %d 版" % [C.RECIPES[item.design.recipe].name,int(item.design.version)])
		var actions := row(box)
		thumbnail(actions,item.design)
		button(actions,"查看与使用",show_item.bind(id))
		if item.where == "inventory": button(actions,"摆进家里",start_placement.bind(id))
		else: button(actions,"收回仓库",func():
			if transact("store",{"id":id}).ok: show_inventory()
		)

func show_item(id: String) -> void:
	if not snapshot().items.has(id): show_inventory(); return
	var item: Dictionary = snapshot().items[id]
	if not screen(item.design.name,"%s · 第 %d 版 · %s" % [C.RECIPES[item.design.recipe].name,int(item.design.version),item.where]): return
	_draft = item.design.duplicate(true)
	build_preview(content)
	var actions := row()
	if item.where in ["inventory","placed"]:
		button(actions,"摆放／移动",start_placement.bind(id))
		if snapshot().designs.has(item.source): button(actions,"换成设计的最新版",func():
			if transact("apply_design",{"id":id,"design":item.source}).ok: show_item(id)
		)
	if item.where == "inventory":
		if item.design.recipe in ["vase","cake","plate"]: button(actions,"放在桌上",show_table_choices.bind(id))
		button(actions,"送给朋友",show_gifts.bind(id))
		button(actions,"摆上小摊",func():
			if transact("stock",{"id":id}).ok: show_stall()
		)
		button(actions,"借给邻里作品角",func():
			await travel("landmark_F",show_community)
			confirm("借展这件作品？","可以随时换一件或收回。","community",{"id":id,"room":game.room},show_community)
		,item.design.recipe not in ["frame","vase","stool"])
		button(content,"回收 · %d 叶币" % int(C.RECIPES[item.design.recipe].recycle),confirm.bind("回收这件实物？","设计稿仍然保留。","recycle",{"id":id},show_inventory))
	else: button(actions,"收回仓库",func():
		if transact("store",{"id":id}).ok: show_inventory()
	)
	match C.RECIPES[item.design.recipe].use:
		"storage": button(content,"打开统一仓库",show_inventory)
		"books": button(content,"翻开教材词故事",game.journey.show_library)
		"light": button(content,"关灯" if item.lit else "开灯",func():
			if transact("light",{"id":id}).ok: show_item(id)
		)
		"food":
			if item.where == "inventory": button(content,"一起品尝／自己享用",confirm.bind("取用一份点心？","品尝后消耗这一份。来访朋友正在使用作品时，会一起品尝。","eat",{"id":id,"room":game.room},show_inventory))
		_: button(content,"邀请朋友使用或参观",show_visitors)

func show_gifts(id: String) -> void:
	if not screen("把作品送给朋友"): return
	for friend: String in C.FRIENDS:
		button(content,"送给 "+C.FRIENDS[friend],confirm.bind("送给 %s？" % C.FRIENDS[friend],"送出的实物保持这次外观，你的设计稿仍然保留。","gift",{"id":id,"friend":friend},show_inventory),not C.known_friend(state.data,friend))

func show_table_choices(id: String) -> void:
	if not screen("放到哪张桌上？","桌上的作品会随桌子一起移动；收纳桌子时，两件实物都回到仓库。"): return
	var count := 0
	for support: String in snapshot().items:
		var base: Dictionary = snapshot().items[support]
		if base.where == "placed" and base.design.recipe in ["table","stand"]:
			count+=1
			button(content,"%s · %s" % [base.design.name,C.ROOMS[base.room]],func():
				if transact("place_on",{"id":id,"support":support}).ok: show_inventory()
			)
	if count==0: label(content,"先制作并摆好一张桌子或陈列台。")

func show_materials() -> void:
	if not snapshot().started: show_home(); return
	if not screen("材料仓库","看看手边有什么，再去岛上找一些新材料。","材料"): return
	if game.room in ["landmark_C","landmark_F"]:
		button(content,"请米洛陪做苹果点心" if game.room == "landmark_C" else "请花婆婆陪做花瓶",teach)
	for id: String in C.MATERIALS:
		var m: Dictionary = C.MATERIALS[id]
		var g: Dictionary = snapshot().gathered.get(id,{"day":0,"count":0})
		var used := int(state.data.harvested) if id == "apple" else int(g.count) if int(g.day) == int(state.data.day) else 0
		var box := card("%s · %s · 库存 %d" % [m.name,m.en,Model.amount(state.data,id)],"%s · 今天还可采 %d 份" % [C.ROOMS[m.room],maxi(0,int(m.daily)-used)])
		var actions := row(box)
		if game.room == m.room: button(actions,"采集 1 份",func():
			if transact("gather",{"id":id,"room":game.room}).ok:
				ui.notify("收到了 1 份"+str(m.name))
				show_materials()
		,used >= int(m.daily))
		else: button(actions,"前往采集点",travel.bind(m.room,show_materials))
		button(actions,"买 1 份 · %d" % int(m.buy),confirm.bind("补齐材料", "%s 1 份，花费 %d 叶币。" % [m.name,int(m.buy)],"buy",{"id":id},show_materials))
		button(actions,"回收 1 份 · %d" % int(m.sell),confirm.bind("回收材料", "%s 1 份，获得 %d 叶币。" % [m.name,int(m.sell)],"sell_material",{"id":id},show_materials))

func teach() -> void:
	if not snapshot().started: show_home(); return
	if not screen("米洛的苹果点心" if game.room == "landmark_C" else "花婆婆的花艺桌","居民提供示范材料，你可以随时照着制作自己的版本。"): return
	_draft = C.blank_design("cake" if game.room == "landmark_C" else "vase")
	build_preview(content)
	label(content,"把三颗苹果放进烘焙盘，摆好果片，做成一份苹果蛋糕。两颗苹果也能做成一份果盘。" if game.room == "landmark_C" else "用两份黏土做瓶身，插入一份花材。你可以选择花的排列和瓶身配色。")
	button(content,"看完示范，收进配方册",func():
		var result := transact("learn",{"room":game.room})
		if result.ok: ui.notify(result.message); show_recipes()
	)

func show_orders() -> void:
	if not snapshot().started: show_home(); return
	if not screen("居民生活订单","把作品送到需要它的朋友手里。","订单"): return
	for id: String in snapshot().orders:
		var order: Dictionary = snapshot().orders[id]
		var spec: Dictionary = C.ORDERS[int(order.kind)]
		var box := card(spec.name,"%s · 送到%s" % [spec.friend,C.ROOMS[spec.room]])
		var prices: PackedStringArray = []
		for recipe: String in spec.recipes: prices.append("%s %d 叶币" % [C.RECIPES[recipe].name,int(C.RECIPES[recipe].sale)])
		label(box," / ".join(prices),17)
		var actions := row(box)
		if not order.accepted: button(actions,"接下订单",func():
			if transact("order_accept",{"id":id}).ok: show_orders()
		)
		else:
			button(actions,"取消订单",func():
				if transact("order_cancel",{"id":id}).ok: show_orders()
			)
			if game.room != spec.room: button(actions,"前往送达",travel.bind(spec.room,show_orders))
			else:
				for iid: String in Model.items_at(snapshot(),"inventory"):
					if spec.recipes.has(snapshot().items[iid].design.recipe):
						button(box,"交付「%s」" % snapshot().items[iid].design.name,confirm.bind("确认交付？","这件作品会送给%s，按实际品种获得叶币。" % spec.friend,"order_deliver",{"id":iid,"order":id,"room":game.room},show_orders))
		button(actions,"换一张订单",func():
			if transact("order_replace",{"id":id}).ok: show_orders()
		)

func show_stall() -> void:
	if not snapshot().started: show_home(); return
	if not screen("小院手作摊","挑好作品，等一位喜欢它的客人。","小摊"): return
	var s: Dictionary = snapshot().stall
	label(content,"%s · %d 个陈列位 · 本次 %d / 3 位顾客 · 收入 %d 叶币" % ["营业中" if s.open else "已收摊",int(s.slots),int(s.served),int(s.income)])
	if game.room != "home_estate":
		button(content,"去小院的小摊",travel.bind("home_estate",show_stall))
		return
	var stock := Model.items_at(snapshot(),"stall")
	var customer_busy := story_owns_actor(["npc_bear_uncle","resident_a","resident_c"][mini(int(s.served),2)])
	if customer_busy: label(content,"这位顾客正在参加当前故事。营业记录会保留，可以稍后继续，或先补货、布置。",18)
	for id: String in stock:
		var item: Dictionary = snapshot().items[id]
		var box := card(item.design.name,"手作价 %d 叶币" % int(C.RECIPES[item.design.recipe].sale))
		if s.open and int(s.served) < 3 and not customer_busy:
			var customer: String = ["熊叔","阿梨","米洛"][int(s.served)]
			label(box,"%s：我想要一件%s，可以介绍给我吗？" % [customer,C.RECIPES[item.design.recipe].name],18)
			button(box,"介绍作品并确认成交",confirm.bind("%s 想买「%s」" % [customer,item.design.name],"交付后获得 %d 叶币，作品保留当前外观。" % int(C.RECIPES[item.design.recipe].sale),"sell",{"id":id,"room":game.room},show_stall))
		button(box,"撤下陈列",func():
			if transact("store",{"id":id}).ok: show_stall()
		)
	var actions := row()
	if not s.open: button(actions,"开始营业",func():
		if transact("stall_open",{"room":game.room}).ok: show_stall()
	,stock.is_empty() or customer_busy)
	else: button(actions,"收摊，保留未售作品",func():
		if transact("stall_close").ok: show_stall()
	)
	button(actions,"从仓库补货",show_inventory)
	if int(s.slots)<3: button(actions,"扩充陈列 · %d 叶币" % (24 if int(s.slots)==1 else 36),confirm.bind("增加一个陈列位？","同时展示更多作品，单件售价保持不变。","stall_expand",{},show_stall))

func show_community() -> void:
	if not screen("邻里作品角","花婆婆留下了基础展台。借出画框、花瓶或小凳，就能让邻居看到自己的作品。"): return
	for id: String in Model.items_at(snapshot(),"community"):
		label(content,"正在展示「%s」" % snapshot().items[id].design.name)
		button(content,"查看作品",show_item.bind(id))
	button(content,"从仓库选择作品",show_inventory)
	button(content,"邀请朋友来看",show_visitors)

func show_memories() -> void:
	if not screen("生活回忆","留住一起动手、分享和相聚的小日子。","回忆"): return
	var memories: Array = snapshot().memories.duplicate()
	memories.reverse()
	if memories.is_empty(): label(content,"把一件作品放进生活，第一段共同经历会留在这里。")
	for memory: Dictionary in memories:
		label(content,memory.text,18)
		var image_path := str(memory.get("image_path",""))
		if not image_path.is_empty() and FileAccess.file_exists(image_path):
			var preview := TextureRect.new()
			preview.texture=ImageTexture.create_from_image(Image.load_from_file(image_path))
			preview.custom_minimum_size=Vector2(300,200)
			preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			content.add_child(preview)
			button(content,"用这张照片设计画框",func():
				var d:=C.blank_design("frame")
				d.name="我们的生活合照"
				d.keepsake=image_path
				edit("",d)
			)
	for id: String in snapshot().items:
		var item: Dictionary = snapshot().items[id]
		if item.where in ["gifted","sold","delivered"]:
			var box := card("%s · 第 %d 版" % [item.design.name,int(item.design.version)],"现在在 %s 那里" % C.FRIENDS.get(item.recipient,item.recipient))
			thumbnail(box,item.design)

func show_visitors() -> void:
	if not screen("请朋友来坐坐","在客厅、小院或邻里作品角，先摆好作品并留出走近的位置。"): return
	for friend: String in C.FRIENDS:
		button(content,"邀请 "+C.FRIENDS[friend],invite.bind(friend),not C.known_friend(state.data,friend))
	if not snapshot().visit.is_empty() and snapshot().visit.status != "done":
		if snapshot().visit.status == "using":
			button(content,"一起拍张照片",take_photo,snapshot().visit.has("photo_path"))
		button(content,"继续这次来访",resume_visit)
		button(content,"结束来访",func():
			if transact("visit_end").ok:
				clear_visitor()
				show_home()
		)

func take_photo() -> void:
	var visit: Dictionary = snapshot().visit
	if visit.is_empty() or visit.status != "using" or game.room != visit.room or not is_instance_valid(_visit_actor):
		ui.notify("先继续这次来访，和朋友站在作品旁，再一起拍照。")
		return
	if DisplayServer.get_name()=="headless": return
	game._close()
	game.capturing_photo=true
	var old_position: Vector3 = game.camera.position
	var old_rotation: Vector3 = game.camera.rotation
	var old_size: float = game.camera.size
	var focus: Vector3 = (_visit_actor.position+game.player.position)/2+Vector3(0,0.8,0)
	game.camera.position=focus+game.camera_offset
	game.camera.look_at(focus)
	game.camera.size=7
	ui.root.hide()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var directory := "user://creation-photos/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory+state.save_path.get_file().get_basename()+"-"+str(visit.get("id","visit"))+".png"
	var error := image.save_png(ProjectSettings.globalize_path(path))
	game.camera.position=old_position
	game.camera.rotation=old_rotation
	game.camera.size=old_size
	ui.root.show()
	game.capturing_photo=false
	if error != OK: ui.notify("照片暂时无法保存，来访和作品仍然保留。"); return
	if transact("photo",{"room":game.room,"path":path}).ok:
		ui.notify("合照已收入生活回忆，可以装进自己的画框。")
		show_memories()

func _state_changed() -> void:
	if _refresh_queued: return
	_refresh_queued = true
	call_deferred("refresh_world")

func room_changed() -> void:
	clear_visitor()
	clear_customer()
	_last_world_signature = ""
	await refresh_world()

func prepare_room_change() -> void:
	clear_visitor()
	clear_customer()
	for child: Node in world_items.get_children():
		world_items.remove_child(child)
		child.queue_free()
	_last_world_signature=""

func refresh_world() -> void:
	_refresh_queued = false
	if not is_instance_valid(game) or not is_instance_valid(world_items): return
	if game.loading_room: return
	var signature: String = str(game.room)+str(snapshot().started)
	for id: String in snapshot().items:
		var item: Dictionary = snapshot().items[id]
		if item.where in ["placed","community","stall","gifted"]: signature += id + JSON.stringify(item)
	signature += JSON.stringify(snapshot().stall)
	if signature == _last_world_signature: return
	_last_world_signature = signature
	var had_colliders := not world_items.find_children("*", "CollisionObject3D", true, false).is_empty()
	for child: Node in world_items.get_children():
		world_items.remove_child(child)
		child.queue_free()
	for entry: Dictionary in game.interactions.duplicate():
		if str(entry.get("id", "")).begins_with("creation:"): game.interactions.erase(entry)
	for id: String in snapshot().items:
		var item: Dictionary = snapshot().items[id]
		var pos := Vector3.ZERO
		var visible_here := false
		if item.where == "placed" and item.room == game.room:
			pos = Vector3(item.position[0],item.position[1],item.position[2])
			visible_here = true
		elif item.where == "community" and game.room == "landmark_F":
			pos = community_position()
			visible_here = true
		if not visible_here: continue
		var visual := Visual.build(item.design,true,item.lit)
		visual.name = id
		visual.position = pos
		visual.rotation_degrees.y = int(item.rotation)
		world_items.add_child(visual)
		add_interaction("creation:item:"+id,item.design.name,pos)
	if snapshot().started:
		if game.room in ["home","home_estate"]:
			var pos: Vector3 = game.metadata.get("spawn", Vector3.ZERO) + Vector3(2.5,0,-2.0)
			add_interaction("creation:home","生活工坊",pos)
		if game.room == "home_estate": build_stall()
		if game.room == "landmark_F":
			var pos := community_position()
			var base := Visual.box(world_items,Vector3(2.6,0.08,2),pos-Vector3(0,0.04,0),Color("e6d5ac"))
			base.name = "CommunityCorner"
			add_interaction("creation:community","邻里作品角",pos+Vector3(1.5,0,0))
		for material: String in C.MATERIALS:
			if C.MATERIALS[material].room == game.room:
				var offset := float(C.MATERIALS.keys().find(material)) * 0.8
				var pos: Vector3 = game.metadata.get("spawn", Vector3.ZERO)+Vector3(-2.5-offset*0.3,0,-1.8)
				Visual.cylinder(world_items,0.25,0.25,pos+Vector3(0,0.12,0),Color("9fbb7d"))
				add_interaction("creation:material:"+material,str(C.MATERIALS[material].name)+"材料点",pos)
	game.feedback.bind_interactions(game.interactions)
	var has_colliders := not world_items.find_children("*", "CollisionObject3D", true, false).is_empty()
	if had_colliders or has_colliders:
		game.navigation_cache.erase(game.room)
		if not game.loading_room and game.nav_ready:
			await get_tree().physics_frame
			if not game.loading_room: await game._build_navigation()

func add_interaction(id: String, title: String, pos: Vector3) -> void:
	game.interactions.append({"id":id,"label":title,"position":pos,"radius":2.4,"type":"creation"})

func community_position() -> Vector3:
	return game.metadata.get("spawn",Vector3.ZERO)+Vector3(3,0,-3)

func stall_position() -> Vector3:
	return game.metadata.get("spawn",Vector3.ZERO)+Vector3(-3,0,-3)

func build_stall() -> void:
	var pos := stall_position()
	var d := C.blank_design("stand")
	d.color = 9
	d.text = "手作小摊"
	var stall := Visual.build(d)
	stall.position = pos
	world_items.add_child(stall)
	var index := 0
	for id: String in Model.items_at(snapshot(),"stall"):
		var item := Visual.build(snapshot().items[id].design)
		item.scale = Vector3.ONE*0.4
		item.position = pos+Vector3(-0.45+index*0.45,1,0)
		world_items.add_child(item)
		index+=1
	add_interaction("creation:stall","我的手作小摊",pos+Vector3(0,0,1.3))
	if snapshot().stall.open and int(snapshot().stall.served)<3:
		var actor_id: String = ["npc_bear_uncle","resident_a","resident_c"][int(snapshot().stall.served)]
		if story_owns_actor(actor_id): clear_customer(); return
		if is_instance_valid(_customer) and _customer.character_id != actor_id: clear_customer()
		if not is_instance_valid(_customer):
			_customer = game.living.get_actor(actor_id)
			_customer_owned = not is_instance_valid(_customer)
			if _customer_owned: _customer = game.living.spawn_actor(actor_id,game.metadata.get("spawn",Vector3.ZERO),{"validate_position":false})
			if is_instance_valid(_customer):
				_customer_origin = _customer.transform
				_customer.set_path(actor_path(_customer.position,pos+Vector3(0,0,1.5)))
	else: clear_customer()

func clear_customer() -> void:
	if is_instance_valid(_customer) and game.living.get_actor(_customer.character_id) == _customer:
		if _customer_owned: game.living.remove_actor(_customer.character_id)
		else:
			_customer.set_path(PackedVector3Array())
			_customer.play_action("idle")
			_customer.transform = _customer_origin
	_customer=null
	_customer_owned=false

func handle_action(id: String) -> bool:
	if id == "creation" or id == "creation:home": show_home(); return true
	if id == "creation:stall": show_stall(); return true
	if id == "creation:community": show_community(); return true
	if id == "creation:teach": teach(); return true
	if id == "creation:materials": show_materials(); return true
	if id.begins_with("creation:item:"): show_item(id.trim_prefix("creation:item:")); return true
	if id.begins_with("creation:material:"): show_materials(); return true
	return false

func start_placement(id: String) -> void:
	if not before_close(): return
	if game.room not in ["home","home_estate"]: await game.change_room("home")
	var item: Dictionary = snapshot().items[id]
	_placement_id = id
	_rotation = int(item.rotation)
	cursor_pos = game.player.position + Vector3(2,0,0)
	if item.where == "placed" and item.room == game.room: cursor_pos = Vector3(item.position[0],item.position[1],item.position[2])
	ui._begin("creation_place","decorate")
	ui.modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui._heading("摆放「%s」" % item.design.name,"点击地面选位置 · 方向键微调 · R 旋转 · Enter 确认 · Esc 暂停")
	active = true
	game.player.locked = true
	_ghost = Visual.build(item.design)
	add_child(_ghost)
	_place_hint = label(ui.panel_box,"请选择位置",18)
	var actions := row(ui.panel_box)
	for entry: Array in [["←",Vector3(-0.5,0,0)],["→",Vector3(0.5,0,0)],["↑",Vector3(0,0,-0.5)],["↓",Vector3(0,0,0.5)]]:
		button(actions,entry[0],func(): cursor_pos += entry[1]; update_ghost())
	button(actions,"转 90°",func(): _rotation=posmod(_rotation+90,360); update_ghost())
	button(actions,"放在这里",place)
	button(actions,"暂不摆放",show_inventory)
	update_ghost()

func close_placement() -> void:
	active = false
	if is_instance_valid(_ghost): _ghost.queue_free(); _ghost=null

func update_ghost() -> void:
	cursor_pos.x = snappedf(cursor_pos.x,0.5)
	cursor_pos.z = snappedf(cursor_pos.z,0.5)
	if is_instance_valid(_ghost):
		_ghost.position = cursor_pos
		_ghost.rotation_degrees.y = _rotation
	if is_instance_valid(_place_hint):
		var reason := placement_error(_placement_id,cursor_pos,_rotation)
		_place_hint.text = reason if not reason.is_empty() else "这里放得下，朋友也能走近。"

func placement_error(id: String, pos: Vector3, rotation_value: int) -> String:
	if not pos.is_finite() or not game.player.bounds.grow(-1.2).has_point(Vector2(pos.x,pos.z)): return "请放在房间或小院范围里。"
	var recipe: String = snapshot().items[id].design.recipe
	var footprint := Visual.footprint(recipe)
	if posmod(rotation_value,180)==90: footprint = Vector3(footprint.z,footprint.y,footprint.x)
	var rect := Rect2(Vector2(pos.x-footprint.x/2,pos.z-footprint.z/2),Vector2(footprint.x,footprint.z))
	for entry: Dictionary in game.interactions:
		if str(entry.id).begins_with("creation:"): continue
		var point: Vector3 = entry.get("position",Vector3.ZERO)
		if rect.grow(1.2).has_point(Vector2(point.x,point.z)): return "这里靠近门口或活动位置，请留出通道。"
	for other_id: String in snapshot().items:
		var other: Dictionary = snapshot().items[other_id]
		if other_id == id or other.where != "placed" or other.room != game.room or other.design.recipe == "rug" or recipe == "rug": continue
		var size := Visual.footprint(other.design.recipe)
		if int(other.rotation)%180 == 90: size = Vector3(size.z,size.y,size.x)
		var other_rect := Rect2(Vector2(other.position[0]-size.x/2,other.position[2]-size.z/2),Vector2(size.x,size.z))
		if rect.grow(0.15).intersects(other_rect): return "与「%s」重叠了，请挪开一点。" % other.design.name
	var probe := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = footprint*Vector3(0.9,0.8,0.9)
	probe.shape=box
	probe.transform.origin=pos+Vector3(0,footprint.y/2+0.1,0)
	probe.collision_mask=1
	var old := world_items.get_node_or_null(NodePath(id))
	if old:
		var exclusions: Array[RID] = []
		for body: Node in old.find_children("*","StaticBody3D",true,false): exclusions.append((body as StaticBody3D).get_rid())
		probe.exclude = exclusions
	if not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(): return "这里已有家具或墙面，请换一个位置。"
	var front := pos+Vector3(0,0,1.4).rotated(Vector3.UP,deg_to_rad(rotation_value))
	var cell := Vector2i(roundi(front.x/game.NAV_CELL),roundi(front.z/game.NAV_CELL))
	if not game.navigation.is_in_boundsv(cell) or game.navigation.is_point_solid(cell): return "作品前面需要留出朋友走近的位置。"
	for legacy: Dictionary in state.data.v4.get("free_decor_placed",{}).get(game.room,[]):
		if str(legacy.id).contains("rug") or recipe == "rug": continue
		if rect.grow(0.7).has_point(Vector2(float(legacy.x),float(legacy.z))): return "这里已有原来的家具，请为它留出位置。"
	if not preserves_paths(rect,front): return "这会挡住房间的通路，请往边上挪一挪。"
	return ""

func legacy_placement_error(item_id: String, pos: Vector3) -> String:
	if item_id.contains("rug"): return ""
	for item: Dictionary in snapshot().items.values():
		if item.where != "placed" or item.room != game.room or item.design.recipe == "rug": continue
		var extent := Visual.footprint(item.design.recipe)
		var rect := Rect2(Vector2(item.position[0]-extent.x/2,item.position[2]-extent.z/2),Vector2(extent.x,extent.z)).grow(0.8)
		if rect.has_point(Vector2(pos.x,pos.z)): return "这里已经摆了「%s」，请换个位置，或先把作品收好。" % item.design.name
	return ""

func preserves_paths(rect: Rect2, front: Vector3) -> bool:
	var nav := AStarGrid2D.new()
	nav.region = game.navigation.region
	nav.cell_size = game.navigation.cell_size
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(nav.region.position.x,nav.region.end.x):
		for z in range(nav.region.position.y,nav.region.end.y):
			var cell := Vector2i(x,z)
			nav.set_point_solid(cell,game.navigation.is_point_solid(cell) or rect.grow(0.35).has_point(Vector2(x*game.NAV_CELL,z*game.NAV_CELL)))
	var from := Vector2i(roundi(game.player.position.x/game.NAV_CELL),roundi(game.player.position.z/game.NAV_CELL))
	if not nav.is_in_boundsv(from) or nav.is_point_solid(from): return false
	var endpoints: Array[Vector3] = [front]
	for entry: Dictionary in game.interactions:
		if entry.has("destination"): endpoints.append(entry.position)
	for point: Vector3 in endpoints:
		var cell := Vector2i(roundi(point.x/game.NAV_CELL),roundi(point.z/game.NAV_CELL))
		if not game.navigation.is_in_boundsv(cell): continue
		if game.navigation.is_point_solid(cell): cell=game._nearest_walkable_cell(cell,point)
		if not game.navigation.is_in_boundsv(cell): continue
		if not game.navigation.get_id_path(from,cell).is_empty() and (not nav.is_in_boundsv(cell) or nav.is_point_solid(cell) or nav.get_id_path(from,cell).is_empty()): return false
	return true

func place() -> void:
	var reason := placement_error(_placement_id,cursor_pos,_rotation)
	if not reason.is_empty(): ui.notify(reason); return
	var result := transact("place",{"id":_placement_id,"room":game.room,"position":[cursor_pos.x,cursor_pos.y,cursor_pos.z],"rotation":_rotation})
	if result.ok:
		close_placement()
		game._close()
		ui.notify("作品已经摆好。走近它，可以使用、收纳或邀请朋友。")

func handle_input(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: close_placement(); show_inventory()
			KEY_ENTER, KEY_KP_ENTER: place()
			KEY_R: _rotation=posmod(_rotation+90,360)
			KEY_LEFT,KEY_A: cursor_pos.x-=0.5
			KEY_RIGHT,KEY_D: cursor_pos.x+=0.5
			KEY_UP,KEY_W: cursor_pos.z-=0.5
			KEY_DOWN,KEY_S: cursor_pos.z+=0.5
			_: return false
		update_ghost()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ui.panel.get_global_rect().has_point(event.position): return false
		var origin: Vector3 = game.camera.project_ray_origin(event.position)
		var direction: Vector3 = game.camera.project_ray_normal(event.position)
		var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*300,4)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): cursor_pos = hit.position
		elif absf(direction.y)>0.01: cursor_pos=origin-direction*(origin.y/direction.y)
		update_ghost()
		return true
	return false

func invite(friend: String) -> void:
	if story_owns_actor(friend): ui.notify("这位朋友正在参加当前故事，可以先邀请另一位，或稍后再来。"); return
	if game.room not in ["home","home_estate","landmark_F"]: ui.notify("回到家或邻里作品角，再请朋友过来。"); return
	if find_visit_work().is_empty(): ui.notify("先摆出一件作品，并在前面留出空间。"); return
	if not transact("visit_start",{"id":friend,"room":game.room}).ok: return
	resume_visit()

func story_owns_actor(friend: String) -> bool:
	var checker := Memories.new()
	var busy: bool = checker.task_owns_actor(friend,state.journey_snapshot())
	checker.free()
	return busy

func find_visit_work() -> String:
	var chosen := ""
	for id: String in snapshot().items:
		var item: Dictionary = snapshot().items[id]
		if (item.where=="placed" and item.room==game.room) or (item.where=="community" and game.room=="landmark_F"):
			chosen=id
			if item.design.recipe=="stool": return id
	var original: Array = state.data.v4.get("free_decor_placed",{}).get(game.room,[])
	for index in range(original.size()):
		var id := "legacy:%s:%d" % [game.room,index]
		var work := Model.visit_work(state.data,id)
		if work.is_empty(): continue
		if work.design.recipe=="stool": return id
		if chosen.is_empty(): chosen=id
	return chosen

func resume_visit() -> void:
	var visit: Dictionary = snapshot().visit
	if visit.is_empty() or visit.status == "done": return
	if game.room != visit.room: await game.change_room(visit.room)
	_visit_target = find_visit_work()
	if _visit_target.is_empty(): ui.notify("先放好一件作品，再继续来访。"); return
	if story_owns_actor(visit.friend): ui.notify("朋友正在参加当前故事，稍后再继续这次来访。"); return
	clear_visitor()
	_visit_actor = game.living.get_actor(visit.friend)
	_visitor_owned = not is_instance_valid(_visit_actor)
	if _visitor_owned: _visit_actor = game.living.spawn_actor(visit.friend,game.metadata.get("spawn",Vector3.ZERO),{"validate_position":false})
	if not is_instance_valid(_visit_actor): ui.notify("朋友暂时没能到达，请稍后继续。"); return
	_visitor_origin = _visit_actor.transform
	var item := Model.visit_work(state.data,_visit_target)
	var target := community_position() if item.where=="community" else Vector3(item.position[0],item.position[1],item.position[2])
	var front := target+Vector3(0,0,1.4).rotated(Vector3.UP,deg_to_rad(int(item.rotation)))
	_visit_front=front
	var path := actor_path(_visit_actor.position,front)
	if path.is_empty(): ui.notify("作品前的路线被挡住了，挪一挪家具再邀请。"); clear_visitor(); return
	game._close()
	_visit_actor.set_path(path)
	_visit_elapsed=0
	ui.notify("%s 来了，正在走向「%s」。" % [C.FRIENDS[visit.friend],item.design.name])

func actor_path(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	var from := Vector2i(roundi(from_pos.x/game.NAV_CELL),roundi(from_pos.z/game.NAV_CELL))
	var to := Vector2i(roundi(to_pos.x/game.NAV_CELL),roundi(to_pos.z/game.NAV_CELL))
	if not game.navigation.is_in_boundsv(from) or not game.navigation.is_in_boundsv(to) or game.navigation.is_point_solid(to): return path
	if game.navigation.is_point_solid(from): from = game._nearest_walkable_cell(from,from_pos)
	for point: Vector2 in game.navigation.get_point_path(from,to):
		var cell := Vector2i(roundi(point.x/game.NAV_CELL),roundi(point.y/game.NAV_CELL))
		path.append(Vector3(point.x,float(game.nav_heights.get(cell,0)),point.y))
	return path

func _process(delta: float) -> void:
	if not is_instance_valid(_visit_actor) or _visit_target.is_empty(): return
	if game.loading_room or snapshot().visit.is_empty() or game.room != snapshot().visit.room: clear_visitor(); return
	if not _visit_actor.world_running: return
	_visit_elapsed+=delta
	if _visit_elapsed>45:
		ui.notify("朋友暂时走不过去，调整作品前的空间后可以继续来访。")
		clear_visitor()
		return
	if not _visit_actor.motion_path.is_empty(): return
	var item := Model.visit_work(state.data,_visit_target)
	if item.is_empty(): clear_visitor(); return
	var pos := community_position() if item.where=="community" else Vector3(item.position[0],item.position[1],item.position[2])
	if Vector2(_visit_actor.position.x-_visit_front.x,_visit_actor.position.z-_visit_front.z).length()>0.75:
		ui.notify("朋友还没能走到作品前，挪一挪家具后可以继续来访。")
		clear_visitor()
		return
	if item.design.recipe=="stool":
		_visit_actor.position = pos
		_visit_actor.face(pos+Vector3(0,0,2).rotated(Vector3.UP,deg_to_rad(int(item.rotation))))
		_visit_actor.visual.rotation.y=_visit_actor._desired_yaw
		_visit_actor.sit_at_height(0.63)
	else:
		_visit_actor.look_at(Vector3(pos.x,_visit_actor.position.y,pos.z),Vector3.UP)
		_visit_actor.play_action("talk")
	if snapshot().visit.status=="arriving":
		var result := transact("visit_used",{"id":_visit_target})
		if result.ok: ui.notify("%s：我%s了你做的「%s」，这里真适合一起待一会儿。" % [C.FRIENDS[snapshot().visit.friend],"坐上" if item.design.recipe=="stool" else "看见",item.design.name])
	_visit_target=""

func clear_visitor() -> void:
	if is_instance_valid(_visit_actor) and game.living.get_actor(_visit_actor.character_id) == _visit_actor:
		if _visitor_owned: game.living.remove_actor(_visit_actor.character_id)
		else:
			_visit_actor.set_path(PackedVector3Array())
			_visit_actor.play_action("idle")
			_visit_actor.transform=_visitor_origin
	_visit_actor=null
	_visitor_owned=false
