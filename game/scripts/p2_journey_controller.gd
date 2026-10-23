extends Node
## P2 presentation and journeys use State's transactional events exclusively.
const Progress = preload("res://scripts/p2_progress.gd")
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
var journey: Node
var game: Node3D
var ui: CanvasLayer
var chapter_number := 2
var context := ""
var current_step: Dictionary = {}
var trial_return: Callable
var district := ""
var selected_mail := ""
var home_preview := ""
var transfer_active := false
var presented_step := ""

class MailCard extends Button:
	var recipient := ""
	func _get_drag_data(_point: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = text
		set_drag_preview(preview)
		return {"recipient":recipient}

class Mailbox extends Button:
	var recipient := ""
	var delivered: Callable
	func _can_drop_data(_point: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("recipient")
	func _drop_data(_point: Vector2, data: Variant) -> void:
		delivered.call(str(data.recipient),recipient)

func setup(owner: Node) -> void:
	journey = owner
	game = owner.game
	ui = owner.ui

func state() -> Dictionary:
	return journey.snapshot().p2

func commit(event: Dictionary) -> bool:
	event.room = game.room
	return State.journey_p2_event(event)

func _open(title: String, subtitle: String, mode: String = "map") -> bool:
	if not game._prepare_screen(): return false
	ui._begin("journey_p2",mode)
	ui._heading(title,subtitle)
	return true

func _text(value: String, font_size: int = 21) -> Label:
	var label: Label = ui.label(value,font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.panel_box.add_child(label)
	return label

func _button(label: String, callback: Callable, primary: bool = false, parent: Node = null) -> Button:
	var button: Button = ui.button(label,"",primary,Vector2(0,46))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	(parent if parent else ui.panel_box).add_child(button)
	return button

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	ui.panel_box.add_child(row)
	return row

func _end() -> void:
	ui._layout.call_deferred()

func show_home_choice() -> void:
	if not _open("给家门添一个喜欢的样子","先预览，再决定","dialogue"): return
	_text("看看花朵和星星摆在家门口的样子。也可以先不摆，之后回来再选。")
	var row := _row()
	_button("预览花朵",func(): preview_home("flowers"),false,row)
	_button("预览星星",func(): preview_home("star"),false,row)
	if not home_preview.is_empty():
		_button("就摆这个",func():
			if commit({"kind":"home_choice","choice":home_preview}):
				home_preview=""
				journey._build_story_props()
				journey.show_home()
		,true)
		_button("取消预览",func(): home_preview=""; journey._build_story_props(); show_home_choice())
	_button("稍后再选",func():
		if commit({"kind":"home_choice","choice":"later"}):
			home_preview=""
			journey._build_story_props()
			journey.show_home()
	)
	_end()

func preview_home(value: String) -> void:
	home_preview=value
	journey._build_story_props()
	journey._build_home_decoration(value)
	show_home_choice()

func show_trip() -> void:
	if not _open("今天想去哪里？","五个街区 · 一次选一到三站"): return
	var districts := _row()
	for area: Dictionary in journey.prologue.districts:
		_button(str(area.name),func(): district=str(area.id); show_trip(),district==str(area.id),districts)
	if district.is_empty(): district = str(journey.prologue.districts[0].id)
	var letters: Array = []
	for area: Dictionary in journey.prologue.districts:
		if area.id==district: letters = area.letters
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	ui.panel_box.add_child(grid)
	for raw: Variant in letters:
		var letter := str(raw)
		var record: Dictionary = journey._letter(letter)
		var completed: bool = journey.snapshot().letters[letter].experienced
		_button(letter+letter.to_lower()+" · "+str(record.anchor.chinese_image_name)+("\n已收下发现页" if completed else "\n一起去看看"),func():
			var route: Array = state().trip.duplicate()
			if route.has(letter): route.erase(letter)
			elif route.size()<3: route.append(letter)
			else: ui.notify("这次先选三站，之后再出发。" ); return
			if commit({"kind":"trip","letters":route}): show_trip()
		,state().trip.has(letter),grid)
	var route: Array = state().trip
	_text("这次的路线："+("还没有选择" if route.is_empty() else " → ".join(route)),19)
	var bottom := _row()
	if not route.is_empty(): _button("请向导陪我出发",func(): journey.travel_letter(str(state().trip[0])),true,bottom)
	_button("打开地图慢慢走",game.show_map,false,bottom)
	_button("回到旅行册",journey.show_hub,false,bottom)
	_end()

func after_letter(letter: String) -> void:
	var route: Array = state().trip.duplicate()
	if route.has(letter): route.erase(letter); commit({"kind":"trip","letters":route})

func show_recall_menu(letter: String) -> void:
	if game.room!="home" and game.room!="landmark_"+letter:
		if not game._prepare_screen(): return
		await game.change_room("home")
	if not _open("想一想这位伙伴","可选回想 · 可以随时跳过","dialogue"): return
	_text("可以试一种，也可以下次再来。是否做回想，不影响发现页和出行。")
	for item: Array in [["大小写配对","case_pair"],["看形象想字母","landmark"],["试着说字母名","letter_name"]]:
		_button(item[0],func(): start_trial("recall/"+letter+"/"+str(item[1]),func(): show_recall_menu(letter),true))
	_button("先不回想，继续旅行",journey.show_hub)
	_end()

func start_trial(value: String, return_to: Callable, again: bool = false) -> void:
	context = value
	trial_return = return_to
	if not commit({"kind":"trial_begin","context":context,"again":again}): return
	show_trial()

func _trial_event(kind: String, extra: Dictionary = {}) -> bool:
	extra.kind = kind
	extra.context = context
	extra.trial_id = state().trials[context].id
	return commit(extra)

func show_trial() -> void:
	var spec := Progress.trial_spec(context)
	var trial: Dictionary = state().trials[context]
	var optional := context.begins_with("recall/") or context=="U1-10"
	var title := str(spec.get("prompt","想起这位字母伙伴了吗？"))
	if not _open(title,"可选回想" if optional else "和朋友一起回应"): return
	if context.begins_with("recall/"):
		var parts := context.split("/")
		if parts[2]=="landmark":
			var image := TextureRect.new()
			image.texture = Content.icon(parts[1],2.0)
			image.custom_minimum_size=Vector2(180,180)
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ui.panel_box.add_child(image)
		else: _text(parts[1],64)
	if trial.completed:
		var labels := {"independent_correct":"这次自己选对了。","supported_correct":"借助帮助，也找到答案了。","demonstrated":"和向导一起看过示范了。","skipped":"这次先跳过，下次再想。","self_report_unassessed":"记录了“我试着说了”。这里没有自动判断发音。"}
		_text(str(labels.get(trial.result,"这次回应已保存。")),23)
		if not current_step.is_empty() and current_step.has("reply") and context==current_step.id: _text(current_step.reply)
		_button("继续",func(): trial_return.call(),true)
		if context.begins_with("recall/"): _button("再试一轮",func(): start_trial(context,trial_return,true))
		_end()
		return
	var level := int(trial.help)
	if level>0:
		var hint := str(spec.get("hint","看看形象和字母的轮廓，慢慢想。"))
		if level>=2:
			for option: Dictionary in spec.options:
				if option.id==spec.correct: hint+="\n向导指给你看："+str(option.text)
		if level==3: hint=str(spec.get("demo",hint))
		_text(hint,20)
	var options: Array = spec.options.duplicate(true)
	if not options.is_empty():
		for index: int in int(state().trial_sequence)%options.size(): options.append(options.pop_front())
	var row := _row()
	if str(spec.dimension)=="letter_name_self_report":
		_text("看着字母，试着说出它的名字。这里只记录你的自述。",20)
		_button("我试着说了",func(): _answer("__spoken__"),true,row)
	else:
		for option: Dictionary in options: _button(str(option.text),_answer.bind(str(option.id)),false,row)
	var help_row := _row()
	_button("小提示",func(): if _trial_event("trial_help",{"level":1}): show_trial(),false,help_row)
	_button("陪我选择",func(): if _trial_event("trial_help",{"level":2}): show_trial(),false,help_row)
	_button("完整示范",_trial_demo,false,help_row)
	if level==3: _button("看过示范，继续",func(): _answer("__demonstrated__"),true)
	if optional: _button("这次先跳过",func(): if _trial_event("trial_skip"): trial_return.call())
	_button("先休息，稍后接着来",journey.show_hub)
	_end()

func _answer(answer: String) -> void:
	if not _trial_event("trial_answer",{"answer":answer}): return
	var trial: Dictionary = state().trials[context]
	show_trial()
	if not trial.completed: ui.notify("可以再想一想，也可以请朋友提示或示范。")

func _trial_demo() -> void:
	if not _trial_event("trial_help",{"level":3}): return
	show_trial()
	var spec := Progress.trial_spec(context)
	if not str(spec.get("phrase","")).is_empty(): game.play_phrase(str(spec.phrase))
	elif context.begins_with("recall/"): journey._play_letter_audio(context.split("/")[1],"letter")

func ensure_actor(id: String) -> bool:
	if not game.living.get_actor(id):
		await get_tree().physics_frame
		game.living._spawn_from_markers([id])
	var actor: Node3D = game.living.get_actor(id)
	if not actor:
		ui.notify("朋友还没走到安全位置，稍后再来试试。")
		return false
	journey.active_actor_ids = [id]
	game.conversation_position = actor.position
	actor.face(game.player.position)
	game.living.play_actor_action(id,"talk")
	return true

func show_chapter() -> void:
	presented_step=""
	chapter_number = Progress.next_chapter(state())
	if chapter_number==0:
		journey.party.show_wish()
		return
	current_step = Progress.next_step(state(),chapter_number)
	if game.room!=current_step.room:
		if not game._prepare_screen(): return
		ui.close_panel()
		await game.change_room(current_step.room)
	if not await ensure_actor(str(current_step.actor)): return
	var chapter: Dictionary = Progress.content().chapters[str(chapter_number)]
	if not _open(str(current_step.title),"Unit %d · %s"%[chapter_number,chapter.unit_title],"map" if current_step.kind in ["mail","seats","letters"] or current_step.id=="U2-01" else "dialogue"): return
	_text(str(current_step.text),21)
	if current_step.id=="U2-01": journey.friend_corner.add_cover_editor(ui.panel_box)
	if chapter_number==2 and current_step.kind=="complete": _text("两封回信和信夹会一起收好。回家可以亲手把它们挂在合照旁边。",19)
	match str(current_step.kind):
		"question":
			_button("和朋友回应",func(): start_trial(current_step.id,complete_step),true)
		"mail": _mail_ui()
		"seats": _seats_ui()
		"letters":
			var row := _row()
			for letter: String in str(chapter.letters):
				var button := _button(letter+letter.to_lower(),func(): journey._play_letter_audio(letter,"letter"),false,row)
				button.icon=Content.icon(letter,1.0)
				button.add_theme_constant_override("icon_max_width",72)
				button.custom_minimum_size.y=105
			if chapter_number==3: _text("one 1 · two 2 · three 3 · four 4 · five 5\nsix 6 · seven 7 · eight 8 · nine 9 · ten 10",20)
			_button("收进旅行册",complete_step,true)
		_:
			if current_step.has("phrase"): _button("听听朋友怎么说",func(): game.play_phrase(current_step.phrase))
			_button(("收下回信，完成这一章" if chapter_number==2 else "收好座位卡，去布置欢迎桌") if current_step.kind=="complete" else "一起继续",complete_step,true)
	_button("先休息，稍后继续",journey.show_hub)
	presented_step=str(current_step.id)
	_end()

func complete_step() -> void:
	var finished_u2: bool = chapter_number==2 and current_step.kind=="complete"
	if commit({"kind":"chapter_step","chapter":chapter_number,"step":current_step.id}):
		journey._build_story_props()
		if finished_u2:
			presented_step=""
			journey.friend_corner.show_wish("reward")
		else: show_chapter()

func _mail_ui() -> void:
	var row := _row()
	for recipient: String in ["textbook_lingling","textbook_tim"]:
		var card := MailCard.new()
		card.recipient=recipient
		card.text=("已寄出 ✓ " if state().mail.has(recipient) else "邀请给 ")+recipient.trim_prefix("textbook_").capitalize()
		card.custom_minimum_size=Vector2(0,90)
		card.icon=load("res://assets/learning/story_props_v3/envelope.png")
		card.add_theme_constant_override("icon_max_width",78)
		card.custom_minimum_size.y=130
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		journey.friend_corner.decorate_invitation(card,recipient)
		card.disabled=state().mail.has(recipient)
		card.pressed.connect(func(): selected_mail=recipient; ui.notify("选好了邀请，再点同名信格。"))
		row.add_child(card)
	var boxes := _row()
	for recipient: String in ["textbook_tim","textbook_lingling"]:
		var box := Mailbox.new()
		box.recipient=recipient
		box.text=recipient.trim_prefix("textbook_").capitalize()+" 的信格"
		box.custom_minimum_size=Vector2(0,90)
		box.add_theme_stylebox_override("normal",Style.box(Color("e0e9dc"),12,18))
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		box.delivered=deliver_mail
		box.pressed.connect(func(): deliver_mail(selected_mail,recipient))
		boxes.add_child(box)
	if state().mail.size()==2: _button("两封都送好了",complete_step,true)

func deliver_mail(recipient: String, mailbox: String) -> void:
	if recipient.is_empty(): ui.notify("先点选一封邀请，再点信格。" ); return
	if commit({"kind":"mail","recipient":recipient,"mailbox":mailbox}): selected_mail=""; show_chapter()

func _seats_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y=180
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.panel_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns=5
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var guests: Array = ["Mingming","Dongdong","Tim","Anne"]
	for index: int in int(state().seats):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",Style.box(Color("edf1e5"),16,14))
		card.custom_minimum_size=Vector2(150,180)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		var picture := TextureRect.new()
		picture.texture=load("res://assets/learning/story_props_v3/chair.png")
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size=Vector2(90,110)
		picture.size_flags_vertical=Control.SIZE_EXPAND_FILL
		column.add_child(picture)
		var label := Label.new()
		label.text="座位 %d\n%s"%[index+1,guests[index] if index<int(current_step.seat_count) else "还没有来客"]
		label.add_theme_font_size_override("font_size",22)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		column.add_child(label)
	_text("已摆 %d 张 · 本次有 %d 位来客"%[state().seats,current_step.seat_count],20)
	var row := _row()
	_button("再摆一张",func(): if commit({"kind":"seats","count":mini(10,int(state().seats)+1)}): show_chapter(),false,row)
	_button("收起一张",func(): if commit({"kind":"seats","count":maxi(0,int(state().seats)-1)}): show_chapter(),false,row)
	_button("摆好了，数一数",complete_step,true,row)

func show_transfer() -> void:
	if not game._prepare_screen(): return
	if game.room!="landmark_F": await game.change_room("landmark_F")
	if not await ensure_actor("npc_rabbit_gardener"): return
	start_trial("U1-10",func():
		if commit({"kind":"u1_transfer"}): journey.show_hub()
	)

func show_keepsakes() -> void:
	if not _open("朋友们留下的回忆","邀请册 · 年龄卡 · 欢迎桌"): return
	var row := _row()
	for recipient: String in ["textbook_lingling","textbook_tim"]:
		var card := Label.new()
		card.text=recipient.trim_prefix("textbook_").capitalize()+"\n"+("邀请已寄出 ✓" if state().mail.has(recipient) else "还等着邀请")
		card.add_theme_font_size_override("font_size",25)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(card)
	_text("欢迎会的角色卡",23)
	for step: Dictionary in Progress.content().chapters["3"].steps:
		if step.has("age"):
			var ready: bool=state().chapters["3"].steps.has(step.id)
			_text(str(step.age_actor).trim_prefix("textbook_").capitalize()+" · "+(str(int(step.age))+" 岁" if ready else "还没有问到年龄"),20)
	_text("欢迎桌摆了 %d 张座位卡。"%int(state().seats),23)
	_text("这些是本次故事的角色卡；年龄和来客人数分别记录。",17)
	_button("继续我的旅程",journey.continue_journey,true)
	_button("回到旅行册",journey.show_hub)
	_end()
