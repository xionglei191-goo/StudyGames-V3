extends SceneTree
var game: Node3D
var directory := ProjectSettings.globalize_path("res://../docs/screenshots/v0.4.0")

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		printerr("Screenshots require -- --test-harness to protect the player save")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	create_timer(150).timeout.connect(func(): printerr("CAPTURE TIMEOUT"); quit(2))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.scene_ready:
		await process_frame
	game.muted = true
	game.sounds.enabled = false
	game.ui.reduced_motion = true
	game.set_process_unhandled_input(false)
	root.gui_disable_input = true
	game._close()
	DirAccess.make_dir_recursive_absolute(directory)
	await _capture("01-island")
	game.show_map()
	await _capture("01b-island-map")
	game._close()
	await game.change_room("home")
	await _capture("02-home")
	game.show_bag()
	await _capture("03-wardrobe")
	await game._on_action("outfit:pink")
	await _capture("04-wardrobe-pink")
	game.show_shop()
	await _capture("05-shop")
	await game._preview_purchase("flower_box")
	await _capture("06-purchase-preview")
	await game._on_action("buy:flower_box")
	await _capture("07-decorate")
	game._preview_decoration("flower_box")
	await _capture("08-decoration-preview")
	game._close()
	await game.change_room("landmark_C")
	game.interact_id("baker")
	await _capture("09-dialogue")
	game._close()
	await game.change_room("school")
	await _capture("10-school")
	game.show_map()
	await _capture("11-campus-map")
	game._close()
	await game.change_room("music_room")
	game.start_activity("music")
	game.ui.activity_board.play_note(0)
	game.ui.activity_board.play_note(2)
	await _capture("12-music")
	game._close()
	await game.change_room("art_room")
	game.start_activity("art")
	var painting := [{"color":0,"points":[[0.5,0.8],[0.5,0.42],[0.4,0.55],[0.5,0.61],[0.62,0.53]]},{"color":1,"points":[[0.5,0.42],[0.39,0.35],[0.4,0.23],[0.48,0.3],[0.51,0.16],[0.58,0.23],[0.55,0.32],[0.67,0.3],[0.62,0.42],[0.5,0.42]]},{"color":2,"points":[[0.48,0.35],[0.55,0.35]]},{"color":3,"points":[[0.15,0.21],[0.2,0.18],[0.25,0.2],[0.3,0.18]]}]
	game.ui.activity_board.canvas.restore(painting)
	game.ui.activity_board.dirty = true
	await game._on_action("save_art")
	await _capture("13-art")
	game._close()
	await game.change_room("science_room")
	game.start_activity("science")
	game.ui.activity_board.choose_pigment(1)
	game.ui.activity_board.choose_pigment(2)
	game.ui.activity_board.mix()
	await _capture("14-science")
	game._close()
	await game.change_room("football_field")
	game.start_activity("football")
	await _capture("15-football")
	game._close()
	game.show_journal()
	await _capture("16-journal")
	game._close()
	await game.change_room("classroom")
	game.start_unit(1)
	await _capture("17-lesson")
	game._close()
	root.size = Vector2i(960,640)
	await game.change_room("home")
	await _capture("18-small-home")
	game.show_bag()
	await _capture("19-small-wardrobe")
	game._close()
	await game.change_room("art_room")
	game.start_activity("art")
	await _capture("20-small-art")
	game._close()
	print("CAPTURE COMPLETE ",directory)
	quit(0)

func _capture(name: String) -> void:
	await create_timer(0.65).timeout
	await game._capture(directory,name)
	print("CAPTURE ",name)

