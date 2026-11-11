extends Node3D
## A remote presence never reads local input, owns a camera, or writes State.

const Visual = preload("res://actors/player_visual_v3.gd")
const Style = preload("res://ui/island_theme.gd")
var visual: Node3D
var nameplate: Label3D
var target := Vector3.ZERO
var target_angle := 0.0
var scene_id := ""
var outfit := ""
var initialized := false
var online := false
var walking := false
var stride := 0.0
var wave_time := 0.0
var reduced_motion := false

func setup(nickname: String) -> void:
	visual = Visual.new()
	visual.configure("player")
	add_child(visual)
	nameplate = Label3D.new()
	nameplate.name = "FriendName"
	nameplate.text = nickname
	nameplate.font = Style.body_font()
	nameplate.font_size = 64
	nameplate.outline_size = 12
	nameplate.pixel_size = 0.008
	nameplate.position.y = 3.0
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = Color("fffaf0")
	nameplate.outline_modulate = Color("395948")
	nameplate.no_depth_test = false
	add_child(nameplate)

func apply_member(member: Dictionary, current_scene: String) -> void:
	online = bool(member.get("online", false))
	var pose: Variant = member.get("pose")
	if not pose is Dictionary or not pose.get("p") is Array or pose.p.size() != 3:
		visible = false
		return
	var new_scene := str(pose.get("scene", ""))
	var point := Vector3(float(pose.p[0]), float(pose.p[1]), float(pose.p[2]))
	if not initialized or new_scene != scene_id or point.distance_to(position) > 12.0:
		position = point
		initialized = true
	scene_id = new_scene
	target = point
	target_angle = float(pose.get("r", 0.0))
	walking = bool(pose.get("moving", false))
	var next_outfit := str(member.get("outfit", "yellow"))
	if next_outfit != outfit:
		outfit = next_outfit
		visual.set_outfit(outfit)
	nameplate.text = str(member.get("nickname", "朋友"))
	visible = online and scene_id == current_scene

func wave() -> void:
	wave_time = 0.8

func _process(delta: float) -> void:
	if not initialized or not visible:
		return
	var previous := position
	position = position.lerp(target, 1.0 - exp(-delta * 14.0))
	visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, 1.0 - exp(-delta * 14.0))
	stride += position.distance_to(previous) * 2.3
	wave_time = maxf(0.0, wave_time - delta)
	visual.animate_player(walking, delta, stride, "wave", wave_time, reduced_motion)
