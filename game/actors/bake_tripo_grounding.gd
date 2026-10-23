extends SceneTree
## Bake sole-based pelvis corrections once; runtime clips only read keyframes.
const Art = preload("res://actors/character_art_v3.gd")
const Actor = preload("res://scripts/textbook_actor.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Art.use_manifest("res://assets/characters/tripo_v1/manifest.json")
	Art._skip_grounding=true
	var result := {"schema_version":1,"method":"60 Hz fitted sole support, 18 mm rest-space sample cells; root position and action timing retained","characters":{}}
	for id: String in Art.manifest().characters:
		if id=="player" or str(Art.character_entry(id).family)=="wheelchair": continue
		var actor: Node3D = Actor.new()
		actor.configure(id)
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		var points := _sole_points(actor)
		if points.is_empty():
			printerr("No sole geometry: "+id)
			quit(1)
			return
		var modes := {}
		for mode: String in ["normal","reduced"]:
			var clips := {}
			for name: String in ["walk","carry_walk"]:
				var path := mode+"/"+name
				var clip: Animation = actor.animation_player.get_animation(path)
				actor.animation_player.play(path,0.0)
				actor.animation_player.advance(0.0)
				var count := ceili(clip.length*60.0)
				var frames := []
				for frame: int in range(count+1):
					var time := clip.length*float(frame)/float(count)
					actor.animation_player.seek(time,true,true)
					actor.skeleton.force_update_all_bone_transforms()
					frames.append({"time":time,"offset":-_lowest(actor,points)})
				clips[name]=frames
			modes[mode]=clips
		result.characters[id]=modes
		print("TRIPO_GROUNDING ",id," samples=",points.size())
		actor.queue_free()
		await process_frame
	var file := FileAccess.open(Art.GROUNDING_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("TRIPO_GROUNDING_DONE ",result.characters.size())
	quit(0)

func _sole_points(actor: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in actor.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.skin==null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var influences: int = weights.size()/vertices.size()
			var cells := {}
			for vertex: int in range(vertices.size()):
				if vertices[vertex].y>0.22: continue
				var cell := Vector2i(floori(vertices[vertex].x/0.018),floori(vertices[vertex].z/0.018))
				if not cells.has(cell) or vertices[vertex].y<vertices[int(cells[cell])].y: cells[cell]=vertex
			for vertex: int in cells.values():
				var sample := {"vertex":vertices[vertex],"bones":[],"binds":[],"weights":[]}
				for slot: int in range(influences):
					var at := vertex*influences+slot
					if weights[at]<=0.00001: continue
					var bind := indices[at]
					var name := mesh.skin.get_bind_name(bind)
					sample.bones.append(actor.skeleton.find_bone(name) if not str(name).is_empty() else mesh.skin.get_bind_bone(bind))
					sample.binds.append(mesh.skin.get_bind_pose(bind))
					sample.weights.append(weights[at])
				result.append(sample)
	return result

func _lowest(actor: Node3D,points: Array[Dictionary]) -> float:
	var poses := {}
	var lowest := INF
	for sample: Dictionary in points:
		var vertex := Vector3.ZERO
		for index: int in range(sample.bones.size()):
			var bone: int = sample.bones[index]
			if not poses.has(bone): poses[bone]=actor.skeleton.get_bone_global_pose(bone)
			vertex+=(poses[bone]*sample.binds[index]*sample.vertex)*float(sample.weights[index])
		lowest=minf(lowest,vertex.y)
	return lowest
