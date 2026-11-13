extends RefCounted
## Runtime clip retargeted through the same rig adapter as the authored P1 actions.
const Source = preload("res://actors/p1_action_source.gd")

static func library(family: String) -> AnimationLibrary:
	var result := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length=2.0
	clip.loop_mode=Animation.LOOP_LINEAR
	var pose := {"UpperLeg_L":Vector3(-82,0,-3),"UpperLeg_R":Vector3(-82,0,3),"LowerLeg_L":Vector3(88,0,0),"LowerLeg_R":Vector3(88,0,0),"UpperArm_L":Vector3(-22,0,6),"UpperArm_R":Vector3(-22,0,-6),"LowerArm_L":Vector3(-35,0,0),"LowerArm_R":Vector3(-35,0,0)}
	for bone: String in Source.bones_for(family):
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath("VisualRoot/PrototypeSkeleton:"+bone))
		var angles: Vector3 = pose.get(bone,Vector3.ZERO)
		var rotation: Quaternion = Source.rest_rotation(family,bone)*Quaternion.from_euler(angles*PI/180.0)
		clip.rotation_track_insert_key(track,0,rotation)
		clip.rotation_track_insert_key(track,2,rotation)
	var hips := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(hips,NodePath("VisualRoot/PrototypeSkeleton:Hips"))
	clip.position_track_insert_key(hips,0,Vector3(0,Source.hips_height(family),0))
	clip.position_track_insert_key(hips,2,Vector3(0,Source.hips_height(family),0))
	result.add_animation("sit",clip)
	return result
