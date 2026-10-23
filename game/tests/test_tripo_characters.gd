extends SceneTree
## Real skin data, deformation and native inspection evidence. No production writes.

const Art = preload("res://actors/character_art_v3.gd")
const Actor = preload("res://scripts/textbook_actor.gd")
const Builder = preload("res://scripts/world_builder.gd")
const Player = preload("res://scripts/player.gd")
const ACTOR_IDS := ["npc_bear_uncle","npc_rabbit_gardener","textbook_lingling","textbook_peter","textbook_anne","textbook_mingming","textbook_dongdong","textbook_tim","textbook_dino","textbook_miss_li","textbook_jim"]
const PROTECTED := ["user://island-save-v1.json","user://island-save-v1.json.bak"]
const CHARACTER_MANIFEST := "res://assets/characters/tripo_v1/manifest.json"
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var skin_rows: Array[Dictionary] = []
var action_frames: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var expression_rows: Array[Dictionary] = []
var runtime_sha256: Dictionary = {}
var before: Dictionary = {}
var capture_enabled := false
var requested_size := Vector2i(1440,900)
var output := ""
var image_output := ""
var stage: Node3D
var camera: Camera3D
var caption: Label

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		printerr("Tripo character validation requires -- --test-harness")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--art-width="): requested_size.x = arg.trim_prefix("--art-width=").to_int()
		if arg.begins_with("--art-height="): requested_size.y = arg.trim_prefix("--art-height=").to_int()
	_run.call_deferred()

func _run() -> void:
	Art.use_manifest(CHARACTER_MANIFEST)
	create_timer(240).timeout.connect(func(): printerr("TRIPO_CHARACTERS_V1_TIMEOUT"); quit(2))
	for path: String in PROTECTED: before[path] = _hash(path)
	runtime_sha256 = _runtime_hashes()
	var state: Node = root.get_node("State")
	state.save_path = "user://validation-tripo-characters-v1-%d.json" % OS.get_process_id()
	_check(str(state.save_path).begins_with("user://validation-tripo-characters-v1-"),"isolated State path before any mutable call")
	var output_tag := "tripo-wave-refinement" if OS.get_cmdline_user_args().has("--refinement") else "tripo-characters-v1"
	output = ProjectSettings.globalize_path("res://../docs/verification/"+output_tag)
	image_output = ProjectSettings.globalize_path("res://../docs/screenshots/"+output_tag+"/%dx%d/characters" % [requested_size.x,requested_size.y])
	DirAccess.make_dir_recursive_absolute(output)
	if capture_enabled: DirAccess.make_dir_recursive_absolute(image_output)
	root.size = requested_size
	await _ticks(3)
	if capture_enabled:
		_check(DisplayServer.get_name() != "headless","native capture uses a real rendering window")
		_check(DisplayServer.window_get_size() == requested_size and root.size == requested_size,"actual window matches requested physical size")
	_make_stage()
	await _ticks(2)
	_check(Actor.PROFILES.size() == ACTOR_IDS.size(),"fixture explicitly covers every implemented actor profile")
	for id: String in ACTOR_IDS:
		if _selected(id): await _test_actor(id)
	if _selected("player"): await _test_player()
	for path: String in PROTECTED:
		_check(_hash(path) == str(before[path]),"formal save unchanged: " + path)
	await _finish()

func _make_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("dbe6dd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e8eee6")
	environment.environment.ambient_light_energy = 0.34
	environment.environment.adjustment_enabled = true
	environment.environment.adjustment_saturation = 0.85
	environment.environment.adjustment_contrast = 0.96
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-28,0)
	sun.light_color = Color("fff9ef")
	sun.light_energy = 0.20
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.42
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40,140,0)
	fill.light_color = Color("e0e9ec")
	fill.light_energy = 0.08
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e4dfcd")
	material.roughness = 1.0
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.65
	camera.position = Vector3(4.6,3.0,7.2)
	stage.add_child(camera)
	camera.look_at(Vector3(0,1.15,0))
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24,18)
	caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_color",Color("283b37"))
	layer.add_child(caption)

func _test_actor(id: String) -> void:
	var actor: Node3D = Actor.new()
	_check(actor.configure(id),"implemented actor configures: " + id)
	stage.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.set_clock_state(true,true,false,false)
	actor.face(Vector3(0,0,3),true)
	# The inspection caption identifies the actor; world-space nameplates belong
	# to the separate gameplay captures and can clip during close-up bending.
	actor.name_label.visible = false
	await _ticks(2)
	var actual := _inspect_skin(actor,id)
	var status: Dictionary = actor.get_status()
	_check(int(status.get("skinned_meshes",-1)) == int(actual.mesh_count),"reported real skin count: " + id)
	_check(int(status.get("skin_bind_count",-1)) == int(actual.bind_count),"reported real bind count: " + id)
	_check(int(status.get("weighted_vertices",-1)) == int(actual.weighted_vertices),"reported actual weighted vertices: " + id)
	_check(not str(status.get("art_revision","")).is_empty(),"actor declares traceable art revision: " + id)
	_check(int(status.get("blend_shape_count",-1)) == int(actual.blend_shape_count),"reported real blend shape count: " + id)
	_check(_sorted_names(status.get("blend_shape_names",[])) == _sorted_names(actual.blend_shape_names),"reported real blend shape names: " + id)
	actual["status"] = status
	skin_rows.append(actual)
	actor.play_action("idle")
	caption.text = id + " / idle\nActual Godot skin; inspection stage"
	await _capture(id+"-idle.png")
	var initial := _sample_deformed(actor)
	_check(actor.play_action("wave","tripo-v1/"+id+"/wave"),"wave is supported: " + id)
	for frame: int in range(48): actor.advance_visual(1.0/60.0)
	var moved := _sample_deformed(actor)
	if id == "textbook_jim":
		var chair_initial := {}
		var chair_moved := {}
		for key: String in initial:
			if key.contains("Wheelchair"):
				chair_initial[key] = initial[key]
				chair_moved[key] = moved[key]
		_check(chair_initial.size() > 0 and _maximum_displacement(chair_initial,chair_moved) < 0.000001,"Jim wheelchair stays rigid while the upper body waves",{"sampled_vertices":chair_initial.size(),"max_displacement":_maximum_displacement(chair_initial,chair_moved)})
	var max_displacement := _maximum_displacement(initial,moved)
	_check(max_displacement > 0.01,"bound mesh actually deforms under wave: " + id,{"max_displacement":max_displacement})
	caption.text = id + " / wave 0.80 s\nActual Godot skin; inspection stage"
	await _capture(id+"-wave.png")
	actor.set_clock_state(false,false,false,false)
	var paused := _sample_deformed(actor)
	for frame: int in range(30): actor._process(1.0/60.0)
	_check(_maximum_displacement(paused,_sample_deformed(actor)) < 0.000001,"pause freezes actual skinned vertices: " + id)
	actor.set_clock_state(true,true,false,false)
	await _test_expressions(actor,id)
	# Each new silhouette needs a locomotion/contact still, including the skirt
	# and seated arms that share action names but have different geometry.
	actor.set_clock_state(true,true,false,false)
	for pose: String in (["take","give"] if id == "textbook_jim" else ["walk","give"]):
		_check(actor.play_action(pose,"tripo-v1/"+id+"/inspection-"+pose),"inspection action supported: "+id+"/"+pose)
		var pose_time := 0.28 if pose == "walk" else 1.1
		for frame: int in range(roundi(pose_time*60.0)): actor.advance_visual(1.0/60.0)
		caption.text = "%s / %s / %.2f s\nActual Godot skin; inspection stage" % [id,pose,pose_time]
		await _capture(id+"-"+pose+".png")
	var actions: Array[String] = ["wave"]
	if id == "npc_rabbit_gardener": actions.append_array(["pick","place"])
	elif id == "textbook_jim": actions.append("take")
	for action: String in actions:
		await _capture_action(actor,id,action)
	if id == "textbook_peter":
		await _test_held_props(actor)
	actor.queue_free()
	await process_frame

func _inspect_skin(owner: Node3D, id: String) -> Dictionary:
	var result: Dictionary = {"id":id,"mesh_count":0,"bind_count":0,"weighted_vertices":0,"blended_vertices":0,"invalid_vertices":0,"blend_shape_count":0,"blend_shape_names":[],"instances":[]}
	for node: Node in owner.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null: continue
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		_check(skeleton != null,"skin resolves an actual Skeleton3D: "+id+"/"+str(node.name))
		if skeleton == null: continue
		result.mesh_count += 1
		result.bind_count += mesh.skin.get_bind_count()
		for shape: int in range(mesh.mesh.get_blend_shape_count()):
			var shape_name := str(mesh.mesh.get_blend_shape_name(shape))
			result.blend_shape_count += 1
			if not result.blend_shape_names.has(shape_name): result.blend_shape_names.append(shape_name)
			var changed_vertices := 0
			for surface: int in range(mesh.mesh.get_surface_count()):
				var base: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var shape_arrays: Array = mesh.mesh.surface_get_blend_shape_arrays(surface)
				_check(shape < shape_arrays.size(),"real blend shape array exists: "+id+"/"+shape_name)
				if shape >= shape_arrays.size(): continue
				var target: PackedVector3Array = shape_arrays[shape][Mesh.ARRAY_VERTEX]
				_check(base.size() == target.size(),"blend shape preserves vertex correspondence: "+id+"/"+shape_name)
				for index: int in range(mini(base.size(),target.size())):
					var delta := target[index] if mesh.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE else target[index]-base[index]
					if delta.length() > 0.000001: changed_vertices += 1
			_check(changed_vertices > 0,"blend shape has actual nonzero vertex deltas: "+id+"/"+shape_name,changed_vertices)
			_check(is_zero_approx(mesh.get_blend_shape_value(shape)),"authored default expression weight is neutral: "+id+"/"+shape_name)
		var instance: Dictionary = {"path":str(owner.get_path_to(mesh)),"surfaces":mesh.mesh.get_surface_count(),"bind_count":mesh.skin.get_bind_count(),"skeleton_bones":skeleton.get_bone_count(),"vertices":0,"blended_vertices":0}
		for bind: int in range(mesh.skin.get_bind_count()):
			var bone := _bind_bone(mesh.skin,skeleton,bind)
			_check(bone >= 0 and bone < skeleton.get_bone_count(),"skin bind resolves bone: "+id+"/"+str(node.name)+"/"+str(bind))
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var influences: int = weights.size()/maxi(1,vertices.size())
			var format_valid: bool = vertices.size() > 0 and influences in [4,8] and indices.size() == weights.size() and weights.size() == vertices.size()*influences
			_check(format_valid,"surface has genuine bone-index and weight arrays: "+id+"/"+str(node.name)+"/"+str(surface))
			if not format_valid: continue
			for vertex: int in range(vertices.size()):
				var total := 0.0
				var nonzero := 0
				var valid := true
				for slot: int in range(influences):
					var at := vertex*influences+slot
					var weight := float(weights[at])
					valid = valid and is_finite(weight) and weight >= 0.0
					total += weight
					if weight > 0.00001:
						nonzero += 1
						valid = valid and indices[at] >= 0 and indices[at] < mesh.skin.get_bind_count()
				if total > 0.0: result.weighted_vertices += 1
				if nonzero > 1:
					result.blended_vertices += 1
					instance.blended_vertices += 1
				if not valid or absf(total-1.0) > 0.001: result.invalid_vertices += 1
			instance.vertices += vertices.size()
		result.instances.append(instance)
	_check(int(result.mesh_count) > 0 and int(result.weighted_vertices) > 0,"real skinned geometry exists: " + id)
	_check(int(result.blended_vertices) > 0,"smooth mixed-bone vertices exist: " + id)
	_check(int(result.invalid_vertices) == 0,"all weights finite, normalized and bound: " + id,result.invalid_vertices)
	_check(_sorted_names(result.blend_shape_names) == ["Blink","Smile","Talk"],"all three authored expression targets exist: "+id)
	return result

func _test_expressions(actor: Node3D, id: String) -> void:
	actor.play_action("idle")
	var blink_peak := 0.0
	for frame: int in range(300):
		actor.advance_visual(1.0/60.0)
		blink_peak = maxf(blink_peak,float(_shape_values(actor).get("Blink",0.0)))
	_check(blink_peak > 0.5,"real idle clock activates blink shape: "+id,blink_peak)
	actor.play_action("wave")
	actor.advance_visual(0.1)
	var smile := _shape_values(actor)
	_check(float(smile.get("Smile",0.0)) > 0.7 and is_zero_approx(float(smile.get("Talk",0.0))),"greeting enables the smile target: "+id)
	actor.play_action("talk")
	var mouth_samples: Array[float] = []
	for frame: int in range(7):
		actor.advance_visual(0.1)
		mouth_samples.append(float(_shape_values(actor).get("Talk",0.0)))
	_check(mouth_samples.min() > 0.0 and mouth_samples.max()-mouth_samples.min() > 0.05,"talk action drives a changing real mouth target: "+id,mouth_samples)
	if id in ["textbook_peter","npc_bear_uncle","textbook_dino","textbook_jim"]:
		caption.text = id + " / talk\nActual authored mouth blend shape"
		await _capture(id+"-talk.png")
	actor.set_clock_state(false,false,false,false)
	var paused := _shape_values(actor)
	for frame: int in range(30): actor._process(1.0/60.0)
	_check(paused == _shape_values(actor),"public paused clock freezes every expression weight: "+id)
	actor.set_clock_state(true,true,false,true)
	actor.advance_visual(0.1)
	var reduced := _shape_values(actor)
	_check(is_zero_approx(float(reduced.get("Blink",-1.0))) and is_zero_approx(float(reduced.get("Talk",-1.0))),"reduced motion disables blink and mouth cycling: "+id)
	expression_rows.append({"actor":id,"blink_peak":blink_peak,"greeting":smile,"talk_samples":mouth_samples,"paused":paused,"reduced_motion":reduced})
	actor.set_clock_state(true,true,false,false)
	actor.play_action("idle")

func _shape_values(owner: Node) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in owner.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for index: int in range(mesh.mesh.get_blend_shape_count()):
			result[str(mesh.mesh.get_blend_shape_name(index))] = mesh.get_blend_shape_value(index)
	return result

func _sorted_names(values: Variant) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values: result.append(str(value))
	result.sort()
	return result

func _runtime_hashes() -> Dictionary:
	var result: Dictionary = {CHARACTER_MANIFEST:_hash(CHARACTER_MANIFEST)}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_MANIFEST))
	for entry: Dictionary in manifest.get("characters",{}).values():
		for group: Dictionary in entry.get("groups",[]):
			var path: String = str(group.path)
			result[path] = _hash(path)
	for path: String in ["res://assets/characters/active-set.json",Art.GROUNDING_PATH,Art.GESTURE_PATH,"res://actors/character_art_v3.gd","res://actors/player_visual_v3.gd","res://scripts/textbook_actor.gd","res://scripts/player.gd","res://tests/test_tripo_characters.gd"]:
		result[path] = _hash(path)
	return result

func _sample_deformed(owner: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in owner.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null: continue
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null: continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = weights.size()/maxi(1,vertices.size())
			if influences not in [4,8]: continue
			for vertex: int in range(0,vertices.size(),maxi(1,vertices.size()/160)):
				var skinned := Vector3.ZERO
				for slot: int in range(influences):
					var at := vertex*influences+slot
					if weights[at] <= 0.0 or bones[at] < 0 or bones[at] >= mesh.skin.get_bind_count(): continue
					var bone := _bind_bone(mesh.skin,skeleton,bones[at])
					if bone < 0 or bone >= skeleton.get_bone_count(): continue
					skinned += (skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bones[at])*vertices[vertex])*weights[at]
				result[str(owner.get_path_to(mesh))+"/"+str(surface)+"/"+str(vertex)] = skeleton.global_transform*skinned
	return result

func _bind_bone(skin: Skin, skeleton: Skeleton3D, bind: int) -> int:
	var name: StringName = skin.get_bind_name(bind)
	return skeleton.find_bone(name) if not str(name).is_empty() else skin.get_bind_bone(bind)

func _maximum_displacement(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for key: String in first:
		if second.has(key): maximum = maxf(maximum,(first[key] as Vector3).distance_to(second[key]))
	return maximum

func _capture_action(actor: Node3D, id: String, action: String) -> void:
	actor.play_action("idle")
	actor.play_action(action,"tripo-v1/"+id+"/"+action)
	var duration := float(actor.get_action_duration(action))
	var frame_count := ceili(duration/0.1)
	for frame: int in range(frame_count+1):
		if frame > 0:
			for substep: int in range(6): actor.advance_visual(1.0/60.0)
		var time := minf(frame*0.1,duration)
		caption.text = "%s / %s / %.2f s\nActual skinned animation; inspection stage" % [id,action,time]
		var filename := "%s-%s/frame-%03d.png" % [id,action,frame]
		await _capture(filename)
		action_frames.append({"actor":id,"action":action,"time":time,"phase":actor.get_action_phase(),"file":filename if capture_enabled else "not_captured"})

func _test_held_props(actor: Node3D) -> void:
	var receipts_before: int = int(actor.get_status().semantic_receipt_count)
	for id: String in ["apple","basket","cake","travel_book","invitation","nameplate"]:
		actor.set_held_prop(id)
		actor.play_action("carry")
		for frame: int in range(12): actor.advance_visual(1.0/60.0)
		await _ticks(2)
		var kind := "book" if id == "travel_book" else id
		var held: Node3D = actor._held_prop
		var authored: Node3D = held.get_node_or_null("WorldArt_"+kind) if is_instance_valid(held) else null
		_check(is_instance_valid(held) and held.get_parent() == actor.hand_socket,"authored prop attaches to real semantic hand socket: "+id)
		_check(is_instance_valid(authored) and str(authored.get_meta("world_art_kind","")) == kind,"held prop loads its authored resource: "+id)
		if is_instance_valid(authored):
			_check(not authored.find_children("*","MeshInstance3D",true,false).is_empty() and authored.find_children("*","CollisionObject3D",true,false).is_empty(),"held visual has render meshes without new gameplay collision: "+id)
		caption.text = "Peter / carrying " + id + "\nAuthored prop on existing semantic hand socket"
		await _capture("held-"+id+".png")
	actor.set_held_prop("")
	await _ticks(2)
	_check(not is_instance_valid(actor._held_prop) and int(actor.get_status().semantic_receipt_count) == receipts_before,"changing display props never grants semantic receipts")

func _test_player() -> void:
	var builder := Builder.new()
	var visual: Node3D = builder.make_character("player")
	builder.free()
	var player: CharacterBody3D = Player.new()
	player.visual = visual
	player.camera = camera
	player.add_child(visual)
	stage.add_child(player)
	player.set_physics_process(false)
	await _ticks(2)
	skin_rows.append(_inspect_skin(visual,"player"))
	caption.text = "player / actual production visual\nSkin structure and authored silhouette"
	await _capture("player-idle.png")
	var initial := _sample_deformed(visual)
	for frame: int in range(23):
		for substep: int in range(6):
			player.walk_time += 12.0/60.0
			player._animate_limbs(true,1.0/60.0)
		caption.text = "player / walk / %.2f s\nProduction player animation driver; fixed inspection root" % (float(frame+1)*0.1)
		var filename := "player-walk/frame-%03d.png" % frame
		await _capture(filename)
		action_frames.append({"actor":"player","action":"walk","time":float(frame+1)*0.1,"file":filename if capture_enabled else "not_captured"})
	_check(_maximum_displacement(initial,_sample_deformed(visual)) > 0.01,"production player controller moves real skinned limbs")
	var outfit_nodes := visual.find_children("Body","MeshInstance3D",true,false)
	_check(not outfit_nodes.is_empty(),"player exposes Tripo Body mesh with a garment mask")
	var colors := {"yellow":Color("e6b946"),"pink":Color("d87e93"),"blue":Color("79aeca")}
	for id: String in colors:
		player.set_outfit(id)
		for node: Node in outfit_nodes:
			var mesh := node as MeshInstance3D
			var material := mesh.get_active_material(0) as ShaderMaterial
			_check(material != null and material.shader != null and material.get_shader_parameter("albedo_texture") != null,"player garment shader and original albedo survive serialization: " + id)
			_check(material != null and (material.get_shader_parameter("outfit_color") as Color).is_equal_approx(colors[id]) and bool(material.get_shader_parameter("recolor")) == (id != "yellow"),"actual player outfit material changes: " + id)
		caption.text = "player / outfit " + id + "\nProduction clothing API on the same skin"
		await _capture("player-outfit-"+id+".png")
	player.queue_free()
	await process_frame

func _ticks(count: int) -> void:
	for index: int in range(count): await process_frame

func _capture(filename: String) -> void:
	if not capture_enabled: return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var path := image_output.path_join(filename)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(picture.save_png(path) == OK,"native frame saved: " + filename)
	captures.append({"path":path,"sha256":_hash(path),"image_size":[picture.get_width(),picture.get_height()]})

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(condition: bool, label: String, detail: Variant = null) -> void:
	checks.append({"check":label,"passed":condition,"detail":detail})
	if not condition:
		failures.append(label)
		push_error("TRIPO_CHARACTERS_V1_FAIL: " + label + " " + str(detail))

func _finish() -> void:
	_check(runtime_sha256 == _runtime_hashes(),"runtime character resources and driver sources are unchanged during this run")
	var tested_ids: Array[String] = []
	for row: Dictionary in skin_rows: tested_ids.append(str(row.id))
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"check_details":checks,"skin_evidence":skin_rows,"expression_evidence":expression_rows,"runtime_sha256":runtime_sha256,"action_frames":action_frames,"captures":captures,"capture_enabled":capture_enabled,"requested_window":[requested_size.x,requested_size.y],"actual_display_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"actual_viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"protected_before":before,"scope":"All implemented NPCs and player real Skin/weight and Blink/Smile/Talk target arrays; NPC action drives CPU-sampled skin and expression weights, paused clock freezes both, reduced motion stops mouth/blink cycling. Six 10-Hz native action sequences, real held props and player clothing. Separate integrated tests cover gameplay and world UI inputs. Captured images require visual review; no performance or unimplemented curriculum claim."}
	report["tested_character_ids"] = tested_ids
	report["tested_character_count"] = tested_ids.size()
	report["scope"] = "Only the listed tested_character_ids: real Skin, normalized weights, Blink/Smile/Talk vertex targets, actual deformation, pause and reduced-motion behavior. Applicable captures include action sequences, held props, player clothing and Jim chair rigidity. Separate integrated tests cover gameplay and world UI. Captures require visual review; no performance or unimplemented curriculum claim."
	var prefix := "native" if capture_enabled else "headless"
	var file := FileAccess.open(output.path_join("%s-%dx%d-characters.json" % [prefix,requested_size.x,requested_size.y]),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("TRIPO_CHARACTERS_V1 " + JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures,"captures":captures.size()}))
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _selected(id: String) -> bool:
	var selected := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--character="):
			selected = true
			if arg.trim_prefix("--character=") == id: return true
	return not selected
