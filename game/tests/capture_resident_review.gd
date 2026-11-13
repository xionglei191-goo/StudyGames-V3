extends "res://tests/test_building_residents.gd"
## Close native views requested by the independent deformation measurements.
var requests_path: String=""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--requests="): requests_path=arg.trim_prefix("--requests=")
	super._initialize()

func _run() -> void:
	if output.is_empty() or requests_path.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	root.get_node("State").save_path="user://validation-resident-review-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(output)
	var requests: Array=JSON.parse_string(FileAccess.get_file_as_string(requests_path))
	_make_stage()
	camera.size=3.1
	var actor: Node3D
	var id: String=""
	var captured: Array=[]
	for request: Dictionary in requests:
		if str(request.id)!=id:
			if is_instance_valid(actor): actor.free()
			id=str(request.id)
			actor=Actor.new()
			if not actor.configure(id):
				quit(1)
				return
			stage.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.name_label.visible=false
			actor.face(Vector3(0,0,3),true)
			if expansion: camera.size=maxf(float(Art.character_entry(id).height)*1.4,1.25)
		var action: String=str(request.action)
		var at: float=float(request.get("time",0.0))
		actor.animation_player.play(str(request.get("mode","normal"))+"/"+action,0.0)
		actor.animation_player.advance(0.0)
		actor.animation_player.seek(at,true,true)
		actor.skeleton.force_update_all_bone_transforms()
		for view: String in request.get("views",["front","side","back"]):
			camera.position={"front":Vector3(0,1.5,8),"side":Vector3(8,1.5,0),"back":Vector3(0,1.5,-8),"left":Vector3(-8,1.5,0),"threequarter":Vector3(4,2,8)}.get(view,Vector3(0,1.5,8))
			var center_y: float = float(Art.character_entry(id).height)*.5 if expansion else 1.1
			if expansion: camera.position.y=center_y + .1
			camera.look_at(Vector3(0,center_y,0))
			caption.text="%s · %s\n%s / %.3fs / %s" % [str(profile_for(id).name),id,action,at,view]
			await process_frame
			await RenderingServer.frame_post_draw
			var mode: String=str(request.get("mode","normal"))
			var file: String="%s-%s-%s%04d-%s.png" % [id,action,"reduced-" if mode=="reduced" else "",roundi(at*1000.),view]
			root.get_texture().get_image().save_png(output.path_join(file))
			captured.append({"id":id,"action":action,"mode":mode,"time":at,"view":view,"file":file})
		print("REVIEW_CAPTURE ",id," ",action," ",at)
	var file:=FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(captured,"\t"))
	file.close()
	print("REVIEW_CAPTURE_DONE ",captured.size())
	quit(0)
