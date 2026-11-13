extends VBoxContainer
## V5 Object-Grounded Compact Memory Card (`memory_card.gd`).
## Displays:
##   1. Physical Object Core Noun Badge (`object_en` · `object_zh`)
##   2. Situational English Sentence (`EnglishText`)
##   3. Collapsible Chinese Translation & Activity Tip (`ChineseText`)
##   4. Neural TTS Listen + Optional Mic Follow-Along + 1-Click 3D Memory Palace Link
## Listening and optional practice never change formal learning scores.

const Style = preload("res://ui/island_theme.gd")
const Bridge = preload("res://core/ai_companion_bridge.gd")
var game: Node
var english := ""
var spoken_english := ""
var audio_path := ""
var _hint: Label
var _status: Label
var _listen_button: Button
var _follow_button: Button
var _voice: AudioStreamPlayer
var _bridge: Node
var _request: HTTPRequest
var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _mic_bus := ""
var _frames := PackedVector2Array()
var _recording := false
var _elapsed := 0.0
var _record_seconds := 6.0
var _sample_rate := 48000.0

func setup(host: Node, content: Dictionary, actions: Array) -> void:
	game = host
	name = "MemoryCard"
	english = str(content.get("english", ""))
	spoken_english = str(content.get("spoken_english", english))
	audio_path = str(content.get("audio", ""))
	var obj_en := str(content.get("object_en", "")).strip_edges()
	var obj_zh := str(content.get("object_zh", "")).strip_edges()

	add_theme_constant_override("separation", 10)
	_bridge = Bridge.new()
	add_child(_bridge)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -5
	add_child(_voice)

	var top := HBoxContainer.new()
	top.name = "EnglishTools"
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	var heading: Label = game.ui.label("眼前实物英语", 16, Style.SAGE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)

	_listen_button = _tool_button("听读音", "Listen", "speaker", _listen)
	top.add_child(_listen_button)
	_follow_button = _tool_button("跟读试试", "FollowAlong", "mic", _toggle_follow_along)
	top.add_child(_follow_button)
	var hint_button := _tool_button("中文贴士", "ChineseHint", "bulb", _toggle_hint)
	hint_button.toggle_mode = true
	top.add_child(hint_button)

	# Layer 1: Crisp Physical Object Core Word Pill (so child never confuses sentence for object name!)
	if not obj_en.is_empty():
		var badge_panel := PanelContainer.new()
		badge_panel.name = "ObjectWordBadge"
		var b_sb := Style.keycap(Color("f4efe0"), Color("d9cbb0"), 2, 14, 12, 7)
		b_sb.shadow_size = 0
		badge_panel.add_theme_stylebox_override("panel", b_sb)
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		ic.texture = Style.icon("sparkle")
		ic.custom_minimum_size = Vector2(18, 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_row.add_child(ic)
		var obj_en_lbl: Label = game.ui.label(obj_en, 19, Style.INK)
		obj_en_lbl.add_theme_font_override("font", Style.heading_font())
		badge_row.add_child(obj_en_lbl)
		if not obj_zh.is_empty():
			var sep_lbl: Label = game.ui.label("·  " + obj_zh, 16, Style.MUTED)
			sep_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sep_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			badge_row.add_child(sep_lbl)
		badge_panel.add_child(badge_row)
		add_child(badge_panel)

	# Layer 2: Authentic Situational Sentence at This Object
	var phrase: Label = game.ui.label(english, 23)
	phrase.name = "EnglishText"
	phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phrase.add_theme_constant_override("line_spacing", 4)
	add_child(phrase)

	_hint = game.ui.label(str(content.get("hint", "")), 17, Style.MUTED)
	_hint.name = "ChineseText"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.hide()
	add_child(_hint)

	_status = game.ui.label("", 16, Style.SAGE)
	_status.name = "PracticeStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()
	add_child(_status)

	var divider := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Style.LINE
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	add_child(divider)

	var source_row := HBoxContainer.new()
	source_row.name = "Source"
	source_row.add_theme_constant_override("separation", 12)
	add_child(source_row)
	source_row.add_child(game.ui.label("定位", 15, Style.MUTED))
	var source_text: Label = game.ui.label(str(content.get("source", "")), 15, Style.MUTED)
	source_text.name = "SourceText"
	source_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_row.add_child(source_text)

	var footer := HBoxContainer.new()
	footer.name = "CardActions"
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	add_child(footer)
	var first: Button
	for entry: Dictionary in actions:
		var action_button: Button = game.ui.button(str(entry.label), str(entry.id), bool(entry.get("primary", false)), Vector2(108, 42))
		action_button.disabled = bool(entry.get("disabled", false))
		action_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var act_icon := str(entry.get("icon", ""))
		if not act_icon.is_empty():
			action_button.icon = Style.icon(act_icon)
			action_button.add_theme_constant_override("icon_max_width", 18)
			action_button.add_theme_constant_override("h_separation", 6)
		_compact_style(action_button, 16, 9)
		footer.add_child(action_button)
		if first == null and not action_button.disabled:
			first = action_button
	if first:
		game.ui._focus_if_current.call_deferred(first.get_instance_id())
	minimum_size_changed.connect(game.ui._layout.call_deferred)
	get_window().focus_exited.connect(_cancel_practice)

func _tool_button(caption: String, node_name: String, icon_key: String, callback: Callable) -> Button:
	var result := Button.new()
	result.name = node_name
	result.text = caption
	if not icon_key.is_empty():
		result.icon = Style.icon(icon_key)
		result.add_theme_constant_override("icon_max_width", 17)
		result.add_theme_constant_override("h_separation", 5)
	result.theme_type_variation = "QuietButton"
	result.custom_minimum_size = Vector2(104, 38)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_compact_style(result, 15, 8)
	result.pressed.connect(callback)
	return result

func _compact_style(target: Button, font_size: int, padding: int) -> void:
	target.add_theme_font_size_override("font_size", font_size)
	var variant := str(target.theme_type_variation) if not str(target.theme_type_variation).is_empty() else "Button"
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var surface := game.ui.root.theme.get_stylebox(state_name, variant).duplicate() as StyleBoxFlat
		if surface != null:
			surface.set_content_margin_all(padding)
			target.add_theme_stylebox_override(state_name, surface)

func _toggle_hint() -> void:
	_hint.visible = not _hint.visible

func _set_status(message: String) -> void:
	_status.text = message
	_status.visible = not message.is_empty()

func _listen() -> void:
	if game.muted:
		_set_status("语音已关闭，可以在设置里开启。")
		return
	_voice.stop()
	_bridge.voice_player.stop()
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		_voice.stream = load(audio_path) as AudioStream
		if _voice.stream != null:
			_voice.play()
			_set_status("")
			return
	_bridge.muted = false
	_bridge.speak_text(spoken_english.replace(" / ", ", "), "en", "warm")
	_set_status("")

func _toggle_follow_along() -> void:
	if _recording:
		_finish_recording()
		return
	if DisplayServer.get_name() == "headless" or not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		_set_status("当前无法使用麦克风。可以先听读音，再跟着读一遍。")
		return
	_sample_rate = float(AudioServer.get_mix_rate())
	if _sample_rate < 16000.0:
		_set_status("麦克风暂时无法录音，可以先听读音。")
		return
	_voice.stop()
	_bridge.voice_player.stop()
	_bridge.muted = true
	if is_instance_valid(game.voice): game.voice.stop()
	if is_instance_valid(game.ai_bridge): game.ai_bridge.voice_player.stop()
	_mic_bus = "MemoryCardMic_%d" % get_instance_id()
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, _mic_bus)
	AudioServer.set_bus_mute(index, true)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(index, _capture)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = _mic_bus
	add_child(_mic_player)
	_frames.clear()
	_elapsed = 0.0
	_record_seconds = clampf(float(english.split(" ", false).size()) * 0.65 + 1.5, 5.0, 12.0)
	_recording = true
	_follow_button.text = "结束跟读"
	_listen_button.disabled = true
	_mic_player.play()
	_set_status("正在听你读，读完点「结束跟读」；最多录 %d 秒。" % int(ceilf(_record_seconds)))

func _process(delta: float) -> void:
	if not _recording: return
	_read_frames()
	_elapsed += delta
	if _elapsed >= _record_seconds: _finish_recording()

func _read_frames() -> void:
	if _capture != null:
		var count := _capture.get_frames_available()
		if count > 0: _frames.append_array(_capture.get_buffer(count))

func _stop_mic() -> void:
	_recording = false
	if is_instance_valid(_mic_player):
		_mic_player.stop()
		_mic_player.queue_free()
	_mic_player = null
	_capture = null
	if not _mic_bus.is_empty():
		var index := AudioServer.get_bus_index(_mic_bus)
		if index >= 0: AudioServer.remove_bus(index)
	_mic_bus = ""

func _finish_recording() -> void:
	_read_frames()
	_stop_mic()
	_follow_button.text = "跟读试试"
	_listen_button.disabled = false
	if _frames.size() < int(_sample_rate * 0.25):
		_frames.clear()
		_set_status("没有收到麦克风声音。检查麦克风后，可以再试一次。")
		return
	var step := _sample_rate / 16000.0
	var count := int(float(_frames.size()) / step)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var energy := 0.0
	for i in range(count):
		var frame: Vector2 = _frames[mini(_frames.size() - 1, int(float(i) * step))]
		var sample := clampf((frame.x + frame.y) * 0.5, -1.0, 1.0)
		energy += sample * sample
		pcm.encode_s16(i * 2, clampi(int(round(sample * 32767.0)), -32768, 32767))
	_frames.clear()
	var rms := sqrt(energy / float(count))
	if rms < 0.0015:
		_set_status("这次声音太轻，没听清。靠近麦克风，再试一次吧。")
		return
	var wav := "RIFF".to_ascii_buffer()
	wav.resize(44)
	wav.encode_u32(4, 36 + pcm.size())
	for chunk: Array in [[8, "WAVE"], [12, "fmt "], [36, "data"]]:
		var bytes: PackedByteArray = str(chunk[1]).to_ascii_buffer()
		for i in range(4): wav[int(chunk[0]) + i] = bytes[i]
	wav.encode_u32(16, 16)
	wav.encode_u16(20, 1)
	wav.encode_u16(22, 1)
	wav.encode_u32(24, 16000)
	wav.encode_u32(28, 32000)
	wav.encode_u16(32, 2)
	wav.encode_u16(34, 16)
	wav.encode_u32(40, pcm.size())
	wav.append_array(pcm)
	_submit_recording(Marshalls.raw_to_base64(wav), rms, int(float(count) / 16.0))

func _submit_recording(wav: String, rms: float, duration_ms: int) -> void:
	_request = HTTPRequest.new()
	_request.timeout = 10.0
	add_child(_request)
	_request.request_completed.connect(_speech_reply)
	_follow_button.disabled = true
	_set_status("正在听这次跟读……")
	var payload := {"target_text":english, "mode":"voice", "rms_energy":rms, "duration_ms":duration_ms, "wav_base64":wav}
	var error := _request.request(str(_bridge.base_url) + "/api/v4/speech/encourage", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_speech_reply(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _speech_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_instance_valid(_request): _request.queue_free()
	_request = null
	_follow_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("跟读服务暂时没连上。可以先听读音，再试一次。")
		return
	var reply: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not reply is Dictionary or not bool(reply.get("ok", false)):
		_set_status("这次没有收到跟读结果，可以再试一次。")
		return
	var transcript := str(reply.get("transcript", "")).strip_edges()
	_set_status("听到：%s\n可以对照上面的英语，再听一遍、读一遍。" % transcript if not transcript.is_empty() else "已录到声音，暂未识别出词句。可以听一遍读音后再试。")

func _cancel_practice() -> void:
	var was_busy := _recording or is_instance_valid(_request)
	_stop_mic()
	_frames.clear()
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null
	if was_busy and is_inside_tree():
		_follow_button.text = "跟读试试"
		_follow_button.disabled = false
		_listen_button.disabled = false
		_set_status("已暂停跟读，准备好后可以再试一次。")

func _exit_tree() -> void:
	_cancel_practice()
	if is_instance_valid(_voice): _voice.stop()
	if is_instance_valid(_bridge):
		_bridge.muted = true
		_bridge.voice_player.stop()
