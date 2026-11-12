extends Control
## V4 Diegetic Storybook Dialogue Overlay.
## Replaces full-screen quiz/exam popups with an airy, world-anchored speech bubble
## above the speaking character + a compact bottom graphical response ribbon +
## optional AI Safe Companion free-chat bar. The 3D world remains alive and visible!

signal action_triggered(action_id: String)
signal ai_chat_submitted(npc_id: String, message: String)
signal speak_requested(text: String, lang: String)
signal follow_along_submitted(target_text: String, mode: String, rms_energy: float, duration_ms: int)
signal hint_toggled(npc_id: String, shown: bool)
signal closed

const Style = preload("res://ui/island_theme.gd")

var camera: Camera3D
var anchor_world_pos := Vector3.ZERO
var has_world_anchor := false
var current_npc_id := ""
var current_en := ""
var current_zh := ""
var zh_visible := false
var last_captured_wav_b64 := ""
var _mic_player: AudioStreamPlayer
var _mic_capture: AudioEffectCapture

var _bubble_card: PanelContainer
var _speaker_badge: Label
var _en_label: Label
var _zh_label: Label
var _hint_btn: Button
var _chat_toggle_btn: Button
var _chat_box: HBoxContainer
var _chat_input: LineEdit
var _ribbon_panel: PanelContainer
var _choices_flow: HBoxContainer

func _ready() -> void:
	name = "DiegeticDialogueOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_build_ui()

func _build_ui() -> void:
	# Floating World Speech Bubble
	_bubble_card = PanelContainer.new()
	_bubble_card.name = "WorldSpeechBubble"
	_bubble_card.custom_minimum_size = Vector2(360, 118)
	var b_style := Style.box(Color(0.99, 0.98, 0.94, 0.97), 22, 18)
	b_style.border_color = Color("d8ccb2")
	b_style.set_border_width_all(2)
	b_style.shadow_color = Color(0.20, 0.16, 0.10, 0.16)
	b_style.shadow_size = 14
	b_style.shadow_offset = Vector2(0, 6)
	_bubble_card.add_theme_stylebox_override("panel", b_style)
	add_child(_bubble_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_bubble_card.add_child(col)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	col.add_child(top_row)

	_speaker_badge = Label.new()
	_speaker_badge.add_theme_font_size_override("font_size", 16)
	_speaker_badge.add_theme_color_override("font_color", Color("6f5a38"))
	_speaker_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_speaker_badge)

	var listen_btn := _mini_pill("🔊 听读音")
	listen_btn.pressed.connect(func():
		if not current_en.is_empty():
			speak_requested.emit(current_en, "en")
	)
	top_row.add_child(listen_btn)

	var follow_btn := _mini_pill("🎤 跟读试试")
	follow_btn.pressed.connect(func(): _start_follow_along("voice"))
	top_row.add_child(follow_btn)

	var shy_btn := _mini_pill("🤫 默读")
	shy_btn.tooltip_text = "害羞或安静环境下，在心里默读也可以获得鼓励星"
	shy_btn.pressed.connect(func(): _start_follow_along("shy"))
	top_row.add_child(shy_btn)

	_hint_btn = _mini_pill("💡 中文贴士")
	_hint_btn.pressed.connect(func():
		zh_visible = not zh_visible
		_zh_label.visible = zh_visible and not current_zh.is_empty()
		hint_toggled.emit(current_npc_id, zh_visible)
	)
	top_row.add_child(_hint_btn)

	_chat_toggle_btn = _mini_pill("💬 自由聊")
	_chat_toggle_btn.pressed.connect(func():
		_chat_box.visible = not _chat_box.visible
		if _chat_box.visible:
			_chat_input.grab_focus()
	)
	top_row.add_child(_chat_toggle_btn)

	var close_x := _mini_pill("✕")
	close_x.pressed.connect(dismiss)
	top_row.add_child(close_x)

	_en_label = Label.new()
	_en_label.add_theme_font_size_override("font_size", 22)
	_en_label.add_theme_color_override("font_color", Style.INK)
	_en_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_en_label.custom_minimum_size.x = 380
	col.add_child(_en_label)

	_zh_label = Label.new()
	_zh_label.add_theme_font_size_override("font_size", 16)
	_zh_label.add_theme_color_override("font_color", Style.MUTED)
	_zh_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zh_label.custom_minimum_size.x = 380
	col.add_child(_zh_label)

	# Expandable Safe AI Companion Free-Chat Input
	_chat_box = HBoxContainer.new()
	_chat_box.add_theme_constant_override("separation", 8)
	_chat_box.hide()
	col.add_child(_chat_box)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "用英文或中文和伙伴打招呼吧 (例如: Hello! Nice hat!)"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size.y = 38
	_chat_input.text_submitted.connect(_submit_chat)
	_chat_box.add_child(_chat_input)

	var send_btn := _mini_pill("发送 ✨")
	send_btn.pressed.connect(func(): _submit_chat(_chat_input.text))
	_chat_box.add_child(send_btn)

	# Compact Bottom Floating Response Ribbon (keeps 80% of 3D world visible!)
	_ribbon_panel = PanelContainer.new()
	_ribbon_panel.name = "BottomResponseRibbon"
	var r_style := Style.box(Color(0.98, 0.96, 0.91, 0.95), 24, 14)
	r_style.border_color = Color("dcd0b8")
	r_style.set_border_width_all(2)
	r_style.shadow_color = Color(0.18, 0.14, 0.08, 0.14)
	r_style.shadow_size = 12
	_ribbon_panel.add_theme_stylebox_override("panel", r_style)
	add_child(_ribbon_panel)

	_choices_flow = HBoxContainer.new()
	_choices_flow.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices_flow.add_theme_constant_override("separation", 12)
	_ribbon_panel.add_child(_choices_flow)

func _mini_pill(caption: String) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Style.INK)
	var sb := Style.box(Color("efeadd"), 14, 8)
	sb.shadow_size = 0
	btn.add_theme_stylebox_override("normal", sb)
	var hv := Style.box(Color("e4ecda"), 14, 8)
	hv.shadow_size = 0
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	return btn

func _submit_chat(raw_text: String) -> void:
	var cleaned := raw_text.strip_edges()
	if cleaned.is_empty():
		return
	_chat_input.clear()
	ai_chat_submitted.emit(current_npc_id, cleaned)

func open_conversation(config: Dictionary) -> void:
	current_npc_id = str(config.get("npc_id", "neighbor"))
	var speaker_name := str(config.get("speaker", "小岛伙伴"))
	current_en = str(config.get("en", "Hello! Welcome to Alphabet Island!"))
	current_zh = str(config.get("zh", ""))
	zh_visible = bool(config.get("show_zh_immediately", false))
	anchor_world_pos = config.get("world_pos", Vector3.ZERO)
	has_world_anchor = config.has("world_pos")

	_speaker_badge.text = "✦ " + speaker_name
	_en_label.text = current_en
	_zh_label.text = current_zh
	_zh_label.visible = zh_visible and not current_zh.is_empty()
	_hint_btn.visible = not current_zh.is_empty()
	_chat_box.hide()

	_rebuild_choices(config.get("actions", []))
	show()
	_update_positions()
	if bool(config.get("auto_speak", true)) and not current_en.is_empty():
		speak_requested.emit(current_en, "en")

func _start_follow_along(mode: String) -> void:
	var phrase := current_en if not current_en.is_empty() else "Hello!"
	last_captured_wav_b64 = ""
	if mode == "shy":
		follow_along_submitted.emit(phrase, "shy", 0.0, 0)
		return
	if DisplayServer.get_name() == "headless":
		follow_along_submitted.emit(phrase, "voice", 0.042, 850)
		return
	_zh_label.text = "🎙️ 正在温暖倾听你跟读：「%s」……（离线语音识别中）" % phrase.left(44)
	_zh_label.visible = true
	_update_positions()

	var rec_info := await _record_mic_wav_16k(1.35)
	last_captured_wav_b64 = str(rec_info.get("wav_b64", ""))
	var est_rms := float(rec_info.get("rms", 0.035))
	var dur_ms := int(rec_info.get("duration_ms", 1100))
	if is_inside_tree() and visible:
		follow_along_submitted.emit(phrase, "voice", est_rms, dur_ms)

func _record_mic_wav_16k(duration_sec: float) -> Dictionary:
	var mix_rate := float(AudioServer.get_mix_rate())
	var can_capture := bool(ProjectSettings.get_setting("audio/driver/enable_input", false)) and mix_rate >= 8000.0
	if not can_capture:
		await get_tree().create_timer(0.85).timeout
		return {"wav_b64": "", "rms": 0.035, "duration_ms": 880}

	var bus_idx := AudioServer.get_bus_index("V4MicBus")
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "V4MicBus")
		AudioServer.set_bus_mute(bus_idx, true)
		_mic_capture = AudioEffectCapture.new()
		_mic_capture.buffer_length = 3.0
		AudioServer.add_bus_effect(bus_idx, _mic_capture)
	else:
		_mic_capture = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture

	if not is_instance_valid(_mic_player):
		_mic_player = AudioStreamPlayer.new()
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = "V4MicBus"
		add_child(_mic_player)

	if _mic_capture != null:
		_mic_capture.clear_buffer()
	_mic_player.play()
	await get_tree().create_timer(duration_sec).timeout
	_mic_player.stop()

	if _mic_capture == null:
		return {"wav_b64": "", "rms": 0.035, "duration_ms": int(duration_sec * 1000.0)}

	var avail := _mic_capture.get_frames_available()
	if avail < 400:
		return {"wav_b64": "", "rms": 0.032, "duration_ms": int(duration_sec * 1000.0)}

	var raw_frames: PackedVector2Array = _mic_capture.get_buffer(avail)
	var target_sr := 16000
	var step := maxf(1.0, mix_rate / float(target_sr))
	var out_count := int(float(raw_frames.size()) / step)
	if out_count < 160:
		return {"wav_b64": "", "rms": 0.032, "duration_ms": int(duration_sec * 1000.0)}

	var pcm := PackedByteArray()
	pcm.resize(out_count * 2)
	var sum_sq := 0.0
	for i in range(out_count):
		var src_i := mini(raw_frames.size() - 1, int(float(i) * step))
		var mono := clampf((raw_frames[src_i].x + raw_frames[src_i].y) * 0.5, -1.0, 1.0)
		sum_sq += mono * mono
		pcm.encode_s16(i * 2, clampi(int(round(mono * 32767.0)), -32768, 32767))

	var rms := sqrt(sum_sq / float(out_count))
	if rms < 0.0015:
		# Silence / unplugged mic -> let server use friendly envelope mode
		return {"wav_b64": "", "rms": 0.032, "duration_ms": int(duration_sec * 1000.0)}

	var data_len := pcm.size()
	var header := PackedByteArray()
	header.resize(44)
	header.encode_u8(0, 82); header.encode_u8(1, 73); header.encode_u8(2, 70); header.encode_u8(3, 70) # RIFF
	header.encode_u32(4, 36 + data_len)
	header.encode_u8(8, 87); header.encode_u8(9, 65); header.encode_u8(10, 86); header.encode_u8(11, 69) # WAVE
	header.encode_u8(12, 102); header.encode_u8(13, 109); header.encode_u8(14, 116); header.encode_u8(15, 32) # fmt 
	header.encode_u32(16, 16)
	header.encode_u16(20, 1) # PCM
	header.encode_u16(22, 1) # Mono
	header.encode_u32(24, target_sr)
	header.encode_u32(28, target_sr * 2)
	header.encode_u16(32, 2)
	header.encode_u16(34, 16)
	header.encode_u8(36, 100); header.encode_u8(37, 97); header.encode_u8(38, 116); header.encode_u8(39, 97) # data
	header.encode_u32(40, data_len)
	header.append_array(pcm)

	return {
		"wav_b64": Marshalls.raw_to_base64(header),
		"rms": rms,
		"duration_ms": int(float(out_count) * 1000.0 / float(target_sr))
	}

func show_speech_encouragement(reply: Dictionary) -> void:
	var badge := str(reply.get("cheer_badge", "🌟 自信开口星"))
	var rep_en := str(reply.get("reply_en", current_en))
	var rep_zh := str(reply.get("reply_zh", ""))
	_en_label.text = rep_en
	_zh_label.text = "%s · %s" % [badge, rep_zh]
	_zh_label.visible = true
	_update_positions()
	if not rep_en.is_empty():
		speak_requested.emit(rep_en, "en")

func show_ai_reply(reply: Dictionary) -> void:
	current_en = str(reply.get("reply_en", current_en))
	current_zh = str(reply.get("reply_zh", current_zh))
	_en_label.text = current_en
	_zh_label.text = current_zh
	_zh_label.visible = true
	if reply.get("suggestions") is Array and not (reply.suggestions as Array).is_empty():
		var actions: Array = []
		for sug: Variant in reply.suggestions:
			var s_text := str(sug)
			actions.append({"label": "💬 " + s_text, "id": "ai_quick:" + s_text, "primary": true})
		actions.append({"label": "先聊到这里", "id": "close"})
		_rebuild_choices(actions)
	_update_positions()
	if not current_en.is_empty():
		speak_requested.emit(current_en, "en")

func _rebuild_choices(actions: Array) -> void:
	for child: Node in _choices_flow.get_children():
		_choices_flow.remove_child(child)
		child.queue_free()
	for entry: Variant in actions:
		if not entry is Dictionary:
			continue
		var act := entry as Dictionary
		var btn := Button.new()
		btn.text = str(act.get("label", "继续"))
		btn.disabled = bool(act.get("disabled", false))
		btn.custom_minimum_size = Vector2(150, 52)
		btn.add_theme_font_size_override("font_size", 18)
		var primary := bool(act.get("primary", false))
		var fill := Color("dce9cc") if primary else Color("f3efe3")
		var sb := Style.box(fill, 18, 14)
		sb.border_color = Color("8fb573") if primary else Color("d7cbb2")
		sb.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", sb)
		var hv := Style.box(fill.lightened(0.06), 18, 14)
		hv.border_color = Color("6e9c52") if primary else Color("bba988")
		hv.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hv)
		btn.add_theme_stylebox_override("pressed", hv)
		btn.add_theme_color_override("font_color", Style.INK)
		var act_id := str(act.get("id", "close"))
		btn.set_meta("action_id", act_id)
		btn.pressed.connect(func():
			if act_id.begins_with("ai_quick:"):
				_submit_chat(act_id.trim_prefix("ai_quick:"))
			elif act_id == "close":
				dismiss()
			else:
				action_triggered.emit(act_id)
		)
		_choices_flow.add_child(btn)

func dismiss() -> void:
	if not visible:
		return
	hide()
	closed.emit()

func _process(_delta: float) -> void:
	if visible:
		_update_positions()

func _update_positions() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x < 10:
		vp_size = Vector2(1440, 900)
	_bubble_card.reset_size()
	var bsize := _bubble_card.get_combined_minimum_size()
	bsize.x = clampf(bsize.x, 380.0, 540.0)
	_bubble_card.size = bsize

	var target_screen := Vector2(vp_size.x * 0.5, vp_size.y * 0.30)
	if has_world_anchor and is_instance_valid(camera) and not camera.is_position_behind(anchor_world_pos + Vector3(0, 2.35, 0)):
		target_screen = camera.unproject_position(anchor_world_pos + Vector3(0, 2.45, 0))

	var bx := clampf(target_screen.x - bsize.x * 0.5, 28.0, vp_size.x - bsize.x - 28.0)
	var by := clampf(target_screen.y - bsize.y - 16.0, 76.0, vp_size.y - bsize.y - 140.0)
	_bubble_card.position = Vector2(bx, by)

	_ribbon_panel.reset_size()
	var rsize := _ribbon_panel.get_combined_minimum_size()
	rsize.x = minf(maxf(rsize.x, 420.0), vp_size.x - 64.0)
	_ribbon_panel.size = rsize
	_ribbon_panel.position = Vector2((vp_size.x - rsize.x) * 0.5, vp_size.y - rsize.y - 22.0)
