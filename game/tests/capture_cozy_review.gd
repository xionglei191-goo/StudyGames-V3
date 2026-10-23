extends SceneTree
## Deterministic presentation review. Always uses an isolated validation save.
const Journey = preload("res://scripts/journey_progress.gd")
const Content = preload("res://ui/memory_story_content.gd")
var game: Node3D
var phase := "before"
var size_id := "1440x900"
var output_dir := ""
var save_path := ""
var protected: Dictionary = {}
var captures: Array = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--cozy-phase="): phase = argument.trim_prefix("--cozy-phase=")
		if argument.begins_with("--cozy-size="): size_id = argument.trim_prefix("--cozy-size=")
	var dimensions := size_id.split("x")
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	root.grab_focus()
	output_dir = ProjectSettings.globalize_path("res://../docs/verification/cozy-ui/"+phase+"/"+size_id)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): output_dir = argument.trim_prefix("--report-dir=").path_join(size_id)
	DirAccess.make_dir_recursive_absolute(output_dir)
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]:
		protected[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	create_timer(150.0).timeout.connect(func(): print("COZY_CAPTURE_TIMEOUT"); quit(2))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.scene_ready: await process_frame
	var state: Node = root.get_node("State")
	save_path = state.save_path
	game.muted = true
	game.sounds.enabled = false
	state.data = state._default_state()
	state.data.preferences.fixed_day = true
	game.ui.reduced_motion = true
	game._close()
	await game.change_room("home")
	await shot("01-home")
	game.journey.show_home()
	await shot("02-welcome-dialogue")
	game.journey.show_hub()
	await shot("03-travel-journal")
	game.show_bag()
	await shot("04-wardrobe")
	game._close()
	await game.change_room("landmark_C")
	game.interact_id("baker")
	await shot("05-bakery-dialogue")
	game._close()
	await game.change_room("school")
	await shot("06-school")
	game.show_settings()
	await shot("07-settings")
	game._close()
	await game.change_room("village")
	await shot("08-island")
	game._close()
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(state.data.journey,step)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(state.data.journey,letter,"landmark_"+letter,fact,"demonstration_viewed")
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(state.data.journey,step,{},1000.0)
	await game.journey.p2.show_chapter()
	await shot("09-invitation")
	if phase != "before":
		for entry: Dictionary in Content.list_entries("","","book"):
			if str(entry.spelling_display).to_lower() != "book": continue
			game.journey.open_story(str(entry.entry_id))
			await process_frame
			game.journey.current_memory._play_story()
			await shot("10-word-story-font-check")
			game.journey.close_memory()
			break
	var preserved := true
	for path: String in protected:
		preserved = preserved and (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == protected[path]
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase":phase,"requested_window":size_id,"captures":captures,"production_preserved":preserved,"scope":"Presentation fixtures, not a full gameplay or learning-effectiveness test."},"  "))
	file.close()
	if save_path == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	print("COZY_CAPTURE phase=",phase," size=",size_id," images=",captures.size()," production_preserved=",preserved)
	quit(0 if preserved else 1)

func shot(id: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(output_dir.path_join(id+".png"))
	captures.append({"id":id,"image_size":[picture.get_width(),picture.get_height()],"actual_window":[root.size.x,root.size.y],"logical_ui":[game.ui.root.size.x,game.ui.root.size.y],"room":game.room,"panel":game.ui.current_panel,"camera_size":game.camera.size})
