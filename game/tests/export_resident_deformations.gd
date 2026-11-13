extends SceneTree
## Export actual production skin transforms for independent mesh deformation review.
const Actor=preload("res://scripts/textbook_actor.gd")
const Residents=preload("res://actors/building_resident_catalog.gd")
var output: String=""
var selected: Array[String]=[]

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--only="): selected.assign(arg.trim_prefix("--only=").split(","))
	_run.call_deferred()

func _matrix(value: Transform3D) -> Array:
	return [value.basis.x.x,value.basis.y.x,value.basis.z.x,value.origin.x,value.basis.x.y,value.basis.y.y,value.basis.z.y,value.origin.y,value.basis.x.z,value.basis.y.z,value.basis.z.z,value.origin.z]

func _run() -> void:
	if output.is_empty():
		quit(2)
		return
	root.get_node("State").save_path="user://validation-resident-deformation-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(output)
	var expansion := OS.get_cmdline_user_args().has("--expansion")
	var entries: Dictionary = Actor.CharacterArt.expansion_characters() if expansion else Residents.all()
	for id: String in entries:
		if not selected.is_empty() and not selected.has(id): continue
		var actor: Node3D=Actor.new()
		if not actor.configure(id):
			quit(1)
			return
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		var geometries: Array=[]
		var mesh_nodes: Array[MeshInstance3D]=[]
		for node: Node in actor.find_children("*","MeshInstance3D",true,false):
			var mesh:=node as MeshInstance3D
			if mesh.skin==null: continue
			mesh_nodes.append(mesh)
			var surfaces: Array=[]
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays:=mesh.mesh.surface_get_arrays(surface)
				var points: PackedFloat32Array=[]
				for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: points.append_array([point.x,point.y,point.z])
				surfaces.append({"vertices":points,"weights":arrays[Mesh.ARRAY_WEIGHTS],"bones":arrays[Mesh.ARRAY_BONES],"triangles":arrays[Mesh.ARRAY_INDEX]})
			var resource_path: String=mesh.mesh.resource_path.split("::")[0]
			geometries.append({"name":str(mesh.name),"resource":resource_path,"resource_sha256":FileAccess.get_sha256(resource_path),"surfaces":surfaces})
		var poses: Array=[]
		for mode: String in ["normal","reduced"]:
			for action: String in Actor.P1Actions.SPECS:
				if not actor.animation_player.has_animation(mode+"/"+action): continue
				var clip: Animation=actor.animation_player.get_animation(mode+"/"+action)
				actor.animation_player.play(mode+"/"+action,0.0)
				actor.animation_player.advance(0.0)
				for sample: int in range(17):
					var time: float=clip.length*float(sample)/16.0
					actor.animation_player.seek(time,true,true)
					actor.skeleton.force_update_all_bone_transforms()
					var transforms: Array=[]
					for mesh: MeshInstance3D in mesh_nodes:
						var matrices: Array=[]
						for bind: int in range(mesh.skin.get_bind_count()):
							var bone: int=actor.skeleton.find_bone(mesh.skin.get_bind_name(bind)) if not str(mesh.skin.get_bind_name(bind)).is_empty() else mesh.skin.get_bind_bone(bind)
							matrices.append(_matrix(actor.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)))
						transforms.append(matrices)
					poses.append({"mode":mode,"action":action,"time":time,"transforms":transforms})
		var names: Array=[]
		for bone: int in range(actor.skeleton.get_bone_count()): names.append(actor.skeleton.get_bone_name(bone))
		var file:=FileAccess.open(output.path_join(id+".json"),FileAccess.WRITE)
		var profile: Dictionary = actor.profile.duplicate()
		profile["locomotion"] = str(Actor.CharacterArt.character_entry(id).get("locomotion","biped"))
		file.store_string(JSON.stringify({"id":id,"profile":profile,"bone_names":names,"geometries":geometries,"poses":poses}))
		file.close()
		print("DEFORMATION_EXPORTED ",id," ",poses.size())
		actor.free()
		await process_frame
	quit(0)
