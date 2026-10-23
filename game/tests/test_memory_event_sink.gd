extends SceneTree
## Fake acknowledgements isolate write failures without touching a player save.

const SINK = preload("res://scripts/memory_event_sink.gd")

class FakeState extends Node:
	var fail_kind: String = ""
	var calls: Array[String] = []
	var committed: Array[Dictionary] = []
	var acknowledged: Dictionary = {}
	var close_results: Array[String] = []
	var close_calls: int = 0
	var cue_count: int = 0
	var cues_seen_by_response: Array[int] = []
	var first_response: Dictionary = {}
	var on_acknowledge: Callable

	func journey_record_memory_cue(id: String, payload: Dictionary) -> bool:
		return _accept("cue", id, payload)

	func journey_record_memory_response(id: String, payload: Dictionary) -> bool:
		return _accept("response", id, payload)

	func journey_update_memory(id: String, payload: Dictionary) -> bool:
		return _accept("progress", id, payload)

	func journey_close_memory(id: String, result: String) -> bool:
		calls.append("close:" + id)
		close_calls += 1
		if fail_kind == "close":
			return false
		close_results.append(result)
		return true

	func _accept(kind: String, id: String, payload: Dictionary) -> bool:
		calls.append(kind + ":" + id)
		if fail_kind == kind:
			return false
		var key: String = kind + "/" + str(payload.get("event_id", payload.get("response_id", "")))
		if kind != "progress" and acknowledged.has(key):
			return acknowledged[key] == payload
		committed.append({"kind": kind, "payload": payload.duplicate(true)})
		if kind == "cue":
			cue_count += 1
		elif kind == "response":
			cues_seen_by_response.append(cue_count)
			if first_response.is_empty():
				first_response = payload.duplicate(true)
		if kind != "progress":
			acknowledged[key] = payload.duplicate(true)
		if on_acknowledge.is_valid():
			var callback: Callable = on_acknowledge
			on_acknowledge = Callable()
			callback.call()
		return true


var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_test_failed_cue_blocks_everything()
	_test_partial_flush_and_close_retry()
	_test_duplicate_identity_and_owned_payload()
	_test_reentrant_enqueue_and_lifetime()
	for failure: String in _failures:
		push_error(failure)
	print("Memory event sink: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_failed_cue_blocks_everything() -> void:
	var state := FakeState.new()
	var sink = SINK.new()
	_check(sink.setup(state, "attempt-a"), "Bind one invocation")
	state.fail_kind = "cue"
	_check(not sink.enqueue("cue", {"event_id": "hint-1", "support_level": 5}), "Failed cue remains pending")
	_check(not sink.enqueue("response", {"response_id": "answer-1", "correct": true}), "A later answer waits behind the failed cue")
	_check(not sink.enqueue("progress", {"current_beat": 2}), "A later view snapshot waits behind both observations")
	_check(sink.pending_count() == 3 and state.committed.is_empty(), "All unacknowledged observations remain queued")
	_check(state.calls == ["cue:attempt-a", "cue:attempt-a", "cue:attempt-a"], "Later answer never reaches State before the cue")
	_check(not sink.close("completed") and state.close_calls == 0, "Closing cannot bypass pending observations")
	_check(not sink.setup(state, "attempt-b") and sink.pending_count() == 3, "Rebinding cannot discard a failed queue")
	state.fail_kind = ""
	_check(sink.flush() and sink.pending_count() == 0, "Retry flush acknowledges and drains the same queue")
	_check(_kinds(state) == ["cue", "response", "progress"], "Recovered writes preserve observation order")
	_check(state.cues_seen_by_response == [1], "Recovered response sees the actual earlier help")
	_check(sink.close("completed") and state.close_results == ["completed"], "Close follows the successfully flushed evidence")
	_check(sink.close("completed") and state.close_calls == 1, "Successful close retry is idempotent")
	_check(not sink.enqueue("progress", {"current_beat": 3}) and sink.pending_count() == 0, "A closed component cannot append stale events")
	state.free()


func _test_partial_flush_and_close_retry() -> void:
	var state := FakeState.new()
	var sink = SINK.new()
	sink.setup(state, "partial")
	_check(sink.enqueue("cue", {"event_id": "hint"}), "Earlier acknowledged cue is durable")
	state.fail_kind = "response"
	_check(not sink.enqueue("response", {"response_id": "first", "correct": false}), "Failed first response remains queued")
	_check(not sink.enqueue("response", {"response_id": "retry", "correct": true}), "Later correct response cannot replace the failed first")
	_check(not sink.enqueue("progress", {"draft_response": "nose"}) and sink.pending_count() == 3, "Progress cannot skip a failed response")
	_check(state.committed.size() == 1 and state.first_response.is_empty(), "Only the earlier cue is acknowledged so far")
	state.fail_kind = "close"
	_check(not sink.close("paused"), "Status write failure is reported after evidence flush")
	_check(sink.pending_count() == 0 and state.committed.size() == 4, "Already acknowledged evidence is not requeued or lost on close failure")
	_check(state.first_response.response_id == "first" and not state.first_response.correct, "First incorrect response survives later correction")
	_check(state.close_results.is_empty(), "Failed close does not claim a saved status")
	state.fail_kind = ""
	_check(sink.close("paused") and state.close_results == ["paused"], "Retry closes the retained invocation")
	_check(state.committed.size() == 4 and state.close_calls == 2, "Close retry does not duplicate observations")
	state.free()


func _test_duplicate_identity_and_owned_payload() -> void:
	var state := FakeState.new()
	var sink = SINK.new()
	sink.setup(state, "duplicates")
	state.fail_kind = "cue"
	var original: Dictionary = {"event_id": "same", "revealed_letter_positions": [1]}
	_check(not sink.enqueue("cue", original), "Queue original cue")
	_check(not sink.enqueue("cue", original.duplicate(true)) and sink.pending_count() == 1, "Transport retry does not multiply a pending event")
	original.revealed_letter_positions.append(2)
	_check(not sink.enqueue("cue", original) and sink.pending_count() == 1, "Conflicting same ID cannot replace the queued event")
	state.fail_kind = ""
	_check(sink.flush(), "Original pending cue retries")
	_check(state.committed[0].payload.revealed_letter_positions == [1], "Queued payload is independent of caller mutation")
	_check(sink.enqueue("cue", {"event_id": "same", "revealed_letter_positions": [1]}) and state.committed.size() == 1, "Acknowledged duplicate relies on State idempotency")
	_check(not sink.enqueue("unknown", {}) and sink.pending_count() == 0, "Unknown kinds cannot enter the queue")
	_check(not sink.close("invalid") and state.close_calls == 0, "Unknown status cannot be committed")
	state.free()


func _test_reentrant_enqueue_and_lifetime() -> void:
	var state := FakeState.new()
	var sink = SINK.new()
	_check(not sink.setup(state, ""), "Missing invocation cannot bind")
	_check(not sink.flush(), "Unbound sink cannot report a successful flush")
	sink.setup(state, "nested")
	state.on_acknowledge = func(): sink.enqueue("progress", {"current_beat": 2})
	_check(sink.enqueue("cue", {"event_id": "nested-hint"}), "A synchronously queued follow-up drains in the outer flush")
	_check(_kinds(state) == ["cue", "progress"] and sink.pending_count() == 0, "Reentrant enqueue cannot resubmit the current head")
	state.free()
	_check(not sink.flush() and not sink.enqueue("progress", {}) and not sink.close("paused"), "Destroyed State cannot produce false acknowledgements")


func _kinds(state: FakeState) -> Array:
	return state.committed.map(func(event: Dictionary) -> String: return str(event.kind))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
