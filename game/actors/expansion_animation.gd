extends RefCounted
## Authored species-specific clips; the same keyframes are exported in the GLB.
static var _clips: Dictionary = {}

static func library(path: String, reduced: bool) -> AnimationLibrary:
	if not _clips.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_clips[path] = parsed if parsed is Dictionary else {}
	var result := AnimationLibrary.new()
	var source: Dictionary = _clips[path].get("reduced" if reduced else "normal",{})
	for action: String in source:
		var spec: Dictionary = source[action]
		var clip := Animation.new()
		clip.resource_name = action
		clip.length = float(spec.length)
		clip.loop_mode = Animation.LOOP_LINEAR if bool(spec.loop) else Animation.LOOP_NONE
		for row: Dictionary in spec.tracks:
			var rotation := str(row.type) == "rotation"
			var track := clip.add_track(Animation.TYPE_ROTATION_3D if rotation else Animation.TYPE_POSITION_3D)
			clip.track_set_path(track,NodePath("VisualRoot/PrototypeSkeleton:"+str(row.bone)))
			clip.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
			for key: Dictionary in row.get("keys",[]):
				var v: Array = key.value
				if rotation:
					clip.rotation_track_insert_key(track,float(key.time),Quaternion(v[0],v[1],v[2],v[3]).normalized())
				else:
					clip.position_track_insert_key(track,float(key.time),Vector3(v[0],v[1],v[2]))
		result.add_animation(action,clip)
	return result
