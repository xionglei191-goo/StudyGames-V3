extends SubViewportContainer
## Real craft models, framed for the available space rather than a fixed tiny camera.
const Visual = preload("res://gameplay/creation_visuals.gd")
const Catalog = preload("res://gameplay/creation_catalog.gd")
const Style = preload("res://ui/island_theme.gd")
var stage: Node3D
var model: Node3D
var camera: Camera3D
var viewport: SubViewport
var angle := -0.22

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport = SubViewport.new()
	viewport.size = Vector2i(400,300)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-32,0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Style.SOFT
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Style.PAPER
	environment.environment.ambient_light_energy = 0.45
	stage.add_child(environment)
	Visual.box(stage,Vector3(16,0.04,16),Vector3(0,-0.04,0),Style.SOFT)
	resized.connect(redraw)

func redraw() -> void:
	if is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func show_design(design: Dictionary) -> Node3D:
	_clear_model()
	model = Visual.build(design)
	model.rotation.y = angle
	stage.add_child(model)
	var bounds := Visual.footprint(str(design.recipe))
	var height := bounds.y
	if design.recipe == "lantern": height = 1.7
	if design.recipe in ["cake","plate"]: height = 0.5
	_frame(Vector3(0,height*0.48,0),maxf(maxf(bounds.x,bounds.z),height)*1.65)
	return model

func turn() -> void:
	angle += PI/4
	if is_instance_valid(model): model.rotation.y = angle
	redraw()

func show_wish(wish: String) -> void:
	_clear_model()
	model = Node3D.new()
	stage.add_child(model)
	if wish == "stall":
		_prop("stand",Vector3(0,0,0),0.85,2)
		_prop("cake",Vector3(0,0.85,0),0.9,5)
		_prop("sign",Vector3(-1.0,0,0.25),0.65,9)
	elif wish == "collection":
		_prop("frame",Vector3(-0.6,0,-0.2),0.8,9)
		_prop("vase",Vector3(0.6,0,0.15),1.05,10)
		_prop("basket",Vector3(-0.35,0,0.65),0.8,2)
	else:
		_prop("rug",Vector3(0,0,0.2),1.1,8)
		_prop("shelf",Vector3(0.5,0,-0.7),0.85,9)
		_prop("table",Vector3(-0.55,0,0),0.65,2)
		_prop("stool",Vector3(0.45,0,0.6),0.85,9)
		_prop("vase",Vector3(-0.55,0.66,0),0.5,10)
	_frame(Vector3(0,0.5,0),3.5)

func _prop(recipe: String, position_value: Vector3, scale_value: float, color: int) -> void:
	var design := Catalog.blank_design(recipe)
	design.color = color
	if recipe == "rug": design.pattern = "8".repeat(4096)
	var item := Visual.build(design)
	item.position = position_value
	item.scale = Vector3.ONE*scale_value
	model.add_child(item)

func _frame(target: Vector3, extent: float) -> void:
	camera.size = maxf(1.2,extent)
	camera.position = target+Vector3(3,2.7,4)
	camera.look_at(target)
	redraw()

func _clear_model() -> void:
	if is_instance_valid(model):
		stage.remove_child(model)
		model.queue_free()
