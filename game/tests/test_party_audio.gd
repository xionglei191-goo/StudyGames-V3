extends SceneTree
var checks: Array = []
var failures: Array = []

class AudioGame extends Node3D:
	var voice: AudioStreamPlayer
	var muted := false
	var application_backgrounded := false
	var room := "home"
	var curriculum: Dictionary = {}

class AudioUI extends CanvasLayer:
	var current_panel := "party"
	var modal: Control

class PauseStage extends Control:
	var paused := false

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition: failures.append(label); print("FAIL ",label)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	create_timer(25.0).timeout.connect(func(): print("FAIL audio_test_timeout"); quit(1))
	var protected: Dictionary = {}
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: protected[path] = _hash(path)
	var game := AudioGame.new()
	root.add_child(game)
	game.curriculum = JSON.parse_string(FileAccess.get_file_as_string("res://data/curriculum.json"))
	game.voice = AudioStreamPlayer.new()
	game.voice.volume_db = -80
	game.add_child(game.voice)
	var silence := AudioStreamWAV.new()
	silence.format = AudioStreamWAV.FORMAT_16_BITS
	silence.mix_rate = 44100
	var samples := PackedByteArray()
	samples.resize(88200)
	silence.data = samples
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 44100
	game.voice.stream = silence
	game.voice.play()
	var ui := AudioUI.new()
	root.add_child(ui)
	ui.modal = Control.new()
	ui.add_child(ui.modal)
	var stage := PauseStage.new()
	root.add_child(stage)
	var controller: Node = load("res://scripts/party_controller.gd").new()
	root.add_child(controller)
	controller.set_process(false)
	controller.game = game
	controller.ui = ui
	controller.stage = stage
	controller._play_narration("hello")
	check(is_instance_valid(controller.narration) and controller.narration.playing,"party_uses_its_own_playing_narration")
	check(controller.narration.get_parent() == stage and controller.narration != game.voice,"voice_owned_by_visible_stage")
	check(game.voice.playing and game.voice.stream == silence and not game.voice.stream_paused,"starting_party_leaves_existing_shared_voice_untouched")
	controller.toggle_pause()
	check(controller.narration.stream_paused and stage.paused,"explicit_pause_stops_voice_and_visual")
	check(game.voice.playing and not game.voice.stream_paused,"party_pause_does_not_pause_shared_voice")
	controller.toggle_pause()
	check(not controller.narration.stream_paused and not stage.paused,"resume_restores_party_voice_and_visual")
	controller.playback_active = true
	game.application_backgrounded = true
	controller._process(2.0)
	check(controller.narration.stream_paused and stage.paused and controller.playback_elapsed == 0.0,"background_stops_narration_and_watch_timer")
	game.application_backgrounded = false
	controller._process(0.1)
	check(not controller.narration.stream_paused and not stage.paused and controller.playback_elapsed == 0.1,"foreground_resumes_owned_narration_and_timer")
	controller.toggle_pause()
	ui.current_panel = "another_screen"
	game.voice.play()
	controller._process(1.0)
	check(not controller.narration.playing and not controller.narration.stream_paused,"leaving_clears_own_paused_narration")
	check(game.voice.playing and not game.voice.stream_paused,"new_shared_voice_not_stopped_or_left_paused")
	game.voice.stream_paused = true
	controller._stop_narration()
	check(game.voice.stream_paused,"cleanup_preserves_another_voices_own_pause")
	controller.playback_paused = false
	controller._play_narration("hello")
	check(controller.narration.playing and not controller.narration.stream_paused,"next_party_starts_without_stale_pause")
	root.remove_child(stage)
	check(not controller.narration.playing,"stage_tree_exit_stops_its_owned_narration")
	controller.narration.stream = null
	game.voice.stop()
	game.voice.stream = null
	silence = null
	stage.free()
	controller.queue_free()
	ui.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	# Let the audio mixer release stopped playback instances before the harness exits.
	await create_timer(0.2).timeout
	for path: String in protected: check(_hash(path) == protected[path],"production_preserved_"+path)
	var directory := ProjectSettings.globalize_path("res://../docs/verification/life-keepsakes/party")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory+"/audio-%d.json" % OS.get_process_id()
	var report := FileAccess.open(path,FileAccess.WRITE)
	if report == null: print("FAIL report_write"); quit(1); return
	report.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Owned narration pause/resume, background watch timer, teardown, shared voice isolation. Uses existing phrases quietly; no save writes."},"  "))
	report.close()
	print("PARTY_AUDIO checks=",checks.size()," failures=",failures.size()," report=",path)
	quit(0 if failures.is_empty() else 1)

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
