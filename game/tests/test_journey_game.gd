extends SceneTree
## Integration through real room loads and engine-dispatched UI input.
const Content = preload("res://ui/memory_story_content.gd")
var game: Node3D
var state: Node
var checks: Array = []
var failures: Array[String] = []
var production_hash := ""
var production_backup_hash := ""
var capture_directory := ""
var orchard_evidence: Dictionary = {}
var journey_evidence: Dictionary = {}
var guided_trace: Array = []
var requested_size := "1440x900"
const PRODUCTION := "user://island-save-v1.json"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--journey-capture="): capture_directory = argument.trim_prefix("--journey-capture=")
		if argument.begins_with("--journey-size="): requested_size = argument.trim_prefix("--journey-size=")
	var dimensions := requested_size.split("x")
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": root.grab_focus()
	production_hash = FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing"
	production_backup_hash = FileAccess.get_sha256(PRODUCTION+".bak") if FileAccess.file_exists(PRODUCTION+".bak") else "missing"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame: int in 1200:
		await process_frame
		if game.scene_ready: break
	_check(game.scene_ready,"scene_ready")
	if not game.scene_ready:
		_finish()
		return
	state = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-"),"isolated_save")
	state.data = state._default_state()
	game.muted = true
	game.ui.reduced_motion = false
	state.set_preference("reduced_motion",false)
	await game.change_room("home")
	game.journey.show_home()
	await _frames(3)
	await _capture("01-home-invitation")
	_check(game.living.get_actor("npc_bear_uncle")!=null,"home_has_guide_with_stable_identity")
	await _click_action("journey:guide")
	for frame: int in 1500:
		await _frames(1)
		if state.journey_snapshot().home_steps.has("H01"): break
	_check(state.journey_snapshot().home_steps.has("H01"),"walking_to_bear_opens_home_guide")
	if not state.journey_snapshot().home_steps.has("H01"):
		_finish()
		return
	await _click_text("预览花朵")
	_check(state.data.journey.p2.home_choice=="","preview_does_not_commit_home_choice")
	await _click_text("取消预览")
	_check(state.data.journey.home_steps==["H01"],"cancel_preview_does_not_complete_home_step")
	await _click_text("预览星星")
	await _capture("01b-home-preview")
	await _click_text("就摆这个")
	_check(state.data.journey.p2.home_choice=="star","home_decoration_confirmed")
	await _click_action("journey:take_book")
	_check(game.ui.current_panel=="map","receiving_book_opens_real_home_map")
	game._close()
	await game.journey.continue_journey()
	await _frames(3)
	await _click_action("journey:start")
	for frame: int in 1800:
		await _frames(1)
		if game.room=="landmark_A" and not game.pending_interaction.is_empty():
			var target: Vector3 = game.pending_interaction.position
			var distance := Vector2(game.player.position.x,game.player.position.z).distance_to(Vector2(target.x,target.z))
			if distance<3.0:
				var contacts: Array = []
				for index: int in game.player.get_slide_collision_count():
					var contact = game.player.get_slide_collision(index)
					var collider = contact.get_collider()
					contacts.append({"name":str(collider.name) if is_instance_valid(collider) else "freed","normal":contact.get_normal(),"position":contact.get_position()})
				guided_trace.append({"frame":frame,"position":game.player.position,"distance":distance,"path_size":game.player.path.size(),"pending":game.pending_interaction,"pending_auto":game.pending_auto,"contacts":contacts})
				if guided_trace.size()>30: guided_trace.pop_front()
		if is_instance_valid(game.orchard_activity): break
	_check(game.room=="landmark_A" and is_instance_valid(game.orchard_activity),"guided_travel_opens_real_orchard_activity")
	if not is_instance_valid(game.orchard_activity):
		journey_evidence={"room":game.room,"panel":game.ui.current_panel,"loading_room":game.loading_room,
			"player_position":game.player.position,"player_path":game.player.path,"player_locked":game.player.locked,
			"nearest":game.nearest,"pending":game.pending_interaction,"toast":game.ui.toast_label.text,"guided_trace":guided_trace,"journey":state.journey_snapshot()}
		_finish()
		return
	var orchard: Node3D = game.orchard_activity
	await _frames(4)
	await _capture("02a-orchard-ready")
	await _click_button(orchard.demo_button)
	_check(orchard.demonstration and orchard.mode=="demonstration_viewed","real_orchard_button_starts_supported_demonstration")
	for frame: int in 3600:
		await _frames(1)
		if not is_instance_valid(orchard): break
		if orchard.phase=="deposited" and is_instance_valid(orchard.discovery_panel): break
	if is_instance_valid(orchard): orchard_evidence=orchard.get_status().duplicate(true)
	_check(is_instance_valid(orchard) and orchard.phase=="deposited","demonstration_physically_deposits_apple")
	_check(is_instance_valid(orchard) and is_instance_valid(orchard.discovery_panel),"deposited_apple_opens_discovery_card")
	if not is_instance_valid(orchard) or orchard.phase!="deposited" or not is_instance_valid(orchard.discovery_panel):
		_finish()
		return
	_check(state.journey_orchard_snapshot().stage=="deposited","orchard_deposit_is_durably_recorded")
	await _capture("02b-orchard-discovery")
	await _click_text_in(orchard.panel_root,"收下这次发现")
	await _frames(4)
	await _click_text("看看建筑里的 A")
	await _click_text("收下这张发现页")
	_check(state.journey_snapshot().letters.A.experienced,"demonstration_can_complete_supported_encounter")
	_check(state.journey_snapshot().letters.A.completion_mode=="demonstration_viewed","demonstration_mode_persisted")
	_check(not is_instance_valid(game.orchard_activity),"accepting_discovery_leaves_orchard_activity")
	for letter: String in "BCDEFGHIJKLMNOPQRSTUVWXYZ":
		game._close()
		await game.change_room("landmark_"+letter)
		game.journey.show_letter(letter)
		await _frames(3)
		var component: Node = game.ui.panel_box.get_child(game.ui.panel_box.get_child_count()-1)
		for action_index: int in 4:
			if component.action_done: break
			var buttons: Array = component.actions.find_children("*","Button",true,false)
			await _click_button(buttons[1] if letter=="U" else buttons[0])
			for wait_frame: int in 120:
				await _frames(1)
				if not component.busy: break
		await _frames(2)
		await _click_text("看看建筑里的 "+letter)
		_check(state.journey_snapshot().letters[letter].experienced,"actual_room_card_and_glyph_encounter/"+letter)
		await _click_text("收下这张发现页")
	_check(state.journey_snapshot().prologue_completed,"all_26_encounters_unlock_mainline")
	_check(state.data.learning.is_empty(),"letter_encounters_do_not_grant_old_course_mastery")
	state.load_state()
	_check(state.journey_snapshot().experienced_count==26,"letter_progress_survives_reload")
	game.journey.show_letters()
	await _frames(3)
	await _capture("03-alphabet-book")
	await game.journey.continue_journey()
	await _frames(3)
	await _click_action("journey:u1:01")
	await _click_action("journey:u1:school")
	for frame: int in 600:
		await _frames(1)
		if not game.loading_room and game.ui.current_panel=="journey_u1": break
	_check(game.room=="school","u1_arrives_in_school")
	await _capture("04-school-greeting")
	await _click_action("journey:u1:name")
	await _click_action("journey:u1:name:星星")
	await _click_action("journey:u1:decorate:花朵")
	var corner: Node = game.world.find_child("JourneyKeepsakes",true,false)
	_check(corner!=null and corner.get_child_count()>0,"welcome_corner_has_visible_saved_result")
	await _click_action("journey:u1:05")
	for frame: int in 2000:
		await _frames(1)
		if state.journey_snapshot().u1.steps.has("U1-05"): break
	_check(state.journey_snapshot().u1.step_details.get("U1-05",{}).get("contact_seen",false),"u1_book_contact_precedes_commit")
	await _click_action("journey:u1:hello")
	await _frames(6)
	_check(game.ui.current_panel=="word_story","optional_story_opens_inside_u1")
	var invocation: String = game.journey.memory_invocation
	var story: Node = game.journey.current_memory
	_check(is_instance_valid(story),"story_component_is_live")
	await _capture("05-hello-story")
	if not is_instance_valid(story):
		_finish()
		return
	_check(is_instance_valid(story._story_player),"u1_story_uses_live_animation_stage")
	await _click_text_in(story,"播放故事")
	await _frames(30)
	await _click_text_in(story,"暂停")
	var animated_session: Dictionary = state.journey_snapshot().memory.sessions[invocation]
	_check(not animated_session.animation_state.is_empty() and animated_session.animation_state.phase>0 and animated_session.animation_state.playback_status=="paused","actual_animation_phase_is_saved_in_current_session")
	var animation_cues: Array = animated_session.cue_events.filter(func(cue: Dictionary): return str(cue.get("display_event",""))=="story_animation_step")
	_check(not animation_cues.is_empty() and int(animation_cues[-1].animated_letter_position)==1,"rendered_animation_cue_reaches_authoritative_session")
	story.set_support(3)
	await _frames(3)
	_check(state.journey_snapshot().memory.sessions[invocation].max_help_level==5,"actual_demonstration_and_later_gap_help_are_saved")
	game._request_close()
	_check(state.journey_snapshot().memory.sessions[invocation].status=="paused","escape_pauses_same_memory_session")
	game.journey.open_hello_story()
	await _frames(5)
	_check(game.journey.memory_invocation==invocation,"reopen_resumes_same_invocation")
	story = game.journey.current_memory
	_check(story.support_level==3,"help_level_restored")
	var original_save_path: String = state.save_path
	var blocker := "user://journey-save-blocker-%d" % OS.get_process_id()
	var blocker_file := FileAccess.open(blocker,FileAccess.WRITE)
	blocker_file.store_string("isolated save failure fixture")
	blocker_file.close()
	state.save_path = blocker+"/save.json"
	story.set_support(2)
	game._request_close()
	_check(game.ui.current_panel=="word_story" and is_instance_valid(game.journey.current_memory),"failed_save_keeps_learning_page_open")
	_check(game.journey.memory_sink.pending_count()>0,"failed_observations_stay_in_ordered_queue")
	state.save_path = original_save_path
	game._request_close()
	_check(not game.ui.modal.visible and state.journey_snapshot().memory.sessions[invocation].support_level==2,"restored_storage_flushes_before_closing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	game.journey.open_hello_story()
	await _frames(5)
	story = game.journey.current_memory
	story.start_practice()
	story.submit_response("hello")
	await _frames(3)
	var session: Dictionary = state.journey_snapshot().memory.sessions[invocation]
	_check(session.responses.size()==1 and session.responses[0].result=="supported_correct","post_demo_correct_is_not_independent_success")
	story.request_close("completed")
	await _frames(3)
	_check(state.journey_snapshot().u1.steps.has("U1-06"),"optional_story_returns_to_life_event")
	await _click_action("journey:u1:07:demo")
	await _click_action("journey:u1:photo:yellow")
	for frame: int in 180:
		await _frames(1)
		if state.journey_snapshot().u1.photo.created: break
	_check(state.journey_snapshot().u1.photo.created and not state.journey_snapshot().u1.completed,"photo_does_not_complete_chapter")
	await _click_action("journey:u1:return")
	for frame: int in 600:
		await _frames(1)
		if game.room=="home" and not game.loading_room and game.ui.current_panel=="journey_u1": break
	await _frames(4)
	await _click_action("journey:u1:09")
	var result: Dictionary = state.journey_snapshot()
	_check(result.u1.completed and result.reward_receipts.size()==2,"home_display_completes_chapter_with_separate_receipt")
	_check(state.data.coins==30,"u1_has_no_unplanned_coin_reward")
	state.load_state()
	_check(state.journey_snapshot().u1.completed,"chapter_completion_survives_reload")
	game.journey.show_photo()
	await _frames(3)
	await _capture("06-welcome-photo")
	game.journey.show_library()
	await _frames(3)
	_check(game.journey.library_matches.size()>100,"full_selected_book_word_list_visible")
	await _capture("07-word-library")
	for book: Dictionary in Content.load_catalog().books:
		_check(not Content.list_entries(str(book.book_id)).is_empty(),"runtime_book_available/"+str(book.book_id))
	var after := FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing"
	_check(after==production_hash,"production_save_unchanged")
	game._close()
	_finish()

func _click_action(id: String) -> void:
	await _frames(2)
	for button: Node in game.ui.panel_box.find_children("*","Button",true,false):
		if str(button.get_meta("action_id",""))==id:
			await _click_button(button)
			return
	_check(false,"missing_action/"+id)

func _click_text(text: String) -> void:
	await _click_text_in(game.ui.panel_box,text)

func _click_text_in(container: Node,text: String) -> void:
	await _frames(2)
	for button: Node in container.find_children("*","Button",true,false):
		if button.text==text:
			await _click_button(button)
			return
	_check(false,"missing_button/"+text)

func _click_button(button: Button) -> void:
	var ancestor := button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await _frames(3)
	_check(button.is_visible_in_tree() and not button.disabled,"clickable/"+button.text)
	var location := button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = location
		event.global_position = location
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await _frames(1)
	await _frames(2)

func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame

func _capture(name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join(name+".png"))

func _check(value: bool, name: String) -> void:
	checks.append({"id":name,"passed":value})
	if not value:
		failures.append(name)
		print("FAIL: ",name)

func _finish() -> void:
	var protected_hash := FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing"
	var protected_backup := FileAccess.get_sha256(PRODUCTION+".bak") if FileAccess.file_exists(PRODUCTION+".bak") else "missing"
	_check(protected_hash==production_hash and protected_backup==production_backup_hash,"production_save_and_backup_unchanged_on_exit")
	var directory := ProjectSettings.globalize_path("res://../docs/verification/p2")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("journey-game-"+requested_size+"-"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"engine_input_dispatch":true,"reduced_motion":false,"orchard_evidence":orchard_evidence,"journey_evidence":journey_evidence,"protected_production_save":PRODUCTION,"production_save_and_backup_unchanged":protected_hash==production_hash and protected_backup==production_backup_hash},"  "))
	print("JOURNEY_GAME_RESULT checks=%d failures=%d" % [checks.size(),failures.size()])
	if is_instance_valid(state):
		var photo_path := str(state.journey_snapshot().u1.photo.get("details",{}).get("image_path",""))
		if photo_path.begins_with("user://welcome-photo-"+str(OS.get_process_id())+"-") and FileAccess.file_exists(photo_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
		for suffix: String in ["",".bak",".tmp"]:
			var path: String = state.save_path+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)
