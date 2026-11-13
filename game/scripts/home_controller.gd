extends Node
## Household work happens in the room, recorded separately from English learning.

const Catalog = preload("res://scripts/home_catalog.gd")
const CardContent = preload("res://ui/memory_card_content.gd")
const TASK_LABELS := {"home_estate":"浇一浇", "home":"摆茶几", "home_bedroom":"理床铺", "home_kitchen":"洗蔬菜", "home_dining":"摆餐桌", "home_bathroom":"洗洗手", "home_study":"收好书", "home_balcony":"晾袜子"}
var game: Node3D
var _task_room := ""
var _task_id := ""
var _sequence := 0
var activity: Node3D

func setup(host: Node3D) -> void:
	game = host

func handles_room() -> bool:
	return Catalog.is_home_space(game.room)

func cancel_task() -> void:
	if is_instance_valid(activity):
		activity.stop()
		activity.queue_free()
	activity = null
	_task_room = ""
	_task_id = ""
	refresh_visuals()

func is_active() -> bool:
	return is_instance_valid(activity)

func handle_input(event: InputEvent) -> bool:
	if not is_active(): return false
	activity.handle_input(event)
	return true

func refresh_visuals() -> void:
	if not is_instance_valid(game.world) or game.room not in Catalog.ROOMS: return
	preload("res://activities/household_props.gd").prepare_room(game.world,game.room)
	var plan: Dictionary = Catalog.room(game.room)
	var done := bool(State.data.life.get("home_tasks", {}).get(str(plan.task.id), false))
	_set_visual("after" if done else "before")

func _set_visual(state: String) -> void:
	for node: Node in game.world.find_children("HOME_TASK_*", "Node3D", true, false):
		(node as Node3D).visible = str(node.name) == "HOME_TASK_" + state.to_upper()

func show_memory(sequence: int) -> void:
	if game.room not in Catalog.ROOMS or sequence < 1 or sequence > 5: return
	cancel_task()
	_sequence = sequence
	var plan: Dictionary = Catalog.room(game.room)
	var anchor: Dictionary = plan.anchors[sequence - 1]
	State.discover(game.room, sequence)
	var actions: Array = []
	if sequence == int(plan.task.anchor):
		actions.append({"label":str(TASK_LABELS.get(game.room, "做一做")), "id":"home:begin", "primary":true})
	if game.room == "home" and sequence == 2:
		actions.append({"label":"装扮", "id":"decorate", "primary":true})
	if game.room == "home_bedroom" and sequence == 3:
		actions.append({"label":"换衣服", "id":"home:outfit", "primary":true})
	if game.room == "home_bedroom" and sequence == 5:
		actions.append({"label":"睡一觉", "id":"next_day", "primary":true})
	if game.room == "home_study" and sequence == 5:
		actions.append({"label":"画一画", "id":"activity:art", "primary":true})
	if game.room == "home" and sequence == 4:
		actions.append({"label":"去休息", "id":"home:bedroom", "primary":true})
	var visited := 0
	for i in range(1, 6):
		if State.data.life.discoveries.has("%s/memory_%02d" % [game.room, i]): visited += 1
	var done := bool(State.data.life.get("home_tasks", {}).get(str(plan.task.id), false))
	var content := CardContent.build(plan, anchor)
	if sequence == int(plan.task.anchor) and done:
		content.hint += "\n" + str(plan.task.result) + "  可以再做一次。"
	actions.append({"label":"退出", "id":"close"})
	game.ui.show_memory_card(game, str(anchor.label), "%s · 已发现 %d / 5" % [plan.name, visited], content, actions)

func show_overview() -> void:
	if not handles_room(): return
	cancel_task()
	var actions: Array = []
	if game.room == "home_estate":
		actions.append({"label":"走到家门前", "id":"navigate:house_entry", "primary":true})
	elif game.room == "home":
		actions.append({"label":"看看室内地图", "id":"map", "primary":true})
		actions.append({"label":"走到通往小院的门", "id":"navigate:courtyard_exit"})
	else:
		actions.append({"label":"走回客厅", "id":"navigate:home_exit", "primary":true})
	actions.append({"label":"看看今天能做什么", "id":"home:day"})
	if game.room in ["home", "home_estate", "home_bedroom", "home_study"]:
		actions.append({"label":"✨ 动森自由网格布置", "id":"v4_free_decor"})
		actions.append({"label":"生活工坊 · 我的作品与小摊", "id":"creation"})
	if game.room != "home": actions.append({"label":"打开家园地图", "id":"map"})
	game.ui.show_panel("home_overview", "每个房间都有自己的生活", "我的家 · 小院与七个房间", "推开家门就是客厅。\n沿客厅两侧走到书房、卧室、浴室、厨房、餐厅和阳台门前，按 E 进入。离开房间会回到客厅对应的门边。", actions)

func show_day() -> void:
	cancel_task()
	var lines: Array[String] = []
	for entry: Dictionary in Catalog.all().rooms:
		var done := bool(State.data.life.home_tasks.get(str(entry.task.id), false))
		lines.append(("✓ " if done else "○ ") + str(entry.name) + "：" + str(entry.task.title))
	game.ui.show_panel("home_day", "在家的一天", "想做哪件，就从哪件开始", "\n".join(lines), [{"label":"看看家园地图", "id":"map", "primary":true}, {"label":"继续散步", "id":"close"}], "这里记录生活体验，不催促完成，也不作为英语能力评分。")

func _begin_task() -> void:
	if is_active(): return
	if game.room not in Catalog.ROOMS: return
	var plan: Dictionary = Catalog.room(game.room)
	if plan.is_empty() or _sequence != int(plan.task.anchor): return
	var marker: Node3D = game.metadata.get("marker_nodes", {}).get("SG_MEMORY_%02d" % _sequence)
	if not is_instance_valid(marker) or Vector2(game.player.position.x, game.player.position.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z)) > 2.6:
		game.ui.notify("先走到这件物品旁边，再动手试一试。")
		return
	_task_room = game.room
	_task_id = str(plan.task.id)
	activity = preload("res://activities/household_activity.gd").new()
	add_child(activity)
	activity.setup(game, plan)
	activity.leave_requested.connect(cancel_task)

func handle_action(id: String) -> bool:
	if not id.begins_with("home:"): return false
	if not handles_room(): return true
	var parts := id.split(":")
	if parts.size() < 2: return true
	match parts[1]:
		"begin": _begin_task()
		"overview": show_overview()
		"day": show_day()
		"memory":
			if parts.size() == 3: show_memory(int(parts[2]))
		"outfit": game.ui.show_inventory(State.data)
		"bedroom":
			cancel_task()
			game._navigate_to_id("home_bedroom_gate", true)
		"audio", "source":
			if game.room not in Catalog.ROOMS: return true
			if parts.size() != 3: return true
			var sequence := int(parts[2])
			if sequence < 1 or sequence > 5: return true
			var source: Dictionary = Catalog.room(game.room).anchors[sequence - 1].source
			if parts[1] == "audio" and source.has("audio"):
				game.voice.stream = load(str(source.audio)) as AudioStream
				if not game.muted: game.voice.play()
			elif parts[1] == "source":
				game.ui.show_panel("home_source", str(source.unit_title), "%s · %s · 第 %s 页" % [source.book_title, str(source.unit_id).replace("unit-", "Unit "), str(source.printed_page)], str(source.text), [{"label":"回到生活物品", "id":"home:memory:%d" % sequence}], "课本表达用于这个原创生活场景；听过和做过不会自动记作掌握。")
	return true
