extends Node3D
## V5 Tactile World Feedback: soft glowing target rings, 3D bobbing interaction
## beacon, animated ground click ripples, and stepping-stone pearls that fade as walked.

const WorldArt = preload("res://scripts/world_art.gd")
const Targets = preload("res://scripts/interaction_targets.gd")

var target_ring: MeshInstance3D
var _target_halo: MeshInstance3D
var _target_beacon: MeshInstance3D
var destination_ring: MeshInstance3D
var path_root: Node3D
var pick_root: Node3D
var reduced_motion := false
var _clock := 0.0
var _path_clock := 0.0
var _beacon_base_y := 2.4

func _ready() -> void:
	target_ring = _ring(Color(0.98, 0.87, 0.52, 0.90), 0.68, 0.80)
	_target_halo = _ring(Color(0.99, 0.94, 0.76, 0.36), 0.80, 0.98)
	_target_beacon = _build_beacon()
	destination_ring = _ring(Color(1.0, 0.93, 0.68, 0.92), 0.30, 0.44)
	target_ring.hide()
	_target_halo.hide()
	_target_beacon.hide()
	destination_ring.hide()
	path_root = Node3D.new()
	add_child(path_root)
	pick_root = Node3D.new()
	add_child(pick_root)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _ring(color: Color, inner: float, outer: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 36
	torus.ring_segments = 8
	ring.mesh = torus
	ring.scale.y = 0.28
	ring.material_override = _material(color)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.layers = 2
	add_child(ring)
	return ring

func _build_beacon() -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.24, 0.22, 0.24)
	b.mesh = prism
	b.rotation_degrees.z = 180.0
	b.material_override = _material(Color(0.99, 0.84, 0.40, 0.92))
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.layers = 2
	add_child(b)
	return b

func spawn_click_ripple(world_pos: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rip := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.37
	torus.rings = 28
	torus.ring_segments = 6
	rip.mesh = torus
	var mat := _material(Color(1.0, 0.92, 0.62, 0.86))
	rip.material_override = mat
	rip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rip.layers = 2
	rip.position = world_pos + Vector3(0.0, 0.08, 0.0)
	rip.scale = Vector3(0.35, 0.22, 0.35)
	add_child(rip)
	var tw := rip.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rip, "scale", Vector3(1.55, 0.22, 1.55), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.chain().tween_callback(rip.queue_free)

func bind_interactions(entries: Array) -> void:
	for child: Node in pick_root.get_children():
		pick_root.remove_child(child)
		child.queue_free()
	clear_path()
	target_ring.hide()
	_target_halo.hide()
	_target_beacon.hide()
	for entry: Dictionary in entries:
		var area := Area3D.new()
		area.collision_layer = 16
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("interaction", entry)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var npc := str(entry.get("type", "")) in Targets.NPC_TYPES
		var doorway := str(entry.get("type", "")) in ["travel", "landmark"]
		shape.size = Vector3(1.35, 2.7, 1.35) if npc else (Vector3(1.65, 2.1, 1.65) if doorway else Vector3(1.4, 0.85, 1.4))
		collision.shape = shape
		collision.position.y = 1.25 if npc else (0.9 if doorway else 0.3)
		area.position = entry.position
		area.add_child(collision)
		pick_root.add_child(area)

func pick(point: Vector2, camera: Camera3D) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 400, 16)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	var excluded: Array[RID] = []
	var selected: Dictionary = {}
	var best := INF
	for attempt: int in range(pick_root.get_child_count()):
		ray.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			break
		var area: CollisionObject3D = hit.collider
		excluded.append(area.get_rid())
		var entry: Dictionary = area.get_meta("interaction", {})
		if entry.is_empty():
			continue
		var focus: Vector3 = entry.position + Vector3.UP * Targets.focus_height(entry)
		if camera.is_position_behind(focus):
			continue
		var score := point.distance_squared_to(camera.unproject_position(focus))
		if score < best - 0.001 or (absf(score - best) < 0.001 and str(entry.id) < str(selected.get("id", "~"))):
			selected = entry
			best = score
	return selected

func update_dynamic_targets() -> void:
	for target: Node3D in pick_root.get_children():
		var entry: Dictionary = target.get_meta("interaction", {})
		if entry.has("actor_ref") and is_instance_valid(entry.actor_ref):
			target.position = entry.actor_ref.global_position

func highlight(entry: Dictionary) -> void:
	var show_it := not entry.is_empty()
	target_ring.visible = show_it
	_target_halo.visible = show_it
	_target_beacon.visible = show_it
	if show_it:
		var pos: Vector3 = entry.position
		if entry.has("actor_ref") and is_instance_valid(entry.actor_ref):
			pos = (entry.actor_ref as Node3D).global_position
		target_ring.position = pos + Vector3(0.0, 0.08, 0.0)
		_target_halo.position = pos + Vector3(0.0, 0.06, 0.0)
		var is_npc := str(entry.get("type", "")) in Targets.NPC_TYPES
		_beacon_base_y = pos.y + (2.45 if is_npc else 1.55)
		_target_beacon.position = Vector3(pos.x, _beacon_base_y, pos.z)

func show_path(points: PackedVector3Array) -> void:
	clear_path()
	_path_clock = 0.0
	if points.is_empty():
		return
	destination_ring.position = points[-1] + Vector3(0, 0.09, 0)
	destination_ring.show()
	var step := maxi(2, ceili(float(points.size()) / 48.0))
	for index: int in range(0, points.size(), step):
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.095
		mesh.height = 0.075
		mesh.radial_segments = 10
		mesh.rings = 6
		dot.mesh = mesh
		dot.material_override = _material(Color(0.99, 0.94, 0.74, 0.82))
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.position = points[index] + Vector3(0, 0.10, 0)
		dot.layers = 2
		path_root.add_child(dot)

func trim_passed_path(player_pos: Vector3) -> void:
	for child: Node in path_root.get_children():
		var dot := child as Node3D
		if dot != null and Vector2(dot.position.x - player_pos.x, dot.position.z - player_pos.z).length() < 0.75:
			dot.queue_free()

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
	for mesh: Node in object.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2
	add_child(object)
	var start := origin + Vector3(0, 1.4, 0)
	var finish := receiver + Vector3(0, 1.4, 0)
	object.position = start
	var tween := object.create_tween()
	if reduced_motion:
		object.position = finish
		tween.tween_interval(0.2)
	else:
		tween.tween_method(func(progress: float): object.position = start.lerp(finish, progress) + Vector3.UP * sin(progress * PI) * 1.1, 0.0, 1.0, 0.65)
	tween.tween_callback(object.queue_free)
	var caption := Label3D.new()
	caption.text = text
	caption.font = preload("res://ui/island_theme.gd").heading_font()
	caption.font_size = 32
	caption.pixel_size = 0.014
	caption.modulate = Color("fff7d4")
	caption.outline_modulate = Color("3c5942")
	caption.outline_size = 6
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = true
	caption.layers = 2
	caption.position = receiver + Vector3(0, 3.3, 0)
	add_child(caption)
	var label_tween := caption.create_tween()
	label_tween.set_parallel(true)
	label_tween.tween_property(caption, "modulate:a", 0.0, 1.25).set_delay(0.35)
	if not reduced_motion:
		label_tween.tween_property(caption, "position:y", caption.position.y + 1.1, 1.4)
	label_tween.chain().tween_callback(caption.queue_free)

func _process(delta: float) -> void:
	_clock += delta
	_path_clock += delta
	if is_instance_valid(target_ring) and target_ring.visible:
		var pulse := 1.0 if reduced_motion else 1.0 + sin(_clock * 3.6) * 0.045
		target_ring.scale = Vector3(pulse, 0.28, pulse)
		_target_halo.scale = Vector3(2.0 - pulse, 0.22, 2.0 - pulse)
		if is_instance_valid(_target_beacon):
			_target_beacon.position.y = _beacon_base_y + (0.0 if reduced_motion else sin(_clock * 4.2) * 0.08)
			_target_beacon.rotation.y = _clock * 1.6 if not reduced_motion else 0.0
	if is_instance_valid(destination_ring) and destination_ring.visible:
		var arrival := 1.0 if reduced_motion else 1.0 + sin(_clock * 4.0) * 0.08
		destination_ring.scale = Vector3(arrival, 0.28, arrival)
