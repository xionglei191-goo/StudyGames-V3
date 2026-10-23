extends SceneTree
## Frame-level movement regression plus engine-dispatched stop / zoom input.
const Player = preload("res://scripts/player.gd")
const Style = preload("res://ui/island_theme.gd")
var checks: Array = []
var samples: Array = []
var game: Node3D
var protected: Dictionary = {}
var save_path := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, id: String, detail: Variant = null) -> void:
	checks.append({"id":id,"passed":ok,"detail":detail})
	if not ok: push_error("COZY_CONTROL "+id)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]:
		protected[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	create_timer(120.0).timeout.connect(func(): push_error("COZY_CONTROL_TIMEOUT"); quit(2))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.scene_ready: await process_frame
	var state: Node = root.get_node("State")
	save_path = state.save_path
	check(save_path == "user://validation-%d.json" % OS.get_process_id(),"isolated_save")
	game.muted = true
	game.sounds.enabled = false
	game.ui.reduced_motion = true
	await movement_probe()
	await game.change_room("landmark_C")
	await frames(10)
	var baker: Dictionary = {}
	for entry: Dictionary in game.interactions:
		if str(entry.id)=="baker": baker = entry; break
	game._request_interaction(baker,true)
	await frames(12)
	check(not game.player.path.is_empty(),"route_started")
	await mouse(MOUSE_BUTTON_RIGHT,Vector2(720,450))
	var stopped: Vector3 = game.player.position
	await frames(12)
	check(game.player.path.is_empty() and game.pending_interaction.is_empty(),"right_click_cancels_route_and_interaction")
	check(Vector2(game.player.position.x-stopped.x,game.player.position.z-stopped.z).length()<0.02,"right_click_has_no_drift")
	check(not game.ui.modal.visible and not game.feedback.destination_ring.visible,"stop_clears_route_feedback_without_dialogue")
	var old_zoom: float = game.camera_base_size
	await mouse(MOUSE_BUTTON_WHEEL_UP,Vector2(720,450))
	check(game.camera_base_size<old_zoom,"wheel_zooms_in")
	await mouse(MOUSE_BUTTON_WHEEL_DOWN,Vector2(720,450))
	check(is_equal_approx(game.camera_base_size,old_zoom),"wheel_zooms_back_out")
	game.interact_id("baker")
	await frames(10)
	var framed := true
	for foot: Vector3 in [game.player.position,game.conversation_position]:
		for point: Vector3 in [foot,foot+Vector3.UP*3.35]:
			var pixel: Vector2 = game.camera.unproject_position(point)
			framed = framed and pixel.y>=30.0 and pixel.y<game.ui.panel.position.y-18.0
	check(framed,"dialogue_keeps_both_full_characters_above_card")
	game.journey.show_hub()
	await frames(3)
	check(not game.ui.hud.visible and game.ui.modal.visible,"journal_removes_background_hud")
	game._request_close()
	await frames(3)
	check(game.ui.hud.visible and not game.ui.modal.visible,"close_restores_play_hud")
	var font_ok := true
	for character: String in "小岛朋友邀请旅行册花朵星星早上好，。！？Aa Bb Cc What's your name? 0123456789":
		font_ok = font_ok and Style.body_font().has_char(character.unicode_at(0)) and Style.heading_font().has_char(character.unicode_at(0))
	check(font_ok,"rounded_fonts_cover_core_chinese_english_and_punctuation")
	for path: String in protected:
		check(protected[path] == (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"),"production_preserved/"+path)
	var failures := checks.filter(func(entry: Dictionary): return not entry.passed)
	var directory := ProjectSettings.globalize_path("res://../docs/verification/cozy-ui")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory = argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("controls-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"waypoint_samples":samples,"scope":"Actual physics and input dispatch; not a child usability or learning outcome study."},"  "))
	file.close()
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	print("COZY_CONTROLS checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func movement_probe() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 4
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,1,40)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(1000,-0.5,1000)
	arena.add_child(floor_body)
	var camera := Camera3D.new()
	arena.add_child(camera)
	var walker := Player.new()
	walker.camera = camera
	walker.bounds = Rect2(980,980,40,40)
	walker.position = Vector3(1000,0.1,1000)
	arena.add_child(walker)
	await frames(5)
	for index: int in range(1,33): walker.path.append(Vector3(1000+index*0.25,0,1000))
	var dips := 0
	var previous_speed := 0.0
	var abrupt_acceleration := false
	for frame: int in 120:
		await frames(1)
		var speed_value: float = Vector2(walker.velocity.x,walker.velocity.z).length()
		if frame>10 and walker.path.size()>3 and speed_value<4.7: dips += 1
		if frame<8 and speed_value-previous_speed>0.65: abrupt_acceleration = true
		if frame<8 or (frame>10 and walker.path.size()>3): samples.append({"frame":frame,"speed":speed_value,"points_left":walker.path.size()})
		previous_speed = speed_value
	check(dips==0,"dense_waypoints_do_not_interrupt_walking",{"slow_frames":dips})
	check(not abrupt_acceleration,"starts_with_short_acceleration")
	await frames(25)
	check(walker.path.is_empty() and absf(walker.position.x-1008)<0.25,"path_finishes_without_overshoot",walker.position.x)
	walker.touch_axis = Vector2.RIGHT
	await frames(15)
	var straight_speed: float = Vector2(walker.velocity.x,walker.velocity.z).length()
	walker.touch_axis = Vector2.ONE
	await frames(15)
	var diagonal_speed: float = Vector2(walker.velocity.x,walker.velocity.z).length()
	check(absf(straight_speed-diagonal_speed)<0.02,"diagonal_speed_matches_straight_speed")
	walker.path.append(walker.position+Vector3(5,0,0))
	await frames(1)
	check(walker.path.is_empty(),"manual_direction_takes_over_route")
	walker.touch_axis = Vector2.ZERO
	var released: Vector3 = walker.position
	await frames(12)
	check(Vector2(walker.velocity.x,walker.velocity.z).length()<0.01 and walker.position.distance_to(released)<0.35,"release_brakes_within_short_distance")
	walker.touch_axis = Vector2.RIGHT
	await frames(12)
	walker.locked = true
	await frames(1)
	check(Vector2(walker.velocity.x,walker.velocity.z).length()<0.01,"dialogue_lock_stops_immediately")
	arena.queue_free()
	await frames(2)

func mouse(index: MouseButton, point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = index
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
