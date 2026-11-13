extends Node3D
## Skinned player/portrait visual with V4 Modular Wardrobe sockets (Headwear, Backpacks,
## 3D CarrySocket) and expressive breathing / head LookAt / two-hand carry poses.

const Art = preload("res://actors/character_art_v3.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const WalkGait = preload("res://actors/walk_gait.gd")
const FootSupport = preload("res://actors/foot_support.gd")

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var elapsed := 0.0
var character_id := "player"

var _hat_attachment: BoneAttachment3D
var _bag_attachment: BoneAttachment3D
var _carry_attachment: BoneAttachment3D
var _hat_anchor: Node3D
var _bag_anchor: Node3D
var _carry_anchor: Node3D

var current_outfit := "yellow"
var current_hat := "none"
var current_bag := "none"
var carried_item := ""
var head_interest_yaw := 0.0
var head_interest_pitch := 0.0
var _walk_weight := 0.0
var _foot_support := FootSupport.new()
var _bone_indices: Dictionary = {}

func configure(id: String = "player") -> void:
	character_id = id
	name = "StorybookVisual"
	scale = Vector3.ONE * 1.12
	skeleton = Art.create_skeleton(id)
	add_child(skeleton)
	meshes = Art.attach(id, skeleton)
	for index: int in range(skeleton.get_bone_count()):
		_bone_indices[skeleton.get_bone_name(index)] = index
	_foot_support.configure(skeleton,meshes)
	set_meta("art_revision", Art.revision())
	if id == "player":
		_setup_accessory_sockets()

func _ready() -> void:
	if skeleton:
		skeleton.force_update_all_bone_transforms()

func _setup_accessory_sockets() -> void:
	if skeleton == null:
		return
	var combined_box := AABB()
	var has_box := false
	for m: MeshInstance3D in meshes:
		if m.mesh != null:
			var b := m.get_aabb()
			combined_box = b if not has_box else combined_box.merge(b)
			has_box = true
	if not has_box:
		combined_box = AABB(Vector3(-0.35, 0.0, -0.25), Vector3(0.70, 1.55, 0.50))

	var head_idx := skeleton.find_bone("Head")
	var spine_idx := skeleton.find_bone("Spine")

	if head_idx >= 0:
		_hat_attachment = BoneAttachment3D.new()
		_hat_attachment.name = "HeadAccessorySocket"
		_hat_attachment.bone_name = "Head"
		skeleton.add_child(_hat_attachment)
		var head_rest := skeleton.get_bone_global_rest(head_idx).origin
		var crown_offset_y := maxf(0.18, (combined_box.end.y - head_rest.y) * 0.86)
		_hat_anchor = Node3D.new()
		_hat_anchor.name = "HatAnchor"
		_hat_anchor.position = Vector3(0.0, crown_offset_y, 0.0)
		_hat_attachment.add_child(_hat_anchor)

	if spine_idx >= 0:
		_bag_attachment = BoneAttachment3D.new()
		_bag_attachment.name = "BackAccessorySocket"
		_bag_attachment.bone_name = "Spine"
		skeleton.add_child(_bag_attachment)
		var spine_rest := skeleton.get_bone_global_rest(spine_idx).origin
		var back_z := minf(-0.14, combined_box.position.z * 0.62 - spine_rest.z)
		_bag_anchor = Node3D.new()
		_bag_anchor.name = "BagAnchor"
		_bag_anchor.position = Vector3(0.0, 0.08, back_z)
		_bag_attachment.add_child(_bag_anchor)

		_carry_attachment = BoneAttachment3D.new()
		_carry_attachment.name = "CarrySocket"
		_carry_attachment.bone_name = "Spine"
		skeleton.add_child(_carry_attachment)
		var front_z := maxf(0.28, combined_box.end.z * 0.85 - spine_rest.z + 0.14)
		_carry_anchor = Node3D.new()
		_carry_anchor.name = "CarryAnchor"
		_carry_anchor.position = Vector3(0.0, 0.04, front_z)
		_carry_attachment.add_child(_carry_anchor)

func animate_player(walking: bool, delta: float, stride_time: float, gesture: String, gesture_time: float, reduced_motion: bool) -> void:
	if skeleton == null:
		return
	elapsed += delta
	var blend := 1.0-exp(-delta*16.0)
	_walk_weight = lerpf(_walk_weight,1.0 if walking else 0.0,blend)
	var gait := WalkGait.pose(stride_time/TAU,reduced_motion)
	var breath := 0.0 if reduced_motion else sin(elapsed * 2.3) * 0.028
	var carrying := not carried_item.is_empty()

	var pose := {
		"Spine": Vector3(breath,0,0).lerp(gait.Spine,_walk_weight),
		"Hips": (gait.Hips as Vector3)*_walk_weight,
		"Head": Vector3(
			clampf(head_interest_pitch + (-breath * 0.6), -0.22, 0.22),
			clampf(head_interest_yaw, -0.45, 0.45),
			0.0 if reduced_motion else sin(stride_time) * 0.012 * _walk_weight
		),
		"UpperArm_L": Vector3(-0.78,0.22,0.10) if carrying else Vector3(0,0,0.10).lerp(gait.UpperArm_L,_walk_weight),
		"UpperArm_R": Vector3(-0.78,-0.22,-0.10) if carrying else Vector3(0,0,-0.10).lerp(gait.UpperArm_R,_walk_weight),
		"LowerArm_L": Vector3(-0.48,0,0) if carrying else Vector3(-0.10,0,0).lerp(gait.LowerArm_L,_walk_weight),
		"LowerArm_R": Vector3(-0.48,0,0) if carrying else Vector3(-0.10,0,0).lerp(gait.LowerArm_R,_walk_weight)
	}
	for side: String in ["L","R"]:
		for bone: String in ["UpperLeg_","LowerLeg_","Foot_"]:
			pose[bone+side] = (gait[bone+side] as Vector3)*_walk_weight

	if gesture_time > 0.0:
		if gesture == "kick":
			var kick := sin(gesture_time * PI / 0.8)
			pose.UpperLeg_R = (pose.UpperLeg_R as Vector3).lerp(Vector3(-0.8,0,0),kick)
			pose.LowerLeg_R = (pose.LowerLeg_R as Vector3).lerp(Vector3(0.12,0,0),kick)
			pose.Foot_R = (pose.Foot_R as Vector3).lerp(Vector3(0.2,0,0),kick)
		else:
			pose.UpperArm_R = Vector3(-1.3 if gesture == "reach" else -2.2 + sin(gesture_time * 18.0) * 0.18, 0.0, -0.1)
			pose.LowerArm_R = Vector3(-0.22, 0.0, 0.0)

	for bone_name: String in pose:
		var index := int(_bone_indices.get(bone_name,-1))
		if index >= 0:
			var target := skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion.from_euler(pose[bone_name])
			# The gait is already C1 continuous. Filtering each joint again flattens
			# the brief knee fold and delays the foot relative to the support phase.
			var lower_body := bone_name.contains("Leg_") or bone_name.begins_with("Foot_") or bone_name == "Hips"
			skeleton.set_bone_pose_rotation(index,target if lower_body else skeleton.get_bone_pose_rotation(index).slerp(target,blend))
	var hips := int(_bone_indices.get("Hips",-1))
	if hips >= 0: skeleton.set_bone_pose_position(hips,skeleton.get_bone_rest(hips).origin)
	skeleton.force_update_all_bone_transforms()
	if hips >= 0:
		skeleton.set_bone_pose_position(hips,skeleton.get_bone_rest(hips).origin-Vector3.UP*_foot_support.lowest(skeleton))
		skeleton.force_update_all_bone_transforms()
	Art.expression(meshes, elapsed, gesture if gesture_time > 0.0 else "idle", reduced_motion)

	if is_instance_valid(_carry_anchor) and carrying and not reduced_motion:
		_carry_anchor.position.y = 0.04 + sin(elapsed * 3.2) * 0.015

func set_outfit(id: String) -> void:
	current_outfit = id
	Art.set_outfit(self, id)

func set_hat(hat_id: String) -> void:
	current_hat = hat_id
	if not is_instance_valid(_hat_anchor):
		return
	for child: Node in _hat_anchor.get_children():
		_hat_anchor.remove_child(child)
		child.queue_free()
	var node := Wardrobe.build_hat_mesh(hat_id)
	if node != null:
		_hat_anchor.add_child(node)

func set_bag(bag_id: String) -> void:
	current_bag = bag_id
	if not is_instance_valid(_bag_anchor):
		return
	for child: Node in _bag_anchor.get_children():
		_bag_anchor.remove_child(child)
		child.queue_free()
	var node := Wardrobe.build_bag_mesh(bag_id)
	if node != null:
		_bag_anchor.add_child(node)

func set_wardrobe(outfit_id: String, hat_id: String = "none", bag_id: String = "none") -> void:
	set_outfit(outfit_id)
	set_hat(hat_id)
	set_bag(bag_id)

func set_carried_item(prop_id: String) -> void:
	carried_item = prop_id
	if not is_instance_valid(_carry_anchor):
		return
	for child: Node in _carry_anchor.get_children():
		_carry_anchor.remove_child(child)
		child.queue_free()
	var prop := Wardrobe.build_carried_prop(prop_id)
	if prop != null:
		_carry_anchor.add_child(prop)

func set_head_interest(yaw: float, pitch: float = 0.0) -> void:
	head_interest_yaw = yaw
	head_interest_pitch = pitch

func get_status() -> Dictionary:
	var stats := Art.statistics(self)
	stats["outfit"] = current_outfit
	stats["hat"] = current_hat
	stats["bag"] = current_bag
	stats["carried_item"] = carried_item
	return stats
