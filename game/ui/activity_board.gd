extends VBoxContainer
## Short, replayable campus activities. They never produce English mastery scores.
signal action(id: String)
const Style = preload("res://ui/island_theme.gd")
const Canvas = preload("res://ui/art_canvas.gd")
var kind := ""
var status: Label
var canvas: Control
var dirty := false
var notes: Array[Button] = []
var melody := [0,2,4,2]
var played := 0
var demo: Tween
var demonstrating := false
var selected: Array[int] = []
var experiment := 0
var result_card: PanelContainer
var result_label: Label
var pigments: Array[Button] = []
var save_button: Button
const NAMES := ["Do","Re","Mi","Fa","Sol","La","Si","Do"]
const PIGMENTS := [Color("d47d69"),Color("dabb64"),Color("82aabd")]

func setup(activity: String, data: Dictionary) -> void:
	kind = activity
	add_theme_constant_override("separation",18)
	status = Style.text("",20)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	match kind:
		"music": _music()
		"art": _art(data)
		"science": _science()

func _button(value: String, callback: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size = Vector2(130,52)
	item.theme_type_variation = "PrimaryButton" if primary else "Button"
	item.pressed.connect(callback)
	return item

func _music() -> void:
	status.text = "试试这段欢迎曲：Do · Mi · Sol · Mi。也可以随意弹奏。"
	var staff := PanelContainer.new()
	staff.add_theme_stylebox_override("panel",Style.box(Color("e7ecdf"),20))
	add_child(staff)
	var tune := Style.text("1     3     5     3     /     小岛欢迎曲",25)
	tune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	staff.add_child(tune)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation",10)
	keys.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(keys)
	for index: int in 8:
		var key := _button(NAMES[index]+"\n\n"+str(index+1),func(): play_note(index))
		key.custom_minimum_size = Vector2(0,170)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.size_flags_vertical = Control.SIZE_EXPAND_FILL
		keys.add_child(key)
		notes.append(key)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",16)
	add_child(controls)
	controls.add_child(_button("先听一遍",play_demo,true))
	controls.add_child(_button("从头试试",func(): played=0; status.text="从 Do 开始，慢慢弹就好。"))
	controls.add_child(Style.text("点击琴键，或按数字 1–8",16,Style.MUTED))

func play_note(index: int) -> void:
	if demonstrating:
		return
	action.emit("note:"+str(index))
	_flash(index)
	if index == melody[played]:
		played += 1
		status.text = "已经接上 %d / 4 个音符" % played
		if played == melody.size():
			played = 0
			status.text = "这段旋律完成啦！还可以继续弹自己的歌。"
			action.emit("activity_complete:music")
	else:
		played = 1 if index==melody[0] else 0
		status.text = "这是一个新的声音。欢迎曲从 Do 开始，可以再听一次。"

func _flash(index: int) -> void:
	if index<0 or index>=notes.size():
		return
	notes[index].modulate = Color("c8dfbb")
	var tween := notes[index].create_tween()
	tween.tween_property(notes[index],"modulate",Color.WHITE,0.3)

func play_demo() -> void:
	if demo and demo.is_valid():
		demo.kill()
	demonstrating = true
	played = 0
	status.text = "听一听，亮起的是正在弹奏的琴键。"
	demo = create_tween()
	for raw: int in melody:
		var index := raw
		demo.tween_callback(func(): action.emit("note:"+str(index)); _flash(index))
		demo.tween_interval(0.5)
	demo.tween_callback(func(): demonstrating=false; status.text="轮到你了：Do · Mi · Sol · Mi。")

func _art(data: Dictionary) -> void:
	status.text = "选一种颜色，按住鼠标画画。完成后把明信片收入回忆册。"
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",12)
	add_child(tools)
	canvas = Canvas.new()
	var labels := ["草木绿","珊瑚红","向日葵黄","天空蓝","丁香紫"]
	var brush_group := ButtonGroup.new()
	for index: int in 5:
		var swatch := _button(str(labels[index]),func(): canvas.brush=index)
		swatch.toggle_mode = true
		swatch.button_group = brush_group
		swatch.button_pressed = index==0
		var sample := Style.box(Canvas.COLORS[index].lightened(0.55),16,12)
		swatch.add_theme_stylebox_override("normal",sample)
		var selected_sample := sample.duplicate() as StyleBoxFlat
		selected_sample.border_color = Style.SAGE
		selected_sample.set_border_width_all(3)
		swatch.add_theme_stylebox_override("pressed",selected_sample)
		tools.add_child(swatch)
	add_child(canvas)
	canvas.restore(data.get("artwork",[]))
	canvas.changed.connect(func(): dirty=true; save_button.text="保存明信片"; status.text="喜欢现在的样子吗？也可以撤销一笔。")
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	add_child(controls)
	controls.add_child(_button("撤销一笔",func(): canvas.undo()))
	controls.add_child(_button("清空画纸",func(): canvas.clear()))
	save_button = _button("保存明信片",func(): action.emit("save_art"),true)
	controls.add_child(save_button)

func mark_saved() -> void:
	dirty = false
	status.text = "明信片已保存在回忆册，下次来还可以继续画。"
	if is_instance_valid(save_button):
		save_button.text = "已保存"

func _science() -> void:
	status.text = "用黄色和蓝色，调出一杯绿色。选两瓶颜色，再点混合。"
	var table := HBoxContainer.new()
	table.add_theme_constant_override("separation",20)
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(table)
	for index: int in 3:
		var bottle := _button(["红色\nRed","黄色\nYellow","蓝色\nBlue"][index],func(): choose_pigment(index))
		bottle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottle.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bottle.add_theme_stylebox_override("normal",Style.box(PIGMENTS[index].lightened(0.48),24,20))
		table.add_child(bottle)
		pigments.append(bottle)
	result_card = PanelContainer.new()
	result_card.custom_minimum_size.y = 100
	result_card.add_theme_stylebox_override("panel",Style.box(Color("e4e9df"),20))
	result_label = Style.text("实验杯 · 等待两种颜色",23)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_card.add_child(result_label)
	add_child(result_card)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",16)
	add_child(controls)
	controls.add_child(_button("混合颜色",mix,true))
	controls.add_child(_button("倒掉重来",reset_mix))

func choose_pigment(index: int) -> void:
	if selected.has(index):
		selected.erase(index)
	elif selected.size()<2:
		selected.append(index)
	else:
		selected.pop_front()
		selected.append(index)
	for number: int in pigments.size():
		pigments[number].modulate = Color.WHITE if selected.has(number) else Color(0.87,0.89,0.85)
	result_label.text = "已加入 %d / 2 种颜色" % selected.size()
	action.emit("sound:click")

func reset_mix() -> void:
	selected.clear()
	for pigment: Button in pigments:
		pigment.modulate = Color.WHITE
	result_label.text = "实验杯 · 等待两种颜色"
	result_card.add_theme_stylebox_override("panel",Style.box(Color("e4e9df"),20))

func mix() -> void:
	if selected.size()!=2:
		status.text = "先选择两种颜色，实验杯就准备好了。"
		return
	selected.sort()
	var key := str(selected[0])+str(selected[1])
	var mixes := {"01":["橙色 · Orange",Color("d9a06c")],"02":["紫色 · Purple",Color("a995b6")],"12":["绿色 · Green",Color("a0b98a")]}
	var result: Array = mixes[key]
	result_label.text = str(result[0])
	result_card.add_theme_stylebox_override("panel",Style.box(result[1].lightened(0.25),20))
	var targets := ["12","01","02"]
	if key == targets[experiment]:
		experiment += 1
		if experiment == 3:
			experiment = 0
			status.text = "三种新颜色都调出来了！还可以自由试一试。"
			action.emit("activity_complete:science")
		else:
			status.text = "成功了！接下来试试调出"+("橙色：红色 + 黄色。" if experiment==1 else "紫色：红色 + 蓝色。")
			action.emit("sound:pickup")
	else:
		status.text = "发现了"+str(result[0])+"。试着换两瓶，看看颜色如何变化。"

func _unhandled_key_input(event: InputEvent) -> void:
	if kind=="music" and event is InputEventKey and event.pressed and not event.echo and event.keycode>=KEY_1 and event.keycode<=KEY_8:
		play_note(event.keycode-KEY_1)
		get_viewport().set_input_as_handled()
