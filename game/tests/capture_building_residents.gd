extends SceneTree
## Native motion preview of five representative production resident rigs.
const Actor = preload("res://scripts/textbook_actor.gd")
const Residents = preload("res://actors/building_resident_catalog.gd")
const IDS := ["resident_classroom","resident_b","resident_m","resident_canteen","resident_art_room"]
var output := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	root.get_node("State").save_path="user://validation-resident-preview-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1440,720)
	var stage:=Node3D.new()
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("e3e8df")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("f1eee2")
	environment.environment.ambient_light_energy=.65
	stage.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-30,0)
	sun.light_energy=.7
	sun.shadow_enabled=true
	stage.add_child(sun)
	var floor_mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(40,40)
	floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("d5d6c7")
	material.roughness=1.0
	floor_mesh.material_override=material
	stage.add_child(floor_mesh)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH
	camera.size=10.2
	camera.position=Vector3(0,2.1,12)
	stage.add_child(camera)
	camera.look_at(Vector3(0,1.1,0))
	camera.current=true
	var layer:=CanvasLayer.new()
	stage.add_child(layer)
	var caption:=Label.new()
	caption.position=Vector2(24,22)
	caption.add_theme_font_override("font",load("res://assets/fonts/IslandSans.otf"))
	caption.add_theme_font_size_override("font_size",25)
	caption.add_theme_color_override("font_color",Color("294739"))
	layer.add_child(caption)
	var actors:Array[Node3D]=[]
	for i: int in range(IDS.size()):
		var actor:Node3D=Actor.new()
		if not actor.configure(IDS[i]):
			quit(1)
			return
		stage.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.position.x=(float(i)-2.)*1.8
		actor.name_label.visible=false
		actor.face(actor.global_position+Vector3(0,0,3),true)
		actors.append(actor)
	var frame_number:=0
	for item: Dictionary in [{"id":"idle","label":"待机","seconds":1.0},{"id":"walk","label":"行走","seconds":2.24},{"id":"greet_wave","label":"挥手","seconds":2.2},{"id":"give_item","label":"递物","seconds":2.2},{"id":"idle","label":"待机","seconds":.7}]:
		caption.text="Mesh2Motion 绑定 · Godot 原生动作预览\n%s — 苏老师 / 阿渡 / 团团 / 饭团 / 彩彩" % str(item.label)
		for actor:Node3D in actors:
			actor.animation_player.play("normal/"+str(item.id),0.0)
			actor.animation_player.advance(0.0)
		for frame: int in range(int(ceil(float(item.seconds)*24.))):
			for actor:Node3D in actors:
				var clip:Animation=actor.animation_player.get_animation("normal/"+str(item.id))
				var at:=float(frame)/24.
				if item.id=="walk": at=fmod(at,clip.length)
				actor.animation_player.seek(minf(at,clip.length),true,true)
				actor.skeleton.force_update_all_bone_transforms()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("frame-%04d.png" % frame_number))
			frame_number+=1
	print("RESIDENT_MOTION_CAPTURE_DONE ",frame_number)
	quit(0)
