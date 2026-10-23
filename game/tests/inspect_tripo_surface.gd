extends "res://tests/test_tripo_characters.gd"
## Locate a visible defect on the actual deformed mesh without changing assets.

func _capture(filename: String) -> void:
	if filename not in ["textbook_jim-wave.png","textbook_jim-give.png"]: return
	var pixels := [Vector2(718,566),Vector2(721,570)] if filename.contains("wave") else [Vector2(787,426),Vector2(787,408)]
	for pixel: Vector2 in pixels:
		var origin := camera.project_ray_origin(pixel)
		var direction := camera.project_ray_normal(pixel)
		var hits: Array[Dictionary] = []
		for node: Node in stage.find_children("*","MeshInstance3D",true,false):
			var mesh := node as MeshInstance3D
			if mesh.skin == null: continue
			var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
			var transforms: Array[Transform3D] = []
			for bind: int in range(mesh.skin.get_bind_count()):
				transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(_bind_bone(mesh.skin,skeleton,bind))*mesh.skin.get_bind_pose(bind))
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var count: int = weights.size()/vertices.size()
				var posed := PackedVector3Array()
				posed.resize(vertices.size())
				for vertex: int in range(vertices.size()):
					for slot: int in range(count):
						var at := vertex*count+slot
						if weights[at]>0.0: posed[vertex]+=(transforms[bones[at]]*vertices[vertex])*weights[at]
				for face: int in range(0,indices.size(),3):
					var a := indices[face]
					var b := indices[face+1]
					var c := indices[face+2]
					var hit: Variant = Geometry3D.ray_intersects_triangle(origin,direction,posed[a],posed[b],posed[c])
					if hit == null: continue
					var material := mesh.get_active_material(surface) as StandardMaterial3D
					var binds := []
					for v: int in [a,b,c]:
						var bindings := {}
						for slot: int in range(count):
							var at := v*count+slot
							if weights[at]>0.001: bindings[skeleton.get_bone_name(_bind_bone(mesh.skin,skeleton,bones[at]))]=weights[at]
						binds.append(bindings)
					hits.append({"distance":origin.distance_to(hit),"mesh":mesh.name,"surface":surface,"triangle":face/3,"source_vertices":[str(vertices[a]/2.05),str(vertices[b]/2.05),str(vertices[c]/2.05)],"posed_vertices":[str(posed[a]),str(posed[b]),str(posed[c])],"material":material.resource_name,"textured":material.albedo_texture!=null,"weights":binds})
		hits.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance<b.distance)
		print("SURFACE_PROBE ",filename," ",pixel," ",JSON.stringify(hits.slice(0,3)))

func _finish() -> void:
	output=output.path_join("surface-probe")
	DirAccess.make_dir_recursive_absolute(output)
	await super._finish()
