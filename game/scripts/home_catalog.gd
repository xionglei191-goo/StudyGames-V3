extends RefCounted
## Stable household identifiers are shared by navigation, saving and activities.

const ROOMS: Array[String] = ["home_estate", "home", "home_bedroom", "home_kitchen", "home_dining", "home_bathroom", "home_study", "home_balcony"]
const HOME_NAV_ROOMS: Array[String] = ["home_hall"]
const CHILD_ROOMS: Array[String] = ["home", "home_bedroom", "home_kitchen", "home_dining", "home_bathroom", "home_study", "home_balcony"]
static var _catalog: Dictionary = {}

static func all() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_hierarchy.json"))
	return _catalog

static func room(id: String) -> Dictionary:
	if not is_home_space(id): return {}
	for entry: Dictionary in all().get("rooms", []):
		if str(entry.room_id) == id: return entry
	for entry: Dictionary in all().get("routes", []):
		if str(entry.room_id) == id: return entry
	return {}

static func is_home_space(id: String) -> bool:
	return id in ROOMS or id in HOME_NAV_ROOMS

static func valid_task(id: String, room_id: String = "") -> bool:
	for entry: Dictionary in all().get("rooms", []):
		if (room_id.is_empty() or str(entry.room_id) == room_id) and str(entry.task.id) == id:
			return true
	return false
