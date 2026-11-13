extends "res://tests/test_building_residents.gd"
## Exercise the production carry, wardrobe and furniture factories.
const Props = preload("res://actors/tripo_prop_library.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const Decor = preload("res://gameplay/free_grid_decor_studio.gd")
const PlayerVisual = preload("res://actors/player_visual_v3.gd")
var captured: Array[Dictionary] = []

func _run() -> void:
	root.get_node("State").save_path = "user://validation-expansion-props-%d.json" % OS.get_process_id()
	if output.is_empty(): output=ProjectSettings.globalize_path("res://../docs/verification/textbook-expansion-v1/props")
	DirAccess.make_dir_recursive_absolute(output)
	var before := FileAccess.get_sha256("user://island-save-v1.json") if FileAccess.file_exists("user://island-save-v1.json") else "missing"
	_make_stage()
	check(Props.entries().size()==16,"16 imported props in production catalog")
	for id: String in Props.entries():
		var row: Dictionary=Props.entries()[id]
		var model: Node3D
		if id in ["reading_sofa","walnut_bookshelf","music_gramophone","bunny_topiary"]: model=Decor.build_furniture_mesh(id)
		elif id in ["straw_hat","star_beret"]: model=Wardrobe.build_hat_mesh(id)
		elif id in ["school_pack","picnic_basket"]: model=Wardrobe.build_bag_mesh(id)
		else: model=Wardrobe.build_carried_prop(id)
		check(model!=null and str(model.get_meta("source_asset",""))=="prop_"+id,"production factory uses imported prop "+id)
		if model==null: continue
		model.free()
		model=Props.create(id)
		stage.add_child(model)
		var vertices:=0
		var triangles:=0
		var valid:=true
		for node: Node in model.find_children("*","MeshInstance3D",true,false):
			var mesh:=node as MeshInstance3D
			check(mesh.skin==null,"rigid prop is attached without unnecessary skin "+id)
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays:=mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				vertices+=points.size();triangles+=indices.size()/3
				for point: Vector3 in points: valid=valid and point.is_finite()
				valid=valid and mesh.get_active_material(surface)!=null
		check(vertices>500 and triangles<=16010 and valid,"bounded textured native mesh "+id,{"vertices":vertices,"triangles":triangles})
		var size: Array=row.bounds_size
		await _views(model,id,"display",maxf(float(size[0]),maxf(float(size[1]),float(size[2]))),float(size[1])*.5)
		model.free()
		rows.append({"id":id,"vertices":vertices,"triangles":triangles,"factory":true})
	for id: String in ["straw_hat","star_beret","school_pack","picnic_basket","train","whale_shell","nest","lantern","yarn","pumpkin","ice_cream","bread"]:
		var player: Node3D=PlayerVisual.new()
		player.configure("player")
		stage.add_child(player)
		if id in ["straw_hat","star_beret"]:player.set_hat(id)
		elif id in ["school_pack","picnic_basket"]:player.set_bag(id)
		else:player.set_carried_item(id)
		# Let the production arm blend reach its holding pose before judging fit.
		for settle: int in range(45):
			player.animate_player(false,1.0/60.0,0.0,"",0.0,false)
		player.skeleton.force_update_all_bone_transforms()
		await process_frame
		check(not player.find_children("TripoProp_"+id,"Node3D",true,false).is_empty(),"player socket uses imported prop "+id)
		await _views(player,id,"equipped",2.6,1.2)
		player.free()
	var after := FileAccess.get_sha256("user://island-save-v1.json") if FileAccess.file_exists("user://island-save-v1.json") else "missing"
	check(before==after,"formal save preserved")
	var failed:=checks.filter(func(row: Dictionary)->bool:return not row.passed)
	var report: Dictionary={"status":"PASS" if failed.is_empty() else "FAIL","checks":checks.size(),"failures":failed,"props":rows,"captures":captured,"native_capture":capture}
	var file:=FileAccess.open(output.path_join("props.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EXPANSION_PROPS_VALIDATED ",report.status," ",checks.size()," ",failed)
	quit(0 if failed.is_empty() else 1)

func _views(_model: Node3D,id: String,mode: String,extent: float,center_y: float) -> void:
	if not capture:return
	camera.size=maxf(extent*1.45,.5)
	for view: String in ["front","side","back"]:
		camera.position={"front":Vector3(0,center_y+extent*.18,extent*4),"side":Vector3(extent*4,center_y+extent*.18,0),"back":Vector3(0,center_y+extent*.18,-extent*4)}[view]
		camera.look_at(Vector3(0,center_y,0))
		caption.text="%s / %s / %s" % [str(Props.entries()[id].name),mode,view]
		await process_frame
		await RenderingServer.frame_post_draw
		var filename:=id+"-"+mode+"-"+view+".png"
		root.get_texture().get_image().save_png(output.path_join(filename))
		captured.append({"id":id,"mode":mode,"view":view,"file":filename})
