extends SceneTree
## Drives the real player controller over each imported-map route, using an isolated save.

func _initialize() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	var main: Node3D = packed.instantiate() as Node3D
	root.add_child(main)
	while not bool(main.get("scene_ready")):
		await process_frame
	var player: CharacterBody3D = main.get("player") as CharacterBody3D
	var metadata: Dictionary = main.get("metadata")
	var spawn: Vector3 = metadata.spawn
	var entries: Array = metadata.interactions.duplicate(true)
	var only_id := ""
	var start_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only_id = arg.trim_prefix("--only=")
		elif arg.begins_with("--start="):
			start_id = arg.trim_prefix("--start=")
	if not start_id.is_empty():
		for entry: Dictionary in entries:
			if str(entry.id) == start_id:
				spawn = entry.position
	var rows: Array[Dictionary] = []
	var failures: Array[String] = []
	var marker_errors: Array[String] = []
	var marker_nodes: Dictionary = metadata.marker_nodes
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/manifest.json")) as Dictionary
	for marker: Dictionary in manifest.markers:
		var expected := Vector3(float(marker.world_godot[0]), float(marker.world_godot[1]), float(marker.world_godot[2]))
		if not marker_nodes.has(marker.name) or (marker_nodes[marker.name].position as Vector3).distance_to(expected) > 0.025:
			marker_errors.append(str(marker.name))
	for entry: Dictionary in entries:
		if not only_id.is_empty() and str(entry.id) != only_id:
			continue
		player.set("path", PackedVector3Array())
		player.position = spawn + Vector3.UP * 0.15
		player.velocity = Vector3.ZERO
		player.set("safe_position", player.position)
		for index: int in range(5):
			await physics_frame
		var planned: bool = bool(main.call("navigate_to", entry.position))
		var ticks := 0
		var end_distance := INF
		var next_waypoint := Vector3.ZERO
		var last_progress_position: Vector3 = player.position
		var last_progress_tick := 0
		while planned and ticks < 6000:
			var path: PackedVector3Array = player.get("path")
			end_distance = Vector2(player.position.x, player.position.z).distance_to(Vector2(entry.position.x, entry.position.z))
			if end_distance < minf(1.7, float(entry.radius) - 0.2):
				break
			if path.is_empty():
				break
			next_waypoint = path[0]
			await physics_frame
			ticks += 1
			if player.position.distance_to(last_progress_position) > 0.2:
				last_progress_position = player.position
				last_progress_tick = ticks
			elif ticks - last_progress_tick > 150:
				break
		var passed: bool = planned and end_distance < float(entry.radius)
		if not passed:
			failures.append(str(entry.id))
		var collisions: Array[Dictionary] = []
		for index: int in range(player.get_slide_collision_count()):
			var collision: KinematicCollision3D = player.get_slide_collision(index)
			var collider: Object = collision.get_collider()
			collisions.append({"body": str(collider.get("name")), "normal": str(collision.get_normal()), "position": str(collision.get_position())})
		var row := {"id": entry.id, "planned": planned, "reached": passed, "distance": snappedf(end_distance, 0.01), "ticks": ticks, "position": [player.position.x, player.position.y, player.position.z], "next_waypoint": [next_waypoint.x, next_waypoint.y, next_waypoint.z], "goal": [entry.position.x, entry.position.y, entry.position.z], "on_floor": player.is_on_floor(), "collisions": collisions}
		rows.append(row)
		print("WORLD_WALK ", JSON.stringify(row))
	var report := {"result": "PASS" if failures.is_empty() and marker_errors.is_empty() else "FAIL", "start_id": start_id, "failures": failures, "marker_transform_errors": marker_errors, "collision_stats": metadata.collision_stats, "routes": rows, "source": metadata.source_scene, "player_collision_mask": player.collision_mask}
	var report_name := "build_v1_art_navigation_report" + ("_" + start_id if not start_id.is_empty() else "")
	var output := FileAccess.open("F:/LoveStudy/scripts/" + report_name + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("WORLD_WALK_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() and marker_errors.is_empty() else 1)
