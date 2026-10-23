extends Control
signal changed

const COLORS := [Color("557a65"),Color("d48979"),Color("d5b55d"),Color("83acbd"),Color("8e7fa3")]
var strokes: Array = []
var brush := 0
var drawing := false
var keyboard_cursor := Vector2(0.5,0.5)
var _point_count := 0

func _ready() -> void:
	custom_minimum_size = Vector2(420,280)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	tooltip_text = "按住画画；也可用方向键移动画笔，按空格落笔"
	resized.connect(queue_redraw)

func restore(values: Array) -> void:
	strokes = values.duplicate(true)
	_point_count = 0
	for stroke: Dictionary in strokes:
		_point_count += stroke.points.size()
	queue_redraw()

func undo() -> void:
	if not strokes.is_empty():
		_point_count -= strokes.back().points.size()
		strokes.pop_back()
		changed.emit()
		queue_redraw()

func clear() -> void:
	strokes.clear()
	_point_count = 0
	changed.emit()
	queue_redraw()

func _append(point: Vector2) -> void:
	if _point_count >= 4000 or strokes.is_empty():
		return
	var normalized := (point / size).clamp(Vector2.ZERO,Vector2.ONE)
	var points: Array = strokes.back().points
	if not points.is_empty():
		var previous := Vector2(float(points.back()[0]),float(points.back()[1]))
		if normalized.distance_to(previous) < 0.004:
			return
	points.append([snappedf(normalized.x,0.0001),snappedf(normalized.y,0.0001)])
	_point_count += 1
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed and _point_count < 4000 and strokes.size() < 200
		if drawing:
			grab_focus()
			strokes.append({"color":brush,"points":[]})
			_append(event.position)
			changed.emit()
		else:
			changed.emit()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_append(event.position)
		else:
			drawing = false
			changed.emit()
		accept_event()
	elif event is InputEventKey and event.pressed:
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction.x = -0.025
			KEY_RIGHT: direction.x = 0.025
			KEY_UP: direction.y = -0.025
			KEY_DOWN: direction.y = 0.025
			KEY_SPACE:
				if strokes.size()<200 and _point_count<4000:
					strokes.append({"color":brush,"points":[[keyboard_cursor.x,keyboard_cursor.y]]})
					_point_count += 1
					changed.emit()
			_: return
		keyboard_cursor = (keyboard_cursor+direction).clamp(Vector2.ZERO,Vector2.ONE)
		queue_redraw()
		accept_event()

func _draw() -> void:
	var paper := preload("res://ui/island_theme.gd").box(Color("fffcf2"),18,0)
	draw_style_box(paper,Rect2(Vector2.ZERO,size))
	for stroke: Dictionary in strokes:
		var points := PackedVector2Array()
		for point: Array in stroke.points:
			points.append(Vector2(float(point[0]),float(point[1]))*size)
		if points.is_empty():
			continue
		var color: Color = COLORS[int(stroke.color)]
		if points.size()>1:
			draw_polyline(points,color,7,true)
		draw_circle(points[0],3.5,color)
		draw_circle(points[-1],3.5,color)
	if has_focus():
		draw_arc(keyboard_cursor*size,9,0,TAU,24,Color("7a8976"),1.5,true)
