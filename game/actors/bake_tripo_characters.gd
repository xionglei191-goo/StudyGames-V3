extends SceneTree
## Convert Blender's real GLB skins to the established native character loader.
## The semantic bone order and canonical rest transforms come from rig.json.
const OUTPUT := "res://assets/characters/tripo_v1"
const SOURCE := "res://../assets/characters/tripo_v1"
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	failures += 1
	push_error(message)

func _run() -> void:
	var manifest := {"schema_version":4,"art_revision":"tripo-character-v1","characters":{}}
	if FileAccess.file_exists(OUTPUT.path_join("manifest.json")):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT.path_join("manifest.json")))
	var folder := ProjectSettings.globalize_path(SOURCE).simplify_path()
	var ids := DirAccess.open(folder).get_directories()
	ids.sort()
	var selected := OS.get_cmdline_user_args()
	for id: String in ids:
		if not selected.is_empty() and not selected.has(id) and not selected.has("--all"):
			continue
		var source_file := folder.path_join(id).path_join("rig.json")
		if not FileAccess.file_exists(source_file):
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_file))
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		var error := document.append_from_file(folder.path_join(id).path_join("character.glb"),state)
		if error != OK:
			_fail("GLB import failed: " + id)
			continue
		var scene := document.generate_scene(state)
		if scene == null:
			_fail("GLB scene missing: " + id)
			continue
		root.add_child(scene)
		var record := {"groups":[],"bones":data.bones,"profile":{"kind":data.family},"hand_sockets":data.hand_sockets,
			"source":data.source,"source_sha256":data.source_sha256,"revision":"tripo-character-v1",
			"family":data.family,"height":data.height,"source_triangles":data.source_triangles,
			"actions":data.actions,"weight_method":data.weight_method,"editable_source":data.editable_source}
		if data.has("rigging_provider"): record["rigging_provider"]=data.rigging_provider
		var order := {}
		for i: int in range(data.bones.size()):
			order[str(data.bones[i].name)] = i
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(id)))
		for node: Node in scene.find_children("*","MeshInstance3D",true,false):
			var source_mesh := node as MeshInstance3D
			var source_skeleton := source_mesh.get_node_or_null(source_mesh.skeleton) as Skeleton3D
			if source_mesh.skin == null or source_skeleton == null:
				_fail("Missing real skin: " + id + "/" + str(node.name))
				continue
			var remap := {}
			for bind: int in range(source_mesh.skin.get_bind_count()):
				var name := str(source_mesh.skin.get_bind_name(bind))
				if name.is_empty():
					name = source_skeleton.get_bone_name(source_mesh.skin.get_bind_bone(bind))
				if not order.has(name):
					_fail("Unmapped GLB bone: " + id + "/" + name)
					continue
				remap[bind] = int(order[name])
			var mesh := ArrayMesh.new()
			mesh.resource_name = id + "_" + str(node.name)
			mesh.blend_shape_mode = source_mesh.mesh.blend_shape_mode
			for shape: int in range(source_mesh.mesh.get_blend_shape_count()):
				mesh.add_blend_shape(source_mesh.mesh.get_blend_shape_name(shape))
			var mesh_transform := source_mesh.global_transform
			var total_vertices := 0
			var weighted := 0
			var triangle_count := 0
			for surface: int in range(source_mesh.mesh.get_surface_count()):
				var arrays := source_mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var bone_indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var skin_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var normal_matrix := mesh_transform.basis.inverse().transposed()
				for i: int in range(vertices.size()):
					vertices[i] = mesh_transform * vertices[i]
					if i < normals.size(): normals[i] = (normal_matrix * normals[i]).normalized()
				for i: int in range(bone_indices.size()):
					bone_indices[i] = int(remap.get(bone_indices[i],0))
				var influences: int = skin_weights.size() / maxi(vertices.size(),1)
				for vertex: int in range(vertices.size()):
					var weight_sum := 0.0
					for influence: int in range(influences): weight_sum += skin_weights[vertex*influences+influence]
					if absf(weight_sum-1.0) < 0.001: weighted += 1
					else: _fail("Invalid vertex weight sum: " + id)
				arrays[Mesh.ARRAY_VERTEX] = vertices
				arrays[Mesh.ARRAY_NORMAL] = normals
				arrays[Mesh.ARRAY_BONES] = bone_indices
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for i: int in range(0,tangents.size(),4):
					var tangent := (mesh_transform.basis * Vector3(tangents[i],tangents[i+1],tangents[i+2])).normalized()
					tangents[i]=tangent.x; tangents[i+1]=tangent.y; tangents[i+2]=tangent.z
				arrays[Mesh.ARRAY_TANGENT] = tangents
				var morphs := source_mesh.mesh.surface_get_blend_shape_arrays(surface)
				for shape: Array in morphs:
					var points: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
					var shape_normals: PackedVector3Array = shape[Mesh.ARRAY_NORMAL]
					for i: int in range(points.size()):
						points[i] = mesh_transform * points[i] if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else mesh_transform.basis * points[i]
						if i < shape_normals.size():
							var transformed_normal := normal_matrix * shape_normals[i]
							shape_normals[i] = transformed_normal.normalized() if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else transformed_normal
					shape[Mesh.ARRAY_VERTEX] = points
					shape[Mesh.ARRAY_NORMAL] = shape_normals
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,morphs)
				var material := source_mesh.mesh.surface_get_material(surface)
				if id == "player": material = _player_material(material as StandardMaterial3D)
				mesh.surface_set_material(surface,material)
				total_vertices += vertices.size()
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangle_count += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var target := OUTPUT.path_join(id).path_join(str(node.name)+".res")
			if ResourceSaver.save(mesh,target,ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
				_fail("Cannot save native mesh: " + target)
			var shapes := []
			for i: int in range(mesh.get_blend_shape_count()): shapes.append(str(mesh.get_blend_shape_name(i)))
			record.groups.append({"name":str(node.name),"path":target,"vertices":total_vertices,"weighted_vertices":weighted,"triangles":triangle_count,"blend_shapes":shapes,"blend_shape_mode":mesh.blend_shape_mode})
		manifest.characters[id] = record
		scene.free()
		print("TRIPO_BAKED " + id + " " + JSON.stringify(record.groups))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("TRIPO_BAKE_RESULT " + JSON.stringify({"characters":manifest.characters.size(),"failures":failures}))
	quit(1 if failures else 0)

func _player_material(source: StandardMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	# Embed the shader source with the bundled mesh. A loaded external Shader
	# can retain an invalid external-resource index when bundled into binary RES.
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/tripo_outfit.gdshader")
	material.shader = shader
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("normal_texture",source.normal_texture)
	material.set_shader_parameter("has_normal",source.normal_texture != null)
	material.set_shader_parameter("orm_texture",source.roughness_texture)
	material.set_shader_parameter("has_orm",source.roughness_texture != null)
	return material
