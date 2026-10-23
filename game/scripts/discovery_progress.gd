extends RefCounted
## Keepsake designs never create learning facts. Eligibility is derived from actual experiences.

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DISTRICTS := {
	"morning_village":"ABCDEF", "craft_street":"GHIJK", "woodland_village":"LMNOP",
	"hill_academy_district":"QRSTU", "bay_travel_district":"VWXYZ"}
const DISTRICT_NAMES := {"morning_village":"晨光村", "craft_street":"巧手街", "woodland_village":"林间村", "hill_academy_district":"山丘学园", "bay_travel_district":"海湾远行区"}
const THEMES: Array[String] = ["sunrise", "meadow", "sea"]
const LAYOUTS: Array[String] = ["portrait", "postcard"]
const TYPES: Array[String] = ["card", "page"]

static func fresh() -> Dictionary:
	return {"schema_version":1, "cards":{}, "pages":{}, "drafts":{}, "display":{"card":"", "page":""}}

static func eligible_letters(journey: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for letter: String in LETTERS:
		if journey.get("letters",{}).get(letter,{}).get("experienced",false) == true:
			result.append(letter)
	return result

static func eligible_districts(journey: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var letters := eligible_letters(journey)
	for id: String in DISTRICTS:
		var complete := true
		for letter: String in str(DISTRICTS[id]):
			complete = complete and letters.has(letter)
		if complete: result.append(id)
	return result

static func district_for_letter(letter: String) -> String:
	for id: String in DISTRICTS:
		if letter.length() == 1 and str(DISTRICTS[id]).contains(letter): return id
	return ""

static func eligible(journey: Dictionary, item_type: Variant, item_id: Variant) -> bool:
	if not item_type is String or not item_id is String: return false
	if item_type == "card": return eligible_letters(journey).has(item_id)
	if item_type == "page": return eligible_districts(journey).has(item_id)
	return false

static func item_key(item_type: String, item_id: String) -> String:
	return item_type + "/" + item_id

static func default_design(item_type: String, item_id: String) -> Dictionary:
	return {"image_letter":item_id if item_type == "card" else str(DISTRICTS.get(item_id,"A"))[0], "theme":"sunrise", "layout":"portrait" if item_type == "card" else "postcard"}

static func designs(state: Dictionary, item_type: String) -> Dictionary:
	return state.cards if item_type == "card" else state.pages

static func apply(journey: Dictionary, event: Dictionary, now: float) -> Dictionary:
	if not _time(now): return _fail("还没记好这次时间，请再试一下。")
	var item_type: Variant = event.get("item_type")
	var item_id: Variant = event.get("item_id")
	if not eligible(journey,item_type,item_id): return _fail("先亲自看看这个字母的发现，再把它带回家。")
	var state: Dictionary = journey.p2.discovery
	var key := item_key(item_type,item_id)
	var saved := designs(state,item_type)
	var kind := str(event.get("kind",""))
	if kind == "discovery_begin":
		if state.drafts.has(key): return _ok(false)
		var design: Dictionary = saved[item_id].design.duplicate(true) if saved.has(item_id) else default_design(item_type,item_id)
		state.drafts[key] = {"item_type":item_type,"item_id":item_id,"design":design,"display":state.display[item_type] == item_id}
		return _ok()
	if kind == "discovery_cancel":
		if not state.drafts.has(key): return _ok(false)
		state.drafts.erase(key)
		return _ok()
	if kind == "discovery_confirm" and not state.drafts.has(key) and saved.has(item_id): return _ok(false)
	if not state.drafts.has(key): return _fail("先打开这张发现，再选一个喜欢的样子。")
	var draft: Dictionary = state.drafts[key]
	match kind:
		"discovery_image":
			var image: Variant = event.get("image_letter")
			if not _valid_image(image,item_type,item_id,journey): return _fail("选这一街区里真正发现过的字母图吧。")
			if draft.design.image_letter == image: return _ok(false)
			draft.design.image_letter = image
		"discovery_theme":
			if not event.get("theme") is String or event.theme not in THEMES: return _fail("请选择晨光、草地或海边背景。")
			if draft.design.theme == event.theme: return _ok(false)
			draft.design.theme = event.theme
		"discovery_layout":
			if not event.get("layout") is String or event.layout not in LAYOUTS: return _fail("请选择大图或明信片排法。")
			if draft.design.layout == event.layout: return _ok(false)
			draft.design.layout = event.layout
		"discovery_display":
			if not event.get("display") is bool: return _fail("选好收进册里，或带回家展示。")
			if draft.display == event.display: return _ok(false)
			draft.display = event.display
		"discovery_confirm":
			if not saved.has(item_id):
				saved[item_id] = {"design":draft.design.duplicate(true),"revision":1,"confirmed_at":now}
			elif saved[item_id].design != draft.design:
				if int(saved[item_id].revision) >= 1_000_000: return _fail("这次样式暂时无法保存。")
				saved[item_id].design = draft.design.duplicate(true)
				saved[item_id].revision += 1
				saved[item_id].confirmed_at = now
			if draft.display: state.display[item_type] = item_id
			elif state.display[item_type] == item_id: state.display[item_type] = ""
			state.drafts.erase(key)
		_:
			return _fail("这个发现册动作还没有准备好。")
	return _ok()

static func normalize(value: Variant, journey: Dictionary) -> Dictionary:
	if value == null: return {"ok":true,"value":fresh()}
	if not value is Dictionary or value.size() != 5 or value.get("schema_version") != 1: return {"ok":false}
	var result := fresh()
	for item_type: String in TYPES:
		var field := "cards" if item_type == "card" else "pages"
		if not value.get(field) is Dictionary or value[field].size() > (26 if item_type == "card" else 5): return {"ok":false}
		for item_id: Variant in value[field]:
			if not eligible(journey,item_type,item_id): return {"ok":false}
			var record: Variant = value[field][item_id]
			if not record is Dictionary or record.size() != 3 or not _valid_design(record.get("design"),item_type,item_id,journey): return {"ok":false}
			if not _integer(record.get("revision"),1,1_000_000) or not _time(record.get("confirmed_at")): return {"ok":false}
			result[field][item_id] = {"design":record.design.duplicate(true),"revision":int(record.revision),"confirmed_at":float(record.confirmed_at)}
	if not value.get("display") is Dictionary or value.display.size() != 2: return {"ok":false}
	for item_type: String in TYPES:
		var displayed: Variant = value.display.get(item_type)
		if not displayed is String or (not displayed.is_empty() and not designs(result,item_type).has(displayed)): return {"ok":false}
		result.display[item_type] = displayed
	if not value.get("drafts") is Dictionary or value.drafts.size() > 31: return {"ok":false}
	for key: Variant in value.drafts:
		var draft: Variant = value.drafts[key]
		if not key is String or not draft is Dictionary or draft.size() != 4: return {"ok":false}
		if not eligible(journey,draft.get("item_type"),draft.get("item_id")) or not draft.get("display") is bool: return {"ok":false}
		if key != item_key(draft.item_type,draft.item_id) or not _valid_design(draft.get("design"),draft.item_type,draft.item_id,journey): return {"ok":false}
		result.drafts[key] = draft.duplicate(true)
	return {"ok":true,"value":result}

static func _valid_image(value: Variant, item_type: String, item_id: String, journey: Dictionary) -> bool:
	if not value is String or value.length() != 1 or not eligible_letters(journey).has(value): return false
	return value == item_id if item_type == "card" else str(DISTRICTS.get(item_id,"")).contains(value)

static func _valid_design(value: Variant, item_type: String, item_id: String, journey: Dictionary) -> bool:
	return value is Dictionary and value.size() == 3 and value.get("theme") is String and value.theme in THEMES and value.get("layout") is String and value.layout in LAYOUTS and _valid_image(value.get("image_letter"),item_type,item_id,journey)

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 32_503_680_000.0

static func _ok(changed: bool = true) -> Dictionary:
	return {"ok":true,"changed":changed}

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
