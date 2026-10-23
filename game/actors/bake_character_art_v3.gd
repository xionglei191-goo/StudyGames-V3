extends SceneTree
## Offline authoring conversion: Blender's source vertex data -> compact native meshes.

const SOURCE := "../assets/characters/storybook_v3/source"
const OUTPUT := "res://assets/characters/storybook_v3"

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--bake-character-art"):
		quit(2)
		return
	_run.call_deferred()

func _v3(values: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i: int in range(0,values.size(),3):
		result.append(Vector3(float(values[i]),float(values[i+1]),float(values[i+2])))
	return result

func _run() -> void:
	var manifest := {"schema_version":3,"art_revision":"storybook-character-v3","characters":{}}
	var source_directory := ProjectSettings.globalize_path("res://").path_join(SOURCE).simplify_path()
	var directory := DirAccess.open(source_directory)
	if directory == null:
		push_error("Character source folder is missing")
		quit(1)
		return
	var filenames := directory.get_files()
	filenames.sort()
	for filename: String in filenames:
		if not filename.ends_with(".json"):
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_directory.path_join(filename)))
		var id := str(data.id)
		DirAccess.make_dir_recursive_absolute(OUTPUT.path_join(id))
		var record := {"groups":[],"bones":data.bones,"profile":data.profile}
		for group: Dictionary in data.groups:
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = _v3(group.vertices)
			arrays[Mesh.ARRAY_NORMAL] = _v3(group.normals)
			var colors := PackedColorArray()
			for i: int in range(0,group.colors.size(),4):
				colors.append(Color(float(group.colors[i]),float(group.colors[i+1]),float(group.colors[i+2]),float(group.colors[i+3])))
			arrays[Mesh.ARRAY_COLOR] = colors
			var uvs := PackedVector2Array()
			for i: int in range(0,group.uv.size(),2):
				uvs.append(Vector2(float(group.uv[i]),float(group.uv[i+1])))
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_BONES] = PackedInt32Array(group.bones)
			arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array(group.weights)
			var mesh := ArrayMesh.new()
			mesh.resource_name = id + "_" + str(group.name)
			var shapes: Array[Array] = []
			var morphs: Dictionary = group.get("morphs",{})
			for shape_name: String in morphs:
				mesh.add_blend_shape(shape_name)
				mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
				var shape := []
				shape.resize(Mesh.ARRAY_MAX)
				shape[Mesh.ARRAY_VERTEX] = _v3(morphs[shape_name])
				shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
				shapes.append(shape)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
			var material := StandardMaterial3D.new()
			material.resource_name = id + "_" + str(group.name)
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = true
			material.albedo_color = Color(str(group.tint))
			material.roughness = float(group.roughness)
			mesh.surface_set_material(0,material)
			var path := OUTPUT.path_join(id).path_join(str(group.name)+".res")
			if ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS) != OK:
				push_error("Failed saving " + path)
				quit(1)
				return
			record.groups.append({"name":group.name,"path":path,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"blend_shapes":morphs.keys(),"blink":morphs.has("Blink")})
		manifest.characters[id] = record
		print("BAKED_CHARACTER ",id," ",record.groups.size()," meshes")
	var output := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t"))
	output.close()
	quit(0)
