extends Node
## GDD journey orchestration. State owns durable facts; world geometry stays authored.
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const MemorySink = preload("res://scripts/memory_event_sink.gd")
const P2Progress = preload("res://scripts/p2_progress.gd")
const DiscoveryProgress = preload("res://scripts/discovery_progress.gd")
# The rear-wall gap between the pantry and sofa belongs to the discovery display.
# Keep its walk-up point separate from the wardrobe's authored interaction anchor.
const HOME_DISCOVERY_APPROACH := Vector3(-2.4, 0, -4.7)
const HOME_DISCOVERY_MOUNT := Vector3(-2.4, 1.9, -6.72)
var game: Node3D
var ui: CanvasLayer
var prologue: Dictionary = {}
var catalog: Dictionary = {}
var entries: Array = []
var current_letter := ""
var current_memory: Control
var memory_invocation := ""
var library_query := ""
var library_unit := ""
var library_page := 0
var story_room_root: Node3D
var u1_nickname := "小岛朋友"
var u1_decoration := "星星"
var backgrounded := false
var library_grid: GridContainer
var library_counter: Label
var library_previous: Button
var library_next: Button
var library_matches: Array = []
var memory_from_u1 := false
var active_actor_ids: Array = []
var u1_visible_step := ""
var memory_sink: RefCounted
var letter_pending: Array = []
var letter_activity: Control
var p2: Node
var friend_corner: Node
var party: Node
var discovery: Node
var memories: Node
var reviews: Node
var handoff_busy := false
var handoff_contact := false
var handoff_invocation := 0

func setup(owner_game: Node3D) -> void:
	game = owner_game
	ui = game.ui
	prologue = _read("res://data/learning/prologue.json")
	_load_catalog()
	p2 = load("res://scripts/p2_journey_controller.gd").new()
	add_child(p2)
	p2.setup(self)
	friend_corner = load("res://scripts/friend_corner_controller.gd").new()
	add_child(friend_corner)
	friend_corner.setup(self)
	party = load("res://scripts/party_controller.gd").new()
	add_child(party)
	party.setup(self)
	discovery = load("res://scripts/discovery_controller.gd").new()
	add_child(discovery)
	discovery.setup(self)
	memories = load("res://scripts/friend_memories_controller.gd").new()
	add_child(memories)
	memories.setup(self)
	reviews = load("res://scripts/review_controller.gd").new()
	add_child(reviews)
	reviews.setup(self)
	State.review_refresh()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _load_catalog() -> void:
	catalog = Content.load_catalog()
	entries = catalog.get("entries", [])

func snapshot() -> Dictionary:
	return State.journey_snapshot()

func objective() -> String:
	var state := snapshot()
	match str(state.get("phase", "home")):
		"home": return "我的第一天 · " + str({"H01":"认识家门旁的向导","H02":"选一个喜欢的样子","H03":"带上旅行册","H04":"开始小岛旅行"}.get(state.next_home_step,"准备出发"))
		"prologue": return "旅行册 · %d / 26 个发现" % int(state.experienced_count)
		"u1": return "欢迎新朋友 · " + str({"U1-01":"和熊叔说声早上好","U1-02":"出发去学校","U1-03":"认识门口的新朋友","U1-04":"一起布置欢迎角","U1-05":"收下朋友的小礼物","U1-06":"听听朋友的故事","U1-07":"和朋友打个招呼","U1-08":"留一张大家的合照","U1-09":"收好今天的回忆","U1-10":"带着回忆回家"}.get(state.next_u1_step,"一起去见朋友"))
		"u2": return "给朋友送邀请 · " + str(P2Progress.next_step(state.p2,2).get("title","接着送邀请"))
		"u3": return "欢迎会座位数 · 给来客留个位置"
		"p2_complete": return "朋友的欢迎桌 · 来欢迎桌坐坐"
		_: return "我的旅程 · 打开旅行册"

func on_room_ready() -> void:
	if game.room.begins_with("landmark_") and (snapshot().home_steps.size()==4 or snapshot().legacy_compatible):
		State.journey_record_letter(game.room.trim_prefix("landmark_"), game.room, "visited")
	_build_story_props()

func intercept_interaction(id: String) -> bool:
	if party.handles_interaction(id) or discovery.handles_interaction(id): return true
	if id.begins_with("actor:"):
		var actor_id := id.trim_prefix("actor:")
		var transfer: Dictionary = snapshot().p2.trials.get("U1-10",{})
		if actor_id == "npc_rabbit_gardener" and not transfer.is_empty() and not transfer.completed:
			p2.show_transfer()
			return true
		if memories.handles_actor(actor_id): return true
		if friend_corner.handles_actor(actor_id): return true
		active_actor_ids = [actor_id]
		if game.living:
			var actor: Node3D = game.living.get_actor(actor_id)
			if actor:
				actor.face(game.player.position)
			game.living.play_actor_action(actor_id,"wave")
		if str(snapshot().phase)=="home" and game.room=="home":
			State.journey_complete_home_step("H01")
			show_home()
		elif str(snapshot().phase) in ["u2","u3"]:
			p2.show_chapter()
		elif str(snapshot().phase)=="u1":
			show_u1()
		else:
			ui.show_panel("journey_talk","Hello! 很高兴见到你。","小岛朋友","一起在小岛上走走吧。也可以打开旅行册，接着看今天的发现。",[{"label":"打开旅行册","id":"journey:hub","primary":true},{"label":"继续散步","id":"close"}])
		return true
	if id=="journey_friend_corner":
		friend_corner.show_wish()
		return true
	if id=="journey_photo":
		show_photo()
		return true
	if id=="journey_welcome":
		show_u1()
		return true
	if game.room.begins_with("landmark_") and (snapshot().home_steps.size()==4 or snapshot().legacy_compatible):
		var letter: String = str(game.room).trim_prefix("landmark_")
		var entry := _letter(letter)
		var target := "memory_" + str(entry.get("scene_ref",{}).get("learning_node","SG_MEMORY_03")).trim_prefix("SG_MEMORY_")
		if id==target:
			show_letter(letter)
			return true
	return false

func show_hub() -> void:
	if not game._prepare_screen(): return
	var state := snapshot()
	var chosen := _book_title(str(state.selected_book_id))
	var actions: Array = [{"label":"继续我的旅程","id":"journey:continue","primary":true},{"label":"和兔兔一起采苹果","id":"journey:orchard_play"},{"label":"26 个字母发现页","id":"journey:letters"},{"label":"教材里的词故事","id":"journey:library"},{"label":"选择教材 · "+chosen,"id":"journey:books"},{"label":"回到自己的家","id":"journey:home"},{"label":"原有生活回忆册","id":"journey:old_journal"}]
	actions.insert(1,{"label":"我的朋友角 · 小岛心愿","id":"journey:friend_corner"})
	actions.insert(2,{"label":"发现卡和街区旅行页","id":"journey:discoveries"})
	actions.insert(3,{"label":"去看看我的朋友","id":"journey:friends"})
	actions.insert(1,{"label":"朋友捎来的小邀请","id":"journey:revisits"})
	actions.append({"label":"家长观察册","id":"journey:parent"})
	if state.p2.chapters["3"].completed:
		actions.insert(1,{"label":"我们的欢迎桌 · 相聚回忆","id":"journey:party"})
	if state.u1.photo.created:
		actions.append({"label":"我们的第一张合照","id":"journey:photo"})
		actions.append({"label":"去花园和兔兔打招呼","id":"journey:p2:transfer"})
	actions.append({"label":"在家门摆个装饰","id":"journey:p2:home"})
	if not state.p2.chapters["2"].steps.is_empty(): actions.append({"label":"邀请和欢迎桌的回忆","id":"journey:p2:keepsakes"})
	if state.legacy_compatible:
		actions.append({"label":"继续原有的生活小心愿","id":"journey:old_quest"})
	ui.show_travel_book(chosen,objective(),_visited_count(state),int(state.experienced_count),actions)

func show_home() -> void:
	active_actor_ids = ["npc_bear_uncle"]
	var state := snapshot()
	var step := str(state.next_home_step)
	var text := "熊叔在门边等你。试着点击地面走近他，再点击人物或按 E 打招呼。"
	var actions: Array = [{"label":"去和熊叔打招呼","id":"journey:guide","primary":true},{"label":"先自由走走","id":"close"}]
	if step=="H02":
		p2.show_home_choice()
		return
	elif step=="H03":
		text = "这是你的旅行册。岛上分成五个街区，二十六个字母伙伴等着认识你。今天走几站，由你决定。"
		actions = [{"label":"收下旅行册，看看地图","id":"journey:take_book","primary":true}]
	elif step=="H04":
		text = "从苹果屋出发吧。可以让向导陪你抵达，也可以打开地图，自己沿路走过去。"
		actions = [{"label":"请向导陪我去苹果屋","id":"journey:start","primary":true},{"label":"打开地图，慢慢走","id":"journey:start_walk"}]
	ui.show_panel("journey_home","熊叔的小岛邀请","我的第一天",text,actions)

func show_books() -> void:
	var actions: Array = []
	for book: Dictionary in game.curriculum.get("source_books",[]):
		actions.append({"label":str(book.title),"id":"journey:book:"+str(book.id),"primary":str(book.id)==str(snapshot().selected_book_id)})
	ui.show_panel("journey_books","选一本正在学的教材","你的进度会分别保留","八册词故事都可以浏览。三年级上册可接续开学欢迎故事；其他册的生活主线还在制作。",actions,"切换教材不会清空旅行册、已有物品或学习记录。")

func show_letters() -> void:
	if not State.review_expose("letter/"): return
	p2.show_trip()

func show_letter_index() -> void:
	if not game._prepare_screen(): return
	ui._begin("journey_letters","map")
	ui._heading("二十六个字母伙伴","五个街区 · 陪同出发，或回到熟悉的地方")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.panel_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	var state := snapshot()
	for record: Dictionary in prologue.get("letters",[]):
		var letter := str(record.letter.uppercase)
		var facts: Dictionary = state.letters.get(letter,{})
		var detail := "已收下发现页" if facts.get("experienced",false) else ("来过，还可以继续" if facts.get("visited",false) else "请向导陪我去")
		var button: Button = ui.button("%s  %s\n%s" % [record.letter.pair,record.anchor.chinese_image_name,detail],"journey:travel:"+letter,bool(facts.get("experienced",false)),Vector2(0,100))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	ui.panel_box.add_child(ui.button("回到旅行册","journey:hub",false))
	ui._layout.call_deferred()

func _letter(value: String) -> Dictionary:
	for record: Dictionary in prologue.get("letters",[]):
		if str(record.letter.uppercase)==value:
			return record
	return {}

func travel_letter(letter: String) -> void:
	if _letter(letter).is_empty():
		return
	if str(snapshot().phase)=="home":
		ui.notify("先和熊叔把出门的小准备做好，再一起出发。")
		continue_journey()
		return
	game._close()
	await game.change_room("landmark_"+letter)
	var record := _letter(letter)
	var marker := "memory_" + str(record.scene_ref.learning_node).trim_prefix("SG_MEMORY_")
	game.ui.notify("向导陪你到了。沿亮起的小路，去看看"+str(record.anchor.chinese_image_name)+"。")
	await game._navigate_to_id(marker,true)

func show_letter(letter: String) -> void:
	if game.room!="landmark_"+letter:
		return
	if letter=="A":
		game.start_orchard_activity()
		return
	show_letter_card(letter)

func show_letter_card(letter: String) -> void:
	if game.room!="landmark_"+letter: return
	if not State.review_expose("letter/"+letter+"/"): return
	var record := _letter(letter)
	if record.is_empty():
		return
	current_letter = letter
	if not game._prepare_screen(): return
	ui._begin("prologue_card","map")
	ui._heading(str(record.anchor.landmark_name),"字母伙伴 · "+str(record.letter.pair))
	var component: Control = load("res://ui/prologue_activity.gd").new()
	component.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(component)
	letter_activity = component
	component.setup(record,ui.reduced_motion,snapshot().p2.letters[letter],func(event: Dictionary): return State.journey_p2_event(event))
	component.suspended=game.application_backgrounded
	component.fact.connect(func(fact: String, mode: String):
		letter_pending.append({"letter":letter,"room":str(game.room),"fact":fact,"mode":mode})
		_flush_letter_facts()
	)
	component.audio_requested.connect(func(kind: String): _play_letter_audio(letter,kind))
	component.object_sound.connect(func(kind: String, index: int):
		if kind=="note": game.sounds.note(index)
		else: game.sounds.play(kind)
	)
	component.finished.connect(func():
		if not _flush_letter_facts() or not snapshot().letters[letter].experienced:
			ui.notify("发现页还没有保存成功，先留在这里再试一次。")
			return
		ui.notify("收下了 "+str(record.letter.pair)+" 的发现页。")
		show_letter_result(letter)
	)
	ui._layout.call_deferred()

func show_letter_result(letter: String) -> void:
	var selected_trip: Array = snapshot().p2.trip
	var trip_finished: bool = selected_trip.size()==1 and selected_trip.has(letter)
	p2.after_letter(letter)
	var state := snapshot()
	var next := str(state.next_letter)
	if not state.p2.trip.is_empty(): next = str(state.p2.trip[0])
	var actions: Array = [{"label":"再看看这张发现页","id":"journey:inspect:"+letter},{"label":"回家歇一会儿","id":"journey:home"}]
	actions.append({"label":"把这张发现卡带回家","id":"journey:discovery-card:"+letter})
	var area := DiscoveryProgress.district_for_letter(letter)
	if DiscoveryProgress.eligible_districts(state).has(area):
		actions.append({"label":"做一张这个街区的旅行页","id":"journey:discovery-page:"+area})
	actions.append({"label":"想一想这位伙伴（可跳过）","id":"journey:p2:recall:"+letter})
	if trip_finished:
		actions.push_front({"label":"这次小旅行完成，回家吧","id":"journey:home","primary":true})
		actions.append({"label":"再选几站","id":"journey:letters"})
	elif not next.is_empty():
		actions.push_front({"label":"请向导陪我去 "+next,"id":"journey:travel:"+next,"primary":true})
	else:
		actions.push_front({"label":"二十六个伙伴都见过了！","id":"journey:continue","primary":true})
	ui.show_panel("prologue_result","又认识了一位字母伙伴","旅行册 · %d / 26" % int(state.experienced_count),"有帮助也能把发现带回家。想起它的时候，可以再来看看它的样子。",actions)

func _play_letter_audio(letter: String, kind: String) -> void:
	if game.muted:
		ui.notify("声音已关闭；看字卡也可以继续。")
		return
	var path := "res://assets/audio/prologue/%s_%s.wav" % [kind,letter]
	if ResourceLoader.exists(path):
		game.voice.stop()
		game.voice.stream = load(path)
		game.voice.play()
		if game.room=="landmark_"+letter:
			State.journey_p2_event({"kind":"letter_audio","letter":letter,"room":game.room,"role":kind,"played":true})

func show_u1() -> void:
	var state := snapshot()
	if str(state.phase)!="u1" and not state.u1.completed:
		show_hub()
		return
	var step := str(state.next_u1_step)
	u1_visible_step = step
	active_actor_ids = {"U1-01":["npc_bear_uncle"],"U1-03":["textbook_lingling"],"U1-04":["textbook_lingling"],"U1-05":["textbook_peter"],"U1-07":["textbook_anne"],"U1-08":["textbook_lingling","textbook_peter","textbook_anne"]}.get(step,[])
	var title := "新的一天，新的朋友"
	var body := ""
	var actions: Array = []
	match step:
		"U1-01":
			title = "熊叔：Good morning!"
			body = "早晨，熊叔送来了学校欢迎角的邀请。\nGood morning. 早上好。\n先听一听示范，再一起出发吧。"
			actions = [{"label":"听听早安问候","id":"audio:good_morning"},{"label":"接受学校的邀请","id":"journey:u1:01","primary":true}]
		"U1-02":
			body = "Lingling 和 Peter 在校园等你。可以让向导陪你到校门，也可以在地图中自己找到学校。"
			actions = [{"label":"一起去校园","id":"journey:u1:school","primary":true},{"label":"看看地图","id":"map"}]
		"U1-03":
			title = "Lingling：Hello, I'm Lingling."
			body = "你好，我是 Lingling。欢迎加入我们！\n先和她打个招呼，再给游戏里的自己选一个称呼。"
			actions = [{"label":"听 Lingling 介绍","id":"audio:hello_lingling"},{"label":"Hello! 你好！","id":"journey:u1:name","primary":true}]
		"U1-04":
			title = "一起布置欢迎角"
			body = "把名牌放好，再为欢迎角选一个喜欢的图案。\nAa · Bb · Cc —— 还记得苹果、小船和蛋糕吗？"
			actions = [{"label":"星星欢迎牌","id":"journey:u1:decorate:星星","primary":true},{"label":"花朵欢迎牌","id":"journey:u1:decorate:花朵"},{"label":"听字母 A","id":"journey:audio:A:letter"}]
		"U1-05":
			title = "Peter 递来了你的旅行册"
			body = "刚才腾不出手，Peter 帮你拿好了旅行册。\n收到帮助时，可以说 Thank you. 谢谢你。"
			actions = [{"label":"听听 Thank you.","id":"audio:thank_you"},{"label":"Thank you, Peter!","id":"journey:u1:05","primary":true}]
		"U1-06":
			title = "给 Hello 编一个记忆故事"
			body = "想看看熟悉的地标怎样串起一个词吗？\n我们可以一起看看，也可以先去参加合照。"
			actions = [{"label":"打开 hello 的故事","id":"journey:u1:hello","primary":true},{"label":"先去见 Anne","id":"journey:u1:06"}]
		"U1-07":
			if not State.journey_p2_event({"kind":"trial_begin","context":"U1-07","room":game.room}): return
			title = "Anne 也来参加欢迎会了"
			body = "Anne 向你挥手。刚见到新朋友时，你想怎么回应？"
			actions = [{"label":"Thank you.","id":"journey:u1:07:retry"},{"label":"Hello!","id":"journey:u1:07:hello","primary":false},{"label":"请再示范一次","id":"journey:u1:07:demo"}]
			var support := int(snapshot().p2.trials["U1-07"].help)
			if support>0: body+="\n先打个招呼，再一起去参加欢迎会。"
			if support>=2: body+="\nAnne 说：Hello! 你好！你也可以这样回应。"
			actions.append({"label":"小提示","id":"journey:u1:07:hint"})
			actions.append({"label":"陪我选择","id":"journey:u1:07:together"})
		"U1-08":
			title = "把今天留在一张合照里"
			body = "Lingling、Peter 和 Anne 都到了。\n选一个相框，留下今天共同布置欢迎角的样子。"
			actions = [{"label":"暖黄色相框 · 拍照","id":"journey:u1:photo:yellow","primary":true},{"label":"晴空蓝相框 · 拍照","id":"journey:u1:photo:blue"}]
		"U1-09":
			title = "把合照带回家"
			body = "欢迎会结束了。回到自己的小屋，把合照放在回忆展示位。"
			actions = [{"label":"陪我回家","id":"journey:u1:return","primary":true}] if game.room!="home" else [{"label":"把合照摆到展示架","id":"journey:u1:09","primary":true}]
		_:
			title = "欢迎你，小岛的新朋友"
			body = "合照已经摆在家里。下次见面，试着主动和朋友打招呼吧。\n熊叔还带来了邀请册，我们可以接着去认识朋友的名字。"
			actions = [{"label":"接着给朋友送邀请","id":"journey:continue","primary":true},{"label":"看看合照","id":"journey:photo"},{"label":"在小岛上走走","id":"close"}]
	var exposure_texts: Array = actions.map(func(action: Dictionary): return str(action.get("label","")))
	exposure_texts.append(body)
	exposure_texts.append("Hello!") # This expression is also printed in the U1 subtitle.
	if not State.review_expose_text(exposure_texts): return
	ui.show_panel("journey_u1",title,"Unit 1 · Hello!",body,actions)

func _u1_commit(step: String, details: Dictionary = {}) -> void:
	if State.journey_complete_u1_step(step,details):
		_build_story_props()
		show_u1()

func show_photo() -> void:
	var photo: Dictionary = snapshot().u1.photo
	if not photo.created:
		show_hub()
		return
	ui._begin("journey_photo","wardrobe")
	ui._heading("第一次，和大家站在一起","我的小岛合照 · 欢迎角")
	var image := TextureRect.new()
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := str(photo.get("details",{}).get("image_path",""))
	if FileAccess.file_exists(path):
		var source := Image.load_from_file(path)
		if source:
			image.texture = ImageTexture.create_from_image(source)
	var frame := PanelContainer.new()
	frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel",Style.box(Color("e5be72") if photo.details.get("frame","yellow")=="yellow" else Color("94c0c6"),14,12))
	frame.add_child(image)
	ui.panel_box.add_child(frame)
	ui.panel_box.add_child(ui.label("Lingling · Peter · Anne · 还有你",22))
	ui.panel_box.add_child(ui.button("回校园重新拍一张","journey:retake:"+str(photo.details.get("frame","yellow")),false))
	ui.panel_box.add_child(ui.button("继续我的旅程","journey:continue",true))
	ui._layout.call_deferred()

func _take_photo(frame: String) -> void:
	if game.capturing_photo: return
	ui.close_panel()
	if game.room!="school":
		await game.change_room("school")
	for id: String in ["textbook_lingling","textbook_peter","textbook_anne"]:
		if not game.living.get_actor(id):
			ui.notify("等合照里的朋友都到齐，再拍一张。")
			show_u1()
			return
	game.capturing_photo = true
	game.player.locked = true
	ui.hud.hide()
	ui.toast_label.hide()
	var original_position: Vector3 = game.camera.position
	var original_size: float = game.camera.size
	var original_rotation: Vector3 = game.camera.rotation
	var original_player_yaw: float = game.player.visual.rotation.y
	var center: Vector3 = game.player.position
	var count := 1
	for id: String in ["textbook_lingling","textbook_peter","textbook_anne"]:
		var actor: Node3D = game.living.get_actor(id)
		if actor:
			center += actor.global_position
			count += 1
			game.living.play_actor_action(id,"photo")
	center /= count
	game.living.set_context({"dialogue_open":true,"active_actor_ids":["textbook_lingling","textbook_peter","textbook_anne"]})
	game.camera.position = center+game.camera_offset
	game.camera.look_at(center+Vector3(0,0.7,0),Vector3.UP)
	game.camera.size = 13.5
	game.player.face(game.camera.global_position)
	for id: String in ["textbook_lingling","textbook_peter","textbook_anne"]:
		var actor: Node3D = game.living.get_actor(id)
		if actor: actor.face(game.camera.global_position)
	var ready := false
	while not ready:
		await get_tree().process_frame
		ready = not game.application_backgrounded
		for id: String in ["textbook_lingling","textbook_peter","textbook_anne"]:
			var phase: Dictionary = game.living.get_actor(id).get_action_phase()
			ready = ready and float(phase.normalized)>=0.26
	var path := ""
	var image_ok := DisplayServer.get_name()=="headless"
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		path = "user://welcome-photo-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_msec())+".png"
		var picture := game.get_viewport().get_texture().get_image()
		image_ok = picture.save_png(path)==OK
	game.camera.position = original_position
	game.camera.size = original_size
	game.camera.rotation = original_rotation
	game.player.visual.rotation.y = original_player_yaw
	game.capturing_photo = false
	ui.hud.show()
	if not image_ok:
		ui.notify("照片还没保存好。先留在欢迎会，再试着拍一次。")
		show_u1()
		return
	if snapshot().u1.photo.created:
		if State.journey_p2_event({"kind":"photo_retake","path":path,"frame":frame}):
			_build_story_props()
			show_photo()
	else:
		_u1_commit("U1-08",{"frame":frame,"image_path":path,"participants":"textbook_lingling,textbook_peter,textbook_anne","completion_mode":"life_activity"})

func _build_story_props() -> void:
	if is_instance_valid(story_room_root):
		if story_room_root.get_parent(): story_room_root.get_parent().remove_child(story_room_root)
		story_room_root.queue_free()
	for index: int in range(game.interactions.size()-1,-1,-1):
		if str(game.interactions[index].id) in ["journey_party_table","journey_discoveries"]:
			game.interactions.remove_at(index)
	story_room_root = Node3D.new()
	story_room_root.name = "JourneyKeepsakes"
	game.world.add_child(story_room_root)
	var state := snapshot()
	var has_corner: bool = state.u1.steps.has("U1-04")
	if game.room=="home": _build_home_decoration(str(state.p2.home_choice))
	if game.room=="home":
		var party_position: Vector3 = game.metadata.get("spawn",Vector3.ZERO)
		for entry: Dictionary in game.interactions:
			if str(entry.id)=="memory_03": party_position = entry.position
		discovery.build_world(story_room_root,HOME_DISCOVERY_APPROACH,HOME_DISCOVERY_MOUNT)
		party.build_world(story_room_root,party_position)
	if game.room=="school" and has_corner:
		var position: Vector3 = game.metadata.get("spawn",Vector3.ZERO)+Vector3(3,0,0)
		for entry: Dictionary in game.interactions:
			if str(entry.id)=="memory_01": position = entry.position
		var details: Dictionary = state.u1.step_details.get("U1-04",{})
		_prop_sign(position,"欢迎来到小岛\n"+str(details.get("nickname","小岛朋友"))+" · "+str(details.get("decoration","星星")),Color("e5be72"))
	if game.room=="home" and state.u1.completed:
		var position: Vector3 = game.metadata.get("spawn",Vector3.ZERO)
		for entry: Dictionary in game.interactions:
			if str(entry.id)=="memory_05": position = entry.position
		friend_corner.build_world(story_room_root,position)

func _prop_sign(at: Vector3, text: String, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(2.6,1.4,0.12)
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = at+Vector3(0,1.3,0)
	story_room_root.add_child(mesh)
	var caption := Label3D.new()
	caption.text = text
	caption.font = load("res://assets/fonts/IslandSans.otf")
	caption.font_size = 40
	caption.pixel_size = 0.006
	caption.modulate = Style.INK
	caption.position = at+Vector3(0,1.3,0.09)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	story_room_root.add_child(caption)

func _build_home_decoration(choice: String) -> void:
	var previous: Node = story_room_root.get_node_or_null("HomeDoorOrnament")
	if previous: previous.free()
	if choice not in ["flowers","star"] or game.room!="home": return
	var point: Vector3 = game.metadata.get("spawn",Vector3.ZERO)
	for item: Dictionary in game.interactions:
		if str(item.id)=="memory_01": point=item.position
	var ornament := Sprite3D.new()
	ornament.name = "HomeDoorOrnament"
	ornament.texture = Content.icon("F" if choice=="flowers" else "S",2.0)
	ornament.pixel_size=0.005
	ornament.position=point+Vector3(0,1.5,0)
	ornament.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	story_room_root.add_child(ornament)

func _book_title(id: String) -> String:
	for book: Dictionary in game.curriculum.get("source_books",[]):
		if str(book.id)==id: return str(book.title)
	return "三年级上册"

func _visited_count(state: Dictionary) -> int:
	var count := 0
	for value: Dictionary in state.letters.values():
		if value.get("visited",false): count += 1
	return count

func handle_action(id: String) -> bool:
	if id=="journey:revisits":
		reviews.show_invites()
		return true
	if id=="journey:parent":
		reviews.show_parent(true)
		return true
	if not id.begins_with("journey:"): return false
	var action := id.trim_prefix("journey:")
	if action.begins_with("p2:"):
		var target := action.trim_prefix("p2:")
		if target=="transfer": p2.show_transfer()
		elif target=="keepsakes": p2.show_keepsakes()
		elif target=="home":
			if game.room!="home": await game.change_room("home")
			p2.show_home_choice()
		elif target.begins_with("recall:"): p2.show_recall_menu(target.trim_prefix("recall:"))
	elif action.begins_with("glyph:"): show_letter_card(action.trim_prefix("glyph:"))
	elif action.begins_with("discovery-card:"): discovery.show_letter_reward(action.trim_prefix("discovery-card:"))
	elif action.begins_with("discovery-page:"): discovery.show_district_reward(action.trim_prefix("discovery-page:"))
	elif action.begins_with("retake:"): _take_photo(action.trim_prefix("retake:"))
	elif action.begins_with("book:"):
		if State.journey_select_book(action.trim_prefix("book:")):
			library_unit = ""
			library_page = 0
			show_hub()
	elif action.begins_with("outfit:"):
		State.set_outfit(action.trim_prefix("outfit:"))
		show_home()
	elif action.begins_with("travel:"):
		travel_letter(action.trim_prefix("travel:"))
	elif action.begins_with("inspect:"):
		show_letter(action.trim_prefix("inspect:"))
	elif action.begins_with("audio:"):
		var pieces := action.split(":")
		_play_letter_audio(pieces[1],pieces[2])
	elif action.begins_with("u1:"):
		_handle_u1_action(action.trim_prefix("u1:"))
	else:
		match action:
			"orchard_play": game.start_orchard_activity()
			"hub": show_hub()
			"continue": continue_journey()
			"books": show_books()
			"letters": show_letters()
			"library": show_library()
			"old_journal": game.show_journal()
			"old_quest": game._follow_quest()
			"photo": show_photo()
			"friend_corner": friend_corner.show_wish()
			"discoveries": discovery.show_collection()
			"party": party.show_wish()
			"friends": memories.show_friends()
			"home":
				game._close()
				await game.change_room("home")
				show_home() if str(snapshot().phase)=="home" else show_hub()
			"guide":
				game._close()
				await game._navigate_to_id("actor:npc_bear_uncle",true)
			"take_book":
				State.journey_complete_home_step("H03")
				game.show_map()
			"start","start_walk":
				State.journey_complete_home_step("H04")
				if action=="start": travel_letter("A")
				else: game.show_map()
	return true

func continue_journey() -> void:
	var state := snapshot()
	match str(state.phase):
		"home":
			if game.room!="home": await game.change_room("home")
			show_home()
		"prologue": show_letters()
		"u1":
			var step := str(state.next_u1_step)
			if step=="U1-01" and game.room!="home": await game.change_room("home")
			elif step in ["U1-03","U1-04","U1-05","U1-06","U1-07","U1-08"] and game.room!="school": await game.change_room("school")
			show_u1()
		"u2","u3": p2.show_chapter()
		"p2_complete": party.show_wish()
		_: show_library()

func _handle_u1_action(action: String) -> void:
	match action:
		"01":
			game.play_phrase("good_morning")
			_u1_commit("U1-01",{"completion_mode":"demonstrated"})
		"school":
			game._close()
			await game.change_room("school")
			_u1_commit("U1-02",{"room_id":"school"})
		"name":
			ui.show_panel("journey_name","Hello! 我是……","给游戏里的自己一个称呼","选一个你喜欢的游戏称呼就好。",[{"label":"星星","id":"journey:u1:name:星星","primary":true},{"label":"小叶","id":"journey:u1:name:小叶"},{"label":"小岛朋友","id":"journey:u1:name:小岛朋友"}])
		"05":
			_give_travel_book()
		"06": _u1_commit("U1-06",{"completion_mode":"deferred"})
		"hello": open_hello_story()
		"07:retry":
			_u1_trial("trial_answer",{"answer":"thanks"})
			ui.notify("这是刚见到朋友的情境。可以先说 Hello!；收到帮助时再说 Thank you.")
		"07:hint","07:together":
			if _u1_trial("trial_help",{"level":1 if action=="07:hint" else 2}): show_u1()
		"07:demo":
			if not _u1_trial("trial_help",{"level":3}): return
			show_u1()
			game.play_phrase("hello")
			await get_tree().process_frame
			if _u1_trial("trial_answer",{"answer":"__demonstrated__"}): _finish_u1_trial()
		"07:hello":
			if _u1_trial("trial_answer",{"answer":"hello"}): _finish_u1_trial()
		"return":
			await game.change_room("home")
			show_u1()
		"09":
			if game.room=="home": _u1_commit("U1-09",{"display_room_id":"home","display_marker":"SG_MEMORY_05"})
		_:
			if action.begins_with("name:"):
				u1_nickname = action.trim_prefix("name:")
				_u1_commit("U1-03",{"nickname":u1_nickname,"completion_mode":"supported_choice"})
			elif action.begins_with("decorate:"):
				u1_decoration = action.trim_prefix("decorate:")
				var name_details: Dictionary = snapshot().u1.step_details.get("U1-03",{})
				_u1_commit("U1-04",{"nickname":name_details.get("nickname",u1_nickname),"decoration":u1_decoration})
			elif action.begins_with("photo:"):
				_take_photo(action.trim_prefix("photo:"))

func show_library() -> void:
	active_actor_ids = []
	if not game._prepare_screen(): return
	ui._begin("journey_library","map")
	var book_id := str(snapshot().selected_book_id)
	ui._heading("把熟悉的形象，编成一个词的故事",_book_title(book_id)+" · 词故事库")
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",12)
	ui.panel_box.add_child(filters)
	var search := LineEdit.new()
	search.placeholder_text = "找一个英文词或中文意思"
	search.text = library_query
	search.custom_minimum_size = Vector2(380,48)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(search)
	var units := OptionButton.new()
	units.custom_minimum_size = Vector2(170,48)
	units.add_item("全部单元",0)
	var unit_count := 10
	for book: Dictionary in catalog.get("books",[]):
		if str(book.book_id)==book_id: unit_count = int(book.unit_count)
	for number: int in range(1,unit_count+1): units.add_item("Unit "+str(number),number)
	units.select(0 if library_unit.is_empty() else int(library_unit.trim_prefix("unit-")))
	filters.add_child(units)
	filters.add_child(ui.button("换一本教材","journey:books",false,Vector2(170,48)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(scroll)
	library_grid = GridContainer.new()
	library_grid.columns = 3
	library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_grid.add_theme_constant_override("h_separation",12)
	library_grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(library_grid)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation",12)
	ui.panel_box.add_child(pages)
	library_previous = ui.button("上一页","",false,Vector2(130,46))
	library_previous.pressed.connect(func(): library_page -= 1; _populate_library())
	pages.add_child(library_previous)
	library_counter = ui.label("",17)
	library_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pages.add_child(library_counter)
	library_next = ui.button("下一页","",false,Vector2(130,46))
	library_next.pressed.connect(func(): library_page += 1; _populate_library())
	pages.add_child(library_next)
	pages.add_child(ui.button("返回旅行册","journey:hub",false,Vector2(160,46)))
	var note: Label = ui.label("可选的图像记忆与练习 · 家长提示：故事仍待独立编辑复核，未做口语评分和学习效果验证。",15,Style.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.panel_box.add_child(note)
	search.text_changed.connect(func(value: String):
		library_query = value
		library_page = 0
		_refresh_library_matches()
	)
	units.item_selected.connect(func(index: int):
		library_unit = "" if index==0 else "unit-"+str(index)
		library_page = 0
		_refresh_library_matches()
	)
	_refresh_library_matches()
	ui._layout.call_deferred()

func _u1_trial(kind: String, extra: Dictionary) -> bool:
	var trial: Dictionary = snapshot().p2.trials.get("U1-07",{})
	if trial.is_empty(): return false
	extra.kind=kind
	extra.context="U1-07"
	extra.trial_id=trial.id
	extra.room=game.room
	return State.journey_p2_event(extra)

func _finish_u1_trial() -> void:
	var trial: Dictionary = snapshot().p2.trials["U1-07"]
	_u1_commit("U1-07",{"completion_mode":str(trial.result),"independent":trial.result=="independent_correct","dimension":"written_situation_choice","trial_id":str(trial.id),"spoken_ability_assessed":false})

func _refresh_library_matches() -> void:
	library_matches = Content.list_entries(str(snapshot().selected_book_id),library_unit,library_query)
	_populate_library()

func _populate_library() -> void:
	if not is_instance_valid(library_grid): return
	for child: Node in library_grid.get_children():
		library_grid.remove_child(child)
		child.queue_free()
	var pages := maxi(1,ceili(float(library_matches.size())/12.0))
	library_page = clampi(library_page,0,pages-1)
	for record: Dictionary in library_matches.slice(library_page*12,library_page*12+12):
		var requirements := {"recognition":"认识这个词","listen_speak":"听说目标","listen_speak_read":"听说认读","listen_speak_read_write":"听说读写"}
		var button: Button = ui.button(str(record.spelling_display)+"\n"+str(record.meaning_zh)+" · "+str(requirements.get(record.requirement,"教材目标")),"",false,Vector2(0,88))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var entry_id := str(record.entry_id)
		button.set_meta("entry_id",entry_id)
		button.pressed.connect(func(): open_story(entry_id,false))
		library_grid.add_child(button)
	if library_matches.is_empty(): library_grid.add_child(ui.label("这次没有找到，换一个词试试。",20))
	library_counter.text = "%d 个词表条目 · %d / %d 页" % [library_matches.size(),library_page+1,pages]
	library_previous.disabled = library_page==0
	library_next.disabled = library_page==pages-1

func open_hello_story() -> void:
	for record: Dictionary in Content.list_entries("xiangshao-g3-1","unit-1","hello"):
		if str(record.spelling_display).to_lower()=="hello":
			open_story(str(record.entry_id),true)
			return
	ui.notify("这个故事暂时找不到，可以先参加欢迎合照。")

func open_story(entry_id: String, from_u1: bool = false) -> void:
	var entry := Content.get_entry(entry_id)
	if entry.is_empty():
		ui.notify("词故事暂时无法打开，请先继续小岛生活。")
		return
	if not game._prepare_screen(): return
	# Only the actual spelling/phrase shown by this story touches related revisit targets.
	var exposed_ids: Array = preload("res://scripts/review_progress.gd").targets_in_text([entry.spelling_display])
	for slot: Dictionary in entry.letter_slots:
		for dimension: String in ["case","image"]:
			var id := "letter/"+str(slot.letter).to_upper()+"/"+dimension
			if not exposed_ids.has(id): exposed_ids.append(id)
	if not State.review_expose_ids(exposed_ids): return
	var unit_id := "unit-1" if from_u1 else library_unit
	if unit_id.is_empty(): unit_id = str(entry.source_unit.unit_ids[0])
	var context := {"book_id":str(entry.source_unit.book_id),"unit_id":unit_id,"story_step_id":"U1-06" if from_u1 else "library/"+str(entry.entry_id),"task_mode":"meaning_to_spelling","target_dimension":"orthography","declared_stimulus":"written_meaning: "+str(entry.meaning_zh),"answer_visible_at_start":true}
	var session: Dictionary = State.journey_begin_memory(entry,context)
	if not session.get("ok",false): return
	memory_invocation = str(session.invocation_id)
	memory_from_u1 = from_u1
	memory_sink = MemorySink.new()
	memory_sink.setup(State,memory_invocation)
	ui._begin("word_story","map")
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(host)
	current_memory = load("res://ui/memory_story.gd").new()
	host.add_child(current_memory)
	current_memory.help_shown.connect(func(cue: Dictionary): _queue_memory("cue",cue))
	current_memory.response_submitted.connect(func(response: Dictionary): _queue_memory("response",response))
	current_memory.progress_changed.connect(func(progress: Dictionary): _queue_memory("progress",progress))
	current_memory.close_requested.connect(_on_memory_closed)
	var resume: Dictionary = session.resume_state.duplicate(true)
	if resume.cue_events.is_empty() and resume.seen_beats.is_empty():
		resume.support_level = 5
	current_memory.setup(entry,resume)
	current_memory.set_reduced_motion(ui.reduced_motion)
	ui._layout.call_deferred()

func _on_memory_closed(result: Dictionary) -> void:
	var from_u1 := memory_from_u1
	if result.get("progress") is Dictionary:
		_queue_memory("progress",result.progress)
	if memory_sink==null or not memory_sink.close(str(result.get("result","paused"))):
		ui.notify("学习记录还没保存好。请保留这一页，稍后再试着关闭。")
		return
	memory_invocation = ""
	current_memory = null
	memory_sink = null
	if from_u1:
		_u1_commit("U1-06",{"completion_mode":"optional_story_viewed"})
		show_u1()
	else:
		show_library()

func _queue_memory(kind: String, payload: Dictionary) -> void:
	if memory_sink!=null and not memory_sink.enqueue(kind,payload):
		ui.notify("记录暂未写入，已保留当前步骤；保存恢复后会按顺序重试。")

func _flush_letter_facts() -> bool:
	while not letter_pending.is_empty():
		var event: Dictionary = letter_pending[0]
		if not State.journey_record_letter(event.letter,event.room,event.fact,event.mode): return false
		letter_pending.pop_front()
	return true

func close_memory() -> bool:
	if handoff_busy:
		ui.notify("正在接过旅行册，等朋友把手收好。")
		return false
	if is_instance_valid(letter_activity) and not letter_activity.flush():
		ui.notify("等当前动作完成，就可以离开。")
		return false
	if not _flush_letter_facts(): return false
	if not memory_invocation.is_empty():
		if is_instance_valid(current_memory):
			_queue_memory("progress",current_memory.get_resume())
		if memory_sink==null or not memory_sink.close("paused"):
			ui.notify("记录还没保存好，请先保留这一页。")
			return false
		memory_invocation = ""
	current_memory = null
	memory_sink = null
	return true

func _give_travel_book() -> void:
	if handoff_busy or snapshot().next_u1_step!="U1-05" or game.room!="school": return
	var actor: Node3D = game.living.get_actor("textbook_peter")
	if not actor: return
	await game._navigate_to_id("actor:textbook_peter",false)
	var walk_seconds := 0.0
	while game.room=="school" and is_instance_valid(actor) and game.player.position.distance_to(actor.position)>2.7:
		await get_tree().process_frame
		if not game.application_backgrounded: walk_seconds+=get_process_delta_time()
		if walk_seconds>20 or (walk_seconds>0.5 and game.player.path.is_empty()):
			ui.notify("先走近 Peter，再接过旅行册。")
			show_u1()
			return
	if game.room!="school" or not is_instance_valid(actor): return
	handoff_busy=true
	handoff_contact=false
	active_actor_ids=["textbook_peter"]
	game.pending_interaction={}
	game.player.path.clear()
	game.player.face(actor.global_position)
	actor.face(game.player.global_position)
	ui.show_panel("journey_handoff","Peter 把旅行册递给你","Thank you!","走近朋友，接过旅行册。",[])
	var old_camera: Transform3D = game.camera.transform
	var old_size: float = game.camera.size
	var center: Vector3 = (actor.position+game.player.position)/2.0
	game.camera.position=center+game.camera_offset
	game.camera.look_at(center+Vector3.UP,Vector3.UP)
	game.camera.size=8.5
	actor.set_held_prop("travel_book")
	var contact_callback := func(_id: String, action: String, key: String, invocation: int, socket: Transform3D):
		if action!="give_item" or key!="u1-help-book" or invocation!=handoff_invocation: return
		handoff_contact=true
		game.player.gesture("reach")
		var book: Node3D = actor._held_prop
		if not is_instance_valid(book): return
		book.reparent(game.world,true)
		actor._held_prop=null
		actor._held_prop_id=""
		book.global_transform=socket
		var elapsed := 0.0
		var origin := book.global_position
		while elapsed<0.45 and is_instance_valid(book):
			await get_tree().process_frame
			if game.application_backgrounded: continue
			elapsed+=get_process_delta_time()
			var skeleton: Skeleton3D = game.player.visual.skeleton
			var hand: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("LowerArm_R"))
			var endpoint := hand*Vector3(0,-0.26,0)
			book.global_position=origin.lerp(endpoint,smoothstep(0,0.45,elapsed))
		if is_instance_valid(book):
			var attachment := BoneAttachment3D.new()
			attachment.bone_name="LowerArm_R"
			game.player.visual.skeleton.add_child(attachment)
			book.reparent(attachment,false)
			book.transform=Transform3D(Basis.IDENTITY,Vector3(0,-0.26,0))
	actor.action_contact.connect(contact_callback)
	game.living.play_actor_action("textbook_peter","give","u1-help-book")
	handoff_invocation=int(actor.get_action_phase().invocation_id)
	while is_instance_valid(actor) and not bool(actor.get_action_phase().complete): await get_tree().process_frame
	if is_instance_valid(actor) and actor.action_contact.is_connected(contact_callback): actor.action_contact.disconnect(contact_callback)
	game.camera.transform=old_camera
	game.camera.size=old_size
	handoff_busy=false
	if handoff_contact:
		_u1_commit("U1-05",{"completion_mode":"supported_response","contact_seen":true,"action":"give_item","action_invocation":handoff_invocation,"recovery_seen":true})
	else:
		ui.notify("刚才没接稳，再试着接一次。")
		show_u1()
