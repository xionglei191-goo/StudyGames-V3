extends SceneTree
## Real CharacterBody3D movement, collision and room-transition integration checks.
## Godot --headless --fixed-fps 60 --path game --script res://tests/test_movement.gd -- --test-harness

const MAX_WALK_FRAMES: int = 6000
const PRODUCTION_SAVE: String = "user://island-save-v1.json"
const SCHOOL_ROOMS: Array[String] = ["classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field"]

var _main: Node3D
var _report: Dictionary = {"checks": [], "planned_routes": [], "routes": [], "transitions": [], "collisions": [], "failures": []}
var _protected_before: Dictionary = {}
var _report_name: String = "movement-report.json"


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Movement validation requires -- --test-harness to isolate player progress.")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-name="): _report_name = argument.trim_prefix("--report-name=").get_file()
	_protected_before = _production_signature()
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_main = packed.instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	var ready_ok: bool = await _wait_for_room("village")
	_check("initial_scene_ready", ready_ok)
	if not ready_ok:
		await _finish()
		return
	var state: Node = root.get_node("State")
	_check("isolated_validation_save", str(state.save_path) == "user://validation-%s.json" % OS.get_process_id())
	_main.muted = true
	_main.voice.stop()
	_check("no_welcome_modal_in_harness", not _main.ui.modal.visible)
	var village_entries: Array = _main.interactions.duplicate(true)
	_check("main_map_from_blender", str(_main.metadata.get("source_scene", "")) == "res://assets/world/island.glb")
	_check("village_interaction_count", village_entries.size() == 32)
	# All 26 letter doors use production AStar from the real spawn. The routes below
	# are a representative physical journey; the separate art validation tours all doors.
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		var id: String = "landmark_" + letter
		var entry: Dictionary = _entry(id)
		var accepted: bool = not entry.is_empty() and _main.navigate_to(entry.position)
		var endpoint: Vector3 = _main.player.path[-1] if not _main.player.path.is_empty() else _main.player.position
		var remaining: float = _distance_xz(endpoint, entry.get("position", Vector3(INF, INF, INF)))
		var passed: bool = accepted and remaining < float(entry.get("radius", 0.0))
		_report.planned_routes.append({"id": id, "accepted": accepted, "waypoints": _main.player.path.size(), "remaining_distance": remaining, "passed": passed})
		_check("letter_door_connected/" + id, passed)
		_main.player.path.clear()
	for id: String in ["home_gate", "baker", "orchard", "landmark_A", "landmark_C"]:
		if await _walk_to_entry(id, "island_journey"):
			if id.begins_with("landmark_"):
				if await _transition(id, id):
					if await _walk_to_entry("village_exit", "return_to_own_door"):
						await _transition("village_exit", "village")
	if await _walk_to_entry("school_gate", "enter_school"):
		if await _transition("school_gate", "school"):
			await _test_school_rooms()
	if _main.room == "school":
		if await _walk_to_entry("village_exit", "leave_school"):
			await _transition("village_exit", "village")
	if _main.room == "village":
		if await _walk_to_entry("home_gate", "enter_home"):
			if await _transition("home_gate", "home_estate"):
				if await _enter_house_room("home"):
					await _test_home_activity("memory_02", "装扮客厅", "decorate")
					if await _walk_to_entry("home_exit", "leave_living_room"):
						await _transition("home_exit", "home_hall")
				if _main.room == "home_hall":
					if await _enter_house_room("home_bedroom"):
						await _test_home_activity("memory_05", "睡到明天", "rest")
						if await _walk_to_entry("home_exit", "leave_bedroom"):
							await _transition("home_exit", "home_hall")
				if _main.room == "home_hall" and await _walk_to_entry("courtyard_exit", "leave_indoor_home"):
					await _transition("courtyard_exit", "home_estate")
				if _main.room == "home_estate" and await _walk_to_entry("village_exit", "leave_home"):
					await _transition("village_exit", "village")
	_check("journey_returns_to_village", _main.room == "village")
	if _main.room == "village":
		await _test_village_collisions()
	await _finish()


func _enter_house_room(room_id: String) -> bool:
	if _main.room == "home_estate":
		if not await _walk_to_entry("house_entry", "enter_house"): return false
		if not await _transition("house_entry", "home_hall"): return false
	_check("front_door_enters_walkable_hall/" + room_id, _main.room == "home_hall" and not _main.ui.modal.visible and _main.ui.current_panel != "home_entry")
	if _main.room != "home_hall": return false
	if not await _walk_to_entry(room_id + "_gate", "indoor_room_door"): return false
	return await _transition(room_id + "_gate", room_id)


func _test_school_rooms() -> void:
	var rooms: Array[Dictionary] = [
		{"door": "classroom_gate", "room": "classroom", "activity": "teacher"},
		{"door": "music_room_gate", "room": "music_room", "activity": "host"},
		{"door": "art_room_gate", "room": "art_room", "activity": "host"},
		{"door": "science_room_gate", "room": "science_room", "activity": "host"},
		{"door": "canteen_gate", "room": "canteen", "activity": "lunch"},
		{"door": "playground_gate", "room": "playground", "activity": "sports"},
		{"door": "football_field_gate", "room": "football_field", "activity": "host"},
	]
	for visit: Dictionary in rooms:
		if _main.room != "school":
			_check("school_visit_order_" + str(visit.room), false)
			return
		if not await _walk_to_entry(str(visit.door), "campus_door"):
			continue
		if not await _transition(str(visit.door), str(visit.room)):
			continue
		if await _walk_to_entry(str(visit.activity), "room_activity"):
			await _open_and_close(str(visit.activity))
		if await _walk_to_entry("school_exit", "return_from_" + str(visit.room)):
			await _transition("school_exit", "school")


func _open_and_close(id: String) -> void:
	var selected: bool = str(_main.nearest.get("id", "")) == id
	_check("activity_selected_" + str(_main.room) + "/" + id, selected)
	if not selected:
		return
	_main.interact_nearest()
	await process_frame
	_check("activity_panel_" + str(_main.room) + "/" + id, _main.ui.modal.visible)
	_main._on_action("close")
	await process_frame
	_check("activity_unlocked_" + str(_main.room) + "/" + id, not _main.ui.modal.visible and not _main.player.locked)


func _test_home_activity(marker_id: String, button_text: String, activity: String) -> void:
	if not await _walk_to_entry(marker_id, "home_activity/" + activity):
		return
	_main.interact_nearest()
	await process_frame
	await process_frame
	_check("home_" + activity + "_opens_from_nearest", _main.ui.modal.visible and _main.ui.current_panel == "memory")
	var target_button: Button = null
	for node: Node in _main.ui.panel_box.find_children("*", "Button", true, false):
		var candidate := node as Button
		if candidate.text == button_text and candidate.visible and not candidate.disabled:
			target_button = candidate
			break
	_check("home_" + activity + "_button_available", target_button != null)
	if target_button != null:
		var state: Node = root.get_node("State")
		var day_before: int = int(state.data.day)
		target_button.pressed.emit()
		await process_frame
		await process_frame
		if activity == "rest":
			_check("home_rest_advances_one_day", int(state.data.day) == day_before + 1)
		else:
			_check("home_wardrobe_opens_decoration_panel", _main.ui.modal.visible and _main.ui.current_panel == "decorate")
	_main._on_action("close")
	await process_frame
	_check("home_" + activity + "_unlocks_player", not _main.ui.modal.visible and not _main.player.locked)


func _wait_for_room(expected: String) -> bool:
	var stable: int = 0
	for frame: int in range(600):
		await physics_frame
		await process_frame
		if _main.scene_ready and not _main.loading_room and _main.nav_ready and _main.room == expected:
			stable += 1
			if stable >= 3:
				return true
		else:
			stable = 0
	return false


func _entry(id: String) -> Dictionary:
	for entry: Dictionary in _main.interactions:
		if str(entry.id) == id:
			return entry
	return {}


func _walk_to_entry(id: String, context: String) -> bool:
	var entry: Dictionary = _entry(id)
	if entry.is_empty():
		_check("missing_interaction_" + str(_main.room) + "/" + id, false)
		return false
	var reached: bool = await _walk_to_point(context + "/" + id, entry.position, float(entry.radius))
	var nearest_id: String = str(_main.nearest.get("id", ""))
	var selected: bool = nearest_id == id
	_check("interaction_available_" + str(_main.room) + "/" + context + "/" + id, reached and selected)
	var last: Dictionary = _report.routes[-1]
	last["target_interaction"] = id
	last["nearest_interaction"] = nearest_id
	last["interaction_available"] = selected
	return reached and selected


func _walk_to_point(label: String, destination: Vector3, tolerance: float) -> bool:
	_main._on_action("close")
	await process_frame
	var initial: Vector3 = _main.player.position
	var initial_room: String = _main.room
	var accepted: bool = _main.navigate_to(destination)
	var frames: int = 0
	var moved: float = 0.0
	var previous: Vector3 = initial
	var last_waypoint: Vector3 = initial
	var contacts: Dictionary = {}
	while accepted and not _main.player.path.is_empty() and frames < MAX_WALK_FRAMES:
		last_waypoint = _main.player.path[0]
		await physics_frame
		await process_frame
		frames += 1
		var position_now: Vector3 = _main.player.position
		moved += _distance_xz(previous, position_now)
		previous = position_now
		for index: int in range(_main.player.get_slide_collision_count()):
			var hit: KinematicCollision3D = _main.player.get_slide_collision(index)
			var collider: Object = hit.get_collider()
			var key: String = str((collider as Node).get_path()) if collider is Node else str(collider)
			contacts[key] = {"frame": frames, "normal": _vector(hit.get_normal()), "position": _vector(hit.get_position())}
	await process_frame
	await process_frame
	var final_position: Vector3 = _main.player.position
	var remaining: float = _distance_xz(final_position, destination)
	var result: bool = accepted and remaining <= tolerance and _main.room == initial_room and frames < MAX_WALK_FRAMES
	var item: Dictionary = {
		"room": initial_room, "label": label, "accepted": accepted,
		"start": _vector(initial), "destination": _vector(destination), "finish": _vector(final_position),
		"physics_frames": frames, "distance_walked": moved, "remaining_distance": remaining,
		"allowed_distance": tolerance, "remaining_waypoints": _main.player.path.size(), "passed": result,
	}
	if not result:
		item["last_waypoint"] = _vector(last_waypoint)
		item["last_contacts_by_collider"] = contacts
		item["player_floor_max_angle_degrees"] = rad_to_deg(_main.player.floor_max_angle)
	_report.routes.append(item)
	_check("walk_" + initial_room + "/" + label, result)
	print("WALK %s/%s: %s (%.3f / %.2f, %d frames)" % [initial_room, label, "PASS" if result else "FAIL", remaining, tolerance, frames])
	return result


func _transition(id: String, destination_room: String) -> bool:
	var origin: String = _main.room
	var original_entry: Dictionary = _entry(id)
	var selected: bool = str(_main.nearest.get("id", "")) == id
	_check("transition_selected_" + origin + "/" + id, selected)
	if not selected:
		_report.transitions.append({"from": origin, "interaction": id, "to": destination_room, "passed": false, "reason": "Requested doorway is not the nearest interaction."})
		return false
	_main.interact_nearest()
	var result: bool = await _wait_for_room(destination_room)
	var item: Dictionary = {"from": origin, "interaction": id, "to": destination_room, "passed": result}
	if result and destination_room != "village":
		_check("transition_blender_source/" + destination_room, str(_main.metadata.get("source", "")) == "blender")
	if result and id in ["village_exit", "school_exit", "home_exit", "courtyard_exit"]:
		var fallback_door: String = origin + "_gate" if id == "home_exit" or origin in SCHOOL_ROOMS else str({"school": "school_gate", "home_estate": "home_gate", "home_hall":"house_entry"}.get(origin, origin))
		var door: String = str(original_entry.get("return_id", fallback_door))
		var entry: Dictionary = _entry(door)
		var remaining: float = _distance_xz(_main.player.position, entry.get("return_position", entry.get("position", Vector3(INF, INF, INF))))
		item["return_door"] = door
		item["return_distance"] = remaining
		_check("return_at_own_door/" + origin, not entry.is_empty() and remaining <= 2.0)
	_report.transitions.append(item)
	_check("transition_" + origin + "/" + id + "->" + destination_room, result)
	return result


func _test_village_collisions() -> void:
	# Resolve the actual imported collider; no old village coordinates are used.
	_main._on_action("close")
	_main.player.touch_axis = Vector2.ZERO
	await process_frame
	var bodies: Array[Node] = _main.world.find_children("Fountain_*", "StaticBody3D", true, false)
	_check("imported_fountain_body_exists", bodies.size() == 1)
	if bodies.size() != 1:
		return
	var body: StaticBody3D = bodies[0] as StaticBody3D
	var box_node: CollisionShape3D = null
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			var box_candidate: CollisionShape3D = child as CollisionShape3D
			if box_candidate.shape is BoxShape3D and not box_candidate.disabled:
				box_node = box_candidate
				break
	var player_shape: CollisionShape3D = null
	for child: Node in _main.player.get_children():
		if child is CollisionShape3D:
			var capsule_candidate: CollisionShape3D = child as CollisionShape3D
			if capsule_candidate.shape is CapsuleShape3D:
				player_shape = capsule_candidate
				break
	var shapes_ready: bool = box_node != null and player_shape != null and (body.collision_layer & 1) != 0
	_check("imported_fountain_live_shapes", shapes_ready)
	if not shapes_ready:
		return
	var radius: float = (player_shape.shape as CapsuleShape3D).radius
	var half: Vector3 = (box_node.shape as BoxShape3D).size * 0.5
	var nav: AStarGrid2D = _main.navigation
	var cell: float = _main.NAV_CELL
	var player: CharacterBody3D = _main.player
	var from_cell: Vector2i = Vector2i(roundi(player.position.x / cell), roundi(player.position.z / cell))
	if not nav.is_in_boundsv(from_cell):
		_check("fountain_probe_source_in_navigation", false)
		return
	if nav.is_point_solid(from_cell):
		from_cell = _main._nearest_walkable_cell(from_cell, player.position)
	if not nav.is_in_boundsv(from_cell):
		_check("fountain_probe_source_walkable", false)
		return
	var best: Dictionary = {}
	var best_score: float = INF
	# Imported box bodies have rotation and unit scale; size already includes mesh scale.
	for local_normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var x_face: bool = absf(local_normal.x) > 0.5
		var extent: float = half.x if x_face else half.z
		var face_point: Vector3 = box_node.to_global(local_normal * extent)
		var outward: Vector3 = (box_node.global_basis * local_normal).normalized()
		if absf(outward.y) > 0.02:
			continue
		outward.y = 0
		outward = outward.normalized()
		var desired: Vector3 = _main.to_local(face_point + outward * (radius + 1.4))
		var center_cell: Vector2i = Vector2i(roundi(desired.x / cell), roundi(desired.z / cell))
		for dx: int in range(-2, 3):
			for dz: int in range(-2, 3):
				var key: Vector2i = center_cell + Vector2i(dx, dz)
				if not nav.is_in_boundsv(key) or nav.is_point_solid(key) or not _main.nav_heights.has(key):
					continue
				var local_start: Vector3 = Vector3(key.x * cell, float(_main.nav_heights[key]) + 0.05, key.y * cell)
				var world_start: Vector3 = _main.to_global(local_start)
				var gap: float = (world_start - face_point).dot(outward)
				if gap < radius + 0.8 or gap > radius + 2.4:
					continue
				var in_box: Vector3 = box_node.to_local(world_start)
				var tangent: float = in_box.z if x_face else in_box.x
				var tangent_half: float = half.z if x_face else half.x
				if absf(tangent) > tangent_half - radius - 0.35:
					continue
				# Test this exact grid cell, without navigate_to's target-cell fallback.
				var route: PackedVector2Array = nav.get_point_path(from_cell, key)
				if route.is_empty() or not _fountain_start_clear(body, player_shape, world_start, outward, gap, radius):
					continue
				var score: float = float(route.size()) + absf(tangent)
				if score < best_score:
					best_score = score
					best = {"start": local_start, "face": face_point, "normal": outward}
	_check("fountain_probe_reachable_side_found", not best.is_empty())
	if best.is_empty():
		return
	# Real walking is required before direct input; never teleport to a probe fixture.
	if not await _walk_to_point("fountain_collision_approach", best.start, 0.25):
		return
	player.path.clear()
	await physics_frame
	await process_frame
	var face: Vector3 = best.face
	var normal: Vector3 = best.normal
	var initial: Vector3 = player.global_position
	var initial_gap: float = (initial - face).dot(normal)
	var ready: bool = player.is_on_floor() and not player.locked and initial_gap > radius + 0.45
	ready = ready and _fountain_start_clear(body, player_shape, initial, normal, initial_gap, radius)
	_check("fountain_probe_actual_start_valid", ready)
	if not ready:
		return
	var consecutive_contacts: int = 0
	var longest_contact_run: int = 0
	var minimum_clearance: float = INF
	var tail_start: Vector3 = initial
	var frames: int = 120
	var input_valid: bool = true
	for frame: int in range(frames):
		var axis: Vector2 = _world_direction_to_touch_axis(-normal)
		if axis.length() < 0.05:
			input_valid = false
			break
		player.touch_axis = axis
		await physics_frame
		await process_frame
		var target_contact: bool = false
		for index: int in range(player.get_slide_collision_count()):
			var hit: KinematicCollision3D = player.get_slide_collision(index)
			if hit.get_collider() == body and hit.get_normal().dot(normal) > 0.85:
				target_contact = true
		consecutive_contacts = consecutive_contacts + 1 if target_contact else 0
		longest_contact_run = maxi(longest_contact_run, consecutive_contacts)
		var clearance: float = (player.global_position - face).dot(normal) - radius
		minimum_clearance = minf(minimum_clearance, clearance)
		if frame == frames - 21:
			tail_start = player.global_position
	player.touch_axis = Vector2.ZERO
	player.path.clear()
	var final_position: Vector3 = player.global_position
	var forward_motion: float = (final_position - initial).dot(-normal)
	var tail_motion: float = _distance_xz(tail_start, final_position)
	var result: bool = input_valid and _main.room == "village" and forward_motion > 0.25
	result = result and longest_contact_run >= 12 and minimum_clearance >= -0.06 and tail_motion < 0.08
	_report.collisions.append({
		"obstacle": str(body.get_path()), "shape": str(box_node.get_path()),
		"box_size": _vector((box_node.shape as BoxShape3D).size),
		"face": _vector(face), "outward_normal": _vector(normal),
		"start": _vector(initial), "finish": _vector(final_position),
		"frames_driven": frames, "forward_motion": forward_motion,
		"longest_target_contact_run": longest_contact_run,
		"minimum_capsule_clearance": minimum_clearance,
		"final_20_frame_motion": tail_motion, "passed": result,
	})
	_check("physical_collision_imported_fountain", result)


func _fountain_start_clear(body: StaticBody3D, player_shape: CollisionShape3D, foot: Vector3, normal: Vector3, gap: float, radius: float) -> bool:
	var player: CharacterBody3D = _main.player
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var hypothetical: Transform3D = player.global_transform
	hypothetical.origin = foot
	# Use the real capsule and its local offset, not the navigation sphere.
	var probe: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	probe.shape = player_shape.shape
	probe.transform = hypothetical * player_shape.transform
	probe.collision_mask = 1
	probe.exclude = [player.get_rid()]
	if not space.intersect_shape(probe, 1).is_empty():
		return false
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe.transform.origin, probe.transform.origin - normal * (gap + radius + 0.5), 1)
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty() or hit.get("collider") != body:
		return false
	# Reject a short approach with a drop or steep ramp that could mimic blocking.
	var ground_y: float = INF
	var travel: float = maxf(gap - radius - 0.05, 0.0)
	for sample: int in range(5):
		var at: Vector3 = foot - normal * travel * float(sample) / 4.0
		var floor_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 4)
		var floor_hit: Dictionary = space.intersect_ray(floor_ray)
		if floor_hit.is_empty():
			return false
		var floor_normal: Vector3 = floor_hit.normal
		var floor_position: Vector3 = floor_hit.position
		if floor_normal.dot(Vector3.UP) < 0.95:
			return false
		if sample == 0:
			ground_y = floor_position.y
		elif absf(floor_position.y - ground_y) > 0.15:
			return false
	return true


func _world_direction_to_touch_axis(direction: Vector3) -> Vector2:
	# Solve the camera's projected basis rather than assuming orthogonal axes.
	var right: Vector3 = _main.camera.global_basis.x
	var down: Vector3 = _main.camera.global_basis.z
	right.y = 0
	down.y = 0
	right = right.normalized()
	down = down.normalized()
	var determinant: float = right.x * down.z - down.x * right.z
	if absf(determinant) < 0.001:
		return Vector2.ZERO
	return Vector2((direction.x * down.z - direction.z * down.x) / determinant, (right.x * direction.z - right.z * direction.x) / determinant)


func _check(label: String, passed: bool) -> void:
	_report.checks.append({"name": label, "passed": passed})
	if not passed:
		_report.failures.append(label)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _production_signature() -> Dictionary:
	var signature: Dictionary = {}
	for suffix: String in ["", ".bak"]:
		var path: String = PRODUCTION_SAVE + suffix
		signature[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return signature


func _finish() -> void:
	_check("production_save_unchanged", _production_signature() == _protected_before)
	_report["engine"] = Engine.get_version_info()["string"]
	_report["passed"] = _report.failures.is_empty()
	_report["complete"] = true
	_report["actual_physics_movement"] = true
	_report["production_save_unchanged"] = _production_signature() == _protected_before
	_report["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	var report_directory: String = ProjectSettings.globalize_path("res://../.local/validation")
	DirAccess.make_dir_recursive_absolute(report_directory)
	var report_path: String = report_directory.path_join(_report_name)
	var output: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(_report, "\t"))
		output.close()
	else:
		push_error("Could not write movement report: " + report_path)
		_report.failures.append("write_report")
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	var validation_save: String = "user://validation-%s.json" % OS.get_process_id()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(validation_save + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(validation_save + suffix))
	if _report.failures.is_empty():
		print("PASS: %d actual movement routes, %d transitions, %d physical collision probes; player save unchanged" % [_report.routes.size(), _report.transitions.size(), _report.collisions.size()])
		quit(0)
	else:
		for failure: String in _report.failures:
			push_error(str(failure))
		quit(1)
