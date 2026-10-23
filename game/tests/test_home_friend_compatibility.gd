extends "res://tests/test_friend_corner_game.gd"
## Reuse the full friend-corner integration in an unattended native window.
## Only focus flags are held in the foreground state; actions and rendering use
## the production implementation. The player save is isolated by the base test.

func _initialize() -> void:
	process_frame.connect(_keep_test_clock_running)
	run.call_deferred()

func _keep_test_clock_running() -> void:
	if is_instance_valid(game):
		game.application_backgrounded = false
		if is_instance_valid(game.living):
			game.living._focus_backgrounded = false
			game.living.set_context({"backgrounded":false})
