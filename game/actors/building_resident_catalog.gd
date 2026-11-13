extends RefCounted
## Distinct building hosts. Textbook cast and outdoor quest NPCs retain their IDs.
const PATH := "res://assets/characters/building_residents_v1/catalog.json"
static var _catalog: Dictionary = {}

static func all() -> Dictionary:
	if _catalog.is_empty() and FileAccess.file_exists(PATH):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary: _catalog = value.get("residents",{})
	return _catalog

static func for_room(room_id: String) -> Dictionary:
	for record: Dictionary in all().values():
		if str(record.room_id) == room_id: return record
	return {}

static func profile(character_id: String) -> Dictionary:
	return all().get(character_id,{})
