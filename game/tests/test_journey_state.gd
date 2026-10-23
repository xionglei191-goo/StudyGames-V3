extends SceneTree
## Isolated fixtures only: never loads or writes the player's island-save-v1.json.

const STATE = preload("res://scripts/game_state.gd")
const JOURNEY = preload("res://scripts/journey_progress.gd")
const MEMORY_SINK = preload("res://scripts/memory_event_sink.gd")

var _failures: Array[String] = []
var _checks: int = 0
var _directory: String = "user://journey-state-tests-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	_test_legacy_migration()
	_test_prologue_and_route()
	_test_u1_receipts()
	_test_memory_history_and_versions()
	_test_memory_ui_payload_roundtrip()
	_test_full_sequence_support_transition()
	_test_orchard_rounds_and_atomic_save()
	_test_orchard_mode_persistence()
	_test_animation_state_and_cues()
	_test_atomic_failures_and_invalid_state()
	_cleanup()
	for failure: String in _failures:
		push_error(failure)
	print("Journey state: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _new_state(name: String):
	var state = STATE.new()
	state.save_path = _directory + "/" + name + ".json"
	state.load_state()
	return state


func _test_legacy_migration() -> void:
	var state = _new_state("legacy")
	_check(state.mark_greeted(), "Legacy fixture greeting")
	_check(state.collect_apple(), "Legacy fixture inventory")
	_check(state.discover("landmark_A", 2), "Legacy fixture discovery")
	state.begin_question("u1_greeting")
	state.record_answer("u1_greeting", true, false)
	var legacy: Dictionary = state.snapshot()
	legacy.erase("journey")
	legacy.preferences.erase("fixed_day")
	_write(state.save_path, JSON.stringify(legacy))
	state.load_state()
	for key: String in legacy:
		if key != "preferences":
			_check(state.data[key] == legacy[key], "Legacy data preserved: " + key)
	for key: String in legacy.preferences:
		_check(state.data.preferences[key] == legacy.preferences[key], "Legacy preference preserved: " + key)
	var journey: Dictionary = state.journey_snapshot()
	_check(journey.legacy_compatible and journey.can_continue_legacy and journey.phase == "legacy_life", "Legacy save can continue existing life")
	_check(journey.experienced_count == 0 and not journey.letters.A.visited, "Old discoveries do not imply new letter experience")
	_check(not state.data.preferences.fixed_day, "Old preferences migrate fixed_day to false")
	_check(state.set_preference("fixed_day", true), "Fixed daylight preference commits")
	var expected: Dictionary = state.snapshot()
	state.load_state()
	_check(state.snapshot() == expected, "Migrated old state and fixed_day roundtrip")
	_check(state.journey_complete_u1_step("U1-01"), "Legacy may enter new welcome content without erasing old progress")
	_check(state.journey_snapshot().experienced_count == 0, "Legacy exception grants no invented prologue facts")
	state.free()


func _complete_home(state) -> void:
	for step: String in JOURNEY.HOME_STEPS:
		_check(state.journey_complete_home_step(step), "Home step commits: " + step)


func _complete_letters(state) -> void:
	for letter: String in JOURNEY.LETTERS:
		for fact: String in JOURNEY.LETTER_FACTS:
			_check(state.journey_record_letter(letter, "landmark_" + letter, fact, "demonstration_viewed"), "Letter fact: " + letter + "/" + fact)


func _test_prologue_and_route() -> void:
	var state = _new_state("prologue")
	_check(not state.journey_snapshot().legacy_compatible and state.journey_snapshot().phase == "home", "New save starts home with no legacy bypass")
	_check(not state.journey_record_letter("A", "landmark_A", "visited"), "New save cannot skip home introduction")
	_check(not state.journey_complete_u1_step("U1-01"), "New save cannot skip the prologue")
	_check(not state.journey_complete_home_step("H02"), "Home steps enforce order")
	_complete_home(state)
	_check(state.journey_snapshot().phase == "prologue", "Home leads to prologue")
	_check(not state.journey_record_letter("A", "home", "visited"), "Wrong room cannot count as landmark arrival")
	_check(not state.journey_record_letter("A", "landmark_A", "case_pair_presented"), "No letter presentation before actual arrival")
	_check(state.discover("landmark_A", 2) and state.journey_snapshot().experienced_count == 0, "Existing discovery remains separate from prologue")
	_check(state.journey_record_letter("A", "landmark_A", "visited"), "Arrival records only visited")
	_check(not state.journey_snapshot().letters.A.experienced, "Arrival alone is not an experience")
	var arrived: Dictionary = state.snapshot()
	_check(state.journey_record_letter("A", "landmark_A", "visited") and state.snapshot() == arrived, "Repeated arrival is idempotent")
	var old_learning: Dictionary = state.data.learning.duplicate(true)
	_complete_letters(state)
	var summary: Dictionary = state.journey_snapshot()
	_check(summary.experienced_count == 26 and summary.prologue_completed and summary.phase == "u1", "All five facts across all letters enter default U1")
	_check(summary.letters.A.completion_mode == "demonstration_viewed", "Demonstrated completion is accepted and retained")
	_check(state.data.learning == old_learning and state.data.coins == 30, "Experience coverage creates no English scores or extra currency")
	var detached: Dictionary = state.journey_snapshot()
	detached.letters.A.visited = false
	_check(state.journey_snapshot().letters.A.visited, "Journey summary is deeply detached")
	_check(state.journey_select_book("xiangshao-g6-2"), "Parent may select a later book at boundary")
	_check(state.journey_snapshot().phase == "library_available", "Unimplemented higher-grade story is explicitly a library route")
	_check(not state.journey_complete_u1_step("U1-01"), "Higher-book route cannot falsely complete default U1")
	_check(not state.journey_select_book("invented-book"), "Unknown book cannot enter route")
	_check(state.journey_select_book("xiangshao-g3-1"), "Switching back preserves full prologue")
	_check(state.journey_complete_u1_step("U1-01"), "Default U1 begins")
	_check(not state.journey_select_book("xiangshao-g4-1"), "Active chapter cannot be reset by switching book")
	var expected: Dictionary = state.snapshot()
	state.load_state()
	_check(state.snapshot() == expected, "Prologue and active chapter roundtrip")
	state.free()


func _test_u1_receipts() -> void:
	var state = _new_state("u1")
	_complete_home(state)
	_complete_letters(state)
	_check(not state.journey_complete_u1_step("U1-08"), "Cannot claim photo before actual chapter steps")
	for index: int in range(7):
		var mode: String = "deferred" if index == 5 else "companion_action"
		_check(state.journey_complete_u1_step(JOURNEY.U1_STEPS[index], {"completion_mode": mode}), "Supported U1 step: " + JOURNEY.U1_STEPS[index])
	_check(not state.journey_complete_u1_step("U1-09"), "Photo and chapter receipt are separate")
	_check(state.journey_complete_u1_step("U1-08", {"photo_frame": "green", "photo_pose": "wave"}), "Photo result saves")
	var at_photo: Dictionary = state.snapshot()
	_check(at_photo.journey.u1.photo.created and not at_photo.journey.u1.completed and at_photo.journey.reward_receipts.size() == 1, "Photo does not prematurely complete chapter")
	_check(state.journey_complete_u1_step("U1-08", {"photo_frame": "red"}) and state.snapshot() == at_photo, "Replayed photo does not replace reward or mint another result")
	state.load_state()
	_check(state.snapshot() == at_photo, "Photo checkpoint resumes intact")
	_check(state.journey_complete_u1_step("U1-09", {"completion_mode": "companion_action"}), "Photo placement commits chapter receipt")
	var complete: Dictionary = state.snapshot()
	_check(complete.journey.u1.completed and complete.journey.reward_receipts.size() == 2, "Chapter receipt granted once")
	_check(state.journey_complete_u1_step("U1-09") and state.snapshot() == complete, "Chapter replay is fully idempotent")
	_check(state.data.coins == 30 and state.data.learning.is_empty() and not state.data.completed_units["1"], "Story completion never fabricates old test success or duplicate course rewards")
	_check(state.journey_snapshot().phase == "u2", "Completed welcome continues to the invitation chapter")
	_check(state.journey_complete_u1_step("U1-10") and state.journey_snapshot().reward_receipts.size() == 2, "Later revisit gives no duplicate rewards")
	_check(state.journey_select_book("xiangshao-g5-2"), "Completed chapter allows a new route while retaining prior result")
	_check(state.journey_snapshot().u1.completed and state.journey_snapshot().phase == "library_available", "New route preserves completed original chapter")
	state.free()


func _entry() -> Dictionary:
	# Deliberately isolated content fixture: IDs are not presented as production curriculum.
	return {"entry_id": "occ-test-nose", "lexeme_id": "lex-test-nose", "sense_id": "story-test-nose", "content_revision": "test-content-v1", "codebook_revision": "test-codebook-v1",
		"source_unit": {"book_id": "xiangshao-g3-1", "unit_ids": ["unit-6"]},
		"letter_slots": [{"letter": "N"}, {"letter": "O"}, {"letter": "S"}, {"letter": "E"}],
		"story_beats": [{"beat_id": "test-nose/frame-1"}, {"beat_id": "test-nose/frame-2"}]}


func _context(step: String = "test-body-step") -> Dictionary:
	return {"story_step_id": step, "book_id": "xiangshao-g3-1", "unit_id": "unit-6", "task_mode": "picture_to_spelling", "target_dimension": "orthography", "declared_stimulus": "test-nose-picture", "answer_visible_at_start": false}


func _response(id: String, correct: bool, text: String) -> Dictionary:
	return {"response_id": id, "correct": correct, "response_text": text, "target_dimension": "orthography", "task_mode": "picture_to_spelling", "practice_is_extra": false, "observed_at": 1234.0}


func _test_memory_history_and_versions() -> void:
	var state = _new_state("memory")
	var opened: Dictionary = state.journey_begin_memory(_entry(), _context())
	_check(opened.ok, "Memory invocation starts with stable content identity")
	if not opened.ok:
		state.free()
		return
	var id: String = opened.invocation_id
	_check(opened.resume_state.current_beat == 1 and opened.resume_state.first_response == null and opened.resume_state.max_help_level == 0, "Opening alone invents no response or shown help")
	_check(state.journey_record_memory_response(id, _response("first-wrong", false, "nsoe")), "Unassisted incorrect answer is recorded")
	var first: Dictionary = state.journey_snapshot().memory.sessions[id].first_response
	_check(first.unassisted_attempt and not first.independent_success and first.result == "not_correct", "Independent attempt may be wrong")
	_check(state.journey_record_memory_response(id, _response("retry-correct", true, "nose")), "Retry preserves later answer")
	var retried: Dictionary = state.journey_snapshot().memory.sessions[id]
	_check(retried.first_response == first and not retried.later_response.independent_success and retried.later_response.retry_after_first_response, "Same-attempt correction cannot wash first error")
	_check(retried.later_response.unassisted_attempt, "No fictional viewed cue added to a cue-free retry")
	var before: Dictionary = state.snapshot()
	_check(state.journey_record_memory_response(id, _response("retry-correct", true, "nose")) and state.snapshot() == before, "Response retry transport is idempotent")
	_check(not state.journey_record_memory_response(id, _response("retry-correct", false, "bad")), "An existing response ID cannot change answer")
	var cue: Dictionary = {"event_id": "demo-1", "support_level": 5, "support_kind": "full_demonstration", "revealed_letter_positions": [1, 2, 3, 4], "answer_revealing_dimensions": ["orthography", "meaning"], "asset_or_content_ref": "test-nose/frame-1", "requested_by": "child", "shown_at": 1235.0}
	var wrong_cue: Dictionary = cue.duplicate(true)
	wrong_cue.revealed_letter_positions = [5]
	_check(not state.journey_record_memory_cue(id, wrong_cue), "Out-of-range letter cue rejected")
	wrong_cue = cue.duplicate(true)
	wrong_cue.support_level = 0
	_check(not state.journey_record_memory_cue(id, wrong_cue), "H0 cannot falsely label revealed answers")
	_check(state.journey_record_memory_cue(id, cue), "Shown full demo commits evidence")
	before = state.snapshot()
	_check(state.journey_record_memory_cue(id, cue) and state.snapshot() == before, "Cue event is idempotent")
	_check(state.journey_update_memory(id, {"current_beat": 2, "seen_beats": ["test-nose/frame-1"], "view_mode": "recall", "support_level": 0, "draft_response": "no", "max_help_level": 0, "cue_events": [], "first_response": null}), "View change may persist without erasing authoritative evidence")
	var progress: Dictionary = state.journey_snapshot().memory.sessions[id]
	_check(progress.max_help_level == 5 and progress.cue_events.size() == 1 and progress.first_response == first, "Hidden view does not clear prior help or answer")
	_check(not state.journey_update_memory(id, {"current_beat": 99}), "Invalid resume position rejected")
	_check(state.journey_close_memory(id, "paused"), "Partial story pauses")
	state.load_state()
	var resumed: Dictionary = state.journey_begin_memory(_entry(), _context())
	_check(resumed.ok and resumed.invocation_id == id and resumed.attempt_id == opened.attempt_id, "Reopening the same context reuses invocation and attempt")
	_check(resumed.resume_state.current_beat == 2 and resumed.resume_state.max_help_level == 5 and resumed.resume_state.draft_response == "no", "Reload restores position, shown help and draft")
	_check(not resumed.resume_state.exposure_completed and resumed.resume_state.seen_beats.size() == 1, "Partial story is not full exposure")
	_check(state.journey_close_memory(id, "completed"), "Practice can end without mandatory viewing")
	_check(not state.journey_snapshot().memory.sessions[id].exposure_completed, "Session completion does not fabricate full story exposure")
	_check(state.journey_update_memory(id, {"seen_beats": ["test-nose/frame-1", "test-nose/frame-2"]}), "Remaining actually viewed frame commits")
	_check(state.journey_snapshot().memory.sessions[id].exposure_completed, "Full exposure requires all actual beats")
	before = state.snapshot()
	var changed_entry: Dictionary = _entry()
	changed_entry.content_revision = "test-content-v2"
	var unavailable: Dictionary = state.journey_begin_memory(changed_entry, _context())
	_check(not unavailable.ok and unavailable.status == "content_unavailable" and state.snapshot() == before, "Content revision mismatch preserves old session exactly")
	var wrong_source: Dictionary = _context("wrong-source")
	wrong_source.unit_id = "unit-7"
	_check(not state.journey_begin_memory(_entry(), wrong_source).ok, "Source membership is enforced")
	var review: Dictionary = state.journey_begin_memory(_entry(), _context("new-context-review"))
	_check(review.ok and review.invocation_id != id, "Explicit new task context gets a distinct attempt")
	_check(state.journey_record_memory_response(review.invocation_id, _response("review-first", true, "nose")), "New unassisted success records")
	var independent: Dictionary = state.journey_snapshot().memory.sessions[review.invocation_id].first_response
	_check(independent.unassisted_attempt and independent.independent_success and independent.result == "independent_correct", "First correct without answers is independent success")
	_check(state.journey_record_memory_cue(review.invocation_id, cue), "A later review cue is logged")
	_check(state.journey_snapshot().memory.sessions[review.invocation_id].first_response == independent, "Later cues do not rewrite historical first-answer conditions")
	var visible_context: Dictionary = _context("visible-answer")
	visible_context.answer_visible_at_start = true
	var visible: Dictionary = state.journey_begin_memory(_entry(), visible_context)
	_check(state.journey_record_memory_response(visible.invocation_id, _response("copy-first", true, "nose")), "Visible-target answer records")
	_check(not state.journey_snapshot().memory.sessions[visible.invocation_id].first_response.independent_success, "Visible target cannot become independent recall")
	_check(state.data.learning.is_empty() and state.data.coins == 30, "Memory records do not manufacture old course scores or currency")
	var last: Dictionary = state.snapshot()
	state.load_state()
	_check(state.snapshot() == last, "All observation conditions roundtrip without reclassification")
	state.free()


func _test_memory_ui_payload_roundtrip() -> void:
	var state = _new_state("memory-ui")
	var context: Dictionary = _context("meaning-recall-ui")
	context.task_mode = "meaning_to_spelling"
	context.declared_stimulus = {"kind": "written_meaning", "text": "鼻子"}
	var opened: Dictionary = state.journey_begin_memory(_entry(), context)
	_check(opened.ok, "Actual meaning-to-spelling task accepts a written-meaning stimulus")
	if not opened.ok:
		state.free()
		return
	var id: String = opened.invocation_id
	_check(opened.resume_state.support_level == 5 and opened.resume_state.max_help_level == 0, "New view defaults to demonstration without fabricating shown-help evidence")
	var cue: Dictionary = {"event_id": "ui-h0", "invocation_id": id, "attempt_id": opened.attempt_id,
		"support_level": 0, "support_kind": "no_extra_help", "display_event": "support_changed",
		"asset_or_content_ref": "test-nose/frame-1", "requested_by": "child", "shown_at": 1234.125,
		"revealed_letter_positions": [], "answer_revealing_dimensions": [], "displayed_stimulus_dimensions": ["meaning"]}
	_check(state.journey_record_memory_cue(id, cue), "H0 may show the declared meaning stimulus without revealing spelling")
	var response: Dictionary = _response("ui-first", true, "nose")
	response.task_mode = "meaning_to_spelling"
	_check(state.journey_record_memory_response(id, response), "Actual UI response mode is persisted")
	_check(state.journey_snapshot().memory.sessions[id].first_response.independent_success, "Meaning stimulus alone does not contaminate orthography recall")
	cue.event_id = "ui-h3"
	cue.support_level = 3
	cue.support_kind = "gap_fill"
	cue.display_event = "gap_revealed"
	cue.revealed_letter_positions = [1, 2, 3]
	cue.answer_revealing_dimensions = ["meaning", "orthography"]
	_check(state.journey_record_memory_cue(id, cue), "Actual gap reveal records answer evidence")
	_check(state.journey_update_memory(id, {"support_level": 3, "revealed_gaps": [2], "bridge_position": 3, "show_sequence": false, "draft_response": "nos", "view_mode": "recall"}), "Expanded gap and bridge controls persist")
	var before: Dictionary = state.snapshot()
	_check(not state.journey_update_memory(id, {"revealed_gaps": [5]}) and state.snapshot() == before, "Out-of-range gap cannot corrupt resume state")
	_check(not state.journey_update_memory(id, {"bridge_position": 5}) and state.snapshot() == before, "Out-of-range bridge cannot corrupt resume state")
	_check(not state.journey_update_memory(id, {"show_sequence": true}) and state.snapshot() == before, "Full answer view cannot keep a lower display level")
	state.load_state()
	var resumed: Dictionary = state.journey_begin_memory(_entry(), context)
	_check(resumed.ok and resumed.resume_state.revealed_gaps == [2] and resumed.resume_state.bridge_position == 3 and not resumed.resume_state.show_sequence, "Reload restores expanded gaps and bridge position")
	_check(resumed.resume_state.cue_events[0].displayed_stimulus_dimensions == ["meaning"] and resumed.resume_state.cue_events[1].display_event == "gap_revealed", "Actual stimulus and reveal event detail survive reload")
	_check(resumed.resume_state.first_response.independent_success and resumed.resume_state.max_help_level == 3, "Later reveal does not rewrite the historical first response")
	_check(state.journey_update_memory(id, {"support_level": 5, "show_sequence": true}), "Full chain expansion persists separately from cue evidence")
	state.load_state()
	_check(state.journey_snapshot().memory.sessions[id].show_sequence, "Full chain expansion survives reload")
	var old_session: Dictionary = state.snapshot()
	for field: String in ["revealed_gaps", "bridge_position", "show_sequence"]:
		old_session.journey.memory.sessions[id].erase(field)
	_write(state.save_path, JSON.stringify(old_session, "\t", true, true))
	state.load_state()
	var migrated: Dictionary = state.journey_snapshot().memory.sessions[id]
	_check(migrated.revealed_gaps.is_empty() and migrated.bridge_position == 1 and not migrated.show_sequence and migrated.responses.size() == 1, "Earlier journey sessions acquire neutral UI defaults without losing evidence")
	state.free()


func _test_full_sequence_support_transition() -> void:
	for level: int in [0, 1, 2, 3, 4, 5]:
		var state = _new_state("sequence-support-" + str(level))
		var opened: Dictionary = state.journey_begin_memory(_entry(), _context("sequence-support"))
		_check(opened.ok, "Full-sequence transition fixture opens at H" + str(level))
		var id: String = opened.invocation_id
		var full_cue: Dictionary = {"event_id": "sequence-visible", "support_level": 5, "display_event": "full_sequence", "revealed_letter_positions": [1, 2, 3, 4], "answer_revealing_dimensions": ["orthography", "meaning"], "shown_at": 10.0}
		_check(state.journey_record_memory_cue(id, full_cue), "Full chain is actual prior evidence")
		_check(state.journey_update_memory(id, {"support_level": 5, "show_sequence": true, "revealed_gaps": [2]}), "Expanded H5 chain persists before support change")
		var sink = MEMORY_SINK.new()
		_check(sink.setup(state, id), "Real sink binds the full-sequence session")
		var positions: Array = [] if level <= 1 else ([1] if level == 2 else ([1, 3] if level == 3 else ([1, 2] if level == 4 else [1, 2, 3, 4])))
		var dimensions: Array = [] if level == 0 else ["meaning"]
		if not positions.is_empty(): dimensions.append("orthography")
		var cue: Dictionary = {"event_id": "support-selected", "support_level": level, "display_event": "support_selected", "revealed_letter_positions": positions, "answer_revealing_dimensions": dimensions, "shown_at": 11.0}
		_check(sink.enqueue("cue", cue) and sink.pending_count() == 0, "Support cue commits before progress without blocking sink: H" + str(level))
		var after_cue: Dictionary = state.journey_snapshot().memory.sessions[id]
		_check(after_cue.support_level == level and not after_cue.show_sequence and after_cue.revealed_gaps.is_empty(), "Cue write alone resets current expanded view: H" + str(level))
		_check(after_cue.max_help_level == 5 and after_cue.cue_events[0].revealed_letter_positions == [1, 2, 3, 4] and after_cue.cue_events[1].revealed_letter_positions == positions, "Historical full answer and current partial exposure remain exact")
		state.load_state()
		_check(state.journey_snapshot().memory.sessions[id] == after_cue, "Crash between cue and progress can reload valid support state")
		_check(sink.enqueue("progress", {"support_level": level, "show_sequence": false, "revealed_gaps": [], "animation_state": {}}) and sink.pending_count() == 0, "Following UI snapshot drains normally")
		_check(sink.enqueue("response", _response("after-sequence", true, "nose")), "Response after reduced support still records")
		_check(not state.journey_snapshot().memory.sessions[id].first_response.independent_success, "Reducing current help never erases previous full-answer assistance")
		_check(sink.close("paused"), "The user can leave the story after switching support")
		var next: Dictionary = state.journey_begin_memory(_entry(), _context("after-sequence-next"))
		_check(next.ok and next.invocation_id != id, "A different story context opens after the prior sink closes")
		state.free()


func _test_orchard_rounds_and_atomic_save() -> void:
	var state = _new_state("orchard")
	var untouched: Dictionary = state.snapshot()
	_check(state.journey_orchard_snapshot() == {"stage": "ready", "round_id": "", "completed_once": false, "completion_mode": ""}, "New orchard starts with a waiting unowned apple")
	var old_save: Dictionary = state.snapshot()
	old_save.journey.erase("experiences")
	var migrated: Dictionary = state._normalize_state(old_save)
	_check(migrated.ok and migrated.state.journey.experiences.orchard_pick.stage == "ready", "Pre-P1 journey save acquires neutral orchard state")
	_check(not state.journey_orchard_commit("ready", "deposited", "round-a") and state.snapshot() == untouched, "Apple cannot jump from branch directly to basket")
	_check(state.journey_orchard_commit("ready", "carrying", "round-a"), "Picking binds the actual round before carrying")
	var carrying: Dictionary = state.snapshot()
	_check(state.journey_orchard_snapshot().stage == "carrying" and not state.journey_orchard_snapshot().completed_once, "Carrying is distinct from completion")
	_check(state.journey_orchard_commit("ready", "carrying", "round-a") and state.snapshot() == carrying, "Pick transport retry cannot duplicate ownership")
	var exposed: Dictionary = state.journey_orchard_snapshot()
	exposed.stage = "deposited"
	_check(state.snapshot() == carrying, "Public orchard snapshot cannot mutate ownership")
	state.load_state()
	_check(state.snapshot() == carrying, "Interrupted carrying survives reload")
	var good_path: String = state.save_path
	var blocker: String = _directory + "/orchard-blocker"
	_write(blocker, "fixture")
	state.save_path = blocker + "/save.json"
	_check(not state.journey_orchard_commit("carrying", "deposited", "round-a", "demonstration_viewed") and state.snapshot() == carrying, "Failed basket save leaves the apple in the player's saved hand")
	state.save_path = good_path
	_check(state.journey_orchard_commit("carrying", "deposited", "round-a", "demonstration_viewed"), "Basket deposit can retry after storage recovers")
	var deposited: Dictionary = state.snapshot()
	_check(state.journey_orchard_snapshot().completed_once and state.journey_orchard_snapshot().completion_mode == "demonstration_viewed", "Deposited experience keeps actual completion mode")
	_check(state.journey_orchard_commit("carrying", "deposited", "round-a", "independent_action") and state.snapshot() == deposited, "Repeated deposit cannot rewrite demonstration as independent action")
	state.load_state()
	_check(state.snapshot() == deposited, "Deposited apple and first completion survive reload")
	_check(not state.journey_orchard_commit("deposited", "ready", "round-a") and state.snapshot() == deposited, "Replay cannot reuse the completed round ID")
	_check(state.journey_orchard_commit("deposited", "ready", "round-b"), "Replay creates a fresh round with a new waiting apple")
	var replay: Dictionary = state.snapshot()
	_check(state.journey_orchard_snapshot().completed_once and state.journey_orchard_snapshot().completion_mode == "", "Replay retains completed experience and clears the new round's mode")
	_check(state.journey_orchard_commit("deposited", "ready", "round-b") and state.snapshot() == replay, "Replay reset is idempotent")
	_check(not state.journey_orchard_commit("ready", "carrying", "round-a") and state.snapshot() == replay, "Old-round pick cannot move the replay apple")
	_check(not state.journey_orchard_commit("carrying", "deposited", "round-a") and state.snapshot() == replay, "Delayed old-round deposit cannot complete the replay")
	_check(state.journey_orchard_commit("ready", "carrying", "round-b") and state.journey_orchard_commit("carrying", "deposited", "round-b"), "The new round can complete normally")
	for key: String in ["coins", "apples", "cakes", "learning", "completed_units", "quests", "life"]:
		_check(state.data[key] == untouched[key], "Orchard experience does not alter economic or English data: " + key)
	_check(state.data.journey.letters == untouched.journey.letters, "Orchard replay never resets or invents alphabet facts")
	var invalid: Dictionary = state.snapshot()
	invalid.journey.experiences.orchard_pick.round_id = ""
	_check(not state._normalize_state(invalid).ok, "Saved deposited state requires a round identity")
	invalid = state.snapshot()
	invalid.journey.experiences.orchard_pick.completed_once = false
	_check(not state._normalize_state(invalid).ok, "Saved basket ownership cannot conceal completion")
	state.free()


func _test_orchard_mode_persistence() -> void:
	for mode: String in JOURNEY.MODES:
		var state = _new_state("orchard-mode-" + mode)
		var facts: Dictionary = state.journey_snapshot().letters
		_check(state.journey_orchard_commit("ready", "carrying", "mode-round", mode), "Pick saves the current assistance mode: " + mode)
		_check(state.journey_orchard_snapshot().completion_mode == mode and not state.journey_orchard_snapshot().completed_once, "Carrying records assistance before completion: " + mode)
		state.load_state()
		_check(state.journey_orchard_snapshot().stage == "carrying" and state.journey_orchard_snapshot().completion_mode == mode, "Assistance survives exit while carrying: " + mode)
		var carrying: Dictionary = state.snapshot()
		_check(state.journey_orchard_commit("ready", "carrying", "mode-round", "independent_action") and state.snapshot() == carrying, "Repeated pick cannot downgrade actual support: " + mode)
		_check(state.journey_orchard_commit("carrying", "deposited", "mode-round", "independent_action"), "Deposit accepts resumed supported round: " + mode)
		_check(state.journey_orchard_snapshot().completion_mode == mode, "Deposit preserves highest assistance already recorded: " + mode)
		state.load_state()
		_check(state.journey_orchard_snapshot().completion_mode == mode and state.journey_orchard_snapshot().completed_once, "Final round evidence survives reload: " + mode)
		_check(state.journey_orchard_commit("deposited", "ready", "mode-round-replay"), "Replay creates a separate assistance scope: " + mode)
		_check(state.journey_orchard_snapshot().completion_mode == "" and state.journey_orchard_snapshot().completed_once and state.journey_snapshot().letters == facts, "Replay clears only current assistance and preserves completion and letters: " + mode)
		_check(state.journey_orchard_commit("ready", "carrying", "mode-round-replay", "independent_action") and state.journey_orchard_snapshot().completion_mode == "independent_action", "A genuinely new independent round is not contaminated by older help: " + mode)
		var invalid: Dictionary = state.snapshot()
		invalid.journey.experiences.orchard_pick.completion_mode = ""
		_check(not state._normalize_state(invalid).ok, "Saved carrying without an observed completion mode is invalid: " + mode)
		state.free()
	var supported = _new_state("orchard-mode-upgrade")
	_check(supported.journey_orchard_commit("ready", "carrying", "upgrade-round"), "Support-upgrade fixture starts independently")
	var before: Dictionary = supported.snapshot()
	var good_path: String = supported.save_path
	var blocker: String = _directory + "/orchard-mode-blocker"
	_write(blocker, "fixture")
	supported.save_path = blocker + "/save.json"
	_check(not supported.journey_orchard_commit("ready", "carrying", "upgrade-round", "demonstration_viewed") and supported.snapshot() == before, "Failed assistance escalation rolls back atomically")
	supported.save_path = good_path
	_check(supported.journey_orchard_commit("ready", "carrying", "upgrade-round", "demonstration_viewed"), "Same carrying round may persist newly observed demonstration")
	var upgraded: Dictionary = supported.snapshot()
	_check(supported.journey_orchard_commit("ready", "carrying", "upgrade-round", "demonstration_viewed") and supported.snapshot() == upgraded, "Repeated assistance escalation is idempotent")
	supported.load_state()
	_check(supported.journey_orchard_snapshot().completion_mode == "demonstration_viewed", "Newly observed help survives interruption before deposit")
	_check(supported.journey_orchard_commit("carrying", "deposited", "upgrade-round", "hinted_action") and supported.journey_orchard_snapshot().completion_mode == "demonstration_viewed", "A demonstrated round cannot become hinted or independent at deposit")
	supported.free()


func _test_animation_state_and_cues() -> void:
	var state = _new_state("animation")
	var opened: Dictionary = state.journey_begin_memory(_entry(), _context("animation-fixture"))
	_check(opened.ok, "Animation fixture opens")
	if not opened.ok:
		state.free()
		return
	var id: String = opened.invocation_id
	var animation: Dictionary = {"schema_version": 1, "beat_id": "test-nose/frame-1", "step_position": 2, "phase": 0.375, "playback_status": "playing", "reduced_motion": false, "stage_revision": "memory-stage-v1"}
	_check(state.journey_update_memory(id, {"animation_state": animation}), "Animation position and fractional phase persist")
	var saved: Dictionary = state.snapshot()
	state.load_state()
	_check(state.snapshot() == saved and state.journey_snapshot().memory.sessions[id].animation_state == animation, "Animation phase roundtrips without silently resuming or rewriting stored state")
	_check(state.journey_snapshot().memory.sessions[id].max_help_level == 0 and not state.journey_snapshot().memory.sessions[id].exposure_completed, "Animation snapshot alone invents neither exposure nor help")
	for patch: Dictionary in [{"schema_version": 2}, {"beat_id": "foreign/frame"}, {"step_position": 0}, {"step_position": 5}, {"step_position": 1.5}, {"phase": -0.1}, {"phase": 1.1}, {"phase": NAN}, {"playback_status": "auto"}, {"reduced_motion": "false"}, {"stage_revision": 1}]:
		var invalid_animation: Dictionary = animation.duplicate(true)
		invalid_animation.merge(patch, true)
		_check(not state.journey_update_memory(id, {"animation_state": invalid_animation}) and state.snapshot() == saved, "Invalid animation metadata is rejected atomically: " + str(patch.keys()[0]))
	var cue: Dictionary = {"event_id": "animated-position-2", "support_level": 3, "display_event": "story_animation_step", "animation_action": "book_open", "animated_letter_position": 2, "revealed_letter_positions": [2], "answer_revealing_dimensions": ["orthography"], "shown_at": 1235.25}
	_check(state.journey_record_memory_cue(id, cue), "Animation exposure commits its actual letter position")
	var before: Dictionary = state.snapshot()
	_check(state.journey_record_memory_cue(id, cue) and state.snapshot() == before, "Animation cue transport replay remains idempotent")
	var hidden: Dictionary = cue.duplicate(true)
	hidden.event_id = "hidden-animation"
	hidden.revealed_letter_positions = []
	_check(not state.journey_record_memory_cue(id, hidden) and state.snapshot() == before, "A visible animated letter cannot be declared hidden")
	hidden = cue.duplicate(true)
	hidden.event_id = "partial-animation-metadata"
	hidden.erase("animated_letter_position")
	_check(not state.journey_record_memory_cue(id, hidden), "Animation action and position must be provided together")
	_check(state.journey_record_memory_response(id, _response("animation-first", true, "nose")), "Answer after animated spelling cue records")
	_check(not state.journey_snapshot().memory.sessions[id].first_response.independent_success, "Animation help prevents false independent spelling success")
	var good_path: String = state.save_path
	var blocker: String = _directory + "/animation-blocker"
	_write(blocker, "fixture")
	before = state.snapshot()
	animation.phase = 0.875
	animation.playback_status = "paused"
	state.save_path = blocker + "/save.json"
	_check(not state.journey_update_memory(id, {"animation_state": animation}) and state.snapshot() == before, "Failed animation save preserves its last acknowledged position")
	state.save_path = good_path
	_check(state.journey_update_memory(id, {"animation_state": animation}), "Paused animation snapshot retries successfully")
	state.load_state()
	var resumed: Dictionary = state.journey_snapshot().memory.sessions[id]
	_check(resumed.animation_state == animation and resumed.cue_events[0].animated_letter_position == 2 and resumed.cue_events[0].animation_action == "book_open", "Paused action and actual exposure details survive reload")
	var old_save: Dictionary = state.snapshot()
	old_save.journey.memory.sessions[id].erase("animation_state")
	var migrated: Dictionary = state._normalize_state(old_save)
	_check(migrated.ok and migrated.state.journey.memory.sessions[id].animation_state.is_empty() and migrated.state.journey.memory.sessions[id].cue_events.size() == 1, "Earlier sessions gain a neutral animation snapshot without losing cues")
	state.free()


func _test_atomic_failures_and_invalid_state() -> void:
	var state = _new_state("atomic")
	_complete_home(state)
	_complete_letters(state)
	for index: int in range(8):
		_check(state.journey_complete_u1_step(JOURNEY.U1_STEPS[index]), "Atomic fixture U1 step")
	var before: Dictionary = state.snapshot()
	var valid_path: String = state.save_path
	var blocker: String = _directory + "/blocked-parent"
	_write(blocker, "fixture")
	state.save_path = blocker + "/save.json"
	_check(not state.journey_complete_u1_step("U1-09") and state.snapshot() == before, "Save failure rolls back chapter and receipt together")
	_check(not state.journey_begin_memory(_entry(), _context()).ok and state.snapshot() == before, "Failed memory start rolls back sequence and invocation")
	_check(not state.set_preference("fixed_day", true) and state.snapshot() == before, "Failed preference save rolls back")
	state.save_path = valid_path
	_check(state.journey_complete_u1_step("U1-09"), "Chapter may retry after storage becomes available")
	var opened: Dictionary = state.journey_begin_memory(_entry(), _context())
	_check(opened.ok, "Atomic memory fixture opens")
	if not opened.ok:
		state.free()
		return
	before = state.snapshot()
	state.save_path = blocker + "/save.json"
	_check(not state.journey_record_memory_response(opened.invocation_id, _response("atomic-answer", false, "bad")) and state.snapshot() == before, "Failed response save preserves null observation")
	state.save_path = valid_path
	var invalid: Dictionary = before.duplicate(true)
	invalid.journey.letters.A.visited = false
	_check(not state._normalize_state(invalid).ok, "Persisted experienced flag cannot conceal a missing arrival")
	invalid = before.duplicate(true)
	invalid.journey.u1.completed = false
	_check(not state._normalize_state(invalid).ok, "Persisted chapter flag must match steps and receipt")
	invalid = before.duplicate(true)
	invalid.journey.memory.sessions[opened.invocation_id].max_help_level = 5
	_check(not state._normalize_state(invalid).ok, "Persisted help maximum must match actual cue history")
	invalid = before.duplicate(true)
	invalid.journey.memory.sequence = 0
	_check(not state._normalize_state(invalid).ok, "Sequence cannot rewind over saved sessions")
	invalid = before.duplicate(true)
	invalid.preferences.fixed_day = "false"
	_check(not state._normalize_state(invalid).ok, "Fixed daylight rejects non-boolean corruption")
	var snapshot: Dictionary = state.snapshot()
	state.load_state()
	_check(state.snapshot() == snapshot, "Rejected invalid state never overwrites the valid save")
	state.free()


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Cannot write isolated fixture: " + path)
		return
	file.store_string(content)
	file.close()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	var directory: DirAccess = DirAccess.open(_directory)
	if directory == null:
		return
	for filename: String in directory.get_files():
		directory.remove(filename)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_directory))
