extends Node3D
## Skinned player/portrait visual. Gameplay movement remains in player.gd.

const Art = preload("res://actors/character_art_v3.gd")
var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var elapsed := 0.0
var character_id := "player"

func configure(id: String = "player") -> void:
	character_id = id
	name = "StorybookVisual"
	scale = Vector3.ONE * 1.12
	skeleton = Art.create_skeleton(id)
	add_child(skeleton)
	meshes = Art.attach(id,skeleton)
	set_meta("art_revision",Art.revision())

func _ready() -> void:
	if skeleton:
		skeleton.force_update_all_bone_transforms()

func animate_player(walking: bool, delta: float, stride_time: float, gesture: String, gesture_time: float, reduced_motion: bool) -> void:
	if skeleton == null:
		return
	elapsed += delta
	var stride := sin(stride_time)*0.48 if walking else 0.0
	var pose := {"UpperLeg_L":Vector3(stride,0,0),"UpperLeg_R":Vector3(-stride,0,0),
		"LowerLeg_L":Vector3(maxf(0,-stride)*0.7,0,0),"LowerLeg_R":Vector3(maxf(0,stride)*0.7,0,0),
		"UpperArm_L":Vector3(-stride*0.6,0,0.09),"UpperArm_R":Vector3(stride*0.6,0,-0.09),
		"LowerArm_L":Vector3(-0.08,0,0),"LowerArm_R":Vector3(-0.08,0,0)}
	if gesture_time > 0.0:
		if gesture == "kick":
			pose.UpperLeg_R = Vector3(-0.8*sin(gesture_time*PI/0.8),0,0)
		else:
			pose.UpperArm_R = Vector3(-1.3 if gesture == "reach" else -2.2+sin(gesture_time*18)*0.18,0,-0.1)
			pose.LowerArm_R = Vector3(-0.22,0,0)
	for bone_name: String in pose:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			var target := skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion.from_euler(pose[bone_name])
			skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index).slerp(target,minf(delta*14,1)))
	skeleton.force_update_all_bone_transforms()
	Art.expression(meshes,elapsed,gesture if gesture_time>0.0 else "idle",reduced_motion)

func set_outfit(id: String) -> void:
	Art.set_outfit(self,id)

func get_status() -> Dictionary:
	return Art.statistics(self)
