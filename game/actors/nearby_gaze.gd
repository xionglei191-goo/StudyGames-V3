extends SkeletonModifier3D
## A nearby visitor attracts a small head turn over the authored idle pose.
## Skeleton3D restores its base pose after skinning, so the turn never accumulates.
var observer: Node3D
var head := -1
var neck := -1
var angles := Vector2.ZERO

func _process_modification_with_delta(delta: float) -> void:
	var rig := get_skeleton()
	if not is_instance_valid(observer) or head < 0 or rig == null:
		return
	var pivot := rig.get_bone_global_pose(head).origin
	var offset := rig.to_local(observer.global_position + Vector3.UP * 1.65) - pivot
	var horizontal := Vector2(offset.x,offset.z).length()
	var yaw := atan2(offset.x,offset.z)
	var weight := (1.0 - smoothstep(2.6,4.5,horizontal)) * (1.0 - smoothstep(0.98,1.63,absf(yaw)))
	var pitch := -atan2(offset.y,maxf(horizontal,0.12))
	var desired := Vector2(clampf(yaw,-0.49,0.49),clampf(pitch,-0.32,0.18)) * weight
	angles = angles.lerp(desired,1.0-exp(-minf(delta,0.1)*5.0))
	var turn := Quaternion(Vector3.UP,angles.x) * Quaternion(Vector3.RIGHT,angles.y)
	if neck >= 0:
		_turn_bone(rig,neck,Quaternion.IDENTITY.slerp(turn,0.34))
		_turn_bone(rig,head,Quaternion.IDENTITY.slerp(turn,0.66))
	else:
		_turn_bone(rig,head,turn)

func _turn_bone(rig: Skeleton3D, bone: int, turn: Quaternion) -> void:
	var parent := rig.get_bone_parent(bone)
	var basis := rig.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	rig.set_bone_pose_rotation(bone,(basis.inverse()*turn*basis*rig.get_bone_pose_rotation(bone)).normalized())
