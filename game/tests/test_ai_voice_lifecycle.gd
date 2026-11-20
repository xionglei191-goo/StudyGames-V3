extends SceneTree
const Bridge = preload("res://core/ai_companion_bridge.gd")
const Overlay = preload("res://ui_v4/diegetic_dialogue.gd")

class DelayedOverlay:
	extends "res://ui_v4/diegetic_dialogue.gd"
	func _record_mic_wav_16k(_duration_sec: float) -> Dictionary:
		await get_tree().create_timer(0.04).timeout
		return {"wav_b64":"fixture", "rms":0.02, "duration_ms":100}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("VOICE_LIFECYCLE: " + label)

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	var bridge := Bridge.new()
	root.add_child(bridge)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(44100)
	audio.data = samples
	bridge.voice_player.stream = audio
	bridge.voice_player.play()
	_check(bridge.voice_player.playing, "fixture starts audio")
	bridge.muted = true
	_check(not bridge.voice_player.playing, "muting immediately stops playing audio")
	var generation: int = bridge._speak_seq
	bridge.muted = false
	bridge.stop_speaking()
	_check(bridge._speak_seq > generation, "closing invalidates delayed playback")
	bridge.base_url = "http://127.0.0.1:1"
	bridge._dispatch_tts_request("hello", "en", "warm", bridge._speak_seq, false)
	_check(is_instance_valid(bridge._tts_request), "pending synthesis request is tracked")
	var stale_request: HTTPRequest = bridge._tts_request
	bridge.stop_speaking()
	_check(bridge._tts_request == null and stale_request.is_queued_for_deletion(), "closing cancels and releases pending request")
	stale_request.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"ok":true, "wav_base64":Marshalls.raw_to_base64(_wav_bytes())}).to_utf8_buffer())
	_check(not bridge.voice_player.playing, "late completed request cannot restart audio")
	var child_count := bridge.get_child_count()
	bridge._dispatch_tts_request("hello", "en", "warm", bridge._speak_seq - 1, true)
	_check(bridge.get_child_count() == child_count, "stale retry never launches a request")

	var quiet: Dictionary = bridge._local_fallback_encourage("apple", "voice", 0.0, 1500)
	_check(not quiet.voice_detected and quiet.match_tier == "no_voice", "standalone silence is not detected as speech")
	_check(quiet.similarity == null, "standalone fallback does not invent accuracy")
	var shy: Dictionary = bridge._local_fallback_encourage("apple", "shy", 0.0, 0)
	_check(not shy.voice_detected and shy.target_text == "apple", "quiet reading keeps its own participation result")
	bridge.queue_free()
	await process_frame
	await _test_recording_lifecycle()
	await _test_main_close_and_evidence()
	print("VOICE_LIFECYCLE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_recording_lifecycle() -> void:
	var overlay := DelayedOverlay.new()
	root.add_child(overlay)
	var submissions: Array[String] = []
	overlay.follow_along_submitted.connect(func(target: String, _mode: String, _rms: float, _duration: int): submissions.append(target))
	overlay.open_conversation({"npc_id":"textbook_miss_li", "en":"First phrase", "auto_speak":false})
	overlay._start_follow_along("voice")
	overlay.open_conversation({"npc_id":"textbook_lingling", "en":"Second phrase", "auto_speak":false})
	await create_timer(0.08).timeout
	_check(submissions.is_empty() and overlay.last_captured_wav_b64.is_empty(), "previous conversation recording is discarded")
	overlay._start_follow_along("voice")
	overlay._start_follow_along("voice")
	await create_timer(0.08).timeout
	_check(submissions == ["Second phrase"], "double recording click submits only newest attempt")
	submissions.clear()
	overlay._start_follow_along("voice")
	overlay.dismiss()
	await create_timer(0.08).timeout
	_check(submissions.is_empty() and overlay.last_captured_wav_b64.is_empty(), "closing cancels in-progress recording")
	overlay.queue_free()
	var plain := Overlay.new()
	root.add_child(plain)
	var input_enabled: Variant = ProjectSettings.get_setting("audio/driver/enable_input")
	ProjectSettings.set_setting("audio/driver/enable_input", false)
	var unavailable: Dictionary = await plain._record_mic_wav_16k(0.1)
	ProjectSettings.set_setting("audio/driver/enable_input", input_enabled)
	_check(float(unavailable.rms) == 0 and str(unavailable.wav_b64).is_empty(), "unavailable microphone never invents a voice signal")
	plain.queue_free()
	await process_frame

func _test_main_close_and_evidence() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for _frame in range(1200):
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready, "game scene ready")
	var state: Node = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-"), "game uses isolated save")
	var events_before: int = state.data.v4.stealth_events.size()
	game.ai_bridge.speech_encouragement_ready.emit(game.ai_bridge._local_fallback_encourage("apple", "shy", 0, 0))
	game.ai_bridge.speech_encouragement_ready.emit(game.ai_bridge._local_fallback_encourage("apple", "voice", 0.04, 900))
	_check(state.data.v4.stealth_events.size() == events_before, "reading and unrecognized sound do not create correct-word evidence")
	game.ai_bridge.speech_encouragement_ready.emit({"ok":true, "target_text":"apple", "transcript":"apple", "asr_engine":"vosk_offline_asr", "match_tier":"exact"})
	_check(state.data.v4.stealth_events.size() == events_before + 1, "recognized matching word records supported practice")
	var event: Dictionary = state.data.v4.stealth_events.back()
	_check(event.support_level == 1 and event.correct, "recognized follow-along is assisted practice")
	game.ai_bridge.speech_encouragement_ready.emit({"ok":true, "target_text":"good morning", "transcript":"morning", "asr_engine":"vosk_offline_asr", "match_tier":"close"})
	_check(state.data.v4.stealth_events.size() == events_before + 1, "unheard target word does not gain correct evidence")
	var chat_seq: int = game.ai_bridge._chat_seq
	game.ui.diegetic.open_conversation({"npc_id":"textbook_lingling", "en":"Hello Lingling", "auto_speak":false})
	_check(game.ai_bridge._chat_seq > chat_seq, "opening another conversation invalidates old requests")
	game.ai_bridge.chat_reply_ready.emit("textbook_miss_li", {"reply_en":"Stale teacher reply"})
	_check(game.ui.diegetic.current_en == "Hello Lingling", "reply from previous NPC cannot overwrite new conversation")
	game.ai_bridge.chat_reply_ready.emit("textbook_lingling", {"reply_en":"Current reply"})
	_check(game.ui.diegetic.current_en == "Current reply", "current NPC reply still displays")
	game.muted = false
	game.ai_bridge.muted = false
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(44100)
	stream.data = samples
	game.ai_bridge.voice_player.stream = stream
	game.ai_bridge.voice_player.play()
	game._on_action("toggle_audio")
	_check(game.muted and not game.ai_bridge.voice_player.playing, "settings mute action immediately stops companion audio")
	var capture_seq: int = game.ai_bridge._encouragement_seq
	game.ui.diegetic.listening_started.emit()
	_check(game.ai_bridge._encouragement_seq > capture_seq, "listening stops prior dialogue and follow-along requests")
	var seq: int = game.ai_bridge._speak_seq
	game._close()
	_check(game.ai_bridge._speak_seq > seq, "closing game panel cancels companion voice")
	seq = game.ai_bridge._speak_seq
	await game.change_room("home")
	_check(game.ai_bridge._speak_seq > seq, "changing rooms cancels previous voice")
	await _capture_quiet_feedback(game)
	game.queue_free()
	await process_frame

func _capture_quiet_feedback(game: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var capture_dir := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game.validation_mode = false
	await game.change_room("home")
	game.ui.close_panel()
	game.ui.diegetic.open_conversation({"npc_id":"textbook_role_lingling_mother", "speaker":"妈妈", "en":"Good morning!", "zh":"早上好！", "auto_speak":false})
	game.ui.diegetic.show_speech_encouragement(game.ai_bridge._local_fallback_encourage("Good morning!", "voice", 0, 1500))
	for _i in range(18):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(capture_dir.path_join("quiet-feedback.png"))
	_check(result == OK, "native feedback screenshot saved")

func _wav_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(48)
	for i in range(4):
		bytes[i] = "RIFF".unicode_at(i)
		bytes[8 + i] = "WAVE".unicode_at(i)
		bytes[12 + i] = "fmt ".unicode_at(i)
		bytes[36 + i] = "data".unicode_at(i)
	bytes.encode_u32(4, 40)
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 1)
	bytes.encode_u16(22, 1)
	bytes.encode_u32(24, 22050)
	bytes.encode_u32(28, 44100)
	bytes.encode_u16(32, 2)
	bytes.encode_u16(34, 16)
	bytes.encode_u32(40, 4)
	return bytes
