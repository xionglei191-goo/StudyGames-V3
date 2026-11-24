extends Node
## V5 Multi-Character Async Client Bridge to `services/ai_companion` (`http://127.0.0.1:4195`).
## Handles Cloud + Offline Multi-Character Neural TTS, KidRails safe NPC free-chat,
## Vosk speech follow-along encouragement, auto-spawning the local sidecar when available,
## and character-pitched standalone fallback when running without Python!

signal chat_reply_ready(npc_id: String, reply: Dictionary)
signal parent_report_ready(report: Dictionary)
signal speech_encouragement_ready(reply: Dictionary)
signal voice_playback_started(voice_profile: String, voice_label_zh: String, engine: String)
signal speech_speed_changed(mode: String)

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
var speech_speed_mode: String = "natural"
var _boot_validation_muted := false
var muted := false:
	set(value):
		var p := get_parent()
		if value and p != null and ("scene_ready" in p) and not bool(p.get("scene_ready")) and bool(p.get("validation_mode")) and not bool(p.get("muted")):
			_boot_validation_muted = true
		else:
			_boot_validation_muted = false
		muted = value
		if value:
			stop_speaking()
var last_voice_profile := "teacher_gentle"
var last_voice_engine := ""
var _speak_seq := 0
var _spawned_sidecar_pid := -1
var _sidecar_boot_msec := 0
var _tts_request: HTTPRequest
var _chat_request: HTTPRequest
var _chat_seq := 0
var _encouragement_request: HTTPRequest
var _encouragement_seq := 0
var voice_bank_dir_override := ""
var _voice_bank_dir_resolved := ""
var _voice_bank_manifest_path := ""
var _voice_bank_mtime := -1
var _voice_bank_entries: Dictionary = {}

func set_speech_speed_mode(mode: String) -> void:
	var normalized := "slow" if mode.strip_edges().to_lower() == "slow" else "natural"
	if speech_speed_mode == normalized:
		return
	speech_speed_mode = normalized
	speech_speed_changed.emit(speech_speed_mode)

func toggle_speech_speed_mode() -> String:
	set_speech_speed_mode("slow" if speech_speed_mode != "slow" else "natural")
	return speech_speed_mode

func _is_muted() -> bool:
	if muted and _boot_validation_muted:
		var p := get_parent()
		if p != null and not bool(p.get("validation_mode")) and not bool(p.get("muted")):
			_boot_validation_muted = false
			muted = false
	return muted

func _find_audio_director() -> Node:
	var p := get_parent()
	if p != null:
		var pad: Variant = p.get("audio_director")
		if pad is Node and is_instance_valid(pad):
			return pad as Node
	if is_inside_tree() and get_tree() != null:
		var cs := get_tree().current_scene
		if cs != null:
			var cad: Variant = cs.get("audio_director")
			if cad is Node and is_instance_valid(cad):
				return cad as Node
		for child: Node in get_tree().root.get_children():
			if child.has_method("play_animal_voice"):
				return child
			var sub: Variant = child.get("audio_director")
			if sub is Node and is_instance_valid(sub):
				return sub as Node
	return null

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
	if is_instance_valid(voice_player):
		voice_player.stop()
		voice_player.stream = null
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
	_chat_seq += 1
	var seq := _chat_seq
	_cancel_request(_chat_request)
	_chat_request = null
	if DisplayServer.get_name() == "headless":
		var local := _local_fallback_chat(npc_id, message, context)
		chat_reply_ready.emit(npc_id, local)
		return
	var req := HTTPRequest.new()
	req.timeout = 4.5
	add_child(req)
	_chat_request = req
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		if _chat_request == req:
			_chat_request = null
		req.queue_free()
		if seq != _chat_seq:
			return
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
		_chat_request = null
		req.queue_free()
		chat_reply_ready.emit(npc_id, _local_fallback_chat(npc_id, message, context))

func speak_text(text: String, lang: String = "en", voice_hint: String = "warm") -> void:
	var cleaned := text.strip_edges()
	if _is_muted() or cleaned.is_empty():
		return
	stop_speaking()
	var seq := _speak_seq
	var norm_hint := CharacterVoices.normalize_hint(voice_hint)
	var sfx_key := CharacterVoices.animal_sound_key(norm_hint)
	if DisplayServer.get_name() == "headless":
		if not sfx_key.is_empty():
			var ad_headless := _find_audio_director()
			if ad_headless != null and ad_headless.has_method("play_animal_voice"):
				ad_headless.play_animal_voice(sfx_key)
		return
	if not sfx_key.is_empty():
		var ad := _find_audio_director()
		if ad != null and ad.has_method("play_animal_voice"):
			ad.play_animal_voice(sfx_key)
		if CharacterVoices.is_pure_animal(norm_hint):
			var narrated_text := CharacterVoices.strip_animal_interjection(cleaned, lang)
			if not narrated_text.is_empty() and is_inside_tree():
				get_tree().create_timer(0.48).timeout.connect(func():
					if is_inside_tree() and seq == _speak_seq and not _is_muted():
						_dispatch_tts_request(narrated_text, lang, "storyteller", seq, false)
				)
			return
		if CharacterVoices.is_talking_mascot(norm_hint):
			if is_inside_tree():
				get_tree().create_timer(0.36).timeout.connect(func():
					if is_inside_tree() and seq == _speak_seq and not _is_muted():
						_dispatch_tts_request(cleaned, lang, norm_hint, seq, false)
				)
			return
	_dispatch_tts_request(cleaned, lang, norm_hint, seq, false)

func stop_speaking() -> void:
	_speak_seq += 1
	if is_instance_valid(_tts_request):
		_tts_request.cancel_request()
		_tts_request.queue_free()
	_tts_request = null
	if is_instance_valid(voice_player):
		voice_player.stop()
	if DisplayServer.get_name() != "headless":
		DisplayServer.tts_stop()

func _cancel_request(req: HTTPRequest) -> void:
	if is_instance_valid(req):
		req.cancel_request()
		req.queue_free()

func cancel_conversation() -> void:
	stop_speaking()
	_chat_seq += 1
	_encouragement_seq += 1
	_cancel_request(_chat_request)
	_cancel_request(_encouragement_request)
	_chat_request = null
	_encouragement_request = null

static func norm_text_for_bank(raw: String) -> String:
	var s := raw.replace("\r", " ").replace("\n", " ").replace("\t", " ").replace("\u3000", " ").replace("\u00a0", " ")
	var parts := s.split(" ", false)
	return " ".join(parts).strip_edges().to_lower()

static func bank_entry_key(archetype: String, lang: String, raw_text: String) -> String:
	var nlang := "en" if lang.to_lower().begins_with("en") else "zh"
	var norm := norm_text_for_bank(raw_text)
	return "%s|%s|%s" % [archetype, nlang, norm.sha1_text().left(20)]

static func _candidate_bank_texts(raw_text: String, lang: String, is_animal: bool) -> Array[String]:
	var out: Array[String] = []
	var push_unique := func(val: String) -> void:
		var n := norm_text_for_bank(val)
		if not n.is_empty() and not out.has(n):
			out.append(n)

	if is_animal:
		var stripped := CharacterVoices.strip_animal_interjection(raw_text, lang)
		if not stripped.is_empty():
			push_unique.call(stripped)
	push_unique.call(raw_text)

	var sym_snapshot := out.duplicate()
	for base_sym: String in sym_snapshot:
		var sym_clean := base_sym
		for sym: String in ["★", "☆", "◈", "◇", "♪", "·", "▷", "【", "】"]:
			sym_clean = sym_clean.replace(sym, " ")
		push_unique.call(sym_clean)

	var punct_snapshot := out.duplicate()
	for base_s: String in punct_snapshot:
		if base_s.contains("... "):
			push_unique.call(base_s.replace("... ", ". "))
		if base_s.contains(". "):
			push_unique.call(base_s.replace(". ", "... "))
		if base_s.contains("……"):
			push_unique.call(base_s.replace("…… ", "。").replace("……", "。"))
			push_unique.call(base_s.replace("…… ", "。 ").replace("……", "。 "))
		if base_s.contains("。"):
			push_unique.call(base_s.replace("。 ", "…… ").replace("。", "…… "))
	return out

func _resolve_voice_bank_dir() -> String:
	if not voice_bank_dir_override.strip_edges().is_empty():
		return voice_bank_dir_override.strip_edges().simplify_path()
	var env_dir := OS.get_environment("STUDYGAMES_VOICE_BANK_DIR").strip_edges()
	if not env_dir.is_empty():
		return env_dir.simplify_path()
	var exe_dir := OS.get_executable_path().get_base_dir()
	var candidates: Array[String] = [
		ProjectSettings.globalize_path("res://../assets/voice_bank_v10").simplify_path(),
		exe_dir.path_join("../../assets/voice_bank_v10").simplify_path(),
		exe_dir.path_join("../assets/voice_bank_v10").simplify_path(),
		exe_dir.path_join("assets/voice_bank_v10").simplify_path(),
		exe_dir.path_join("voice_bank_v10").simplify_path(),
	]
	for cand: String in candidates:
		if not cand.is_empty() and FileAccess.file_exists(cand.path_join("manifest.json")):
			return cand
	return candidates[0] if not candidates.is_empty() else ""

func reload_voice_bank_manifest(force: bool = false) -> void:
	var bank_dir := _resolve_voice_bank_dir()
	if bank_dir.is_empty():
		return
	var mpath := bank_dir.path_join("manifest.json")
	if not FileAccess.file_exists(mpath):
		if force or mpath != _voice_bank_manifest_path:
			_voice_bank_dir_resolved = bank_dir
			_voice_bank_manifest_path = mpath
			_voice_bank_mtime = -1
			_voice_bank_entries.clear()
		return
	var mtime := int(FileAccess.get_modified_time(mpath))
	if not force and mpath == _voice_bank_manifest_path and mtime == _voice_bank_mtime and not _voice_bank_entries.is_empty():
		return
	var raw_json := FileAccess.get_file_as_string(mpath)
	var parsed: Variant = JSON.parse_string(raw_json)
	if not (parsed is Dictionary):
		return
	var pdict := parsed as Dictionary
	var entries_dict: Dictionary = {}
	if pdict.get("entries") is Dictionary:
		entries_dict = pdict["entries"] as Dictionary
	elif pdict.get("items") is Dictionary:
		entries_dict = pdict["items"] as Dictionary
	else:
		for k: Variant in pdict.keys():
			if "|" in str(k):
				entries_dict[k] = pdict[k]
	_voice_bank_dir_resolved = bank_dir
	_voice_bank_manifest_path = mpath
	_voice_bank_mtime = mtime
	_voice_bank_entries = entries_dict

func find_prebaked_voice_clip(text: String, lang: String = "en", voice_hint: String = "warm", speed_mode_override: String = "") -> Dictionary:
	var smode := speech_speed_mode
	if not speed_mode_override.strip_edges().is_empty():
		smode = "slow" if speed_mode_override.strip_edges().to_lower() == "slow" else "natural"
	else:
		smode = "slow" if speech_speed_mode == "slow" else "natural"

	var norm_hint := CharacterVoices.normalize_hint(voice_hint)
	var arch := CharacterVoices.archetype_for(norm_hint)
	var nlang := "en" if lang.to_lower().begins_with("en") else "zh"
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return {"hit": false, "path": "", "archetype": arch, "speed_mode": smode, "duration_sec": 0.0}

	reload_voice_bank_manifest(false)
	if _voice_bank_entries.is_empty():
		return {"hit": false, "path": "", "archetype": arch, "speed_mode": smode, "duration_sec": 0.0}

	var is_animal := CharacterVoices.is_pure_animal(norm_hint)
	var candidates := _candidate_bank_texts(cleaned, nlang, is_animal)
	for cand_norm: String in candidates:
		var key := bank_entry_key(arch, nlang, cand_norm)
		if not _voice_bank_entries.has(key):
			continue
		var rec_v: Variant = _voice_bank_entries[key]
		var rel_path := ""
		var dur_sec := 0.0
		if rec_v is String:
			rel_path = str(rec_v)
		elif rec_v is Dictionary:
			var rec := rec_v as Dictionary
			if smode == "slow":
				rel_path = str(rec.get("slow", rec.get("clip_slow", rec.get("slow_path", rec.get("natural", rec.get("path", ""))))))
				if rec.has("slow_duration_sec"):
					dur_sec = float(rec.get("slow_duration_sec", 0.0))
				elif rec.has("duration_slow_sec"):
					dur_sec = float(rec.get("duration_slow_sec", 0.0))
				else:
					dur_sec = float(rec.get("duration_sec", 0.0)) * 1.25
			else:
				rel_path = str(rec.get("natural", rec.get("clip", rec.get("natural_path", rec.get("path", "")))))
				dur_sec = float(rec.get("duration_sec", rec.get("natural_duration_sec", 0.0)))
		if rel_path.is_empty():
			continue
		var abs_path := rel_path if rel_path.is_absolute_path() else _voice_bank_dir_resolved.path_join(rel_path).simplify_path()
		if FileAccess.file_exists(abs_path):
			return {
				"hit": true,
				"key": key,
				"path": abs_path,
				"archetype": arch,
				"speed_mode": smode,
				"duration_sec": dur_sec,
			}

	return {"hit": false, "path": "", "archetype": arch, "speed_mode": smode, "duration_sec": 0.0}

func _load_prebaked_stream(abs_path: String) -> AudioStream:
	var lower := abs_path.to_lower()
	if lower.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(abs_path)
	if lower.ends_with(".wav"):
		return _parse_pcm_wav(FileAccess.get_file_as_bytes(abs_path))
	return null

func _should_use_prebaked_bank_in_dispatch() -> bool:
	if not voice_bank_dir_override.strip_edges().is_empty():
		return true
	if not OS.get_environment("STUDYGAMES_VOICE_BANK_DIR").strip_edges().is_empty():
		return true
	return base_url == DEFAULT_BASE_URL

func _dispatch_tts_request(cleaned: String, lang: String, norm_hint: String, seq: int, retried: bool) -> void:
	if seq != _speak_seq or _is_muted():
		return
	if _should_use_prebaked_bank_in_dispatch():
		var prebaked := find_prebaked_voice_clip(cleaned, lang, norm_hint, speech_speed_mode)
		if bool(prebaked.get("hit", false)):
			var clip_path := str(prebaked.get("path", ""))
			var pre_stream := _load_prebaked_stream(clip_path)
			if pre_stream != null:
				voice_player.stop()
				voice_player.pitch_scale = 1.0
				voice_player.stream = pre_stream
				voice_player.play()
				var arch := str(prebaked.get("archetype", CharacterVoices.archetype_for(norm_hint)))
				last_voice_profile = arch
				last_voice_engine = "local_llm_voice_bank"
				var lbl := CharacterVoices.label_zh_for(norm_hint)
				voice_playback_started.emit(arch, lbl, "local_llm_voice_bank")
				return
	var req := HTTPRequest.new()
	# The service bounds cloud attempts, but a cold local voice bank can take
	# several seconds to load. Playback remains cancellable during that wait.
	req.timeout = 20.0
	add_child(req)
	_tts_request = req
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		if _tts_request == req:
			_tts_request = null
		req.queue_free()
		if seq != _speak_seq or _is_muted():
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
				if is_inside_tree() and seq == _speak_seq and not _is_muted():
					_dispatch_tts_request(cleaned, lang, norm_hint, seq, true)
			)
			return
		_play_local_fallback(cleaned, lang, norm_hint)
	)
	var payload := JSON.stringify({
		"text": cleaned,
		"lang": lang,
		"voice_hint": norm_hint,
		"speed_mode": speech_speed_mode,
	})
	var err := req.request(base_url + "/api/v4/tts/speak", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK:
		_tts_request = null
		req.queue_free()
		if seq == _speak_seq and not _is_muted():
			_play_local_fallback(cleaned, lang, norm_hint)

func _play_local_fallback(cleaned: String, lang: String, norm_hint: String) -> void:
	if _is_muted():
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
		var tts_rate := 0.68 if speech_speed_mode == "slow" else 0.84
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(cleaned, str(os_voices[0]), 90, clampf(pitch, 0.75, 1.30), tts_rate)
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

func request_speech_encouragement(target_text: String, mode: String = "voice", rms_energy: float = 0.0, duration_ms: int = 0, wav_base64: String = "") -> void:
	_encouragement_seq += 1
	var seq := _encouragement_seq
	_cancel_request(_encouragement_request)
	_encouragement_request = null
	if DisplayServer.get_name() == "headless":
		speech_encouragement_ready.emit(_local_fallback_encourage(target_text, mode, rms_energy, duration_ms))
		return
	var req := HTTPRequest.new()
	req.timeout = 4.5
	add_child(req)
	_encouragement_request = req
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		if _encouragement_request == req:
			_encouragement_request = null
		req.queue_free()
		if seq != _encouragement_seq:
			return
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
		_encouragement_request = null
		req.queue_free()
		speech_encouragement_ready.emit(_local_fallback_encourage(target_text, mode, rms_energy, duration_ms))

func _local_fallback_encourage(target_text: String, mode: String, rms_energy: float, duration_ms: int) -> Dictionary:
	var clean := target_text.strip_edges() if not target_text.strip_edges().is_empty() else "Hello!"
	if mode == "shy":
		return {
			"ok": true,
			"mode": "shy",
			"target_text": clean,
			"voice_detected": false,
			"asr_engine": "shy_silent",
			"match_tier": "shy_silent",
			"similarity": null,
			"cheer_badge": "安心默读星",
			"reply_en": "Listening in your heart is great too! \"%s\" stays with you!" % clean,
			"reply_zh": "在心里轻轻默读「%s」也很棒！不着急，想开口时随时都可以！" % clean
		}
	if rms_energy >= 0.008 and duration_ms > 0:
		return {
			"ok": true,
			"mode": "voice",
			"target_text": clean,
			"voice_detected": true,
			"asr_engine": "envelope_fallback",
			"match_tier": "confident_voice",
			"similarity": null,
			"cheer_badge": "自信开口星",
			"reply_en": "I heard your voice! Let's listen to \"%s\" together." % clean,
			"reply_zh": "听到你的声音啦！我们一起听听「%s」，再轻松试一试吧。" % clean
		}
	return {
		"ok": true,
		"mode": "voice",
		"target_text": clean,
		"voice_detected": false,
		"asr_engine": "envelope_fallback",
		"match_tier": "no_voice",
		"similarity": null,
		"cheer_badge": "慢慢来就好",
		"reply_en": "No hurry! Listen to \"%s\" or read quietly with me." % clean,
		"reply_zh": "不着急，先听听「%s」，也可以在心里一起读。" % clean
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
			"suggestions": ["Thank you!", "Look at my schoolbag!", "Let's practise English!"],
			"engine": "local_i_plus_1_fallback"
		}
	if npc_id == "textbook_role_lingling_mother":
		return {
			"ok": true,
			"npc_id": npc_id,
			"reply_en": "Sweetie, I'm so glad we're chatting at home! Let's look at \"%s\" together!" % target_word,
			"reply_zh": "宝贝，在家和妈妈用英语聊天真温馨！我们一起来看看身边的「%s」（%s）吧！" % [target_word, target_zh],
			"suggestions": ["Good morning, Mom!", "Where is my schoolbag?", "Thank you, Mom!"],
			"engine": "local_i_plus_1_fallback"
		}
	if npc_id == "textbook_role_lingling_father":
		return {
			"ok": true,
			"npc_id": npc_id,
			"reply_en": "Great speaking, champ! On our desk today we can practise \"%s\" together!" % target_word,
			"reply_zh": "说得真棒宝贝！今天在书房和餐桌旁，我们一起把「%s」（%s）用进句子里吧！" % [target_word, target_zh],
			"suggestions": ["Hi Dad!", "What's on the desk?", "Let's read a book!"],
			"engine": "local_i_plus_1_fallback"
		}
	if npc_id == "textbook_kitty":
		return {
			"ok": true,
			"npc_id": npc_id,
			"reply_en": "Meow! Little Kitty paws gently beside \"%s\" — let's read it slowly together!" % target_word,
			"reply_zh": "喵～小猫轻轻走近身边的「%s」（%s），我们一起慢慢读一读吧！" % [target_word, target_zh],
			"suggestions": ["Hello, Kitty!", "Soft warm sofa!", "Nice clothes!"],
			"engine": "local_i_plus_1_fallback"
		}
	if npc_id == "textbook_doggie":
		return {
			"ok": true,
			"npc_id": npc_id,
			"reply_en": "Woof woof! Doggie wags its tail happily near \"%s\" in the sunny yard!" % target_word,
			"reply_zh": "汪汪！小狗在阳光院子里的「%s」（%s）旁开心地摇尾巴呢！" % [target_word, target_zh],
			"suggestions": ["Good boy, Doggie!", "Green grass!", "Sunny garden!"],
			"engine": "local_i_plus_1_fallback"
		}
	return {
		"ok": true,
		"npc_id": npc_id,
		"reply_en": "Hello, my friend! Let's use \"%s\" in our daily conversation today!" % target_word,
		"reply_zh": "你好呀好伙伴！今天我们在日常对话里一起活学活用「%s」（%s）吧！" % [target_word, target_zh],
		"suggestions": ["Good morning!", "Let's learn together!", "Thank you!"],
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
	var v8_s: Dictionary = payload.get("v8_memory_summary", {}) if payload.get("v8_memory_summary") is Dictionary else {}
	var v8_txt := ""
	if not v8_s.is_empty():
		v8_txt = "\n【艾宾浩斯实物记忆】已点亮 %d / 287 处家具实物 · 金星永固 %d 词 · 待温故 %d 词 · 发音星 %d 词" % [
			int(v8_s.get("visited_placements", 0)),
			int(v8_s.get("gold_words", 0)),
			int(v8_s.get("due_words", 0)),
			int(v8_s.get("spoken_words", 0)),
		]
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
		"narrative_zh": "【当前同步册次】%s（%s）\n【小岛生活足迹】已探索 %d / 26 处字母记忆宫殿地标%s\n【隐性成长观察】%s\n【家庭温和互动建议】散步或吃点心时，用轻松口吻和孩子聊聊房间里的英文物品或今天换上的小草帽即可，无需纸笔抽查。" % [book_title, unit_id, visited, v8_txt, highlight],
		"note": "本地 IRT 隐性成长估算（启动 AI 伴学服务后自动启用完整 3PL 模型与多角色神经语音合成）。"
	}
