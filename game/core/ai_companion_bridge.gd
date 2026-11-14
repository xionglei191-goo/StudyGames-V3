extends Node
## V5 Multi-Character Async Client Bridge to `services/ai_companion` (`http://127.0.0.1:4195`).
## Handles Cloud + Offline Multi-Character Neural TTS, KidRails safe NPC free-chat,
## Vosk speech follow-along encouragement, auto-spawning the local sidecar when available,
## and character-pitched standalone fallback when running without Python!

signal chat_reply_ready(npc_id: String, reply: Dictionary)
signal parent_report_ready(report: Dictionary)
signal speech_encouragement_ready(reply: Dictionary)
signal voice_playback_started(voice_profile: String, voice_label_zh: String, engine: String)

const DEFAULT_BASE_URL := "http://127.0.0.1:4195"
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const CharacterVoices = preload("res://core/character_voices.gd")

const BUNDLED_PHRASE_MAP := {
	"hello": "res://assets/audio/hello.wav",
	"good morning": "res://assets/audio/good_morning.wav",
	"goodbye": "res://assets/audio/goodbye.wav",
	"thank you": "res://assets/audio/thank_you.wav",
	"apple": "res://assets/audio/apple.wav",
	"milk": "res://assets/audio/milk.wav",
	"bread": "res://assets/audio/bread.wav",
	"cake": "res://assets/audio/cake.wav",
	"how old are you": "res://assets/audio/how_old.wav",
	"i'm nine": "res://assets/audio/im_nine.wav",
}

var base_url := DEFAULT_BASE_URL
var voice_player: AudioStreamPlayer
var muted := false
var last_voice_profile := "teacher_gentle"
var last_voice_engine := ""
var _speak_seq := 0
var _spawned_sidecar_pid := -1
var _sidecar_boot_msec := 0

func _ready() -> void:
	name = "AICompanionBridge"
	var env_url := OS.get_environment("STUDYGAMES_AI_URL").strip_edges()
	if not env_url.is_empty():
		base_url = env_url
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "CompanionTTSPlayer"
	add_child(voice_player)
	if DisplayServer.get_name() != "headless" and OS.get_environment("STUDYGAMES_NO_AUTO_SIDECAR").strip_edges().is_empty():
		_ensure_sidecar_running()

func _exit_tree() -> void:
	if _spawned_sidecar_pid > 0 and OS.is_process_running(_spawned_sidecar_pid):
		OS.kill(_spawned_sidecar_pid)
		_spawned_sidecar_pid = -1

func _ensure_sidecar_running() -> void:
	var probe := HTTPRequest.new()
	probe.timeout = 0.85
	add_child(probe)
	probe.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		probe.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			return
		_try_autospawn_local_sidecar()
	)
	var err := probe.request(base_url + "/health")
	if err != OK:
		probe.queue_free()
		_try_autospawn_local_sidecar()

func _try_autospawn_local_sidecar() -> void:
	if _spawned_sidecar_pid > 0:
		return
	var exe_dir := OS.get_executable_path().get_base_dir()
	var candidates: Array[String] = [
		ProjectSettings.globalize_path("res://..").simplify_path(),
		exe_dir.path_join("../..").simplify_path(),
		exe_dir.simplify_path(),
	]
	for root_dir: String in candidates:
		if root_dir.is_empty():
			continue
		var app_py := root_dir.path_join("services/ai_companion/app.py")
		if not FileAccess.file_exists(app_py):
			continue
		var pyw := root_dir.path_join(".local/ai-companion-venv/Scripts/pythonw.exe")
		var py := root_dir.path_join(".local/ai-companion-venv/Scripts/python.exe")
		var chosen_py := pyw if FileAccess.file_exists(pyw) else (py if FileAccess.file_exists(py) else "")
		if chosen_py.is_empty():
			continue
		# Launch via short Python bootstrapper that chdirs to root_dir so `services.ai_companion.app` resolves cleanly
		var boot_code := "import os, uvicorn; os.chdir(%s); uvicorn.run('services.ai_companion.app:app', host='127.0.0.1', port=4195, log_level='warning')" % JSON.stringify(root_dir)
		var pid := OS.create_process(chosen_py, PackedStringArray(["-X", "utf8", "-c", boot_code]), false)
		if pid > 0:
			_spawned_sidecar_pid = pid
			_sidecar_boot_msec = Time.get_ticks_msec()
			return

func request_npc_chat(npc_id: String, message: String, context: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		var local := _local_fallback_chat(npc_id, message, context)
		chat_reply_ready.emit(npc_id, local)
		return
	var req := HTTPRequest.new()
	req.timeout = 4.5
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and bool(parsed.get("ok", false)):
				chat_reply_ready.emit(npc_id, parsed)
				return
		chat_reply_ready.emit(npc_id, _local_fallback_chat(npc_id, message, context))
	)
	var payload := JSON.stringify({"npc_id": npc_id, "message": message, "context": context})
	var err := req.request(base_url + "/api/v4/npc/chat", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()
		chat_reply_ready.emit(npc_id, _local_fallback_chat(npc_id, message, context))

func speak_text(text: String, lang: String = "en", voice_hint: String = "warm") -> void:
	var cleaned := text.strip_edges()
	if muted or DisplayServer.get_name() == "headless" or cleaned.is_empty():
		return
	_speak_seq += 1
	var seq := _speak_seq
	var norm_hint := CharacterVoices.normalize_hint(voice_hint)
	_dispatch_tts_request(cleaned, lang, norm_hint, seq, false)

func _dispatch_tts_request(cleaned: String, lang: String, norm_hint: String, seq: int, retried: bool) -> void:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if seq != _speak_seq or muted:
			return
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and bool(parsed.get("ok", false)):
				var b64 := str(parsed.get("wav_base64", ""))
				if not b64.is_empty():
					var raw := Marshalls.base64_to_raw(b64)
					var stream := _parse_pcm_wav(raw)
					if stream != null:
						voice_player.stop()
						voice_player.pitch_scale = 1.0
						voice_player.stream = stream
						voice_player.play()
						last_voice_profile = str(parsed.get("voice_profile", CharacterVoices.archetype_for(norm_hint)))
						last_voice_engine = str(parsed.get("engine", "neural_tts"))
						var lbl := str(parsed.get("voice_label_zh", CharacterVoices.label_zh_for(norm_hint)))
						voice_playback_started.emit(last_voice_profile, lbl, last_voice_engine)
						return
		# If the sidecar just spawned (< 3.5s ago), retry once before falling back to local WAV
		if not retried and _sidecar_boot_msec > 0 and (Time.get_ticks_msec() - _sidecar_boot_msec) < 3500:
			get_tree().create_timer(0.85).timeout.connect(func():
				if is_inside_tree() and seq == _speak_seq and not muted:
					_dispatch_tts_request(cleaned, lang, norm_hint, seq, true)
			)
			return
		_play_local_fallback(cleaned, lang, norm_hint)
	)
	var payload := JSON.stringify({"text": cleaned, "lang": lang, "voice_hint": norm_hint})
	var err := req.request(base_url + "/api/v4/tts/speak", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()
		_play_local_fallback(cleaned, lang, norm_hint)

func _play_local_fallback(cleaned: String, lang: String, norm_hint: String) -> void:
	if muted:
		return
	var arch := CharacterVoices.archetype_for(norm_hint)
	var lbl := CharacterVoices.label_zh_for(norm_hint)
	var pitch := CharacterVoices.fallback_pitch_scale(norm_hint)
	var clean_key := cleaned.to_lower().trim_suffix("!").trim_suffix(".").trim_suffix("?")
	if BUNDLED_PHRASE_MAP.has(clean_key) and ResourceLoader.exists(str(BUNDLED_PHRASE_MAP[clean_key])):
		voice_player.stop()
		voice_player.pitch_scale = pitch
		voice_player.stream = load(str(BUNDLED_PHRASE_MAP[clean_key])) as AudioStream
		voice_player.play()
		last_voice_profile = arch
		last_voice_engine = "bundled_pitched_wav"
		voice_playback_started.emit(arch, lbl, last_voice_engine)
		return
	var os_voices := DisplayServer.tts_get_voices_for_language("en" if lang.to_lower().begins_with("en") else "zh")
	if not os_voices.is_empty():
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(cleaned, str(os_voices[0]), 90, clampf(pitch, 0.75, 1.30), 1.0)
		last_voice_profile = arch
		last_voice_engine = "os_system_tts"
		voice_playback_started.emit(arch, lbl, last_voice_engine)

func observe_stealth_mastery(word: String, support_level: int, correct: bool, response_ms: int, _context_id: String = "") -> void:
	if DisplayServer.get_name() == "headless" or word.strip_edges().is_empty():
		return
	var req := HTTPRequest.new()
	req.timeout = 3.0
	add_child(req)
	req.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray): req.queue_free())
	var payload := JSON.stringify({
		"events": [{
			"word": word,
			"support_level": support_level,
			"correct": correct,
			"response_ms": response_ms
		}]
	})
	var err := req.request(base_url + "/api/v4/mastery/observe", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()

func request_speech_encouragement(target_text: String, mode: String = "voice", rms_energy: float = 0.035, duration_ms: int = 900, wav_base64: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		speech_encouragement_ready.emit(_local_fallback_encourage(target_text, mode, rms_energy, duration_ms))
		return
	var req := HTTPRequest.new()
	req.timeout = 4.5
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and bool(parsed.get("ok", false)):
				speech_encouragement_ready.emit(parsed as Dictionary)
				return
		speech_encouragement_ready.emit(_local_fallback_encourage(target_text, mode, rms_energy, duration_ms))
	)
	var payload := JSON.stringify({
		"target_text": target_text,
		"mode": mode,
		"rms_energy": rms_energy,
		"duration_ms": duration_ms,
		"wav_base64": wav_base64
	})
	var err := req.request(base_url + "/api/v4/speech/encourage", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()
		speech_encouragement_ready.emit(_local_fallback_encourage(target_text, mode, rms_energy, duration_ms))

func _local_fallback_encourage(target_text: String, mode: String, rms_energy: float, duration_ms: int) -> Dictionary:
	var clean := target_text.strip_edges() if not target_text.strip_edges().is_empty() else "Hello!"
	if mode == "shy":
		return {
			"ok": true,
			"mode": "shy",
			"cheer_badge": "安心默读星",
			"reply_en": "Listening in your heart is great too! \"%s\" stays with you!" % clean,
			"reply_zh": "在心里轻轻默读「%s」也很棒！不着急，想开口时随时都可以！" % clean
		}
	if rms_energy >= 0.015 or duration_ms >= 600:
		return {
			"ok": true,
			"mode": "voice",
			"cheer_badge": "自信开口星",
			"reply_en": "Sunny voice! You spoke \"%s\" so warmly and bravely!" % clean,
			"reply_zh": "声音真洪亮温暖！刚才跟读「%s」超级自信，为你鼓掌！" % clean
		}
	return {
		"ok": true,
		"mode": "voice",
		"cheer_badge": "勇敢轻声星",
		"reply_en": "I heard your gentle voice trying \"%s\"! Wonderful try!" % clean,
		"reply_zh": "听到了你轻轻跟读「%s」的声音！勇敢开口就是最棒的进步！" % clean
	}

func request_parent_report(payload: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		parent_report_ready.emit(_local_fallback_report(payload))
		return
	var req := HTTPRequest.new()
	req.timeout = 4.5
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and bool(parsed.get("ok", false)):
				parent_report_ready.emit(parsed)
				return
		parent_report_ready.emit(_local_fallback_report(payload))
	)
	var err := req.request(base_url + "/api/v4/parent/report", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		req.queue_free()
		parent_report_ready.emit(_local_fallback_report(payload))

func _parse_pcm_wav(raw: PackedByteArray) -> AudioStreamWAV:
	if raw.size() < 44:
		return null
	if raw.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var pos := 12
	var channels := 1
	var sample_rate := 22050
	var bits_per_sample := 16
	var data_bytes := PackedByteArray()
	while pos + 8 <= raw.size():
		var chunk_id := raw.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size := raw.decode_u32(pos + 4)
		pos += 8
		if pos + chunk_size > raw.size():
			chunk_size = raw.size() - pos
		if chunk_id == "fmt " and chunk_size >= 16:
			channels = maxi(1, raw.decode_u16(pos + 2))
			sample_rate = maxi(8000, raw.decode_u32(pos + 4))
			bits_per_sample = raw.decode_u16(pos + 14)
		elif chunk_id == "data":
			data_bytes = raw.slice(pos, pos + chunk_size)
			break
		pos += chunk_size + (chunk_size % 2)
	if data_bytes.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = (channels >= 2)
	wav.data = data_bytes
	return wav

func _local_fallback_chat(npc_id: String, message: String, context: Dictionary) -> Dictionary:
	var outfit_meta := Wardrobe.outfit_info(str(context.get("outfit", "yellow")))
	var hat_meta := Wardrobe.hat_info(str(context.get("hat", "none")))
	var target_word := str(context.get("target_word", "apple"))
	var target_zh := str(context.get("target_meaning_zh", "红苹果"))
	var lower := message.to_lower()
	for bad: String in ["笨蛋", "傻瓜", "去死", "手机号", "住址", "stupid", "idiot", "hate you"]:
		if bad in lower:
			return {
				"ok": true,
				"blocked": true,
				"npc_id": npc_id,
				"reply_en": "Let's keep our island warm and friendly! Want to talk about apples or hats?",
				"reply_zh": "让我们一起守护温暖友善的小岛吧！要不要聊聊红苹果或好看的穿搭？",
				"suggestions": ["Hello!", "Look at my outfit!", "Three red apples!"],
				"engine": "local_kidrails_fallback"
			}
	if "hat" in lower or "outfit" in lower or "帽" in lower or "穿搭" in lower:
		var extra := (" and " + str(hat_meta.en)) if str(context.get("hat", "none")) != "none" else ""
		return {
			"ok": true,
			"npc_id": npc_id,
			"reply_en": "Wow! Your %s%s looks so sunny today!" % [str(outfit_meta.en), extra],
			"reply_zh": "哇！你今天这一身%s真阳光、真好看！" % str(outfit_meta.zh),
			"suggestions": ["Thank you!", "Let's pick apples!", "Open pop-up book!"],
			"engine": "local_i_plus_1_fallback"
		}
	return {
		"ok": true,
		"npc_id": npc_id,
		"reply_en": "Hello, little friend! Today we love sharing \"%s\" on Alphabet Island!" % target_word,
		"reply_zh": "你好呀好朋友！今天小岛大家都在开心分享「%s」（%s）呢！" % [target_word, target_zh],
		"suggestions": ["Good morning!", "Look at my outfit!", "Thank you!"],
		"engine": "local_i_plus_1_fallback"
	}

func _local_fallback_report(payload: Dictionary) -> Dictionary:
	var events: Array = payload.get("stealth_events", []) if payload.get("stealth_events") is Array else []
	var ind: Array[String] = []
	var spr: Array[String] = []
	for ev: Variant in events:
		if ev is Dictionary:
			var w := str(ev.get("word", ""))
			if w.is_empty():
				continue
			if bool(ev.get("correct", false)) and int(ev.get("support_level", 5)) == 0:
				if not ind.has(w):
					ind.append(w)
			elif not spr.has(w) and not ind.has(w):
				spr.append(w)
	var flourish := clampi(50 + ind.size() * 7 + spr.size() * 3, 45, 99)
	var book_title := str(payload.get("book_title", "湘少版三年级上册"))
	var unit_id := str(payload.get("unit_id", "unit-1")).to_upper()
	var visited := int(payload.get("visited_landmarks", 0))
	var highlight := ("无提示自主提取词汇：" + ", ".join(ind.slice(0, 6))) if not ind.is_empty() else ("情境探索萌芽词汇：" + (", ".join(spr.slice(0, 6)) if not spr.is_empty() else "正在开启第一天小岛旅程"))
	return {
		"ok": true,
		"summary": {
			"theta": snappedf(float(ind.size()) * 0.25 - 0.1, 0.01),
			"flourish_index": flourish,
			"tracked_word_count": ind.size() + spr.size(),
			"independent_words": ind,
			"sprouting_words": spr,
			"recommended_revisits": []
		},
		"narrative_zh": "【当前同步册次】%s（%s）\n【小岛生活足迹】已探索 %d / 26 处字母记忆宫殿地标\n【隐性成长观察】%s\n【家庭温和互动建议】散步或吃点心时，用轻松口吻和孩子聊聊果园里的红苹果或今天换上的小草帽即可，无需纸笔抽查。" % [book_title, unit_id, visited, highlight],
		"note": "本地 IRT 隐性成长估算（启动 AI 伴学服务后自动启用完整 3PL 模型与多角色神经语音合成）。"
	}
