extends "res://tests/test_v6_home_school_immersion.gd"
## Verify the visible geometry used by the workbench and the non-destructive idle modifier.

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.scene_ready:
		await process_frame
	_check(str(root.get_node("State").save_path).begins_with("user://validation-"),"isolated_profile")
	game.muted = true
	game.ai_bridge.muted = true
	game.validation_mode = false
	game.application_backgrounded = false
	game.ui.reduced_motion = true
	for id: String in CastDirector.ROOM_CAST:
		await game.change_room(id)
		await _frames(3)
		var sun := game.world.get_node("DioramaSunLight") as DirectionalLight3D
		_check(sun.shadow_enabled and sun.directional_shadow_max_distance > game.camera_offset.length()+10.0,
			"shadows_reach_room_focus_"+id)
		for entry: Dictionary in CastDirector.actors_for_room(id):
			var actor: Node3D = game.living.get_actor(entry.id)
			_check(actor != null and actor._gaze != null,"attention_rig_"+str(entry.id))
			if actor == null: continue
			for mesh: MeshInstance3D in actor._art_meshes:
				var mat := mesh.get_active_material(0) as BaseMaterial3D
				_check(mat.albedo_texture.get_image().has_mipmaps() and mat.normal_texture.get_image().has_mipmaps(),
					"baked_mipmaps_"+str(entry.id))
	await game.change_room("music_room")
	await _frames(6)
	game.spatial_bench.open_workbench(game,"music_room","guitar",4)
	await _frames(24)
	var bench: Node3D = game.spatial_bench
	var guitar: Node3D = bench._prop_nodes.guitar
	var guitar_box: AABB = guitar.get_meta("art_bounds")
	_check(absf(guitar_box.size.y-1.6) < 0.003,"rack_displays_full_instrument")
	var neck := guitar.to_global(guitar_box.get_center()+Vector3.UP*guitar_box.size.y*0.36)
	_check(bench._pick_3d_prop_at_screen(game.camera.unproject_position(neck)) == "guitar","pick_neck_of_guitar")
	_check(bench._hidden_anchor_meshes.size() > 20,"rack_removes_duplicate_static_instruments")
	bench.close_workbench()
	_check(bench._hidden_anchor_meshes.is_empty(),"rack_restores_source_scene")
	await game.change_room("home_bedroom")
	await _frames(4)
	bench.open_workbench(game,"home_bedroom","coat",3)
	await _frames(24)
	for key: String in ["coat","dress","shirt"]:
		var holder: Node3D = bench._prop_nodes[key]
		var box: AABB = holder.get_meta("art_bounds")
		_check(absf(holder.position.y+box.end.y-(bench.CLOSET_ROD_Y+0.029))<0.002,"hanger_rests_on_rod_"+key)
	_check(not bench._selected_halo.visible,"no_floor_ring_under_hanging_coat")
	bench.select_bench_item("coat",true)
	await _frames(32)
	var coat: Node3D = bench._prop_nodes.coat
	var coat_box: AABB = coat.get_meta("art_bounds")
	_check(absf(coat.position.y+coat_box.end.y-(bench.CLOSET_ROD_Y+0.029))<0.002,"placed_coat_stays_on_rod")
	bench.close_workbench()
	game.queue_free()
	await _frames(2)
	await _check_gaze()
	print("HOME_SCHOOL_ART: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _check_gaze() -> void:
	var actor := preload("res://scripts/textbook_actor.gd").new()
	actor.configure("textbook_role_lingling_mother")
	root.add_child(actor)
	var visitor := Marker3D.new()
	root.add_child(visitor)
	visitor.position = Vector3(1.8,0,2.0)
	actor.attend_to(visitor)
	await _frames(90)
	_check(actor._gaze.angles.x>0.20 and actor._gaze.angles.x<=0.49,"looks_toward_nearby_visitor_within_limit")
	visitor.position = Vector3(0,0,-3)
	await _frames(90)
	_check(actor._gaze.angles.length()<0.01,"returns_to_idle_when_visitor_is_behind")
	actor.play_action("greet_wave")
	await _frames(4)
	_check(not actor._gaze.active,"authored_greeting_owns_pose")
	actor.play_action("idle")
	actor.set_clock_state(true,true,false,true)
	await _frames(4)
	_check(not actor._gaze.active and actor._gaze.angles==Vector2.ZERO,"reduced_motion_disables_idle_turn")
	visitor.queue_free()
	actor.queue_free()
	await _frames(2)
