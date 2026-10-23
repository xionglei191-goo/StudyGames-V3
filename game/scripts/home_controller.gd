extends Node
## A household activity is a reversible prop sequence, recorded separately from English learning.

const Catalog = preload("res://scripts/home_catalog.gd")
var game: Node3D
var _task_room := ""
var _task_id := ""
var _step := 0
var _sequence := 0

func setup(host: Node3D) -> void:
	game = host

func handles_room() -> bool:
	return game.room in Catalog.ROOMS

func cancel_task() -> void:
	_task_room = ""
	_task_id = ""
	_step = 0
	refresh_visuals()

func refresh_visuals() -> void:
	if not is_instance_valid(game.world) or not handles_room(): return
	var plan: Dictionary = Catalog.room(game.room)
	var done := bool(State.data.life.get("home_tasks", {}).get(str(plan.task.id), false))
	_set_visual("after" if done else "before")

func _set_visual(state: String) -> void:
	for node: Node in game.world.find_children("HOME_TASK_*", "Node3D", true, false):
		(node as Node3D).visible = str(node.name) == "HOME_TASK_" + state.to_upper()

func show_memory(sequence: int) -> void:
	if not handles_room() or sequence < 1 or sequence > 5: return
	cancel_task()
	_sequence = sequence
	var plan: Dictionary = Catalog.room(game.room)
	var anchor: Dictionary = plan.anchors[sequence - 1]
	var source: Dictionary = anchor.source
	State.discover(game.room, sequence)
	var actions: Array = []
	if sequence == int(plan.task.anchor):
		actions.append({"label":str(plan.task.title), "id":"home:begin", "primary":true})
	if source.has("audio"):
		actions.append({"label":"听一听这句英语", "id":"home:audio:%d" % sequence})
	if game.room == "home" and sequence == 2:
		actions.append({"label":"装扮客厅", "id":"decorate"})
	if game.room == "home_bedroom" and sequence == 3:
		actions.append({"label":"挑选今天的穿搭", "id":"home:outfit"})
	if game.room == "home_bedroom" and sequence == 5:
		actions.append({"label":"睡到明天", "id":"next_day"})
	if game.room == "home_study" and sequence == 5:
		actions.append({"label":"画一张贺卡", "id":"activity:art"})
	if game.room == "home" and sequence == 4:
		actions.append({"label":"去卧室休息", "id":"home:bedroom"})
	var visited := 0
	for i in range(1, 6):
		if State.data.life.discoveries.has("%s/memory_%02d" % [game.room, i]): visited += 1
	var done := bool(State.data.life.get("home_tasks", {}).get(str(plan.task.id), false))
	var body: String = str(anchor.activity) + "\n\n" + str(source.text)
	if sequence == int(plan.task.anchor) and done:
		body += "\n\n" + str(plan.task.result) + "  可以再做一次。"
	actions.append({"label":"看看课本出处", "id":"home:source:%d" % sequence})
	actions.append({"label":"继续逛逛", "id":"close"})
	game.ui.show_panel("memory", str(anchor.label), "%s · 已发现 %d / 5" % [plan.name, visited], body, actions)

func show_overview() -> void:
	if not handles_room(): return
	cancel_task()
	var actions: Array = []
	if game.room == "home_estate":
		actions.append({"label":"走到正门 · 进屋", "id":"navigate:house_entry", "primary":true})
	else:
		actions.append({"label":"回到家门前的小院", "id":"navigate:home_exit", "primary":true})
	actions.append({"label":"看看今天能做什么", "id":"home:day"})
	actions.append({"label":"打开家园地图", "id":"map"})
	game.ui.show_panel("home_overview", "每个房间都有自己的生活", "我的家 · 小院与七个房间", "穿过小院，走到住宅正门。进门后再选择想去的房间。\n从房间出来，会回到家门前的小院。", actions)

func _at_front_door() -> bool:
	if game.room != "home_estate" or game.loading_room: return false
	for entry: Dictionary in game.interactions:
		if str(entry.id) == "house_entry":
			var delta: Vector3 = game.player.position - entry.position
			return Vector2(delta.x, delta.z).length() <= float(entry.radius)
	return false

func show_entry() -> void:
	if not _at_front_door():
		game.ui.notify("先走到住宅正门，再进屋看看。")
		return
	cancel_task()
	var actions: Array = []
	for child_id: String in Catalog.ROOMS:
		if child_id == "home_estate": continue
		var plan: Dictionary = Catalog.room(child_id)
		actions.append({"label":str(plan.name) + "\n" + str(plan.task.title), "id":"home:enter:" + child_id, "primary":child_id == "home"})
	actions.append({"label":"先回小院逛逛", "id":"close"})
	game.ui.show_panel("home_entry", "欢迎回家", "住宅正门 · 想去哪个房间？", "客厅、卧室和厨房都在屋里。选一个房间，开始今天的小生活。", actions)
	# Keep all seven rooms visible together while retaining the production theme.
	for node: Node in game.ui.panel_box.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.get_parent() is GridContainer: continue
		button.custom_minimum_size.y = 74
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBox
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			button.add_theme_stylebox_override(state, style)

func _enter_room(room_id: String) -> void:
	if room_id == "home_estate" or room_id not in Catalog.ROOMS: return
	if not _at_front_door() or game.ui.current_panel != "home_entry": return
	await game.change_room(room_id)

func show_day() -> void:
	cancel_task()
	var lines: Array[String] = []
	for entry: Dictionary in Catalog.all().rooms:
		var done := bool(State.data.life.home_tasks.get(str(entry.task.id), false))
		lines.append(("✓ " if done else "○ ") + str(entry.name) + "：" + str(entry.task.title))
	game.ui.show_panel("home_day", "在家的一天", "想做哪件，就从哪件开始", "\n".join(lines), [{"label":"看看家园地图", "id":"map", "primary":true}, {"label":"继续散步", "id":"close"}], "这里记录生活体验，不催促完成，也不作为英语能力评分。")

func _show_task() -> void:
	var plan: Dictionary = Catalog.room(_task_room)
	var task: Dictionary = plan.task
	game.ui.show_panel("home_task", str(task.title), "%s · %d / %d" % [plan.name, _step + 1, task.steps.size()], str(task.steps[_step]), [{"label":str(task.steps[_step]), "id":"home:step", "primary":true}, {"label":"先放下，等会儿再做", "id":"close"}])

func _begin_task() -> void:
	var plan: Dictionary = Catalog.room(game.room)
	if plan.is_empty() or _sequence != int(plan.task.anchor): return
	var marker: Node3D = game.metadata.get("marker_nodes", {}).get("SG_MEMORY_%02d" % _sequence)
	if not is_instance_valid(marker) or Vector2(game.player.position.x, game.player.position.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z)) > 2.6:
		game.ui.notify("先走到这件物品旁边，再动手试一试。")
		return
	_task_room = game.room
	_task_id = str(plan.task.id)
	_step = 0
	_set_visual("before")
	_show_task()

func _advance_task() -> void:
	if _task_id.is_empty() or _task_room != game.room or game.ui.current_panel != "home_task": return
	var plan: Dictionary = Catalog.room(_task_room)
	_step += 1
	game.player.gesture("give" if _step == 3 else "take")
	game.sounds.play("place")
	if _step < plan.task.steps.size():
		_set_visual("middle")
		_show_task()
		return
	if not State.complete_home_task(_task_id, _task_room):
		cancel_task()
		game.ui.show_panel("home_task", "这次还没有保存", "可以稍后再试", "原有生活记录已保留。", [{"label":"返回物品旁", "id":"home:memory:%d" % _sequence}])
		return
	_task_room = ""
	_task_id = ""
	_step = 0
	refresh_visuals()
	show_memory(_sequence)

func handle_action(id: String) -> bool:
	if not id.begins_with("home:"): return false
	if not handles_room(): return true
	var parts := id.split(":")
	if parts.size() < 2: return true
	match parts[1]:
		"begin": _begin_task()
		"step": _advance_task()
		"overview": show_overview()
		"enter":
			if parts.size() == 3: await _enter_room(parts[2])
		"day": show_day()
		"memory":
			if parts.size() == 3: show_memory(int(parts[2]))
		"outfit": game.ui.show_inventory(State.data)
		"bedroom":
			cancel_task()
			if game.room == "home":
				await game.change_room("home_estate", "house_entry")
			show_entry()
		"audio", "source":
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
