extends Node
## V4.5 Multi-Layer Stereo Cozy Soundscape & Original Acoustic BGM Director.
## Synthesizes 4 distinct stereo multi-instrument acoustic BGM compositions
## (Morning Breeze Guitar & Kalimba, Warm Hearth Music-Box & Rhodes, Sunlit Campus
## Xylophone & Pizzicato, Pop-up Wonder Harp & Celesta), nature breeze/rain,
## and crisp tactile toy Foley with graceful headless muting.

const SAMPLE_RATE := 22050

var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _foley_player: AudioStreamPlayer
var _clips: Dictionary = {}
var enabled := true
var current_room := "village"
var current_weather := "clear"
var theater_mode := false
var active_bgm_key := "bgm_island"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "CozyBgmPlayer"
	_bgm_player.volume_db = -15.5
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

static func select_bgm_key(room_id: String, is_theater: bool = false) -> String:
	if is_theater:
		return "bgm_theater"
	if room_id.begins_with("home"):
		return "bgm_home"
	if room_id in ["school", "classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field"]:
		return "bgm_campus"
	if room_id.begins_with("landmark_"):
		var code := room_id.trim_prefix("landmark_")
		if code in ["G", "I", "L", "O", "Q", "S", "U", "X"]:
			return "bgm_theater"
	return "bgm_island"

func set_enabled(on: bool) -> void:
	enabled = on and DisplayServer.get_name() != "headless"
	if not enabled:
		if is_instance_valid(_bgm_player):
			_bgm_player.stop()
		if is_instance_valid(_ambience_player):
			_ambience_player.stop()
	else:
		if _clips.is_empty():
			_build_soundbank()
		apply_room_soundscape(current_room, current_weather)

func set_theater_mode(active: bool) -> void:
	theater_mode = active
	active_bgm_key = select_bgm_key(current_room, theater_mode)
	apply_room_soundscape(current_room, current_weather)

func apply_room_soundscape(room_id: String, weather_id: String = "clear") -> void:
	current_room = room_id
	current_weather = weather_id
	active_bgm_key = select_bgm_key(room_id, theater_mode)
	if not enabled or not is_instance_valid(_bgm_player):
		return
	var bgm_stream := _clips.get(active_bgm_key) as AudioStreamWAV
	if bgm_stream != null and (_bgm_player.stream != bgm_stream or not _bgm_player.playing):
		_bgm_player.stream = bgm_stream
		_bgm_player.play()

	var outdoor := room_id in ["village", "home_estate", "school", "playground", "football_field"] or room_id.begins_with("landmark_")
	var amb_key := "amb_rain" if (outdoor and weather_id == "light_rain") else ("amb_breeze" if outdoor else "amb_indoor")
	var amb_stream := _clips.get(amb_key) as AudioStreamWAV
	if amb_stream != null and (_ambience_player.stream != amb_stream or not _ambience_player.playing):
		_ambience_player.stream = amb_stream
		_ambience_player.play()

func play_footstep_for_room(room_id: String) -> void:
	if not enabled:
		return
	var surface := "step_grass"
	if room_id.begins_with("home") and room_id != "home_estate":
		surface = "step_wood"
	elif room_id in ["classroom", "music_room", "art_room", "landmark_C", "landmark_H", "landmark_O", "landmark_Q", "landmark_Y"]:
		surface = "step_wood"
	elif room_id in ["school", "canteen", "science_room", "landmark_G", "landmark_R", "landmark_S", "landmark_T", "landmark_Z"]:
		surface = "step_stone"
	play_foley(surface)

func play_foley(kind: String) -> void:
	if not enabled or not is_instance_valid(_foley_player):
		return
	var stream := _clips.get(kind) as AudioStreamWAV
	if stream != null:
		_foley_player.stream = stream
		_foley_player.pitch_scale = randf_range(0.95, 1.06)
		_foley_player.play()

func _build_soundbank() -> void:
	# 1. bgm_island — Morning Breeze Village (16s Stereo: Acoustic Guitar + Kalimba + Warm Bass)
	var island_events := [
		# Bar 1 (G6): G2 bass + guitar arpeggio + kalimba motif
		[0.0, 98.00, 3.6, "bass", 0.0],
		[0.0, 196.00, 1.4, "guitar", -0.35], [0.5, 246.94, 1.3, "guitar", -0.25], [1.0, 293.66, 1.3, "guitar", -0.20], [1.5, 392.00, 1.4, "guitar", -0.30],
		[0.0, 587.33, 1.1, "kalimba", 0.30], [1.0, 659.25, 0.9, "kalimba", 0.35], [1.5, 783.99, 1.4, "kalimba", 0.25], [2.5, 659.25, 1.1, "kalimba", 0.30], [3.0, 587.33, 1.0, "kalimba", 0.20],
		# Bar 2 (Em7)
		[4.0, 82.41, 3.6, "bass", 0.0],
		[4.0, 164.81, 1.5, "guitar", -0.35], [4.5, 246.94, 1.3, "guitar", -0.25], [5.0, 293.66, 1.3, "guitar", -0.20], [5.5, 392.00, 1.4, "guitar", -0.30],
		[4.0, 493.88, 1.2, "kalimba", 0.28], [5.0, 587.33, 0.9, "kalimba", 0.32], [5.5, 659.25, 1.5, "kalimba", 0.25], [7.0, 587.33, 1.0, "kalimba", 0.28],
		# Bar 3 (Cmaj7)
		[8.0, 130.81, 3.6, "bass", 0.0],
		[8.0, 261.63, 1.5, "guitar", -0.32], [8.5, 329.63, 1.3, "guitar", -0.22], [9.0, 392.00, 1.3, "guitar", -0.18], [9.5, 493.88, 1.4, "guitar", -0.28],
		[8.0, 523.25, 1.2, "kalimba", 0.32], [9.0, 659.25, 1.0, "kalimba", 0.35], [9.5, 783.99, 1.3, "kalimba", 0.26], [10.5, 880.00, 1.2, "kalimba", 0.30],
		# Bar 4 (Dadd9 -> gentle turnaround)
		[12.0, 146.83, 3.6, "bass", 0.0],
		[12.0, 293.66, 1.5, "guitar", -0.32], [12.5, 369.99, 1.3, "guitar", -0.22], [13.0, 440.00, 1.3, "guitar", -0.18], [13.5, 329.63, 1.5, "guitar", -0.26],
		[12.0, 659.25, 1.4, "kalimba", 0.30], [13.0, 587.33, 1.1, "kalimba", 0.26], [14.0, 493.88, 1.0, "kalimba", 0.22], [14.5, 440.00, 1.2, "kalimba", 0.18]
	]
	_clips["bgm_island"] = _synth_stereo_ensemble_loop(16.0, island_events)

	# 2. bgm_home — Warm Hearth & Tea (16s Stereo: Rhodes Warm Chords + Music Box Lullaby)
	var home_events := [
		# Fmaj7
		[0.0, 174.61, 3.8, "rhodes", -0.20], [0.0, 220.00, 3.8, "rhodes", 0.15], [0.0, 261.63, 3.8, "rhodes", -0.10], [0.0, 329.63, 3.8, "rhodes", 0.22],
		[0.0, 523.25, 1.4, "celesta", 0.25], [1.0, 659.25, 1.2, "celesta", -0.20], [2.0, 587.33, 1.5, "celesta", 0.20], [3.0, 523.25, 1.1, "celesta", -0.15],
		# Dm7
		[4.0, 146.83, 3.8, "rhodes", -0.20], [4.0, 220.00, 3.8, "rhodes", 0.15], [4.0, 261.63, 3.8, "rhodes", -0.10], [4.0, 349.23, 3.8, "rhodes", 0.22],
		[4.0, 440.00, 1.5, "celesta", 0.22], [5.5, 523.25, 1.2, "celesta", -0.22], [6.5, 587.33, 1.4, "celesta", 0.18],
		# Bbmaj7
		[8.0, 116.54, 3.8, "rhodes", -0.20], [8.0, 233.08, 3.8, "rhodes", 0.15], [8.0, 293.66, 3.8, "rhodes", -0.10], [8.0, 349.23, 3.8, "rhodes", 0.22],
		[8.0, 698.46, 1.4, "celesta", 0.26], [9.0, 659.25, 1.2, "celesta", -0.18], [10.0, 587.33, 1.5, "celesta", 0.22], [11.0, 523.25, 1.1, "celesta", -0.15],
		# C9sus4
		[12.0, 130.81, 3.8, "rhodes", -0.18], [12.0, 233.08, 3.8, "rhodes", 0.16], [12.0, 293.66, 3.8, "rhodes", -0.10], [12.0, 349.23, 3.8, "rhodes", 0.20],
		[12.0, 587.33, 1.6, "celesta", 0.20], [13.5, 523.25, 1.2, "celesta", -0.20], [14.5, 440.00, 1.4, "celesta", 0.15]
	]
	_clips["bgm_home"] = _synth_stereo_ensemble_loop(16.0, home_events)

	# 3. bgm_campus — Sunlit Chalk & Xylophone (16s Stereo: Playful Marimba + Pizzicato Bass)
	var campus_events := [
		# D major playful bounce
		[0.0, 146.83, 0.8, "pizz", -0.15], [1.0, 220.00, 0.8, "pizz", -0.15], [2.0, 146.83, 0.8, "pizz", -0.15], [3.0, 220.00, 0.8, "pizz", -0.15],
		[0.0, 587.33, 0.7, "kalimba", 0.25], [0.5, 659.25, 0.7, "kalimba", -0.20], [1.0, 739.99, 1.0, "kalimba", 0.28], [2.0, 880.00, 0.9, "celesta", -0.25], [3.0, 739.99, 0.9, "kalimba", 0.22],
		# Bm7
		[4.0, 123.47, 0.8, "pizz", -0.15], [5.0, 185.00, 0.8, "pizz", -0.15], [6.0, 123.47, 0.8, "pizz", -0.15], [7.0, 185.00, 0.8, "pizz", -0.15],
		[4.0, 659.25, 0.8, "kalimba", 0.24], [5.0, 587.33, 0.8, "kalimba", -0.22], [6.0, 493.88, 1.1, "kalimba", 0.26], [7.0, 587.33, 0.8, "celesta", -0.18],
		# Gmaj7
		[8.0, 98.00, 0.8, "pizz", -0.15], [9.0, 146.83, 0.8, "pizz", -0.15], [10.0, 196.00, 0.8, "pizz", -0.15], [11.0, 146.83, 0.8, "pizz", -0.15],
		[8.0, 587.33, 0.7, "kalimba", 0.25], [8.5, 659.25, 0.7, "kalimba", -0.20], [9.0, 783.99, 1.1, "celesta", 0.30], [10.5, 739.99, 0.9, "kalimba", -0.22], [11.25, 659.25, 0.7, "kalimba", 0.20],
		# Asus4 -> A
		[12.0, 110.00, 0.8, "pizz", -0.15], [13.0, 164.81, 0.8, "pizz", -0.15], [14.0, 220.00, 1.2, "pizz", -0.15],
		[12.0, 587.33, 1.0, "kalimba", 0.25], [13.0, 554.37, 1.0, "kalimba", -0.22], [14.0, 659.25, 1.4, "celesta", 0.24]
	]
	_clips["bgm_campus"] = _synth_stereo_ensemble_loop(16.0, campus_events)

	# 4. bgm_theater — Pop-up Wonder Book (16s Stereo: Harp Arpeggios + Celesta Bell)
	var theater_events := [
		[0.0, 261.63, 1.8, "guitar", -0.35], [0.4, 329.63, 1.6, "guitar", -0.15], [0.8, 392.00, 1.6, "guitar", 0.15], [1.2, 493.88, 1.6, "guitar", 0.35],
		[1.6, 783.99, 1.8, "celesta", 0.25], [2.8, 659.25, 1.2, "celesta", -0.25],
		[4.0, 220.00, 1.8, "guitar", -0.35], [4.4, 261.63, 1.6, "guitar", -0.15], [4.8, 329.63, 1.6, "guitar", 0.15], [5.2, 392.00, 1.6, "guitar", 0.35],
		[5.6, 659.25, 1.8, "celesta", 0.22], [6.8, 587.33, 1.2, "celesta", -0.22],
		[8.0, 174.61, 1.8, "guitar", -0.35], [8.4, 261.63, 1.6, "guitar", -0.15], [8.8, 349.23, 1.6, "guitar", 0.15], [9.2, 440.00, 1.6, "guitar", 0.35],
		[9.6, 880.00, 1.8, "celesta", 0.28], [10.8, 783.99, 1.2, "celesta", -0.22],
		[12.0, 196.00, 1.8, "guitar", -0.35], [12.4, 293.66, 1.6, "guitar", -0.15], [12.8, 392.00, 1.6, "guitar", 0.15], [13.2, 493.88, 1.6, "guitar", 0.35],
		[13.6, 783.99, 1.6, "celesta", 0.20], [14.8, 587.33, 1.2, "celesta", -0.20]
	]
	_clips["bgm_theater"] = _synth_stereo_ensemble_loop(16.0, theater_events)

	_clips["amb_breeze"] = _synth_breeze_loop(5.0, true)
	_clips["amb_indoor"] = _synth_breeze_loop(5.0, false)
	_clips["amb_rain"] = _synth_rain_loop(4.5)
	_clips["page_flip"] = _synth_page_flip()
	_clips["slot_snap"] = _synth_wooden_pop(587.33, 880.0)
	_clips["bubble_pop"] = _synth_wooden_pop(440.0, 659.25)
	_clips["decor_place"] = _synth_wooden_pop(220.0, 523.25)
	_clips["decor_rotate"] = _synth_wooden_pop(392.0, 587.33)
	_clips["bell_ding"] = _synth_sparkle()
	_clips["wardrobe_sparkle"] = _synth_sparkle()
	_clips["step_grass"] = _synth_footstep("grass")
	_clips["step_wood"] = _synth_footstep("wood")
	_clips["step_stone"] = _synth_footstep("stone")

func _synth_stereo_ensemble_loop(duration: float, events: Array) -> AudioStreamWAV:
	var frames := int(duration * SAMPLE_RATE)
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(frames)
	right.resize(frames)
	left.fill(0.0)
	right.fill(0.0)

	for ev: Array in events:
		var start_i := int(float(ev[0]) * SAMPLE_RATE)
		var freq := float(ev[1])
		var len_s := float(ev[2])
		var inst := str(ev[3])
		var pan := clampf(float(ev[4]), -0.8, 0.8)
		var gain_l := sqrt(0.5 * (1.0 - pan))
		var gain_r := sqrt(0.5 * (1.0 + pan))
		var len_i := int(len_s * SAMPLE_RATE)

		for j in range(len_i):
			var idx := (start_i + j) % frames
			var t := float(j) / float(SAMPLE_RATE)
			var sig := 0.0
			if inst == "guitar":
				var env := minf(t / 0.008, 1.0) * exp(-t * 2.1)
				sig = (sin(TAU * freq * t) * 0.68 + sin(TAU * freq * 2.0 * t) * 0.24 * exp(-t * 3.5) + sin(TAU * freq * 3.0 * t) * 0.08 * exp(-t * 6.0)) * env * 0.20
			elif inst == "kalimba":
				var env := minf(t / 0.010, 1.0) * exp(-t * 2.8)
				sig = (sin(TAU * freq * t) * 0.78 + sin(TAU * freq * 2.98 * t) * 0.14 * exp(-t * 9.0)) * env * 0.21
			elif inst == "celesta":
				var env := minf(t / 0.012, 1.0) * exp(-t * 2.3)
				sig = (sin(TAU * freq * t) * 0.72 + sin(TAU * freq * 2.0 * t) * 0.20 + sin(TAU * freq * 4.0 * t) * 0.08 * exp(-t * 7.0)) * env * 0.18
			elif inst == "rhodes":
				var fade_out := clampf((len_s - t) / 0.25, 0.0, 1.0)
				var trem := 0.88 + 0.12 * sin(TAU * 3.2 * t)
				var env := minf(t / 0.04, 1.0) * exp(-t * 0.55) * fade_out * trem
				sig = (sin(TAU * freq * t) * 0.82 + sin(TAU * freq * 2.0 * t) * 0.14 * exp(-t * 2.0)) * env * 0.11
			elif inst == "pizz":
				var env := minf(t / 0.006, 1.0) * exp(-t * 5.2)
				sig = (sin(TAU * freq * t) * 0.75 + sin(TAU * freq * 2.0 * t) * 0.25 * exp(-t * 8.0)) * env * 0.22
			else: # warm upright bass
				var fade_out := clampf((len_s - t) / 0.20, 0.0, 1.0)
				var env := minf(t / 0.025, 1.0) * exp(-t * 0.85) * fade_out
				sig = (sin(TAU * freq * t) * 0.85 + sin(TAU * freq * 2.0 * t) * 0.15) * env * 0.18
			left[idx] += sig * gain_l
			right[idx] += sig * gain_r

	# Subtle warm stereo room reflection (Haas 24ms cross-echo) for spacious studio warmth
	var delay_samples := int(0.024 * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frames * 4)
	for i in range(frames):
		var prev_i := (i - delay_samples + frames) % frames
		var out_l := clampf(left[i] + right[prev_i] * 0.14, -0.92, 0.92)
		var out_r := clampf(right[i] + left[prev_i] * 0.14, -0.92, 0.92)
		pcm.encode_s16(i * 4, clampi(int(round(out_l * 32767.0)), -32768, 32767))
		pcm.encode_s16(i * 4 + 2, clampi(int(round(out_r * 32767.0)), -32768, 32767))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = true
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav

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

func _synth_footstep(surface: String) -> AudioStreamWAV:
	var count := int(0.11 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = surface.hash()
	var lp := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var raw := rng.randf_range(-1.0, 1.0)
		if surface == "grass":
			lp = lp * 0.72 + raw * 0.28
			var env := sin(PI * clampf(t / 0.10, 0.0, 1.0)) * exp(-t * 18.0)
			buf[i] = lp * env * 0.22
		elif surface == "wood":
			var thump := sin(TAU * 165.0 * t) * exp(-t * 36.0) * 0.28 + sin(TAU * 310.0 * t) * exp(-t * 48.0) * 0.14
			buf[i] = clampf(thump, -0.8, 0.8)
		else:
			lp = lp * 0.45 + raw * 0.55
			var click := (sin(TAU * 520.0 * t) * 0.16 + lp * 0.20) * exp(-t * 44.0)
			buf[i] = clampf(click, -0.8, 0.8)
	return _to_wav(buf, false)

func _synth_rain_loop(duration: float) -> AudioStreamWAV:
	var count := int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	var lp := 0.0
	for i in range(count):
		var white := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.84 + white * 0.16
		var drop := 0.0
		if rng.randf() < 0.0025:
			drop = rng.randf_range(-0.18, 0.18)
		buf[i] = clampf(lp * 0.14 + drop, -0.85, 0.85)
	return _to_wav(buf, true)
