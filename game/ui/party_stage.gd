extends SubViewportContainer
## Isolated table scene using the active authored character skins. Legs stay seated.
const Progress = preload("res://scripts/party_progress.gd")
const Visual = preload("res://actors/player_visual_v3.gd")
const Art = preload("res://actors/character_art_v3.gd")
const WorldArt = preload("res://scripts/world_art.gd")
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const PLACES := {"seat_1":Vector3(-0.65,0,-1.13),"seat_2":Vector3(0.65,0,-1.13),"seat_3":Vector3(-1.54,0,0.48),"seat_4":Vector3(1.54,0,0.48)}
const YAWS := {"seat_1":0.12,"seat_2":-0.12,"seat_3":1.32,"seat_4":-1.32}
var viewport: SubViewport
var scene_root: Node3D
var actors: Dictionary = {}
var current_layout: Dictionary = {}
var beat := -1
var elapsed := 0.0
var paused := true
var reduced_motion := false

func setup(layout: Dictionary) -> void:
	stretch = true
	custom_minimum_size = Vector2(250,250)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "PartyViewport"
	viewport.own_world_3d = true
	viewport.size = Vector2i(800,520)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var environment := WorldEnvironment.new()
	var config := Environment.new()
	config.background_mode = Environment.BG_COLOR
	config.background_color = Color("e6eadb")
	config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	config.ambient_light_color = Color("fff4dc")
	config.ambient_light_energy = 0.6
	environment.environment = config
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_energy = 0.45
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.3
	viewport.add_child(camera)
	camera.position = Vector3(0,5.4,8.8)
	camera.look_at(Vector3(0,0.8,0))
	set_layout(layout)

func set_layout(layout: Dictionary) -> void:
	current_layout = layout.duplicate(true)
	actors.clear()
	if is_instance_valid(scene_root):
		viewport.remove_child(scene_root)
		scene_root.queue_free()
	scene_root = Node3D.new()
	scene_root.name = "PartyStage"
	viewport.add_child(scene_root)
	_box(scene_root,"Rug",Vector3(0,-0.05,0),Vector3(4.7,0.06,3.9),Color("d1d9bd"))
	add_table(scene_root,str(layout.theme))
	for guest: String in Progress.GUESTS:
		var seat := str(layout.seats[guest])
		if seat.is_empty(): continue
		var person := Node3D.new()
		person.name = guest
		person.position = PLACES[seat]
		person.rotation.y = float(YAWS[seat])
		person.set_meta("seat",seat)
		scene_root.add_child(person)
		var visual := Visual.new()
		visual.configure(guest)
		person.add_child(visual)
		_pose_seated(visual)
		var skeleton: Skeleton3D = visual.skeleton
		# Ground both feet at their authored rest height, then fit the chair under the pelvis.
		var foot := skeleton.find_bone("Foot_L")
		var hips := skeleton.find_bone("Hips")
		var correction := skeleton.get_bone_global_rest(foot).origin.y - skeleton.get_bone_global_pose(foot).origin.y
		var position_value := skeleton.get_bone_pose_position(hips)
		position_value.y += correction
		skeleton.set_bone_pose_position(hips,position_value)
		skeleton.force_update_all_bone_transforms()
		var pelvis_y := skeleton.get_bone_global_pose(hips).origin.y * visual.scale.y
		var chair_y := maxf(0.22,pelvis_y - 0.145)
		add_chair(person,chair_y)
		person.set_meta("seat_height",chair_y)
		person.set_meta("pelvis_height",pelvis_y)
		person.set_meta("genuine_seated_pose",true)
		var tag := Label3D.new()
		tag.name = "GuestName"
		tag.font = Style.body_font()
		tag.font_size = 42
		tag.outline_size = 7
		tag.modulate = Color("394f3e")
		tag.outline_modulate = Color("fffaf0")
		tag.pixel_size = 0.0045
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.text = "%s\n%s号椅" % [guest.trim_prefix("textbook_").capitalize(),seat.trim_prefix("seat_")]
		tag.position = Vector3(0,2.36,0)
		person.add_child(tag)
		actors[guest] = visual

func set_beat(index: int) -> void:
	beat = index
	elapsed = 0.0
	paused = false

func _process(delta: float) -> void:
	if paused or not is_visible_in_tree(): return
	elapsed += delta
	for index: int in Progress.GUESTS.size():
		var guest := Progress.GUESTS[index]
		if not actors.has(guest): continue
		var visual: Node3D = actors[guest]
		var skeleton: Skeleton3D = visual.skeleton
		var speaking := beat == 1 and int(elapsed / 1.2) % 4 == index
		var waving := beat in [0,3] or speaking
		var sway := 0.0 if reduced_motion else sin(elapsed * 5.0 + index) * 0.13
		_rotate(skeleton,"UpperArm_R",Vector3(-1.8 + sway,0,-0.15) if waving else Vector3(-0.35,0,-0.06))
		_rotate(skeleton,"LowerArm_R",Vector3(-0.25,0,0) if waving else Vector3(-0.72,0,0))
		_rotate(skeleton,"Head",Vector3(0,0,0.02 * sin(elapsed * 2.0 + index)) if not reduced_motion and speaking else Vector3.ZERO)
		Art.expression(visual.meshes,elapsed,"talk" if speaking else "photo",reduced_motion)
		skeleton.force_update_all_bone_transforms()

static func _pose_seated(visual: Node3D) -> void:
	var skeleton: Skeleton3D = visual.skeleton
	for side: String in ["L","R"]:
		_rotate(skeleton,"UpperLeg_" + side,Vector3(-PI / 2.0,0,0))
		_rotate(skeleton,"LowerLeg_" + side,Vector3(PI / 2.0,0,0))
		_rotate(skeleton,"UpperArm_" + side,Vector3(-0.35,0,0.06 if side == "L" else -0.06))
		_rotate(skeleton,"LowerArm_" + side,Vector3(-0.72,0,0))
	skeleton.force_update_all_bone_transforms()

static func _rotate(skeleton: Skeleton3D, bone: String, value: Vector3) -> void:
	var index := skeleton.find_bone(bone)
	if index >= 0: skeleton.set_bone_pose_rotation(index,skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion.from_euler(value))

static func add_table(parent: Node3D, chosen_theme: String) -> Node3D:
	var table := Node3D.new()
	table.name = "WelcomeTable"
	table.set_meta("theme",chosen_theme)
	parent.add_child(table)
	_box(table,"TableTop",Vector3(0,0.91,0),Vector3(1.9,0.12,1.45),Color("b99162"))
	for x: float in [-0.72,0.72]:
		for z: float in [-0.49,0.49]: _box(table,"TableLeg",Vector3(x,0.44,z),Vector3(0.12,0.88,0.12),Color("a87f53"))
	_box(table,"Tablecloth",Vector3(0,0.98,0),Vector3(1.95,0.025,1.50),Color("e8bdc3") if chosen_theme == "flowers" else Color("a9c7dc"))
	_box(table,"ClothRunner",Vector3(0,1.0,0),Vector3(0.50,0.01,1.52),Color("f9e6c8"))
	for x: float in [-0.81,0.81]:
		for z: float in [-0.18,0.18]:
			var motif := Sprite3D.new()
			motif.name = "FlowerMotif" if chosen_theme == "flowers" else "StarMotif"
			motif.texture = Content.icon("F" if chosen_theme == "flowers" else "S")
			motif.pixel_size = 0.0016
			motif.rotation.x = -PI / 2.0
			motif.position = Vector3(x,1.003,z)
			table.add_child(motif)
	var cake: Node3D = WorldArt.create_prop("cake")
	if cake:
		table.add_child(cake)
		cake.position = Vector3(0,1.015,0)
		cake.scale = Vector3.ONE * 0.55
	for x: float in [-0.62,0.62]:
		for z: float in [-0.42,0.42]:
			var plate := MeshInstance3D.new()
			plate.name = "GuestPlate"
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.17
			cylinder.bottom_radius = 0.17
			cylinder.height = 0.025
			plate.mesh = cylinder
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("fff8e8")
			plate.material_override = material
			plate.position = Vector3(x,1.02,z)
			table.add_child(plate)
	return table

static func add_chair(parent: Node3D, height: float) -> void:
	_box(parent,"ChairSeat",Vector3(0,height - 0.04,0),Vector3(0.68,0.08,0.64),Color("b6895c"))
	_box(parent,"ChairCushion",Vector3(0,height + 0.005,0.02),Vector3(0.61,0.035,0.54),Color("efcf87"))
	_box(parent,"ChairBack",Vector3(0,height + 0.36,-0.33),Vector3(0.66,0.58,0.07),Color("c9a374"))
	for x: float in [-0.25,0.25]:
		for z: float in [-0.24,0.24]: _box(parent,"ChairLeg",Vector3(x,height / 2.0,z),Vector3(0.07,height,0.07),Color("aa7e53"))

static func _box(parent: Node3D, title: String, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = title
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func seated_evidence() -> Array:
	var result: Array = []
	for guest: String in Progress.GUESTS:
		if not actors.has(guest): continue
		var visual: Node3D = actors[guest]
		var skeleton: Skeleton3D = visual.skeleton
		var hip := skeleton.get_bone_global_pose(skeleton.find_bone("UpperLeg_L")).origin
		var knee := skeleton.get_bone_global_pose(skeleton.find_bone("LowerLeg_L")).origin
		var ankle := skeleton.get_bone_global_pose(skeleton.find_bone("Foot_L")).origin
		result.append({"guest":guest,"seat":visual.get_parent().get_meta("seat"),"thigh_forward":knee.z - hip.z,"thigh_vertical":absf(knee.y - hip.y),"shin_down":knee.y - ankle.y,"shin_horizontal":absf(knee.z - ankle.z),"pelvis_height":visual.get_parent().get_meta("pelvis_height"),"seat_height":visual.get_parent().get_meta("seat_height"),"source":Art.revision()})
	return result
