extends CharacterBody3D

var visual: Node3D
var camera: Camera3D
var bounds := Rect2(-25, -22, 50, 44)
var locked := false
var path: PackedVector3Array = PackedVector3Array()
var walk_time := 0.0
var idle_time := 0.0
var stuck_time := 0.0
var speed := 5.2
var acceleration := 34.0
var braking := 48.0
var touch_axis := Vector2.ZERO
var terrain := false
var safe_position := Vector3.ZERO
var safe_position_ready := false
var gesture_time := 0.0
var gesture_kind := ""
var reduced_motion := false

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = 0.65
	# The authored island has short road facets around 47 degrees near hill joins.
	floor_max_angle = deg_to_rad(52.0)

func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	if not locked:
		axis = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down") + touch_axis
	var direction := Vector3.ZERO
	if axis.length() > 0.05:
		path.clear()
		var right := camera.global_basis.x
		var down := camera.global_basis.z
		right.y = 0
		down.y = 0
		direction = (right.normalized() * axis.x + down.normalized() * axis.y).normalized()
	elif not locked and not path.is_empty():
		# Consume reached points in this frame; a road waypoint must not stop a walk.
		while not path.is_empty():
			var offset := path[0] - position
			offset.y = 0
			if offset.length() < 0.20:
				path.remove_at(0)
			else:
				direction = offset.normalized()
				break
	var old_position := position
	var travel_speed := speed
	if axis.length() <= 0.05 and path.size() == 1:
		var remaining := Vector2(path[0].x-position.x,path[0].z-position.z).length()
		travel_speed *= clampf(remaining / 0.60,0.32,1.0)
	var horizontal := Vector2(velocity.x,velocity.z)
	var target := Vector2(direction.x,direction.z)*travel_speed
	horizontal = Vector2.ZERO if locked else horizontal.move_toward(target,(braking if target.is_zero_approx() else acceleration)*delta)
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
	if terrain and not water_contact and direction.length() > 0.1:
		_try_small_ground_step(direction)
	if is_on_floor() and dry_ground and not water_contact:
		safe_position = position
		safe_position_ready = true
	elif safe_position_ready and position.y < safe_position.y - 8.0:
		position = safe_position + Vector3(0, 0.25, 0)
		velocity = Vector3.ZERO
		path.clear()
	position.x = clampf(position.x, bounds.position.x + 0.4, bounds.end.x - 0.4)
	position.z = clampf(position.z, bounds.position.y + 0.4, bounds.end.y - 0.4)
	if direction.length() > 0.1 and position.distance_to(old_position) < 0.005:
		stuck_time += delta
		if stuck_time > 0.5:
			path.clear()
	else:
		stuck_time = 0
	if visual:
		var movement := Vector2(position.x-old_position.x,position.z-old_position.z)
		var moving := movement.length() > 0.002 and not water_contact
		if moving:
			walk_time += movement.length() * 2.3
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(movement.x, movement.y), minf(delta * 14,1.0))
			visual.position.y = 0.0 if reduced_motion else absf(sin(walk_time))*0.065
			visual.rotation.z = 0.0 if reduced_motion else sin(walk_time)*0.025
		else:
			idle_time += delta
			visual.position.y = 0.0 if reduced_motion else sin(idle_time*2.0)*0.015
			visual.rotation.z = lerpf(visual.rotation.z, 0, delta * 8)
		_animate_limbs(moving,delta)

func face(point: Vector3) -> void:
	if not visual:
		return
	var offset := point-position
	if Vector2(offset.x,offset.z).length()>0.01:
		visual.rotation.y = atan2(offset.x,offset.z)

func gesture(kind: String = "wave") -> void:
	gesture_kind = kind
	gesture_time = 0.8

func _animate_limbs(walking: bool, delta: float) -> void:
	gesture_time = maxf(0.0,gesture_time-delta)
	if visual.has_method("animate_player"):
		visual.animate_player(walking,delta,walk_time,gesture_kind,gesture_time,reduced_motion)
		return
	var stride := sin(walk_time)*0.48 if walking else 0.0
	for entry: Array in [["LegLeft",stride],["LegRight",-stride],["ArmLeft",-stride*0.6],["ArmRight",stride*0.6]]:
		var limb := visual.get_node_or_null(str(entry[0])) as Node3D
		if limb:
			var angle := float(entry[1])
			if str(entry[0])=="ArmRight" and gesture_time>0:
				angle = -1.3 if gesture_kind=="reach" else -2.2+sin(gesture_time*18)*0.18
			if str(entry[0])=="LegRight" and gesture_time>0 and gesture_kind=="kick":
				angle = -0.8*sin(gesture_time*PI/0.8)
			limb.rotation.x = lerpf(limb.rotation.x,angle,minf(delta*14,1))

func _water_above_feet(point: Vector3) -> bool:
	# Layer 8 exists only on water volumes. A dry bridge deck remains above this
	# surface, while submerged terrain must never become a recovery position.
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*20.0, point+Vector3.DOWN*20.0, 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or point.y + 0.05 > float(hit.position.y) + 0.01:
		return false
	# A contact may become resting floor contact with no new slide collision.
	# Require actual dry ground under the feet, so water cannot act as a floor.
	var ground_ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.3, point+Vector3.DOWN*1.5, 4)
	var ground := get_world_3d().direct_space_state.intersect_ray(ground_ray)
	return ground.is_empty() or float(ground.position.y) < float(hit.position.y) - 0.002

func _try_small_ground_step(direction: Vector3) -> void:
	var ground_edge := false
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as CollisionObject3D
		if body == null:
			continue
		# Never step over fences, furniture, buildings or water blockers.
		if body.collision_layer & 1:
			return
		if body.collision_layer & 4 and collision.get_normal().y < cos(floor_max_angle):
			ground_edge = true
	if not ground_edge:
		return
	var ahead := global_position + direction * 0.45
	var ray := PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*0.45, ahead+Vector3.DOWN*0.1, 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < cos(floor_max_angle):
		return
	var rise: float = float(hit.position.y) - (global_position.y + 0.05)
	if rise < 0.025 or rise > 0.30:
		return
	var lift := Vector3.UP * (rise+0.10)
	var raised := global_transform
	raised.origin += lift
	if test_move(global_transform, lift) or test_move(raised, direction*0.45):
		return
	global_position = Vector3(ahead.x,float(hit.position.y)+0.02,ahead.z)
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
