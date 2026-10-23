extends SceneTree

const Living = preload("res://scripts/living_world.gd")
const Actor = preload("res://scripts/textbook_actor.gd")
const Builder = preload("res://scripts/world_builder.gd")
var checks: Array[Dictionary] = []
var receipts: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String, detail: Variant = null) -> void:
	checks.append({"check":label,"passed":condition,"detail":detail})
	if not condition:
		push_error("LIVING_TEST " + label + " " + str(detail))

func _run() -> void:
	Engine.max_fps = 240
	var stage := Node3D.new()
	root.add_child(stage)
	var world := Node3D.new()
	stage.add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = 4
	ground.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(70, 1, 70)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.5
	ground.add_child(collision)
	world.add_child(ground)
	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_color = Color("d7e2d8")
	environment.ambient_light_energy = 0.70
	env_node.environment = environment
	world.add_child(env_node)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("b6d5e3")
	fill.light_energy = 0.2
	world.add_child(fill)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1,0,-1),Vector3(0,2,0),Vector3(1,0,-1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED,Color.GREEN,Color.BLUE])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2(0.5,1),Vector2.RIGHT])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0.2,0.1),Vector2(0.5,0.8),Vector2(0.9,0.1)])
	var source_mesh := ArrayMesh.new()
	source_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var crown := MeshInstance3D.new()
	crown.name = "Test_Tree_Canopy_01"
	crown.mesh = source_mesh
	crown.position = Vector3(8,1,0)
	world.add_child(crown)
	var original_transform := crown.transform
	var water := MeshInstance3D.new()
	water.name = "ALPHA_River_Water"
	water.mesh = source_mesh
	water.position.x = 15
	var base_material := StandardMaterial3D.new()
	base_material.vertex_color_use_as_albedo = true
	water.material_override = base_material
	world.add_child(water)
	var marker := Marker3D.new()
	marker.name = "SG_SPAWN"
	world.add_child(marker)
	var marker_transform := marker.transform
	var living := Living.new()
	stage.add_child(living)
	living.set_process(false)
	await physics_frame
	await physics_frame
	living.configure(world,"village",{"spawn_core_actors":false,"auto_cycle":false,"world_info":{"spawn":Vector3.ZERO,"marker_nodes":{"SG_SPAWN":marker},"interactions":[]}})
	living.set_process(false)
	check(living.get_status().foliage_count == 1 and living.get_status().water_count == 1,"captures only selected canopy/water")
	check(living.get_status().registered_identity_count == 144 and living.get_status().registered_textbook_identity_count == 142,"full source-scoped identity roster registered")
	check(not living.get_status().all_textbook_roster_produced and living.get_actor_catalog().prototype_identity_count == 11,"roster and prototype completion distinguished")
	for index in range(35):
		living.tick(0.1)
	check(crown.transform != original_transform,"wind changes crown node presentation")
	var preserved := true
	var after_arrays := source_mesh.surface_get_arrays(0)
	for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		preserved = preserved and arrays[field] == after_arrays[field]
	check(preserved,"vertices COLOR_0 UV and UV2 preserved")
	check(shape.size == Vector3(70,1,70) and collision.position.y == -0.5 and marker.transform == marker_transform,"collider and SG marker unchanged")
	check(water.material_override == base_material and water.material_overlay != null,"water preserves original material with additive overlay")
	var time_before := living.world_time
	var crown_before := crown.transform
	living.set_context({"dialogue_open":true})
	living.tick(0.1)
	check(living.world_time == time_before and crown.transform == crown_before,"dialogue freezes environment clock and geometry")
	check(living.performance_time > time_before,"performance clock remains available during dialogue")
	for key in ["learning_open","memory_open"]:
		living.set_context({"dialogue_open":false,key:true})
		living.tick(0.1)
		check(living.world_time == time_before,key + " freezes environment")
		living.set_context({key:false})
	living.set_context({"paused":true})
	var perf_before := living.performance_time
	living.tick(10.0)
	check(living.world_time == time_before and living.performance_time == perf_before,"pause freezes both clocks")
	living.set_context({"paused":false,"backgrounded":true})
	living.tick(10.0)
	check(living.world_time == time_before and living.performance_time == perf_before,"background freezes both clocks without catchup")
	living.set_context({"backgrounded":false})
	living.tick(10.0)
	check(is_equal_approx(living.world_time - time_before,0.1),"large resume delta capped")
	for weather in ["clear","cloudy","light_rain","mist"]:
		check(living.set_weather(weather,true) and living.get_status().weather == weather,"weather " + weather)
	for phase in ["dawn","day","dusk","night"]:
		check(living.set_day_phase(phase,true) and living.get_status().day_phase == phase,"phase " + phase)
	living.set_weather("light_rain",true)
	check(living.get_status().rain_visible,"rain visible outdoors")
	living.set_context({"reduced_motion":true})
	check(crown.transform.is_equal_approx(original_transform) and not living.get_status().rain_visible,"reduced motion restores still crown and hides rain")
	check(is_zero_approx(float((water.material_overlay as ShaderMaterial).get_shader_parameter("ripple_strength"))),"reduced motion disables water ripples")
	living.set_context({"fixed_day":true,"fixed_weather":true})
	check(living.get_status().weather == "clear" and living.get_status().day_phase == "day","comfort fixed options override cycle")
	living.set_context({"fixed_day":false,"fixed_weather":false,"guided_prologue":true})
	check(living.get_status().weather == "clear" and living.get_status().day_phase == "day","guided prologue stays clear day")
	living.set_context({"dialogue_open":true,"story_day_phase":"dawn"})
	check(living.get_status().day_phase == "dawn" and environment.background_color.is_equal_approx(Color("e3ddc9")),"story dawn overrides guide and applies while dialogue paused")
	living.set_context({"story_day_phase":""})
	check(living.get_status().day_phase == "day" and environment.background_color.is_equal_approx(Color("d5e2d6")),"clearing story phase restores guided daylight")
	living.set_context({"dialogue_open":false})
	living.set_context({"guided_prologue":false,"reduced_motion":false})
	var actor_ids := Actor.PROFILES.keys()
	for index in range(actor_ids.size()):
		var actor: Node3D = living.spawn_actor(str(actor_ids[index]),Vector3(-14 + index * 2.5,0.02,-8),{"validate_position":false})
		check(actor != null,"actor construct " + str(actor_ids[index]))
		if actor:
			actor.set_process(false)
			var actual_skins := 0
			for instance: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
				if instance.mesh!=null and instance.skin!=null and instance.skin.get_bind_count()>0 and instance.get_node_or_null(instance.skeleton) is Skeleton3D: actual_skins+=1
			check(actor.get_status().bones >= 11 and actual_skins>0 and actor.get_status().skinned_meshes == actual_skins,"authored skin matches actual skeleton " + str(actor_ids[index]))
			check(actor.name_label.get_parent() == actor and actor.interaction_anchor.get_parent() == actor,"name and interaction follow body " + str(actor_ids[index]))
	living.semantic_event.connect(func(id: String, action: String, key: String): receipts.append({"id":id,"action":action,"key":key}))
	var lingling: Node3D = living.get_actor("lingling")
	check(living.play_actor_action("lingling","give","invitation-once"),"give action accepted")
	for index in range(30):
		lingling.advance_visual(0.1)
	check(receipts.size() == 1 and receipts[0].key == "invitation-once","give emits exactly one contact receipt")
	check(not lingling.play_action("not_an_action"),"unknown action rejected")
	var jim: Node3D = living.get_actor("jim")
	var jim_before := jim.global_position
	check(not jim.move_to(jim_before + Vector3.RIGHT) and not jim.set_path(PackedVector3Array([jim_before + Vector3.RIGHT])),"Jim cannot enter humanoid locomotion")
	var wheelchair := jim.skeleton.get_node_or_null("Accessories") as MeshInstance3D
	check(jim.play_action("wave") and wheelchair!=null and wheelchair.mesh!=null and wheelchair.get_aabb().size.x>0.7 and wheelchair.skin!=null,"Jim has authored wheelchair mesh and seated interaction")
	for index in range(15):
		jim.advance_visual(0.1)
	check(jim.global_position == jim_before,"Jim remains seated at original support")
	var dino: Node3D = living.get_actor("dino")
	check(dino.skeleton.find_bone("Tail") >= 0 and dino.skeleton.find_bone("Wing_L") >= 0,"Dino has dedicated tail and wing bones")
	var entries: Array = []
	living.refresh_interactions(entries)
	check(entries.size() == actor_ids.size(),"all actor interaction entries registered")
	lingling.global_position += Vector3.RIGHT
	living.refresh_interactions(entries)
	var synced := false
	for entry: Dictionary in entries:
		if str(entry.character_id) == "textbook_lingling":
			synced = entry.position == lingling.global_position
	check(synced and entries.size() == actor_ids.size(),"actor interaction position refresh without duplicates")
	living.set_context({"dialogue_open":true,"active_actor_ids":["lingling"]})
	var peter: Node3D = living.get_actor("peter")
	var lingling_time := float(lingling.get_status().visual_time)
	var peter_time := float(peter.get_status().visual_time)
	lingling._process(0.1)
	peter._process(0.1)
	check(float(lingling.get_status().visual_time) > lingling_time and peter.get_status().visual_time == peter_time,"dialogue advances only participating actor")
	living.set_context({"dialogue_open":false})
	check(lingling.move_to(lingling.global_position + Vector3(0,0,1.5)),"short dry path accepted")
	var walk_before := lingling.global_position
	for index in range(85):
		await physics_frame
	check(lingling.global_position.distance_to(walk_before) > 1.0,"actor actually walks with CharacterBody physics",lingling.global_position.distance_to(walk_before))
	check(absf(lingling.global_position.y - 0.02) < 0.03,"moving actor stays grounded")
	living.configure(world,"home",{"spawn_core_actors":false,"auto_cycle":false})
	check(crown.transform.is_equal_approx(original_transform) == false or living.get_status().foliage_count == 1,"targets safely released and rebound")
	living._release_targets()
	check(crown.transform.is_equal_approx(original_transform) and water.material_overlay == null,"release restores source presentation")
	check(fill.light_color == Color("b6d5e3") and is_equal_approx(fill.light_energy,0.2),"release restores fill light")
	living.prepare_room_change()
	check(not living._configured and living.get_interactions().is_empty(),"room transition disables tick and clears actors")
	world.queue_free()
	await process_frame
	living.tick(0.1)
	check(not living._configured,"room transition tick safe after old world freed")
	stage.queue_free()
	await process_frame
	await _check_real_rooms()
	var failures := checks.filter(func(row: Dictionary): return not bool(row.passed))
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"receipts":receipts,"scope":"headless component and actual home/school/classroom spawn; no visual production acceptance"}
	print("LIVING_WORLD_REPORT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _check_real_rooms() -> void:
	for room: String in ["home","school","classroom"]:
		var stage := Node3D.new()
		root.add_child(stage)
		var world := Builder.new()
		stage.add_child(world)
		var info: Dictionary = world.build(room)
		await physics_frame
		await physics_frame
		var living := Living.new()
		stage.add_child(living)
		var status: Dictionary = living.configure(world,room,{"world_info":info,"auto_cycle":false})
		living.set_process(false)
		var expected := 1 if room == "home" else 3 if room == "school" else 4
		check(status.actors.size() == expected and status.spawn_failures.is_empty(),"actual " + room + " all default actors safely spawned",status)
		for actor: Dictionary in status.actors:
			var body := living.get_actor(str(actor.character_id))
			check(body != null and not living._find_spawn_floor(body.global_position).is_empty(),room + " actor has dry floor " + str(actor.character_id))
		stage.queue_free()
		await process_frame
		await physics_frame
