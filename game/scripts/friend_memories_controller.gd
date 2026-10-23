extends Node
## Read-only conversations from saved life events. No social scores or learning trials.
const Chapter = preload("res://scripts/p2_progress.gd")
const Style = preload("res://ui/island_theme.gd")
const FRIENDS := {
	"npc_bear_uncle":{"name":"熊叔","room":"home","place":"家门旁"},
	"npc_rabbit_gardener":{"name":"兔兔","room":"landmark_F","place":"花园"},
	"textbook_lingling":{"name":"Lingling","room":"school","place":"校园"},
	"textbook_peter":{"name":"Peter","room":"school","place":"校园"},
	"textbook_anne":{"name":"Anne","room":"school","place":"校园"},
	"textbook_tim":{"name":"Tim","room":"landmark_M","place":"邻居屋"},
	"textbook_mingming":{"name":"Mingming","room":"classroom","place":"教室"},
	"textbook_dongdong":{"name":"Dongdong","room":"classroom","place":"教室"}
}
const U1_ACTORS := {
	"U1-01":["npc_bear_uncle"], "U1-02":["npc_bear_uncle"],
	"U1-03":["textbook_lingling"], "U1-04":["textbook_lingling"],
	"U1-05":["textbook_peter"], "U1-06":["textbook_peter"],
	"U1-07":["textbook_anne"],
	"U1-08":["textbook_lingling","textbook_peter","textbook_anne"],
	"U1-09":["npc_bear_uncle"], "U1-10":["npc_rabbit_gardener"]
}
const DISTRICTS := {"morning_village":"晨光村", "craft_street":"巧手街", "woodland_village":"林间村", "hill_academy_district":"山丘学园", "bay_travel_district":"海湾远行区"}
const SEAT_NAMES := {"seat_1":"1号椅", "seat_2":"2号椅", "seat_3":"3号椅", "seat_4":"4号椅"}
var journey: Node
var game: Node3D
var ui: CanvasLayer

func setup(owner_journey: Node) -> void:
	journey = owner_journey
	game = owner_journey.game
	ui = owner_journey.ui

func _section(value: Dictionary, key: String) -> Dictionary:
	var item: Variant = value.get(key,{})
	return item if item is Dictionary else {}

func _has_step(snapshot: Dictionary, unit: String, step: String) -> bool:
	var section := _section(snapshot,"u1") if unit == "1" else _section(_section(_section(snapshot,"p2"),"chapters"),unit)
	return section.get("steps",[]).has(step)

func known_friend(actor_id: String, snapshot: Dictionary) -> bool:
	if not FRIENDS.has(actor_id): return false
	match actor_id:
		"npc_bear_uncle": return snapshot.get("home_steps",[]).has("H01") or _has_step(snapshot,"1","U1-01")
		"npc_rabbit_gardener":
			var orchard := _section(_section(snapshot,"experiences"),"orchard_pick")
			var transfer := _section(_section(_section(snapshot,"p2"),"trials"),"U1-10")
			return bool(orchard.get("completed_once",false)) or str(orchard.get("stage","ready")) != "ready" or (bool(transfer.get("completed",false)) and str(transfer.get("result","")) in ["independent_correct","supported_correct","demonstrated"])
		"textbook_lingling": return _has_step(snapshot,"1","U1-03") or _has_step(snapshot,"2","U2-02")
		"textbook_peter": return _has_step(snapshot,"1","U1-05")
		"textbook_anne": return _has_step(snapshot,"1","U1-07") or _has_step(snapshot,"2","U2-05") or _has_step(snapshot,"3","U3-06")
		"textbook_tim": return _has_step(snapshot,"2","U2-03") or _has_step(snapshot,"3","U3-04")
		"textbook_mingming": return _has_step(snapshot,"3","U3-02")
		"textbook_dongdong": return _has_step(snapshot,"3","U3-03")
	return false

func task_owns_actor(actor_id: String, snapshot: Dictionary) -> bool:
	var phase := str(snapshot.get("phase",""))
	if phase == "home": return actor_id == "npc_bear_uncle"
	if phase == "u1": return U1_ACTORS.get(str(snapshot.get("next_u1_step","")),[]).has(actor_id)
	if phase in ["u2","u3"]:
		var p2 := _section(snapshot,"p2")
		if not p2.has("chapters"): return false
		var number := Chapter.next_chapter(p2)
		if number != 0 and str(Chapter.next_step(p2,number).get("actor","")) == actor_id: return true
	var trial := _section(_section(_section(snapshot,"p2"),"trials"),"U1-10")
	return actor_id == "npc_rabbit_gardener" and not trial.is_empty() and not bool(trial.get("completed",false))

func _real_photo(snapshot: Dictionary) -> bool:
	var photo := _section(_section(snapshot,"u1"),"photo")
	var path := str(_section(photo,"details").get("image_path",""))
	return bool(photo.get("created",false)) and not path.is_empty() and FileAccess.file_exists(path)

func _displayed_discovery(snapshot: Dictionary) -> Dictionary:
	var discovery := _section(_section(snapshot,"p2"),"discovery")
	var display := _section(discovery,"display")
	var letter := str(display.get("card",""))
	var card := _section(_section(discovery,"cards"),letter)
	if not card.is_empty() and float(card.get("confirmed_at",0.0)) > 0.0:
		return {"kind":"card","id":letter,"label":letter+letter.to_lower()+" 旅行卡"}
	var district := str(display.get("page",""))
	var page := _section(_section(discovery,"pages"),district)
	if not page.is_empty() and float(page.get("confirmed_at",0.0)) > 0.0:
		return {"kind":"page","id":district,"label":str(DISTRICTS.get(district,"小岛"))+"纪念页"}
	return {}

func memory_for(actor_id: String, snapshot: Dictionary) -> Dictionary:
	if not known_friend(actor_id,snapshot): return {}
	var result := {"actor":actor_id,"name":FRIENDS[actor_id].name,"room":FRIENDS[actor_id].room,"stage":"first_days","title":"又见面了","text":"","action":"hub","action_label":"打开旅行册","facts":[]}
	var p2 := _section(snapshot,"p2")
	var corner := _section(p2,"friend_corner")
	var photo := _real_photo(snapshot)
	match actor_id:
		"npc_bear_uncle":
			result.text = "还记得你第一次来家门旁打招呼。今天想去哪儿走走？"
			if snapshot.get("home_steps",[]).has("H03"):
				result.text = "你已经带上旅行册了。哪一站让你想再去看看？我就在家门旁。"
				result.facts.append("travel_book")
			if _has_step(snapshot,"2","U2-04"):
				result.text = "你把给 Lingling 和 Tim 的两张邀请送进了信格。那些小小的心意，我记着呢。"
				result.action = "corner"
				result.action_label = "回家看看朋友角"
				result.stage = "invitations"
		"npc_rabbit_gardener":
			var orchard := _section(_section(snapshot,"experiences"),"orchard_pick")
			if bool(orchard.get("completed_once",false)):
				result.text = "你把苹果送进篮子的那一趟，我记着呢。今天想再去果园看看，还是先在花园走走？"
				result.facts.append("orchard_deposited")
			elif str(orchard.get("stage","ready")) == "carrying":
				result.text = "上次的苹果已经摘下来了，还等着送进篮子。想继续时，我们再回果园。"
				result.facts.append("orchard_carrying")
			else:
				result.text = "我们在花园打过招呼了。你再来时，可以坐一会儿，也可以去看看苹果树。"
			result.action = "orchard"
			result.action_label = "去果园接着玩"
		"textbook_peter":
			result.text = "你收下的那本旅行册还带着吗？可以翻翻走过的地方，再选一站去散步。"
			result.facts.append("travel_book_gift")
		"textbook_anne":
			result.text = "还记得那天我们在校园打招呼。今天也很高兴见到你。"
			if _has_step(snapshot,"2","U2-05"):
				result.text = "上次你送完邀请，我们在校园道了别。今天又见面啦！想先聊聊哪段小回忆？"
				result.stage = "invitations"
				result.facts.append("campus_goodbye")
		"textbook_lingling", "textbook_tim":
			result.text = "还记得我们互相认识的那一天。今天也一起在小岛上走走吧。"
			if p2.get("mail",[]).has(actor_id):
				var cover := str({"plain":"邀请","flowers":"花朵邀请","star":"星星邀请"}.get(_section(corner,"invitation_styles").get(actor_id,"plain"),"邀请"))
				result.text = "你送来的"+cover+"我收好了。谢谢你想到我！"
				result.stage = "invitations"
				result.facts.append("invitation:"+str(_section(corner,"invitation_styles").get(actor_id,"plain")))
				result.action = "corner"
				result.action_label = "看看邀请和回信"
				var position := str(_section(_section(corner,"layout"),"positions").get(actor_id,""))
				if not position.is_empty():
					result.text += " 我的回信也在你的朋友角有了位置。"
					result.facts.append("reply_displayed:"+position)
		"textbook_mingming":
			result.text = "你给我的欢迎会角色卡选过年龄贴。卡上写着 8，我们可以回去翻翻那一页。"
			result.action = "keepsakes"
			result.action_label = "看看我们的角色卡"
			result.facts.append("age_card:8")
		"textbook_dongdong":
			result.text = "我的欢迎会角色卡上是 9。你把这位来客的那一页也留在旅行册里了。"
			result.action = "keepsakes"
			result.action_label = "看看我们的角色卡"
			result.facts.append("age_card:9")
	if photo and actor_id in ["textbook_lingling","textbook_peter","textbook_anne"]:
		var frame := str(_section(_section(_section(snapshot,"u1"),"photo"),"details").get("frame","yellow"))
		result.text += "\n我们那张合照还在，"+("晴空蓝" if frame == "blue" else "暖黄色")+"的相框很显眼。"
		result.action = "photo"
		result.action_label = "一起看看合照"
		result.facts.append("real_photo:"+frame)
	var prepared := bool(_section(_section(p2,"chapters"),"3").get("completed",false))
	var party := _section(p2,"party")
	var memory := _section(party,"memory")
	var watched := str(memory.get("id","")) == "party-memory-v1" and int(memory.get("views",0)) > 0
	if prepared and actor_id in ["npc_bear_uncle","textbook_anne","textbook_mingming","textbook_dongdong","textbook_tim"]:
		result.stage = "table_ready"
		result.text += "\n欢迎桌的准备已经完成了，接下来可以选桌面的样子，给大家摆好椅子。"
		result.action = "party"
		result.action_label = "去看看欢迎桌"
		result.facts.append("table_prepared")
		if watched:
			var layout := _section(memory,"layout")
			var theme := "星星" if str(layout.get("theme","flowers")) == "star" else "花朵"
			var seat := str(_section(layout,"seats").get(actor_id,""))
			result.stage = "party_memory"
			result.text = ("那次聚会，我坐在"+str(SEAT_NAMES[seat])+"。" if SEAT_NAMES.has(seat) else "那次聚会的纪念已经收好了。")+"你选了"+theme+"桌面。想再回去看看吗？"
			result.action_label = "回看那次聚会"
			result.facts.append("party_watched:"+theme+":"+seat)
		elif float(party.get("confirmed_at",0.0)) > 0.0:
			var layout := _section(party,"layout")
			var theme := "星星" if str(layout.get("theme","flowers")) == "star" else "花朵"
			var seat := str(_section(layout,"seats").get(actor_id,""))
			result.text = "你已经摆好了"+theme+"桌面。"+("我的位置是"+str(SEAT_NAMES[seat])+"。" if SEAT_NAMES.has(seat) else "椅子也留在你确认的位置。")+"等你想开始时，再一起看看。"
			result.facts.append("party_arranged")
	var discovery := _displayed_discovery(snapshot)
	if not discovery.is_empty() and actor_id in ["npc_bear_uncle","npc_rabbit_gardener","textbook_peter","textbook_anne"]:
		result.text += "\n你把"+str(discovery.label)+"摆在家里了。回去看看，就能想起那一站。"
		result.facts.append("discovery_displayed:"+str(discovery.kind)+":"+str(discovery.id))
		result["discovery_action"] = true
	return result

func should_use_corner(actor_id: String, snapshot: Dictionary) -> bool:
	if actor_id not in ["textbook_lingling","textbook_tim"]: return false
	# Tim's newer shared event is the default; his invitation remains a separate topic.
	return actor_id != "textbook_tim" or str(memory_for(actor_id,snapshot).get("stage","")) != "party_memory"

func handles_actor(actor_id: String) -> bool:
	if not FRIENDS.has(actor_id) or not is_instance_valid(game.living): return false
	var snapshot: Dictionary = journey.snapshot()
	if task_owns_actor(actor_id,snapshot) or not known_friend(actor_id,snapshot): return false
	if journey.handoff_busy or game.capturing_photo: return false
	if should_use_corner(actor_id,snapshot) and journey.friend_corner.handles_actor(actor_id): return true
	return show_friend(actor_id)

func visit_friend(actor_id: String) -> void:
	var snapshot: Dictionary = journey.snapshot()
	if not known_friend(actor_id,snapshot): return
	if task_owns_actor(actor_id,snapshot):
		if actor_id == "npc_rabbit_gardener": journey.p2.show_transfer()
		else: journey.continue_journey()
		return
	if not game._prepare_screen(): return
	var room := str(FRIENDS[actor_id].room)
	if game.room != room: await game.change_room(room)
	if not await journey.p2.ensure_actor(actor_id): return
	if task_owns_actor(actor_id,journey.snapshot()): journey.continue_journey(); return
	handles_actor(actor_id)

func show_friends() -> void:
	if not game._prepare_screen(): return
	ui._begin("journey_friends","map")
	ui._heading("去看看老朋友","我们一起做过的小事，朋友都记着")
	var snapshot: Dictionary = journey.snapshot()
	var scroll := ScrollContainer.new()
	scroll.name = "FriendMemoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 270
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.panel_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	var first: Button
	for actor_id: String in FRIENDS:
		if not known_friend(actor_id,snapshot): continue
		var record := memory_for(actor_id,snapshot)
		var label := "去见 "+str(record.name)+" · "+str(FRIENDS[actor_id].place)
		if task_owns_actor(actor_id,snapshot): label = "和 "+str(record.name)+" 接着完成眼前的事"
		var button := _button(list,label,visit_friend.bind(actor_id),false,"MemoryVisit_"+actor_id)
		if first == null: first = button
	if first == null: _text(list,"先去家门旁和熊叔打个招呼。结识的朋友会留在这里。")
	var back := _button(ui.panel_box,"回到旅行册",journey.show_hub,true,"FriendsBack")
	_finish(first if first != null else back)

func show_friend(actor_id: String) -> bool:
	var snapshot: Dictionary = journey.snapshot()
	if task_owns_actor(actor_id,snapshot): return false
	var record := memory_for(actor_id,snapshot)
	var actor: Node3D = game.living.get_actor(actor_id)
	if record.is_empty() or actor == null or not game._prepare_screen(): return false
	journey.active_actor_ids = [actor_id]
	game.conversation_position = actor.position
	actor.face(game.player.position)
	game.living.play_actor_action(actor_id,"talk")
	ui._begin("friend_memory","dialogue")
	ui._heading(str(record.name)+" · 又见面了","朋友之间的小回忆")
	_text(ui.panel_box,str(record.text))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	ui.panel_box.add_child(actions)
	var first := _button(actions,str(record.action_label),_open_memory.bind(str(record.action)),true,"MemoryRecall")
	if actor_id == "textbook_tim" and str(record.stage) == "party_memory":
		_button(actions,"聊聊那封邀请",_open_invitation.bind(actor_id),false,"MemoryInvitation")
	if bool(record.get("discovery_action",false)): _button(actions,"看看旅行作品",_open_memory.bind("discoveries"),false,"MemoryDiscovery")
	_button(actions,"看看别的朋友",show_friends,false,"MemoryFriends")
	_button(actions,"继续散步",game._close,false,"MemoryGoodbye")
	_finish(first)
	return true

func _open_invitation(actor_id: String) -> void:
	if game.room == str(FRIENDS[actor_id].room):
		journey.friend_corner.show_friend(actor_id)
	else:
		# A direct classroom conversation can also reach the original, location-bound topic.
		journey.friend_corner.visit_friend(actor_id)

func _open_memory(action: String) -> void:
	match action:
		"photo": journey.show_photo()
		"corner":
			if game.room != "home": await game.change_room("home")
			journey.friend_corner.show_wish()
		"keepsakes": journey.p2.show_keepsakes()
		"party": journey.party.show_wish()
		"discoveries":
			if game.room != "home": await game.change_room("home")
			journey.discovery.show_collection()
		"orchard": game.start_orchard_activity()
		_: journey.show_hub()

func _text(parent: Node, value: String) -> void:
	var label: Label = ui.label(value,22,Style.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _button(parent: Node, value: String, callback: Callable, primary: bool, node_name: String) -> Button:
	var button: Button = ui.button(value,"",primary,Vector2(0,46))
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _finish(first: Button) -> void:
	ui._layout.call_deferred()
	if is_instance_valid(first): ui._focus_if_current.call_deferred(first.get_instance_id())
