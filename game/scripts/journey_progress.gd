extends RefCounted
## Persisted journey facts. This module never writes files or awards old course currency.

const BOOK_IDS: Array[String] = ["xiangshao-g3-1", "xiangshao-g3-2", "xiangshao-g4-1", "xiangshao-g4-2", "english-grade5-volume1-smartedu-2022", "xiangshao-g5-2", "xiangshao-g6-1", "xiangshao-g6-2"]
const BOOK_UNITS: Array[int] = [10, 10, 10, 10, 10, 12, 10, 9]
const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const LETTER_FACTS: Array[String] = ["visited", "representative_image_presented", "micro_action_feedback_seen", "case_pair_presented", "letter_name_support_offered"]
const MODES: Array[String] = ["independent_action", "hinted_action", "companion_action", "demonstration_viewed"]
const HOME_STEPS: Array[String] = ["H01", "H02", "H03", "H04"]
const U1_STEPS: Array[String] = ["U1-01", "U1-02", "U1-03", "U1-04", "U1-05", "U1-06", "U1-07", "U1-08", "U1-09", "U1-10"]
const PHOTO_RECEIPT: String = "event/xiangshao-g3-1/unit-1/photo"
const CHAPTER_RECEIPT: String = "event/xiangshao-g3-1/unit-1/chapter"
const MAX_SESSIONS: int = 4096
const MAX_CUES: int = 256
const MAX_RESPONSES: int = 128
const DIMENSIONS: Array[String] = ["orthography", "meaning", "listening", "spoken_expression", "written_recognition", "ordered_images", "letter_recognition", "all"]
const P2 = preload("res://scripts/p2_progress.gd")


static func fresh(legacy: bool = false) -> Dictionary:
	var letters: Dictionary = {}
	for letter: String in LETTERS:
		var record: Dictionary = {"experienced": false, "completion_mode": ""}
		for fact: String in LETTER_FACTS:
			record[fact] = false
		letters[letter] = record
	return {"schema_version": 1, "legacy_compatible": legacy, "selected_book_id": BOOK_IDS[0], "home_steps": [], "letters": letters,
		"u1": {"steps": [], "step_details": {}, "photo": {"created": false, "details": {}}, "completed": false},
		"p2":P2.fresh(), "experiences": {"orchard_pick": fresh_orchard()}, "reward_receipts": {}, "memory": {"sequence": 0, "sessions": {}}}


static func fresh_orchard() -> Dictionary:
	return {"stage": "ready", "round_id": "", "completed_once": false, "completion_mode": ""}


static func commit_orchard(journey: Dictionary, expected_stage: String, next_stage: String, round_id: String, mode: String) -> Dictionary:
	if not text_value(round_id, 160, false) or not MODES.has(mode):
		return fail("果园体验的轮次或完成方式无法保存。")
	var transition: String = expected_stage + ">" + next_stage
	if transition not in ["ready>carrying", "carrying>deposited", "deposited>ready"]:
		return fail("先接着完成当前果园动作。")
	var orchard: Dictionary = journey.experiences.orchard_pick
	if orchard.stage == next_stage and orchard.round_id == round_id:
		if next_stage == "carrying":
			var supported_mode: String = MODES[maxi(MODES.find(str(orchard.completion_mode)), MODES.find(mode))]
			if supported_mode != orchard.completion_mode:
				orchard.completion_mode = supported_mode
				return success()
		return success(false)
	if orchard.stage != expected_stage:
		return fail("果园动作已经变化，请恢复已保存的位置。")
	if transition == "deposited>ready":
		if round_id == orchard.round_id:
			return fail("重玩果园体验需要新的轮次。")
	elif not orchard.round_id.is_empty() and orchard.round_id != round_id:
		return fail("这次操作属于另一轮果园体验。")
	orchard.round_id = round_id
	orchard.stage = next_stage
	if next_stage == "ready":
		orchard.completion_mode = ""
	elif next_stage == "carrying":
		orchard.completion_mode = mode
	elif next_stage == "deposited":
		orchard.completed_once = true
		orchard.completion_mode = MODES[maxi(MODES.find(str(orchard.completion_mode)), MODES.find(mode))]
	return success()


static func summary(journey: Dictionary) -> Dictionary:
	var result: Dictionary = journey.duplicate(true)
	var count: int = 0
	var next_letter: String = ""
	for letter: String in LETTERS:
		if journey.letters[letter].experienced:
			count += 1
		elif next_letter.is_empty():
			next_letter = letter
	result["experienced_count"] = count
	result["prologue_completed"] = count == 26
	result["next_letter"] = next_letter
	result["next_home_step"] = HOME_STEPS[journey.home_steps.size()] if journey.home_steps.size() < 4 else ""
	result["next_u1_step"] = U1_STEPS[journey.u1.steps.size()] if journey.u1.steps.size() < U1_STEPS.size() else ""
	result["can_continue_legacy"] = journey.legacy_compatible
	var phase: String = "home"
	var visited: bool = false
	for letter: String in LETTERS:
		visited = visited or journey.letters[letter].visited
	if journey.legacy_compatible and journey.home_steps.is_empty() and not visited and journey.u1.steps.is_empty():
		phase = "legacy_life"
	elif journey.home_steps.size() == 4 or journey.legacy_compatible:
		phase = "prologue"
	if count == 26 or (journey.legacy_compatible and not journey.u1.steps.is_empty()):
		phase = "u1" if journey.selected_book_id == BOOK_IDS[0] else "library_available"
		if journey.selected_book_id == BOOK_IDS[0] and journey.u1.completed:
			phase = "p2_complete" if P2.next_chapter(journey.p2)==0 else "u"+str(P2.next_chapter(journey.p2))
	result["next_chapter"] = P2.next_chapter(journey.p2)
	result["phase"] = phase
	return result


static func select_book(journey: Dictionary, book_id: String) -> Dictionary:
	if not BOOK_IDS.has(book_id):
		return fail("这册教材尚未接入。")
	if journey.selected_book_id == book_id:
		return success(false)
	if not journey.u1.steps.is_empty() and not journey.u1.completed:
		return fail("请先完成当前欢迎事件，再切换起点册次；原有记录会保留。")
	for chapter: Dictionary in journey.p2.chapters.values():
		if not chapter.steps.is_empty() and not chapter.completed:
			return fail("先完成当前邀请或欢迎桌事件，再换教材；原记录会保留。")
	journey.selected_book_id = book_id
	return success()


static func complete_home_step(journey: Dictionary, step_id: String) -> Dictionary:
	if not HOME_STEPS.has(step_id):
		return fail("开场步骤不存在。")
	if journey.home_steps.has(step_id):
		return success(false)
	if journey.home_steps.size() >= 4 or step_id != HOME_STEPS[journey.home_steps.size()]:
		return fail("先接着完成当前开场步骤。")
	journey.home_steps.append(step_id)
	return success()


static func record_letter(journey: Dictionary, letter: String, room_id: String, fact: String, mode: String) -> Dictionary:
	if not journey.letters.has(letter) or room_id != "landmark_" + letter or not LETTER_FACTS.has(fact) or not MODES.has(mode):
		return fail("字母体验的地点或步骤不一致，尚未记录。")
	if journey.home_steps.size() < 4 and not journey.legacy_compatible:
		return fail("先完成家园操作引导，再开始字母小旅程。")
	var record: Dictionary = journey.letters[letter]
	if fact != "visited" and not record.visited:
		return fail("请先抵达这个字母地标。")
	if record[fact]:
		return success(false)
	record[fact] = true
	if fact == "micro_action_feedback_seen":
		record.completion_mode = mode
	var complete: bool = true
	for required: String in LETTER_FACTS:
		complete = complete and bool(record[required])
	record.experienced = complete
	return success()


static func complete_u1_step(journey: Dictionary, step_id: String, details: Dictionary, now: float) -> Dictionary:
	if not U1_STEPS.has(step_id) or journey.selected_book_id != BOOK_IDS[0]:
		return fail("此册完整剧情尚待制作，可先使用词故事库和已有生活活动。")
	if not summary(journey).prologue_completed and not journey.legacy_compatible:
		return fail("先完成二十六处字母体验；可以一直使用示范。")
	if journey.u1.steps.has(step_id):
		return success(false)
	if step_id != U1_STEPS[journey.u1.steps.size()]:
		return fail("先接着完成当前欢迎事件步骤。")
	if not small_metadata(details):
		return fail("当前选择无法安全保存。")
	journey.u1.steps.append(step_id)
	journey.u1.step_details[step_id] = details.duplicate(true)
	if step_id == "U1-08":
		journey.u1.photo = {"created": true, "details": details.duplicate(true)}
		journey.reward_receipts[PHOTO_RECEIPT] = {"step_id": step_id, "created_at_utc": now}
	if step_id == "U1-09":
		journey.u1.completed = true
		journey.reward_receipts[CHAPTER_RECEIPT] = {"step_id": step_id, "created_at_utc": now}
	return success()


static func begin_memory(journey: Dictionary, entry: Dictionary, context: Dictionary, game_day: int, now: float) -> Dictionary:
	for field: String in ["entry_id", "lexeme_id", "sense_id", "content_revision", "codebook_revision"]:
		if not text_value(entry.get(field), 160, false):
			return fail("词故事身份或内容版本缺失。", "content_unavailable")
	if not entry.get("source_unit") is Dictionary or not entry.source_unit.get("unit_ids") is Array:
		return fail("词故事教材定位缺失。", "content_unavailable")
	var book_id: String = str(context.get("book_id", entry.source_unit.get("book_id", "")))
	var units: Array = entry.source_unit.unit_ids
	var unit_id: String = str(context.get("unit_id", units[0] if not units.is_empty() else ""))
	if book_id != entry.source_unit.get("book_id") or not valid_unit(book_id, unit_id) or not units.has(unit_id):
		return fail("这个词条不属于所选教材单元。", "content_unavailable")
	if not text_value(context.get("story_step_id"), 200, false):
		return fail("缺少可恢复的学习步骤。")
	if not entry.get("letter_slots") is Array or entry.letter_slots.size() > 128 or not entry.get("story_beats") is Array or entry.story_beats.is_empty() or entry.story_beats.size() > 64:
		return fail("词故事的字母或分镜内容不可用。", "content_unavailable")
	var beat_ids: Array = []
	for beat: Variant in entry.story_beats:
		if not beat is Dictionary or not text_value(beat.get("beat_id"), 200, false) or beat_ids.has(beat.beat_id):
			return fail("词故事分镜标识不可用。", "content_unavailable")
		beat_ids.append(beat.beat_id)
	var context_key: String = book_id + "/" + unit_id + "/" + context.story_step_id + "/" + entry.entry_id
	for saved: Dictionary in journey.memory.sessions.values():
		if saved.context_key != context_key:
			continue
		for field: String in ["entry_id", "lexeme_id", "sense_id", "content_revision", "codebook_revision"]:
			if saved[field] != entry[field]:
				var unavailable: Dictionary = memory_result(saved, false)
				unavailable.ok = false
				unavailable.status = "content_unavailable"
				unavailable.message = "原学习记录使用另一个内容版本，已保留原进度；请返回生活活动。"
				return unavailable
		return memory_result(saved, false)
	if journey.memory.sessions.size() >= MAX_SESSIONS:
		return fail("学习记录已达到本地容量上限，原记录完整保留。")
	var task_mode: Variant = context.get("task_mode", "story_exposure")
	var target: Variant = context.get("target_dimension", "")
	var stimulus: Variant = context.get("declared_stimulus", "")
	var visible: Variant = context.get("answer_visible_at_start", false)
	if not text_value(task_mode, 100, false) or not text_value(target, 100) or (target != "" and not DIMENSIONS.has(target)) or not stimulus_value(stimulus) or not visible is bool:
		return fail("学习任务条件不完整。")
	journey.memory.sequence += 1
	var id: String = "journey-memory-%06d" % int(journey.memory.sequence)
	var session: Dictionary = {"invocation_id": id, "attempt_id": id + "/attempt-1", "context_key": context_key,
		"source_unit": {"book_id": book_id, "unit_id": unit_id}, "story_step_id": context.story_step_id,
		"task_mode": task_mode, "target_dimension": target, "declared_stimulus": stimulus, "answer_visible_at_start": visible,
		"letter_count": entry.letter_slots.size(), "beat_ids": beat_ids, "current_beat": 1, "seen_beats": [], "exposure_completed": false,
		"max_help_level": 0, "support_level": 5, "view_mode": "story", "draft_response": "", "revealed_gaps": [], "bridge_position": 1, "show_sequence": false, "animation_state": {}, "cue_events": [], "responses": [],
		"first_response": null, "later_response": null, "status": "active", "created_at_utc": now, "updated_at_utc": now, "game_day": game_day}
	for field: String in ["entry_id", "lexeme_id", "sense_id", "content_revision", "codebook_revision"]:
		session[field] = entry[field]
	journey.memory.sessions[id] = session
	return memory_result(session)


static func record_cue(journey: Dictionary, id: String, cue: Dictionary, now: float) -> Dictionary:
	var session: Dictionary = journey.memory.sessions.get(id, {})
	if session.is_empty():
		return fail("这次词故事记录不存在。")
	var clean: Dictionary = clean_cue(cue, session, now)
	if not clean.ok:
		return clean
	var record: Dictionary = clean.value
	for saved: Dictionary in session.cue_events:
		if saved.event_id == record.event_id:
			return success(false) if saved == record else fail("同一提示标识不能覆盖已有线索。")
	if session.cue_events.size() >= MAX_CUES:
		return fail("本次提示记录已满，请保留记录并返回生活。")
	session.cue_events.append(record)
	session.max_help_level = maxi(int(session.max_help_level), int(record.support_level))
	var display_changed: bool = int(session.support_level) != int(record.support_level)
	session.support_level = record.support_level
	# UI delivers the observed cue before its resume snapshot. Keep that first
	# durable write valid on its own; historical cue evidence is never removed.
	var resets_view: bool = str(record.get("display_event", "")) in ["support_selected", "practice_started"]
	if int(record.support_level) != 5 or resets_view:
		session.show_sequence = false
	if resets_view:
		session.revealed_gaps = []
	if display_changed or resets_view:
		session.animation_state = {}
	session.updated_at_utc = now
	return success()


static func record_response(journey: Dictionary, id: String, response: Dictionary, now: float) -> Dictionary:
	var session: Dictionary = journey.memory.sessions.get(id, {})
	if session.is_empty() or not response.get("correct") is bool:
		return fail("没有可记录的实际作答。")
	if not matching_identity(response, session):
		return fail("作答不属于当前学习记录。")
	var response_id: Variant = response.get("response_id", id + "/response-" + str(session.responses.size() + 1))
	var dimension: Variant = response.get("target_dimension", session.target_dimension)
	var mode: Variant = response.get("task_mode", session.task_mode)
	var response_text: Variant = response.get("response_text", "")
	if not text_value(response_id, 240, false) or not text_value(response_text, 2000) or not text_value(mode, 100, false) or not DIMENSIONS.has(dimension):
		return fail("作答条件或文本无法保存。")
	for saved: Dictionary in session.responses:
		if saved.response_id == response_id:
			return success(false) if saved.correct == response.correct and saved.response_text == response_text and saved.target_dimension == dimension and saved.task_mode == mode and saved.practice_is_extra == response.get("practice_is_extra", false) else fail("不能覆盖已经记录的作答。")
	if session.responses.size() >= MAX_RESPONSES:
		return fail("本次练习记录已满，原回应完整保留。")
	var observed: Variant = response.get("observed_at", now)
	var extra: Variant = response.get("practice_is_extra", false)
	if not timestamp_value(observed) or not extra is bool:
		return fail("作答时间或任务要求无法保存。")
	var unassisted: bool = not has_answer_cue(session, dimension)
	var first: bool = session.responses.is_empty()
	var independent_success: bool = first and unassisted and response.correct
	var record: Dictionary = {"response_id": response_id, "invocation_id": id, "attempt_id": session.attempt_id,
		"correct": response.correct, "response_text": response_text, "target_dimension": dimension, "task_mode": mode,
		"practice_is_extra": extra, "observed_at": float(observed), "unassisted_attempt": unassisted,
		"independent_success": independent_success, "retry_after_first_response": not first,
		"result": "not_correct" if not response.correct else ("independent_correct" if independent_success else "supported_correct")}
	session.responses.append(record)
	if first:
		session.first_response = record.duplicate(true)
	else:
		session.later_response = record.duplicate(true)
	session.updated_at_utc = now
	return success()


static func update_memory(journey: Dictionary, id: String, progress: Dictionary, now: float) -> Dictionary:
	var session: Dictionary = journey.memory.sessions.get(id, {})
	if session.is_empty() or not matching_identity(progress, session):
		return fail("无法恢复这次词故事。")
	var beat: Variant = progress.get("current_beat", session.current_beat)
	var seen: Variant = progress.get("seen_beats", session.seen_beats)
	var view: Variant = progress.get("view_mode", session.view_mode)
	var level: Variant = progress.get("support_level", session.support_level)
	var draft: Variant = progress.get("draft_response", session.draft_response)
	var gaps: Variant = progress.get("revealed_gaps", session.get("revealed_gaps", []))
	var bridge: Variant = progress.get("bridge_position", session.get("bridge_position", 1))
	var sequence: Variant = progress.get("show_sequence", session.get("show_sequence", false))
	if not integer_value(beat, 1, maxi(1, session.beat_ids.size())) or not seen is Array or seen.size() > session.beat_ids.size() or not text_value(view, 80, false) or not integer_value(level, 0, 5) or not text_value(draft, 2000):
		return fail("分镜恢复信息不完整。")
	if not letter_positions_value(gaps, session.letter_count) or not integer_value(bridge, 1, maxi(1, session.letter_count)) or not sequence is bool or (sequence and int(level) != 5):
		return fail("提示展开位置无法恢复。")
	var animation: Dictionary = normalize_animation(progress.get("animation_state", session.get("animation_state", {})), session)
	if not animation.ok:
		return fail("故事动作的恢复位置无法保存。")
	for beat_id: Variant in seen:
		if not beat_id is String or not session.beat_ids.has(beat_id):
			return fail("分镜不属于当前内容版本。")
	for beat_id: String in seen:
		if not session.seen_beats.has(beat_id):
			session.seen_beats.append(beat_id)
	session.current_beat = int(beat)
	session.view_mode = view
	session.support_level = int(level)
	session.draft_response = draft
	session.revealed_gaps = gaps.map(func(position: Variant) -> int: return int(position))
	session.bridge_position = int(bridge)
	session.show_sequence = sequence
	session.animation_state = animation.value
	session.exposure_completed = session.seen_beats.size() == session.beat_ids.size()
	# Caller snapshots cannot erase or invent authoritative cue/response history.
	session.updated_at_utc = now
	return success()


static func close_memory(journey: Dictionary, id: String, result: String, now: float) -> Dictionary:
	if not journey.memory.sessions.has(id) or result not in ["paused", "completed", "content_unavailable", "deferred"]:
		return fail("词故事结束状态无法记录。")
	var session: Dictionary = journey.memory.sessions[id]
	# A practice session may finish without watching the story. Its exposure fact stays separate.
	if session.status == result:
		return success(false)
	session.status = result
	session.updated_at_utc = now
	return success()


static func memory_result(session: Dictionary, changed: bool = true) -> Dictionary:
	return {"ok": true, "changed": changed, "status": session.status, "invocation_id": session.invocation_id,
		"attempt_id": session.attempt_id, "resume_state": session.duplicate(true)}


static func has_answer_cue(session: Dictionary, dimension: String) -> bool:
	if session.answer_visible_at_start:
		return true
	for cue: Dictionary in session.cue_events:
		if cue.answer_revealing_dimensions.has("all") or cue.answer_revealing_dimensions.has(dimension):
			return true
	return false


static func matching_identity(payload: Dictionary, session: Dictionary) -> bool:
	for field: String in ["invocation_id", "attempt_id", "entry_id", "content_revision", "codebook_revision"]:
		if payload.has(field) and payload[field] != session[field]:
			return false
	return true


static func clean_cue(cue: Dictionary, session: Dictionary, now: float) -> Dictionary:
	if not matching_identity(cue, session):
		return fail("提示不属于当前学习记录。")
	var level: Variant = cue.get("support_level", -1)
	var positions: Variant = cue.get("revealed_letter_positions", [])
	var dimensions: Variant = cue.get("answer_revealing_dimensions", [])
	var event_id: Variant = cue.get("event_id", session.invocation_id + "/cue-" + str(session.cue_events.size() + 1))
	var shown_at: Variant = cue.get("shown_at", now)
	if not integer_value(level, 0, 5) or not positions is Array or positions.size() > 128 or not dimensions is Array or dimensions.size() > DIMENSIONS.size() or not text_value(event_id, 240, false) or not timestamp_value(shown_at):
		return fail("提示线索格式不完整。")
	var ordered: Array = []
	for position: Variant in positions:
		if not integer_value(position, 1, session.letter_count) or ordered.has(int(position)):
			return fail("提示的字母位置不属于当前词。")
		ordered.append(int(position))
	for dimension: Variant in dimensions:
		if not dimension is String or not DIMENSIONS.has(dimension):
			return fail("提示影响的学习维度未知。")
	if int(level) == 0 and (not ordered.is_empty() or not dimensions.is_empty()):
		return fail("已经揭示答案的提示不能记录为H0。")
	var record: Dictionary = {"event_id": event_id, "invocation_id": session.invocation_id, "attempt_id": session.attempt_id,
		"support_level": int(level), "revealed_letter_positions": ordered, "answer_revealing_dimensions": dimensions.duplicate(), "shown_at": float(shown_at)}
	for field: String in ["support_kind", "asset_or_content_ref", "requested_by"]:
		var value: Variant = cue.get(field, "")
		if not text_value(value, 500):
			return fail("提示来源无法保存。")
		record[field] = value
	for field: String in ["display_event", "audio_role"]:
		if cue.has(field):
			if not text_value(cue[field], 100, false):
				return fail("提示事件说明无法保存。")
			record[field] = cue[field]
	if cue.has("animation_action") or cue.has("animated_letter_position"):
		if not text_value(cue.get("animation_action"), 100, false) or not integer_value(cue.get("animated_letter_position"), 1, session.letter_count):
			return fail("故事动作线索的位置或类型无法保存。")
		var animated_position: int = int(cue.animated_letter_position)
		if not ordered.has(animated_position):
			return fail("已展示的动作形象必须保留它揭示的字母位置。")
		record.animation_action = cue.animation_action
		record.animated_letter_position = animated_position
	if cue.has("displayed_stimulus_dimensions"):
		var stimulus_dimensions: Variant = cue.displayed_stimulus_dimensions
		if not stimulus_dimensions is Array or stimulus_dimensions.size() > DIMENSIONS.size():
			return fail("题干展示维度无法保存。")
		for dimension: Variant in stimulus_dimensions:
			if not dimension is String or not DIMENSIONS.has(dimension):
				return fail("题干展示维度未知。")
		record.displayed_stimulus_dimensions = stimulus_dimensions.duplicate()
	return {"ok": true, "value": record}


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false}
	var source: Dictionary = value
	if not integer_value(source.get("schema_version"), 1, 1) or not source.get("legacy_compatible") is bool or not BOOK_IDS.has(source.get("selected_book_id")):
		return {"ok": false}
	if not prefix_steps(source.get("home_steps"), HOME_STEPS) or not source.get("letters") is Dictionary or source.letters.size() != 26:
		return {"ok": false}
	var result: Dictionary = fresh(source.legacy_compatible)
	result.selected_book_id = source.selected_book_id
	result.home_steps = source.home_steps.duplicate()
	if source.has("experiences"):
		if not source.experiences is Dictionary:
			return {"ok": false}
		if source.experiences.has("orchard_pick"):
			var orchard: Dictionary = normalize_orchard(source.experiences.orchard_pick)
			if not orchard.ok:
				return {"ok": false}
			result.experiences.orchard_pick = orchard.value
	for letter: String in LETTERS:
		if not source.letters.get(letter) is Dictionary:
			return {"ok": false}
		var record: Dictionary = source.letters[letter]
		var complete: bool = true
		for fact: String in LETTER_FACTS:
			if not record.get(fact) is bool:
				return {"ok": false}
			result.letters[letter][fact] = record[fact]
			complete = complete and record[fact]
		if not record.get("experienced") is bool or record.experienced != complete or not text_value(record.get("completion_mode"), 40) or (record.completion_mode != "" and not MODES.has(record.completion_mode)):
			return {"ok": false}
		if record.micro_action_feedback_seen != (record.completion_mode != ""):
			return {"ok": false}
		for fact: String in LETTER_FACTS:
			if fact != "visited" and record[fact] and not record.visited:
				return {"ok": false}
		if record.visited and result.home_steps.size() < 4 and not result.legacy_compatible:
			return {"ok": false}
		result.letters[letter].experienced = complete
		result.letters[letter].completion_mode = record.completion_mode
	if not source.get("u1") is Dictionary or not source.get("reward_receipts") is Dictionary:
		return {"ok": false}
	var u1: Dictionary = source.u1
	if not prefix_steps(u1.get("steps"), U1_STEPS) or not u1.get("step_details") is Dictionary or u1.step_details.size() != u1.steps.size() or not u1.get("completed") is bool or not u1.get("photo") is Dictionary:
		return {"ok": false}
	if u1.completed != u1.steps.has("U1-09") or not u1.photo.get("created") is bool or u1.photo.created != u1.steps.has("U1-08") or not u1.photo.get("details") is Dictionary or not small_metadata(u1.photo.details):
		return {"ok": false}
	if not u1.steps.is_empty() and not summary(result).prologue_completed and not result.legacy_compatible:
		return {"ok": false}
	for step: String in u1.steps:
		if not u1.step_details.get(step) is Dictionary or not small_metadata(u1.step_details[step]):
			return {"ok": false}
	if u1.photo.created and u1.photo.details != u1.step_details["U1-08"]:
		return {"ok": false}
	result.u1 = {"steps": u1.steps.duplicate(), "step_details": u1.step_details.duplicate(true), "photo": u1.photo.duplicate(true), "completed": u1.completed}
	var expected_receipts: Dictionary = {}
	if u1.photo.created:
		expected_receipts[PHOTO_RECEIPT] = "U1-08"
	if u1.completed:
		expected_receipts[CHAPTER_RECEIPT] = "U1-09"
	if source.reward_receipts.size() != expected_receipts.size():
		return {"ok": false}
	for id: String in expected_receipts:
		var receipt: Variant = source.reward_receipts.get(id)
		if not receipt is Dictionary or receipt.get("step_id") != expected_receipts[id] or not timestamp_value(receipt.get("created_at_utc")):
			return {"ok": false}
		result.reward_receipts[id] = {"step_id": receipt.step_id, "created_at_utc": float(receipt.created_at_utc)}
	if not source.get("memory") is Dictionary or not integer_value(source.memory.get("sequence"), 0, 1_000_000) or not source.memory.get("sessions") is Dictionary or source.memory.sessions.size() > MAX_SESSIONS:
		return {"ok": false}
	var contexts: Dictionary = {}
	result.memory.sequence = int(source.memory.sequence)
	for id: Variant in source.memory.sessions:
		if not text_value(id, 160, false):
			return {"ok": false}
		var sequence_text: String = id.trim_prefix("journey-memory-")
		if not sequence_text.is_valid_int() or int(sequence_text) < 1 or int(sequence_text) > result.memory.sequence or id != "journey-memory-%06d" % int(sequence_text):
			return {"ok": false}
		var normalized: Dictionary = normalize_session(source.memory.sessions[id], id)
		if not normalized.ok or contexts.has(normalized.value.context_key):
			return {"ok": false}
		contexts[normalized.value.context_key] = true
		result.memory.sessions[id] = normalized.value
	if result.memory.sequence < result.memory.sessions.size():
		return {"ok": false}
	if source.has("p2"):
		var p2_normalized: Dictionary = P2.normalize(source.p2,result)
		if not p2_normalized.ok: return {"ok":false}
		result.p2 = p2_normalized.value
	return {"ok": true, "value": result}


static func normalize_session(value: Variant, id: String) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false}
	var session: Dictionary = value
	for field: String in ["invocation_id", "attempt_id", "context_key", "entry_id", "lexeme_id", "sense_id", "content_revision", "codebook_revision", "story_step_id", "task_mode", "view_mode"]:
		if not text_value(session.get(field), 1000, false):
			return {"ok": false}
	if session.invocation_id != id or session.attempt_id != id + "/attempt-1" or not session.get("source_unit") is Dictionary or not valid_unit(session.source_unit.get("book_id", ""), session.source_unit.get("unit_id", "")):
		return {"ok": false}
	if session.context_key != session.source_unit.book_id + "/" + session.source_unit.unit_id + "/" + session.story_step_id + "/" + session.entry_id:
		return {"ok": false}
	if not text_value(session.get("target_dimension"), 100) or (session.target_dimension != "" and not DIMENSIONS.has(session.target_dimension)) or not stimulus_value(session.get("declared_stimulus")) or not session.get("answer_visible_at_start") is bool or not text_value(session.get("draft_response"), 2000):
		return {"ok": false}
	if not integer_value(session.get("letter_count"), 0, 128) or not session.get("beat_ids") is Array or session.beat_ids.size() > 64 or not session.get("seen_beats") is Array or session.seen_beats.size() > session.beat_ids.size():
		return {"ok": false}
	var unique_beats: Dictionary = {}
	for beat_id: Variant in session.beat_ids:
		if not text_value(beat_id, 200, false) or unique_beats.has(beat_id):
			return {"ok": false}
		unique_beats[beat_id] = true
	var seen: Dictionary = {}
	for beat_id: Variant in session.seen_beats:
		if not text_value(beat_id, 200, false) or not unique_beats.has(beat_id) or seen.has(beat_id):
			return {"ok": false}
		seen[beat_id] = true
	if not integer_value(session.get("current_beat"), 1, maxi(1, session.beat_ids.size())) or not integer_value(session.get("max_help_level"), 0, 5) or not integer_value(session.get("support_level"), 0, 5) or session.get("status") not in ["active", "paused", "completed", "content_unavailable", "deferred"]:
		return {"ok": false}
	var gaps: Variant = session.get("revealed_gaps", [])
	var bridge: Variant = session.get("bridge_position", 1)
	var sequence: Variant = session.get("show_sequence", false)
	if not letter_positions_value(gaps, session.letter_count) or not integer_value(bridge, 1, maxi(1, session.letter_count)) or not sequence is bool or (sequence and int(session.support_level) != 5):
		return {"ok": false}
	var animation: Dictionary = normalize_animation(session.get("animation_state", {}), session)
	if not animation.ok:
		return {"ok": false}
	if session.has("exposure_completed") and (not session.exposure_completed is bool or session.exposure_completed != (session.seen_beats.size() == session.beat_ids.size())):
		return {"ok": false}
	if not timestamp_value(session.get("created_at_utc")) or not timestamp_value(session.get("updated_at_utc")) or not integer_value(session.get("game_day"), 1, 1_000_000):
		return {"ok": false}
	if not session.get("cue_events") is Array or session.cue_events.size() > MAX_CUES or not session.get("responses") is Array or session.responses.size() > MAX_RESPONSES:
		return {"ok": false}
	var cue_ids: Dictionary = {}
	var max_level: int = 0
	var normalized_cues: Array = []
	for cue: Variant in session.cue_events:
		if not cue is Dictionary:
			return {"ok": false}
		var cleaned: Dictionary = clean_cue(cue, session, 0.0)
		if not cleaned.ok or cue_ids.has(cue.event_id):
			return {"ok": false}
		cue_ids[cue.event_id] = true
		max_level = maxi(max_level, int(cue.support_level))
		normalized_cues.append(cleaned.value)
	if int(session.max_help_level) != max_level:
		return {"ok": false}
	var response_ids: Dictionary = {}
	for response: Variant in session.responses:
		if not response is Dictionary or not matching_identity(response, session) or not text_value(response.get("response_id"), 240, false) or response_ids.has(response.response_id):
			return {"ok": false}
		for field: String in ["correct", "practice_is_extra", "unassisted_attempt", "independent_success", "retry_after_first_response"]:
			if not response.get(field) is bool:
				return {"ok": false}
		if not text_value(response.get("response_text"), 2000) or not DIMENSIONS.has(response.get("target_dimension")) or not text_value(response.get("task_mode"), 100, false) or not timestamp_value(response.get("observed_at")) or response.get("result") not in ["not_correct", "independent_correct", "supported_correct"]:
			return {"ok": false}
		var first: bool = response_ids.is_empty()
		if response.retry_after_first_response == first or (response.independent_success and (not first or not response.correct or not response.unassisted_attempt)):
			return {"ok": false}
		var expected: String = "not_correct" if not response.correct else ("independent_correct" if response.independent_success else "supported_correct")
		if response.result != expected:
			return {"ok": false}
		response_ids[response.response_id] = true
	if not session.has("first_response") or not session.has("later_response"):
		return {"ok": false}
	if session.first_response != (session.responses[0] if not session.responses.is_empty() else null) or session.later_response != (session.responses[-1] if session.responses.size() > 1 else null):
		return {"ok": false}
	var result: Dictionary = session.duplicate(true)
	for field: String in ["letter_count", "current_beat", "max_help_level", "support_level", "game_day"]:
		result[field] = int(session[field])
	result.revealed_gaps = gaps.map(func(position: Variant) -> int: return int(position))
	result.bridge_position = int(bridge)
	result.show_sequence = sequence
	result.animation_state = animation.value
	result.cue_events = normalized_cues
	result.exposure_completed = session.seen_beats.size() == session.beat_ids.size()
	return {"ok": true, "value": result}


static func normalize_orchard(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("stage") not in ["ready", "carrying", "deposited"] or not text_value(value.get("round_id"), 160) or not value.get("completed_once") is bool:
		return {"ok": false}
	var mode: Variant = value.get("completion_mode", "")
	if not text_value(mode, 40) or (mode != "" and not MODES.has(mode)):
		return {"ok": false}
	if value.stage == "deposited" and not value.completed_once:
		return {"ok": false}
	if value.stage in ["carrying", "deposited"] and mode == "":
		return {"ok": false}
	if value.round_id.is_empty() and (value.stage != "ready" or value.completed_once):
		return {"ok": false}
	if value.stage == "ready":
		# Pre-release replay fixtures could retain the previous round's mode.
		# That mode is not evidence about the new waiting apple.
		mode = ""
	return {"ok": true, "value": {"stage": value.stage, "round_id": value.round_id, "completed_once": value.completed_once, "completion_mode": mode}}


static func normalize_animation(value: Variant, session: Dictionary) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false}
	if value.is_empty():
		return {"ok": true, "value": {}}
	if not integer_value(value.get("schema_version"), 1, 1) or not session.beat_ids.has(value.get("beat_id")) or not integer_value(value.get("step_position"), 1, int(session.letter_count)):
		return {"ok": false}
	var phase: Variant = value.get("phase")
	if not (phase is int or phase is float) or not is_finite(float(phase)) or float(phase) < 0.0 or float(phase) > 1.0 or value.get("playback_status") not in ["paused", "playing", "completed"] or not value.get("reduced_motion") is bool:
		return {"ok": false}
	var result: Dictionary = {"schema_version": 1, "beat_id": value.beat_id, "step_position": int(value.step_position), "phase": float(phase), "playback_status": value.playback_status, "reduced_motion": value.reduced_motion}
	if value.has("stage_revision"):
		if not text_value(value.stage_revision, 100, false):
			return {"ok": false}
		result.stage_revision = value.stage_revision
	return {"ok": true, "value": result}


static func prefix_steps(value: Variant, allowed: Array[String]) -> bool:
	if not value is Array or value.size() > allowed.size():
		return false
	for index: int in value.size():
		if value[index] != allowed[index]:
			return false
	return true


static func valid_unit(book_id: Variant, unit_id: Variant) -> bool:
	if not book_id is String or not unit_id is String or not BOOK_IDS.has(book_id):
		return false
	for number: int in range(1, BOOK_UNITS[BOOK_IDS.find(book_id)] + 1):
		if unit_id == "unit-" + str(number):
			return true
	return false


static func small_metadata(value: Dictionary) -> bool:
	if value.size() > 32:
		return false
	for key: Variant in value:
		if not text_value(key, 80, false):
			return false
		var item: Variant = value[key]
		if item is String:
			if item.length() > 1000:
				return false
		elif item is bool or item == null:
			continue
		elif str(key)=="elapsed_real_seconds":
			if not integer_value(item,0,10_000_000_000): return false
		elif not integer_value(item, 0, 1_000_000):
			return false
	return true


static func text_value(value: Variant, maximum: int, allow_empty: bool = true) -> bool:
	return value is String and value.length() <= maximum and (allow_empty or not value.is_empty())


static func stimulus_value(value: Variant) -> bool:
	if value is String:
		return text_value(value, 1000)
	return value is Dictionary and small_metadata(value) and text_value(value.get("kind"), 80, false) and text_value(value.get("text"), 1000)


static func integer_value(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


static func letter_positions_value(value: Variant, letter_count: int) -> bool:
	if not value is Array or value.size() > letter_count:
		return false
	var seen: Dictionary = {}
	for position: Variant in value:
		if not integer_value(position, 1, letter_count) or seen.has(int(position)):
			return false
		seen[int(position)] = true
	return true


static func timestamp_value(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 32_503_680_000.0


static func success(changed: bool = true) -> Dictionary:
	return {"ok": true, "changed": changed}


static func fail(message: String, status: String = "rejected") -> Dictionary:
	return {"ok": false, "status": status, "message": message}
