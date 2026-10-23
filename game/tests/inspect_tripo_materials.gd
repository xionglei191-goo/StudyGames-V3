extends "res://tests/test_tripo_characters.gd"
## Local diagnostic fixture; never writes production meshes or historical captures.

func _inspect_skin(owner: Node3D,id: String) -> Dictionary:
	for node: Node in owner.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			print("TRIPO_MATERIAL ",id,"/",node.name,"/",surface," ",source.resource_name," normal=",source.normal_enabled," cull=",source.cull_mode)
			var material := source.duplicate() as StandardMaterial3D
			material.normal_enabled = false
			if OS.get_cmdline_user_args().has("--debug-flat-color"):
				material.albedo_texture = null
				material.albedo_color = Color("cccccc")
				material.metallic_texture = null
				material.roughness_texture = null
				material.metallic = 0.0
				material.roughness = 0.8
			if OS.get_cmdline_user_args().has("--debug-double-sided"): material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface,material)
	return super._inspect_skin(owner,id)

func _capture(filename: String) -> void:
	await super._capture("diagnostic-no-normal/"+filename)

func _finish() -> void:
	output = output.path_join("diagnostic-no-normal")
	DirAccess.make_dir_recursive_absolute(output)
	await super._finish()
