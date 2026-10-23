extends RefCounted
## Repository-only content package. No State or external textbook dependency.

static var _catalog: Dictionary = {}
static var _entry_index: Dictionary = {}
static var _icon_cache: Dictionary = {}
const STORY_ART_REVISION := "storybook-v2"
static var _icon_overrides: Dictionary = {
	"A":"res://assets/learning/storybook_v2/A.png",
	"B":"res://assets/learning/storybook_v1/B.png",
	"C":"res://assets/learning/storybook_v2/C.png",
	"D":"res://assets/learning/storybook_v2/D.png",
	"E":"res://assets/learning/storybook_v2/E.png",
	"F":"res://assets/learning/storybook_v2/F.png",
	"G":"res://assets/learning/storybook_v2/G.png",
	"H":"res://assets/learning/storybook_v2/H.png",
	"I":"res://assets/learning/storybook_v2/I.png",
	"J":"res://assets/learning/storybook_v2/J.png",
	"K":"res://assets/learning/storybook_v1/K.png",
	"L":"res://assets/learning/storybook_v2/L.png",
	"M":"res://assets/learning/storybook_v2/M.png",
	"N":"res://assets/learning/storybook_v2/N.png",
	"O":"res://assets/learning/storybook_v1/O.png",
	"P":"res://assets/learning/storybook_v2/P.png",
	"Q":"res://assets/learning/storybook_v2/Q.png",
	"R":"res://assets/learning/storybook_v2/R.png",
	"S":"res://assets/learning/storybook_v2/S.png",
	"T":"res://assets/learning/storybook_v2/T.png",
	"U":"res://assets/learning/storybook_v2/U.png",
	"V":"res://assets/learning/storybook_v2/V.png",
	"W":"res://assets/learning/storybook_v2/W.png",
	"X":"res://assets/learning/storybook_v2/X.png",
	"Y":"res://assets/learning/storybook_v2/Y.png",
	"Z":"res://assets/learning/storybook_v2/Z.png"
}

static func load_catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/catalog.json"))
		if parsed is Dictionary:
			_catalog = parsed
			for entry: Dictionary in _catalog.get("entries", []):
				_entry_index[str(entry.get("entry_id", ""))] = entry
	return _catalog

static func get_entry(entry_id: String) -> Dictionary:
	var data := load_catalog()
	if not _entry_index.has(entry_id):
		return {}
	var entry: Dictionary = _entry_index[entry_id].duplicate(true)
	entry.merge(data.get("lexemes", {}).get(entry.lexeme_id, {}).duplicate(true))
	entry.merge(data.get("stories", {}).get(entry.story_id, {}).duplicate(true))
	entry["content_revision"] = data.get("content_revision", "")
	entry["codebook_revision"] = data.get("codebook_revision", "")
	entry["content_status"] = data.get("content_status", {}).duplicate(true)
	entry["source_refs"] = []
	for id: String in entry.get("source_ids", []):
		entry.source_refs.append(data.get("sources", {}).get(id, {}).duplicate(true))
	return entry

static func list_entries(book_id: String = "", unit_id: String = "", query: String = "") -> Array:
	var result: Array = []
	var normalized := query.strip_edges().to_lower()
	for entry: Dictionary in load_catalog().get("entries", []):
		var source: Dictionary = entry.get("source_unit", {})
		if not book_id.is_empty() and str(source.get("book_id", "")) != book_id:
			continue
		if not unit_id.is_empty() and not source.get("unit_ids", []).has(unit_id):
			continue
		if not normalized.is_empty() and not (str(entry.spelling_display).to_lower()+" "+str(entry.meaning_zh)).contains(normalized):
			continue
		result.append(entry)
	return result

static func icon(letter: String, raster_scale: float = 1.0) -> Texture2D:
	var key := letter.to_upper()
	if key.length() != 1 or not "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(key) or not is_finite(raster_scale) or raster_scale <= 0:
		return null
	var asset_path := icon_asset_path(key)
	var cache_key := key+"@"+str(raster_scale)+"@"+asset_path
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key] as Texture2D
	# Art revisions are independent of curriculum IDs and saved learning evidence.
	# Load through ResourceLoader so imported PNG textures also work inside the PCK.
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path, "Texture2D"):
		var source := load(asset_path) as Texture2D
		if source != null:
			var raster := source.get_image()
			if raster != null and not raster.is_empty():
				if not raster.is_compressed() or raster.decompress() == OK:
					var pixels := maxi(1, roundi(160.0*raster_scale))
					if raster.get_width() != pixels or raster.get_height() != pixels:
						raster.resize(pixels,pixels,Image.INTERPOLATE_LANCZOS)
					var painted := ImageTexture.create_from_image(raster)
					painted.set_meta("source_art_path",asset_path)
					_icon_cache[cache_key] = painted
					return painted
	var svg := str(codebook_item(key).get("svg_source", ""))
	if svg.is_empty():
		svg = FileAccess.get_file_as_string("res://data/learning/icons/%s.svg" % key)
	var picture := Image.new()
	if picture.load_svg_from_string(svg, raster_scale) != OK:
		return null
	var texture := ImageTexture.create_from_image(picture)
	_icon_cache[cache_key] = texture
	return texture

static func icon_asset_path(letter: String) -> String:
	return str(_icon_overrides.get(letter.to_upper(), ""))

static func codebook_item(letter: String) -> Dictionary:
	for entry: Dictionary in load_catalog().get("codebook", []):
		if str(entry.letter) == letter.to_upper():
			return entry
	return {}

static func animation_events(entry: Dictionary, frame_positions: Array, allowed_positions: Array, support_level: int) -> Array:
	# Presentation events are derived, never written into the source curriculum.
	var result: Array = []
	var allowed: Array = allowed_positions.map(func(value: Variant): return int(value))
	var word := str(entry.get("spelling_display", ""))
	var special := {
		"hello":["hat_greet","egg_greet","lantern_welcome","lantern_pass","owl_greet"],
		"nose":["nest_release","nose_lift","sneeze_star","shell_catch"],
		"book":["boat_book","book_open","book_page","kite_book"],
		"football":["ball_kick","ball_chest","ball_pass","train_ball","boat_ball","apple_kick","goal_near","goal_far"]
	}
	for raw_position: Variant in frame_positions:
		var position := int(raw_position)
		if not allowed.has(position):
			continue
		var step: Dictionary = entry.get("steps", [])[position-1]
		var action := str(step.get("action", ""))
		var kind := _action_kind(action)
		var caption := "%d. %s：%s" % [position, str(step.get("anchor_zh", "")), action]
		if support_level == 3:
			kind = "known_position"
			caption = "第 %d 格是已经出现的%s；空着的格子留给你想。" % [position, str(step.get("anchor_zh", ""))]
		elif support_level == 5 and special.has(word):
			kind = str(special[word][position-1])
		var target_position := position+1 if allowed.has(position+1) else 0
		result.append({"event_id":"%s/animation-%d" % [str(entry.get("story_id", "")),position],
			"actor_position":position,"target_position":target_position,"action_kind":kind,
			"caption":caption,"source_action":action if support_level != 3 else "",
			"duration":2.4 if kind in ["sneeze_star","book_open","book_page","ball_chest"] else 2.0,
			"specialized":support_level == 5 and special.has(word),"meaning_label":str(entry.get("meaning_zh", ""))})
	return result

static func _action_kind(action: String) -> String:
	var groups := [
		["light",["照","点亮","发亮","星光"]], ["open",["翻","展开","打开","掀","开口"]],
		["roll",["滚","转"]], ["fly",["飞","飘","吹"]], ["tap",["敲","拍","啄"]],
		["catch",["接","托","捧"]], ["lift",["抬","举","提","挂"]],
		["transport",["运","载","推","递","送","带","拉"]], ["mark",["画","写","印","盖"]],
		["greet",["说","问","读","挥","点头"]], ["place",["放","摆","坐","停","站"]],
		["travel",["进入","跳","跨","跑","走"]]
	]
	for group: Array in groups:
		for keyword: String in group[1]:
			if action.contains(keyword):
				return str(group[0])
	return "present"
