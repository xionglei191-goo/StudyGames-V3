extends RefCounted
## One continuous gait for the player and the fitted NPC animation libraries.
## Each row is thigh, knee, and WORLD foot pitch in degrees, at 10% intervals.
## Contact -> loading -> support -> toe-off -> bent-knee swing -> heel contact.
const LEG_KEYS := [
	Vector3(-24,8,-7), Vector3(-18,18,0), Vector3(-8,12,0),
	Vector3(5,6,0), Vector3(17,8,8), Vector3(22,16,22),
	Vector3(10,42,30), Vector3(-12,62,12), Vector3(-26,42,-2),
	Vector3(-28,18,-7)
]
const REVISION := "walk-gait-20261112"

static func _tangent(before: float, after: float) -> float:
	# Monotone Hermite tangents keep the knee from overshooting through straight.
	return 0.0 if before * after <= 0.0 else 2.0 * before * after / (before + after)

static func leg(phase: float) -> Vector3:
	var at := fposmod(phase,1.0) * LEG_KEYS.size()
	var index := floori(at)
	var t := at - index
	var a: Vector3 = LEG_KEYS[posmod(index-1,LEG_KEYS.size())]
	var b: Vector3 = LEG_KEYS[index]
	var c: Vector3 = LEG_KEYS[(index+1)%LEG_KEYS.size()]
	var d: Vector3 = LEG_KEYS[(index+2)%LEG_KEYS.size()]
	var result := Vector3.ZERO
	for axis: int in range(3):
		var m0 := _tangent(b[axis]-a[axis],c[axis]-b[axis])
		var m1 := _tangent(c[axis]-b[axis],d[axis]-c[axis])
		result[axis] = (2*t*t*t-3*t*t+1)*b[axis] + (t*t*t-2*t*t+t)*m0 + (-2*t*t*t+3*t*t)*c[axis] + (t*t*t-t*t)*m1
	return result * PI / 180.0

static func pose(phase: float, reduced: bool = false) -> Dictionary:
	var result := {}
	for side: String in ["L","R"]:
		var angles := leg(phase + (0.5 if side == "R" else 0.0))
		result["UpperLeg_"+side] = Vector3(angles.x,0,0)
		result["LowerLeg_"+side] = Vector3(angles.y,0,0)
		# Cancel the accumulated thigh/shin pitch before adding the foot roll.
		result["Foot_"+side] = Vector3(angles.z-angles.x-angles.y,0,0)
	var swing := cos(phase * TAU) * 0.34
	result["UpperArm_L"] = Vector3(swing,0,0.10)
	result["UpperArm_R"] = Vector3(-swing,0,-0.10)
	result["LowerArm_L"] = Vector3(-0.18-maxf(0,-swing)*0.22,0,0)
	result["LowerArm_R"] = Vector3(-0.18-maxf(0,swing)*0.22,0,0)
	result["Hips"] = Vector3.ZERO if reduced else Vector3(0,cos(phase*TAU)*0.025,sin(phase*TAU)*0.012)
	result["Spine"] = Vector3.ZERO if reduced else Vector3(0.035,-cos(phase*TAU)*0.018,-sin(phase*TAU)*0.009)
	return result

static func adapt_clip(clip: Animation, walking: bool, carrying: bool, reduced: bool, hips_rest: Vector3) -> void:
	var prefix := "VisualRoot/PrototypeSkeleton:"
	var tracks := {}
	var bones: Array[String] = ["Foot_L","Foot_R"]
	if walking:
		bones.append_array(["UpperLeg_L","LowerLeg_L","UpperLeg_R","LowerLeg_R","Hips","Spine"])
		if not carrying: bones.append_array(["UpperArm_L","UpperArm_R","LowerArm_L","LowerArm_R"])
	for bone: String in bones:
		var path := NodePath(prefix+bone)
		var track := clip.find_track(path,Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track,path)
		for key: int in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
		tracks[bone] = track
		clip.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
	var count := ceili(clip.length*60.0) if walking else 1
	for frame: int in range(count+1):
		var phase := float(frame)/count
		var values := pose(phase,reduced) if walking else {}
		for bone: String in tracks:
			clip.rotation_track_insert_key(tracks[bone],phase*clip.length,Quaternion.from_euler(values.get(bone,Vector3.ZERO)))
	if walking:
		# Sole fitting owns pelvis height; remove the old unrelated bob curve.
		var hips_track := clip.find_track(NodePath(prefix+"Hips"),Animation.TYPE_POSITION_3D)
		if hips_track >= 0:
			for key: int in range(clip.track_get_key_count(hips_track)-1,-1,-1): clip.track_remove_key(hips_track,key)
			clip.position_track_insert_key(hips_track,0.0,hips_rest)
			clip.position_track_insert_key(hips_track,clip.length,hips_rest)
