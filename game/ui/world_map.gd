extends Control
## The map renders the actual authored world, with selectable spatial markers.

signal destination_selected(id: String)
const Style = preload("res://ui/island_theme.gd")
var viewport: SubViewport
var camera: Camera3D
var entries: Array = []
var routes: Dictionary = {}
var player_position := Vector3.ZERO
var hovered := ""
var pin_layer: Control
var pins: Array[Button] = []
var _view_size := Vector2.ZERO

func setup(world: World3D, bounds: Rect2, points: Array, origin: Vector3, paths: Dictionary) -> void:
	custom_minimum_size = Vector2(480, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	entries = points
	player_position = origin
	routes = paths
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.show_behind_parent = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 500)
	viewport.world_3d = world
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 500
	camera.cull_mask = 1
	viewport.add_child(camera)
	var center := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
	camera.position = center + Vector3(0, 160, 0.01)
	camera.look_at(center, Vector3.FORWARD)
	camera.set_meta("bounds", bounds)
	pin_layer = Control.new()
	pin_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pin_layer)
	for entry: Dictionary in entries:
		var pin := Button.new()
		var id := str(entry.id)
		pin.text = _short_label(entry)
		pin.tooltip_text = str(entry.label) + " · 点击前往"
		pin.custom_minimum_size = Vector2(42, 42)
		pin.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pin.add_theme_font_size_override("font_size", 16)
		pin.add_theme_stylebox_override("normal", Style.box(Style.PAPER, 20, 8))
		pin.pressed.connect(func(): destination_selected.emit(id))
		pin.mouse_entered.connect(func(): hovered = id; queue_redraw())
		pin.focus_entered.connect(func(): hovered = id; queue_redraw())
		pin.mouse_exited.connect(func(): hovered = ""; queue_redraw())
		pin_layer.add_child(pin)
		pins.append(pin)
	resized.connect(_layout)
	_layout.call_deferred()

func _short_label(entry: Dictionary) -> String:
	var id := str(entry.id)
	if id.begins_with("landmark_"):
		return id.trim_prefix("landmark_")
	if id.begins_with("memory_"):
		return str(int(id.trim_prefix("memory_")))
	if id == "home_gate" and str(entry.get("destination", "")) == "home":
		return "客厅"
	var home_names := {"house_entry":"正门", "courtyard_exit":"小院", "home_exit":"走廊", "home_bedroom_gate":"卧室", "home_kitchen_gate":"厨房", "home_dining_gate":"餐厅", "home_bathroom_gate":"浴室", "home_study_gate":"书房", "home_balcony_gate":"阳台"}
	if home_names.has(id): return str(home_names[id])
	var names := {"school_gate":"学校", "home_gate":"家", "baker":"熊叔", "orchard":"果园", "gardener":"兔兔", "village_exit":"出口", "school_exit":"出口", "classroom_gate":"教室", "music_room_gate":"音乐", "art_room_gate":"美术", "science_room_gate":"科学", "canteen_gate":"餐厅", "playground_gate":"操场", "football_field_gate":"球场", "host":"邻居", "teacher":"老师", "decorate":"布置", "bed":"休息"}
	return str(names.get(id, str(entry.label).left(3)))

func _layout() -> void:
	if not is_instance_valid(camera) or size.y < 1:
		return
	var bounds: Rect2 = camera.get_meta("bounds")
	camera.size = maxf(bounds.size.y, bounds.size.x / maxf(size.x/size.y, 0.1)) * 1.12
	var occupied: Array[Rect2] = []
	var current := _point(player_position)
	occupied.append(Rect2(current-Vector2(19,19),Vector2(38,38)))
	for index: int in pins.size():
		var point := _point(entries[index].position)
		var pin: Button = pins[index]
		pin.size = pin.get_combined_minimum_size()
		pin.position = _pin_position(point,pin.size,occupied)
		occupied.append(Rect2(pin.position,pin.size).grow(4))
	queue_redraw()

func _pin_position(point: Vector2, pin_size: Vector2, occupied: Array[Rect2]) -> Vector2:
	var best := (point-pin_size/2).clamp(Vector2(4,4),size-pin_size-Vector2(4,4))
	for radius: float in [0.0,56.0,80.0,104.0,128.0,152.0]:
		for degrees: float in [-90.0,0.0,90.0,180.0,-45.0,45.0,135.0,-135.0]:
			var offset := Vector2.from_angle(deg_to_rad(degrees))*radius
			var candidate := (point+offset-pin_size/2).clamp(Vector2(4,4),size-pin_size-Vector2(4,4))
			var rectangle := Rect2(candidate,pin_size).grow(3)
			var clear := true
			for other: Rect2 in occupied:
				if rectangle.intersects(other):
					clear = false
					break
			if clear:
				return candidate
	return best

func _point(world_point: Vector3) -> Vector2:
	if viewport.size.x <= 0 or viewport.size.y <= 0:
		return Vector2.ZERO
	return camera.unproject_position(world_point) * size / Vector2(viewport.size)

func _process(_delta: float) -> void:
	if is_instance_valid(viewport) and _view_size != Vector2(viewport.size):
		_view_size = Vector2(viewport.size)
		_layout()

func _draw() -> void:
	if not is_instance_valid(camera):
		return
	for index: int in pins.size():
		var location := _point(entries[index].position)
		var pin_center := pins[index].position+pins[index].size/2
		if location.distance_to(pin_center)>12:
			draw_line(location,pin_center,Color("55715aad"),1.5,true)
			draw_circle(location,3,Style.PAPER)
	if routes.has(hovered):
		var line := PackedVector2Array()
		for point: Vector3 in routes[hovered]:
			line.append(_point(point))
		if line.size() > 1:
			draw_polyline(line, Color("b76449"), 4, true)
	var current := _point(player_position)
	draw_circle(current, 12, Style.PAPER)
	draw_circle(current, 7, Style.CORAL)
	draw_arc(current, 15, 0, TAU, 40, Style.CORAL, 2, true)
