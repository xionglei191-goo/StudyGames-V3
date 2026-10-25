extends Node
## Optional invitations and a separate, read-only parent notebook.
const Progress = preload("res://scripts/review_progress.gd")
const Observations = preload("res://scripts/parent_observations.gd")
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const FRIEND_NAMES := {"npc_rabbit_gardener":"兔兔","npc_bear_uncle":"熊叔","textbook_anne":"Anne"}
var journey: Node
var game: Node3D
var ui: CanvasLayer
var current_id := ""
var parent_filter := "all"
var parent_page := 0
var travelling := false

func setup(owner: Node) -> void:
	journey = owner
	game = owner.game
	ui = owner.ui

func _open(id: String, title: String, subtitle: String) -> bool:
	if not game._prepare_screen(): return false
	ui._begin(id,"map")
	ui._heading(title,subtitle)
	return true

func _text(value: String, parent: Node, size: int = 21, color: Color = Style.INK) -> Label:
	var label: Label = ui.label(value,size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(label: String, name_id: String, callback: Callable, parent: Node, primary: bool = false) -> Button:
	var button: Button = ui.button(label,"",primary,Vector2(0,48))
	button.name = name_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	return row

func _scroll(name_id: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_id
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	ui.panel_box.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	var surface := Style.box(Color("f2f1e3"),12,18)
	surface.shadow_size = 0
	panel.add_theme_stylebox_override("panel",surface)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	return box

func _end(first: Button = null) -> void:
	ui._layout.call_deferred()
	if first: ui._focus_if_current.call_deferred(first.get_instance_id())

func show_invites() -> void:
	if not game._prepare_screen() or not State.review_refresh(): return
	if not _open("review_invites","朋友捎来的小邀请","选一件一起做，也可以继续自己的旅程"): return
	_text("每段旅程最多摆出两份邀请。不赶时间，晚些来，朋友也一样欢迎。",ui.panel_box,20)
	var box := _scroll("RevisitInvitations")
	var ids: Array = State.data.reviews.batch.ids
	var first: Button
	if ids.is_empty():
		var card := _card(box)
		_text("今天先好好玩",card,26)
		_text("先完成一处字母体验，或继续欢迎朋友的故事。隔开一个生活活动，或过一段真实时间，再来看看邀请。",card)
		_text("已经收好的邀请不会变成欠下的任务。",card,18,Style.MUTED)
	for id: String in ids:
		var opportunity: Dictionary = State.data.reviews.opportunities[id]
		var context := Progress.context(opportunity)
		var spec: Dictionary = Progress.catalog()[opportunity.target]
		var card := _card(box)
		_text(str(FRIEND_NAMES.get(context.actor,"朋友"))+" · "+context.title,card,25)
		_text("和朋友整理一张字母旅行卡" if spec.group=="letters" else "在生活里用一用熟悉的话",card,21)
		if opportunity.result.is_empty():
			_text("上次的小提示还留在卡片里，可以从这里接着玩。" if opportunity.paused or opportunity.started_at>0 else "朋友等你一起看看，想试试就来。",card,18,Style.MUTED)
			var button := _button("接着这次相遇" if opportunity.started_at>0 else "去见这位朋友","RevisitGo_"+id,func(): begin(id),card,true)
			if first==null: first = button
		else:
			_text("这次相遇已经收好了。" if opportunity.result!="skipped" else "这次先放一放，朋友知道啦。",card,20,Style.SAGE)
	var footer := _row(ui.panel_box)
	var back := _button("继续我的旅程","RevisitContinue",journey.continue_journey,footer)
	_button("回到旅行册","RevisitBook",journey.show_hub,footer)
	_end(first if first else back)

func begin(id: String) -> void:
	if travelling or not State.data.reviews.opportunities.has(id): return
	if not game._prepare_screen(): return
	travelling = true
	current_id = id
	var context := Progress.context(State.data.reviews.opportunities[id])
	ui.close_panel()
	if game.room!=context.room: await game.change_room(context.room)
	if not await journey.p2.ensure_actor(context.actor):
		travelling = false
		return
	travelling = false
	if State.review_event({"kind":"begin","id":id,"room":game.room}): show_task()

func event(kind: String, extra: Dictionary = {}) -> bool:
	extra.kind = kind
	extra.id = current_id
	extra.room = game.room
	return State.review_event(extra)

func show_task() -> void:
	if not State.data.reviews.opportunities.has(current_id): return
	var opportunity: Dictionary = State.data.reviews.opportunities[current_id]
	var context := Progress.context(opportunity)
	var subtitle := "和 "+str(FRIEND_NAMES.get(context.actor,"朋友"))+" 一起做一件小事"
	var prompt_text: String = context.prompt
	if Progress.catalog()[opportunity.target].group=="letters":
		subtitle = str(FRIEND_NAMES.get(context.actor,"朋友"))+" · "+prompt_text.get_slice("\n",0)
		prompt_text = prompt_text.get_slice("\n",1)
	if not _open("review_task",context.title,subtitle): return
	journey.active_actor_ids = [context.actor]
	var box := _scroll("RevisitTaskScroll")
	if not opportunity.result.is_empty():
		_text("这次相遇，收好了",box,28)
		_text(context.closing,box,23)
		_text("可以继续散步，也可以回家。",box,20,Style.MUTED)
		var row := _row(ui.panel_box)
		var done := _button("继续散步","RevisitFinish",game._close,row,true)
		_button("看看朋友的邀请","RevisitMore",show_invites,row)
		_end(done)
		return
	_text(prompt_text,box,25)
	if not str(context.stimulus).is_empty(): _text(context.stimulus,box,62)
	if not str(context.image_letter).is_empty():
		var image := TextureRect.new()
		image.name = "RevisitImage"
		image.texture = Content.icon(context.image_letter,2.0)
		image.custom_minimum_size = Vector2(128,128)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(image)
	if opportunity.help>0:
		_text(context.demo if opportunity.help==5 else context.hint,box,23,Style.SAGE)
	if not opportunity.answers.is_empty():
		_text("这次还没找到。可以看看提示，或请朋友做给你看。",box,20)
	var choices := _row(box)
	var first: Button
	for option: Dictionary in context.options:
		var button := _button(option.text,"RevisitAnswer_"+option.id,func():
			if event("answer",{"answer":option.id}): show_task()
		,choices,true)
		if first==null: first = button
	var support := _row(box)
	_button("给我一点提示","RevisitHint",func():
		if event("help",{"level":1}): show_task()
	,support)
	_button("看看朋友怎么做","RevisitDemo",func():
		if event("help",{"level":5}): show_task()
	,support)
	if opportunity.help==5:
		_button("和朋友一起看好了","RevisitDemoDone",func():
			if event("demonstrated"): show_task()
		,box,true)
	var footer := _row(ui.panel_box)
	_button("先收好，下次接着玩","RevisitPause",func():
		if event("defer"): journey.show_hub()
	,footer)
	_button("这次先不试了","RevisitSkip",func():
		if event("skip"): show_task()
	,footer)
	_end(first)

func show_parent(reset: bool = false) -> void:
	if reset: parent_page = 0; parent_filter = "all"
	if not _open("parent_observations","家长观察册","实际经历、提示与作答，分别留下记录"): return
	var data := State.snapshot()
	var overview := Observations.overview(data)
	_text("生活经历：%d / 26 处字母体验 · U1–U3 完成 %d / 3 章" % [overview.experienced,overview.chapters],ui.panel_box,22)
	_text("回访已开放 %d 类目标 · 已作答 %d 类 · 尚未作答 %d 类。旧档缺少的时间和条件保持未知。" % [overview.available,overview.attempted_targets,maxi(0,overview.available-overview.attempted_targets)],ui.panel_box,18,Style.MUTED)
	var filters := _row(ui.panel_box)
	for item: Array in [["all","全部"],["letters","字母"],["units","U1–U3"],["stories","词故事"],["legacy","旧情境课"]]:
		_button(item[1],"ParentFilter_"+item[0],func():
			parent_filter = item[0]
			parent_page = 0
			show_parent()
		,filters,item[0]==parent_filter)
	var rows := Observations.rows(data,parent_filter)
	var pages := maxi(1,int(ceil(float(rows.size())/6.0)))
	parent_page = clampi(parent_page,0,pages-1)
	var box := _scroll("ParentObservationScroll")
	if rows.is_empty():
		_text("这里还没有具体尝试记录。",box,25)
		_text("走过地点、完成布置和观看动画不会自动填成英语正确记录。可以照常继续生活活动。",box,21)
	for index: int in range(parent_page*6,mini(rows.size(),(parent_page+1)*6)):
		var row: Dictionary = rows[index]
		var card := _card(box)
		card.name = "Observation_"+str(index)
		_text(row.title,card,23)
		_text(str(Observations.RESULTS.get(row.result,"早期汇总，条件不完整"))+" · "+str(Observations.DIMENSIONS.get(row.dimension,row.dimension)),card,21,Style.SAGE)
		_text(row.detail,card,18)
		_text(Observations.timestamp(float(row.at))+" · "+row.source,card,16,Style.MUTED)
	var note := "时间来自本机，无法验证关机期间是否改过时钟；已检测到的异常记为间隔未知。书面选项不代表听说能力或长期掌握。"
	if data.reviews.clock.anomalies>0: note = "检测到 %d 次时钟跳变，受影响间隔保持未知。\n" % int(data.reviews.clock.anomalies)+note
	_text(note,ui.panel_box,16,Style.MUTED)
	var footer := _row(ui.panel_box)
	var previous := _button("上一页","ParentPrevious",func(): parent_page-=1; show_parent(),footer)
	previous.disabled = parent_page==0
	_text("%d / %d 页 · %d 条" % [parent_page+1,pages,rows.size()],footer,18)
	var next := _button("下一页","ParentNext",func(): parent_page+=1; show_parent(),footer)
	next.disabled = parent_page>=pages-1
	var back := _button("回到旅行册","ParentBack",journey.show_hub,footer,true)
	_end(back)
