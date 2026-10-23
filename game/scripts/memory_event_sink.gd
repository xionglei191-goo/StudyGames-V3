extends RefCounted
## Keeps unacknowledged memory observations in their original order.
## The owning controller must keep this sink and its UI alive while close() fails.

const METHODS: Dictionary = {
	"cue": "journey_record_memory_cue",
	"response": "journey_record_memory_response",
	"progress": "journey_update_memory",
}

var _state: Node
var _invocation_id: String = ""
var _pending: Array[Dictionary] = []
var _flushing: bool = false
var _closed: bool = false
var _closed_result: String = ""


func setup(state_node: Node, invocation_id: String) -> bool:
	if _flushing or not _pending.is_empty() or not is_instance_valid(state_node) or invocation_id.is_empty():
		return false
	for method: String in METHODS.values():
		if not state_node.has_method(method):
			return false
	if not state_node.has_method("journey_close_memory"):
		return false
	_state = state_node
	_invocation_id = invocation_id
	_closed = false
	_closed_result = ""
	return true


func enqueue(kind: String, payload: Dictionary) -> bool:
	if _closed or not METHODS.has(kind) or _invocation_id.is_empty() or not is_instance_valid(_state):
		return false
	var key: String = _event_key(kind, payload)
	if not key.is_empty():
		for event: Dictionary in _pending:
			if event.kind == kind and _event_key(kind, event.payload) == key:
				# A transport retry may not replace the original observation.
				return flush() if event.payload == payload else false
	_pending.append({"kind": kind, "payload": payload.duplicate(true)})
	return flush()


func flush() -> bool:
	if _flushing or _invocation_id.is_empty() or not is_instance_valid(_state):
		return false
	_flushing = true
	while not _pending.is_empty():
		var event: Dictionary = _pending[0]
		var accepted: Variant = _state.call(METHODS[event.kind], _invocation_id, event.payload.duplicate(true))
		if not accepted is bool or not accepted:
			_flushing = false
			return false
		_pending.pop_front()
	_flushing = false
	return true


func close(result: String) -> bool:
	if _closed:
		return result == _closed_result
	if result not in ["paused", "completed", "content_unavailable", "deferred"] or not flush():
		return false
	var accepted: Variant = _state.call("journey_close_memory", _invocation_id, result)
	if not accepted is bool or not accepted:
		return false
	_closed = true
	_closed_result = result
	return true


func pending_count() -> int:
	return _pending.size()


func _event_key(kind: String, payload: Dictionary) -> String:
	return str(payload.get("event_id", "")) if kind == "cue" else (str(payload.get("response_id", "")) if kind == "response" else "")
