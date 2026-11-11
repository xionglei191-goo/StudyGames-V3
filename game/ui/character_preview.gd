extends SubViewportContainer
## A real, isolated 3D preview; changing the outfit never replaces the main world.

var model: Node3D
var viewport: SubViewport
var spinning := false
var last_x := 0.0
var reduced_motion := false
var is_portrait := false

func setup(kind: String = "player", outfit: String = "yellow", portrait: bool = false) -> void:
	is_portrait = portrait
	stretch = true
	custom_minimum_size = Vector2(60,60) if portrait else Vector2(120,140)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE if portrait else Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.size = Vector2i(360, 420)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	model = preload("res://actors/player_visual_v3.gd").new()
	model.configure({"bear":"npc_bear_uncle","rabbit":"npc_rabbit_gardener","teacher":"textbook_miss_li"}.get(kind,kind))
	viewport.add_child(model)
	model.rotation.y = -0.22
	var environment := WorldEnvironment.new()
	var config := Environment.new()
	config.background_mode = Environment.BG_COLOR
	config.background_color = Color("f2efe2")
	config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	config.ambient_light_color = Color("fff5e2")
	config.ambient_light_energy = 0.78
	config.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = config
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-36, -32, 0)
	light.light_color = Color("fff6e5")
	light.light_energy = 0.72
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 148, 0)
	fill.light_color = Color("e2eff5")
	fill.light_energy = 0.34
	fill.shadow_enabled = false
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.15 if portrait else 3.40
	viewport.add_child(camera)
	camera.position = Vector3(0, 1.65, 6)
	camera.look_at(Vector3(0, 1.82 if portrait else 1.25, 0))
	if kind == "player": set_outfit(outfit)
	tooltip_text = "" if portrait else "按住拖动，看看另一面"

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(model): return
	model.animate_player(false,delta,0.0,"",0.0,reduced_motion)

func set_outfit(id: String) -> void:
	if not is_instance_valid(model):
		return
	if model.has_method("set_outfit"):
		model.set_outfit(id)
		return
	var colors := {"yellow":Color("e6b946"), "pink":Color("d87e93"), "blue":Color("79aeca")}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if "overall" in node.name.to_lower() or "outfit" in node.name.to_lower():
			var material := StandardMaterial3D.new()
			material.albedo_color = colors.get(id, colors.yellow)
			material.roughness = 0.88
			node.material_override = material

func set_wardrobe(outfit_id: String, hat_id: String = "none", bag_id: String = "none") -> void:
	if is_instance_valid(model) and model.has_method("set_wardrobe"):
		model.set_wardrobe(outfit_id, hat_id, bag_id)
	else:
		set_outfit(outfit_id)

func _gui_input(event: InputEvent) -> void:
	if is_portrait: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		spinning = event.pressed
		last_x = event.position.x
		accept_event()
	elif event is InputEventMouseMotion and spinning and is_instance_valid(model):
		model.rotation.y += (event.position.x-last_x) * 0.014
		last_x = event.position.x
		accept_event()
