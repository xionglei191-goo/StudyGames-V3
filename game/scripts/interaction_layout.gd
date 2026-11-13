extends RefCounted
## Keep fixed learning anchors; place residents beside them on clear ground.

const MIN_SEPARATION := 2.8
const SEARCH_RADII := [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0]

static func resolve(world: Node3D, info: Dictionary, actors: Dictionary, camera_offset: Vector3) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	var entries: Array = info.get("interactions", [])
	var bounds: Rect2 = info.get("bounds", Rect2(-100,-100,200,200))
	var space := world.get_world_3d().direct_space_state
	for entry: Dictionary in entries:
		var id := str(entry.id)
		if not actors.has(id) or not is_instance_valid(actors[id]): continue
		var actor: Node3D = actors[id]
		var original: Vector3 = entry.position
		if can_place_actor(original, id, entries, camera_offset): continue
		var exclude: Array[RID] = []
		for body: Node in actor.find_children("*","CollisionObject3D",true,false):
			exclude.append((body as CollisionObject3D).get_rid())
		if actor is CollisionObject3D: exclude.append((actor as CollisionObject3D).get_rid())
		var chosen := Vector3.INF
		var best := INF
		for radius: float in SEARCH_RADII:
			for step: int in range(32):
				var angle := TAU*float(step)/32.0
				var point := original + Vector3(cos(angle)*radius,0,sin(angle)*radius)
				if not bounds.grow(-0.7).has_point(Vector2(point.x,point.z)): continue
				if not can_place_actor(point,id,entries,camera_offset): continue
				var floor_ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.0,point+Vector3.DOWN*2.0,4)
				var floor_hit := space.intersect_ray(floor_ray)
				if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < 0.85: continue
				point = floor_hit.position as Vector3
				if absf(point.y-original.y) > 0.65: continue
				var water := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.0,point+Vector3.DOWN,8))
				if not water.is_empty() and float(water.position.y) > point.y+0.01: continue
				var shape := CapsuleShape3D.new()
				shape.radius = 0.6
				shape.height = 2.2
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.collision_mask = 1
				query.exclude = exclude
				query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*1.15)
				if not space.intersect_shape(query,1).is_empty(): continue
				var score := point.distance_squared_to(original)
				if score < best:
					best = score
					chosen = point
			if chosen != Vector3.INF: break
		if chosen == Vector3.INF:
			changes.append({"id":id,"resolved":false,"original":original})
			continue
		actor.global_position = chosen
		entry["authored_position"] = original
		entry.position = chosen
		entry["actor_ref"] = actor
		var marker: Variant = info.get("marker_nodes",{}).get(str(entry.get("marker","")))
		if marker is Node3D: (marker as Node3D).global_position = chosen
		for npc: Dictionary in info.get("npcs",[]):
			if (npc.position as Vector3).distance_to(original)<0.01: npc.position = chosen
		changes.append({"id":id,"resolved":true,"original":original,"position":chosen,"distance":sqrt(best)})
	return changes

static func can_place_actor(point: Vector3, own_id: String, entries: Array, camera_offset: Vector3, clearance: float = MIN_SEPARATION) -> bool:
	var forward := -camera_offset.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	for other: Dictionary in entries:
		if str(other.id) == own_id: continue
		var delta: Vector3 = point-other.position
		if Vector2(delta.x,delta.z).length() < clearance: return false
		# A resident can cover a ground marker even when their feet are separated.
		if str(other.get("type","")) in ["npc","talk","textbook_actor"]: continue
		var bottom := (delta+Vector3.UP*0.1).dot(up)
		var top := (delta+Vector3.UP*2.6).dot(up)
		if absf(delta.dot(right)) < 1.1 and bottom < 0.5 and top > -0.5: return false
	return true
