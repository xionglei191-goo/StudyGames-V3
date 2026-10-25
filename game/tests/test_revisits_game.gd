extends SceneTree
## Native click/keyboard acceptance with explicit past-time fixtures and isolated saves.
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
const Review = preload("res://scripts/review_progress.gd")
var game: Node3D
var state: Node
var checks: Array = []
var failures: Array = []
var screenshots: Array = []
var baseline: Dictionary = {}
var output_dir := ""
var size_id := "1440x900"
var isolated_save := ""
var finished := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--revisit-size="): size_id = arg.trim_prefix("--revisit-size=")
	output_dir = ProjectSettings.globalize_path("res://../docs/verification/revisits/"+size_id)
	DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(180.0).timeout.connect(func(): check(false,"native_timeout"); finish())
	var dimensions := size_id.split("x")
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": root.grab_focus()
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: baseline[path] = file_hash(path)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for tick: int in 1200:
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready,"scene_ready")
	if not game.scene_ready: finish(); return
	state = root.get_node("State")
	isolated_save = state.save_path
	check(isolated_save=="user://validation-%d.json" % OS.get_process_id(),"isolated_save")
	if isolated_save!="user://validation-%d.json" % OS.get_process_id(): finish(); return
	state.data = state._default_state()
	state.data.preferences.reduced_motion = true
	state.data.preferences.fixed_day = true
	state.data.preferences.voice = false
	game.ui.reduced_motion = true
	game.muted = true
	check(state.save_state(),"fresh_fixture_saved")
	game.show_settings()
	await shot("00-settings")
	await click_action("journey:parent")
	check(game.ui.current_panel=="parent_observations","settings_parent_entry")
	var before: Dictionary = state.snapshot()
	await shot("01-parent-empty")
	check(before==state.data,"empty_parent_page_does_not_change_save")
	await click_name("ParentBack")
	seed_fixture()
	game.journey.show_hub()
	await click_action("journey:revisits")
	check(game.ui.current_panel=="review_invites","travel_book_invitation_entry")
	check(state.data.reviews.batch.ids.size()==2,"native_two_invites")
	var ids: Array = state.data.reviews.batch.ids.duplicate()
	if ids.size()!=2: finish(); return
	await shot("02-invitations")
	var letter_id: String = ids[0]
	var unit_id: String = ids[1]
	check(state.data.reviews.opportunities[letter_id].target=="letter/A/case","fixture_letter_target")
	check(state.data.reviews.opportunities[unit_id].target=="unit/hello","fixture_unit_target")
	await click_name("RevisitGo_"+letter_id)
	await panel("review_task")
	check(game.room=="landmark_F" and game.living.get_actor("npc_rabbit_gardener")!=null,"invitation_reaches_real_room_and_actor")
	await shot("03-letter-choice")
	await click_name("RevisitHint")
	check(state.data.reviews.opportunities[letter_id].help==1,"native_hint_recorded_before_display")
	await shot("04-letter-hint")
	await key(KEY_ESCAPE)
	check(not game.ui.modal.visible,"escape_can_leave_without_answering")
	state.load_state()
	game.journey.show_hub()
	await click_action("journey:revisits")
	check(state.data.reviews.batch.ids==ids,"restart_reuses_same_batch")
	await click_name("RevisitGo_"+letter_id)
	await panel("review_task")
	check(state.data.reviews.opportunities[letter_id].help==1,"native_hint_survives_restart")
	var saved_path: String = state.save_path
	var blocker_path := "user://revisit-blocker-%d" % OS.get_process_id()
	var blocker := FileAccess.open(blocker_path,FileAccess.WRITE)
	blocker.store_string("test blocker")
	blocker.close()
	state.save_path = blocker_path+"/save.json"
	before = state.snapshot()
	await click_name("RevisitDemo")
	check(state.data==before and state.data.reviews.opportunities[letter_id].help==1,"write_failure_does_not_reveal_demo_or_change_record")
	state.save_path = saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	await click_name("RevisitAnswer_A")
	check(state.data.reviews.opportunities[letter_id].result=="supported_correct","native_hint_answer_supported")
	await create_timer(4.0).timeout # Let the deliberately induced write-failure notice expire.
	await shot("05-letter-keepsake")
	await click_name("RevisitMore")
	await click_name("RevisitGo_"+unit_id)
	await panel("review_task")
	await shot("06-unit-situation")
	await click_name("RevisitAnswer_thanks")
	check(not state.data.reviews.opportunities[unit_id].answers[0].correct,"native_first_error_preserved")
	await shot("07-unit-after-error")
	await click_name("RevisitPause")
	check(state.data.reviews.opportunities[unit_id].paused,"pause_saved")
	state.load_state()
	await click_action("journey:revisits")
	await click_name("RevisitGo_"+unit_id)
	await panel("review_task")
	await click_name("RevisitDemo")
	check(state.data.reviews.opportunities[unit_id].help==5,"native_full_demo_recorded")
	await shot("08-unit-demonstration")
	await click_name("RevisitDemoDone")
	check(state.data.reviews.opportunities[unit_id].result=="demonstrated" and state.data.reviews.opportunities[unit_id].answers.size()==1 and not state.data.reviews.opportunities[unit_id].answers[0].correct,"demo_does_not_create_correct_answer")
	await click_name("RevisitMore")
	await click_name("RevisitBook")
	await click_action("journey:parent")
	before = state.snapshot()
	await shot("09-parent-observations")
	await click_name("ParentFilter_units")
	await shot("10-parent-units")
	await click_name("ParentNext")
	check(game.journey.reviews.parent_page==1,"native_parent_pagination")
	await shot("11-parent-next-page")
	await click_name("ParentFilter_letters")
	await shot("12-parent-letter-experiences")
	await click_name("ParentFilter_stories")
	check(game.ui.current_panel=="parent_observations","empty_story_filter_reachable")
	check(state.data==before,"parent_filters_and_paging_do_not_write_observations")
	await click_name("ParentBack")
	check(int(state.data.coins)==30 and state.data.reviews.opportunities.size()==2,"review_never_awards_currency_or_duplicate_opportunities")
	await only_due("letter/A/image")
	check(game.ui.panel_box.find_child("RevisitImage",true,false)!=null,"image_dimension_has_actual_illustration")
	await shot("13-image-association")
	await click_name("RevisitAnswer_A")
	await only_due("letter/A/case")
	check(game.room=="home" and game.living.get_actor("npc_bear_uncle")!=null,"second_round_reaches_home_and_bear")
	await shot("14-home-context")
	await click_name("RevisitSkip")
	await only_due("letter/A/case")
	check(game.room=="school" and game.living.get_actor("textbook_anne")!=null,"third_round_reaches_school_and_anne")
	await shot("15-school-context")
	await click_name("RevisitSkip")
	check(state.save_state(),"final_native_save_valid")
	finish()

func only_due(target_id: String) -> void:
	# Explicit schedule fixture, not an assertion that real days elapsed in this run.
	var now := Time.get_unix_time_from_system()
	for id: String in state.data.reviews.targets: state.data.reviews.targets[id].anchor_at = now
	state.data.reviews.targets[target_id].anchor_at = now-Review.DAY*8
	state.data.reviews.batch = {"at":0.0,"ids":[]}
	check(state.save_state(),"context_fixture/"+target_id)
	game.journey.reviews.show_invites()
	await frames(3)
	check(state.data.reviews.batch.ids.size()==1,"one_target_fixture/"+target_id)
	if state.data.reviews.batch.ids.is_empty(): return
	await click_name("RevisitGo_"+str(state.data.reviews.batch.ids[0]))
	await panel("review_task")

func seed_fixture() -> void:
	var before: Dictionary = state.snapshot()
	var past := Time.get_unix_time_from_system()-Review.DAY*2
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(state.data.journey,step)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(state.data.journey,letter,"landmark_"+letter,fact,"demonstration_viewed")
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(state.data.journey,step,{},past)
	for number: int in [2,3]:
		for step: Dictionary in Chapter.content().chapters[str(number)].steps:
			if step.kind=="question":
				fixture_event({"kind":"trial_begin","context":step.id,"room":step.room},past)
				var trial_id: String = state.data.journey.p2.trials[step.id].id
				fixture_event({"kind":"trial_help","context":step.id,"trial_id":trial_id,"level":3,"room":step.room},past)
				fixture_event({"kind":"trial_answer","context":step.id,"trial_id":trial_id,"answer":"__demonstrated__","room":step.room},past)
			elif step.kind=="mail":
				for recipient: String in ["textbook_lingling","textbook_tim"]: fixture_event({"kind":"mail","recipient":recipient,"mailbox":recipient,"room":step.room},past)
			elif step.kind=="seats": fixture_event({"kind":"seats","count":step.seat_count,"room":step.room},past)
			fixture_event({"kind":"chapter_step","chapter":number,"step":step.id,"room":step.room},past)
	Review.sync(state.data,before,past)
	for id: String in state.data.reviews.targets:
		if id not in ["letter/A/case","unit/hello"]: state.data.reviews.targets[id].anchor_at = Time.get_unix_time_from_system()
	state.data.reviews.clock.last_wall = Time.get_unix_time_from_system()
	check(state.save_state(),"past_contact_fixture_saved")

func fixture_event(event: Dictionary, at: float) -> void:
	check(Chapter.apply(state.data.journey,event,at).ok,"fixture/"+str(event.kind)+"/"+str(event.get("step",event.get("context",""))))

func find_name(value: String) -> Button:
	return game.ui.panel_box.find_child(value,true,false) as Button

func click_name(value: String) -> void:
	await click_button(find_name(value),value)

func click_action(value: String) -> void:
	var found: Button
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if str(button.get_meta("action_id",""))==value: found=button; break
	await click_button(found,value)

func click_button(button: Button, label: String) -> void:
	check(button!=null,"button/"+label)
	if button==null: return
	await frames(3)
	var ancestor: Node = button.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await frames(3)
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	check(not button.disabled,"enabled/"+label)
	var point := button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"visible/"+label)
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	await frames(1)
	for pressed: bool in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.position=point
		mouse.global_position=point
		mouse.button_index=MOUSE_BUTTON_LEFT
		mouse.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mouse.pressed=pressed
		root.push_input(mouse,true)
		await frames(1)
	await frames(4)

func key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		root.push_input(event,true)
		await frames(2)

func panel(id: String) -> void:
	for tick: int in 600:
		await frames(1)
		if game.ui.current_panel==id: return
	check(false,"panel_timeout/"+id)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func shot(id: String) -> void:
	await frames(4)
	check(root.get_visible_rect().encloses(game.ui.panel.get_global_rect()),"panel_inside/"+id)
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		var in_scroll := false
		var ancestor: Node = button.get_parent()
		while ancestor:
			if ancestor is ScrollContainer: in_scroll=true
			ancestor=ancestor.get_parent()
		if not in_scroll: check(root.get_visible_rect().encloses(button.get_global_rect()),"layout/"+id+"/"+str(button.name))
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join(id+".png"))
		screenshots.append(id+".png")

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func check(condition: bool, id: String) -> void:
	checks.append({"id":id,"passed":condition})
	if not condition: failures.append(id); print("FAIL ",id)

func finish() -> void:
	if finished: return
	finished=true
	for path: String in baseline: check(file_hash(path)==baseline[path],"production_preserved/"+path)
	var report := {"result":"PASS" if failures.is_empty() else "FAIL","size":size_id,"renderer":DisplayServer.get_name(),"checks":checks,"failures":failures,"screenshots":screenshots,"scope":"Native pointer/keyboard, real scene transitions, persisted hints, write-failure rollback, first-error preservation, demo classification, parent pagination and isolated save checks. Seeded completed U1-U3 and two-day source times; no child playtest or actual multi-day study."}
	var sources: Dictionary = {}
	for path: String in ["scripts/review_progress.gd","scripts/review_controller.gd","scripts/parent_observations.gd","scripts/game_state.gd","scripts/journey_controller.gd","scripts/p2_journey_controller.gd","scripts/main.gd","scripts/ui.gd","ui/travel_book_view.gd","data/learning/revisits.json","project.godot","tests/test_revisits_game.gd"]: sources[path]=file_hash("res://"+path)
	report.source_sha256=sources
	var file := FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  ")); file.close()
	if isolated_save=="user://validation-%d.json"%OS.get_process_id():
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(isolated_save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_save+suffix))
	print("REVISIT_NATIVE ",size_id," checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
