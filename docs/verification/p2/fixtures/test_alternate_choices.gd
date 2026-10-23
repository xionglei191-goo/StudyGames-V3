extends "res://tests/test_p2_ui.gd"
## External verification fixture; leaves measured game sources unchanged.
func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	root.size=Vector2i(960,640)
	root.grab_focus()
	size_id="960x640"
	capture=ProjectSettings.globalize_path("res://../docs/verification/p2/native-alternate-960")
	baseline=hash_file("user://island-save-v1.json")
	baseline_bak=hash_file("user://island-save-v1.json.bak")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for i: int in 1200:
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready,"scene_ready")
	if not game.scene_ready: finish(); return
	state=root.get_node("State")
	state.data=state._default_state()
	for id: String in Journey.HOME_STEPS: state.journey_complete_home_step(id)
	game.ui.reduced_motion=true
	game.muted=true
	for letter: String in "FHPR":
		game._close()
		await game.change_room("landmark_"+letter)
		game.journey.show_letter_card(letter)
		await frames(4)
		var component: Control=game.journey.letter_activity
		var buttons: Array=component.actions.find_children("*","Button",true,false)
		check(buttons.size()==2,"two_distinct_choices/"+letter)
		if buttons.size()!=2: continue
		await click(buttons[1])
		for i: int in 120:
			await frames(1)
			if not component.busy: break
		check(component.action_done and component.stage.choice==1,"alternate_visually_selected/"+letter)
		check(state.data.journey.p2.letters[letter].choice==1,"alternate_saved/"+letter)
		await shot(letter+"-alternate")
		state.load_state()
		check(state.data.journey.p2.letters[letter].choice==1,"alternate_disk_recovery/"+letter)
	finish()

func finish() -> void:
	check(hash_file("user://island-save-v1.json")==baseline and hash_file("user://island-save-v1.json.bak")==baseline_bak,"official_save_unchanged")
	var file:=FileAccess.open("res://../docs/verification/p2/alternate-choices.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"result":"PASS" if failures.is_empty() else "FAIL","scope":"Real second-option UI input and disk recovery for F/H/P/R, Windows 960x640; 960x600 content."},"  "))
	file.close()
	print("P2_ALTERNATE checks=",checks.size()," failures=",failures.size())
	if is_instance_valid(state):
		for suffix: String in ["",".bak",".tmp"]:
			var path: String=state.save_path+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)
