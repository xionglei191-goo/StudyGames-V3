extends SceneTree
## Derived views of the exact shipped island meshes; no new letter geometry.
const Materials = preload("res://scripts/blender_materials.gd")
var model: Node3D
var stage: Node3D
var camera: Camera3D
var records: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness") or DisplayServer.get_name()=="headless":
		quit(2)
		return
	root.size = Vector2i(720,600)
	stage = Node3D.new()
	root.add_child(stage)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("f7f4e7")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff7e5")
	env.ambient_light_energy = 0.72
	env_node.environment = env
	stage.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-25,0)
	sun.light_energy = 0.55
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	stage.add_child(camera)
	model = (load("res://assets/world/island.glb") as PackedScene).instantiate()
	stage.add_child(model)
	Materials.restore_vertex_colors(model)
	for node: Node in model.find_children("*","VisualInstance3D",true,false):
		(node as VisualInstance3D).visible = false
	var destination := ProjectSettings.globalize_path("res://assets/learning/landmark_views")
	DirAccess.make_dir_recursive_absolute(destination)
	for letter: String in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		var landmark := model.find_child("ALPHA_"+letter+"_MODEL_ROOT",true,false) as Node3D
		if landmark==null:
			push_error("Missing original model: "+letter)
			quit(1)
			return
		var meshes := landmark.find_children("*","MeshInstance3D",true,false)
		var box := AABB()
		var first := true
		for raw: Node in meshes:
			var mesh := raw as MeshInstance3D
			mesh.visible = true
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
		var center := box.get_center()
		camera.size = maxf(box.size.y, maxf(box.size.x,box.size.z)*0.86)*1.38
		for view: String in ["front","angle"]:
			var offset := Vector3(0,0.24,1) if view=="front" else Vector3(0.72,0.62,1)
			camera.position = center+offset.normalized()*maxf(box.size.length()*2,15)
			camera.look_at(center,Vector3.UP)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var path := destination.path_join(letter+"-"+view+".png")
			var picture := root.get_texture().get_image()
			if picture.save_png(path)!=OK:
				quit(1)
				return
			records.append({"letter":letter,"view":view,"source_node":str(landmark.get_path()),"source_mesh_count":meshes.size(),"image":"res://assets/learning/landmark_views/"+letter+"-"+view+".png","sha256":FileAccess.get_sha256(path),"camera_position":var_to_str(camera.position),"camera_size":camera.size,"bounds":var_to_str(box),"pixels":[picture.get_width(),picture.get_height()]})
		for raw: Node in meshes: (raw as MeshInstance3D).visible = false
	var report := {"source":"res://assets/world/island.glb","source_sha256":FileAccess.get_sha256("res://assets/world/island.glb"),"engine":Engine.get_version_info().string,"capture_script_sha256":FileAccess.get_sha256("res://tests/capture_p2_landmarks.gd"),"records":records,"purpose":"Same original landmark model, isolated camera views; guidance overlays are separate UI."}
	var file := FileAccess.open(destination.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("P2_LANDMARK_CAPTURE ",records.size())
	quit(0)
