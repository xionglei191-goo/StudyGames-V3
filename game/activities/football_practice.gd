extends Node3D
## A deterministic five-shot practice on the actual pitch, using its authored goal.
signal shot_finished(scored: bool, attempts: int, goals: int)
signal round_finished(goals: int)

var ball: Node3D
var aim_marker: MeshInstance3D
var flight: Tween
var start := Vector3.ZERO
var goal := Vector3.ZERO
var forward := Vector3.RIGHT
var sideways := Vector3.BACK
var half_width := 2.0
var goal_height := 2.2
var ground := 0.05
var aim := 0.0
var power := 0.65
var attempts := 0
var goals := 0
var busy := false
var _original_props: Array[Node3D] = []

func setup(world: Node3D, entries: Array) -> bool:
	var frame := world.find_child("Football_EastGoal_GoalFrame",true,false) as MeshInstance3D
	if frame == null:
		return false
	var box: AABB = frame.global_transform*frame.get_aabb()
	var center := Vector3.ZERO
	for entry: Dictionary in entries:
		if str(entry.id)=="memory_02":
			center = entry.position
	goal = box.get_center()
	goal.y = center.y
	forward = (goal-center).normalized()
	forward.y = 0
	forward = forward.normalized()
	sideways = forward.cross(Vector3.UP).normalized()
	var depth := absf(forward.x)*box.size.x+absf(forward.z)*box.size.z
	goal -= forward*depth*0.5
	half_width = (absf(sideways.x)*box.size.x+absf(sideways.z)*box.size.z)*0.5
	goal_height = box.size.y
	start = goal-forward*6.2
	var ray := PhysicsRayQueryParameters3D.create(start+Vector3.UP*10,start+Vector3.DOWN*10,4)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	ground = float(hit.position.y)+0.02 if not hit.is_empty() else 0.05
	start.y = ground+0.28
	goal.y = ground
	ball = Node3D.new()
	add_child(ball)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff6df")
	material.roughness = 0.85
	mesh.material_override = material
	ball.add_child(mesh)
	for offset: Vector3 in [Vector3(0,0.26,0),Vector3(0.24,0,0.11),Vector3(-0.12,0,0.24)]:
		var patch := MeshInstance3D.new()
		var small := SphereMesh.new()
		small.radius = 0.085
		small.height = 0.17
		patch.mesh = small
		var dark := material.duplicate() as StandardMaterial3D
		dark.albedo_color = Color("466353")
		patch.material_override = dark
		patch.position = offset
		ball.add_child(patch)
	ball.position = start
	aim_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.36
	aim_marker.mesh = torus
	aim_marker.rotation.x = PI/2
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("c8ab57")
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_marker.material_override = marker_material
	add_child(aim_marker)
	update_aim(0.0)
	return true

func update_aim(value: float) -> void:
	aim = clampf(value,-1.25,1.25)
	if is_instance_valid(aim_marker):
		aim_marker.position = goal+sideways*aim*half_width*1.25+Vector3.UP*0.9

func aim_from_screen(point: Vector2, camera: Camera3D) -> void:
	var ray_start := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var denominator := direction.dot(forward)
	if absf(denominator)<0.001:
		return
	var distance := (goal-ray_start).dot(forward)/denominator
	if distance>0:
		var hit := ray_start+direction*distance
		update_aim((hit-goal).dot(sideways)/(half_width*1.25))

func predicted_goal() -> bool:
	var ratio := 0.45+power*1.1
	if ratio<1:
		return false
	var crossing := 1.0/ratio
	var height := 0.28+sin(PI*crossing)*(0.45+power*power*3.8)
	return absf(aim*half_width*1.25)<half_width-0.28 and height<goal_height-0.28

func shoot() -> bool:
	if busy or attempts>=5:
		return false
	busy = true
	attempts += 1
	var scored := predicted_goal()
	var distance := Vector2(goal.x-start.x,goal.z-start.z).length()
	var ratio := 0.45+power*1.1
	var finish := start+forward*distance*ratio+sideways*aim*half_width*1.25*ratio
	var arc := 0.45+power*power*3.8
	flight = create_tween()
	flight.tween_method(func(progress: float):
		ball.position = start.lerp(finish,progress)+Vector3.UP*sin(PI*progress)*arc
		ball.rotation.z = -progress*TAU*3
	,0.0,1.0,0.95)
	flight.tween_callback(func():
		if scored:
			goals += 1
		shot_finished.emit(scored,attempts,goals)
	)
	flight.tween_interval(0.5)
	flight.tween_callback(func():
		busy = false
		ball.position = start
		if attempts==5:
			round_finished.emit(goals)
	)
	return true

func restart() -> void:
	if busy:
		return
	attempts = 0
	goals = 0
	ball.position = start
