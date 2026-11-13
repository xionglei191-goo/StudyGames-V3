extends RefCounted
## Small cached sample of the actual skinned soles, including blended shin weights.
## Used by the player so start/stop blends receive the same grounding as full strides.
var samples: Array[Dictionary] = []

func configure(skeleton: Skeleton3D, meshes: Array[MeshInstance3D]) -> void:
	samples.clear()
	for mesh: MeshInstance3D in meshes:
		if mesh.skin == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var binds: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var influences: int = weights.size()/maxi(1,vertices.size())
			var cells := {}
			for vertex: int in range(vertices.size()):
				if vertices[vertex].y > 0.22: continue
				var cell := Vector2i(floori(vertices[vertex].x/0.035),floori(vertices[vertex].z/0.035))
				if not cells.has(cell) or vertices[vertex].y < vertices[int(cells[cell])].y: cells[cell] = vertex
			for vertex: int in cells.values():
				var sample := {"bones":[],"points":[],"weights":[]}
				for slot: int in range(influences):
					var at := vertex*influences+slot
					if weights[at] <= 0.00001: continue
					var bind := binds[at]
					var name := mesh.skin.get_bind_name(bind)
					var bone := skeleton.find_bone(name) if not str(name).is_empty() else mesh.skin.get_bind_bone(bind)
					if bone < 0: continue
					sample.bones.append(bone)
					sample.points.append(mesh.skin.get_bind_pose(bind)*vertices[vertex])
					sample.weights.append(weights[at])
				if not sample.bones.is_empty(): samples.append(sample)

func lowest(skeleton: Skeleton3D) -> float:
	var result := INF
	var poses := {}
	for sample: Dictionary in samples:
		var point := Vector3.ZERO
		for index: int in range(sample.bones.size()):
			var bone: int = sample.bones[index]
			if not poses.has(bone): poses[bone] = skeleton.get_bone_global_pose(bone)
			point += (poses[bone]*sample.points[index])*float(sample.weights[index])
		result = minf(result,point.y)
	return 0.0 if samples.is_empty() else result
