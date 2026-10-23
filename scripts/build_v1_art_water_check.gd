extends SceneTree

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
	var lake: MeshInstance3D
	for candidate: Node in main.find_children("*", "MeshInstance3D", true, false):
		if str(candidate.name) == "ALPHA_V3_Lake_Deep_To_Shallow":
			lake = candidate as MeshInstance3D
			break
	if lake == null:
		for candidate: Node in main.find_children("*Water*", "MeshInstance3D", true, false):
			print("WATER_CANDIDATE ", candidate.name)
		quit(2)
		return
	var box: AABB = lake.global_transform * lake.get_aabb()
	var center := box.get_center()
	print("WATER_BOUNDS ", lake.name, " ", box)
	var results: Array[Dictionary] = []
	var failures := 0
	for side: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var half_width := box.size.x * 0.5 if absf(side.x) > 0.5 else box.size.z * 0.5
		var start := center + side * (half_width + 5.0)
		var floor_query := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 100, start + Vector3.DOWN * 100, 4)
		var floor_hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(floor_query)
		if floor_hit.is_empty():
			continue
		start.y = (floor_hit.position as Vector3).y + 0.15
		player.position = start
		player.velocity = Vector3.ZERO
		player.set("path", PackedVector3Array())
		player.set("safe_position", start)
		player.set("safe_position_ready", false)
		for tick: int in range(60):
			await physics_frame
		if not bool(player.get("safe_position_ready")):
			failures += 1
			results.append({"side": str(side), "result": "FIXTURE_NOT_ON_DRY_LAND", "position": str(player.position), "start": str(start)})
			print("WATER_FIXTURE_FAIL ", JSON.stringify(results.back()))
			continue
		var unsafe_water_ticks := 0
		for tick: int in range(500):
			player.set("path", PackedVector3Array([center]))
			await physics_frame
			if _standing_on_water(main, player):
				unsafe_water_ticks += 1
		var collisions: Array[Dictionary] = []
		for index: int in range(player.get_slide_collision_count()):
			var collision := player.get_slide_collision(index)
			collisions.append({"body": str(collision.get_collider().get("name")), "normal": str(collision.get_normal())})
		var ground_ray := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*2,player.position+Vector3.DOWN*2,4)
		var ground_under: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(ground_ray)
		var obstacle_ray := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*2,player.position+Vector3.DOWN*2,1)
		var obstacle_under: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(obstacle_ray)
		if unsafe_water_ticks > 0:
			failures += 1
		var row := {"side": str(side), "start": str(start), "position": str(player.position), "safe_position":str(player.get("safe_position")), "ground_under": str(ground_under.get("position", "none")), "obstacle_under": str(obstacle_under.get("position", "none")), "obstacle_body": str((obstacle_under.collider as Node).name) if not obstacle_under.is_empty() else "none", "distance_to_water_center": Vector2(player.position.x - center.x, player.position.z - center.z).length(), "on_floor": player.is_on_floor(), "collisions": collisions, "unsafe_water_ticks": unsafe_water_ticks}
		results.append(row)
		print("WATER_WALK ", JSON.stringify(row))
	var output := FileAccess.open("F:/LoveStudy/scripts/build_v1_art_water_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"result": "PASS" if failures == 0 else "FAIL", "failures": failures, "directions": results}, "  "))
	output.close()
	print("WATER_WALK_RESULT ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _standing_on_water(main: Node3D, player: CharacterBody3D) -> bool:
	# Test the actual capsule foot and physics surfaces, including the shore.
	# The player origin is 5 cm below its capsule foot. A higher dry layer-4
	# surface is legitimate ground even when a water volume lies underneath.
	var origin := player.position + Vector3.UP * 0.5
	var end := player.position + Vector3.DOWN * 3.0
	var space := main.get_world_3d().direct_space_state
	var water_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 8))
	if water_hit.is_empty() or player.position.y + 0.05 > float(water_hit.position.y) + 0.01:
		return false
	var ground_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 4))
	return ground_hit.is_empty() or float(ground_hit.position.y) < float(water_hit.position.y) - 0.002
