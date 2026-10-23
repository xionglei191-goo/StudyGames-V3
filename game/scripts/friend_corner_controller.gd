extends Node
## A playable U2 wish: a visible reward, editable keepsakes and a remembered invitation.
const Progress = preload("res://scripts/friend_corner_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
const Board = preload("res://ui/friend_corner_board.gd")
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
var journey: Node
var game: Node3D
var ui: CanvasLayer
var content: Dictionary = {}
var board: Control
var selected := ""
var mode := "wish"
var selected_label: Label
var read_button: Button
var store_button: Button
var draft_status: Label
var style_buttons: Dictionary = {}

func setup(owner: Node) -> void:
	journey = owner
	game = owner.game
	ui = owner.ui
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/friend_corner.json"))

func state() -> Dictionary:
	return journey.snapshot().p2.friend_corner

func commit(event: Dictionary) -> bool:
	event.room = game.room
	return State.journey_p2_event(event)

func _open(title: String, subtitle: String, kind: String = "map") -> bool:
	if not game._prepare_screen(): return false
	ui._begin("friend_corner",kind)
	ui._heading(title,subtitle)
	return true

func _text(parent: Node, value: String, font_size: int = 20, muted: bool = false) -> Label:
	var label: Label = ui.label(value,font_size,Style.MUTED if muted else Style.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, callback: Callable, primary: bool = false, node_name: String = "") -> Button:
	var button: Button = ui.button(value,"",primary,Vector2(0,46))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not node_name.is_empty(): button.name = node_name
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	return row

func _board_and_sidebar(editing: bool, goal: bool) -> VBoxContainer:
	var body := _row(ui.panel_box)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board = Board.new()
	board.name = "FriendCornerBoard"
	body.add_child(board)
	var snapshot: Dictionary = journey.snapshot()
	board.setup(state(),str(snapshot.u1.photo.details.get("image_path","")),snapshot.u1.photo.created,content.replies,editing,goal)
	board.placement_requested.connect(_place)
	board.selection_changed.connect(_select)
	board.reply_opened.connect(func(recipient: String): show_reply(recipient))
	var sidebar := VBoxContainer.new()
	sidebar.name = "CornerSidebar"
	sidebar.custom_minimum_size.x = 228
	sidebar.add_theme_constant_override("separation",10)
	body.add_child(sidebar)
	return sidebar

func show_wish(view: String = "wish") -> void:
	mode = view
	if not _open("回信来啦！" if view == "reward" else "我的朋友角","我的小岛心愿单 · 把一起做过的事留在家里"): return
	var corner := state()
	var snapshot: Dictionary = journey.snapshot()
	var owned := Progress.owns_replies(corner)
	var sidebar := _board_and_sidebar(false,not owned)
	_text(sidebar,"合照旁边，留两个位置给朋友的回信。",23)
	_text(sidebar,"合照 · "+("已收好" if snapshot.u1.photo.created else "在欢迎会留下"),19,true)
	_text(sidebar,"邀请 · 已寄出 %d / 2" % snapshot.p2.mail.size(),19,true)
	_text(sidebar,"回信 · "+("已收到两封" if owned else "送出邀请后收到"),19,true)
	if owned:
		_text(sidebar,"墙上挂着 %d 封" % Progress.placed_count(corner.layout),19)
		_text(sidebar,"点开回信读一读，也可以再去见见朋友。",17,true)
		_button(sidebar,"去见 Lingling",visit_friend.bind("textbook_lingling"),false,"CornerVisitLingling")
		_button(sidebar,"去见 Tim",visit_friend.bind("textbook_tim"),false,"CornerVisitTim")
	else:
		_text(sidebar,"这是心愿预览。可以请朋友陪你完成每一步。",17,true)
	var actions := _row(ui.panel_box)
	if owned:
		_button(actions,"接着上次的试摆" if not corner.draft.is_empty() else "挂起我的回信",begin_edit,true,"CornerBegin")
		_button(actions,"接着准备欢迎桌" if not snapshot.p2.chapters["3"].completed else "继续我的旅程",journey.continue_journey,false,"CornerContinue")
	else:
		_button(actions,"接着完成小心愿",journey.continue_journey,true,"CornerContinue")
	_button(actions,"先在岛上走走",game._close,false,"CornerLeave")
	_finish("CornerBegin" if owned else "CornerContinue")

func begin_edit() -> void:
	if not Progress.owns_replies(state()): show_wish(); return
	if not game._prepare_screen(): return
	if game.room != "home": await game.change_room("home")
	if commit({"kind":"corner_begin"}): show_editor()

func show_editor() -> void:
	if game.room != "home" or state().draft.is_empty(): begin_edit(); return
	mode = "editor"
	if not _open("把回信挂在喜欢的位置","试摆会自动暂存 · 确认后才挂到墙上"): return
	var sidebar := _board_and_sidebar(true,false)
	_text(sidebar,"先选一封回信，再点挂点。也可以拖过去。",21)
	selected_label = _text(sidebar,"先选一封回信",19)
	var styles := _row(sidebar)
	style_buttons.clear()
	for style: String in ["flowers","star"]:
		var button := _button(styles,"花朵信夹" if style == "flowers" else "星星信夹",_choose_style.bind(style),false,"CornerStyle_"+style)
		button.toggle_mode = true
		style_buttons[style] = button
	read_button = _button(sidebar,"读这封回信",func(): if selected in Progress.RECIPIENTS: show_reply(selected),false,"CornerRead")
	store_button = _button(sidebar,"先收进册里",func(): if selected in Progress.RECIPIENTS: _place(selected,""),false,"CornerStore")
	draft_status = _text(sidebar,"",17,true)
	var actions := _row(ui.panel_box)
	_button(actions,"确认挂好",confirm_layout,true,"CornerConfirm")
	_button(actions,"下次接着摆",game._close,false,"CornerPause")
	_button(actions,"放弃这次试摆",cancel_layout,false,"CornerCancel")
	_refresh_editor()
	_finish("CornerConfirm")

func _select(recipient: String) -> void:
	selected = recipient
	if is_instance_valid(selected_label): selected_label.text = "已选："+str(content.replies[recipient].name)+" 的回信"
	if is_instance_valid(read_button): read_button.disabled = false
	if is_instance_valid(store_button): store_button.disabled = false

func _place(recipient: String, slot: String) -> void:
	selected = recipient
	if commit({"kind":"corner_place","recipient":recipient,"slot":slot}):
		_refresh_editor()
		ui.notify("试摆已暂存；确认后会挂到墙上。")

func _choose_style(style: String) -> void:
	if commit({"kind":"corner_style","style":style}): _refresh_editor()

func _refresh_editor() -> void:
	var corner := state()
	if corner.draft.is_empty(): return
	if is_instance_valid(board):
		board.selected = selected
		board.update_layout(corner.draft)
	for style: String in ["flowers","star"]:
		if style_buttons.has(style) and is_instance_valid(style_buttons[style]):
			style_buttons[style].set_pressed_no_signal(corner.draft.style == style)
			style_buttons[style].theme_type_variation = "PrimaryButton" if corner.draft.style == style else "Button"
	if selected in Progress.RECIPIENTS:
		_select(selected)
	else:
		read_button.disabled = true
		store_button.disabled = true
	if is_instance_valid(draft_status): draft_status.text = "试摆了 %d 封。\n收起或换位置，回信都不会丢。" % Progress.placed_count(corner.draft)

func confirm_layout() -> void:
	if not commit({"kind":"corner_confirm"}): return
	journey._build_story_props()
	show_wish("saved")
	ui.notify("两封回信都挂好了！" if Progress.placed_count(state().layout) == 2 else "这次摆放已收好；其余回信留在册里。")

func cancel_layout() -> void:
	if not commit({"kind":"corner_cancel"}): return
	show_wish()
	ui.notify("保留墙上原来的样子。")

func show_reply(recipient: String) -> void:
	if recipient not in Progress.RECIPIENTS or not Progress.owns_replies(state()): return
	var return_to_editor := mode == "editor"
	var reply: Dictionary = content.replies[recipient]
	if not _open(str(reply.name)+" 的回信","收到的一封小回忆","dialogue"): return
	_text(ui.panel_box,"\n".join(reply.lines),24)
	_button(ui.panel_box,"收好回信，继续摆" if return_to_editor else "回到朋友角",show_editor if return_to_editor else show_wish,true,"CornerReplyBack")
	_finish("CornerReplyBack")

func add_cover_editor(parent: Node) -> void:
	_text(parent,"先为两张邀请选信纸。送出后，朋友会记得它的样子。",18,true)
	var row := _row(parent)
	for index: int in Progress.RECIPIENTS.size():
		var recipient := Progress.RECIPIENTS[index]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",Style.box(Color("edf0e4"),14,12))
		row.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",8)
		panel.add_child(column)
		var header := _row(column)
		var picture := TextureRect.new()
		var chosen: String = state().invitation_styles[recipient]
		picture.texture = Content.icon("F" if chosen == "flowers" else "S",1.0) if chosen != "plain" else load("res://assets/learning/story_props_v3/envelope.png")
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(58,58)
		header.add_child(picture)
		var title := _text(header,"第一张邀请" if index == 0 else "第二张邀请",22)
		title.name = "CornerInvitationTitle_"+recipient
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var choices := _row(column)
		for style: String in Progress.STYLES:
			var button := _button(choices,str({"plain":"原色","flowers":"花朵","star":"星星"}[style]),_choose_cover.bind(recipient,style),false,"CornerCover_"+recipient+"_"+style)
			button.toggle_mode = true
			button.theme_type_variation = "PrimaryButton" if chosen == style else "Button"
			button.set_pressed_no_signal(chosen == style)

func _choose_cover(recipient: String, style: String) -> void:
	if commit({"kind":"corner_cover","recipient":recipient,"style":style}): journey.p2.show_chapter()

func decorate_invitation(card: Button, recipient: String) -> void:
	var style: String = state().invitation_styles[recipient]
	var paper := Color("f6ead0") if style == "star" else Color("e5eddf") if style == "flowers" else Style.PAPER
	card.add_theme_stylebox_override("normal",Style.box(paper,16,14))
	card.tooltip_text = str(content.covers[style])
	if style != "plain": card.icon = Content.icon("F" if style == "flowers" else "S",1.5)

func visit_friend(recipient: String) -> void:
	if recipient not in Progress.RECIPIENTS or not Progress.owns_replies(state()): return
	if not game._prepare_screen(): return
	var room: String = Progress.FRIEND_ROOMS[recipient]
	if game.room != room: await game.change_room(room)
	if await journey.p2.ensure_actor(recipient): show_friend(recipient)

func handles_actor(recipient: String) -> bool:
	if recipient not in Progress.RECIPIENTS or not Progress.owns_replies(state()) or game.room != Progress.FRIEND_ROOMS[recipient]: return false
	var snapshot: Dictionary = journey.snapshot()
	var next := Chapter.next_chapter(snapshot.p2)
	if next != 0 and Chapter.next_step(snapshot.p2,next).get("actor") == recipient: return false
	return show_friend(recipient)

func show_friend(recipient: String, told_about_display: bool = false) -> bool:
	if recipient not in Progress.RECIPIENTS or game.living.get_actor(recipient) == null: return false
	if not game._prepare_screen(): return false
	if not commit({"kind":"corner_friend_seen","recipient":recipient}): return false
	journey.active_actor_ids = [recipient]
	game.conversation_position = game.living.get_actor(recipient).position
	game.living.play_actor_action(recipient,"talk")
	var reply: Dictionary = content.replies[recipient]
	var cover: String = content.covers[state().invitation_styles[recipient]]
	var text := str(reply.memory).replace("{cover}",cover)
	if told_about_display and not str(state().layout.positions[recipient]).is_empty(): text = str(reply.display_reply)
	ui._begin("friend_memory","dialogue")
	ui._heading(str(reply.name)+" 记得那封邀请","朋友之间的小回忆")
	_text(ui.panel_box,text,22)
	var actions := _row(ui.panel_box)
	if not told_about_display and not str(state().layout.positions[recipient]).is_empty():
		_button(actions,"我把你的回信挂好了",func(): show_friend(recipient,true),true,"CornerTellFriend")
	_button(actions,"回家看看朋友角",func():
		await game.change_room("home")
		show_wish()
	,false,"CornerBackHome")
	_button(actions,"先和朋友道别",game._close,false,"CornerGoodbye")
	_finish("CornerTellFriend" if not told_about_display and not str(state().layout.positions[recipient]).is_empty() else "CornerBackHome")
	return true

func build_world(parent: Node3D, at: Vector3) -> void:
	var snapshot: Dictionary = journey.snapshot()
	var root := Node3D.new()
	root.name = "FriendCorner"
	root.set_meta("committed_revision",int(state().revision))
	root.set_meta("letters_displayed",Progress.placed_count(state().layout))
	root.set_meta("draft_visible",false)
	root.set_meta("layout",state().layout.duplicate(true))
	parent.add_child(root)
	var viewport := SubViewport.new()
	viewport.name = "KeepsakeCanvas"
	viewport.size = Vector2i(1000,560)
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var picture := Board.new()
	picture.theme = Style.make_theme()
	viewport.add_child(picture)
	picture.size = Vector2(1000,560)
	picture.setup(state(),str(snapshot.u1.photo.details.get("image_path","")),snapshot.u1.photo.created,content.replies,false,false,true)
	var display := Sprite3D.new()
	display.name = "LettersAndPhoto"
	display.texture = viewport.get_texture()
	display.pixel_size = 0.0038
	display.position = at+Vector3(0,2.1,0)
	display.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(display)
	for offset: float in [-1.0,1.0]:
		var leg := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.12,1.2,0.12)
		leg.mesh = shape
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("aa8053")
		leg.material_override = material
		leg.position = at+Vector3(offset,0.6,0)
		root.add_child(leg)
	var found := false
	for entry: Dictionary in game.interactions:
		if entry.id == "journey_friend_corner": found = true; entry.position = at
	if not found: game.interactions.append({"id":"journey_friend_corner","type":"memory","position":at,"radius":3.0,"label":"看看我的朋友角"})
	game.feedback.bind_interactions(game.interactions)

func _finish(focus_name: String = "") -> void:
	ui._layout.call_deferred()
	if not focus_name.is_empty():
		var button: Button = ui.panel_box.find_child(focus_name,true,false) as Button
		if button: ui._focus_if_current.call_deferred(button.get_instance_id())
