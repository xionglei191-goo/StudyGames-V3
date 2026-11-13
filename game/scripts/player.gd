extends CharacterBody3D

# At full travel speed a stride takes about 0.71 s. Distance still drives the
# phase, so braking and blocked movement cannot keep the feet cycling in place.
const WALK_PHASE_PER_METER := 1.7
const SPRINT_MULTIPLIER := 1.42

var visual: Node3D
var camera: Camera3D
var bounds := Rect2(-25, -22, 50, 44)
var locked := false
var path: PackedVector3Array = PackedVector3Array()
var walk_time := 0.0
var idle_time := 0.0
var stuck_time := 0.0
var speed := 5.4
var acceleration := 38.0
var braking := 52.0
var touch_axis := Vector2.ZERO
var pointer_steer := Vector2.ZERO
var auto_sprint := false
var terrain := false
var safe_position := Vector3.ZERO
var safe_position_ready := false
var gesture_time := 0.0
var gesture_kind := ""
var reduced_motion := false
var _dust_particles: GPUParticles3D
var look_target := Vector3.INF
var _visual_floor_offset := 0.0

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.8
	_visual_floor_offset = shape.position.y - capsule.height * 0.5
	add_child(shape)
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = 0.65
	floor_max_angle = deg_to_rad(52.0)
	_build_footstep_puffs()

func _build_footstep_puffs() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_dust_particles = GPUParticles3D.new()
	_dust_particles.name = "FootstepPuffs"
	_dust_particles.amount = 16
	_dust_particles.lifetime = 0.55
	_dust_particles.emitting = false
	_dust_particles.position = Vector3(0.0, 0.08, 0.0)
	_dust_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 55.0
	proc.initial_velocity_min = 0.25
	proc.initial_velocity_max = 0.68
	proc.gravity = Vector3(0.0, -0.6, 0.0)
	proc.scale_min = 0.65
	proc.scale_max = 1.25
	_dust_particles.process_material = proc
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.065
	puff_mesh.height = 0.11
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 6
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(0.98, 0.95, 0.88, 0.54)
	puff_mesh.material = pmat
	_dust_particles.draw_pass_1 = puff_mesh
	add_child(_dust_particles)

func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	if not locked:
		axis = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down") + touch_axis
	var direction := Vector3.ZERO
	if axis.length() > 0.05:
		path.clear()
		auto_sprint = false
		var right := camera.global_basis.x
		var down := camera.global_basis.z
		right.y = 0
		down.y = 0
		direction = (right.normalized() * axis.x + down.normalized() * axis.y).normalized()
	elif not locked and pointer_steer.length() > 0.05:
		path.clear()
		direction = Vector3(pointer_steer.x, 0.0, pointer_steer.y).normalized()
	elif not locked and not path.is_empty():
		while not path.is_empty():
			var offset := path[0] - position
			offset.y = 0
			if offset.length() < 0.22:
				path.remove_at(0)
			else:
				direction = offset.normalized()
				break
		if path.is_empty():
			auto_sprint = false
	else:
		auto_sprint = false

	var old_position := position
	var sprinting := not locked and (Input.is_key_pressed(KEY_SHIFT) or auto_sprint)
	var travel_speed := speed * (SPRINT_MULTIPLIER if sprinting else 1.0)
	if axis.length() <= 0.05 and pointer_steer.length() <= 0.05 and path.size() == 1:
		var remaining := Vector2(path[0].x - position.x, path[0].z - position.z).length()
		travel_speed *= clampf(remaining / 0.60, 0.34, 1.0)
	var horizontal := Vector2(velocity.x, velocity.z)
	var target := Vector2(direction.x, direction.z) * travel_speed
	horizontal = Vector2.ZERO if locked else horizontal.move_toward(target, (braking if target.is_zero_approx() else acceleration) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if not is_on_floor():
		velocity.y = maxf(velocity.y - 24.0 * delta, -30.0)
	else:
		velocity.y = -0.2
	move_and_slide()
	var water_contact := false
	var dry_ground := false
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as CollisionObject3D
		if body == null:
			continue
		water_contact = water_contact or bool(body.get_meta("sg_water", false))
		if body.collision_layer & 4 and contact.get_normal().y >= cos(floor_max_angle):
			dry_ground = true
	water_contact = water_contact or (terrain and _water_above_feet(global_position))
	if water_contact:
		position = safe_position + Vector3.UP * 0.08 if safe_position_ready else old_position
		velocity = Vector3.ZERO
		path.clear()
		auto_sprint = false
	if terrain and not water_contact and direction.length() > 0.1:
		_try_small_ground_step(direction)
	if is_on_floor() and dry_ground and not water_contact:
		safe_position = position
		safe_position_ready = true
	elif safe_position_ready and position.y < safe_position.y - 8.0:
		position = safe_position + Vector3(0, 0.25, 0)
		velocity = Vector3.ZERO
		path.clear()
		auto_sprint = false
	position.x = clampf(position.x, bounds.position.x + 0.4, bounds.end.x - 0.4)
	position.z = clampf(position.z, bounds.position.y + 0.4, bounds.end.y - 0.4)
	if direction.length() > 0.1 and position.distance_to(old_position) < 0.005:
		stuck_time += delta
		if stuck_time > 0.5:
			path.clear()
			auto_sprint = false
	else:
		stuck_time = 0
	if visual:
		var movement := Vector2(position.x - old_position.x, position.z - old_position.z)
		var moving := movement.length() > 0.002 and not water_contact
		if moving:
			walk_time += movement.length() * WALK_PHASE_PER_METER
			var target_yaw := atan2(movement.x, movement.y)
			var yaw_diff := wrapf(target_yaw - visual.rotation.y, -PI, PI)
			visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, minf(delta * 16.0, 1.0))
			visual.position.y = 0.0 if reduced_motion else absf(sin(walk_time)) * 0.058
			var bank := clampf(-yaw_diff * 0.16, -0.11, 0.11)
			visual.rotation.z = 0.0 if reduced_motion else lerpf(visual.rotation.z, bank + sin(walk_time) * 0.02, minf(delta * 10.0, 1.0))
			visual.rotation.x = 0.0 if reduced_motion else lerpf(visual.rotation.x, 0.045, minf(delta * 8.0, 1.0))
		else:
			idle_time += delta
			visual.position.y = 0.0 if reduced_motion else sin(idle_time * 2.0) * 0.014
			visual.rotation.z = lerpf(visual.rotation.z, 0.0, delta * 8.0)
			visual.rotation.x = lerpf(visual.rotation.x, 0.0, delta * 8.0)
		if visual.has_method("animate_player"):
			visual.position.y = _visual_floor_offset
			visual.rotation.x = 0.0
			visual.rotation.z = 0.0
		if is_instance_valid(_dust_particles):
			_dust_particles.emitting = moving and not reduced_motion and is_on_floor()
		if visual.has_method("set_head_interest"):
			if look_target != Vector3.INF and not reduced_motion:
				var to_target := look_target - global_position
				if Vector2(to_target.x, to_target.z).length() < 4.5:
					var desired_yaw := wrapf(atan2(to_target.x, to_target.z) - visual.rotation.y, -PI, PI)
					if absf(desired_yaw) < 1.15:
						visual.set_head_interest(desired_yaw * 0.48, -0.04)
					else:
						visual.set_head_interest(0.0, 0.0)
				else:
					visual.set_head_interest(0.0, 0.0)
			else:
				visual.set_head_interest(0.0, 0.0)
		_animate_limbs(moving, delta)

func face(point: Vector3) -> void:
	if not visual:
		return
	var offset := point - position
	if Vector2(offset.x, offset.z).length() > 0.01:
		visual.rotation.y = atan2(offset.x, offset.z)

func gesture(kind: String = "wave") -> void:
	gesture_kind = kind
	gesture_time = 0.8

func _animate_limbs(walking: bool, delta: float) -> void:
	gesture_time = maxf(0.0, gesture_time - delta)
	if visual.has_method("animate_player"):
		visual.animate_player(walking, delta, walk_time, gesture_kind, gesture_time, reduced_motion)
		return
	var stride := sin(walk_time) * 0.48 if walking else 0.0
	for entry: Array in [["LegLeft", stride], ["LegRight", -stride], ["ArmLeft", -stride * 0.6], ["ArmRight", stride * 0.6]]:
		var limb := visual.get_node_or_null(str(entry[0])) as Node3D
		if limb:
			var angle := float(entry[1])
			if str(entry[0]) == "ArmRight" and gesture_time > 0:
				angle = -1.3 if gesture_kind == "reach" else -2.2 + sin(gesture_time * 18) * 0.18
			if str(entry[0]) == "LegRight" and gesture_time > 0 and gesture_kind == "kick":
				angle = -0.8 * sin(gesture_time * PI / 0.8)
			limb.rotation.x = lerpf(limb.rotation.x, angle, minf(delta * 14, 1))

func _water_above_feet(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 20.0, point + Vector3.DOWN * 20.0, 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or point.y + 0.05 > float(hit.position.y) + 0.01:
		return false
	var ground_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point + Vector3.DOWN * 1.5, 4)
	var ground := get_world_3d().direct_space_state.intersect_ray(ground_ray)
	return ground.is_empty() or float(ground.position.y) < float(hit.position.y) - 0.002

func _try_small_ground_step(direction: Vector3) -> void:
	var ground_edge := false
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as CollisionObject3D
		if body == null:
			continue
		if body.collision_layer & 1:
			return
		if body.collision_layer & 4 and collision.get_normal().y < cos(floor_max_angle):
			ground_edge = true
	if not ground_edge:
		return
	var ahead := global_position + direction * 0.45
	var ray := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.45, ahead + Vector3.DOWN * 0.1, 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < cos(floor_max_angle):
		return
	var rise: float = float(hit.position.y) - (global_position.y + 0.05)
	if rise < 0.025 or rise > 0.30:
		return
	var lift := Vector3.UP * (rise + 0.10)
	var raised := global_transform
	raised.origin += lift
	if test_move(global_transform, lift) or test_move(raised, direction * 0.45):
		return
	global_position = Vector3(ahead.x, float(hit.position.y) + 0.02, ahead.z)
	velocity.y = 0
	apply_floor_snap()

func set_outfit(color_name: String) -> void:
	if not visual:
		return
	if visual.has_method("set_outfit"):
		visual.set_outfit(color_name)
		return
	var colors := {"yellow": Color("e6b946"), "pink": Color("d87e93"), "blue": Color("79aeca")}
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		if "overall" in mesh.name.to_lower() or "outfit" in mesh.name.to_lower() or "shirt" in mesh.name.to_lower():
			var material := StandardMaterial3D.new()
			material.albedo_color = colors.get(color_name, colors.yellow)
			material.roughness = 0.85
			mesh.material_override = material

func apply_wardrobe(state_data: Dictionary) -> void:
	if not visual:
		return
	var outfit_id := str(state_data.get("outfit", "yellow"))
	var w: Dictionary = state_data.get("wardrobe", {}) if state_data.get("wardrobe") is Dictionary else {}
	var hat_id := str(w.get("hat", "none"))
	var bag_id := str(w.get("bag", "none"))
	if visual.has_method("set_wardrobe"):
		visual.set_wardrobe(outfit_id, hat_id, bag_id)
	else:
		set_outfit(outfit_id)

func set_carried_item(prop_id: String) -> void:
	if visual and visual.has_method("set_carried_item"):
		visual.set_carried_item(prop_id)
