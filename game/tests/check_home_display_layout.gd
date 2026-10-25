extends "res://tests/capture_visual_refinement.gd"
## Native layout and real walk-up interaction check for the wardrobe/display fix.

var paths: Array[Dictionary] = []

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	output_dir = ProjectSettings.globalize_path("res://../docs/verification/home-display-layout")
	DirAccess.make_dir_recursive_absolute(output_dir)
	baseline = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT_ROOT + "/before/report.json"))
	protected_before = production_signature()
	source_before = source_signature()
	create_timer(150.0).timeout.connect(func(): check(false,"timeout"); finish())
	AudioServer.set_bus_mute(0, true)
	game = load("res://main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	if not await wait_for_room("village"):
		check(false,"scene_ready")
		await finish()
		return
	var state: Node = root.get_node("State")
	save_path = str(state.save_path)
	check(save_path == "user://validation-%d.json" % OS.get_process_id(),"isolated_save")
	game.muted = true
	game.voice.stop()
	game.sounds.enabled = false
	game.application_backgrounded = false
	game.ui.reduced_motion = true
	state.set_preference("fixed_day",true)
	state.set_preference("reduced_motion",true)
	await game.change_room("home")
	check(await wait_for_room("home"),"living_room_ready")
	game._close()
	game.living.set_day_phase("day",true)
	game.living.set_weather("clear",true)
	game.living.set_context({"fixed_day":true,"fixed_weather":true,"reduced_motion":true})
	await frames(30)
	check_display_projection("default")
	await capture("home-production","production_camera")
	await review_view("home","overview")
	await review_view("home","detail")
	var original_size: float = game.camera.size
	game.camera.size = 11.0
	check_display_projection("zoom")
	game.camera.size = original_size
	for id: String in ["memory_02","journey_discoveries","memory_02","home_exit"]:
		if not await walk_to(id): continue
		if id == "home_exit": continue
		await capture("approach-%d-" % paths.size()+id,"actual_follow_camera_after_walking")
		if id == "journey_discoveries":
			check_display_projection("approach")
			game.capturing_photo = true
			game.camera.size = 11.0
			check_display_projection("approach_zoom")
			await capture("display-close","zoomed_follow_camera_at_display")
			game.camera.size = original_size
			game.capturing_photo = false
		var press := InputEventKey.new()
		press.physical_keycode = KEY_E
		press.pressed = true
		Input.parse_input_event(press)
		await frames(2)
		press = InputEventKey.new()
		press.physical_keycode = KEY_E
		press.pressed = false
		Input.parse_input_event(press)
		await frames(2)
		check(game.ui.current_panel == ("discovery" if id == "journey_discoveries" else "memory"),"correct_panel/"+id,game.ui.current_panel)
		game._close()
	await finish()

func check_display_projection(view: String) -> void:
	var sprite := game.world.find_child("ConfirmedDiscoveries",true,false) as Sprite3D
	var wardrobe := game.world.find_child("Locus_02_Wardrobe",true,false) as MeshInstance3D
	check(sprite != null and wardrobe != null,"layout_nodes/"+view)
	if sprite == null or wardrobe == null: return
	var half: Vector2 = Vector2(sprite.texture.get_size()) * sprite.pixel_size * 0.5
	var display_points: Array[Vector3] = []
	for x: float in [-half.x,half.x]:
		for y: float in [-half.y,half.y]:
			display_points.append(sprite.global_transform * Vector3(x,y,0))
	var wardrobe_points: Array[Vector3] = []
	var box := wardrobe.mesh.get_aabb()
	for i: int in 8: wardrobe_points.append(wardrobe.global_transform * box.get_endpoint(i))
	var display_rect := screen_rect(display_points)
	var wardrobe_rect := screen_rect(wardrobe_points)
	check(not display_rect.intersects(wardrobe_rect),"display_does_not_cover_wardrobe/"+view,{"display":str(display_rect),"wardrobe":str(wardrobe_rect)})
	for node_name: String in ["Shop_Title_Beam","SG_COLLIDER_Home_Pantry","Home_Window_Left_Frame"]:
		var furniture := game.world.find_child(node_name,true,false) as MeshInstance3D
		check(furniture != null,"furniture_bounds_found/"+view+"/"+node_name)
		if furniture == null: continue
		var corners: Array[Vector3] = []
		for i: int in 8: corners.append(furniture.global_transform * furniture.mesh.get_aabb().get_endpoint(i))
		# Use the actual projected silhouettes; axis-aligned rectangles overlap
		# spuriously for two separate diagonal panels on the same rear wall.
		check(Geometry2D.intersect_polygons(screen_hull(display_points),screen_hull(corners)).is_empty(),"display_clear_of/"+view+"/"+node_name)
	# A room-wide object may leave the screen when zooming at the doorway;
	# require full visibility at the normal view and when approached for viewing.
	if view in ["default","approach"]: check(root.get_visible_rect().encloses(display_rect),"display_inside_view/"+view)

func screen_hull(points: Array[Vector3]) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector3 in points: result.append(game.camera.unproject_position(point))
	return Geometry2D.convex_hull(result)

func screen_rect(points: Array[Vector3]) -> Rect2:
	var result := Rect2(game.camera.unproject_position(points[0]),Vector2.ZERO)
	for point: Vector3 in points: result = result.expand(game.camera.unproject_position(point))
	return result

func walk_to(id: String) -> bool:
	game._navigate_to_id(id,false)
	var start: Vector3 = game.player.position
	for frame: int in 1800:
		await frames(1)
		if frame > 12 and game.player.path.is_empty(): break
	var ok: bool = str(game.nearest.get("id","")) == id and game.player.is_on_floor()
	paths.append({"id":id,"start":vector(start),"end":vector(game.player.position),"passed":ok})
	check(ok,"walk_and_select/"+id,{"nearest":game.nearest.get("id",""),"position":vector(game.player.position)})
	return ok

func source_signature() -> Dictionary:
	var result := super.source_signature()
	for path: String in ["res://scripts/discovery_controller.gd","res://scripts/journey_controller.gd"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func finish() -> void:
	if finishing: return
	finishing = true
	check(protected_before == production_signature(),"formal_saves_unchanged")
	check(source_before == source_signature(),"production_sources_unchanged_during_check")
	var failures := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var report := {"passed":failures.is_empty(),"checks":checks,"captures":captures,"paths":paths,"source_sha256":source_before,"formal_before":protected_before,"formal_after":production_signature(),"scope":"Native projection bounds, same-camera images and real CharacterBody walk-up/E-key interactions for the living-room wardrobe and discovery display only."}
	var file := FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	if save_path == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	print("HOME_DISPLAY_LAYOUT "+JSON.stringify({"checks":checks.size(),"failures":failures.size(),"captures":captures.size(),"paths":paths.size()}))
	quit(0 if failures.is_empty() else 1)
