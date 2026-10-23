extends SceneTree
const Journey = preload("res://scripts/journey_progress.gd")
const Progress = preload("res://scripts/p2_progress.gd")
var game: Node3D
var state: Node
var checks: Array=[]
var failures: Array=[]
var letters := "BCDEFGHIJKLMNOPQRSTUVWXYZ"
var capture := ""
var size_id := "1440x900"
var baseline := ""
var baseline_bak := ""
var demonstrate := false
var last_mouse := Vector2.ZERO
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--letters="): letters=arg.trim_prefix("--letters=")
		if arg.begins_with("--capture="): capture=arg.trim_prefix("--capture=")
		if arg.begins_with("--p2-size="): size_id=arg.trim_prefix("--p2-size=")
		if arg=="--demonstrate": demonstrate=true
	var dimensions := size_id.split("x")
	root.size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": root.grab_focus()
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
	for letter: String in letters:
		game._close()
		await game.change_room("landmark_"+letter)
		game.journey.show_letter_card(letter)
		await frames(4)
		var component: Control=game.journey.letter_activity
		check(is_instance_valid(component),"component/"+letter)
		if not is_instance_valid(component): continue
		check(component.spec.operations.size()>0,"operations/"+letter)
		await shot(letter+"-before")
		var index := 0
		if demonstrate:
			await click_text("完整示范")
			for frame: int in 500:
				await frames(1)
				if component.action_done: break
		while not component.action_done and index<5:
			var buttons: Array = component.actions.find_children("*","Button",true,false)
			check(not buttons.is_empty(),"operation_button/%s/%d"%[letter,index])
			if buttons.is_empty(): break
			await click(buttons[1] if letter=="U" else buttons[0])
			for i: int in 120:
				await frames(1)
				if not component.busy: break
			index+=1
			if letter in ["B","M","I","J","K","T"]: await shot(letter+"-step-"+str(index))
		check(component.action_done,"actions_complete/"+letter)
		check(int(state.data.journey.p2.letters[letter].step)==component.spec.operations.size(),"durable_operations/"+letter)
		check(not state.journey_snapshot().letters[letter].experienced,"new_experience_waits_for_glyph/"+letter)
		await shot(letter+"-after")
		await click_text("看看建筑里的 "+letter)
		await frames(3)
		check(state.data.journey.p2.letters[letter].glyph_seen,"glyph_saved/"+letter)
		check(state.journey_snapshot().letters[letter].experienced,"supported_experience/"+letter)
		check(component.picture.texture!=null,"source_model_image/"+letter)
		await shot(letter+"-glyph")
		await click_text("收下这张发现页")
		check(game.ui.current_panel=="prologue_result","result_screen/"+letter)
		state.load_state()
		check(state.data.journey.p2.letters[letter].glyph_seen,"disk_resume/"+letter)
	print("P2_UI_LOOP_DONE ",letters)
	await extra_checks()
	finish()

func fresh_c() -> Control:
	game._close()
	if game.room!="landmark_C": await game.change_room("landmark_C")
	state.data.journey.p2.letters.C=Progress.fresh().letters.C
	state.save_state()
	game.journey.show_letter_card("C")
	await frames(3)
	return game.journey.letter_activity

func extra_checks() -> void:
	var component: Control=await fresh_c()
	await click_text("小提示")
	check(state.data.journey.p2.letters.C.help==1,"visible_hint_saved")
	game._close()
	state.load_state()
	game.journey.show_letter_card("C")
	await frames(3)
	component=game.journey.letter_activity
	check(component.help==1,"hint_restored_in_view")
	await click_text("陪我一步")
	await click_text("小提示")
	check(state.data.journey.p2.letters.C.help==2,"support_never_downgraded")
	var original_path: String=state.save_path
	var blocker: String="user://p2-ui-blocker-%d"%OS.get_process_id()
	var file:=FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("isolated failure fixture")
	file.close()
	state.save_path=blocker+"/save.json"
	await click_text("拿起一颗莓果")
	await frames(30)
	check(component.action_step==0 and state.data.journey.p2.letters.C.step==0,"failed_save_restores_visible_and_durable_step")
	state.save_path=original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	component.reduced=false
	await click_text("拿起一颗莓果")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var stage_clock: float=component.stage.clock
	await frames(35)
	check(component.busy and state.data.journey.p2.letters.C.step==0,"background_pauses_uncommitted_action")
	check(is_equal_approx(component.stage.clock,stage_clock),"background_freezes_object_animation")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(45)
	check(component.action_step==1 and state.data.journey.p2.letters.C.step==1,"foreground_resumes_same_operation")
	game._close()
	state.load_state()
	game.journey.show_letter_card("C")
	await frames(3)
	component=game.journey.letter_activity
	check(component.action_step==1 and component.help==2,"half_finished_object_and_help_resume")
	await click_text("把莓果放到蛋糕上")
	await frames(30)
	game.muted=true
	await click_text("听字母名 C")
	check(not state.data.journey.p2.letters.C.letter_audio,"muted_does_not_claim_playback")
	game.muted=false
	await click_text("听字母名 C")
	check(state.data.journey.p2.letters.C.letter_audio and not state.data.journey.p2.letters.C.word_audio,"letter_audio_separate_from_word_audio")
	await click_text("听地标名")
	check(state.data.journey.p2.letters.C.word_audio,"actual_word_audio_saved")
	game.muted=true
	game.voice.stop()
	component=await fresh_c()
	var stage: Control=component.stage
	await pointer(stage.global_position+stage.size*Vector2(0.95,0.95),false)
	await mouse(stage.global_position+stage.size*Vector2(0.95,0.95),true)
	await mouse(stage.global_position+stage.size*Vector2(0.95,0.95),false)
	check(component.action_step==0,"empty_canvas_click_does_not_pick_an_object")
	var from:=stage.global_position+stage.size*Vector2(0.11,0.65)
	var to:=stage.global_position+stage.size*Vector2(0.61,0.42)
	await pointer(from,false)
	await mouse(from,true)
	for i: int in range(1,9): await pointer(from.lerp(to,float(i)/8),true)
	await mouse(to,false)
	await frames(65)
	check(component.action_done and state.data.journey.p2.letters.C.step==2,"real_drag_completes_pick_and_place")
	check(absf(float(state.data.journey.p2.letters.C.placement[0])-0.61)<0.01,"drag_keeps_chosen_placement")
	await shot("C-drag-complete")
	component=await fresh_c()
	await click_text("完整示范")
	await frames(100)
	check(component.action_done and component.demonstrated and state.data.journey.p2.letters.C.help==3,"full_demonstration_finishes_with_its_own_evidence")

func pointer(point: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	event.relative=point-last_mouse
	last_mouse=point
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)
	await frames(1)

func mouse(point: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed=pressed
	root.push_input(event,true)
	await frames(1)
func frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled,"clickable/"+button.text)
	await frames(2)
	var point:=button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"reachable/"+button.text)
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	await frames(1)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.global_position=point
		event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await frames(1)
	await frames(3)
func click_text(value: String) -> void:
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if button.text==value:
			await click(button)
			return
	check(false,"missing_button/"+value)
func shot(id: String) -> void:
	if capture.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture)
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture.path_join(id+".png"))
func hash_file(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
func check(passed: bool, id: String) -> void:
	checks.append({"id":id,"passed":passed})
	if not passed: failures.append(id); print("FAIL ",id)
func finish() -> void:
	check(hash_file("user://island-save-v1.json")==baseline and hash_file("user://island-save-v1.json.bak")==baseline_bak,"official_save_unchanged")
	var output:=FileAccess.open("res://../docs/verification/p2/ui-%s-%s%s.json"%[size_id,"headless" if DisplayServer.get_name()=="headless" else "native","-demo" if demonstrate else ""],FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"letters":letters,"result":"PASS" if failures.is_empty() else "FAIL","size":size_id,"renderer":DisplayServer.get_name()},"  "))
	output.close()
	print("P2_UI_RESULT checks=",checks.size()," failures=",failures.size())
	if is_instance_valid(state):
		for suffix: String in ["",".bak",".tmp"]:
			var path: String=state.save_path+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)

