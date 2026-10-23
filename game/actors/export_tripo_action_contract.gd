extends SceneTree
## Export existing authored animation semantics for the offline Blender rig builder.
const Actions = preload("res://actors/p1_action_source.gd")

func _initialize() -> void:
	var families := {}
	for family: String in Actions.FAMILIES:
		var clips := {}
		var library := load(Actions.library_path(family,false)) as AnimationLibrary
		for id: StringName in library.get_animation_list():
			var clip := library.get_animation(id)
			var tracks := []
			for index: int in range(clip.get_track_count()):
				var kind := clip.track_get_type(index)
				if kind not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
					continue
				var keys := []
				for key: int in range(clip.track_get_key_count(index)):
					var value: Variant = clip.track_get_key_value(index,key)
					var components: Array = [value.x,value.y,value.z,value.w] if value is Quaternion else [value.x,value.y,value.z]
					keys.append({"time":clip.track_get_key_time(index,key),"value":components})
				tracks.append({"bone":str(clip.track_get_path(index)).get_slice(":",1),"type":"rotation" if kind == Animation.TYPE_ROTATION_3D else "position","keys":keys})
			clips[str(id)] = {"length":clip.length,"loop":clip.loop_mode != Animation.LOOP_NONE,"tracks":tracks,"semantic_spec":Actions.spec(str(id),family)}
		families[family] = {"source_hips_height":Actions.hips_height(family),"clips":clips}
	var path := ProjectSettings.globalize_path("res://../assets/characters/tripo_v1/action-contract.json")
	var output := FileAccess.open(path,FileAccess.WRITE)
	if output == null:
		push_error("Cannot write action contract")
		quit(1)
		return
	output.store_string(JSON.stringify({"schema_version":1,"source":"res://actors/p1/*.tres","families":families},"\t"))
	output.close()
	print("TRIPO_ACTION_CONTRACT families=4")
	quit(0)
