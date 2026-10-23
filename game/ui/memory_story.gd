extends Control
## Optional story reader and supported writing practice. Persistence belongs to caller.
signal help_shown(event: Dictionary)
signal response_submitted(response: Dictionary)
signal progress_changed(snapshot: Dictionary)
signal close_requested(result: Dictionary)

const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const StoryStage = preload("res://ui/memory_story_stage.gd")
const SUPPORT_NAMES := ["自己想一想", "想想它住哪里", "给我第一步", "一起补空格", "一步一步接", "我们一起看"]
const SUPPORT_KINDS := ["unassisted_attempt", "location_and_meaning", "first_step", "gap_completion", "step_bridge", "full_demonstration"]

var entry: Dictionary = {}
var invocation_id := ""
var attempt_id := ""
var current_beat := 1
var seen_beats: Array = []
var support_level := 5
var max_help_level := 0
var view_mode := "story"
var cue_events: Array = []
var first_response: Variant = null
var later_response: Variant = null
var draft_response := ""
var _revealed_gaps: Array = []
var _bridge_position := 1
var _show_sequence := false
var _ready_done := false
var _setup_revision := 0
var _content_unavailable := false
var _body: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit
var _feedback := ""
var _audio: AudioStreamPlayer
var _rendering := false
var _show_parent_info := false
var _story_player: Control
var _animation_state: Dictionary = {}
var _animation_support_level := 5
var _reduced_motion := false
var _play_button: Button
var _pause_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_"+edge, 12)
	_scroll.add_child(margin)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	margin.add_child(_body)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_ready_done = true
	resized.connect(_fit_cards)
	if not entry.is_empty():
		_present_setup.call_deferred(_setup_revision)

func setup(value: Dictionary, resume: Dictionary = {}) -> void:
	_release_story_player(false)
	if is_instance_valid(_audio):
		_audio.stop()
	entry = value.duplicate(true)
	_setup_revision += 1
	invocation_id = str(resume.get("invocation_id", ""))
	attempt_id = str(resume.get("attempt_id", ""))
	current_beat = clampi(int(resume.get("current_beat", 1)), 1, maxi(1, entry.get("story_beats", []).size()))
	seen_beats = resume.get("seen_beats", []).duplicate(true)
	support_level = clampi(int(resume.get("support_level", 5)), 0, 5)
	_animation_state = resume.get("animation_state", {}).duplicate(true)
	_animation_support_level = support_level
	_reduced_motion = bool(_animation_state.get("reduced_motion", _reduced_motion))
	max_help_level = int(resume.get("max_help_level", 0))
	view_mode = str(resume.get("view_mode", "story"))
	cue_events = resume.get("cue_events", []).duplicate(true)
	first_response = resume.get("first_response", null)
	later_response = resume.get("later_response", null)
	draft_response = str(resume.get("draft_response", ""))
	_revealed_gaps = resume.get("revealed_gaps", []).duplicate()
	_bridge_position = int(resume.get("bridge_position", 1))
	_show_sequence = bool(resume.get("show_sequence", false))
	if _show_sequence:
		support_level = 5
	_content_unavailable = entry.is_empty()
	for key: String in ["entry_id", "content_revision", "codebook_revision"]:
		if resume.has(key) and str(resume[key]) != str(entry.get(key, "")):
			_content_unavailable = true
	_feedback = ""
	_show_parent_info = false
	if _ready_done:
		_present_setup.call_deferred(_setup_revision)

func _present_setup(revision: int) -> void:
	if revision != _setup_revision or not is_inside_tree():
		return
	_render()
	if not _content_unavailable:
		_record_visible_cue("restored_page" if not cue_events.is_empty() else "opened_page", "system")
		_emit_progress()

func get_resume() -> Dictionary:
	if is_instance_valid(_story_player):
		_animation_state = _story_player.snapshot()
	return {"invocation_id":invocation_id,"attempt_id":attempt_id,
		"entry_id":entry.get("entry_id", ""),"content_revision":entry.get("content_revision", ""),
		"codebook_revision":entry.get("codebook_revision", ""),"current_beat":current_beat,
		"seen_beats":seen_beats.duplicate(),"support_level":support_level,"max_help_level":max_help_level,
		"cue_events":cue_events.duplicate(true),"first_response":first_response,"later_response":later_response,
		"view_mode":view_mode,"draft_response":draft_response,"revealed_gaps":_revealed_gaps.duplicate(),
		"bridge_position":_bridge_position,"show_sequence":_show_sequence,
		"animation_state":_animation_state.duplicate(true)}

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if is_instance_valid(_story_player):
		_story_player.set_reduced_motion(value)

func set_paused(value: bool) -> void:
	if value:
		if is_instance_valid(_story_player):
			_story_player.pause()
		if is_instance_valid(_audio):
			_audio.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		set_paused(true)

func set_support(level: int) -> void:
	if _content_unavailable:
		return
	support_level = clampi(level, 0, 5)
	if support_level == 2:
		current_beat = 1
	_show_sequence = false
	_revealed_gaps.clear()
	_bridge_position = int(_beat_positions()[0]) if not _beat_positions().is_empty() else 1
	_render()
	_record_visible_cue("support_selected", "child")
	_emit_progress()

func navigate_beat(direction: int) -> void:
	if support_level == 2:
		return
	current_beat = clampi(current_beat+direction, 1, maxi(1, entry.get("story_beats", []).size()))
	_revealed_gaps.clear()
	_bridge_position = int(_beat_positions()[0]) if not _beat_positions().is_empty() else 1
	_render()
	_record_visible_cue("story_page", "child")
	_emit_progress()

func start_practice() -> void:
	view_mode = "practice"
	support_level = 0
	_show_sequence = false
	_revealed_gaps.clear()
	_feedback = "可以慢慢想，也可以随时请朋友帮忙。刚才看过的帮助会保留。"
	_render()
	_record_visible_cue("practice_started", "child")
	_emit_progress()
	if is_instance_valid(_input):
		_input.grab_focus()

func submit_response(value: String) -> void:
	if _content_unavailable or view_mode != "practice":
		return
	draft_response = value
	var correct := value == str(entry.get("spelling_display", ""))
	var response := {"response_id":_event_id("response"),"invocation_id":invocation_id,"attempt_id":attempt_id,
		"response_text":value,"correct":correct,"target_dimension":"orthography","task_mode":"meaning_to_spelling",
		"practice_is_extra":not bool(entry.get("task_permissions", {}).get("formal_spelling_eligible", false)),
		"observed_at":Time.get_unix_time_from_system(),"support_level":support_level,
		"prior_cue_event_count":cue_events.size(),"answer_visible":support_level == 5 or _show_sequence,
		"independent_claimed":false}
	if first_response == null:
		first_response = response.duplicate(true)
	else:
		later_response = response.duplicate(true)
	_feedback = "这一遍写对了。想再看看故事也可以。" if correct else "再看看顺序、大小写和标点，或请朋友帮忙。"
	response_submitted.emit(response)
	_emit_progress()
	_render()

func request_close(result: String = "paused") -> void:
	set_paused(true)
	if is_instance_valid(_audio):
		_audio.stop()
	_emit_progress()
	close_requested.emit({"invocation_id":invocation_id,"attempt_id":attempt_id,
		"result":"content_unavailable" if _content_unavailable else result,"progress":get_resume()})

func _render() -> void:
	if not _ready_done or _rendering:
		return
	_rendering = true
	_input = null
	_release_story_player(true)
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if _content_unavailable:
		_body.add_child(_label("这页暂时打不开", 27))
		_body.add_child(_label("我们先回到小岛。原来记到的位置会保留。", 19))
		_body.add_child(_button("返回小岛", func(): request_close("content_unavailable")))
		_rendering = false
		return
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_body.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var show_answer := support_level == 5 or _show_sequence
	heading.add_child(_label(str(entry.spelling_display) if show_answer else "把画面接起来", 30))
	heading.add_child(_label(str(entry.meaning_zh), 22))
	var exit := _button("以后再练", func(): request_close("paused"))
	exit.custom_minimum_size.x = 118
	header.add_child(exit)
	var permission := "这一页可以练习书写，也可以只看故事。" if bool(entry.get("task_permissions", {}).get("formal_spelling_eligible", false)) else "这一页先理解和认读；写一写是你自愿的额外练习。"
	if str(entry.get("requirement", "")) == "listen_speak":
		permission = "这一页以听和说为主；故事与写一写都可以自由选择。"
	_body.add_child(_label(permission, 16, Style.MUTED))
	if support_level >= 1:
		var location := str(entry.get("memory_home", {}).get("root_location_label", "回忆册"))
		_body.add_child(_label("故事住在："+location, 17, Style.MUTED))
	if support_level == 5:
		_body.add_child(_label("先懂意思："+str(entry.get("meaning_anchor", entry.meaning_zh)), 18))
	var support := HFlowContainer.new()
	support.add_theme_constant_override("h_separation", 7)
	support.add_theme_constant_override("v_separation", 7)
	_body.add_child(support)
	for level: int in range(6):
		var choice := _button(SUPPORT_NAMES[level], set_support.bind(level))
		choice.set_meta("support_level", level)
		choice.theme_type_variation = "PrimaryButton" if support_level == level else "QuietButton"
		choice.custom_minimum_size = Vector2(132, 40)
		choice.add_theme_font_size_override("font_size", 16)
		support.add_child(choice)
	if support_level <= 1:
		var question := "先想一想这个意思怎样写，想不起来就选一种帮助。"
		if view_mode == "story":
			question = "在脑海里接一接画面。想看故事时，点“我们一起看”。"
		_body.add_child(_label(question, 21))
		if support_level == 1:
			_body.add_child(_label("想想它住的地方，再想一想这个意思。", 18))
	else:
		_render_story_stage()
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 9)
	actions.add_theme_constant_override("v_separation", 7)
	_body.add_child(actions)
	var audio: Dictionary = entry.get("audio", {})
	if not audio.is_empty() and FileAccess.file_exists(str(audio.get("path", ""))):
		actions.add_child(_button("听一听这个词", _play_audio))
	actions.add_child(_button("看完整字母串", _reveal_sequence))
	if view_mode != "practice":
		actions.add_child(_button("遮住试一试", start_practice))
	else:
		actions.add_child(_button("回到故事", _return_to_story))
	if _show_sequence:
		_body.add_child(_label("完整拼写："+str(entry.spelling_display), 26))
		var token_texts: PackedStringArray = []
		for token: Dictionary in entry.get("reconstruction_tokens", []):
			var raw := str(token.get("raw", ""))
			token_texts.append("[空格]" if str(token.get("type", "")) == "space" else raw)
		_body.add_child(_label("按原位保留："+" · ".join(token_texts), 17, Style.MUTED))
	if view_mode == "practice":
		var form := HBoxContainer.new()
		_body.add_child(form)
		_input = LineEdit.new()
		_input.name = "SpellingInput"
		_input.placeholder_text = "在这里写一写，保留大小写和标点"
		_input.text = draft_response
		_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_input.custom_minimum_size.y = 48
		_input.text_changed.connect(func(value: String): draft_response = value; _emit_progress())
		_input.text_submitted.connect(submit_response)
		form.add_child(_input)
		form.add_child(_button("看看这一遍", func(): submit_response(_input.text)))
	if not _feedback.is_empty():
		_body.add_child(_label(_feedback, 18, Style.SAGE))
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 10)
	_body.add_child(footer)
	footer.add_child(_button("今天先到这里", func(): request_close("completed")))
	footer.add_child(_button("给家长的内容说明", _toggle_parent_info))
	if _show_parent_info:
		_render_parent_info()
	_rendering = false
	_fit_cards.call_deferred()

func _render_story_stage() -> void:
	var beats: Array = entry.get("story_beats", [])
	if beats.is_empty():
		return
	var beat: Dictionary = beats[current_beat-1]
	var positions: Array = beat.get("letter_positions", [])
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 14)
	_body.add_child(navigation)
	var previous := _button("上一页", navigate_beat.bind(-1))
	previous.disabled = current_beat <= 1 or support_level == 2
	navigation.add_child(previous)
	var page := _label("从第 1 格开始" if support_level == 2 else "第 %d / %d 页 · 字母位置 %s" % [current_beat, beats.size(), _positions_text(positions)], 18)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(page)
	var next := _button("下一页", navigate_beat.bind(1))
	next.disabled = current_beat >= beats.size() or support_level == 2
	navigation.add_child(next)
	if support_level == 2:
		positions = [1]
	elif support_level == 4:
		_bridge_position = clampi(_bridge_position, int(positions[0]), int(positions[-1]))
		positions = [_bridge_position]
	var visible_positions: Array = []
	for p: Variant in positions:
		if support_level != 3 or (int(p) % 2 != 0 and positions.size() > 1) or _revealed_gaps.has(int(p)):
			visible_positions.append(int(p))
	_render_animation(positions, visible_positions, str(beat.get("beat_id", "")))
	var cards := HFlowContainer.new()
	cards.name = "StoryCards"
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	_body.add_child(cards)
	for position_value: Variant in positions:
		var position := int(position_value)
		var is_gap := support_level == 3 and (position % 2 == 0 or positions.size() == 1) and not _revealed_gaps.has(position)
		cards.add_child(_slot_card(position, is_gap))
	if support_level == 3:
		_body.add_child(_label("按编号补回缺口。点空格可以请朋友揭示这一格。", 17, Style.MUTED))
	elif support_level == 4:
		_render_bridge_choices(int(beat.letter_positions[-1]))
	elif support_level == 2:
		_body.add_child(_label(_prompt_text(2), 17, Style.MUTED))

func _slot_card(position: int, is_gap: bool) -> PanelContainer:
	var slot: Dictionary = entry.letter_slots[position-1]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Style.SOFT if is_gap else Style.PAPER, 18, 12))
	card.set_meta("story_card", true)
	card.set_meta("letter_position", position)
	card.set_meta("answer_hidden", is_gap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	box.add_child(_label("第 %d 格" % position, 16, Style.MUTED))
	if is_gap:
		var reveal := _button("?\n请朋友揭示", _reveal_gap.bind(position))
		reveal.custom_minimum_size = Vector2(120, 66)
		box.add_child(reveal)
		box.add_child(_label("这一格先留给你想。", 16, Style.MUTED))
	else:
		var caption := "%s · %s" % [str(slot.raw_character), str(slot.anchor_zh)]
		if int(slot.occurrence) > 1:
			caption += "（第%d次）" % int(slot.occurrence)
		box.add_child(_label(caption, 20))
		var step: Dictionary = entry.get("steps", [])[position-1]
		# A visible step may name the next, hidden actor. H3 therefore hides action
		# prose as well as the missing image, rather than leaking the answer in text.
		if support_level != 3:
			box.add_child(_label(str(step.get("action", step.get("text", ""))), 17))
	return card

func _render_animation(positions: Array, visible_positions: Array, frame_id: String) -> void:
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	_body.add_child(controls)
	_play_button = _button("播放故事", _play_story)
	_pause_button = _button("暂停", func():
		if is_instance_valid(_story_player): _story_player.pause())
	controls.add_child(_play_button)
	controls.add_child(_pause_button)
	controls.add_child(_button("再看一次", _replay_story))
	controls.add_child(_button("逐步看", _step_story))
	_story_player = StoryStage.new()
	_story_player.name = "MemoryStoryStage"
	_story_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_story_player)
	var previous: Dictionary = _animation_state if str(_animation_state.get("beat_id", "")) == frame_id and _animation_support_level == support_level else {}
	_story_player.setup(entry, positions, visible_positions, support_level, _reduced_motion, previous)
	_story_player.set_beat_id(frame_id)
	_animation_support_level = support_level
	_animation_state = _story_player.snapshot()
	_story_player.step_presented.connect(_on_animation_step)
	_story_player.playback_changed.connect(_on_playback_changed)
	_update_playback_buttons()

func _release_story_player(keep_state: bool) -> void:
	if is_instance_valid(_story_player):
		if _story_player.playback_changed.is_connected(_on_playback_changed):
			_story_player.playback_changed.disconnect(_on_playback_changed)
		if _story_player.step_presented.is_connected(_on_animation_step):
			_story_player.step_presented.disconnect(_on_animation_step)
		_story_player.pause()
		if keep_state:
			_animation_state = _story_player.snapshot()
		_story_player = null
	_play_button = null
	_pause_button = null
	if not keep_state:
		_animation_state = {}

func _play_story() -> void:
	if is_instance_valid(_story_player):
		_scroll.ensure_control_visible(_story_player)
		_story_player.play.call_deferred()

func _replay_story() -> void:
	if is_instance_valid(_story_player):
		_scroll.ensure_control_visible(_story_player)
		_story_player.replay.call_deferred()

func _step_story() -> void:
	if is_instance_valid(_story_player):
		_scroll.ensure_control_visible(_story_player)
		_story_player.step.call_deferred()

func _on_playback_changed(value: Dictionary) -> void:
	_animation_state = value.duplicate(true)
	_update_playback_buttons()
	_emit_progress()

func _update_playback_buttons() -> void:
	if not is_instance_valid(_story_player) or not is_instance_valid(_play_button):
		return
	var status := str(_animation_state.get("playback_status", "paused"))
	_play_button.disabled = _story_player.events.is_empty() or status == "playing"
	_play_button.text = "再播放" if status == "completed" else "继续播放" if float(_animation_state.get("phase", 0.0)) > 0 else "播放故事"
	_pause_button.disabled = status != "playing"

func _on_animation_step(value: Dictionary) -> void:
	if not is_instance_valid(_story_player) or support_level <= 1:
		return
	var event := _base_cue("story_animation_step", "child")
	event["animation_action"] = str(value.get("action_kind", ""))
	event["animated_letter_position"] = int(value.get("actor_position", 0))
	event["revealed_letter_positions"] = value.get("revealed_letter_positions", []).duplicate()
	event["answer_revealing_dimensions"] = ["meaning", "orthography"]
	event["asset_or_content_ref"] = str(value.get("event_id", ""))
	_store_cue(event)
	_emit_progress()

func _render_bridge_choices(last_position: int) -> void:
	if _bridge_position >= last_position:
		_body.add_child(_label("这一页接好了，可以翻到下一页。", 18, Style.SAGE))
		return
	var target_position := _bridge_position+1
	var slot: Dictionary = entry.letter_slots[target_position-1]
	var target_letter := str(slot.letter)
	var decoy := "A" if target_letter != "A" else "B"
	_body.add_child(_label("第 %d 格会接到哪个伙伴？" % target_position, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var candidates: Array[String] = [target_letter, decoy]
	if target_position % 2 == 0:
		candidates.reverse()
	for letter: String in candidates:
		var detail := Content.codebook_item(letter)
		var choice := _button(str(detail.get("representative_label_zh", letter)), _bridge_choice.bind(letter, target_position))
		choice.icon = Content.icon(letter)
		choice.add_theme_constant_override("icon_max_width", 66)
		choice.custom_minimum_size = Vector2(180, 78)
		row.add_child(choice)

func _bridge_choice(letter: String, position: int) -> void:
	if str(entry.letter_slots[position-1].letter) == letter:
		_bridge_position = position
		_feedback = "接上了，看看它怎样把故事往下带。"
	else:
		_feedback = "这次故事里是另一个伙伴。再看一看，也可以直接看示范。"
	_render()
	_record_visible_cue("step_bridge_choice", "child")
	_emit_progress()

func _reveal_gap(position: int) -> void:
	if not _revealed_gaps.has(position):
		_revealed_gaps.append(position)
	_render()
	_record_visible_cue("gap_revealed", "child")
	_emit_progress()

func _reveal_sequence() -> void:
	support_level = 5
	_show_sequence = true
	_render()
	_record_visible_cue("full_sequence", "child")
	_emit_progress()

func _return_to_story() -> void:
	view_mode = "story"
	set_support(5)

func _play_audio() -> void:
	var audio: Dictionary = entry.get("audio", {})
	var path := str(audio.get("path", ""))
	if path.is_empty() or str(audio.get("text", "")) != str(entry.get("spelling_display", "")) or not FileAccess.file_exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_audio.stream = stream
	_audio.play()
	var event := _base_cue("whole_word_audio", "child")
	event["support_level"] = maxi(1, support_level)
	event["support_kind"] = "whole_word_audio"
	event["asset_or_content_ref"] = path
	event["revealed_letter_positions"] = []
	event["answer_revealing_dimensions"] = ["spoken_expression"]
	event["audio_role"] = "additional_cue"
	_store_cue(event)
	_emit_progress()

func _record_visible_cue(kind: String, requested_by: String) -> void:
	var event := _base_cue(kind, requested_by)
	var positions: Array = []
	var dimensions: Array = [] if support_level == 0 else ["meaning"]
	if support_level == 5 or _show_sequence:
		for p: int in range(1, entry.get("letter_slots", []).size()+1):
			positions.append(p)
	elif support_level == 2:
		positions = [1]
	elif support_level == 3:
		for p: Variant in _beat_positions():
			if int(p) % 2 != 0 and _beat_positions().size() > 1 or _revealed_gaps.has(int(p)):
				positions.append(int(p))
	elif support_level == 4:
		positions = [_bridge_position]
		if _bridge_position < int(_beat_positions()[-1]):
			positions.append(_bridge_position+1)
	if not positions.is_empty():
		dimensions.append("orthography")
	event["revealed_letter_positions"] = positions
	event["answer_revealing_dimensions"] = dimensions
	event["displayed_stimulus_dimensions"] = ["meaning"]
	# Partial cues do not claim the whole story frame was displayed.
	if support_level == 5:
		var beat: Dictionary = entry.story_beats[current_beat-1]
		if not seen_beats.has(str(beat.beat_id)):
			seen_beats.append(str(beat.beat_id))
	_store_cue(event)

func _base_cue(kind: String, requested_by: String) -> Dictionary:
	return {"event_id":_event_id("cue"),"invocation_id":invocation_id,"attempt_id":attempt_id,
		"support_level":support_level,"support_kind":SUPPORT_KINDS[support_level],"display_event":kind,
		"asset_or_content_ref":"%s/frame-%d" % [str(entry.get("story_id", "")), current_beat],
		"requested_by":requested_by,"shown_at":Time.get_unix_time_from_system()}

func _store_cue(event: Dictionary) -> void:
	max_help_level = maxi(max_help_level, int(event.support_level))
	cue_events.append(event.duplicate(true))
	help_shown.emit(event)

func _emit_progress() -> void:
	progress_changed.emit(get_resume())

func _event_id(kind: String) -> String:
	return "%s/%s/%s/%d-%d" % [invocation_id, attempt_id, kind, Time.get_ticks_usec(), cue_events.size()]

func _beat_positions() -> Array:
	var beats: Array = entry.get("story_beats", [])
	return beats[current_beat-1].get("letter_positions", []) if not beats.is_empty() else []

func _prompt_text(level: int) -> String:
	for prompt: Dictionary in entry.get("guidance", []):
		if int(prompt.get("level", -1)) == level:
			return str(prompt.get("prompt", ""))
	return ""

func _positions_text(positions: Array) -> String:
	var words: PackedStringArray = []
	for p: Variant in positions:
		words.append(str(int(p)))
	return "、".join(words)

func _label(value: String, pixels: int = 19, color: Color = Style.INK) -> Label:
	var result := Style.text(value, pixels, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _button(caption: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size = Vector2(110, 42)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	return result

func _fit_cards() -> void:
	if not is_instance_valid(_body):
		return
	var cards := _body.find_child("StoryCards", true, false)
	if cards == null:
		return
	var width := clampf((_scroll.size.x-70.0)/4.0, 145.0, 270.0)
	for card: Control in cards.get_children():
		card.custom_minimum_size.x = width

func _toggle_parent_info() -> void:
	_show_parent_info = not _show_parent_info
	_render()

func _render_parent_info() -> void:
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", Style.box(Style.SOFT, 14, 14))
	_body.add_child(info)
	var box := VBoxContainer.new()
	info.add_child(box)
	box.add_child(_label(str(entry.get("content_status", {}).get("parent_note", "记忆故事仍待独立编辑复核。")), 16))
	box.add_child(_label("本次只记录实际提示、书写回应与浏览位置，不评定口语、听力或长期掌握。已有声音为逐字匹配的合成音频候选。", 16))
	var source: Dictionary = entry.get("source_unit", {})
	box.add_child(_label("来源册：%s；单元：%s" % [source.get("book_id", ""), ", ".join(source.get("unit_ids", []))], 14, Style.MUTED))
	box.add_child(_label("内容版本：%s\n固定页：%s" % [entry.get("content_revision", ""), entry.get("memory_home", {}).get("storage_slot", "")], 14, Style.MUTED))
	for ref: Dictionary in entry.get("source_refs", []):
		box.add_child(_label("词表印刷页 %s / 文件页 %s；课文页标注 %s" % [ref.get("page", "?"), ref.get("file_page", "?"), ref.get("listed_lesson_page", "未列")], 14, Style.MUTED))
