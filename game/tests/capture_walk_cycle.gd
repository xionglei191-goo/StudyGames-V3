extends SceneTree
## Native rendering of the production player/NPC drivers, using an isolated stage.
const Visual = preload("res://actors/player_visual_v3.gd")
const Actor = preload("res://scripts/textbook_actor.gd")
var output := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.get_node("State").save_path = "user://validation-walk-capture-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1200,720)
	if OS.get_cmdline_user_args().has("--gameplay"):
		await _capture_gameplay()
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e2e9e2")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("edf0eb")
	environment.environment.ambient_light_energy = 0.50
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d6d4c5")
	material.roughness = 1.0
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.9
	camera.position = Vector3(0,3.0,9)
	stage.add_child(camera)
	camera.look_at(Vector3(0,1.0,0))
	camera.current = true
	var players: Array[Node3D] = []
	for index: int in range(2):
		var player: Node3D = Visual.new()
		player.configure()
		stage.add_child(player)
		player.position.x = -2.0 + index * 1.35
		player.rotation.y = -PI * (0.5 if index == 0 else 0.18)
		players.append(player)
	var actors: Array[Node3D] = []
	for index: int in range(2):
		var actor: Node3D = Actor.new()
		actor.configure("peter" if index == 0 else "rabbit")
		stage.add_child(actor)
		actor.position.x = 0.75 + index * 1.45
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.name_label.visible = false
		actor.face(actor.global_position + Vector3(-1,0,0),true)
		actor.play_action("walk")
		actors.append(actor)
	for frame: int in range(156):
		var moving := frame >= 12 and frame < 132
		var phase := maxf(0.0,float(mini(frame,131)-12)) / 60.0 * TAU / 0.8
		for player: Node3D in players:
			player.animate_player(moving,1.0/60.0,phase,"",0.0,false)
		for actor: Node3D in actors:
			actor.advance_visual(1.0/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			root.get_texture().get_image().save_png(output.path_join("frame-%03d.png" % (frame/2)))
	print("WALK_CAPTURE_DONE ",output)
	quit(0)

func _capture_gameplay() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame: int in range(1800):
		await process_frame
		if game.scene_ready: break
	if not game.scene_ready:
		printerr("WALK_CAPTURE scene load timed out")
		quit(1)
		return
	game.muted = true
	game.voice.stop()
	game.ui.visible = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	root.add_child(camera)
	camera.current = true
	for frame: int in range(240):
		if frame in [20,110,190]:
			var target := "baker" if frame==110 else "home_gate"
			for entry: Dictionary in game.interactions:
				if str(entry.get("id","")) == target:
					game.navigate_to(entry.position)
		await physics_frame
		await process_frame
		var at: Vector3 = game.player.global_position
		camera.global_position = at+Vector3(4,2.6,6)
		camera.look_at(at+Vector3.UP*0.95)
		await RenderingServer.frame_post_draw
		if frame%2==0: root.get_texture().get_image().save_png(output.path_join("frame-%03d.png" % (frame/2)))
	print("WALK_GAMEPLAY_CAPTURE_DONE ",output)
	quit(0)
