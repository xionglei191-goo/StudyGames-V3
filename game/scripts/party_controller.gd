extends Node
## UI owns no progress: every draft and completed scene beat uses the State transaction.
const Progress = preload("res://scripts/party_progress.gd")
const Stage = preload("res://ui/party_stage.gd")
const Style = preload("res://ui/island_theme.gd")
const LINES: Array[String] = ["朋友们都坐好啦。\nHello! 欢迎来做客！","Mingming、Dongdong、Tim、Anne，\n每个人都有自己的座位。","四位朋友，四把椅子。\n谢谢你为大家准备这张欢迎桌。","Goodbye! 下次再见！\n今天的相聚，会留在小屋的回忆里。"]
var journey: Node
var game: Node3D
var ui: CanvasLayer
var stage: Control
var selected := "textbook_mingming"
var selection_label: Label
var seat_buttons: Dictionary = {}
var theme_buttons: Dictionary = {}
var guest_buttons: Dictionary = {}
var playback_active := false
var playback_paused := false
var playback_elapsed := 0.0
var playback_id := ""
var playback_step := 0
var playback_line: Label
var playback_caption: Label
var pause_button: Button
var narration: AudioStreamPlayer

func setup(owner: Node) -> void:
	journey = owner
	game = owner.game
	ui = owner.ui

func state() -> Dictionary:
	return journey.snapshot().p2.party

func commit(event: Dictionary) -> bool:
	event.room = game.room
	return State.journey_p2_event(event)

func _open(title: String, subtitle: String) -> bool:
	playback_active = false
	if not game._prepare_screen(): return false
	_stop_narration()
	ui._begin("party","map")
	ui._heading(title,subtitle)
	return true

func _text(parent: Node, value: String, font_size: int = 21, muted: bool = false) -> Label:
	var label: Label = ui.label(value,font_size,Style.MUTED if muted else Style.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, callback: Callable, primary: bool, node_name: String) -> Button:
	var button: Button = ui.button(value,"",primary,Vector2(0,46))
	button.name = node_name
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	return row

func _body(layout: Dictionary) -> VBoxContainer:
	var row := _row(ui.panel_box)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",Style.box(Color("e6eadb"),16,5))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	stage = Stage.new()
	stage.name = "PartyStagePreview"
	frame.add_child(stage)
	stage.setup(layout)
	stage.reduced_motion = ui.reduced_motion
	var scroll := ScrollContainer.new()
	scroll.name = "PartySidebarScroll"
	scroll.custom_minimum_size.x = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation",10)
	scroll.add_child(sidebar)
	return sidebar

func show_wish() -> void:
	if not _open("我们的小小欢迎桌","我的小岛心愿 · 留下相聚的回忆"): return
	var party := state()
	var ready := Progress.unlocked(journey.snapshot().p2)
	var sidebar := _body(party.layout)
	if not ready:
		_text(sidebar,"四位朋友，各有一把椅子。",24)
		_text(sidebar,"先一起准备欢迎桌，之后就能在这里挑桌布、换座位。",20,true)
		_button(sidebar,"接着准备欢迎桌",journey.continue_journey,true,"PartyContinue")
	else:
		_text(sidebar,"四位朋友的小聚会",24)
		_text(sidebar,"桌布："+Progress.theme_name(str(party.layout.theme)) if int(party.revision) > 0 else "先试摆喜欢的桌布和座位。",20)
		if Progress.watched(party):
			_text(sidebar,"相聚回忆已收好。\n"+Progress.theme_name(str(party.memory.layout.theme))+"旁，四位朋友一起说过 Hello!",20,true)
		else:
			_text(sidebar,"看完这次聚会，就会留下新的回忆。",20,true)
		var pending: bool = not party.playback.is_empty() and not party.playback.finished
		if pending:
			_text(sidebar,"聚会看到第 %d 幕，下次接着看。" % mini(4,int(party.playback.step)+1),19)
			_button(sidebar,"接着看聚会",start_playback,true,"PartyPlay")
			_button(sidebar,"先结束这次放映",abandon_playback,false,"PartyAbandon")
		else:
			_button(sidebar,"接着上次的试摆" if not party.draft.is_empty() else "布置欢迎桌",begin_edit,true,"PartyBegin")
			if Progress.is_arranged(party.layout) and party.draft.is_empty():
				_button(sidebar,"再和朋友聚一聚" if Progress.watched(party) else "请朋友来坐坐",start_playback,false,"PartyPlay")
		_text(sidebar,"可以慢慢换位置，也可以随时休息。",17,true)
	var actions := _row(ui.panel_box)
	_button(actions,"回到旅行册",journey.show_hub,false,"PartyBackHub")
	_button(actions,"先在小屋走走",game._close,false,"PartyBackHome")
	_finish("PartyBegin" if ready else "PartyContinue")

func begin_edit() -> void:
	if not game._prepare_screen(): return
	if game.room != "home": await game.change_room("home")
	if commit({"kind":"party_begin"}): show_editor()

func show_editor() -> void:
	if state().draft.is_empty(): begin_edit(); return
	if not _open("挑桌布，给朋友换个座位","试摆会自动暂存 · 确认后才摆进小屋"): return
	var sidebar := _body(state().draft)
	_text(sidebar,"先选桌布",21)
	var themes := _row(sidebar)
	theme_buttons.clear()
	for value: String in Progress.THEMES:
		theme_buttons[value] = _button(themes,Progress.theme_name(value),choose_theme.bind(value),false,"PartyTheme_"+value)
	_text(sidebar,"再选朋友，点一把椅子",21)
	var guests := GridContainer.new()
	guests.columns = 2
	guests.add_theme_constant_override("h_separation",8)
	guests.add_theme_constant_override("v_separation",8)
	sidebar.add_child(guests)
	guest_buttons.clear()
	for guest: String in Progress.GUESTS:
		guest_buttons[guest] = _button(guests,guest.trim_prefix("textbook_").capitalize(),choose_guest.bind(guest),false,"PartyGuest_"+guest)
	selection_label = _text(sidebar,"",18,true)
	var seats := GridContainer.new()
	seats.columns = 2
	seats.add_theme_constant_override("h_separation",8)
	seats.add_theme_constant_override("v_separation",8)
	sidebar.add_child(seats)
	seat_buttons.clear()
	for seat: String in Progress.SEATS:
		seat_buttons[seat] = _button(seats,seat.trim_prefix("seat_")+"号椅",choose_seat.bind(seat),false,"PartySeat_"+seat)
	_text(sidebar,"椅子有人时，两位朋友会交换位置。",17,true)
	var actions := _row(ui.panel_box)
	_button(actions,"确认摆好",confirm_layout,true,"PartyConfirm")
	_button(actions,"下次接着摆",game._close,false,"PartyPause")
	_button(actions,"放弃这次试摆",cancel_layout,false,"PartyCancel")
	_refresh_editor(false)
	_finish("PartyConfirm")

func choose_guest(guest: String) -> void:
	selected = guest
	_refresh_editor(false)

func choose_theme(value: String) -> void:
	if commit({"kind":"party_theme","theme":value}): _refresh_editor()

func choose_seat(seat: String) -> void:
	if commit({"kind":"party_seat","guest":selected,"seat":seat}): _refresh_editor()

func _refresh_editor(refresh_stage: bool = true) -> void:
	var draft: Dictionary = state().draft
	if draft.is_empty(): return
	if refresh_stage and is_instance_valid(stage): stage.set_layout(draft)
	for theme: String in theme_buttons:
		(theme_buttons[theme] as Button).theme_type_variation = "PrimaryButton" if draft.theme == theme else "Button"
	for guest: String in guest_buttons:
		(guest_buttons[guest] as Button).theme_type_variation = "PrimaryButton" if selected == guest else "Button"
	for seat: String in seat_buttons:
		var guest_name := ""
		for guest: String in Progress.GUESTS:
			if draft.seats[guest] == seat: guest_name = guest.trim_prefix("textbook_").capitalize()
		(seat_buttons[seat] as Button).text = seat.trim_prefix("seat_")+"号椅\n"+guest_name
	selection_label.text = "已选 "+selected.trim_prefix("textbook_").capitalize()+" · 点椅子换位置"

func confirm_layout() -> void:
	if not commit({"kind":"party_confirm"}): return
	journey._build_story_props()
	show_wish()
	ui.notify("欢迎桌已摆好。可以请朋友来坐坐了。")

func cancel_layout() -> void:
	if commit({"kind":"party_cancel"}): show_wish(); ui.notify("保留之前摆好的欢迎桌。")

func abandon_playback() -> void:
	if commit({"kind":"party_abandon"}): show_wish(); ui.notify("这次放映已结束。没看完的相聚不会记成回忆。")

func start_playback() -> void:
	if not game._prepare_screen(): return
	if game.room != "home": await game.change_room("home")
	if not commit({"kind":"party_play"}): return
	if not _open("朋友们来做客啦","四幕小聚会 · 可以暂停，也可以下次接着看"): return
	var playback: Dictionary = state().playback
	var sidebar := _body(playback.layout)
	playback_caption = _text(sidebar,"",20,true)
	playback_line = _text(sidebar,"",25)
	_text(sidebar,"大家都坐在自己的椅子上。",18,true)
	var actions := _row(ui.panel_box)
	pause_button = _button(actions,"暂停一会儿",toggle_pause,false,"PartyPlaybackPause")
	_button(actions,"稍后接着看",game._close,false,"PartyPlaybackLeave")
	playback_id = str(playback.id)
	playback_step = int(playback.step)
	playback_elapsed = 0.0
	playback_paused = false
	playback_active = true
	if playback_step >= Progress.BEATS.size(): _finish_playback(); return
	_show_beat()
	_finish("PartyPlaybackPause")

func toggle_pause() -> void:
	playback_paused = not playback_paused
	if is_instance_valid(pause_button): pause_button.text = "继续看聚会" if playback_paused else "暂停一会儿"
	if is_instance_valid(stage): stage.paused = playback_paused
	_pause_narration(playback_paused or game.application_backgrounded)

func _show_beat() -> void:
	playback_elapsed = 0.0
	playback_caption.text = "第 %d / 4 幕" % (playback_step + 1)
	playback_line.text = LINES[playback_step]
	stage.set_beat(playback_step)
	stage.paused = playback_paused
	if playback_step == 0: _play_narration("hello")
	if playback_step == 3: _play_narration("goodbye")

func _play_narration(phrase: String) -> void:
	# The shared world voice may already belong to another screen. Party narration
	# lives under its own stage so pausing or leaving cannot change that voice.
	if not is_instance_valid(stage) or game.muted: return
	var phrases: Dictionary = game.curriculum.get("phrases",{})
	if not phrases.has(phrase): return
	var stream: AudioStream = load(str(phrases[phrase].audio)) as AudioStream
	if stream == null: return
	if not is_instance_valid(narration) or narration.get_parent() != stage:
		narration = AudioStreamPlayer.new()
		narration.name = "PartyNarration"
		if is_instance_valid(game.voice):
			narration.volume_db = game.voice.volume_db
			narration.bus = game.voice.bus
		stage.add_child(narration)
		stage.tree_exiting.connect(_stop_narration.bind(narration.get_instance_id()),CONNECT_ONE_SHOT)
	narration.stop()
	narration.stream_paused = false
	narration.stream = stream
	narration.play()
	_pause_narration(playback_paused or game.application_backgrounded)

func _pause_narration(paused: bool) -> void:
	if is_instance_valid(narration) and (narration.playing or narration.stream_paused): narration.stream_paused = paused

func _stop_narration(instance_id: int = 0) -> void:
	if not is_instance_valid(narration) or (instance_id != 0 and narration.get_instance_id() != instance_id): return
	narration.stop()
	narration.stream_paused = false

func _process(delta: float) -> void:
	if not playback_active: return
	if not is_instance_valid(stage) or ui.current_panel != "party" or not ui.modal.visible or game.room != "home":
		playback_active = false
		_stop_narration()
		return
	var stopped: bool = playback_paused or game.application_backgrounded or get_tree().paused
	stage.paused = stopped
	_pause_narration(stopped)
	if stopped: return
	playback_elapsed += delta
	if playback_elapsed < Progress.DURATIONS[playback_step]: return
	# Each automatic receipt follows visible, foreground playback. Buttons cannot skip it.
	if not commit({"kind":"party_beat","id":playback_id,"step":playback_step,"beat":Progress.BEATS[playback_step]}):
		playback_paused = true
		_pause_narration(true)
		pause_button.text = "重试保存这一幕"
		return
	playback_step += 1
	if playback_step >= Progress.BEATS.size(): _finish_playback()
	else: _show_beat()

func _finish_playback() -> void:
	playback_active = false
	_stop_narration()
	if is_instance_valid(stage): stage.paused = true
	if not commit({"kind":"party_finish","id":playback_id}):
		show_wish()
		return
	journey._build_story_props()
	show_wish()
	ui.notify("今天的相聚收进回忆里了。下次还可以再来坐坐。")

func handles_interaction(id: String) -> bool:
	if id != "journey_party_table": return false
	show_wish()
	return true

func build_world(parent: Node3D, at: Vector3) -> void:
	var party := state()
	var root := Node3D.new()
	root.name = "PartyKeepsake"
	# The existing living-room table is behind the navigation marker. Keep this
	# ornament on its tabletop; the marker and authored collision stay unchanged.
	root.position = at + Vector3(0,0.94,-2.0)
	root.scale = Vector3.ONE * 0.45
	root.set_meta("confirmed_revision",int(party.revision))
	root.set_meta("layout",party.layout.duplicate(true))
	root.set_meta("watched",Progress.watched(party))
	root.set_meta("draft_visible",false)
	parent.add_child(root)
	Stage.add_table(root,str(party.layout.theme))
	var label := Label3D.new()
	label.name = "PartyKeepsakeLabel"
	label.font = Style.body_font()
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.006
	label.position = Vector3(0,1.80,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = "相聚回忆" if Progress.watched(party) else "欢迎桌" if int(party.revision) > 0 else "小小心愿"
	root.add_child(label)
	var found := false
	for entry: Dictionary in game.interactions:
		if entry.id == "journey_party_table": found = true; entry.position = at
	if not found: game.interactions.append({"id":"journey_party_table","type":"memory","position":at,"radius":2.6,"label":"看看我们的欢迎桌"})
	game.feedback.bind_interactions(game.interactions)

func _finish(focus_name: String) -> void:
	ui._layout.call_deferred()
	var button: Button = ui.panel_box.find_child(focus_name,true,false) as Button
	if button: ui._focus_if_current.call_deferred(button.get_instance_id())
