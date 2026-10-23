extends SceneTree

const Actor = preload("res://scripts/textbook_actor.gd")
const Living = preload("res://scripts/living_world.gd")
const Actions = preload("res://actors/p1_action_source.gd")
var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var receipts: Array[Dictionary] = []
var finished: Array[Dictionary] = []
var actors: Dictionary = {}
var stage: Node3D
var living: Node3D
var output_path := ""
var _sole_samples: Dictionary = {}

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		printerr("P1 animation test requires -- --test-harness")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			output_path = argument.trim_prefix("--report=")
	_run.call_deferred()

func check(value: bool, label: String, detail: Variant = null) -> void:
	checks.append({"check":label,"passed":value,"detail":detail})
	if not value:
		push_error("P1_ACTOR_TEST " + label + " " + str(detail))

func _run() -> void:
	Engine.max_fps = 240
	stage = Node3D.new()
	root.add_child(stage)
	var world := Node3D.new()
	stage.add_child(world)
	_add_box(world,"Ground",Vector3(0,-0.5,0),Vector3(80,1,80),4)
	_add_box(world,"Obstacle",Vector3(-10,0.9,3.2),Vector3(2,1.8,0.5),1)
	_add_box(world,"Water",Vector3(-5,0.1,3.5),Vector3(2,0.2,3),9)
	var env_node := WorldEnvironment.new()
	env_node.environment = Environment.new()
	world.add_child(env_node)
	var crown := MeshInstance3D.new()
	crown.name = "P1_Tree_Canopy"
	crown.mesh = SphereMesh.new()
	crown.position = Vector3(12,2,0)
	world.add_child(crown)
	var water := MeshInstance3D.new()
	water.name = "ALPHA_River_Water"
	water.mesh = PlaneMesh.new()
	world.add_child(water)
	await physics_frame
	await physics_frame
	living = Living.new()
	stage.add_child(living)
	living.configure(world,"village",{"spawn_core_actors":false,"auto_cycle":false})
	living.set_process(false)
	var ids := ["peter","lingling","rabbit","dino","jim"]
	for index: int in range(ids.size()):
		var actor: Node3D = living.spawn_actor(ids[index],Vector3(index * 4,0.02,-6),{"validate_position":false})
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.face(actor.global_position + Vector3.FORWARD * -1.0,true)
		actor.action_contact.connect(_on_contact)
		actor.semantic_event.connect(_on_receipt)
		actor.action_finished.connect(_on_finished)
		actors[ids[index]] = actor
		check(actor.animation_player != null and actor.get_status().animation_system == "saved_AnimationLibrary_manual_AnimationPlayer","saved AnimationPlayer library " + ids[index])
		var actual_skinned: int = _count_valid_skinned_meshes(actor)
		check(actual_skinned > 0 and int(actor.get_status().skinned_meshes) == actual_skinned,"reported skin count matches real bound meshes " + ids[index],actual_skinned)
	for family: String in Actions.FAMILIES:
		for reduced: bool in [false,true]:
			var path := Actions.library_path(family,reduced)
			var library := load(path) as AnimationLibrary
			check(library != null,"saved library exists " + path)
			if library:
				for id: String in library.get_animation_list():
					var clip := library.get_animation(id)
					var method_keys := 0
					for track in range(clip.get_track_count()):
						if clip.track_get_type(track) == Animation.TYPE_METHOD:
							method_keys += clip.track_get_key_count(track)
					check(clip.get_track_count() >= 12 and method_keys == (1 if float(Actions.SPECS[id].contact_time) >= 0.0 else 0),"complete tracks and explicit contact marker " + family + "/" + id + (" reduced" if reduced else ""))
	for actor_id: String in actors:
		var actor: Node3D = actors[actor_id]
		for reduced: bool in [false,true]:
			actor.set_clock_state(true,true,false,reduced)
			for action: String in ["wave","reach","pick","place","give","take","photo"]:
				if not bool(actor.get_action_spec(action).allowed):
					check(not actor.play_action(action),"unsupported action rejected " + actor_id + "/" + action)
					continue
				_measure_action(actor_id,actor,action,reduced)
	var rabbit: Node3D = actors.rabbit
	rabbit.set_clock_state(true,true,false,false)
	rabbit.play_action("idle")
	var place_contact: Transform3D = rabbit.get_action_contact_transform("place")
	var pick_contact: Transform3D = rabbit.get_action_contact_transform("pick")
	check(place_contact.origin.z >= 0.78 and place_contact.origin.y >= 0.55 and place_contact.origin.y <= 0.68,"rabbit original basket contact fits height and safe reach",_v3(place_contact.origin))
	check(pick_contact.origin.y >= 0.95 and pick_contact.origin.y <= 1.2,"rabbit low branch contact",_v3(pick_contact.origin))
	_test_repeat_receipt(rabbit)
	_test_pause_and_reduce(rabbit)
	_test_wheelchair(actors.jim)
	_test_dino(actors.dino)
	_test_walk_foot_contact(actors.peter)
	_test_environment_switch(crown,water)
	await _test_physics_motion()
	var old_count: int = living.get_interactions().size()
	var original_npc := {"id":"original_rabbit","type":"npc","position":Vector3.ZERO}
	var shared_entries: Array = [original_npc]
	living.refresh_interactions(shared_entries)
	var stale_entry: Dictionary = actors.jim.get_interaction()
	living.remove_actor("jim")
	check(living.get_actor("jim") == null and living.get_interactions().size() == old_count - 1,"remove_actor clears references and interactions")
	check(shared_entries.size() == old_count and shared_entries.has(original_npc),"remove_actor immediately cleans caller interactions and preserves original NPC")
	await process_frame
	await process_frame
	check(not is_instance_valid(stale_entry.actor_ref),"removal fixture really contains a freed object")
	shared_entries.append(stale_entry)
	living.refresh_interactions(shared_entries)
	check(shared_entries.size() == old_count and shared_entries.has(original_npc),"refresh safely removes a freed actor reference after queue_free")
	var externally_freed: Node3D = living.spawn_actor("anne",Vector3(22,0.02,-6),{"validate_position":false})
	living.refresh_interactions(shared_entries)
	externally_freed.queue_free()
	await process_frame
	await process_frame
	living.set_context({"paused":false})
	living.refresh_interactions(shared_entries)
	check(living.get_actor("anne") == null and living.get_interactions().size() == old_count - 1,"external actor disposal is safe in lookup and clock updates")
	check(shared_entries.size() == old_count and shared_entries.has(original_npc),"external actor disposal clears dynamic rows without replacing original NPC")
	living.remove_actor("anne")
	var failures := checks.filter(func(row: Dictionary): return not bool(row.passed))
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"measurements":measurements,"contact_count":contacts.size(),"semantic_receipt_count":receipts.size(),"finished_count":finished.size(),"scope":"saved keyframe timing/contact/pause/reduced motion/obstacle-water behavior and real skin-count consistency; Tripo grounding samples deformed sole vertices, legacy art retains its original ellipsoid envelope; native captures provide visual evidence; no GPU performance acceptance"}
	if not output_path.is_empty():
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var output := FileAccess.open(output_path,FileAccess.WRITE)
		output.store_string(JSON.stringify(report,"\t"))
	print("P1_ACTOR_REPORT " + JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures,"measurements":measurements.size(),"rabbit_pick":_v3(pick_contact.origin),"rabbit_place":_v3(place_contact.origin)}))
	quit(0 if failures.is_empty() else 1)

func _measure_action(actor_id: String, actor: Node3D, action: String, reduced: bool) -> void:
	actor.play_action("idle")
	var source_position := actor.global_position
	var before_contacts := contacts.size()
	var before_finished := finished.size()
	var key := "measure/%s/%s/%s" % [actor_id,action,str(reduced)]
	actor.play_action(action,key)
	var expected_duration := float(actor.get_action_duration(action))
	var predicted: Transform3D = actor.global_transform * actor.get_action_contact_transform(action)
	var playback_before: Dictionary = actor.get_action_phase()
	actor.get_action_contact_transform(action)
	check(playback_before == actor.get_action_phase(),"contact prediction has no playback side effects " + key)
	var hand_start: Vector3 = actor.get_hand_socket_transform().origin
	var max_hand_travel := 0.0
	var minimum_foot_y := INF
	var elapsed := 0.0
	while not bool(actor.get_action_phase().complete) and elapsed < expected_duration + 0.2:
		actor.advance_visual(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		max_hand_travel = maxf(max_hand_travel,hand_start.distance_to(actor.get_hand_socket_transform().origin))
		minimum_foot_y = minf(minimum_foot_y,_lowest_foot(actor))
	check(absf(elapsed - expected_duration) <= 1.0 / 60.0 + 0.0001 and finished.size() == before_finished + 1,"measured duration and end event " + key,{"expected":expected_duration,"measured":elapsed})
	check(actor.global_position.distance_to(source_position) < 0.0001,"action does not teleport root " + key)
	check(max_hand_travel >= 0.25 or action == "photo","action visibly moves hand " + key,max_hand_travel)
	var contact_expected := float(actor.get_action_spec(action).contact_time) >= 0.0
	var error := -1.0
	if contact_expected:
		check(contacts.size() == before_contacts + 1,"one visual contact per invocation " + key)
		if contacts.size() > before_contacts:
			error = predicted.origin.distance_to(contacts[-1].world_position as Vector3)
			check(error < 0.002,"sampled contact matches actual socket " + key,error)
			check(float(contacts[-1].attachment_error) < 0.002,"actual hand socket node follows contact bone " + key,contacts[-1].attachment_error)
	if actor_id != "jim":
		check(minimum_foot_y >= -0.025,"standing feet never pass through floor " + key,minimum_foot_y)
	measurements.append({"actor":actor_id,"action":action,"reduced_motion":reduced,"expected_duration":expected_duration,"observed_duration":elapsed,"contact_error_m":error,"max_hand_travel_m":max_hand_travel,"minimum_foot_y":minimum_foot_y,"root_drift_m":source_position.distance_to(actor.global_position)})

func _test_repeat_receipt(actor: Node3D) -> void:
	var start_receipts := receipts.size()
	var start_contacts := contacts.size()
	for iteration in range(2):
		actor.play_action("give","repeat-identical-key")
		for frame in range(24):
			actor.advance_visual(0.1)
	check(receipts.size() == start_receipts + 1 and contacts.size() == start_contacts + 2,"replay has visual contact twice but semantic receipt once")

func _test_pause_and_reduce(actor: Node3D) -> void:
	actor.play_action("pick","pause-check")
	for frame in range(4):
		actor.advance_visual(0.1)
	var before: Dictionary = actor.get_action_phase()
	var before_hand: Transform3D = actor.get_hand_socket_transform()
	actor.set_clock_state(false,false,false,false)
	for frame in range(10):
		actor._process(0.1)
	check(actor.get_action_phase() == before and actor.get_hand_socket_transform().is_equal_approx(before_hand),"pause freezes clip, phase and hand socket")
	actor.set_clock_state(false,true,false,false)
	actor._process(0.1)
	check(actor.get_action_phase().elapsed == before.elapsed,"nonparticipating actor freezes during dialogue")
	actor.set_clock_state(false,true,true,false)
	actor._process(0.1)
	check(actor.get_action_phase().elapsed > before.elapsed,"participating actor may perform during dialogue")
	var before_switch := float(actor.get_action_phase().elapsed)
	actor.set_clock_state(true,true,false,true)
	check(is_equal_approx(float(actor.get_action_phase().elapsed),before_switch),"switch reduced motion preserves action phase")
	actor.play_action("idle")
	var idle_before: Transform3D = actor.get_hand_socket_transform()
	for frame in range(12):
		actor.advance_visual(0.1)
	check(actor.get_hand_socket_transform().is_equal_approx(idle_before),"reduced idle remains still")

func _test_wheelchair(actor: Node3D) -> void:
	check(not actor.play_action("walk") and not actor.play_action("stand") and not actor.play_action("pick"),"Jim rejects walk, stand and floor pick")
	check(not actor.move_to(actor.global_position + Vector3.RIGHT) and not actor.set_path(PackedVector3Array([actor.global_position + Vector3.RIGHT])),"Jim rejects navigation")
	actor.play_action("idle")
	var before := actor.global_position
	var feet: Array[Transform3D] = []
	for bone: String in ["UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R"]:
		feet.append(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone)))
	actor.play_action("take","jim-seated-receive")
	var seated := true
	for frame in range(132):
		actor.advance_visual(1.0 / 60.0)
		for index in range(feet.size()):
			var bone: String = ["UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R"][index]
			seated = seated and feet[index].is_equal_approx(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone)))
	check(seated and actor.global_position == before,"Jim seated leg/support transforms stay fixed throughout receive")

func _test_dino(actor: Node3D) -> void:
	actor.set_clock_state(true,true,false,false)
	actor.play_action("wave")
	var tail: int = actor.skeleton.find_bone("Tail")
	var wing: int = actor.skeleton.find_bone("Wing_L")
	var initial_tail: Quaternion = actor.skeleton.get_bone_pose_rotation(tail)
	var initial_wing: Quaternion = actor.skeleton.get_bone_pose_rotation(wing)
	for frame in range(8):
		actor.advance_visual(0.1)
	check(initial_tail.angle_to(actor.skeleton.get_bone_pose_rotation(tail)) > 0.1 and initial_wing.angle_to(actor.skeleton.get_bone_pose_rotation(wing)) > 0.1,"Dino has visible dedicated wing and tail keyframes")

func _test_walk_foot_contact(actor: Node3D) -> void:
	actor.set_clock_state(true,true,false,false)
	actor.play_action("walk")
	var minimum := INF
	var maximum_support_height := -INF
	for frame in range(140):
		actor.advance_visual(1.0 / 60.0)
		var support := _lowest_foot(actor)
		minimum = minf(minimum,support)
		maximum_support_height = maxf(maximum_support_height,support)
	check(minimum >= -0.025 and maximum_support_height <= 0.06,"walk cycle keeps one foot near floor",{"minimum_foot_y":minimum,"maximum_support_height":maximum_support_height})

func _test_environment_switch(crown: MeshInstance3D, water: MeshInstance3D) -> void:
	living._focus_backgrounded = false
	living.tick(0.1)
	var time_before := float(living.world_time)
	living.set_environment_effects_enabled(false)
	check(not living.get_status().environment_effects_enabled and water.material_overlay == null and crown.basis.is_equal_approx(Basis.IDENTITY),"environment comparison switch removes presentation effects")
	living.tick(0.1)
	check(living.world_time > time_before and living.get_interactions().size() == actors.size(),"effects disabled preserves clock and actors")
	living.set_environment_effects_enabled(true)
	check(water.material_overlay != null,"environment effects can be restored")

func _test_physics_motion() -> void:
	var actor: Node3D = actors.peter
	actor.set_clock_state(true,true,false,false)
	actor.global_position = Vector3(-10,0.02,0)
	actor.set_physics_process(true)
	actor.set_process(true)
	actor.set_held_prop("apple")
	actor.play_action("carry")
	actor.move_to(Vector3(-10,0.02,6))
	for frame in range(150):
		await physics_frame
	check(actor.global_position.z < 2.85 and actor.global_position.z > 1.5,"carry walk respects obstacle collision",_v3(actor.global_position))
	check(actor.get_status().carrying_pose,"carry pose persists through path movement")
	actor.global_position = Vector3(-5,0.02,0)
	actor.move_to(Vector3(-5,0.02,6))
	for frame in range(150):
		await physics_frame
	check(actor.global_position.z < 2.1,"actor refuses submerged ground",_v3(actor.global_position))
	actor.set_process(false)
	actor.set_physics_process(false)

func _on_contact(id: String, action: String, key: String, invocation: int, socket: Transform3D) -> void:
	var actor: Node3D = living.get_actor(id)
	var attachment_error := (actor.hand_socket as Node3D).global_position.distance_to(socket.origin)
	contacts.append({"id":id,"action":action,"key":key,"invocation":invocation,"world_position":socket.origin,"attachment_error":attachment_error})

func _on_receipt(id: String, action: String, key: String) -> void:
	receipts.append({"id":id,"action":action,"key":key})

func _on_finished(id: String, action: String) -> void:
	finished.append({"id":id,"action":action})

func _count_valid_skinned_meshes(actor: Node3D) -> int:
	var count := 0
	for node: Node in actor.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		if instance.mesh != null and instance.skin != null and instance.skin.get_bind_count() > 0 and instance.get_node_or_null(instance.skeleton) is Skeleton3D:
			count += 1
	return count

func _lowest_foot(actor: Node3D) -> float:
	if str(actor.get_status().art_revision) == "tripo-character-v1":
		return _lowest_skinned_sole(actor)
	var lowest := INF
	for side: String in ["L","R"]:
		var pose: Transform3D = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("LowerLeg_" + side))
		var center := pose * Vector3(0,-0.31,0.085)
		var basis := pose.basis.scaled(Vector3(0.125,0.085,0.185))
		var radius_y := Vector3(basis.x.y,basis.y.y,basis.z.y).length()
		lowest = minf(lowest,center.y - radius_y)
	return lowest

func _lowest_skinned_sole(actor: Node3D) -> float:
	var key := actor.get_instance_id()
	if not _sole_samples.has(key):
		var samples: Array[Dictionary] = []
		for node: Node in actor.find_children("*","MeshInstance3D",true,false):
			var mesh := node as MeshInstance3D
			if mesh.skin == null: continue
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var binds: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var influences: int = weights.size()/maxi(1,vertices.size())
				var cells := {}
				for vertex: int in range(vertices.size()):
					if vertices[vertex].y > 0.22: continue
					var cell := Vector2i(floori(vertices[vertex].x/0.035),floori(vertices[vertex].z/0.035))
					if not cells.has(cell) or vertices[vertex].y < vertices[int(cells[cell])].y: cells[cell]=vertex
				for vertex: int in cells.values():
					var point := {"mesh":mesh,"vertex":vertices[vertex],"bones":[],"weights":[],"binds":[]}
					for slot: int in range(influences):
						var at := vertex*influences+slot
						if weights[at]<=0.00001: continue
						var bind := binds[at]
						var name := mesh.skin.get_bind_name(bind)
						point.bones.append(actor.skeleton.find_bone(name) if not str(name).is_empty() else mesh.skin.get_bind_bone(bind))
						point.binds.append(mesh.skin.get_bind_pose(bind))
						point.weights.append(weights[at])
					samples.append(point)
		_sole_samples[key]=samples
	var lowest := INF
	var poses := {}
	for sample: Dictionary in _sole_samples[key]:
		var position := Vector3.ZERO
		for influence: int in range(sample.bones.size()):
			var bone: int = sample.bones[influence]
			if not poses.has(bone): poses[bone]=actor.skeleton.get_bone_global_pose(bone)
			position+=(poses[bone]*sample.binds[influence]*sample.vertex)*float(sample.weights[influence])
		lowest=minf(lowest,(actor.skeleton.global_transform*position).y)
	return lowest

func _add_box(parent: Node3D, label: String, point: Vector3, size: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = point
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func _v3(value: Vector3) -> Array:
	return [value.x,value.y,value.z]
