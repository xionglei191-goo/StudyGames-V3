extends Node
## Shared 16kHz Mono PCM WAV Microphone Recorder (`MicWavRecorder`).
## Safely captures microphone audio via `AudioStreamMicrophone` + `AudioEffectCapture`
## with clean cancellation and deterministic headless fallback.

var _mic_player: AudioStreamPlayer
var _mic_capture: AudioEffectCapture
var _recording_gen := 0
var is_recording := false


func _exit_tree() -> void:
	cancel_recording()


func cancel_recording() -> void:
	_recording_gen += 1
	is_recording = false
	if is_instance_valid(_mic_player):
		_mic_player.stop()
	if _mic_capture != null:
		_mic_capture.clear_buffer()


func record_wav_16k(duration_sec: float = 1.8) -> Dictionary:
	cancel_recording()
	var gen := _recording_gen
	var mix_rate := float(AudioServer.get_mix_rate())
	var can_capture := (
		DisplayServer.get_name() != "headless"
		and bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
		and mix_rate >= 8000.0
	)
	if not can_capture or not is_inside_tree():
		return {"wav_b64": "", "rms": 0.0, "duration_ms": 0, "cancelled": false}

	var bus_idx := AudioServer.get_bus_index("V4MicBus")
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "V4MicBus")
		AudioServer.set_bus_mute(bus_idx, true)
		_mic_capture = AudioEffectCapture.new()
		_mic_capture.buffer_length = 4.5
		AudioServer.add_bus_effect(bus_idx, _mic_capture)
	else:
		_mic_capture = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture
		if _mic_capture != null and _mic_capture.buffer_length < 4.5:
			_mic_capture.buffer_length = 4.5

	if not is_instance_valid(_mic_player):
		_mic_player = AudioStreamPlayer.new()
		_mic_player.name = "SharedMicPlayer"
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = "V4MicBus"
		add_child(_mic_player)

	if _mic_capture != null:
		_mic_capture.clear_buffer()
	is_recording = true
	_mic_player.play()
	await get_tree().create_timer(clampf(duration_sec, 0.4, 4.2)).timeout
	if gen != _recording_gen or not is_inside_tree():
		is_recording = false
		return {"wav_b64": "", "rms": 0.0, "duration_ms": 0, "cancelled": true}

	_mic_player.stop()
	is_recording = false
	if _mic_capture == null:
		return {"wav_b64": "", "rms": 0.0, "duration_ms": 0, "cancelled": false}

	var avail := _mic_capture.get_frames_available()
	if avail < 400:
		return {"wav_b64": "", "rms": 0.0, "duration_ms": 0, "cancelled": false}

	var raw_frames: PackedVector2Array = _mic_capture.get_buffer(avail)
	var target_sr := 16000
	var step := maxf(1.0, mix_rate / float(target_sr))
	var out_count := int(float(raw_frames.size()) / step)
	if out_count < 160:
		return {"wav_b64": "", "rms": 0.0, "duration_ms": 0, "cancelled": false}

	var pcm := PackedByteArray()
	pcm.resize(out_count * 2)
	var sum_sq := 0.0
	for i in range(out_count):
		var src_i := mini(raw_frames.size() - 1, int(float(i) * step))
		var mono := clampf((raw_frames[src_i].x + raw_frames[src_i].y) * 0.5, -1.0, 1.0)
		sum_sq += mono * mono
		pcm.encode_s16(i * 2, clampi(int(round(mono * 32767.0)), -32768, 32767))

	var rms := sqrt(sum_sq / float(out_count))
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
		"duration_ms": int(float(out_count) * 1000.0 / float(target_sr)),
		"cancelled": false,
	}


static func strip_emojis(raw: String) -> String:
	var buf := ""
	for i in range(raw.length()):
		var cp := raw.unicode_at(i)
		if cp >= 0x1F000 or cp in [0x2726, 0x2727, 0x2728, 0xFE0E, 0xFE0F]:
			continue
		buf += raw.substr(i, 1)
	return buf.strip_edges()
