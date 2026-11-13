extends Control
## V5 Diegetic Storybook Dialogue Overlay.
## World-anchored speech cloud with a real drawn pointer tail, crisp vector tool chips,
## non-overlapping bottom response ribbon, and 1–5 keyboard quick-response support.

signal action_triggered(action_id: String)
signal ai_chat_submitted(npc_id: String, message: String)
signal speak_requested(text: String, lang: String)
signal follow_along_submitted(target_text: String, mode: String, rms_energy: float, duration_ms: int)
signal hint_toggled(npc_id: String, shown: bool)
signal overlay_visibility_changed(is_open: bool)
signal closed

const Style = preload("res://ui/island_theme.gd")

class SpeechTail extends Control:
	var fill_color := Color(0.996, 0.986, 0.952, 0.98)
	var border_color := Color("d6c6a8")
	var tip_offset_x := 0.0

	func _draw() -> void:
		var cx := clampf(size.x * 0.5 + tip_offset_x, 26.0, size.x - 26.0)
		var pts := PackedVector2Array([
			Vector2(cx - 11.0, 0.0),
			Vector2(cx + 11.0, 0.0),
			Vector2(cx, 13.0)
		])
		draw_colored_polygon(pts, fill_color)
		draw_line(pts[0], pts[2], border_color, 2.2, true)
		draw_line(pts[1], pts[2], border_color, 2.2, true)

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
var _tail: SpeechTail
var _speaker_badge: Label
var _en_label: Label
var _zh_panel: PanelContainer
var _zh_label: Label
var _hint_btn: Button
var _chat_toggle_btn: Button
var _chat_box: HBoxContainer
var _chat_input: LineEdit
var _ribbon_panel: PanelContainer
var _choices_flow: HBoxContainer
var _choice_buttons: Array[Button] = []
var _smoothed_bubble_pos := Vector2(-1.0, -1.0)

func _ready() -> void:
	name = "DiegeticDialogueOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func():
		overlay_visibility_changed.emit(visible)
		if not visible:
			_smoothed_bubble_pos = Vector2(-1.0, -1.0)
	)
	hide()
	_build_ui()

func _build_ui() -> void:
	# 1. Floating World Speech Cloud
	_bubble_card = PanelContainer.new()
	_bubble_card.name = "WorldSpeechBubble"
	_bubble_card.custom_minimum_size = Vector2(420, 128)
	var b_style := Style.modal_box(Color(0.996, 0.986, 0.952, 0.98), 24, 18)
	b_style.border_color = Color("d6c6a8")
	b_style.border_width_bottom = 4
	b_style.shadow_size = 16
	b_style.shadow_offset = Vector2(0, 6)
	_bubble_card.add_theme_stylebox_override("panel", b_style)
	add_child(_bubble_card)

	_tail = SpeechTail.new()
	_tail.name = "BubblePointerTail"
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.size = Vector2(120, 15)
	add_child(_tail)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_bubble_card.add_child(col)

	# Header Row: Speaker Badge Pill + Clean Close Icon
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	col.add_child(top_row)

	var badge_pill := PanelContainer.new()
	badge_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bp_sb := StyleBoxFlat.new()
	bp_sb.bg_color = Color("f4ead3")
	bp_sb.set_corner_radius_all(12)
	bp_sb.content_margin_left = 10
	bp_sb.content_margin_right = 12
	bp_sb.content_margin_top = 4
	bp_sb.content_margin_bottom = 4
	badge_pill.add_theme_stylebox_override("panel", bp_sb)
	top_row.add_child(badge_pill)

	_speaker_badge = Label.new()
	_speaker_badge.add_theme_font_override("font", Style.heading_font())
	_speaker_badge.add_theme_font_size_override("font_size", 15)
	_speaker_badge.add_theme_color_override("font_color", Color("685231"))
	badge_pill.add_child(_speaker_badge)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	var close_x := _tool_chip("", "close", "收起对话 · Esc")
	close_x.custom_minimum_size = Vector2(32, 32)
	close_x.pressed.connect(dismiss)
	top_row.add_child(close_x)

	# Spoken English Line
	_en_label = Label.new()
	_en_label.add_theme_font_override("font", Style.heading_font())
	_en_label.add_theme_font_size_override("font_size", 22)
	_en_label.add_theme_color_override("font_color", Style.INK)
	_en_label.add_theme_constant_override("line_spacing", 4)
	_en_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_en_label.custom_minimum_size.x = 410
	col.add_child(_en_label)

	# Collapsible Warm Chinese Companion Note
	_zh_panel = PanelContainer.new()
	_zh_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zh_sb := StyleBoxFlat.new()
	zh_sb.bg_color = Color("f4efe1")
	zh_sb.set_corner_radius_all(12)
	zh_sb.content_margin_left = 12
	zh_sb.content_margin_right = 12
	zh_sb.content_margin_top = 8
	zh_sb.content_margin_bottom = 8
	_zh_panel.add_theme_stylebox_override("panel", zh_sb)
	_zh_panel.hide()
	col.add_child(_zh_panel)

	_zh_label = Label.new()
	_zh_label.add_theme_font_size_override("font_size", 15)
	_zh_label.add_theme_color_override("font_color", Style.MUTED)
	_zh_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zh_label.custom_minimum_size.x = 390
	_zh_panel.add_child(_zh_label)

	# Clean Vector Footer Tool Row
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	col.add_child(tool_row)

	var listen_btn := _tool_chip("听读音", "speaker", "听柔和美式女声朗读")
	listen_btn.pressed.connect(func():
		if not current_en.is_empty():
			speak_requested.emit(current_en, "en")
	)
	tool_row.add_child(listen_btn)

	var follow_btn := _tool_chip("跟读试试", "mic", "对着麦克风读英文，离线识别鼓励")
	follow_btn.pressed.connect(func(): _start_follow_along("voice"))
	tool_row.add_child(follow_btn)

	var shy_btn := _tool_chip("心底默读", "star", "安静环境下在心里默读也能点亮鼓励星")
	shy_btn.pressed.connect(func(): _start_follow_along("shy"))
	tool_row.add_child(shy_btn)

	_hint_btn = _tool_chip("中文贴士", "bulb", "展开或收起温暖中文翻译与引导")
	_hint_btn.pressed.connect(func():
		zh_visible = not zh_visible
		_zh_panel.visible = zh_visible and not current_zh.is_empty()
		hint_toggled.emit(current_npc_id, zh_visible)
		_update_positions(true)
	)
	tool_row.add_child(_hint_btn)

	_chat_toggle_btn = _tool_chip("自由聊", "chat", "用英文或中文和伙伴自由聊天")
	_chat_toggle_btn.pressed.connect(func():
		_chat_box.visible = not _chat_box.visible
		if _chat_box.visible:
			_chat_input.grab_focus()
		_update_positions(true)
	)
	tool_row.add_child(_chat_toggle_btn)

	# Expandable Safe AI Companion Free-Chat Input
	_chat_box = HBoxContainer.new()
	_chat_box.add_theme_constant_override("separation", 8)
	_chat_box.hide()
	col.add_child(_chat_box)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "输入英文或中文和伙伴聊聊吧 (如: Hello! Nice hat!)"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size.y = 40
	_chat_input.text_submitted.connect(_submit_chat)
	_chat_box.add_child(_chat_input)

	var send_btn := _tool_chip("发送", "sparkle", "发送消息")
	send_btn.pressed.connect(func(): _submit_chat(_chat_input.text))
	_chat_box.add_child(send_btn)

	# 2. Bottom Floating Response Ribbon (Never overlaps HUD Dock!)
	_ribbon_panel = PanelContainer.new()
	_ribbon_panel.name = "BottomResponseRibbon"
	var r_style := Style.modal_box(Color(0.992, 0.980, 0.942, 0.97), 26, 12)
	r_style.border_color = Color("dcd0b6")
	r_style.border_width_bottom = 5
	r_style.shadow_size = 16
	_ribbon_panel.add_theme_stylebox_override("panel", r_style)
	add_child(_ribbon_panel)

	_choices_flow = HBoxContainer.new()
	_choices_flow.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices_flow.add_theme_constant_override("separation", 10)
	_ribbon_panel.add_child(_choices_flow)

func _tool_chip(caption: String, icon_name: String, tip: String = "") -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.icon = Style.icon(icon_name)
	btn.tooltip_text = tip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_constant_override("icon_max_width", 18)
	btn.add_theme_constant_override("h_separation", 5)
	btn.add_theme_color_override("font_color", Style.INK)
	var sb := Style.keycap(Color("f4efe1"), Color("dfd2b8"), 2, 15, 10, 5)
	sb.shadow_size = 0
	var hv := Style.keycap(Color("fdf2d6"), Style.GOLD, 2, 15, 10, 5)
	hv.shadow_size = 0
	var pr := Style.keycap(Color("ebe3cf"), Color("cbb998"), 1, 15, 10, 6)
	pr.shadow_size = 0
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", pr)
	if caption.is_empty():
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return btn

func _submit_chat(raw_text: String) -> void:
	var cleaned := raw_text.strip_edges()
	if cleaned.is_empty():
		return
	_chat_input.clear()
	ai_chat_submitted.emit(current_npc_id, cleaned)

func open_conversation(config: Dictionary) -> void:
	current_npc_id = str(config.get("npc_id", "neighbor"))
	var speaker_name := _clean_emoji_prefix(str(config.get("speaker", "小岛伙伴")))
	current_en = str(config.get("en", "Hello! Welcome to Alphabet Island!"))
	current_zh = _clean_emoji_prefix(str(config.get("zh", "")))
	zh_visible = bool(config.get("show_zh_immediately", false))
	anchor_world_pos = config.get("world_pos", Vector3.ZERO)
	has_world_anchor = config.has("world_pos")

	_speaker_badge.text = "◈  " + speaker_name
	_en_label.text = current_en
	_zh_label.text = current_zh
	_zh_panel.visible = zh_visible and not current_zh.is_empty()
	_hint_btn.visible = not current_zh.is_empty()
	_chat_box.hide()
	_smoothed_bubble_pos = Vector2(-1.0, -1.0)

	_rebuild_choices(config.get("actions", []))
	show()
	_update_positions(true)
	if not _bubble_card.is_queued_for_deletion():
		_bubble_card.modulate.a = 0.0
		_ribbon_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_bubble_card, "modulate:a", 1.0, 0.16)
		tw.tween_property(_ribbon_panel, "modulate:a", 1.0, 0.18)
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
	_zh_label.text = "正在温暖倾听你跟读：「%s」……（离线语音识别中）" % phrase.left(44)
	_zh_panel.visible = true
	_update_positions(true)

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
		return {"wav_b64": "", "rms": 0.032, "duration_ms": int(duration_sec * 1000.0)}

	var data_len := pcm.size()
	var header := PackedByteArray()
	header.resize(44)
	header.encode_u8(0, 82); header.encode_u8(1, 73); header.encode_u8(2, 70); header.encode_u8(3, 70)
	header.encode_u32(4, 36 + data_len)
	header.encode_u8(8, 87); header.encode_u8(9, 65); header.encode_u8(10, 86); header.encode_u8(11, 69)
	header.encode_u8(12, 102); header.encode_u8(13, 109); header.encode_u8(14, 116); header.encode_u8(15, 32)
	header.encode_u32(16, 16)
	header.encode_u16(20, 1)
	header.encode_u16(22, 1)
	header.encode_u32(24, target_sr)
	header.encode_u32(28, target_sr * 2)
	header.encode_u16(32, 2)
	header.encode_u16(34, 16)
	header.encode_u8(36, 100); header.encode_u8(37, 97); header.encode_u8(38, 116); header.encode_u8(39, 97)
	header.encode_u32(40, data_len)
	header.append_array(pcm)

	return {
		"wav_b64": Marshalls.raw_to_base64(header),
		"rms": rms,
		"duration_ms": int(float(out_count) * 1000.0 / float(target_sr))
	}

func show_speech_encouragement(reply: Dictionary) -> void:
	var badge := _clean_emoji_prefix(str(reply.get("cheer_badge", "自信开口星")))
	var rep_en := str(reply.get("reply_en", current_en))
	var rep_zh := _clean_emoji_prefix(str(reply.get("reply_zh", "")))
	_en_label.text = rep_en
	_zh_label.text = "★ %s · %s" % [badge, rep_zh]
	_zh_panel.visible = true
	_update_positions(true)
	if not rep_en.is_empty():
		speak_requested.emit(rep_en, "en")

func show_ai_reply(reply: Dictionary) -> void:
	current_en = str(reply.get("reply_en", current_en))
	current_zh = _clean_emoji_prefix(str(reply.get("reply_zh", current_zh)))
	_en_label.text = current_en
	_zh_label.text = current_zh
	_zh_panel.visible = not current_zh.is_empty()
	if reply.get("suggestions") is Array and not (reply.suggestions as Array).is_empty():
		var actions: Array = []
		for sug: Variant in reply.suggestions:
			var s_text := str(sug)
			actions.append({"label": s_text, "id": "ai_quick:" + s_text, "primary": true, "icon": "chat"})
		actions.append({"label": "先聊到这里", "id": "close"})
		_rebuild_choices(actions)
	_update_positions(true)
	if not current_en.is_empty():
		speak_requested.emit(current_en, "en")

static func _infer_action_icon(act_id: String, raw_label: String) -> String:
	if act_id.begins_with("audio:"):
		return "speaker"
	if act_id.begins_with("v4_chapter_atlas"):
		return "compass"
	if act_id.begins_with("v4_chap_") or act_id.find("story") >= 0:
		return "sparkle"
	if act_id.begins_with("v4_commission"):
		return "star"
	if act_id.begins_with("open_popup") or raw_label.find("立体书") >= 0 or act_id.begins_with("journey:inspect"):
		return "book"
	if act_id.find("orchard") >= 0 or raw_label.find("苹果") >= 0:
		return "apple"
	if act_id in ["craft", "sell"] or raw_label.find("蛋糕") >= 0:
		return "cake"
	if act_id.find("decor") >= 0 or act_id == "shop" or raw_label.find("布置") >= 0 or raw_label.find("装饰") >= 0:
		return "home"
	if act_id == "map":
		return "map"
	if act_id.begins_with("ai_quick:") or act_id == "greet":
		return "chat"
	return ""

static func _clean_emoji_prefix(raw: String) -> String:
	var buf := ""
	for i in range(raw.length()):
		var cp := raw.unicode_at(i)
		if cp >= 0x1F000 or cp in [0x2726, 0x2727, 0x2728, 0xFE0E, 0xFE0F]:
			continue
		buf += raw.substr(i, 1)
	return buf.strip_edges()

func _rebuild_choices(actions: Array) -> void:
	_choice_buttons.clear()
	for child: Node in _choices_flow.get_children():
		_choices_flow.remove_child(child)
		child.queue_free()
	var idx := 0
	for entry: Variant in actions:
		if not entry is Dictionary:
			continue
		var act := entry as Dictionary
		var act_id := str(act.get("id", "close"))
		var raw_lbl := str(act.get("label", "继续"))
		var clean_lbl := _clean_emoji_prefix(raw_lbl)
		idx += 1
		var btn := Button.new()
		btn.text = "%s  [%d]" % [clean_lbl, idx] if idx <= 5 else clean_lbl
		btn.disabled = bool(act.get("disabled", false))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(146, 50)
		btn.add_theme_font_size_override("font_size", 17)
		var primary := bool(act.get("primary", false))
		var icon_name := str(act.get("icon", ""))
		if icon_name.is_empty():
			icon_name = _infer_action_icon(act_id, raw_lbl)
		if not icon_name.is_empty():
			btn.icon = Style.icon(icon_name)
			btn.add_theme_constant_override("icon_max_width", 24)
			btn.add_theme_constant_override("h_separation", 7)

		if primary:
			btn.theme_type_variation = "PrimaryButton"
		else:
			btn.add_theme_stylebox_override("normal", Style.keycap(Color("fffdf7"), Color("d8c8ab"), 4, 18, 16, 10))
			btn.add_theme_stylebox_override("hover", Style.keycap(Color("fdf3dc"), Style.GOLD, 4, 18, 16, 10))
			btn.add_theme_stylebox_override("pressed", Style.keycap(Color("f3ead4"), Color("cbb998"), 2, 18, 16, 11))

		btn.pressed.connect(func():
			if act_id == "close":
				dismiss()
			else:
				action_triggered.emit(act_id)
		)
		_choices_flow.add_child(btn)
		_choice_buttons.append(btn)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := -1
		match event.keycode:
			KEY_1, KEY_KP_1: slot = 0
			KEY_2, KEY_KP_2: slot = 1
			KEY_3, KEY_KP_3: slot = 2
			KEY_4, KEY_KP_4: slot = 3
			KEY_5, KEY_KP_5: slot = 4
		if slot >= 0 and slot < _choice_buttons.size():
			var b := _choice_buttons[slot]
			if is_instance_valid(b) and not b.disabled:
				b.pressed.emit()
				get_viewport().set_input_as_handled()

func dismiss() -> void:
	if not visible:
		return
	hide()
	closed.emit()

func _process(delta: float) -> void:
	if visible:
		_update_positions(false, delta)

func _update_positions(snap_immediate: bool = false, delta: float = 0.016) -> void:
	var vp := size
	if vp.x < 10.0:
		vp = Vector2(1440, 900)
	_bubble_card.reset_size()
	var b_size := _bubble_card.get_combined_minimum_size()
	b_size.x = clampf(b_size.x, 420.0, minf(680.0, vp.x - 96.0))
	_bubble_card.size = b_size

	var screen_anchor := Vector2(vp.x * 0.5, vp.y * 0.42)
	if has_world_anchor and is_instance_valid(camera) and not camera.is_position_behind(anchor_world_pos):
		screen_anchor = camera.unproject_position(anchor_world_pos + Vector3(0, 2.35, 0))

	var target_pos := Vector2(
		clampf(screen_anchor.x - b_size.x * 0.5, 340.0 if vp.x >= 1200.0 else 36.0, vp.x - b_size.x - 36.0),
		clampf(screen_anchor.y - b_size.y - 22.0, 24.0, vp.y - b_size.y - 148.0)
	)
	if snap_immediate or _smoothed_bubble_pos.x < 0.0:
		_smoothed_bubble_pos = target_pos
	else:
		_smoothed_bubble_pos = _smoothed_bubble_pos.lerp(target_pos, minf(1.0, delta * 14.0))
	_bubble_card.position = _smoothed_bubble_pos

	if is_instance_valid(_tail):
		_tail.position = Vector2(_bubble_card.position.x + (_bubble_card.size.x - _tail.size.x) * 0.5, _bubble_card.position.y + _bubble_card.size.y - 2.0)
		var desired_tip := screen_anchor.x - (_tail.position.x + _tail.size.x * 0.5)
		_tail.tip_offset_x = clampf(desired_tip, -36.0, 36.0)
		_tail.queue_redraw()

	_ribbon_panel.reset_size()
	var r_size := _ribbon_panel.get_combined_minimum_size()
	r_size.x = minf(r_size.x, vp.x - 64.0)
	_ribbon_panel.size = r_size
	_ribbon_panel.position = Vector2((vp.x - r_size.x) * 0.5, vp.y - r_size.y - 20.0)
