extends Node
## Local progress and inventory. Every successful mutation is saved before it is announced.

signal changed
signal notice(message: String)

const SAVE_VERSION: int = 1
const JOURNEY = preload("res://scripts/journey_progress.gd")
const P2 = preload("res://scripts/p2_progress.gd")
const HOME = preload("res://scripts/home_catalog.gd")
const DECORATION_PRICES: Dictionary = {"flower_box": 25, "picnic": 35, "lamp": 45}
const OUTFITS: Array[String] = ["yellow", "pink", "blue"]
const UNIT_QUESTIONS: Dictionary = {
	1: ["u1_greeting", "u1_morning", "u1_goodbye"],
	2: ["u2_name", "u2_intro", "u2_polite"],
	3: ["u3_age", "u3_nine", "u3_birthday"],
}

var save_path: String = "user://island-save-v1.json"
var data: Dictionary = _default_state()
var _active_question: String = ""
var _active_assisted: bool = false


func _default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": 30,
		"apples": 0,
		"cakes": 0,
		"day": 1,
		"unit": 1,
		"harvested": 0,
		"quests": {"greet_done": false, "delivery_done": false},
		"decorations_owned": {"flower_box": false, "picnic": false, "lamp": false},
		"decorations_placed": {"flower_box": false, "picnic": false, "lamp": false},
		"outfit": "yellow",
		"completed_units": {"1": false, "2": false, "3": false},
		"learning": {},
		"life": {"discoveries": {}, "activities": {"music":false,"art":false,"science":false,"football":false}, "scores":{"football":0}, "artwork":[], "home_tasks":{}},
		"preferences": {"voice":true,"effects":true,"reduced_motion":false,"fixed_day":false},
		"journey": JOURNEY.fresh(),
	}


func snapshot() -> Dictionary:
	return data.duplicate(true)


func journey_snapshot() -> Dictionary:
	return JOURNEY.summary(data["journey"])


func journey_orchard_snapshot() -> Dictionary:
	return data.journey.experiences.orchard_pick.duplicate(true)


func journey_p2_event(event: Dictionary) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, P2.apply(data.journey,event,Time.get_unix_time_from_system()))


func journey_orchard_commit(expected_stage: String, next_stage: String, round_id: String, mode: String = "independent_action") -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.commit_orchard(data.journey, expected_stage, next_stage, round_id, mode))


func journey_select_book(book_id: String) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.select_book(data.journey, book_id))


func journey_complete_home_step(step_id: String) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.complete_home_step(data.journey, step_id))


func journey_record_letter(letter: String, room_id: String, fact: String, mode: String = "independent_action") -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.record_letter(data.journey, letter, room_id, fact, mode))


func journey_complete_u1_step(step_id: String, details: Dictionary = {}) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.complete_u1_step(data.journey, step_id, details, Time.get_unix_time_from_system()))


func journey_begin_memory(entry: Dictionary, context: Dictionary = {}) -> Dictionary:
	var before: Dictionary = snapshot()
	var result: Dictionary = JOURNEY.begin_memory(data.journey, entry, context, int(data.day), Time.get_unix_time_from_system())
	if not result.ok:
		data = before
		notice.emit(result.get("message", "词故事暂时无法打开。"))
		return result
	if result.get("changed", true) and not _commit(before):
		return {"ok": false, "status": "save_failed", "message": "学习记录尚未保存，请重试。"}
	return result


func journey_record_memory_cue(invocation_id: String, cue: Dictionary) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.record_cue(data.journey, invocation_id, cue, Time.get_unix_time_from_system()))


func journey_record_memory_response(invocation_id: String, response: Dictionary) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.record_response(data.journey, invocation_id, response, Time.get_unix_time_from_system()))


func journey_update_memory(invocation_id: String, progress: Dictionary) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.update_memory(data.journey, invocation_id, progress, Time.get_unix_time_from_system()))


func journey_close_memory(invocation_id: String, result: String) -> bool:
	var before: Dictionary = snapshot()
	return _journey_commit(before, JOURNEY.close_memory(data.journey, invocation_id, result, Time.get_unix_time_from_system()))


func _journey_commit(before: Dictionary, result: Dictionary) -> bool:
	if not result.get("ok", false):
		data = before
		return _reject(result.get("message", "进度尚未记录，请接着完成当前步骤。"))
	if not result.get("changed", true):
		return true
	return _commit(before)


func load_state() -> void:
	_active_question = ""
	_active_assisted = false
	var main_result: Dictionary = _read_valid_file(save_path)
	if main_result["ok"]:
		data = main_result["state"]
		changed.emit()
		return
	var backup_result: Dictionary = _read_valid_file(save_path + ".bak")
	if backup_result["ok"]:
		data = backup_result["state"]
		# Keep the known-good backup intact while replacing the damaged primary file.
		var absolute_path: String = ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(save_path):
			_preserve_corrupt_file(absolute_path)
		var recovery_error: Error = DirAccess.copy_absolute(absolute_path + ".bak", absolute_path)
		if recovery_error == OK:
			notice.emit("已从备份恢复小岛存档。")
		else:
			notice.emit("已读取备份，暂时无法修复存档文件。")
	else:
		data = _default_state()
		if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
			notice.emit("存档无法读取，已载入初始小岛；原文件会保留。")
	changed.emit()


func save_state() -> bool:
	var validation: Dictionary = _normalize_state(data)
	if not validation["ok"]:
		notice.emit("进度数据异常，未覆盖已有存档。")
		return false
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		notice.emit("无法创建存档目录，请检查磁盘权限。")
		return false
	var temp_path: String = absolute_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		notice.emit("无法写入存档，请检查磁盘空间。")
		return false
	file.store_string(JSON.stringify(validation["state"], "\t", true, true))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		notice.emit("存档写入失败，原有进度已保留。")
		return false
	var moved_original: bool = false
	if FileAccess.file_exists(absolute_path):
		var previous: Dictionary = _read_valid_file(absolute_path)
		if previous["ok"]:
			if FileAccess.file_exists(absolute_path + ".bak"):
				if DirAccess.remove_absolute(absolute_path + ".bak") != OK:
					notice.emit("无法更新存档备份，原有进度已保留。")
					return false
			if DirAccess.rename_absolute(absolute_path, absolute_path + ".bak") != OK:
				notice.emit("无法备份存档，原有进度已保留。")
				return false
			moved_original = true
		elif not _preserve_corrupt_file(absolute_path):
			notice.emit("无法保留损坏的存档，未写入新进度。")
			return false
	if DirAccess.rename_absolute(temp_path, absolute_path) != OK:
		if moved_original:
			DirAccess.copy_absolute(absolute_path + ".bak", absolute_path)
		notice.emit("无法完成存档，原有进度已保留。")
		return false
	# A first save also gets a usable backup.
	if not FileAccess.file_exists(absolute_path + ".bak"):
		DirAccess.copy_absolute(absolute_path, absolute_path + ".bak")
	data = validation["state"]
	return true


func collect_apple() -> bool:
	if int(data["harvested"]) >= 3:
		return _reject("今天的苹果已采完，回家休息后再来吧。")
	var before: Dictionary = snapshot()
	data["apples"] += 1
	data["harvested"] += 1
	return _commit(before, "获得 1 个苹果。")


func mark_greeted() -> bool:
	if data["quests"]["greet_done"]:
		return _reject("已经和邻居打过招呼啦。")
	var before: Dictionary = snapshot()
	data["quests"]["greet_done"] = true
	data["coins"] += 5
	return _commit(before, "认识新朋友！获得 5 枚叶币。")


func deliver_apples() -> bool:
	if not data["quests"]["greet_done"]:
		return _reject("先去和邻居打个招呼吧。")
	if data["quests"]["delivery_done"]:
		return _reject("苹果委托已经完成，可以继续制作蛋糕。")
	if int(data["apples"]) < 3:
		return _reject("这份委托需要 3 个苹果。")
	var before: Dictionary = snapshot()
	data["apples"] -= 3
	data["coins"] += 20
	data["cakes"] += 1
	data["quests"]["delivery_done"] = true
	return _commit(before, "委托完成！获得 20 枚叶币和 1 个苹果蛋糕。")


func craft_cake() -> bool:
	if not data["quests"]["delivery_done"]:
		return _reject("先完成邻居的苹果委托，学习蛋糕配方。")
	if int(data["apples"]) < 3:
		return _reject("制作蛋糕需要 3 个苹果。")
	var before: Dictionary = snapshot()
	data["apples"] -= 3
	data["cakes"] += 1
	return _commit(before, "用 3 个苹果制作了 1 个蛋糕。")


func sell_cake() -> bool:
	if int(data["cakes"]) < 1:
		return _reject("背包里还没有苹果蛋糕。")
	var before: Dictionary = snapshot()
	data["cakes"] -= 1
	data["coins"] += 15
	return _commit(before, "卖出 1 个苹果蛋糕，获得 15 枚叶币。")


func buy_decoration(id: String, place_now: bool = false) -> bool:
	if not DECORATION_PRICES.has(id):
		return _reject("暂时没有这件装饰。")
	if data["decorations_owned"][id]:
		return _reject("已经拥有这件装饰，可以在家园布置中摆放。")
	var price: int = int(DECORATION_PRICES[id])
	if int(data["coins"]) < price:
		return _reject("叶币不足，完成委托和学习可以获得叶币。")
	var before: Dictionary = snapshot()
	data["coins"] -= price
	data["decorations_owned"][id] = true
	if place_now:
		data["decorations_placed"][id] = true
	return _commit(before, "购买和布置已保存。" if place_now else "购买成功！在家园布置中摆放它吧。")


func place_decoration(id: String, enabled: bool) -> bool:
	if not DECORATION_PRICES.has(id) or not data["decorations_owned"].get(id, false):
		return _reject("需要先拥有这件装饰。")
	if data["decorations_placed"][id] == enabled:
		return true
	var before: Dictionary = snapshot()
	data["decorations_placed"][id] = enabled
	return _commit(before, "家园布置已保存。")


func set_outfit(id: String) -> bool:
	if not OUTFITS.has(id):
		return _reject("暂时没有这套衣服。")
	if data["outfit"] == id:
		return true
	var before: Dictionary = snapshot()
	data["outfit"] = id
	return _commit(before, "新衣服已换好。")


func next_day() -> bool:
	var before: Dictionary = snapshot()
	data["day"] += 1
	data["harvested"] = 0
	return _commit(before, "新的一天开始了，果园的苹果成熟啦。")


func discover(room_id: String, sequence: int) -> bool:
	var key := "%s/memory_%02d" % [room_id,sequence]
	if not _valid_discovery(key):
		return false
	if data.life.discoveries.has(key):
		return true
	var before := snapshot()
	data.life.discoveries[key] = true
	return _commit(before)


func complete_activity(id: String, score: int = 0) -> bool:
	if not data.life.activities.has(id) or score<0 or score>5:
		return false
	var before := snapshot()
	var first := not bool(data.life.activities[id])
	data.life.activities[id] = true
	if id == "football":
		data.life.scores.football = maxi(int(data.life.scores.football),score)
	if first:
		data.coins += 8
	return _commit(before,"新的小岛回忆！首次体验获得 8 枚叶币。" if first else "这次体验已收入回忆册。")


func save_artwork(strokes: Array) -> bool:
	var cleaned := _clean_artwork(strokes)
	if not cleaned.ok:
		return _reject("画纸内容无法保存，请先撤销一些笔画。")
	var before := snapshot()
	data.life.artwork = cleaned.strokes
	if not cleaned.strokes.is_empty() and not data.life.activities.art:
		data.life.activities.art = true
		data.coins += 8
	return _commit(before,"明信片已保存在回忆册。")


func set_preference(id: String, enabled: bool) -> bool:
	if not data.preferences.has(id):
		return false
	var before := snapshot()
	data.preferences[id] = enabled
	return _commit(before)


func _valid_discovery(key: String) -> bool:
	var parts := key.split("/")
	if parts.size()!=2 or not parts[1] in ["memory_01","memory_02","memory_03","memory_04","memory_05"]:
		return false
	var rooms := ["home","school","classroom","canteen","playground","music_room","art_room","science_room","football_field"]
	if parts[0] in rooms or parts[0] in HOME.ROOMS:
		return true
	return parts[0].begins_with("landmark_") and parts[0].length()==10 and parts[0].right(1) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


func complete_home_task(id: String, room_id: String) -> bool:
	if not HOME.valid_task(id, room_id): return false
	if bool(data.life.home_tasks.get(id, false)): return true
	var before := snapshot()
	data.life.home_tasks[id] = true
	return _commit(before, "这件生活小事已经留在家里的日程板上。")


func _clean_artwork(value: Variant) -> Dictionary:
	if not value is Array or value.size()>200:
		return {"ok":false}
	var strokes: Array = []
	var total := 0
	for stroke: Variant in value:
		if not stroke is Dictionary or not _integer_between(stroke.get("color",-1),0,4) or not stroke.get("points") is Array:
			return {"ok":false}
		var points: Array = []
		for point: Variant in stroke.points:
			if not point is Array or point.size()!=2:
				return {"ok":false}
			for coordinate: Variant in point:
				if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate)<0 or float(coordinate)>1:
					return {"ok":false}
			points.append([float(point[0]),float(point[1])])
			total += 1
			if total>4000:
				return {"ok":false}
		if not points.is_empty():
			strokes.append({"color":int(stroke.color),"points":points})
	return {"ok":true,"strokes":strokes}


func begin_question(id: String) -> void:
	if not _known_question(id):
		notice.emit("学习题目不存在。")
		return
	_active_question = id
	_active_assisted = false
	exposed(id)


func exposed(id: String) -> void:
	if not _known_question(id):
		return
	var before: Dictionary = snapshot()
	var record: Dictionary = _ensure_record(id)
	record["exposed"] += 1
	record["last_seen"] = int(Time.get_unix_time_from_system())
	_commit(before)


func use_hint(id: String) -> void:
	if not _known_question(id):
		return
	if _active_question != id:
		begin_question(id)
	_active_assisted = true


func record_answer(id: String, correct: bool, assisted: bool) -> void:
	if not _known_question(id):
		notice.emit("学习题目不存在，未记录答案。")
		return
	if _active_question != id:
		begin_question(id)
	var before: Dictionary = snapshot()
	var record: Dictionary = _ensure_record(id)
	record["attempts"] += 1
	record["last_seen"] = int(Time.get_unix_time_from_system())
	if correct:
		if assisted or _active_assisted:
			record["assisted"] += 1
		else:
			record["independent"] += 1
	else:
		# Correcting a wrong choice in the same attempt is useful practice, not independent mastery.
		_active_assisted = true
	_commit(before)


func finish_unit(unit_id: int) -> bool:
	if not UNIT_QUESTIONS.has(unit_id) or unit_id > int(data["unit"]):
		return _reject("请按顺序完成已开放的学习单元。")
	if data["completed_units"][str(unit_id)]:
		return _reject("这个单元已经领取过奖励，可以继续复习。")
	for question_id: String in UNIT_QUESTIONS[unit_id]:
		var record: Dictionary = data["learning"].get(question_id, {})
		if int(record.get("independent", 0)) + int(record.get("assisted", 0)) < 1:
			return _reject("先完成本单元的 3 道练习，再领取奖励。")
	var before: Dictionary = snapshot()
	data["completed_units"][str(unit_id)] = true
	data["unit"] = mini(3, unit_id + 1)
	data["coins"] += 15
	return _commit(before, "单元完成！获得 15 枚叶币；提示答对会单独记录。")


func _commit(before: Dictionary, message: String = "") -> bool:
	if not save_state():
		data = before
		return false
	changed.emit()
	if not message.is_empty():
		notice.emit(message)
	return true


func _reject(message: String) -> bool:
	notice.emit(message)
	return false


func _known_question(id: String) -> bool:
	for ids: Array in UNIT_QUESTIONS.values():
		if ids.has(id):
			return true
	return false


func _ensure_record(id: String) -> Dictionary:
	if not data["learning"].has(id):
		data["learning"][id] = {"exposed": 0, "assisted": 0, "independent": 0, "attempts": 0, "last_seen": 0}
	return data["learning"][id]


func _read_valid_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	# Full vocabulary histories are larger than the old nine-question save, but still bounded.
	if file.get_length() > 64_000_000:
		file.close()
		return {"ok": false}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false}
	return _normalize_state(json.data)


func _normalize_state(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false}
	var incoming: Dictionary = value
	var normalized: Dictionary = _default_state()
	# Required fields and exact scalar types prevent silent coercion of damaged data.
	for key: String in normalized.keys():
		if key in ["life","preferences","journey"]:
			continue # Optional additions migrate v0.1-v0.3 saves without changing their identity.
		if not incoming.has(key):
			return {"ok": false}
	if not _integer_between(incoming["version"], 1, 1):
		return {"ok": false}
	for key: String in ["coins", "apples", "cakes"]:
		if not _integer_between(incoming[key], 0, 1_000_000):
			return {"ok": false}
		normalized[key] = int(incoming[key])
	for key: String in ["day", "unit", "harvested"]:
		var minimum: int = 0 if key == "harvested" else 1
		var maximum: int = 1_000_000 if key == "day" else 3
		if not _integer_between(incoming[key], minimum, maximum):
			return {"ok": false}
		normalized[key] = int(incoming[key])
	if not incoming["outfit"] is String or not OUTFITS.has(incoming["outfit"]):
		return {"ok": false}
	normalized["outfit"] = incoming["outfit"]
	for section: String in ["quests", "decorations_owned", "decorations_placed", "completed_units"]:
		if not incoming[section] is Dictionary:
			return {"ok": false}
		var section_data: Dictionary = incoming[section]
		if section_data.size() != normalized[section].size():
			return {"ok": false}
		for key: String in normalized[section].keys():
			if not section_data.has(key) or not section_data[key] is bool:
				return {"ok": false}
			normalized[section][key] = section_data[key]
	if normalized["quests"]["delivery_done"] and not normalized["quests"]["greet_done"]:
		return {"ok": false}
	for key: String in DECORATION_PRICES.keys():
		if normalized["decorations_placed"][key] and not normalized["decorations_owned"][key]:
			return {"ok": false}
	if not incoming["learning"] is Dictionary:
		return {"ok": false}
	var learning: Dictionary = incoming["learning"]
	for raw_id: Variant in learning.keys():
		if not raw_id is String or not _known_question(raw_id):
			return {"ok": false}
		var id: String = raw_id
		if not learning[id] is Dictionary:
			return {"ok": false}
		var source_record: Dictionary = learning[id]
		var clean_record: Dictionary = {}
		if source_record.size() != 5:
			return {"ok": false}
		for key: String in ["exposed", "assisted", "independent", "attempts", "last_seen"]:
			var maximum: int = 32_503_680_000 if key == "last_seen" else 1_000_000
			if not source_record.has(key) or not _integer_between(source_record[key], 0, maximum):
				return {"ok": false}
			clean_record[key] = int(source_record[key])
		if clean_record["assisted"] + clean_record["independent"] > clean_record["attempts"]:
			return {"ok": false}
		normalized["learning"][id] = clean_record
	var completed_count: int = 0
	var saw_unfinished: bool = false
	for unit_id: int in [1, 2, 3]:
		if normalized["completed_units"][str(unit_id)]:
			if saw_unfinished:
				return {"ok": false}
			completed_count += 1
			for id: String in UNIT_QUESTIONS[unit_id]:
				var record: Dictionary = normalized["learning"].get(id, {})
				if int(record.get("assisted", 0)) + int(record.get("independent", 0)) < 1:
					return {"ok": false}
		else:
			saw_unfinished = true
	if normalized["unit"] != mini(3, completed_count + 1):
		return {"ok": false}
	if incoming.has("preferences"):
		if not incoming.preferences is Dictionary:
			return {"ok":false}
		for key: String in normalized.preferences:
			if key == "fixed_day" and not incoming.preferences.has(key):
				continue
			if not incoming.preferences.get(key) is bool:
				return {"ok":false}
			normalized.preferences[key] = incoming.preferences[key]
	if incoming.has("life"):
		if not incoming.life is Dictionary:
			return {"ok":false}
		var life: Dictionary = incoming.life
		if not life.get("discoveries") is Dictionary or life.discoveries.size()>256:
			return {"ok":false}
		for key: Variant in life.discoveries:
			if not key is String or not _valid_discovery(key) or not life.discoveries[key] is bool or not life.discoveries[key]:
				return {"ok":false}
			normalized.life.discoveries[key] = true
		var home_tasks: Variant = life.get("home_tasks", {})
		if not home_tasks is Dictionary or home_tasks.size() > HOME.ROOMS.size():
			return {"ok":false}
		for task_id: Variant in home_tasks:
			if not task_id is String or not HOME.valid_task(task_id) or not home_tasks[task_id] is bool or not home_tasks[task_id]:
				return {"ok":false}
			normalized.life.home_tasks[task_id] = true
		if not life.get("activities") is Dictionary or not life.get("scores") is Dictionary:
			return {"ok":false}
		for id: String in normalized.life.activities:
			if not life.activities.get(id) is bool:
				return {"ok":false}
			normalized.life.activities[id] = life.activities[id]
		if not _integer_between(life.scores.get("football",-1),0,5):
			return {"ok":false}
		normalized.life.scores.football = int(life.scores.football)
		var artwork := _clean_artwork(life.get("artwork"))
		if not artwork.ok:
			return {"ok":false}
		normalized.life.artwork = artwork.strokes
	if incoming.has("journey"):
		var journey_result: Dictionary = JOURNEY.normalize(incoming.journey)
		if not journey_result.ok:
			return {"ok": false}
		normalized.journey = journey_result.value
	else:
		# Legacy discovery/course records remain untouched and grant no invented letter facts.
		normalized.journey = JOURNEY.fresh(true)
	return {"ok": true, "state": normalized}


func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var numeric: float = float(value)
	return is_finite(numeric) and numeric == floor(numeric) and numeric >= minimum and numeric <= maximum


func _preserve_corrupt_file(absolute_path: String) -> bool:
	var preserved_path: String = absolute_path + ".corrupt-" + str(Time.get_ticks_usec())
	return DirAccess.rename_absolute(absolute_path, preserved_path) == OK
