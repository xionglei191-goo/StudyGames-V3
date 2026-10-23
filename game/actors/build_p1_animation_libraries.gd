extends SceneTree

const Source = preload("res://actors/p1_action_source.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Source.DIRECTORY))
	var manifest := {"schema_version":1,"status":"saved_keyframed_rigid_bone_prototypes_not_skinned","source":"res://actors/p1_action_source.gd","families":{},"semantic_data_mutation":false}
	var failures := 0
	for family: String in Source.FAMILIES:
		var family_row := {"libraries":{},"actions":{}}
		for reduced: bool in [false,true]:
			var path := Source.library_path(family,reduced)
			var library: AnimationLibrary = Source.build_library(family,reduced)
			var result := ResourceSaver.save(library,path)
			if result != OK:
				failures += 1
			family_row.libraries["reduced" if reduced else "normal"] = {"path":path,"save_error":result,"animation_count":library.get_animation_list().size()}
		for action: String in Source.SPECS:
			family_row.actions[action] = Source.spec(action,family)
		manifest.families[family] = family_row
	var file := FileAccess.open(Source.DIRECTORY.path_join("action_manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("P1_ANIMATION_LIBRARIES " + JSON.stringify({"families":4,"libraries":8,"failures":failures}))
	quit(0 if failures == 0 else 1)
