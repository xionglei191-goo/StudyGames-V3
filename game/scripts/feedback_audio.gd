extends Node
## Tiny original synthesized sounds: no network, external codecs or audio downloads.

var enabled := true
var cache: Dictionary = {}
var channels: Array[AudioStreamPlayer] = []
var channel_index := 0

func _ready() -> void:
	for index: int in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -17
		add_child(player)
		channels.append(player)

func play(kind: String, pitch: float = 1.0) -> void:
	if not enabled or channels.is_empty():
		return
	if not cache.has(kind):
		var notes := {"click":[660.0], "step":[95.0], "pickup":[523.25,783.99], "success":[523.25,659.25,783.99], "place":[392.0,523.25], "kick":[110.0], "miss":[329.63,261.63], "note":[440.0]}
		cache[kind] = _synthesize(notes.get(kind, [440.0]), 0.045 if kind in ["click","step","kick"] else 0.13, kind == "step")
	var player: AudioStreamPlayer = channels[channel_index % channels.size()]
	channel_index += 1
	player.stream = cache[kind]
	player.pitch_scale = pitch
	player.volume_db = -28 if kind == "step" else -17
	player.play()

func note(index: int) -> void:
	var frequencies := [261.63,293.66,329.63,349.23,392.0,440.0,493.88,523.25]
	play("note", frequencies[clampi(index,0,7)] / 440.0)

func stop_all() -> void:
	for player: AudioStreamPlayer in channels:
		player.stop()

func _synthesize(notes: Array, seconds: float, soft: bool) -> AudioStreamWAV:
	const RATE := 22050
	var frames := int(RATE * seconds)
	var samples := PackedByteArray()
	samples.resize(frames * notes.size() * 2)
	for part: int in notes.size():
		for frame: int in frames:
			var time := float(frame) / RATE
			var phase := float(frame) / frames
			var envelope := sin(PI * phase) * exp(-phase * (6.0 if soft else 3.0))
			var frequency: float = notes[part]
			var value := (sin(TAU * frequency * time) + 0.18*sin(TAU*frequency*2*time))*envelope*0.55
			samples.encode_s16((part*frames+frame)*2, int(clampf(value,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	return stream
