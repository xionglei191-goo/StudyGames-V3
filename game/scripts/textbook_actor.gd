extends CharacterBody3D
## Source-guided storybook meshes with smooth skin weights on the saved P1 rig.
## BoneAttachment3D is reserved for semantic hand sockets, not body geometry.

signal semantic_event(character_id: String, action_id: String, event_key: String)
signal action_finished(character_id: String, action_id: String)
signal action_started(character_id: String, action_id: String, invocation_id: int)
signal action_contact(character_id: String, action_id: String, event_key: String, invocation_id: int, socket_world: Transform3D)
signal action_phase_changed(character_id: String, action_id: String, phase: String, invocation_id: int)

const P1Actions = preload("res://actors/p1_action_source.gd")
const CharacterArt = preload("res://actors/character_art_v3.gd")
const WorldArt = preload("res://scripts/world_art.gd")

const PROFILES := {
	"npc_bear_uncle": {"name":"熊叔", "kind":"bear", "outfit":"78a8b6", "trim":"eee0bc", "source":"existing_island/world_builder.make_character(bear)"},
	"npc_rabbit_gardener": {"name":"兔兔", "kind":"rabbit", "outfit":"86a57a", "trim":"ebdbb2", "source":"existing_island/world_builder.make_character(rabbit)"},
	"textbook_lingling": {"name":"Lingling", "hair":"242729", "outfit":"dc8ea5", "trim":"f5dbe0", "style":"pigtails", "dress":true, "source":"xiangshao-g3-1/file-page-7"},
	"textbook_peter": {"name":"Peter", "hair":"dfb758", "outfit":"f1e8cf", "trim":"dca04c", "style":"curls", "shorts":"dca04c", "source":"xiangshao-g3-1/file-page-7"},
	"textbook_anne": {"name":"Anne", "hair":"bd6943", "outfit":"8fbbcb", "trim":"a39eb7", "style":"ponytail", "dress":true, "source":"xiangshao-g3-1/file-page-7"},
	"textbook_mingming": {"name":"Mingming", "hair":"2e3032", "outfit":"7198b5", "trim":"d8e1dc", "style":"short", "shorts":"587f9f", "source":"xiangshao-g3-1/file-page-7"},
	"textbook_dongdong": {"name":"Dongdong", "hair":"2b2e30", "outfit":"e2bd56", "trim":"f4e6c8", "style":"short", "shorts":"c57668", "striped":true, "width":1.08, "source":"xiangshao-g3-1/file-page-7"},
	"textbook_tim": {"name":"Tim", "hair":"a86a47", "outfit":"f0e8d4", "trim":"6ca4a0", "style":"curls", "shorts":"6ca4a0", "source":"xiangshao-g3-1/file-page-7"},
	"textbook_dino": {"name":"Dino", "kind":"dino", "outfit":"7da868", "trim":"e4d8a8", "source":"xiangshao-g3-1/file-page-7"},
	"textbook_miss_li": {"name":"Miss Li", "hair":"292a2e", "outfit":"d49cae", "trim":"ead3d8", "style":"bob", "dress":true, "height":1.12, "source":"xiangshao-g3-1/file-page-13"},
	"textbook_jim": {"name":"Jim", "hair":"8b6247", "outfit":"dadbd1", "trim":"7d99a1", "style":"short", "kind":"wheelchair", "source":"xiangshao-g6-1/file-page-74", "clothing_status":"neutral_prototype_pending_source_colour_review"},
}

var character_id := ""
var display_name := ""
var visual: Node3D
var skeleton: Skeleton3D
var interaction_anchor: Marker3D
var name_label: Label3D
var hand_socket: Node3D
var left_hand_socket: Node3D
var animation_player: AnimationPlayer
var profile: Dictionary = {}
var reduced_motion := false
var world_running := true
var performance_running := true
var is_performance_actor := false
var movement_speed := 1.6
var motion_path := PackedVector3Array()
var current_action := "idle"
var _action_elapsed := 0.0
var _action_duration := 0.0
var _action_event_key := ""
var _action_contact_sent := false
var _visual_time := 0.0
var _walk_time := 0.0
var _actual_speed := 0.0
var _stuck_time := 0.0
var _desired_yaw := 0.0
var _bones: Dictionary = {}
var _rest_rotations: Dictionary = {}
var _materials: Dictionary = {}
var _held_prop: Node3D
var _configured := false
var _rig_family := "humanoid"
var _art_meshes: Array[MeshInstance3D] = []
var _art_stats: Dictionary = {}
var _active_clip := ""
var _active_reduced := false
var _invocation_id := 0
var _requested_action := "idle"
var _action_complete := false
var _phase_name := "idle"
var _semantic_receipts: Dictionary = {}
var _held_prop_id := ""
var _contact_prediction_cache: Dictionary = {}
var _carrying_pose := false
var _explicit_loop := ""
var _contact_marker_pending := false
var _attachments: Array[BoneAttachment3D] = []

static func canonical_id(value: String) -> String:
	var result := value.strip_edges().to_lower()
	if result in ["bear", "bear_uncle", "npc_bear_uncle"]:
		return "npc_bear_uncle"
	if result in ["rabbit", "rabbit_gardener", "npc_rabbit_gardener"]:
		return "npc_rabbit_gardener"
	if result.begins_with("npc_"):
		result = result.substr(4)
	if not result.begins_with("textbook_"):
		result = "textbook_" + result
	return result

static func supports(value: String) -> bool:
	return PROFILES.has(canonical_id(value))

func configure(value: String, options: Dictionary = {}) -> bool:
	character_id = canonical_id(value)
	if not PROFILES.has(character_id):
		return false
	profile = (PROFILES[character_id] as Dictionary).duplicate(true)
	_rig_family = P1Actions.family_for(str(profile.get("kind","human")))
	display_name = str(profile.name)
	name = "Actor_" + character_id
	set_meta("character_id", character_id)
	set_meta("asset_character_id", character_id if character_id.begins_with("npc_") else "npc_" + character_id)
	set_meta("visual_production_status", CharacterArt.revision())
	set_meta("source_reference", str(profile.get("source", "")))
	reduced_motion = bool(options.get("reduced_motion", false))
	movement_speed = clampf(float(options.get("movement_speed", 1.6)), 0.2, 3.0)
	collision_layer = 16  # Interaction bodies never add a blocker to the player's mask 5.
	collision_mask = 5
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var collider := CollisionShape3D.new()
	collider.name = "ActorCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52 if _is_wheelchair() else 0.30
	capsule.height = 1.65
	collider.shape = capsule
	collider.position.y = 0.84
	add_child(collider)
	visual = Node3D.new()
	visual.name = "VisualRoot"
	visual.scale = Vector3(float(profile.get("width", 1.0)), float(profile.get("height", 1.0)), 1.0)
	add_child(visual)
	skeleton = Skeleton3D.new()
	skeleton.name = "PrototypeSkeleton"
	visual.add_child(skeleton)
	_build_rig()
	_art_meshes = CharacterArt.attach(character_id,skeleton)
	if _art_meshes.is_empty():
		return false
	_art_stats = CharacterArt.statistics(visual)
	_build_hand_sockets()
	interaction_anchor = Marker3D.new()
	interaction_anchor.name = "InteractionAnchor"
	interaction_anchor.position.y = 0.85
	add_child(interaction_anchor)
	name_label = Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.font = load("res://assets/fonts/IslandSans.otf") as Font
	name_label.font_size = 26
	name_label.pixel_size = 0.009
	name_label.position.y = 2.85 if str(profile.get("kind","")) == "rabbit" else 2.65 if not _is_wheelchair() else 2.45
	name_label.modulate = Color("fff5df")
	name_label.outline_modulate = Color("4d554f")
	name_label.outline_size = 6
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(name_label)
	_build_animation_player()
	_configured = true
	return true

func _ready() -> void:
	if skeleton:
		skeleton.force_update_all_bone_transforms()
	if animation_player:
		_start_clip("idle",true)

func _build_rig() -> void:
	var entry := CharacterArt.character_entry(character_id)
	if not entry.get("bones",[]).is_empty():
		for bone: Dictionary in entry.bones:
			var origin: Array = bone.origin
			var rotation: Array = bone.rotation
			_add_bone(str(bone.name),"" if bone.parent==null else str(bone.parent),
				Vector3(float(origin[0]),float(origin[1]),float(origin[2])),
				Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2])))
		return
	_add_bone("Hips", "", Vector3(0, P1Actions.hips_height(_rig_family), 0))
	_add_bone("Spine", "Hips", Vector3(0, 0.20, 0))
	_add_bone("Head", "Spine", Vector3(0, 0.56, 0))
	for side: String in ["L", "R"]:
		var sign_x := -1.0 if side == "L" else 1.0
		_add_bone("UpperArm_" + side, "Spine", Vector3(sign_x * 0.39, 0.22, 0))
		_add_bone("LowerArm_" + side, "UpperArm_" + side, Vector3(0, -0.34, 0))
		_add_bone("UpperLeg_" + side, "Hips", Vector3(sign_x * 0.18, -0.03, 0), Vector3(-PI * 0.5, 0, 0) if _is_wheelchair() else Vector3.ZERO)
		_add_bone("LowerLeg_" + side, "UpperLeg_" + side, Vector3(0, -0.38, 0), Vector3(PI * 0.5, 0, 0) if _is_wheelchair() else Vector3.ZERO)
	if str(profile.get("kind", "")) == "dino":
		_add_bone("Tail", "Hips", Vector3(0, 0.04, -0.22))
		_add_bone("Wing_L", "Spine", Vector3(-0.25, 0.20, -0.17))
		_add_bone("Wing_R", "Spine", Vector3(0.25, 0.20, -0.17))

func _add_bone(bone_name: String, parent_name: String, origin: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var index := skeleton.add_bone(bone_name)
	_bones[bone_name] = index
	if not parent_name.is_empty():
		skeleton.set_bone_parent(index, int(_bones[parent_name]))
	var basis := Basis.from_euler(rotation)
	skeleton.set_bone_rest(index, Transform3D(basis, origin))
	skeleton.reset_bone_pose(index)
	_rest_rotations[bone_name] = basis.get_rotation_quaternion()

func _attachment(bone_name: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = "Parts_" + bone_name
	attachment.bone_name = bone_name
	attachment.bone_idx = int(_bones[bone_name])
	skeleton.add_child(attachment)
	_attachments.append(attachment)
	return attachment

func _build_hand_sockets() -> void:
	for side: String in ["L","R"]:
		var attachment := _attachment("LowerArm_" + side)
		var socket := Node3D.new()
		socket.name = "RightHandPropSocket" if side == "R" else "LeftHandPropSocket"
		socket.position = CharacterArt.hand_socket(character_id,side)
		attachment.add_child(socket)
		if side == "R":
			hand_socket = socket
		else:
			left_hand_socket = socket

func set_clock_state(world_enabled: bool, performance_enabled: bool, active_actor: bool, reduce_motion: bool) -> void:
	world_running = world_enabled
	performance_running = performance_enabled
	is_performance_actor = active_actor
	reduced_motion = reduce_motion
	if _configured and animation_player and is_inside_tree() and _active_reduced != reduced_motion:
		_start_clip(_active_clip if not _active_clip.is_empty() else "idle",false)

func _process(delta: float) -> void:
	if not _configured or get_tree().paused:
		return
	if world_running or (performance_running and is_performance_actor):
		advance_visual(delta)

func advance_visual(delta: float) -> void:
	if not _configured:
		return
	var step := clampf(delta, 0.0, 0.1)
	_visual_time += step
	CharacterArt.expression(_art_meshes,_visual_time,current_action,reduced_motion)
	visual.rotation.y = lerp_angle(visual.rotation.y, _desired_yaw, minf(step * 9.0, 1.0))
	var requested_spec := get_action_spec(_requested_action)
	var one_shot := _action_duration > 0.0 and not bool(requested_spec.get("loop",true)) and not _action_complete
	if one_shot:
		_start_clip(_requested_action,false)
		_action_elapsed = minf(_action_elapsed + step,_action_duration)
		animation_player.advance(step)
		skeleton.force_update_all_bone_transforms()
		_sync_bone_attachments()
		_flush_contact_marker()
		_emit_phase(str(get_action_phase().phase))
		if _action_elapsed >= _action_duration - 0.00001:
			_finish_action()
	else:
		var moving := _actual_speed > 0.08 or _explicit_loop == "walk"
		var loop_name := "carry_walk" if moving and _carrying_pose else "walk" if moving else "carry_item" if _carrying_pose else "idle"
		if _is_wheelchair():
			loop_name = "carry_item" if _carrying_pose else "idle"
		_start_clip(loop_name,false)
		var speed := clampf(_actual_speed / 1.6,0.5,1.6) if moving and _explicit_loop != "walk" else 1.0
		animation_player.advance(step * speed)
		if not _action_complete:
			_action_elapsed = fmod(_action_elapsed + step,maxf(_action_duration,0.001))
		skeleton.force_update_all_bone_transforms()
		_sync_bone_attachments()

func _build_animation_player() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "P1AnimationPlayer"
	animation_player.root_node = NodePath("..")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	add_child(animation_player)
	for reduced: bool in [false,true]:
		var library := load(P1Actions.library_path(_rig_family,reduced)) as AnimationLibrary
		if library == null:
			push_error("Missing saved P1 animation library for " + _rig_family)
			continue
		animation_player.add_animation_library("reduced" if reduced else "normal",CharacterArt.adapt_library(character_id,library,P1Actions.hips_height(_rig_family),reduced))

func _start_clip(clip_name: String, restart: bool) -> void:
	if animation_player == null or not is_inside_tree():
		return
	var path := ("reduced/" if reduced_motion else "normal/") + clip_name
	if not animation_player.has_animation(path):
		return
	if not restart and _active_clip == clip_name and _active_reduced == reduced_motion:
		return
	var preserve_time := animation_player.current_animation_position if _active_clip == clip_name and not restart else 0.0
	_active_clip = clip_name
	_active_reduced = reduced_motion
	animation_player.play(path,0.0)
	animation_player.advance(0.0)
	if preserve_time > 0.0:
		animation_player.seek(preserve_time,true,true)
	skeleton.force_update_all_bone_transforms()
	_sync_bone_attachments()

func _sync_bone_attachments() -> void:
	# BoneAttachment normally waits for the skeleton's end-of-frame update.
	# Manual timeline advancement and contact callbacks need the attached mesh
	# and hand-held prop to have the same transform in this exact simulation step.
	for attachment: BoneAttachment3D in _attachments:
		attachment.on_skeleton_update()

func play_action(action_id: String, event_key: String = "", options: Dictionary = {}) -> bool:
	var requested := P1Actions.canonical_action(action_id)
	var action_spec := get_action_spec(requested)
	if not bool(action_spec.get("allowed",false)):
		return false
	motion_path.clear()
	_actual_speed = 0.0
	current_action = requested
	_requested_action = requested
	_invocation_id += 1
	_action_elapsed = 0.0
	_action_duration = float(action_spec.duration)
	_action_event_key = event_key
	_action_contact_sent = false
	_contact_marker_pending = false
	_action_complete = false
	_explicit_loop = "walk" if requested == "walk" else ""
	if requested == "carry_item":
		_carrying_pose = true
	elif requested == "idle":
		_carrying_pose = false
	if options.has("start_holding"):
		_carrying_pose = bool(options.start_holding)
	_start_clip(requested,true)
	_phase_name = ""
	_emit_phase("loop" if bool(action_spec.loop) else "anticipation")
	action_started.emit(character_id,requested,_invocation_id)
	return true

func _finish_action() -> void:
	if _action_complete:
		return
	var finished := _requested_action
	_action_complete = true
	_action_elapsed = _action_duration
	if finished in ["pick_item","take_item"]:
		_carrying_pose = true
	elif finished in ["place_item","give_item"]:
		_carrying_pose = false
	current_action = "carry_item" if _carrying_pose else "idle"
	_start_clip(current_action,true)
	_emit_phase("complete")
	action_finished.emit(character_id,finished)

func _emit_phase(phase: String) -> void:
	if phase == _phase_name:
		return
	_phase_name = phase
	action_phase_changed.emit(character_id,_requested_action,phase,_invocation_id)

func _on_animation_contact_marker() -> void:
	if _action_contact_sent or _action_complete:
		return
	# Method tracks are evaluated before this frame's bone values are committed.
	# Flush after advance() and force_update so both socket APIs and attached
	# objects refer to the actual contact pose rather than the preceding frame.
	_contact_marker_pending = true

func _flush_contact_marker() -> void:
	if not _contact_marker_pending or _action_contact_sent or _action_complete:
		return
	_contact_marker_pending = false
	_action_contact_sent = true
	_emit_phase("contact")
	var socket_world := get_hand_socket_transform()
	action_contact.emit(character_id,_requested_action,_action_event_key,_invocation_id,socket_world)
	var receipt_key := _requested_action + "|" + _action_event_key
	if _action_event_key.is_empty() or not _semantic_receipts.has(receipt_key):
		if not _action_event_key.is_empty():
			_semantic_receipts[receipt_key] = true
		semantic_event.emit(character_id,_requested_action,_action_event_key)

func get_action_spec(action_id: String) -> Dictionary:
	return P1Actions.spec(action_id,_rig_family)

func get_action_duration(action_id: String) -> float:
	var action_spec := get_action_spec(action_id)
	return float(action_spec.duration) if bool(action_spec.allowed) else 0.0

func get_action_phase() -> Dictionary:
	var action_spec := get_action_spec(_requested_action)
	var phase := "complete" if _action_complete else "loop" if bool(action_spec.get("loop",true)) else "perform"
	if not _action_complete and not bool(action_spec.get("loop",true)):
		if float(action_spec.get("contact_time",-1.0)) >= 0.0:
			phase = "anticipation" if _action_elapsed < 0.3 else "reach" if _action_elapsed < float(action_spec.contact_time) else "contact" if _action_elapsed < 1.4 else "recover"
		else:
			phase = "anticipation" if _action_elapsed < 0.3 else "recover" if _action_elapsed > _action_duration - 0.4 else "perform"
	return {"action":_requested_action,"elapsed":_action_elapsed,"duration":_action_duration,
		"phase":phase,"normalized":clampf(_action_elapsed / maxf(_action_duration,0.001),0.0,1.0),
		"contact_sent":_action_contact_sent,"event_key":_action_event_key,"invocation_id":_invocation_id,
		"active_clip":_active_clip,"complete":_action_complete,"reduced_motion":reduced_motion}

func get_hand_socket_transform(hand: String = "right") -> Transform3D:
	var socket := left_hand_socket if hand == "left" else hand_socket
	var bone := "LowerArm_L" if hand == "left" else "LowerArm_R"
	if socket == null or skeleton == null:
		return global_transform
	return skeleton.global_transform * skeleton.get_bone_global_pose(int(_bones[bone])) * socket.transform

func get_action_contact_transform(action_id: String, hand: String = "right") -> Transform3D:
	var id := P1Actions.canonical_action(action_id)
	var action_spec := get_action_spec(id)
	if not bool(action_spec.allowed) or animation_player == null:
		return Transform3D.IDENTITY
	var clip := animation_player.get_animation(("reduced/" if reduced_motion else "normal/") + id)
	var time := float(action_spec.contact_time) if float(action_spec.contact_time) >= 0.0 else float(action_spec.duration) * 0.5
	var socket := left_hand_socket if hand == "left" else hand_socket
	var bone := "LowerArm_L" if hand == "left" else "LowerArm_R"
	var cache: Dictionary = {}
	var pose := _sample_bone_transform(clip,time,int(_bones[bone]),cache)
	return visual.transform * skeleton.transform * pose * socket.transform

func _sample_bone_transform(clip: Animation, time: float, bone_index: int, cache: Dictionary) -> Transform3D:
	if cache.has(bone_index):
		return cache[bone_index] as Transform3D
	var bone_name := skeleton.get_bone_name(bone_index)
	var rest := skeleton.get_bone_rest(bone_index)
	var position_value := rest.origin
	var rotation := rest.basis.get_rotation_quaternion()
	var scale_value := rest.basis.get_scale()
	for track: int in range(clip.get_track_count()):
		if str(clip.track_get_path(track)) != "VisualRoot/PrototypeSkeleton:" + bone_name:
			continue
		match clip.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				position_value = clip.position_track_interpolate(track,time)
			Animation.TYPE_ROTATION_3D:
				rotation = clip.rotation_track_interpolate(track,time)
			Animation.TYPE_SCALE_3D:
				scale_value = clip.scale_track_interpolate(track,time)
	var local := Transform3D(Basis(rotation).scaled(scale_value),position_value)
	var parent := skeleton.get_bone_parent(bone_index)
	var result := _sample_bone_transform(clip,time,parent,cache) * local if parent >= 0 else local
	cache[bone_index] = result
	return result

func face(point: Vector3, immediate: bool = false) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.001:
		_desired_yaw = atan2(offset.x, offset.z)
		if immediate:
			visual.rotation.y = _desired_yaw

func move_to(point: Vector3) -> bool:
	if _is_wheelchair() or not point.is_finite():
		return false
	if Vector2(point.x - global_position.x, point.z - global_position.z).length() > 12.0:
		return false  # Longer routes must be supplied by the existing navigation system.
	return set_path(PackedVector3Array([point]))

func set_path(points: PackedVector3Array) -> bool:
	if _is_wheelchair():
		return false
	for point: Vector3 in points:
		if not point.is_finite():
			return false
	motion_path = points.duplicate()
	_stuck_time = 0.0
	current_action = "carry_item" if _carrying_pose else "walk"
	_requested_action = current_action
	_action_duration = get_action_duration(current_action)
	_action_elapsed = 0.0
	_action_complete = false
	_explicit_loop = ""
	return true

func _physics_process(delta: float) -> void:
	if not _configured or get_tree().paused or not world_running:
		_actual_speed = 0.0
		velocity = Vector3.ZERO
		return
	if motion_path.is_empty() or _is_wheelchair():
		_actual_speed = 0.0
		velocity = Vector3.ZERO
		return
	var offset := motion_path[0] - global_position
	offset.y = 0
	if offset.length() < 0.15:
		motion_path.remove_at(0)
		_actual_speed = 0.0
		return
	var direction := offset.normalized()
	face(global_position + direction)
	var before := global_position
	var ahead := before + direction * movement_speed * delta
	var dry_floor := _dry_floor_at(ahead)
	if dry_floor.is_empty() or absf(float(dry_floor.position.y) - before.y) > 0.45:
		motion_path.clear()
		_actual_speed = 0.0
		return
	velocity = direction * movement_speed
	velocity.y = -0.5
	move_and_slide()
	var after_floor := _dry_floor_at(global_position)
	if after_floor.is_empty():
		global_position = before
		motion_path.clear()
		velocity = Vector3.ZERO
		_actual_speed = 0.0
		return
	global_position.y = float(after_floor.position.y) + 0.02
	_actual_speed = Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.001)
	_stuck_time = _stuck_time + delta if _actual_speed < 0.05 else 0.0
	if _stuck_time > 0.6:
		motion_path.clear()

func _dry_floor_at(point: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.65, point + Vector3.DOWN * 1.4, 4)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < cos(floor_max_angle):
		return {}
	var water_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0, 8)
	var water := space.intersect_ray(water_ray)
	if not water.is_empty() and float(hit.position.y) < float(water.position.y) - 0.002:
		return {}
	return hit

func set_held_prop(prop_id: String) -> void:
	if is_instance_valid(_held_prop):
		_held_prop.queue_free()
		_held_prop = null
	_held_prop_id = prop_id
	_carrying_pose = not prop_id.is_empty()
	if prop_id.is_empty() or hand_socket == null:
		return
	_held_prop = Node3D.new()
	_held_prop.name = "Held_" + prop_id.validate_node_name()
	hand_socket.add_child(_held_prop)
	if prop_id in ["apple","travel_book","book","cake","basket","invitation","nameplate"]:
		var kind := "book" if prop_id == "travel_book" else prop_id
		var authored := WorldArt.create_prop(kind)
		if authored:
			_held_prop.add_child(authored)
			authored.scale = Vector3.ONE * (0.52 if kind == "apple" else 0.45 if kind == "book" else 0.3 if kind == "cake" else 0.4 if kind == "basket" else 1.0)
			if kind in ["invitation","nameplate"]:
				# The carry clip bends the forearm forward; present the card face
				# above its lower grip while retaining the semantic hand socket.
				authored.rotation_degrees = Vector3(124,8,12)
				authored.position = Vector3(0,0,-0.12)
	else:
		_box(_held_prop, Vector3.ZERO, Vector3(0.24, 0.24, 0.24), Color("cfa590"))

func get_interaction() -> Dictionary:
	return {"id":"actor:" + character_id, "type":"textbook_actor", "character_id":character_id,
		"label":"和%s聊一聊" % display_name, "position":global_position, "radius":2.0,
		"actor_ref":self, "greeting":"hello", "name":display_name}

func get_status() -> Dictionary:
	var result := {"character_id":character_id, "kind":str(profile.get("kind", "human")),
		"visual_production_status":"authored_skinned_storybook_v3", "bones":skeleton.get_bone_count() if skeleton else 0,
		"action":current_action, "action_elapsed":_action_elapsed,
		"visual_time":_visual_time, "moving":not motion_path.is_empty(), "walking_allowed":not _is_wheelchair(),
		"held_prop":is_instance_valid(_held_prop), "held_prop_id":_held_prop_id,"collision_layer":collision_layer,
		"animation_system":"saved_AnimationLibrary_manual_AnimationPlayer","rig_family":_rig_family,
		"animation_library":P1Actions.library_path(_rig_family,reduced_motion),"animation_count":animation_player.get_animation_list().size() if animation_player else 0,
		"action_phase":get_action_phase(),"semantic_receipt_count":_semantic_receipts.size(),"carrying_pose":_carrying_pose}
	result.merge(_art_stats,true)
	return result

func _is_wheelchair() -> bool:
	return str(profile.get("kind", "")) == "wheelchair"

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.88
		_materials[key] = material
	return _materials[key] as StandardMaterial3D

func _mesh(parent: Node3D, shape: Mesh, position_value: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = _material(color)
	instance.position = position_value
	parent.add_child(instance)
	return instance

func _ball(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 14
	shape.rings = 8
	var instance := _mesh(parent, shape, point, color)
	instance.scale = size
	return instance

func _box(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, point, color)

func _capsule(parent: Node3D, point: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	shape.radial_segments = 12
	shape.rings = 4
	return _mesh(parent, shape, point, color)

func _cylinder(parent: Node3D, point: Vector3, radius: float, height: float, color: Color, top_radius: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = 16
	return _mesh(parent, shape, point, color)
