extends SceneTree
## Isolated component/data tests; no main scene, external library, or content import.
const Content = preload("res://ui/memory_story_content.gd")
const Story = preload("res://ui/memory_story.gd")
var _checks := 0
var _failures: Array[String] = []
var _view: Control
var _cues: Array = []
var _responses: Array = []
var _closed: Array = []
var _production_hash := ""
var _production_backup_hash := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Memory tests require -- --test-harness")
		quit(2)
		return
	_production_hash = _file_hash("user://island-save-v1.json")
	_production_backup_hash = _file_hash("user://island-save-v1.json.bak")
	var state := root.get_node_or_null("State")
	_check(state != null and state.has_method("journey_begin_memory"), "State autoload compiled without a missing dependency")
	root.size = Vector2i(1440, 900)
	var catalog := Content.load_catalog()
	_check(catalog.get("entries", []).size() == 1314, "All 1314 source occurrences are offline")
	_check(catalog.get("books", []).size() == 8, "Eight books available")
	_check(catalog.get("unit_index", []).size() == 81, "81 unit indexes available")
	_check(Content.list_entries("xiangshao-g3-1", "unit-1").size() == 16, "Unit filter uses actual membership")
	_check(Content.list_entries("", "", "café").size() == 1, "Unicode search finds café")
	for small: Dictionary in catalog.get("entries", []):
		var full := Content.get_entry(str(small.entry_id))
		var rebuilt := ""
		for token: Dictionary in full.reconstruction_tokens:
			rebuilt += str(token.raw)
		_check(rebuilt == str(full.spelling_display), "Reconstruct "+str(small.entry_id))
		var positions: Array = []
		for beat: Dictionary in full.story_beats:
			positions.append_array(beat.letter_positions)
			_check(beat.letter_positions.size() <= 4, "Frame budget "+str(beat.beat_id))
		_check(positions.size() == full.letter_slots.size(), "No dropped/repeated positions "+str(small.entry_id))
	for symbol: Dictionary in catalog.codebook:
		var texture: Texture2D = Content.icon(str(symbol.letter))
		_check(texture != null and texture.get_width() == 160, "Original SVG decoded for "+str(symbol.letter))
	var audio_entries := 0
	for small: Dictionary in catalog.entries:
		if not small.audio.is_empty():
			audio_entries += 1
			_check(str(small.audio.text) == str(small.spelling_display) and FileAccess.file_exists(str(small.audio.path)), "Audio exactly matches bundled target "+str(small.entry_id))
	_check(audio_entries == 7, "Only seven exact bundled audio targets offered")
	var host := Control.new()
	host.position = Vector2(110, 80)
	host.size = Vector2(1220, 740)
	root.add_child(host)
	_view = Story.new()
	host.add_child(_view)
	_view.help_shown.connect(func(event: Dictionary): _cues.append(event))
	_view.response_submitted.connect(func(response: Dictionary): _responses.append(response))
	_view.close_requested.connect(func(result: Dictionary): _closed.append(result))
	_view.setup(Content.get_entry("occ-89a38b8a39c8"), {"invocation_id":"memory-test/nose", "attempt_id":"attempt-1"})
	await _layout()
	_check(_cues.size() == 1 and int(_cues[-1].support_level) == 5, "Visible initial demonstration emits H5 once")
	_check(_cues[-1].shown_at is float or _cues[-1].shown_at is int, "Cue uses numeric UTC Unix seconds")
	_check(_cues[-1].revealed_letter_positions.size() == 4, "H5 records all visible spelling positions")
	_check(_story_cards().size() == 4, "Four nose cards are visible")
	_check(_all_text(_view).contains("摇出"), "Story action prose is rendered")
	await _capture("memory-nose-1440.png")
	await _click("一起补空格")
	_check(int(_view.support_level) == 3, "Actual GUI click chooses gap support")
	var cards := _story_cards()
	_check(bool(cards[1].get_meta("answer_hidden")) and bool(cards[3].get_meta("answer_hidden")), "H3 hides slots two and four")
	var gap_text := _all_text(_view)
	_check(not gap_text.contains("猫头鹰") and not gap_text.contains("蛋壳") and not gap_text.contains("nose"), "H3 does not leak missing actors through adjacent prose or heading")
	_check(not gap_text.contains("answer_chain_for_evaluator_only"), "Evaluator chain never rendered")
	_view._reveal_gap(2)
	await _layout()
	_check(_cues[-1].revealed_letter_positions.has(2), "Requested gap reveal is tracked")
	_view.start_practice()
	await _layout()
	_check(_cues[-1].answer_revealing_dimensions.is_empty(), "H0 legal meaning stimulus is not an answer cue")
	_check(int(_view.max_help_level) == 5, "H0 does not erase prior demonstration")
	_check(not _all_text(_view).contains("nose"), "Practice hides target spelling")
	_view.submit_response("Nose")
	_view.submit_response("nose")
	_check(not bool(_responses[-2].correct) and bool(_responses[-1].correct), "Exact spelling distinguishes case")
	_check(_responses[-1].observed_at is float or _responses[-1].observed_at is int, "Response uses numeric UTC Unix seconds")
	_check(not bool(_view.first_response.correct) and bool(_view.later_response.correct), "First and later responses remain separate")
	var snapshot: Dictionary = _view.get_resume()
	_view.setup(Content.get_entry("occ-89a38b8a39c8"), snapshot)
	await _layout()
	_check(str(_view.draft_response) == "nose" and int(_view.max_help_level) == 5, "Reopen preserves draft and actual prior help")
	_check(not bool(_view.first_response.correct), "Reopen preserves first error")
	_view._reveal_sequence()
	_check(int(_cues[-1].support_level) == 5, "Full sequence from H0 becomes an actual H5 cue")
	var apple_hits := Content.list_entries("", "", "apple")
	for hit: Dictionary in apple_hits:
		if str(hit.spelling_display) == "apple":
			_view.setup(Content.get_entry(str(hit.entry_id)), {"invocation_id":"memory-test/audio","attempt_id":"attempt-1"})
			break
	await _layout()
	_view.start_practice()
	_view._play_audio()
	_check(int(_cues[-1].support_level) >= 1 and str(_cues[-1].support_kind) == "whole_word_audio", "Extra target audio is recorded as real support")
	_check(_cues[-1].revealed_letter_positions.is_empty(), "Audio does not invent visible letters")
	_view.request_close("paused")
	_check(not _view._audio.playing, "Closing stops audio")
	var special := ["T-shirt", "café", "from... to...", "1st", "International Children's Day"]
	for word: String in special:
		var hits := Content.list_entries("", "", word)
		var found: Dictionary = {}
		for hit: Dictionary in hits:
			if str(hit.spelling_display) == word:
				found = Content.get_entry(str(hit.entry_id))
				break
		_view.setup(found, {"invocation_id":"memory-test/"+word,"attempt_id":"attempt-1"})
		await _layout()
		_check(not found.is_empty(), "Special target available "+word)
		_check(_story_cards().size() <= 4, "Visible card limit "+word)
		if word == "International Children's Day":
			_check(found.letter_slots.size() == 25 and found.story_beats.size() == 7, "Longest target has 25 letters and seven frames")
			_view.set_support(2)
			_view.navigate_beat(6)
			_check(int(_view.current_beat) == 1 and _view.seen_beats.size() == 1, "First-step cue neither changes page nor marks unshown frames seen")
			_view.set_support(5)
			_view.navigate_beat(6)
			await _layout()
			_check(_story_cards().size() == 1 and int(_story_cards()[0].get_meta("letter_position")) == 25, "Long target ends at real position 25")
			await _capture("memory-long-word-1440.png")
	root.size = Vector2i(960, 640)
	host.position = Vector2(30, 30)
	host.size = Vector2(900, 580)
	_view.setup(Content.get_entry("occ-52a5c9558bb9"), {"invocation_id":"memory-test/small","attempt_id":"attempt-1"})
	await _layout()
	_check(_view.size.x <= 900.1, "Component fits 960px viewport host")
	for card: Control in _story_cards():
		_check(card.get_global_rect().end.x <= host.get_global_rect().end.x+1, "Card stays within narrow horizontal viewport")
	_view.start_practice()
	await _layout()
	_view.submit_response("T-shirt")
	_check(bool(_responses[-1].practice_is_extra), "Recognition spelling stays voluntary extra practice")
	await _capture("memory-practice-960.png")
	_view.request_close("paused")
	_check(str(_closed[-1].result) == "paused" and str(_closed[-1].progress.entry_id) == "occ-52a5c9558bb9", "Close emits recoverable paused snapshot")
	var mismatch: Dictionary = _view.get_resume()
	mismatch.content_revision = "missing-old-version"
	var cue_count := _cues.size()
	_view.setup(Content.get_entry("occ-52a5c9558bb9"), mismatch)
	await _layout()
	_check(bool(_view._content_unavailable) and _cues.size() == cue_count, "Version mismatch does not silently replace old content or emit new teaching")
	_check(_file_hash("user://island-save-v1.json") == _production_hash, "Production save unchanged")
	_check(_file_hash("user://island-save-v1.json.bak") == _production_backup_hash, "Production backup unchanged")
	var report := {"status":"passed" if _failures.is_empty() else "failed", "checks":_checks, "failures":_failures,
		"entries":1314,"icons":26,"source_library_required":false,
		"production_save_unchanged":_file_hash("user://island-save-v1.json") == _production_hash and _file_hash("user://island-save-v1.json.bak") == _production_backup_hash,
		"scope":"offline package, real component GUI clicks, support exposure, exact writing, restore, narrow layout; no learning-effect claim"}
	var output := ProjectSettings.globalize_path("res://../.local/validation/memory-story-report.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify(report))
	host.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _story_cards() -> Array:
	var container: Node = _view.find_child("StoryCards", true, false)
	return container.get_children() if container != null else []

func _all_text(node: Node) -> String:
	var value := ""
	if node is Label or node is Button:
		value += str(node.text)+"\n"
	for child: Node in node.get_children():
		value += _all_text(child)
	return value

func _click(caption: String) -> void:
	var candidate := _find_button(_view, caption)
	_check(candidate != null, "Button exists: "+caption)
	if candidate == null:
		return
	_view._scroll.ensure_control_visible(candidate)
	await _layout()
	var point: Vector2 = candidate.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up, true)
	await _layout()

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and str(node.text) == caption:
		return node
	for child: Node in node.get_children():
		var found := _find_button(child, caption)
		if found != null:
			return found
	return null

func _layout() -> void:
	for i: int in range(5):
		await process_frame

func _capture(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://../.local/validation/"+filename)
	picture.save_png(path)

func _file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("FAIL: "+label)
