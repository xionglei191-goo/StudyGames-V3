extends Node3D
## Direct manipulation in the existing room. Only completed, saved work becomes durable.
signal leave_requested
signal finished
const Props = preload("res://activities/household_props.gd")
const Hud = preload("res://ui/household_hud.gd")
const Style = preload("res://ui/island_theme.gd")
const TASK_ENGLISH := {
	"set_dinner": "Let's set the mats, plates, and cups!",
	"welcome_table": "Let's set the tea cups and fruit plate!",
	"make_bed": "Fold the soft quilt and make the bed!",
	"tidy_books": "Put the picture books back neatly!",
	"hang_laundry": "Hang the clean socks in the sun!",
	"wash_vegetables": "Wash the fresh green vegetables!",
	"wash_hands": "Wash your hands with soap and water!",
	"water_garden": "Water the colourful garden flowers!",
}
var game: Node3D
var task: Dictionary
var task_id := ""
var camera_focus := Vector3.ZERO
var camera_size := 6.0
var items: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var stage := 0
var stage_count := 1
var completed := false
var ready_to_save := false
var hud: Control
var dragged := -1
var pointer := Vector2.ZERO
var drag_plane := Plane()
var drag_offset := Vector3.ZERO
var pressed := false
var water_on := false
var water: Node3D
var tap: Node3D
var tap_point := Vector3.ZERO
var sink := Vector3.ZERO
var soap: Node3D
var hands: Node3D
var bubbles: Node3D
var scrub := 0.0
var rinse := 0.0
var clock := 0.0
var wrinkles: Array[MeshInstance3D] = []
var soil: Array[Dictionary] = []
var _hidden: Array[Dictionary] = []
var _stopped := false
var _feedback := ""
var _feedback_until := 0.0

func setup(host: Node3D, plan: Dictionary) -> void:
	game = host
	task = plan.task
	task_id = str(task.id)
	name = "HouseholdActivity"
	game._cancel_navigation()
	game.ui.close_panel()
	game.voice.stop()
	game.feedback.highlight({})
	for node in [game.ui.hud, game.ui.prompt, game.ui.controls_hint, game.ui.bubble_panel, game.player.visual]:
		_hidden.append({"node":node, "visible":node.visible})
		node.hide()
	if is_instance_valid(game.ui.diegetic): game.ui.diegetic.dismiss()
	match task_id:
		"set_dinner": _build_dinner()
		"welcome_table": _build_tea()
		"make_bed": _build_bed()
		"tidy_books": _build_books()
		"hang_laundry": _build_laundry()
		"wash_vegetables", "wash_hands": _build_washing()
		"water_garden": _build_garden()
	for group: Node3D in game.world.find_children("HOME_TASK_*", "Node3D", true, false): group.hide()
	hud = Hud.new()
	game.ui.root.add_child(hud)
	hud.leave_requested.connect(func(): leave_requested.emit())
	hud.retry_requested.connect(_save_result)
	_show_stage()
	_update_hud()
	var en_intro := str(TASK_ENGLISH.get(task_id, ""))
	if not en_intro.is_empty() and is_instance_valid(game.get("ai_bridge")):
		game.ai_bridge.speak_text(en_intro, "en", "player")

func stop() -> void:
	if _stopped: return
	_stopped = true
	set_process(false)
	pressed = false
	dragged = -1
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	for entry: Dictionary in _hidden:
		if is_instance_valid(entry.node): entry.node.visible = entry.visible
	if is_instance_valid(hud):
		hud.hide()
		hud.queue_free()
	hide()

func _exit_tree() -> void:
	stop()

func _suffix(index: int) -> String:
	return "" if index == 0 else "_%03d" % index

func _item(names: Array, target: Vector3, source: Vector3, item_stage: int, kind: String, source_scale: Vector3 = Vector3.ONE) -> Dictionary:
	var node := Props.clone_parts(game.world, self, names, target)
	var shadow := Props.ghost(self, node, target)
	var item := {"node":node, "source":source, "target":target, "stage":item_stage, "kind":kind, "placed":false, "clean":0.0, "source_scale":source_scale, "dirt":null}
	items.append(item)
	targets.append({"point":target, "ghost":shadow, "stage":item_stage, "kind":kind, "used":false})
	node.position = source
	node.scale = source_scale
	return item

func _build_dinner() -> void:
	camera_focus = Vector3(0.7, 0.65, -1.3)
	camera_size = 6.7
	stage_count = 3
	Props.tray(self, Vector3(3.05, 1.0, -1.2), Vector2(1.35, 2.1))
	for i in range(4):
		var target := Vector3(-1.05 if i < 2 else 1.05, 1.16, -0.5 if i % 2 == 0 else -1.9)
		var source := Vector3(2.72 + (i % 2) * 0.64, 1.11, -1.73 + (i / 2) * 1.05)
		_item(["Place_Mat_%03d" % (i + 4)], target, source, 0, "餐垫", Vector3(0.55, 1, 0.55))
		_item(["Dinner_Plate" + _suffix(i)], target + Vector3(0, 0.04, 0), source + Vector3.UP * 0.04, 1, "餐盘")
		var names: Array = []
		for part in ["Body", "Lid", "Label"]: names.append("Dinner_Cup_" + part + _suffix(i))
		_item(names, target + Vector3(0.38, 0.13, -0.12), source + Vector3.UP * 0.13, 2, "杯子")

func _build_tea() -> void:
	camera_focus = Vector3(0.5, 0.65, -1.7)
	camera_size = 4.9
	stage_count = 3
	Props.tray(self, Vector3(1.9, 0.94, -1.6), Vector2(0.9, 1.4))
	_item(["Welcome_Runner_001"], Vector3(0, 1.03, -1.7), Vector3(1.9, 1.03, -1.6), 0, "桌垫", Vector3(0.34, 1, 0.7))
	for i in range(2):
		var names: Array = []
		for part in ["Body", "Lid", "Label"]: names.append("Welcome_Cup_" + part + _suffix(i))
		_item(names, Vector3(-0.65 if i == 0 else 0.65, 1.168, -1.7), Vector3(1.9, 1.13, -1.95 + i * 0.65), 1, "茶杯")
	_item(["Welcome_Fruit_Plate", "Welcome_Apple*"], Vector3(0, 1.15, -1.7), Vector3(1.9, 1.14, -1.6), 2, "果盘")

func _build_bed() -> void:
	camera_focus = Vector3(-4.2, 0.65, -2.5)
	camera_size = 5.6
	stage_count = 3
	_item(["*Quilt*"], Vector3(-4.2, 1.0, -2.0), Vector3(-4.2, 1.03, -0.85), 0, "被子", Vector3(1, 1.2, 0.35))
	_item(["*Pillow*"], Vector3(-4.2, 1.1, -3.6), Vector3(-3.6, 1.14, -2.95), 1, "枕头")
	for i in range(5):
		var crease := Props.sphere(self, Vector3(0.85, 0.075, 0.10), Vector3(-4.45 + (i % 2) * 0.4, 1.11, -2.75 + i * 0.36), Color("e5b2bf"))
		crease.rotation.y = -0.22 + (i % 2) * 0.42
		crease.hide()
		wrinkles.append(crease)

func _build_books() -> void:
	camera_focus = Vector3(1.4, 0.5, -3.85)
	camera_size = 4.3
	for i in range(3):
		var entry := _item(["Returned_Book" + _suffix(i), "Returned_Book_Detail_%d_*" % i], Vector3(1.5 + i * 0.19, 0.45, -4.4), Vector3(1.3 + i * 0.55, 0.25, -3.1), 0, "绘本%d" % i)
		entry.node.rotation.z = PI / 2

func _build_laundry() -> void:
	camera_focus = Vector3(-3.7, 0.85, -2.8)
	camera_size = 4.7
	stage_count = 2
	Props.clone_parts(game.world, self, ["Laundry_Basket*"], Vector3.ZERO)
	for i in range(4):
		var target := Vector3(-4.55 + i * 0.55, 2.07, -3.1)
		_item(["Hanging_Sock_Leg_%03d" % (i + 2), "Hanging_Sock_Foot_%03d" % (i + 2)], target, Vector3(-4.3 + i * 0.4, 0.86, -2.1), 0, "袜子", Vector3(1, 0.55, 1))
		_item(["Clothes_Peg_%03d" % (i + 2)], target + Vector3(0, 0.32, 0), Vector3(-4.3 + i * 0.4, 0.85, -2.1), 1, "夹子", Vector3.ONE * 1.8)

func _build_washing() -> void:
	var vegetables := task_id == "wash_vegetables"
	sink = Vector3(-1.4, 1.38, -5.1) if vegetables else Vector3(-0.5, 1.38, -4.5)
	camera_focus = sink + (Vector3(-0.5,-0.45,0.65) if vegetables else Vector3(-0.35,-0.45,0.3))
	camera_size = 5.4 if vegetables else 3.6
	tap_point = sink + Vector3(-0.12, 0.35, -0.4)
	tap = Props.box(self, Vector3(0.33, 0.09, 0.13), tap_point, Color("72a79d"))
	_label("水龙头", tap_point + Vector3.UP * 0.2)
	water = Props.stream(self)
	if vegetables:
		Props.clone_parts(game.world, self, ["Washed_Basket*"], Vector3.ZERO)
		Props.tray(self, Vector3(-3.15, 1.08, -3.55), Vector2(1.0, 1.5))
		for i in range(3):
			var target := [Vector3(-0.8,1.35,-5.1), Vector3(-0.3,1.35,-5.3), Vector3(-0.2,1.35,-4.9)][i] as Vector3
			var entry := _item(["Vegetable_after" + _suffix(i)], target, Vector3(-3.15, 1.15, -4.0 + i * 0.45), 0, "蔬菜")
			entry.dirt = Props.dirt(entry.node)
	else:
		hands = Props.hands(self, sink + Vector3(0, 0.0, 0.25))
		bubbles = Props.foam(hands)
		bubbles.hide()
		soap = Node3D.new()
		add_child(soap)
		soap.position = sink + Vector3(-0.78, -0.02, 0.03)
		Props.sphere(soap, Vector3(0.22,0.3,0.23), Vector3.ZERO, Color("e5c88f"))
		Props.box(soap, Vector3(0.2,0.06,0.08), Vector3(0.05,0.19,0), Color("eff0de"))
		_label("洗手液", soap.position + Vector3.UP * 0.4)
		Props.clone_parts(game.world, self, ["Clean_Hand_Towel"], Vector3.ZERO)

func _build_garden() -> void:
	camera_focus = Vector3(8.15, 0.45, 11.65)
	camera_size = 5.1
	var entry := _item(["Watering_Can*"], Vector3(6.5,1.05,11.8), Vector3(6.5,1.05,11.8), 0, "水壶")
	entry.node.name = "WateringCan"
	water = Props.stream(self)
	for i in range(3):
		var pos := Vector3(7.69 + i * 0.96, 0.51, 11.85)
		var wet := Props.clone_parts(game.world, self, ["Damp_Soil" + _suffix(i)], pos)
		wet.scale = Vector3(0.01,1,0.01)
		var ring := Props.ring(self,pos + Vector3(-0.34,0.6,0),0.18)
		soil.append({"point":pos, "wet":wet, "amount":0.0, "ring":ring})

func _label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Style.body_font()
	label.font_size = 38
	label.pixel_size = 0.0032
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Style.INK
	label.outline_modulate = Style.PAPER
	label.outline_size = 10
	label.position = pos
	add_child(label)

func _show_stage() -> void:
	for item: Dictionary in items:
		item.node.visible = item.placed or item.stage == stage
	for target: Dictionary in targets:
		target.ghost.visible = not target.used and target.stage == stage
	if task_id == "make_bed":
		for wrinkle in wrinkles: wrinkle.visible = stage == 2

func _screen(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point)

func _radius(world_radius: float = 0.36) -> float:
	return clampf(_screen(camera_focus).distance_to(_screen(camera_focus + game.camera.global_basis.x * world_radius)), 24, 80)

func _near(position_on_screen: Vector2, world_point: Vector3, radius: float = 0.36) -> bool:
	return position_on_screen.distance_to(_screen(world_point)) <= _radius(radius)

func _pick(position_on_screen: Vector2) -> int:
	var selected := -1
	var distance := INF
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.placed or entry.stage != stage: continue
		var d := position_on_screen.distance_to(_screen(entry.node.position))
		if d < distance and d < _radius(0.38):
			distance = d
			selected = i
	return selected

func handle_input(event: InputEvent) -> void:
	if _stopped: return
	if event.is_action_pressed("ui_cancel"):
		leave_requested.emit()
		return
	if completed or ready_to_save: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _press(event.position)
		else: _release(event.position)
	elif event is InputEventMouseMotion:
		_move(event.position, event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed: _press(event.position)
		else: _release(event.position)
	elif event is InputEventScreenDrag:
		_move(event.position, event.relative)

func _input(event: InputEvent) -> void:
	# A release above the small HUD still ends a drag begun in the world.
	if _stopped or not pressed: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_release(event.position)
		get_viewport().set_input_as_handled()

func _press(pos: Vector2) -> void:
	pointer = pos
	pressed = true
	if task_id in ["wash_hands", "wash_vegetables"] and _near(pos,tap_point,0.25):
		water_on = not water_on
		tap.rotation.z = -0.5 if water_on else 0.0
		game.sounds.play("place")
		pressed = false
		if not water_on: _check_washing_complete()
		return
	if task_id == "wash_hands":
		if stage == 0 and water_on and _near(pos,soap.position,0.26):
			stage = 1
			bubbles.show()
			game.sounds.play("place")
			pressed = false
		elif not _near(pos,hands.position,0.65): pressed = false
		return
	if task_id == "make_bed" and stage == 2: return
	dragged = _pick(pos)
	if dragged < 0: return
	var node: Node3D = items[dragged].node
	drag_plane = Plane(game.camera.global_basis.z, node.global_position)
	var point: Variant = drag_plane.intersects_ray(game.camera.project_ray_origin(pos), game.camera.project_ray_normal(pos))
	drag_offset = node.global_position - point if point is Vector3 else Vector3.ZERO
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	game.sounds.play("take")

func _move(pos: Vector2, relative: Vector2) -> void:
	pointer = pos
	if not pressed:
		var over := _pick(pos) >= 0
		if is_instance_valid(tap): over = over or _near(pos,tap_point,0.28)
		if is_instance_valid(soap): over = over or _near(pos,soap.position) or _near(pos,hands.position,0.6)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)
		return
	if task_id == "wash_hands":
		if stage == 1:
			var motion := minf(relative.length(),24.0)
			if _near(pos,sink + Vector3(0,0,0.25),0.9):
				scrub = minf(1.0,scrub + motion / 720.0)
				hands.get_child(0).rotation.y = sin(scrub * 35) * 0.35
				hands.get_child(1).rotation.y = -sin(scrub * 35) * 0.35
				if scrub >= 1.0:
					stage = 2
					pressed = false
		elif stage == 2:
			var point: Variant = Plane(Vector3.UP,sink).intersects_ray(game.camera.project_ray_origin(pos),game.camera.project_ray_normal(pos))
			if point is Vector3 and point.distance_to(sink) < 0.9: hands.position = point
		return
	if task_id == "make_bed" and stage == 2:
		if _near(pos,Vector3(-4.2,1.12,-2.0),1.35):
			scrub = minf(1.0,scrub + minf(relative.length(),24.0) / 760.0)
			for i in range(wrinkles.size()): wrinkles[i].scale.y = 0.075 * maxf(0.01,1.0 - scrub * 1.4 + i * 0.08)
			if scrub >= 1.0: _save_result()
		return
	if dragged < 0: return
	var item: Dictionary = items[dragged]
	var point: Variant = drag_plane.intersects_ray(game.camera.project_ray_origin(pos), game.camera.project_ray_normal(pos))
	if point is Vector3: item.node.global_position = point + drag_offset
	if task_id == "make_bed" and stage == 0:
		var distance := pos.distance_to(_screen(item.target))
		var total := _screen(item.source).distance_to(_screen(item.target))
		item.node.scale.z = lerpf(0.35,1.0,1.0-clampf(distance/maxf(total,1.0),0,1))
	if task_id == "wash_vegetables" and water_on and _near(pos,sink,0.48):
		item.clean = minf(1.0,float(item.clean) + minf(relative.length(),24.0) / 440.0)
		item.dirt.scale = Vector3.ONE * maxf(0.001,1.0 - float(item.clean))
		if float(item.clean) >= 1.0: _feedback_message("洗干净了，拖进右边的菜篮")

func _release(pos: Vector2) -> void:
	pressed = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if dragged < 0: return
	var index := dragged
	dragged = -1
	var item: Dictionary = items[index]
	if task_id == "water_garden":
		var total := 0.0
		for patch: Dictionary in soil: total += float(patch.amount)
		if total >= 2.999 and _near(pos,item.target,0.45):
			item.node.position = item.target
			item.node.rotation = Vector3.ZERO
			_save_result()
		else:
			_return_item(item)
			if total < 2.999: _feedback_message("拿住水壶，让壶嘴在花盆上方停一会儿")
		return
	if task_id == "wash_vegetables" and float(item.clean) < 1.0:
		_return_item(item)
		_feedback_message("先打开水，在水流下拖动蔬菜洗掉泥点")
		return
	var best := -1
	var distance := INF
	for i in range(targets.size()):
		var target: Dictionary = targets[i]
		if target.used or target.stage != stage or target.kind != item.kind: continue
		var d := pos.distance_to(_screen(target.point))
		if d < distance and d < _radius(0.43):
			best = i
			distance = d
	if best < 0:
		_return_item(item)
		_feedback_message("按轮廓的高矮放回对应书位" if task_id == "tidy_books" else "移到浅绿色的位置，再松开")
		return
	var target: Dictionary = targets[best]
	target.used = true
	target.ghost.hide()
	item.placed = true
	_feedback_until = 0.0
	if game.ui.reduced_motion:
		item.node.position = target.point
		item.node.scale = Vector3.ONE
		item.node.rotation = Vector3.ZERO
	else:
		var settle := create_tween().set_parallel(true)
		settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		settle.tween_property(item.node,"position",target.point,0.16)
		settle.tween_property(item.node,"scale",Vector3.ONE,0.16)
		settle.tween_property(item.node,"rotation",Vector3.ZERO,0.16)
	game.sounds.play("place")
	var pending := false
	for entry: Dictionary in items:
		if entry.stage == stage and not entry.placed: pending = true
	if not pending:
		if task_id == "wash_vegetables": _check_washing_complete()
		else:
			stage += 1
			if stage >= stage_count: _save_result()
			else: _show_stage()
	_update_hud()

func _return_item(item: Dictionary) -> void:
	item.node.position = item.source
	item.node.rotation = Vector3.ZERO
	item.node.scale = item.source_scale
	if task_id == "tidy_books": item.node.rotation.z = PI / 2

func _process(delta: float) -> void:
	if _stopped or not is_instance_valid(game): return
	game.ui.toast_label.hide()
	clock += delta
	if game.application_backgrounded:
		if dragged >= 0: _return_item(items[dragged])
		dragged = -1
		pressed = false
		if is_instance_valid(water): water.hide()
		return
	if is_instance_valid(water): water.hide()
	if completed or ready_to_save:
		_update_hud()
		return
	if task_id in ["wash_vegetables", "wash_hands"] and water_on:
		Props.animate_stream(water,sink + Vector3(0,0.3,-0.05),sink + Vector3(0,-0.22,-0.05),clock,game.ui.reduced_motion)
	if task_id == "wash_hands" and stage == 2 and pressed and water_on and _near(pointer,sink + Vector3(0,0,-0.05),0.3):
		rinse = minf(1.0,rinse + delta / 1.8)
		bubbles.scale = Vector3.ONE * maxf(0.001,1.0-rinse)
		if rinse >= 1.0:
			stage = 3
			pressed = false
			_check_washing_complete()
	if task_id == "water_garden" and dragged >= 0 and pressed:
		var can: Node3D = items[dragged].node
		var pouring := false
		for patch: Dictionary in soil:
			var aim: Vector3 = patch.point + Vector3(-0.34,0.6,0)
			if _near(pointer,aim,0.3):
				pouring = true
				can.position = aim
				can.rotation.z = -0.35
				patch.amount = minf(1.0,float(patch.amount) + delta / 1.5)
				patch.wet.scale = Vector3(maxf(0.01,patch.amount),1,maxf(0.01,patch.amount))
				patch.ring.visible = float(patch.amount) < 1.0
				Props.animate_stream(water,aim + Vector3(0.35,0.08,0),patch.point + Vector3.UP * 0.03,clock,game.ui.reduced_motion)
				break
		if not pouring: can.rotation.z = 0.0
	_update_hud()

func _check_washing_complete() -> void:
	if water_on: return
	if task_id == "wash_hands":
		if stage == 3: _save_result()
	else:
		for item: Dictionary in items:
			if not item.placed: return
		_save_result()

func _save_result() -> void:
	if completed or _stopped: return
	ready_to_save = true
	pressed = false
	dragged = -1
	water_on = false
	if not State.complete_home_task(task_id,game.room):
		hud.retry_button.show()
		_update_hud()
		return
	completed = true
	hud.retry_button.hide()
	hud.exit_button.text = "继续逛逛"
	for target: Dictionary in targets: target.ghost.hide()
	for crease in wrinkles: crease.hide()
	game.sounds.play("place")
	if is_instance_valid(game.get("ai_bridge")):
		game.ai_bridge.speak_text("All clean and tidy! Great job!", "en", "teacher_gentle")
	finished.emit()
	_update_hud()

func _feedback_message(message: String) -> void:
	_feedback = message
	_feedback_until = clock + 2.4

func _update_hud() -> void:
	if not is_instance_valid(hud): return
	var en_line := str(TASK_ENGLISH.get(task_id, ""))
	var bilingual_title := str(task.title) if en_line.is_empty() else ("%s  ·  %s" % [str(task.title), en_line])
	if completed:
		hud.update_status(str(task.title) + " · All clean and tidy!", str(task.result), "已保存 · 离开再回来也能看见", 1.0)
		return
	if ready_to_save:
		hud.update_status(bilingual_title, "已做好，保存还没有成功", "可重试保存；原有记录仍保留", 1.0)
		return
	var placed := 0
	for item: Dictionary in items:
		if item.placed: placed += 1
	var hint := "按住物件，拖到浅绿色位置后松开"
	var detail := "已摆好 %d / %d" % [placed,items.size()]
	var fraction := float(placed) / maxf(1,items.size())
	match task_id:
		"set_dinner": hint = ["把右边托盘里的餐垫，拖到四个座位前", "把餐盘拖到餐垫上", "把杯子放在每个餐盘旁"][mini(stage,2)]
		"welcome_table": hint = ["把右边的桌垫拖到茶几中央", "把两个杯子分别摆到桌垫两边", "把果盘放到茶几中央"][mini(stage,2)]
		"make_bed":
			hint = ["抓住床尾的被子，向床头方向拖开", "把歪放的枕头拖回床头", "按住被面来回抚平，让褶皱慢慢消失"][mini(stage,2)]
			fraction = (minf(stage,2) + scrub) / 3.0
			detail = "铺被子 → 摆枕头 → 抚平被角" if stage < 2 else "被面平整度  %d%%" % int(scrub * 100)
		"tidy_books": hint = "按高矮，把绘本放回书架下层的对应位置"
		"hang_laundry": hint = "把篮里的袜子拖到晾衣架上" if stage == 0 else "取出篮里的夹子，夹住每只袜子的上沿"
		"wash_vegetables":
			hint = "点水龙头开水 · 抓住蔬菜在水流下反复移动 · 洗净后放进菜篮"
			if dragged >= 0: detail = "正在清洗  %d%%" % int(float(items[dragged].clean) * 100)
			else: detail = "已洗好 %d / 3 · 水龙头%s" % [placed,"开着" if water_on else "已关闭"]
			if placed == 3: hint = "蔬菜都洗好了，点水龙头关水"
		"wash_hands":
			hint = ["先点水龙头开水，再按一下左边的洗手液", "按住双手来回揉搓；揉搓时可以先关水", "打开水，把双手拖到水流下冲净泡沫", "点水龙头关水"][mini(stage,3)]
			fraction = (scrub + rinse) / 2.0
			detail = "揉搓 %d%% · 冲洗 %d%%" % [int(scrub * 100),int(rinse * 100)]
		"water_garden":
			var total := 0.0
			for patch: Dictionary in soil: total += float(patch.amount)
			fraction = total / 3.0
			hint = "拿住水壶，移到三个绿色圆圈处，停留浇透花丛"
			if total >= 2.999: hint = "都浇好了，把水壶拖回左边的小架子"
			detail = "花圃浇水  %d%%" % int(fraction * 100)
	if clock < _feedback_until: detail = _feedback
	hud.update_status(bilingual_title,hint,detail,fraction)
