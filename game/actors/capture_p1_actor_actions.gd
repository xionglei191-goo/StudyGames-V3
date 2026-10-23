extends SceneTree
## Native rendered evidence of the P1 saved keyframe libraries. Test props and
## camera close-ups are inspection fixtures, not additional production assets.

const Builder = preload("res://scripts/world_builder.gd")
const Actor = preload("res://scripts/textbook_actor.gd")
var output := ProjectSettings.globalize_path("res://../assets/characters/p1/validation")
var stage: Node3D
var world: Node3D
var actor: CharacterBody3D
var camera: Camera3D
var caption: Label
var apple: Node3D
var prop_fixture: Node3D
var drop_start := Vector3.ZERO
var drop_elapsed := -1.0
var frame_rows: Array[Dictionary] = []
var spawn := Vector3.ZERO

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(180).timeout.connect(func(): printerr("P1_ACTION_CAPTURE_TIMEOUT"); quit(2))
	root.size = Vector2i(960,600)
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(output)
	stage = Node3D.new()
	root.add_child(stage)
	world = Builder.new()
	stage.add_child(world)
	var info: Dictionary = world.build("school")
	spawn = info.spawn + Vector3(0,0.02,-1.0)
	await physics_frame
	await physics_frame
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.3
	camera.near = 0.1
	camera.far = 180
	stage.add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(18,14)
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_color",Color("fff7de"))
	caption.add_theme_color_override("font_outline_color",Color("263c35"))
	caption.add_theme_constant_override("outline_size",5)
	layer.add_child(caption)
	var scenarios := [
		{"actor":"peter","action":"wave"},{"actor":"lingling","action":"photo"},
		{"actor":"rabbit","action":"pick"},{"actor":"rabbit","action":"carry"},
		{"actor":"rabbit","action":"place"},{"actor":"dino","action":"wave"},
		{"actor":"jim","action":"take"},{"actor":"jim","action":"wave"}]
	for scenario: Dictionary in scenarios:
		await _capture_action(str(scenario.actor),str(scenario.action))
	var report := {"status":"CAPTURED_REQUIRES_VISUAL_REVIEW","renderer":RenderingServer.get_current_rendering_method(),"resolution":[960,600],"time_step":0.05,"scene":"existing school GLB","camera_direction":[18,25,24],"fixtures":"contact fruit/basket markers; no task or reward writes","frames":frame_rows}
	var file := FileAccess.open(output.path_join("capture-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P1_ACTION_CAPTURE_COMPLETE " + str(frame_rows.size()))
	quit(0)

func _capture_action(id: String, action: String) -> void:
	if is_instance_valid(actor):
		actor.queue_free()
	if is_instance_valid(apple):
		apple.queue_free()
	if is_instance_valid(prop_fixture):
		prop_fixture.queue_free()
	await process_frame
	actor = Actor.new()
	actor.configure(id)
	stage.add_child(actor)
	actor.global_position = spawn
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.face(spawn + Vector3(0,0,3),true)
	actor.action_contact.connect(_on_contact)
	var focus := spawn + Vector3.UP * 1.2
	if action == "carry":
		focus += Vector3.RIGHT * 1.0
	camera.size = 6.4 if action == "carry" else 4.3
	camera.global_position = focus + Vector3(18,25,24)
	camera.look_at(focus,Vector3.UP)
	drop_elapsed = -1.0
	prop_fixture = Node3D.new()
	stage.add_child(prop_fixture)
	var contact: Transform3D = actor.global_transform * actor.get_action_contact_transform(action)
	if action in ["pick","take"]:
		apple = _make_apple()
		stage.add_child(apple)
		apple.global_position = contact.origin
		var stem := CylinderMesh.new()
		stem.top_radius = 0.025
		stem.bottom_radius = 0.025
		stem.height = 0.5
		var support := MeshInstance3D.new()
		support.mesh = stem
		support.position = contact.origin + Vector3(0,0,0.26)
		support.rotation.x = PI * 0.5
		prop_fixture.add_child(support)
	elif action == "place":
		apple = _make_apple()
		actor.hand_socket.add_child(apple)
		var basket := MeshInstance3D.new()
		var basket_mesh := CylinderMesh.new()
		basket_mesh.top_radius = 0.34
		basket_mesh.bottom_radius = 0.26
		basket_mesh.height = 0.38
		basket_mesh.cap_top = false
		basket.mesh = basket_mesh
		basket.material_override = _material(Color("ad8a58"))
		basket.position = Vector3(contact.origin.x,0.28,contact.origin.z)
		prop_fixture.add_child(basket)
		var rim := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.30
		ring.outer_radius = 0.35
		rim.mesh = ring
		rim.material_override = _material(Color("c5a977"))
		rim.position = Vector3(contact.origin.x,0.50,contact.origin.z)
		prop_fixture.add_child(rim)
	elif action == "carry":
		actor.set_held_prop("apple")
	actor.play_action(action,"visual/" + id + "/" + action)
	if action == "carry":
		actor.set_physics_process(true)
		actor.move_to(spawn + Vector3.RIGHT * 2.8)
	var duration := 2.2 if action == "carry" else float(actor.get_action_duration(action))
	var folder := output.path_join(id + "_" + action)
	DirAccess.make_dir_recursive_absolute(folder)
	var frame_count := int(round(duration / 0.05))
	for frame: int in range(frame_count + 1):
		var elapsed := frame * 0.05
		if frame > 0:
			if action == "carry":
				for tick in range(3):
					await physics_frame
			actor.advance_visual(0.05)
			if drop_elapsed >= 0.0 and is_instance_valid(apple):
				drop_elapsed += 0.05
				apple.global_position = drop_start.lerp(Vector3(drop_start.x,0.43,drop_start.z),minf(drop_elapsed / 0.35,1.0))
		caption.text = "P1 / %s / %s / %.2f s\nSaved keyframes - rigid prototype, not skinned" % [str(actor.display_name),action,elapsed]
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var filename := folder.path_join("frame_%03d.png" % frame)
		var error := image.save_png(filename)
		var hand: Transform3D = actor.get_hand_socket_transform()
		frame_rows.append({"actor":id,"action":action,"time":elapsed,"path":filename,"save_error":error,"phase":actor.get_action_phase(),"hand_world":[hand.origin.x,hand.origin.y,hand.origin.z],"root_world":[actor.position.x,actor.position.y,actor.position.z]})
	print("P1_ACTION_CAPTURE " + id + " " + action + " " + str(frame_count + 1))

func _on_contact(_id: String, action: String, _key: String, _invocation: int, _socket: Transform3D) -> void:
	if not is_instance_valid(apple):
		return
	if action in ["pick_item","take_item"]:
		apple.reparent(actor.hand_socket,false)
		apple.transform = Transform3D.IDENTITY
	elif action == "place_item":
		drop_start = apple.global_position
		apple.reparent(stage,true)
		drop_elapsed = 0.0

func _make_apple() -> Node3D:
	var fruit := Node3D.new()
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.16
	shape.height = 0.30
	mesh.mesh = shape
	mesh.material_override = _material(Color("c97b62"))
	fruit.add_child(mesh)
	return fruit

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
