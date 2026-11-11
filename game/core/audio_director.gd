extends Node
## V4 Multi-layer Cozy Soundscape Director.
## Synthesizes warm acoustic kalimba/marimba pentatonic BGM, gentle nature breeze/birds,
## and crisp tactile toy Foley (page flips, wooden token snaps, bubble pops, footsteps)
## with zero external binary dependencies and graceful headless muting.

const SAMPLE_RATE := 22050

var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _foley_player: AudioStreamPlayer
var _clips: Dictionary = {}
var enabled := true
var current_room := "village"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "CozyBgmPlayer"
	_bgm_player.volume_db = -17.5
	add_child(_bgm_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "CozyAmbiencePlayer"
	_ambience_player.volume_db = -21.0
	add_child(_ambience_player)

	_foley_player = AudioStreamPlayer.new()
	_foley_player.name = "CozyFoleyPlayer"
	_foley_player.volume_db = -9.5
	add_child(_foley_player)

	_build_soundbank()

func set_enabled(on: bool) -> void:
	enabled = on and DisplayServer.get_name() != "headless"
	if not enabled:
		if is_instance_valid(_bgm_player):
			_bgm_player.stop()
		if is_instance_valid(_ambience_player):
			_ambience_player.stop()
	else:
		apply_room_soundscape(current_room)

func apply_room_soundscape(room_id: String) -> void:
	current_room = room_id
	if not enabled or not is_instance_valid(_bgm_player):
		return
	var bgm_key := "bgm_home" if room_id.begins_with("home") else "bgm_island"
	var bgm_stream := _clips.get(bgm_key) as AudioStreamWAV
	if bgm_stream != null and (_bgm_player.stream != bgm_stream or not _bgm_player.playing):
		_bgm_player.stream = bgm_stream
		_bgm_player.play()

	var outdoor := room_id in ["village", "home_estate", "school", "playground", "football_field"] or room_id.begins_with("landmark_")
	var amb_key := "amb_breeze" if outdoor else "amb_indoor"
	var amb_stream := _clips.get(amb_key) as AudioStreamWAV
	if amb_stream != null and (_ambience_player.stream != amb_stream or not _ambience_player.playing):
		_ambience_player.stream = amb_stream
		_ambience_player.play()

func play_foley(kind: String) -> void:
	if not enabled or not is_instance_valid(_foley_player):
		return
	var stream := _clips.get(kind) as AudioStreamWAV
	if stream != null:
		_foley_player.stream = stream
		_foley_player.pitch_scale = randf_range(0.95, 1.06)
		_foley_player.play()

func _build_soundbank() -> void:
	# C-major / F-lydian cozy pentatonic kalimba progression (8.0s seamless loop)
	var island_notes := [
		[0.0, 261.63, 1.6], [0.0, 329.63, 1.6], [0.5, 392.00, 0.9], [1.0, 523.25, 1.2],
		[2.0, 293.66, 1.5], [2.5, 440.00, 1.1], [3.0, 392.00, 1.2],
		[4.0, 349.23, 1.7], [4.0, 440.00, 1.5], [4.5, 523.25, 0.9], [5.0, 659.25, 1.3],
		[6.0, 392.00, 1.8], [6.5, 493.88, 0.9], [7.0, 587.33, 1.1]
	]
	_clips["bgm_island"] = _synth_kalimba_loop(8.0, island_notes)

	var home_notes := [
		[0.0, 261.63, 2.0], [0.6, 329.63, 1.4], [1.3, 392.00, 1.4],
		[2.5, 220.00, 2.0], [3.2, 329.63, 1.4], [4.0, 293.66, 1.8],
		[5.2, 349.23, 1.6], [6.2, 392.00, 1.7]
	]
	_clips["bgm_home"] = _synth_kalimba_loop(8.0, home_notes)

	_clips["amb_breeze"] = _synth_breeze_loop(5.0, true)
	_clips["amb_indoor"] = _synth_breeze_loop(5.0, false)
	_clips["page_flip"] = _synth_page_flip()
	_clips["slot_snap"] = _synth_wooden_pop(587.33, 880.0)
	_clips["bubble_pop"] = _synth_wooden_pop(440.0, 659.25)
	_clips["wardrobe_sparkle"] = _synth_sparkle()

func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
		pcm.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

func _synth_kalimba_loop(duration: float, notes: Array) -> AudioStreamWAV:
	var count := int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	for n: Array in notes:
		var start_i := int(float(n[0]) * SAMPLE_RATE)
		var freq := float(n[1])
		var len_s := float(n[2])
		var len_i := int(len_s * SAMPLE_RATE)
		for j in range(len_i):
			var idx := (start_i + j) % count
			var t := float(j) / float(SAMPLE_RATE)
			var env := minf(t / 0.012, 1.0) * exp(-t * 2.6)
			# Soft wooden tine: fundamental + gentle 2nd harmonic + quick woody transient
			var sig := sin(TAU * freq * t) * 0.75 + sin(TAU * freq * 2.0 * t) * 0.18 * exp(-t * 5.0)
			buf[idx] = clampf(buf[idx] + sig * env * 0.24, -0.95, 0.95)
	return _to_wav(buf, true)

func _synth_breeze_loop(duration: float, with_birds: bool) -> AudioStreamWAV:
	var count := int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.965 + white * 0.035
		var swell := 0.55 + 0.45 * sin(TAU * t / duration)
		var val := lp * swell * (0.16 if with_birds else 0.07)
		if with_birds and t > 1.4 and t < 1.62:
			var bt := t - 1.4
			val += sin(TAU * (1680.0 + sin(bt * 45.0) * 240.0) * bt) * exp(-bt * 12.0) * 0.06
		if with_birds and t > 3.3 and t < 3.48:
			var bt2 := t - 3.3
			val += sin(TAU * (1920.0 + bt2 * 600.0) * bt2) * exp(-bt2 * 14.0) * 0.05
		buf[i] = clampf(val, -0.9, 0.9)
	return _to_wav(buf, true)

func _synth_page_flip() -> AudioStreamWAV:
	var count := int(0.24 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var raw := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.78 + raw * 0.22
		var env := sin(PI * clampf(t / 0.24, 0.0, 1.0)) * exp(-t * 6.0)
		buf[i] = lp * env * 0.36
	return _to_wav(buf, false)

func _synth_wooden_pop(f0: float, f1: float) -> AudioStreamWAV:
	var count := int(0.14 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var freq := lerpf(f0, f1, clampf(t / 0.09, 0.0, 1.0))
		var env := minf(t / 0.006, 1.0) * exp(-t * 22.0)
		buf[i] = sin(TAU * freq * t) * env * 0.35
	return _to_wav(buf, false)

func _synth_sparkle() -> AudioStreamWAV:
	var count := int(0.42 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	var tones := [523.25, 659.25, 783.99, 1046.50]
	for idx in range(tones.size()):
		var start := int(float(idx) * 0.065 * SAMPLE_RATE)
		var f := float(tones[idx])
		for j in range(count - start):
			var t := float(j) / float(SAMPLE_RATE)
			buf[start + j] = clampf(buf[start + j] + sin(TAU * f * t) * exp(-t * 9.5) * 0.20, -0.9, 0.9)
	return _to_wav(buf, false)
