extends SceneTree
## V5 Full-Island Semantic Calibration & True Memory Palace Verification Suite.
## Verifies:
##   1. All 210 fixed 3D scene objects have unique, object-grounded English & valid palace links
##   2. `门厅随身篮` teaches `basket / bag` (never `Come in, please.`) + `立体书记词` button
##   3. `科学教室 · 磁铁实验台` teaches `magnet / paperclips` (never `Look at the plant.`)
##   4. `PopupBookTheater` renders real spatial loci, vivid peg-complete fairy-tale beats (zero `→`),
##      authentic usage sentences (zero `Let's remember`), and spoiler-safe H3 `【？神秘精灵】` masking.

const HomeCatalog = preload("res://scripts/home_catalog.gd")
const CardContent = preload("res://ui/memory_card_content.gd")
const StoryContent = preload("res://ui/memory_story_content.gd")
const Theater = preload("res://theater/popup_book_theater.gd")

var _checks := 0
var _failures: Array[String] = []
var _prod_hash := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error("FAIL: " + label)

func _all_text(node: Node) -> String:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return ""
	var out := ""
	if node is Label or node is Button:
		out += str(node.text) + "\n"
	for c: Node in node.get_children():
		out += _all_text(c)
	return out

func _file_hash(p: String) -> String:
	return FileAccess.get_sha256(p) if FileAccess.file_exists(p) else ""

func _run() -> void:
	_prod_hash = _file_hash("user://island-save-v1.json")
	root.size = Vector2i(1440, 900)

	# 1. Verify all 40 Home anchors + 170 Landmark/School anchors via CardContent.build()
	var total_cards := 0
	for room_entry: Dictionary in HomeCatalog.all().get("rooms", []):
		var room_phrases: Dictionary = {}
		for anchor: Dictionary in room_entry.get("anchors", []):
			var built: Dictionary = CardContent.build(room_entry, anchor)
			total_cards += 1
			var eng := str(built.get("english", ""))
			var obj_en := str(built.get("object_en", ""))
			var p_eid := str(built.get("palace_entry_id", ""))
			_check("home_non_empty_%s_%d" % [str(room_entry.room_id), int(anchor.order)], not eng.is_empty() and not obj_en.is_empty() and not p_eid.is_empty())
			_check("home_unique_in_room_%s_%d" % [str(room_entry.room_id), int(anchor.order)], not room_phrases.has(eng))
			room_phrases[eng] = true
			if str(room_entry.room_id) == "home" and int(anchor.order) == 1:
				_check("living_room_basket_teaches_basket_bag", obj_en == "basket / bag" and eng.to_lower().contains("basket") and not eng.to_lower().contains("come in"))

	var li_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/landmark_interiors.json"))
	for lm: Dictionary in li_raw.get("landmarks", []):
		var rid := str(lm.get("room_id", ""))
		if not rid.is_empty() and not HomeCatalog.ROOMS.has(rid) and lm.has("anchors"):
			var seen_lm: Dictionary = {}
			for anchor: Dictionary in lm.get("anchors", []):
				var a_copy := anchor.duplicate(true)
				a_copy["room_id"] = rid
				var built: Dictionary = CardContent.build(lm, a_copy)
				total_cards += 1
				var eng := str(built.get("english", ""))
				_check("lm_unique_%s_%s" % [rid, str(anchor.get("label", ""))], not eng.is_empty() and not seen_lm.has(eng))
				seen_lm[eng] = true
		for area_v: Variant in lm.get("areas", []):
			if area_v is Dictionary:
				var area: Dictionary = area_v
				var arid := str(area.get("room_id", ""))
				if not arid.is_empty() and not HomeCatalog.ROOMS.has(arid) and area.has("anchors"):
					var seen_ar: Dictionary = {}
					for anchor: Dictionary in area.get("anchors", []):
						var a_copy := anchor.duplicate(true)
						a_copy["room_id"] = arid
						var built: Dictionary = CardContent.build(area, a_copy)
						total_cards += 1
						var eng := str(built.get("english", ""))
						_check("school_unique_%s_%s" % [arid, str(anchor.get("label", ""))], not eng.is_empty() and not seen_ar.has(eng))
						seen_ar[eng] = true
						if arid == "science_room" and int(anchor.get("order", 0)) == 4:
							_check("science_magnet_teaches_magnet", str(built.get("object_en", "")).contains("magnet") and eng.to_lower().contains("magnet") and not eng.to_lower().contains("plant"))

	_check("all_210_cards_calibrated", total_cards == 210)

	# 2. Verify PopupBookTheater with `amazing` (`occ` lookup via StoryContent)
	var host := Control.new()
	host.position = Vector2(80, 50)
	host.size = Vector2(1280, 800)
	root.add_child(host)

	var amazing_entry: Dictionary = {}
	for hit: Dictionary in StoryContent.list_entries("", "", "amazing"):
		if str(hit.get("spelling_display", "")) == "amazing":
			amazing_entry = StoryContent.get_entry(str(hit.entry_id))
			break
	_check("found_amazing_entry", not amazing_entry.is_empty())

	var theater := Theater.new()
	host.add_child(theater)
	theater.setup(amazing_entry, {"invocation_id": "v5-test/amazing", "attempt_id": "att-1", "support_level": 5})
	await process_frame
	await process_frame

	var t_beat1 := _all_text(theater)
	_check("amazing_palace_locus_shown", t_beat1.contains("记忆宫殿桩点：") and t_beat1.contains("木琴海边舞台"))
	_check("amazing_beat1_all_4_pegs_present", t_beat1.contains("红苹果A】") and t_beat1.contains("红蘑菇M】") and t_beat1.contains("小斑马Z】"))
	_check("amazing_beat1_zero_arrows", not t_beat1.contains("→"))
	_check("amazing_authentic_example", t_beat1.contains("amazing magic show") and not t_beat1.contains("Let's remember"))

	theater.navigate_beat(1)
	await process_frame
	var t_beat2 := _all_text(theater)
	_check("amazing_beat2_includes_nest_N", t_beat2.contains("冰淇淋I】") and t_beat2.contains("小鸟巢N】") and t_beat2.contains("地球仪G】"))
	_check("amazing_climax_shown_on_final_beat", t_beat2.contains("词义高潮定格："))

	# Test H3 Gap Masking (`小提示`) on Beat 1 (`A-M-A-Z`: pos 1 & 3 revealed, pos 2 & 4 masked!)
	theater.navigate_beat(-1)
	theater._on_gentle_hint()
	await process_frame
	var t_gap := _all_text(theater)
	_check("h3_masks_hidden_pegs_safely", t_gap.contains("【？神秘精灵】") and not t_gap.contains("红蘑菇M】") and not t_gap.contains("小斑马Z】") and not t_gap.to_lower().contains("amazing"))

	# Test Practice Mode spatial recall cue + exact solve
	theater.start_practice()
	await process_frame
	var t_prac := _all_text(theater)
	_check("practice_shows_spatial_locus_cue", t_prac.contains("空间定桩回想：") and not t_prac.to_lower().contains("amazing"))
	theater.submit_response("amazing")
	await process_frame
	_check("practice_solve_succeeds", theater.first_response != null and bool(theater.first_response.get("correct", false)))

	_check("production_save_untouched", _file_hash("user://island-save-v1.json") == _prod_hash)

	host.queue_free()
	await process_frame
	print("V5_WORLD_AND_PALACE checks=%d failures=%d" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
