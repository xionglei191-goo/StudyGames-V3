extends SceneTree
const Journey=preload("res://scripts/journey_progress.gd")
const Progress=preload("res://scripts/p2_progress.gd")
var game: Node3D
var state: Node
var checks: Array=[]
var failures: Array=[]
var capture := ""
var size_id := "1440x900"
var report_dir := "res://../docs/verification/p2"
var baseline: Dictionary={}
var actors: Array=[]
var layout: Array=[]
var last_mouse := Vector2.ZERO
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture=arg.trim_prefix("--capture=")
		if arg.begins_with("--p2-size="): size_id=arg.trim_prefix("--p2-size=")
		if arg.begins_with("--report-dir="): report_dir=arg.trim_prefix("--report-dir=")
	var dimensions:=size_id.split("x")
	root.size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": root.grab_focus()
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: baseline[path]=hash_file(path)
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
	for id: String in Journey.HOME_STEPS: Journey.complete_home_step(state.data.journey,id)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(state.data.journey,letter,"landmark_"+letter,fact,"demonstration_viewed")
	for id: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(state.data.journey,id,{},1000.0)
	state.save_state()
	game.ui.reduced_motion=true
	game.muted=true
	await game.journey.p2.show_chapter()
	for number: int in [2,3]:
		for step: Dictionary in Progress.content().chapters[str(number)].steps:
			await wait_step(step.id)
			check(game.room==step.room,"room/"+step.id)
			var actor: Node3D=game.living.get_actor(step.actor)
			check(actor!=null,"actor/"+step.actor+"/"+step.id)
			if actor: actors.append({"step":step.id,"id":step.actor,"status":actor.get_status()})
			await shot(step.id+"-scene")
			match str(step.kind):
				"question":
					await click_text("和朋友回应")
					if step.id=="U2-02":
						await click_text("Goodbye!")
						check(not state.data.journey.p2.trials[step.id].completed,"wrong_name_response_retries")
						await click_text("小提示")
						await click_text("陪我选择")
						var trial_id: String=state.data.journey.p2.trials[step.id].id
						game._close()
						state.load_state()
						await game.journey.p2.show_chapter()
						await click_text("和朋友回应")
						check(state.data.journey.p2.trials[step.id].id==trial_id and state.data.journey.p2.trials[step.id].help==2,"same_trial_and_help_after_exit_reload")
						await click_text("完整示范")
						await shot(step.id+"-demo")
						await click_text("看过示范，继续")
					else:
						if step.id=="U2-05": await click_text("小提示")
						for option: Dictionary in step.question.options:
							if option.id==step.question.correct: await click_text(option.text)
					var trial: Dictionary=state.data.journey.p2.trials[step.id]
					check(trial.completed,"response_completed/"+step.id)
					check(trial.result==("demonstrated" if step.id=="U2-02" else "supported_correct" if step.id=="U2-05" else "independent_correct"),"response_conditions/"+step.id)
					await click_text("继续")
				"mail":
					await click_text("邀请给 Lingling")
					await click_text("Tim 的信格")
					check(state.data.journey.p2.mail.is_empty(),"mismatched_name_does_not_deliver")
					await click_text("Lingling 的信格")
					await wait_step(step.id)
					check(state.data.journey.p2.mail==["textbook_lingling"],"click_select_and_mailbox_delivery")
					await drag_text("邀请给 Tim","Tim 的信格")
					await wait_step(step.id)
					check(state.data.journey.p2.mail.size()==2,"native_engine_drag_delivery")
					await shot(step.id+"-delivered")
					await click_text("两封都送好了")
				"seats":
					while int(state.data.journey.p2.seats)<int(step.seat_count)+1:
						await click_text("再摆一张")
						await wait_step(step.id)
					await click_text("摆好了，数一数")
					check(not state.data.journey.p2.chapters[str(number)].steps.has(step.id),"extra_seat_does_not_complete/"+step.id)
					await click_text("收起一张")
					await wait_step(step.id)
					await shot(step.id+"-correct-count")
					await click_text("摆好了，数一数")
				"letters": await click_text("收进旅行册")
				"complete": await click_text("收下回信，完成这一章" if number==2 else "收好座位卡，去布置欢迎桌")
				_: await click_text("一起继续")
			check(state.data.journey.p2.chapters[str(number)].steps.has(step.id),"step_saved/"+step.id)
			if not state.data.journey.p2.chapters[str(number)].steps.has(step.id): finish(); return
			state.load_state()
			check(state.data.journey.p2.chapters[str(number)].steps.has(step.id),"step_disk_restore/"+step.id)
			if number==2 and step.kind=="complete":
				check(game.ui.current_panel=="friend_corner","u2_ends_at_optional_keepsake_choice")
				await click_text("接着准备欢迎桌")
	check(state.journey_snapshot().phase=="p2_complete","continuous_u2_u3_complete")
	check(state.data.journey.p2.receipts.size()==2 and state.data.journey.reward_receipts.size()==2,"four_distinct_receipts")
	check(state.data.coins==30 and state.data.learning.is_empty(),"no_currency_or_old_mastery_mutation")
	await game.journey.p2.show_transfer()
	await click_text("完整示范")
	await click_text("看过示范，继续")
	await click_text("继续")
	check(state.data.journey.u1.steps.has("U1-10") and state.data.journey.u1.step_details["U1-10"].actor=="npc_rabbit_gardener","cross_context_garden_transfer")
	if not state.data.journey.u1.steps.has("U1-10"): finish(); return
	check(not state.data.journey.u1.step_details["U1-10"].delayed_recall_claimed,"same_day_not_delayed_evidence")
	await recall_checks()
	if DisplayServer.get_name()!="headless":
		root.grab_focus()
		await frames(5)
		var receipts: Dictionary=state.data.journey.reward_receipts.duplicate(true)
		await game.journey._take_photo("blue")
		check(state.data.journey.p2.photo_revision==1,"real_photo_retake_revision")
		if state.data.journey.p2.photo_revision!=1: finish(); return
		check(receipts==state.data.journey.reward_receipts,"retake_does_not_repeat_receipts")
		check(FileAccess.file_exists(state.data.journey.u1.photo.details.image_path),"real_photo_png_exists")
		await shot("retaken-photo")
	game.journey.p2.show_keepsakes()
	await shot("keepsakes")
	await trip_checks()
	finish()
func trip_checks() -> void:
	game.journey.p2.show_trip()
	for area: Dictionary in game.journey.prologue.districts:
		await click_text(str(area.name))
		await shot("district-"+str(area.id))
	var area: Dictionary=game.journey.prologue.districts[0]
	await click_text(str(area.name))
	for letter: String in ["A","B","C","D"]:
		var record: Dictionary=game.journey._letter(letter)
		await click_text(letter+letter.to_lower()+" · "+str(record.anchor.chinese_image_name)+"\n已收下发现页")
	check(state.data.journey.p2.trip==["A","B","C"],"trip_ui_caps_at_three")
	state.load_state()
	check(state.data.journey.p2.trip==["A","B","C"],"trip_ui_disk_recovery")
	await shot("trip-three-stops")
func recall_checks() -> void:
	await game.journey.p2.show_recall_menu("C")
	await click_text("大小写配对")
	await click_text("这次先跳过")
	check(state.data.journey.p2.trials["recall/C/case_pair"].result=="skipped","optional_recall_skip")
	await click_text("看形象想字母")
	await click_text("完整示范")
	await click_text("看过示范，继续")
	await click_text("再试一轮")
	await click_text("C")
	check(state.data.journey.p2.trials["recall/C/landmark"].result=="supported_correct","retrial_after_demo_is_not_independent")
	await click_text("继续")
	await click_text("试着说字母名")
	await click_text("我试着说了")
	check(state.data.journey.p2.trials["recall/C/letter_name"].result=="self_report_unassessed","speaking_self_report_not_scored")
	await shot("recall-self-report")
func wait_step(id: String) -> void:
	for frame: int in 1200:
		await frames(1)
		if not game.loading_room and game.ui.current_panel=="journey_p2" and game.journey.p2.presented_step==id:
			await frames(3)
			return
	check(false,"chapter_ui_timeout/"+id)
func frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func find_text(value: String) -> Button:
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if button.text==value and button.is_visible_in_tree(): return button
	return null
func click_text(value: String) -> void:
	await frames(2)
	var button:=find_text(value)
	check(button!=null,"button_exists/"+value)
	if button==null: return
	check(not button.disabled,"button_enabled/"+value)
	var point:=button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"button_reachable/"+value)
	await move(point)
	await mouse(point,true)
	await mouse(point,false)
	await frames(3)
func move(point: Vector2, pressed: bool=false) -> void:
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
func drag_text(from_text: String,to_text: String) -> void:
	var source:=find_text(from_text)
	var target:=find_text(to_text)
	check(source!=null and target!=null,"drag_targets_exist")
	if source==null or target==null: return
	var origin:=source.get_global_rect().get_center()
	var destination:=target.get_global_rect().get_center()
	await move(origin)
	await mouse(origin,true)
	for index: int in range(1,11): await move(origin.lerp(destination,float(index)/10),true)
	await mouse(destination,false)
	await frames(4)
func shot(id: String) -> void:
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if button.is_visible_in_tree():
			var rect:=button.get_global_rect()
			var visible: bool=root.get_visible_rect().encloses(rect)
			check(visible,"layout/"+id+"/"+button.text)
			layout.append({"screen":id,"text":button.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"visible":visible})
	if capture.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture)
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture.path_join(id+".png"))
func hash_file(path: String) -> String: return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
func check(passed: bool,id: String) -> void:
	checks.append({"id":id,"passed":passed})
	if not passed: failures.append(id); print("FAIL ",id)
func finish() -> void:
	for path: String in baseline: check(hash_file(path)==baseline[path],"protected/"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var output:=FileAccess.open(report_dir.path_join("chapters-%s-%s.json"%[size_id,"headless" if DisplayServer.get_name()=="headless" else "native"]),FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"result":"PASS" if failures.is_empty() else "FAIL","size":size_id,"renderer":DisplayServer.get_name(),"actors":actors,"layout":layout,"scope":"U1-complete fixture; real U2/U3 scene loading, actor presence, UI input, mail drag, seat count and real disk recovery. Separate journey-game covers new-game onboarding, 26 encounters and U1."},"  "))
	output.close()
	print("P2_CHAPTERS checks=",checks.size()," failures=",failures.size())
	if is_instance_valid(state):
		var path: String=state.data.journey.u1.photo.details.get("image_path","")
		if path.begins_with("user://welcome-photo-"+str(OS.get_process_id())+"-") and FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		for suffix: String in ["",".bak",".tmp"]:
			path=state.save_path+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)
