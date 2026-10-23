extends Node3D
## Interaction picking and small scene-local feedback; no saved geometry edits.
const WorldArt = preload("res://scripts/world_art.gd")

var target_ring: MeshInstance3D
var destination_ring: MeshInstance3D
var path_root: Node3D
var pick_root: Node3D
var reduced_motion := false
var _clock := 0.0
var _path_clock := 0.0

func _ready() -> void:
	target_ring = _ring(Color("f5e2a1"),0.72,0.82)
	destination_ring = _ring(Color("fff1bd"),0.32,0.44)
	target_ring.hide()
	destination_ring.hide()
	path_root = Node3D.new()
	add_child(path_root)
	pick_root = Node3D.new()
	add_child(pick_root)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _ring(color: Color, inner: float, outer: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.scale.y = 0.35
	ring.material_override = _material(color)
	ring.layers = 2
	add_child(ring)
	return ring

func bind_interactions(entries: Array) -> void:
	for child: Node in pick_root.get_children():
		pick_root.remove_child(child)
		child.queue_free()
	clear_path()
	target_ring.hide()
	for entry: Dictionary in entries:
		var duplicated := false
		if str(entry.id).begins_with("memory_"):
			for other: Dictionary in entries:
				if not str(other.id).begins_with("memory_") and (entry.position as Vector3).distance_to(other.position)<0.6:
					duplicated = true
		if duplicated:
			continue
		var area := Area3D.new()
		area.collision_layer = 16
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("interaction",entry)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var npc := str(entry.get("type","")) in ["npc","talk"]
		shape.size = Vector3(1.55,2.8,1.55) if npc else Vector3(2.4,2.5,2.4)
		collision.shape = shape
		collision.position.y = 1.2
		area.position = entry.position
		area.add_child(collision)
		pick_root.add_child(area)

func pick(point: Vector2, camera: Camera3D) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*400,16)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return {}
	var area: CollisionObject3D = hit.collider
	return area.get_meta("interaction",{})

func update_dynamic_targets() -> void:
	for target: Node3D in pick_root.get_children():
		var entry: Dictionary = target.get_meta("interaction",{})
		if entry.has("actor_ref") and is_instance_valid(entry.actor_ref):
			target.position = entry.actor_ref.global_position

func highlight(entry: Dictionary) -> void:
	target_ring.visible = not entry.is_empty()
	if not entry.is_empty():
		target_ring.position = entry.position + Vector3(0,0.09,0)

func show_path(points: PackedVector3Array) -> void:
	clear_path()
	_path_clock = 0.0
	if points.is_empty():
		return
	destination_ring.position = points[-1]+Vector3(0,0.1,0)
	destination_ring.show()
	var step := maxi(2,ceili(float(points.size())/60.0))
	for index: int in range(0,points.size(),step):
		var dot := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.10
		mesh.bottom_radius = 0.10
		mesh.height = 0.035
		mesh.radial_segments = 8
		dot.mesh = mesh
		dot.material_override = _material(Color("f3e5b8"))
		dot.position = points[index]+Vector3(0,0.10,0)
		dot.layers = 2
		path_root.add_child(dot)

func clear_path() -> void:
	destination_ring.hide()
	for child: Node in path_root.get_children():
		path_root.remove_child(child)
		child.queue_free()

func pickup(origin: Vector3, receiver: Vector3, item: String, text: String) -> void:
	var object := WorldArt.create_prop("apple" if item == "apple" else "cake")
	if object == null:
		return
	object.scale = Vector3.ONE * (0.82 if item == "apple" else 0.50)
	for mesh: Node in object.find_children("*","MeshInstance3D",true,false):
		mesh.layers = 2
	add_child(object)
	var start := origin+Vector3(0,1.4,0)
	var finish := receiver+Vector3(0,1.4,0)
	object.position = start
	var tween := object.create_tween()
	if reduced_motion:
		object.position = finish
		tween.tween_interval(0.2)
	else:
		tween.tween_method(func(progress: float): object.position=start.lerp(finish,progress)+Vector3.UP*sin(progress*PI)*1.1,0.0,1.0,0.65)
	tween.tween_callback(object.queue_free)
	var caption := Label3D.new()
	caption.text = text
	caption.font = preload("res://ui/island_theme.gd").body_font()
	caption.font_size = 30
	caption.pixel_size = 0.014
	caption.modulate = Color("fff5cc")
	caption.outline_modulate = Color("47614c")
	caption.outline_size = 5
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = true
	caption.layers = 2
	caption.position = receiver+Vector3(0,3.3,0)
	add_child(caption)
	var label_tween := caption.create_tween()
	label_tween.set_parallel(true)
	label_tween.tween_property(caption,"modulate:a",0.0,1.2).set_delay(0.35)
	if not reduced_motion:
		label_tween.tween_property(caption,"position:y",caption.position.y+1.1,1.4)
	label_tween.chain().tween_callback(caption.queue_free)

func _process(delta: float) -> void:
	_clock += delta
	_path_clock += delta
	if is_instance_valid(target_ring):
		var pulse := 1.0 if reduced_motion else 1.0+sin(_clock*3)*0.035
		target_ring.scale = Vector3(pulse,0.35,pulse)
	if is_instance_valid(destination_ring) and destination_ring.visible:
		var arrival := 1.0 if reduced_motion else 1.0+maxf(0.0,0.7-_path_clock)*0.7
		destination_ring.scale = Vector3(arrival,0.35,arrival)
