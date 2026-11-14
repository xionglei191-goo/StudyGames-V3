extends VBoxContainer
## Short, replayable campus activities with V5 tactile keycaps & bilingual immersion.
## They never produce English mastery scores (`State.data.learning` stays untouched).
signal action(id: String)
const Style = preload("res://ui/island_theme.gd")
const Canvas = preload("res://ui/art_canvas.gd")
var kind := ""
var status: Label
var canvas: Control
var dirty := false
var notes: Array[Button] = []
var melody := [0, 2, 4, 2]
var played := 0
var demo: Tween
var demonstrating := false
var selected: Array[int] = []
var experiment := 0
var result_card: PanelContainer
var result_label: Label
var pigments: Array[Button] = []
var save_button: Button
const NAMES := ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si", "Do"]
const PIGMENTS := [Color("d47d69"), Color("dabb64"), Color("82aabd")]
const PIGMENT_EN := ["red", "yellow", "blue"]
const ART_COLORS_EN := ["green", "red", "yellow", "blue", "purple"]

func setup(activity: String, data: Dictionary) -> void:
	kind = activity
	add_theme_constant_override("separation", 16)
	status = Style.text("", 19, Style.INK)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	match kind:
		"music": _music()
		"art": _art(data)
		"science": _science()

func _speak_bilingual(phrase_en: String) -> void:
	if phrase_en.is_empty():
		return
	var host_map := {
		"music": "resident_music_room",
		"art": "resident_art_room",
		"science": "resident_science_room",
	}
	var vh := str(host_map.get(kind, "teacher_gentle"))
	if Engine.get_main_loop() is SceneTree:
		var bus := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")
		if bus != null:
			bus.tts_speak_requested.emit(phrase_en, "en", vh)

func _button(value: String, callback: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size = Vector2(132, 50)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.theme_type_variation = "PrimaryButton" if primary else "Button"
	item.pressed.connect(callback)
	return item

func _music() -> void:
	status.text = "Let's play a sunny melody! 试试这段欢迎曲：Do · Mi · Sol · Mi，也可以自由弹奏。"
	_speak_bilingual("Let's play a sunny melody!")
	var staff := PanelContainer.new()
	var staff_sb := Style.keycap(Color("eef4e6"), Color("c6d7b9"), 3, 18, 16, 12)
	staff_sb.shadow_size = 0
	staff.add_theme_stylebox_override("panel", staff_sb)
	add_child(staff)
	var tune := Style.text("1     3     5     3     /     Sunny Welcome Melody · 小岛欢迎曲", 23, Style.INK)
	tune.add_theme_font_override("font", Style.heading_font())
	tune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	staff.add_child(tune)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 10)
	keys.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(keys)
	for index: int in 8:
		var key := _button(NAMES[index] + "\n\n" + str(index + 1), func(): play_note(index))
		key.custom_minimum_size = Vector2(0, 168)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.size_flags_vertical = Control.SIZE_EXPAND_FILL
		key.add_theme_stylebox_override("normal", Style.keycap(Color("fffdf7"), Color("d7cab2"), 5, 16, 10, 12))
		key.add_theme_stylebox_override("hover", Style.keycap(Color("fff7e2"), Style.GOLD, 5, 16, 10, 12))
		key.add_theme_stylebox_override("pressed", Style.keycap(Color("eef5e6"), Style.SAGE, 2, 16, 10, 14))
		keys.add_child(key)
		notes.append(key)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 14)
	add_child(controls)
	controls.add_child(_button("先听一遍", play_demo, true))
	controls.add_child(_button("从头试试", func(): played = 0; status.text = "Try from Do! 从 Do 开始，慢慢弹就好。"))
	controls.add_child(Style.text("点击琴键，或按数字键 1–8", 16, Style.MUTED))

func play_note(index: int) -> void:
	if demonstrating:
		return
	action.emit("note:" + str(index))
	_flash(index)
	if index == melody[played]:
		played += 1
		status.text = "Nice note! 已经接上 %d / 4 个音符" % played
		if played == melody.size():
			played = 0
			status.text = "Wonderful music! Well done! 这段旋律完成啦，还可以继续弹自己的歌。"
			_speak_bilingual("Wonderful music! Well done!")
			action.emit("activity_complete:music")
	else:
		played = 1 if index == melody[0] else 0
		status.text = "A new sound! 欢迎曲从 Do 开始，可以再听一次。"

func _flash(index: int) -> void:
	if index < 0 or index >= notes.size():
		return
	notes[index].modulate = Color("d4ecc5")
	var tween := notes[index].create_tween()
	tween.tween_property(notes[index], "modulate", Color.WHITE, 0.3)

func play_demo() -> void:
	if demo and demo.is_valid():
		demo.kill()
	demonstrating = true
	played = 0
	status.text = "Listen closely! 听一听，亮起的是正在弹奏的琴键。"
	demo = create_tween()
	for raw: int in melody:
		var index := raw
		demo.tween_callback(func(): action.emit("note:" + str(index)); _flash(index))
		demo.tween_interval(0.5)
	demo.tween_callback(func(): demonstrating = false; status.text = "Your turn! 轮到你了：Do · Mi · Sol · Mi。")

func _art(data: Dictionary) -> void:
	status.text = "Let's paint a sunny postcard! 选一种颜色，按住画纸作画并收入回忆册。"
	_speak_bilingual("Let's paint a sunny postcard!")
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	add_child(tools)
	canvas = Canvas.new()
	var labels := ["草木绿 · Green", "珊瑚红 · Red", "向日葵黄 · Yellow", "天空蓝 · Blue", "丁香紫 · Purple"]
	var brush_group := ButtonGroup.new()
	for index: int in 5:
		var col_en: String = str(ART_COLORS_EN[index])
		var swatch_caption: String = str(labels[index])
		var swatch := _button(swatch_caption, func():
			canvas.brush = index
			status.text = "Color: %s · 已选画笔「%s」，在画纸上涂绘吧。" % [col_en.capitalize(), swatch_caption]
			_speak_bilingual(col_en)
		)
		swatch.toggle_mode = true
		swatch.button_group = brush_group
		swatch.button_pressed = index == 0
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tint: Color = Canvas.COLORS[index].lightened(0.56)
		var border_tint: Color = Canvas.COLORS[index].darkened(0.10)
		swatch.add_theme_stylebox_override("normal", Style.keycap(tint, border_tint, 3, 14, 12, 8))
		swatch.add_theme_stylebox_override("hover", Style.keycap(tint.lightened(0.08), Style.GOLD, 3, 14, 12, 8))
		swatch.add_theme_stylebox_override("pressed", Style.keycap(tint.lightened(0.05), Style.SAGE, 2, 14, 12, 9))
		tools.add_child(swatch)
	add_child(canvas)
	canvas.restore(data.get("artwork", []))
	canvas.changed.connect(func(): dirty = true; save_button.text = "保存明信片"; status.text = "Lovely strokes! 喜欢现在的样子吗？也可以撤销一笔。")
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	controls.add_child(_button("撤销一笔", func(): canvas.undo()))
	controls.add_child(_button("清空画纸", func(): canvas.clear()))
	save_button = _button("保存明信片", func(): action.emit("save_art"), true)
	controls.add_child(save_button)

func mark_saved() -> void:
	dirty = false
	status.text = "What a lovely postcard! 明信片已保存在回忆册，下次来还可以继续画。"
	_speak_bilingual("What a lovely postcard!")
	if is_instance_valid(save_button):
		save_button.text = "已保存"

func _science() -> void:
	status.text = "Mix two colours! 用黄色（Yellow）和蓝色（Blue）调出一杯绿色（Green）吧。"
	_speak_bilingual("Let's mix colours together!")
	var table := HBoxContainer.new()
	table.add_theme_constant_override("separation", 18)
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(table)
	for index: int in 3:
		var bottle := _button(["红色\nRed", "黄色\nYellow", "蓝色\nBlue"][index], func(): choose_pigment(index))
		bottle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottle.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var base_pigment: Color = PIGMENTS[index]
		var b_fill: Color = base_pigment.lightened(0.50)
		var b_edge: Color = base_pigment.darkened(0.12)
		bottle.add_theme_stylebox_override("normal", Style.keycap(b_fill, b_edge, 4, 20, 18, 16))
		bottle.add_theme_stylebox_override("hover", Style.keycap(b_fill.lightened(0.08), Style.GOLD, 4, 20, 18, 16))
		bottle.add_theme_stylebox_override("pressed", Style.keycap(b_fill, Style.SAGE, 2, 20, 18, 17))
		table.add_child(bottle)
		pigments.append(bottle)
	result_card = PanelContainer.new()
	result_card.custom_minimum_size.y = 96
	var r_sb := Style.keycap(Color("e8eee2"), Color("c5d3ba"), 3, 18, 16, 14)
	r_sb.shadow_size = 0
	result_card.add_theme_stylebox_override("panel", r_sb)
	result_label = Style.text("实验杯 · Pick two colours（等待两种颜色）", 22, Style.INK)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_card.add_child(result_label)
	add_child(result_card)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	add_child(controls)
	controls.add_child(_button("混合颜色", mix, true))
	controls.add_child(_button("倒掉重来", reset_mix))

func choose_pigment(index: int) -> void:
	if selected.has(index):
		selected.erase(index)
	elif selected.size() < 2:
		selected.append(index)
		_speak_bilingual(PIGMENT_EN[clampi(index, 0, 2)])
	else:
		selected.pop_front()
		selected.append(index)
		_speak_bilingual(PIGMENT_EN[clampi(index, 0, 2)])
	for number: int in pigments.size():
		pigments[number].modulate = Color.WHITE if selected.has(number) else Color(0.87, 0.89, 0.85)
	result_label.text = "已加入 %d / 2 种颜色" % selected.size()
	action.emit("sound:click")

func reset_mix() -> void:
	selected.clear()
	for pigment: Button in pigments:
		pigment.modulate = Color.WHITE
	result_label.text = "实验杯 · Pick two colours（等待两种颜色）"
	var r_sb := Style.keycap(Color("e8eee2"), Color("c5d3ba"), 3, 18, 16, 14)
	r_sb.shadow_size = 0
	result_card.add_theme_stylebox_override("panel", r_sb)

func mix() -> void:
	if selected.size() != 2:
		status.text = "Pick two bottles first! 先选择两种颜色，实验杯就准备好了。"
		return
	selected.sort()
	var key := str(selected[0]) + str(selected[1])
	var mixes := {
		"01": ["橙色 · Red + Yellow = Orange", Color("d9a06c"), "Red and yellow make orange!"],
		"02": ["紫色 · Red + Blue = Purple", Color("a995b6"), "Red and blue make purple!"],
		"12": ["绿色 · Yellow + Blue = Green", Color("a0b98a"), "Yellow and blue make green!"]
	}
	var result: Array = mixes[key]
	result_label.text = str(result[0])
	var mixed_col := (result[1] as Color).lightened(0.28)
	var m_sb := Style.keycap(mixed_col, (result[1] as Color).darkened(0.12), 3, 18, 16, 14)
	m_sb.shadow_size = 0
	result_card.add_theme_stylebox_override("panel", m_sb)
	_speak_bilingual(str(result[2]))
	var targets := ["12", "01", "02"]
	if key == targets[experiment]:
		experiment += 1
		if experiment == 3:
			experiment = 0
			status.text = str(result[2]) + " 三种新颜色都调出来啦！还可以自由试一试。"
			action.emit("activity_complete:science")
		else:
			status.text = str(result[2]) + " 接下来试试调出" + ("橙色：Red + Yellow。" if experiment == 1 else "紫色：Red + Blue。")
			action.emit("sound:pickup")
	else:
		status.text = str(result[2]) + " 试着换两瓶，看看颜色如何变化。"

func _unhandled_key_input(event: InputEvent) -> void:
	if kind == "music" and event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_8:
		play_note(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
