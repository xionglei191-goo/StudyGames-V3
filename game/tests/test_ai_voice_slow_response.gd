extends SceneTree
## A real loopback HTTP response arrives after the old five-second timeout.
const Bridge = preload("res://core/ai_companion_bridge.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("VOICE_SLOW_RESPONSE: " + label)

func _run() -> void:
	create_timer(14).timeout.connect(func(): quit(1))
	var server := TCPServer.new()
	var listen_error := server.listen(0, "127.0.0.1")
	_check(listen_error == OK, "isolated loopback fixture starts")
	if listen_error != OK:
		quit(1)
		return
	var bridge := Bridge.new()
	root.add_child(bridge)
	bridge.base_url = "http://127.0.0.1:%d" % server.get_local_port()
	var played: Array[String] = []
	bridge.voice_playback_started.connect(func(_profile: String, _label: String, engine: String): played.append(engine))
	bridge._dispatch_tts_request("hello", "en", "warm", bridge._speak_seq, false)
	var deadline := Time.get_ticks_msec() + 2500
	while not server.is_connection_available() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(server.is_connection_available(), "bridge sends actual HTTP request")
	if not server.is_connection_available():
		bridge.queue_free()
		server.stop()
		quit(1)
		return
	var connection := server.take_connection()
	await create_timer(6.1).timeout
	_check(played.is_empty(), "cold voice is not replaced by premature fallback")
	var payload := JSON.stringify({"ok":true, "engine":"delayed_fixture", "voice_profile":"teacher_gentle", "wav_base64":Marshalls.raw_to_base64(_wav_bytes())}).to_utf8_buffer()
	var response := ("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % payload.size()).to_utf8_buffer()
	response.append_array(payload)
	_check(connection.put_data(response) == OK, "delayed audio response is delivered")
	deadline = Time.get_ticks_msec() + 2000
	while played.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(played == ["delayed_fixture"], "voice arriving after six seconds is played exactly once")
	bridge.queue_free()
	connection.disconnect_from_host()
	server.stop()
	await process_frame
	print("VOICE_SLOW_RESPONSE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

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
