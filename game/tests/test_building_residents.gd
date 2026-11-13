extends SceneTree
## Verify real resident skins, production actions, identity and native captures.
const Art = preload("res://actors/character_art_v3.gd")
const Actor = preload("res://scripts/textbook_actor.gd")
const Residents = preload("res://actors/building_resident_catalog.gd")
var checks: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var stage: Node3D
var camera: Camera3D
var caption: Label
var output := ""
var capture := false
var selected: Array[String] = []
var expansion := false

func catalog_entries() -> Dictionary:
	return Art.expansion_characters() if expansion else Residents.all()

func profile_for(id: String) -> Dictionary:
	return Art.character_entry(id).get("profile",{}) if expansion else Residents.profile(id)

func actions_for(id: String) -> Array:
	return Art.character_entry(id).get("allowed_actions",Actor.P1Actions.SPECS.keys()) if expansion else Actor.P1Actions.SPECS.keys()

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--expansion": expansion = true
		if arg == "--capture": capture = true
		if arg.begins_with("--only="): selected.assign(arg.trim_prefix("--only=").split(","))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok: push_error("RESIDENT_CHECK "+label+" "+str(detail))

func _run() -> void:
	root.get_node("State").save_path = "user://validation-residents-%d.json" % OS.get_process_id()
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../docs/verification/textbook-expansion-v1" if expansion else "res://../docs/verification/building-residents-v1")
	DirAccess.make_dir_recursive_absolute(output.path_join("captures"))
	create_timer(900 if expansion else 300).timeout.connect(func(): printerr("RESIDENT_VALIDATION_TIMEOUT"); quit(2))
	var before := FileAccess.get_sha256("user://island-save-v1.json") if FileAccess.file_exists("user://island-save-v1.json") else "missing"
	check(catalog_entries().size()==(40 if expansion else 34),"expected distinct authored characters")
	_make_stage()
	for id: String in catalog_entries():
		if not selected.is_empty() and not selected.has(id): continue
		await _test_actor(id)
	var after := FileAccess.get_sha256("user://island-save-v1.json") if FileAccess.file_exists("user://island-save-v1.json") else "missing"
	check(before==after,"formal save preserved")
	var failed := checks.filter(func(row: Dictionary) -> bool: return not row.passed)
	var report := {"status":"PASS" if failed.is_empty() else "FAIL","characters":rows.size(),"checks":checks.size(),"failures":failed,"rows":rows,"native_capture":capture,"scope":"Every skin weight; sampled production actions and finite deformation; 49-frame normal/reduced sole support for every allowed action (swimming excluded from sole criterion); native stills"}
	var file := FileAccess.open(output.path_join("characters.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RESIDENT_VALIDATION ",JSON.stringify({"status":report.status,"characters":rows.size(),"checks":checks.size(),"failures":failed}))
	quit(0 if failed.is_empty() else 1)

func _make_stage() -> void:
	root.size = Vector2i(1100,780)
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("e3e8df")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("f1eee2")
	world.environment.ambient_light_energy = 0.65
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d5d6c7")
	material.roughness = 1.0
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(3.0,2.0,7.5)
	stage.add_child(camera)
	camera.look_at(Vector3(0,1.1,0))
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(22,18)
	caption.add_theme_color_override("font_color",Color("2e453b"))
	caption.add_theme_font_override("font",load("res://assets/fonts/IslandSans.otf"))
	caption.add_theme_font_size_override("font_size",24)
	layer.add_child(caption)

func _test_actor(id: String) -> void:
	var actor: Node3D = Actor.new()
	var configured: bool = actor.configure(id)
	check(configured,"configures "+id)
	if not configured:
		actor.free()
		return
	stage.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.name_label.visible = false
	actor.face(Vector3(0,0,3),true)
	await process_frame
	var entry := Art.character_entry(id)
	check(str(entry.get("rigging_provider",{}).get("provider",""))=="Mesh2Motion","traceable Mesh2Motion skin "+id)
	if expansion:
		check(str(actor.display_name)==str(profile_for(id).get("name","")) and str(entry.get("source_sha256","")).length()==64,"correct imported identity "+id)
		camera.size = maxf(float(entry.height)*1.5,1.3)
		camera.position = Vector3(float(entry.height)*1.35,float(entry.height)*.9,float(entry.height)*3.4)
		camera.look_at(Vector3(0,float(entry.height)*.5,0))
	else:
		check(str(entry.get("room_id",""))==str(Residents.profile(id).room_id),"correct room identity "+id)
	var samples: Array[Dictionary] = []
	var feet: Array[Dictionary] = []
	var total := 0
	var bad := 0
	var blended := 0
	for node: Node in actor.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var influences := weights.size()/maxi(1,vertices.size())
			check(influences in [4,8] and indices.size()==weights.size(),"real skin arrays "+id)
			for vertex: int in range(vertices.size()):
				var sum := 0.0
				var nonzero := 0
				var sample := {"bones":[],"points":[],"weights":[],"rest":vertices[vertex]}
				for slot: int in range(influences):
					var at := vertex*influences+slot
					var weight := weights[at]
					if not is_finite(weight) or weight < 0.0: bad += 1
					sum += weight
					if weight <= 0.00001: continue
					nonzero += 1
					var bind := indices[at]
					var bone: int = actor.skeleton.find_bone(mesh.skin.get_bind_name(bind)) if not str(mesh.skin.get_bind_name(bind)).is_empty() else mesh.skin.get_bind_bone(bind)
					if bone < 0 or bone >= actor.skeleton.get_bone_count(): bad += 1
					sample.bones.append(bone)
					sample.points.append(mesh.skin.get_bind_pose(bind)*vertices[vertex])
					sample.weights.append(weight)
				if absf(sum-1.0)>0.001: bad += 1
				if nonzero>1: blended += 1
				if vertex%maxi(1,vertices.size()/600)==0: samples.append(sample)
				if vertices[vertex].y<0.22: feet.append(sample)
				total += 1
	check(total>1000 and bad==0,"all vertices weighted and finite "+id,{"vertices":total,"invalid":bad})
	check(blended>20,"joint weight transitions "+id,blended)
	var max_support := 0.0
	var min_sole := INF
	var max_action_support := 0.0
	var min_action_sole := INF
	var max_displacement := 0.0
	var finite := true
	for reduced: bool in [false,true]:
		var mode := "reduced" if reduced else "normal"
		for action: String in actions_for(id):
			var clip: Animation = actor.animation_player.get_animation(mode+"/"+action)
			check(clip!=null,"production action "+id+"/"+mode+"/"+action)
			if clip==null: continue
			actor.animation_player.play(mode+"/"+action,0.0)
			actor.animation_player.advance(0.0)
			for fraction: float in [0.0,.25,.5,.75,.99]:
				actor.animation_player.seek(clip.length*fraction,true,true)
				actor.skeleton.force_update_all_bone_transforms()
				for sample: Dictionary in samples:
					var point := _point(actor.skeleton,sample)
					finite = finite and point.is_finite() and point.length()<8.0
					max_displacement=maxf(max_displacement,point.distance_to(sample.rest))
		for action: String in actions_for(id):
			actor.animation_player.play(mode+"/"+action,0.0)
			actor.animation_player.advance(0.0)
			var length: float = actor.animation_player.get_animation(mode+"/"+action).length
			for frame: int in range(49):
				actor.animation_player.seek(length*float(frame)/48.0,true,true)
				actor.skeleton.force_update_all_bone_transforms()
				var lowest := INF
				for sample: Dictionary in feet: lowest=minf(lowest,_point(actor.skeleton,sample).y)
				min_action_sole=minf(min_action_sole,lowest)
				max_action_support=maxf(max_action_support,absf(lowest))
				if action in ["walk","carry_walk"]:
					min_sole=minf(min_sole,lowest)
					max_support=maxf(max_support,absf(lowest))
	check(finite and max_displacement>0.02,"sampled actions deform a bounded finite mesh "+id,max_displacement)
	if str(entry.get("locomotion","")) != "swim":
		check(max_support<0.028 and min_sole>-.022,"walk support plane "+id,{"maximum_error_m":max_support,"minimum_y_m":min_sole})
		check(max_action_support<0.01,"all grounded actions stay on support plane "+id,{"maximum_error_m":max_action_support,"minimum_y_m":min_action_sole})
	for action: String in ["idle","greet_wave","walk","give_item"]:
		if not actions_for(id).has(action): continue
		actor.animation_player.play("normal/"+action,0.0)
		actor.animation_player.advance(0.0)
		actor.animation_player.seek(0.0 if action=="idle" else .92 if action=="greet_wave" else .28 if action=="walk" else 1.1,true,true)
		actor.skeleton.force_update_all_bone_transforms()
		caption.text="%s · %s\n%s / %s" % [str(profile_for(id).name),str(profile_for(id).get("role",entry.get("locomotion",""))),id,action]
		if capture:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("captures").path_join(id+"-"+action+".png"))
	rows.append({"id":id,"vertices":total,"blended_vertices":blended,"invalid_vertices":bad,"bones":actor.skeleton.get_bone_count(),"maximum_walk_support_error_m":max_support,"minimum_sole_y_m":min_sole,"maximum_action_support_error_m":max_action_support,"minimum_action_sole_y_m":min_action_sole,"maximum_sampled_displacement_m":max_displacement})
	print("RESIDENT_VALIDATED ",id)
	actor.free()
	await process_frame

func _point(skeleton: Skeleton3D, sample: Dictionary) -> Vector3:
	var point := Vector3.ZERO
	for i: int in range(sample.bones.size()): point += (skeleton.get_bone_global_pose(sample.bones[i])*sample.points[i])*float(sample.weights[i])
	return point
