extends RefCounted
## Shared ordering for the visible nearby action and explicit same-place choices.

const NPC_TYPES := ["npc","talk","textbook_actor"]
const SWITCH_MARGIN := 0.22
const SHARED_PLACE_DISTANCE := 0.85

static func distance(point: Vector3, entry: Dictionary) -> float:
	var target: Vector3 = entry.position
	return Vector2(point.x-target.x,point.z-target.z).length()

static func nearby(entries: Array, point: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if distance(point,entry) < float(entry.get("radius",2.7)):
			result.append(entry)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var da := distance(point,a)
		var db := distance(point,b)
		if absf(da-db)<0.001:
			if (str(a.get("type",""))=="memory") != (str(b.get("type",""))=="memory"):
				return str(a.get("type",""))=="memory"
			return str(a.id)<str(b.id)
		return da<db
	)
	return result

static func select_nearby(candidates: Array[Dictionary], point: Vector3, previous: Dictionary) -> Dictionary:
	if candidates.is_empty(): return {}
	# At the destination itself, never keep a farther neighbour highlighted.
	if distance(point,candidates[0])<0.65: return candidates[0]
	if not previous.is_empty():
		for entry: Dictionary in candidates:
			var distinct_place := (entry.position as Vector3).distance_to(candidates[0].position)>=0.35
			if str(entry.id)==str(previous.id) and (distinct_place or str(entry.id)==str(candidates[0].id)) and distance(point,entry)<=distance(point,candidates[0])+SWITCH_MARGIN:
				return entry
	return candidates[0]

static func colocated(entry: Dictionary, entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entry.is_empty(): return result
	for other: Dictionary in entries:
		if (entry.position as Vector3).distance_to(other.position)<SHARED_PLACE_DISTANCE:
			result.append(other)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.id)<str(b.id))
	return result

static func focus_height(entry: Dictionary) -> float:
	if str(entry.get("type","")) in NPC_TYPES: return 1.1
	if str(entry.get("type","")) in ["travel","landmark"]: return 0.8
	return 0.12
