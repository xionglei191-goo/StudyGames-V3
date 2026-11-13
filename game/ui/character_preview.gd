extends SubViewportContainer
## Sunlit isolated 3D character turntable & dialogue portrait preview.
## Changing the outfit here never mutates or reloads the main 3D world.

var model: Node3D
var viewport: SubViewport
var spinning := false
var last_x := 0.0
var reduced_motion := false
var is_portrait := false
var _target_yaw := -0.22

func setup(kind: String = "player", outfit: String = "yellow", portrait: bool = false) -> void:
	is_portrait = portrait
	stretch = true
	custom_minimum_size = Vector2(60, 60) if portrait else Vector2(120, 140)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE if portrait else Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.size = Vector2i(360, 420)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)

	if not portrait:
		var stand := Node3D.new()
		stand.name = "TurntablePedestal"
		viewport.add_child(stand)

		var wood_base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.88
		cyl.bottom_radius = 0.94
		cyl.height = 0.11
		cyl.radial_segments = 36
		wood_base.mesh = cyl
		wood_base.position = Vector3(0.0, -0.055, 0.0)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color("b58453")
		wmat.roughness = 0.52
		wood_base.material_override = wmat
		stand.add_child(wood_base)

		var felt_top := MeshInstance3D.new()
		var fcyl := CylinderMesh.new()
		fcyl.top_radius = 0.78
		fcyl.bottom_radius = 0.78
		fcyl.height = 0.025
		fcyl.radial_segments = 36
		felt_top.mesh = fcyl
		felt_top.position = Vector3(0.0, 0.004, 0.0)
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color("f6efdc")
		fmat.roughness = 0.82
		felt_top.material_override = fmat
		stand.add_child(felt_top)

	model = preload("res://actors/player_visual_v3.gd").new()
	model.configure({"bear": "npc_bear_uncle", "rabbit": "npc_rabbit_gardener", "teacher": "textbook_miss_li"}.get(kind, kind))
	viewport.add_child(model)
	_target_yaw = -0.22
	model.rotation.y = _target_yaw

	var environment := WorldEnvironment.new()
	var config := Environment.new()
	config.background_mode = Environment.BG_COLOR
	config.background_color = Color("f4efe1")
	config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	config.ambient_light_color = Color("fff6e4")
	config.ambient_light_energy = 0.84
	config.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = config
	viewport.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-36, -32, 0)
	light.light_color = Color("fff6e5")
	light.light_energy = 0.78
	viewport.add_child(light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 148, 0)
	fill.light_color = Color("e4f0f6")
	fill.light_energy = 0.38
	fill.shadow_enabled = false
	viewport.add_child(fill)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.15 if portrait else 3.45
	viewport.add_child(camera)
	camera.position = Vector3(0, 1.65, 6)
	camera.look_at(Vector3(0, 1.82 if portrait else 1.22, 0))
	if kind == "player":
		set_outfit(outfit)
	tooltip_text = "" if portrait else "按住左右拖动旋转查看全身穿搭"

func spin_by(delta_rad: float) -> void:
	if not is_instance_valid(model):
		return
	_target_yaw = model.rotation.y + delta_rad
	if reduced_motion:
		model.rotation.y = _target_yaw

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(model):
		return
	if not spinning and not is_portrait:
		var blend := 1.0 if reduced_motion else minf(1.0, delta * 12.0)
		model.rotation.y = lerpf(model.rotation.y, _target_yaw, blend)
	model.animate_player(false, delta, 0.0, "", 0.0, reduced_motion)

func set_outfit(id: String) -> void:
	if not is_instance_valid(model):
		return
	if model.has_method("set_outfit"):
		model.set_outfit(id)
		return
	var colors := {"yellow": Color("e6b946"), "pink": Color("d87e93"), "blue": Color("79aeca")}
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
	if is_portrait:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		spinning = event.pressed
		last_x = event.position.x
		accept_event()
	elif event is InputEventMouseMotion and spinning and is_instance_valid(model):
		model.rotation.y += (event.position.x - last_x) * 0.014
		_target_yaw = model.rotation.y
		last_x = event.position.x
		accept_event()
