extends Control
## A persistent 64 x 64 drawing surface. A gesture is one undo operation.
signal edited(pattern: String)
const C = preload("res://gameplay/creation_catalog.gd")
var pattern := "0".repeat(4096)
var ink := 9
var tool := "brush"
var stamp := "star"
var undo_stack: Array[String] = []
var _painting := false
var _last := Vector2i(-1,-1)
var _texture: ImageTexture

func _ready() -> void:
	custom_minimum_size = Vector2(320,320)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	refresh()

static func texture_for(pixels: String, repeat_pattern: bool = false) -> ImageTexture:
	var image := Image.create(64,64,false,Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var sx := (x * 2) % 64 if repeat_pattern else x
			var sy := (y * 2) % 64 if repeat_pattern else y
			var index := "0123456789abcdef".find(pixels[sy * 64 + sx]) if pixels.length() == 4096 else 0
			image.set_pixel(x,y,Color(C.PALETTE[maxi(index,0)]))
	return ImageTexture.create_from_image(image)

func set_pattern(value: String) -> void:
	pattern = value
	refresh()

func refresh() -> void:
	_texture = texture_for(pattern)
	queue_redraw()

func _draw() -> void:
	if _texture:
		draw_texture_rect(_texture,Rect2(Vector2.ZERO,Vector2.ONE * minf(size.x,size.y)),false)
		draw_rect(Rect2(Vector2.ZERO,Vector2.ONE * minf(size.x,size.y)),Color("b98759"),false,2)

func undo() -> void:
	if undo_stack.is_empty(): return
	pattern = undo_stack.pop_back()
	refresh()
	edited.emit(pattern)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_Z:
		undo()
		accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			undo_stack.append(pattern)
			if undo_stack.size() > 32: undo_stack.pop_front()
			_painting = true
			_last = Vector2i(-1,-1)
			paint_at(event.position)
		else:
			_painting = false
			edited.emit(pattern)
		accept_event()
	elif event is InputEventMouseMotion and _painting:
		paint_at(event.position)
		accept_event()

func paint_at(point: Vector2) -> void:
	var side := minf(size.x,size.y)
	var cell := Vector2i(floori(point.x / side * 64),floori(point.y / side * 64))
	if cell.x < 0 or cell.y < 0 or cell.x >= 64 or cell.y >= 64 or cell == _last: return
	var color_index := 0 if tool == "erase" else ink
	if tool == "fill":
		flood(cell,color_index)
		_painting = false
		edited.emit(pattern)
	elif tool == "stamp":
		for y in range(-7,8):
			for x in range(-7,8):
				var radius := Vector2(x,y).length()
				var draw_pixel := false
				match stamp:
					"dots": draw_pixel = radius < 5
					"stripes": draw_pixel = posmod(x,5) < 2
					"check": draw_pixel = posmod(floori(x/3.0)+floori(y/3.0),2) == 0
					"star": draw_pixel = radius < 3 or abs(x) + absi(y * 2) < 8 or absi(x * 2) + abs(y) < 8
					"apple": draw_pixel = (radius < 6 and y > -4) or (x in [0,1] and y < -3)
					"flower": draw_pixel = radius < 3 or (radius < 7 and (abs(x) < 2 or abs(y) < 2))
					"owl": draw_pixel = (radius < 6 and y > -3 and not (abs(x) in [2,3] and y == 0)) or (abs(x) in [3,4] and y < -2 and y > -7)
					"music": draw_pixel = (x in [2,3] and y < 5) or (y in [-6,-5] and x > 2) or Vector2(x,y-4).length() < 3
				if draw_pixel: pixel(cell + Vector2i(x,y),color_index)
		_painting = false
		edited.emit(pattern)
	else:
		var start := cell if _last.x < 0 else _last
		var steps := maxi(abs(cell.x-start.x),abs(cell.y-start.y))
		for step in range(steps+1):
			pixel(Vector2i(Vector2(start).lerp(Vector2(cell),float(step)/maxi(1,steps)).round()),color_index)
	_last = cell
	refresh()

func pixel(cell: Vector2i, value: int) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < 64 and cell.y < 64:
		pattern[cell.y * 64 + cell.x] = "0123456789abcdef"[value]

func flood(cell: Vector2i, value: int) -> void:
	var target := pattern[cell.y*64+cell.x]
	if target == "0123456789abcdef"[value]: return
	var pending: Array[Vector2i] = [cell]
	pixel(cell,value)
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next := current + delta
			if next.x >= 0 and next.y >= 0 and next.x < 64 and next.y < 64 and pattern[next.y*64+next.x] == target:
				pixel(next,value)
				pending.append(next)
