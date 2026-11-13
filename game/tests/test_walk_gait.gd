extends SceneTree
## Verify actual bone poses and independently skin all low foot vertices.
const Visual = preload("res://actors/player_visual_v3.gd")
const Actor = preload("res://scripts/textbook_actor.gd")
const Player = preload("res://scripts/player.gd")
var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var output := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok: push_error("WALK_GAIT "+label+" "+str(detail))

func _run() -> void:
	root.get_node("State").save_path = "user://validation-walk-gait-%d.json" % OS.get_process_id()
	var player: Node3D = Visual.new()
	player.configure()
	root.add_child(player)
	var samples := _sole_vertices(player,player.skeleton)
	for reduced: bool in [false,true]:
		for frame: int in range(120): player.animate_player(true,1.0/120.0,float(frame)/120.0*TAU/0.72,"",0.0,reduced)
		_measure_cycle("player"+("/reduced" if reduced else ""),player,player.skeleton,samples,true,reduced)
	_test_stop_and_frame_rates(player)
	player.set_carried_item("apple")
	for frame: int in range(60): player.animate_player(true,1.0/60.0,float(frame)/60.0*TAU,"",0.0,false)
	check(player.skeleton.get_bone_pose_rotation(player.skeleton.find_bone("UpperArm_R")).get_euler().x < -0.6,"carrying keeps the two-arm holding pose")
	player.set_carried_item("")
	for gesture: String in ["kick","wave","reach"]:
		for frame: int in range(48): player.animate_player(false,1.0/60.0,0.7*TAU,gesture,0.8-float(frame)/60.0,false)
		for frame: int in range(60): player.animate_player(false,1.0/60.0,0.7*TAU,"",0.0,false)
		check(player.skeleton.get_bone_pose_rotation(player.skeleton.find_bone("Foot_R")).angle_to(Quaternion.IDENTITY)<0.001,"foot recovers after "+gesture)
	player.free()
	for id: String in Actor.PROFILES:
		var actor: Node3D = Actor.new()
		actor.configure(id)
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		if id == "textbook_jim":
			check(not actor.play_action("walk"),"wheelchair keeps its seated animation contract")
			actor.free()
			continue
		var vertices := _sole_vertices(actor,actor.skeleton)
		for reduced: bool in [false,true]:
			actor.set_clock_state(true,true,false,reduced)
			for action: String in ["walk","carry_walk"]:
				var mode := "reduced" if reduced else "normal"
				actor.animation_player.play(mode+"/"+action,0.0)
				actor.animation_player.advance(0.0)
				_measure_cycle(id+"/"+mode+"/"+action,actor,actor.skeleton,vertices,false,reduced)
				actor.play_action("idle")
				check(actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("Foot_L")).angle_to(Quaternion.IDENTITY)<0.001,"NPC foot resets on idle: "+id+"/"+mode+"/"+action)
		actor.free()
	await _test_controller()
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row.passed)
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"measurements":measurements,"scope":"Actual skinned soles, swing clearance, knee range, cycle continuity, 30/60/120 Hz player blending, carry/gesture/idle reset; flat-ground inspection"}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("WALK_GAIT_REPORT ",JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _test_controller() -> void:
	# Exercise the production CharacterBody3D path, braking, turning and collision.
	for action: String in ["walk_left","walk_right","walk_up","walk_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var stage := Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	ground.collision_layer = 4
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40,1,40)
	ground_shape.shape = box
	ground_shape.position.y = -0.5
	ground.add_child(ground_shape)
	stage.add_child(ground)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(8,3,0.4)
	wall_shape.shape = wall_box
	wall.position = Vector3(0,1.5,5)
	wall.add_child(wall_shape)
	stage.add_child(wall)
	var camera := Camera3D.new()
	stage.add_child(camera)
	var player: CharacterBody3D = Player.new()
	var visual: Node3D = Visual.new()
	visual.configure()
	player.visual = visual
	player.camera = camera
	player.add_child(visual)
	stage.add_child(player)
	var samples := _sole_vertices(visual,visual.skeleton)
	var support_error := 0.0
	var lowest := 0.0
	var distance := 0.0
	var initial_phase := 0.0
	var old_position := Vector3.ZERO
	var blocked_phase := 0.0
	var stop_phase := 0.0
	for frame: int in range(510):
		if frame == 12:
			player.speed = 1.6
			player.path = PackedVector3Array([Vector3(0,0,4)])
			initial_phase = player.walk_time
			old_position = player.position
		if frame == 72:
			check(distance>1.4 and distance<1.8,"controller slow walk travels its requested distance",distance)
			check(absf(player.walk_time-initial_phase-distance*Player.WALK_PHASE_PER_METER)<0.001,"gait phase follows actual movement distance")
			player.speed = 5.2
			player.path = PackedVector3Array([Vector3(-3,0,3)])
		if frame == 132: player.path = PackedVector3Array([Vector3(3,0,3)])
		if frame == 192: player.path.clear()
		if frame == 222: stop_phase = player.walk_time
		if frame == 252:
			check(is_equal_approx(stop_phase,player.walk_time),"idle does not advance the feet")
			check(visual._walk_weight<0.001,"controller braking settles the gait")
			player.set_carried_item("apple")
			player.path = PackedVector3Array([Vector3(player.position.x,0,8)])
		if frame == 342: blocked_phase = player.walk_time
		if frame == 372:
			check(player.position.z<4.6 and is_equal_approx(blocked_phase,player.walk_time),"wall collision stops translation and foot cycling",player.position.z)
			player.reduced_motion = true
			player.path = PackedVector3Array([Vector3(0,0,-3)])
		if frame == 462: player.path.clear()
		await physics_frame
		await process_frame
		if frame>=12 and frame<72:
			distance += Vector2(player.position.x-old_position.x,player.position.z-old_position.z).length()
			old_position = player.position
		if frame>=12 and frame%6==0:
			var soles := _lowest(visual.skeleton,samples)*visual.scale.y
			var support := minf(soles.x,soles.y)+visual.global_position.y
			support_error = maxf(support_error,absf(support))
			lowest = minf(lowest,support)
			check(is_equal_approx(visual.position.y,player._visual_floor_offset) and visual.rotation.x==0.0 and visual.rotation.z==0.0,"controller keeps the support plane level / %d" % frame)
	check(support_error<0.025 and lowest> -0.015,"actual slow/full-speed/turn/carry/reduced-motion feet stay grounded",support_error)
	check(visual._walk_weight<0.001,"reduced-motion stop returns to idle")
	measurements.append({"id":"player_controller","maximum_flat_ground_support_error_m":support_error,"minimum_sole_world_y_m":lowest,"walk_phase_per_meter":Player.WALK_PHASE_PER_METER})
	stage.queue_free()
	await process_frame

func _measure_cycle(label: String, owner: Node3D, skeleton: Skeleton3D, samples: Array[Dictionary], player: bool, reduced: bool) -> void:
	var max_knee := Vector2.ZERO
	var min_knee := 180.0
	var max_clearance := Vector2.ZERO
	var min_sole := INF
	var max_support := -INF
	var max_jump := 0.0
	var previous: Array[Quaternion] = []
	var first: Array[Quaternion] = []
	var max_pelvis_step := 0.0
	var last_hips := Vector3.ZERO
	var hips := skeleton.find_bone("Hips")
	var frames := 160
	for frame: int in range(frames+1):
		var phase := float(frame)/frames
		if player:
			owner.animate_player(true,0.72/frames,phase*TAU,"",0.0,reduced)
		else:
			owner.animation_player.seek(phase*1.12,true,true)
		skeleton.force_update_all_bone_transforms()
		var pose: Array[Quaternion] = []
		for side: String in ["L","R"]:
			var knee := rad_to_deg(skeleton.get_bone_pose_rotation(skeleton.find_bone("LowerLeg_"+side)).get_euler().x)
			var at := 0 if side == "L" else 1
			max_knee[at] = maxf(max_knee[at],knee)
			min_knee = minf(min_knee,knee)
			for bone: String in ["UpperLeg_","LowerLeg_","Foot_"]:
				pose.append(skeleton.get_bone_pose_rotation(skeleton.find_bone(bone+side)))
		var soles := _lowest(skeleton,samples)
		min_sole = minf(min_sole,minf(soles.x,soles.y))
		max_support = maxf(max_support,minf(soles.x,soles.y))
		max_clearance.x = maxf(max_clearance.x,soles.x)
		max_clearance.y = maxf(max_clearance.y,soles.y)
		var pelvis := skeleton.get_bone_pose_position(hips)
		if frame == 0:
			first = pose
		else:
			for index: int in range(pose.size()): max_jump = maxf(max_jump,pose[index].angle_to(previous[index]))
			max_pelvis_step = maxf(max_pelvis_step,pelvis.distance_to(last_hips))
		last_hips = pelvis
		previous = pose
	var seam := 0.0
	for index: int in range(first.size()): seam = maxf(seam,first[index].angle_to(previous[index]))
	measurements.append({"id":label,"knee_max_deg":[max_knee.x,max_knee.y],"knee_min_deg":min_knee,"sole_min_m":min_sole,"support_max_m":max_support,"swing_clearance_m":[max_clearance.x,max_clearance.y],"max_sample_joint_step_deg":rad_to_deg(max_jump),"loop_seam_deg":rad_to_deg(seam),"max_pelvis_sample_step_m":max_pelvis_step,"sole_vertices":samples.size()})
	check(minf(max_knee.x,max_knee.y)>50.0 and maxf(max_knee.x,max_knee.y)<70.0,label+": both knees fold during swing")
	check(min_knee>=-0.1,label+": knees never hyperextend")
	check(min_sole>=-0.015 and max_support<0.025,label+": sole support stays on floor",[min_sole,max_support])
	check(minf(max_clearance.x,max_clearance.y)>0.035 and maxf(max_clearance.x,max_clearance.y)<0.25,label+": each foot clears the ground",[max_clearance.x,max_clearance.y])
	check(rad_to_deg(max_jump)<7.5 and rad_to_deg(seam)<0.2,label+": continuous joints across loop seam",[rad_to_deg(max_jump),rad_to_deg(seam)])
	check(max_pelvis_step<0.018,label+": no abrupt pelvis height change",max_pelvis_step)

func _test_stop_and_frame_rates(player: Node3D) -> void:
	var results: Array[Quaternion] = []
	for fps: int in [30,60,120]:
		player._walk_weight = 0.0
		for frame: int in range(fps):
			player.animate_player(true,1.0/fps,float(frame+1)/fps*TAU/0.72,"",0.0,false)
		results.append(player.skeleton.get_bone_pose_rotation(player.skeleton.find_bone("LowerLeg_L")))
		for frame: int in range(fps/2): player.animate_player(false,1.0/fps,0.7*TAU,"",0.0,false)
		check(player.skeleton.get_bone_pose_rotation(player.skeleton.find_bone("LowerLeg_L")).angle_to(Quaternion.IDENTITY)<0.001,"stop settles to rest at %d Hz" % fps)
	check(results[0].angle_to(results[1])<0.001 and results[1].angle_to(results[2])<0.001,"lower-body blend agrees at 30/60/120 Hz")

func _sole_vertices(owner: Node3D, skeleton: Skeleton3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in owner.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var binds: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var influences: int = weights.size()/maxi(vertices.size(),1)
			for vertex: int in range(vertices.size()):
				if vertices[vertex].y>0.22: continue
				var sample := {"side":0 if vertices[vertex].x<0 else 1,"bones":[],"points":[],"weights":[]}
				for slot: int in range(influences):
					var at := vertex*influences+slot
					if weights[at]<=0.00001: continue
					var bind := binds[at]
					var name := mesh.skin.get_bind_name(bind)
					sample.bones.append(skeleton.find_bone(name) if not str(name).is_empty() else mesh.skin.get_bind_bone(bind))
					sample.points.append(mesh.skin.get_bind_pose(bind)*vertices[vertex])
					sample.weights.append(weights[at])
				result.append(sample)
	return result

func _lowest(skeleton: Skeleton3D, samples: Array[Dictionary]) -> Vector2:
	var result := Vector2(INF,INF)
	var poses := {}
	for sample: Dictionary in samples:
		var point := Vector3.ZERO
		for index: int in range(sample.bones.size()):
			var bone: int = sample.bones[index]
			if not poses.has(bone): poses[bone] = skeleton.get_bone_global_pose(bone)
			point += (poses[bone]*sample.points[index])*float(sample.weights[index])
		result[sample.side] = minf(result[sample.side],point.y)
	return result
