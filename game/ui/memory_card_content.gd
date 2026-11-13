extends RefCounted
## Display text for object cards. Exact textbook sources stay with their anchors.

static var _translations: Dictionary = {}

static func build(plan: Dictionary, anchor: Dictionary) -> Dictionary:
	if _translations.is_empty():
		_translations = JSON.parse_string(FileAccess.get_file_as_string("res://data/memory_card_hints.json"))
	var source: Dictionary = anchor.get("source", {})
	var lines: PackedStringArray = []
	if not str(source.get("text", "")).is_empty():
		lines.append(str(source.text))
	else:
		for phrase: String in plan.get("english_focus", []).slice(0, 2):
			lines.append(phrase)
	var hints: PackedStringArray = []
	for phrase: String in lines:
		if _translations.has(phrase): hints.append(str(_translations[phrase]))
	var activity := str(anchor.get("activity", ""))
	if not activity.is_empty(): hints.append(activity)
	var attribution := "字母岛原创情境 · " + str(plan.get("name", "小岛生活"))
	if not source.is_empty():
		var unit := str(source.get("unit_id", "")).replace("unit-", "Unit ")
		attribution = "%s · %s %s · 第 %d 页" % [str(source.get("book_title", "英语")), unit, str(source.get("unit_title", "")), int(source.get("printed_page", 0))]
	return {"english":"\n".join(lines), "hint":"\n".join(hints), "source":attribution, "audio":str(source.get("audio", ""))}
