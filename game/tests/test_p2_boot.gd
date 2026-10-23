extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 900:
		await process_frame
		if game.scene_ready: break
	print("P2_BOOT ",game.scene_ready, " controller ",is_instance_valid(game.journey.p2))
	quit(0 if game.scene_ready else 1)
