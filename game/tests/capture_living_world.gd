extends SceneTree
## Isolated rendered inspection. Does not instantiate main or write game progress.

const Builder = preload("res://scripts/world_builder.gd")
const Living = preload("res://scripts/living_world.gd")
var directory := ProjectSettings.globalize_path("res://../docs/screenshots/v0.5.0/environment")
var stage: Node3D
var world: Node3D
var living: Node3D
var camera: Camera3D
var info: Dictionary
var captured: Array[Dictionary] = []

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		printerr("Capture requires -- --test-harness")
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(220).timeout.connect(func(): printerr("LIVING_CAPTURE_TIMEOUT"); quit(2))
	root.size = Vector2i(1280,800)
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(directory)
	var environment_rooms: Array = [] if OS.get_cmdline_user_args().has("--actors-only") else ["village","landmark_A"]
	for room: String in environment_rooms:
		await _load_room(room,false)
		var focus: Vector3 = Vector3(-6,5,-2) if room == "village" else _scene_center()
		var camera_size := 47.0 if room == "village" else 22.0
		_frame_camera(focus,camera_size,Vector3(18,25,24))
		for weather: String in ["clear","cloudy","light_rain","mist"]:
			for phase: String in ["dawn","day","dusk","night"]:
				living.set_context({"guided_prologue":false,"fixed_day":false,"fixed_weather":false,"reduced_motion":false,"dialogue_open":false,"learning_open":false,"memory_open":false,"story_day_phase":"","story_weather":"","auto_cycle":false,"backgrounded":false})
				living.set_day_phase(phase,true)
				living.set_weather(weather,true)
				living.world_time = 12.0
				living._focus_backgrounded = false
				living.tick(0.016)
				await _capture("%s-%s-%s" % [room,weather,phase],{"room":room,"weather":weather,"phase":phase,"kind":"environment","status":living.get_status()})
	for room: String in ["school","classroom"]:
		await _load_room(room,true)
		living.set_weather("clear",true)
		living.set_day_phase("day",true)
		var actors: Array = living.get_interactions()
		var center := Vector3.ZERO
		for entry: Dictionary in actors:
			center += entry.position as Vector3
		center /= maxf(actors.size(),1.0)
		_frame_camera(center + Vector3.UP * 1.1,9.0,Vector3(6,5,10))
		for entry: Dictionary in actors:
			var actor := entry.actor_ref as Node3D
			actor.face(camera.global_position)
			actor.play_action("wave")
			for index in range(7):
				actor.advance_visual(0.1)
		await _capture(room + "-core-group",{"room":room,"kind":"prototype_actors","status":living.get_status()})
		_frame_camera(center + Vector3.UP * 1.1,9.0,Vector3(18,25,24))
		await _capture(room + "-gameplay-angle-group",{"room":room,"kind":"unaltered_default_actor_positions_gameplay_camera_angle","status":living.get_status()})
		for entry: Dictionary in actors:
			var actor := entry.actor_ref as Node3D
			# Portrait inspection only: hide other actors, preserving positions and
			# all room architecture. Group views above retain default occlusion.
			for other: Dictionary in actors:
				(other.actor_ref as Node3D).visible = other.actor_ref == actor
			for old_actor: Node in world.get_children():
				if old_actor is Node3D and (old_actor.get_node_or_null("LegLeft") != null or old_actor.has_meta("art_revision")):
					(old_actor as Node3D).visible = false
				elif old_actor is Label3D and str((old_actor as Label3D).text) == "老师":
					(old_actor as Label3D).visible = false
			_frame_camera(actor.global_position + Vector3.UP * 1.2,3.6,Vector3(4.0,4.0,10.0))
			actor.face(camera.global_position)
			for index in range(7):
				actor.advance_visual(0.1)
			await _capture(room + "-portrait-" + str(entry.character_id),{"room":room,"kind":"isolated_rigid_bone_prototype_portrait_not_skinned","other_actors_hidden_for_inspection":true,"actor":actor.get_status()})
		for other: Dictionary in actors:
			(other.actor_ref as Node3D).visible = true
	var report := {"status":"CAPTURED_REQUIRES_VISUAL_REVIEW","captures":captured,"count":captured.size(),"main_scene_instantiated":false,"game_save_written":false,"renderer":RenderingServer.get_current_rendering_method(),"prototype_note":"Rigid BoneAttachment3D prototypes. No final skinned character acceptance."}
	var file := FileAccess.open(directory.path_join("actor-recapture-report.json" if OS.get_cmdline_user_args().has("--actors-only") else "capture-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("LIVING_CAPTURE_COMPLETE " + str(captured.size()) + " " + directory)
	if is_instance_valid(living):
		living.prepare_room_change()
	quit(0)

func _load_room(room: String, actors: bool) -> void:
	if is_instance_valid(stage):
		living.prepare_room_change()
		stage.queue_free()
		await process_frame
		await physics_frame
	stage = Node3D.new()
	root.add_child(stage)
	world = Builder.new()
	stage.add_child(world)
	info = world.build(room)
	await physics_frame
	await physics_frame
	living = Living.new()
	stage.add_child(living)
	living.configure(world,room,{"world_info":info,"spawn_core_actors":actors,"guided_prologue":false,"fixed_day":false,"fixed_weather":false,"auto_cycle":false,"reduced_motion":false})
	living.set_process(false)
	for entry: Dictionary in living.get_interactions():
		(entry.actor_ref as Node3D).set_process(false)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 360
	stage.add_child(camera)
	camera.current = true
	print("LIVING_CAPTURE_ROOM " + room)

func _scene_center() -> Vector3:
	var bounds: Rect2 = info.get("bounds",Rect2(-10,-10,20,20))
	return Vector3(bounds.get_center().x,0.5,bounds.get_center().y)

func _frame_camera(focus: Vector3, size: float, offset: Vector3) -> void:
	camera.size = size
	camera.global_position = focus + offset
	camera.look_at(focus,Vector3.UP)

func _capture(label: String, metadata: Dictionary) -> void:
	for index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := directory.path_join(label + ".png")
	var result := image.save_png(path)
	metadata.path = path
	metadata.save_error = result
	metadata.width = image.get_width()
	metadata.height = image.get_height()
	captured.append(metadata)
	print("LIVING_CAPTURE " + label + " " + str(result))
