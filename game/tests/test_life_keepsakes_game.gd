extends SceneTree
## Native input acceptance from explicitly seeded learning fixtures; never the player's save.
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
const Discovery = preload("res://scripts/discovery_progress.gd")
const Party = preload("res://scripts/party_progress.gd")
var game: Node3D
var state: Node
var checks: Array = []
var failures: Array = []
var layouts: Array = []
var baseline: Dictionary = {}
var output_dir := ""
var size_id := "1440x900"
var last_mouse := Vector2.ZERO
var isolated_save := ""
var photo_path := ""
var finished := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--life-size="): size_id = argument.trim_prefix("--life-size=")
	output_dir = ProjectSettings.globalize_path("res://../docs/verification/life-keepsakes/"+size_id)
	DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(300.0).timeout.connect(func(): check(false,"native_timeout"); finish())
	var dimensions := size_id.split("x")
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name() != "headless": root.grab_focus()
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: baseline[path] = file_hash(path)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for index: int in 1200:
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready,"native_scene_ready")
	if not game.scene_ready: finish(); return
	state = root.get_node("State")
	isolated_save = state.save_path
	check(isolated_save == "user://validation-%d.json" % OS.get_process_id(),"isolated_save")
	state.data = state._default_state()
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(state.data.journey,step)
	experience("A")
	check(state.save_state(),"one_real_experience_fixture_saved")
	game.ui.reduced_motion = true
	game.muted = true
	await game.change_room("landmark_A")
	game.journey.show_letter_result("A")
	await frames(4)
	check(find_action("journey:discovery-card:A") != null,"first_station_offers_take_home")
	check(find_action("journey:discovery-page:morning_village") == null,"one_station_does_not_complete_district")
	await shot("01-first-discovery-result")
	await click_action("journey:discovery-card:A")
	await click_name("DiscoveryChoice_theme_sea")
	await click_name("DiscoveryChoice_layout_postcard")
	await click_name("DiscoveryDisplayChoice")
	check(discovery().cards.is_empty() and discovery().display.card == "","draft_is_not_confirmed_work")
	await shot("02-first-card-draft")
	await click_name("DiscoveryPause")
	state.load_state()
	await click_name("DiscoveryItem_card_A")
	check(discovery().drafts["card/A"].design.theme == "sea","card_draft_recovers_after_reload")
	await click_name("DiscoveryConfirm")
	check(discovery().cards.size() == 1 and discovery().display.card == "A","first_card_confirmed_and_selected")
	await shot("03-first-card-saved")
	await click_name("DiscoveryEdit")
	await click_name("DiscoveryChoice_theme_meadow")
	await click_name("DiscoveryCancel")
	check(discovery().cards.A.design.theme == "sea" and discovery().drafts.is_empty(),"card_cancel_retains_confirmed_design")
	for letter: String in "BCDEF": experience(letter)
	check(state.save_state(),"district_fixture_saved")
	game.journey.show_letter_result("F")
	await frames(3)
	check(find_action("journey:discovery-page:morning_village") != null,"district_end_offers_travel_page")
	await click_action("journey:discovery-page:morning_village")
	await click_name("DiscoveryChoice_image_letter_F")
	await click_name("DiscoveryChoice_theme_meadow")
	await click_name("DiscoveryDisplayChoice")
	await shot("04-district-page-draft")
	await click_name("DiscoveryConfirm")
	check(discovery().pages.morning_village.design.image_letter == "F","district_featured_image_is_selected_letter")
	await click_name("DiscoveryEdit")
	await click_name("DiscoveryChoice_layout_portrait")
	await shot("05-district-portrait-layout")
	await click_name("DiscoveryCancel")
	await click_name("DiscoveryGoHome")
	await frames(8)
	var home_display: Node = game.journey.story_room_root.get_node_or_null("DiscoveryKeepsakes")
	check(home_display != null and home_display.get_meta("display") == discovery().display,"world_uses_confirmed_discovery_designs")
	await shot("06-home-discoveries")
	await walk_to("journey_discoveries")
	check(game.ui.current_panel == "discovery","world_discovery_interaction_reachable")
	await click_name("DiscoveryItem_card_A")
	await click_name("DiscoveryEdit")
	await click_name("DiscoveryChoice_theme_meadow")
	var before_failure: Dictionary = state.snapshot()
	var blocker := "user://validation-life-blocker-%d" % OS.get_process_id()
	var blocker_file := FileAccess.open(blocker,FileAccess.WRITE)
	blocker_file.store_string("not a directory")
	blocker_file.close()
	state.save_path = blocker.path_join("blocked.json")
	await click_name("DiscoveryConfirm")
	check(state.data == before_failure,"discovery_save_failure_rolls_back_and_preserves_draft")
	state.save_path = isolated_save
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	await click_name("DiscoveryConfirm")
	check(discovery().cards.A.design.theme == "meadow","discovery_confirm_retry_succeeds")
	var once: Dictionary = discovery().duplicate(true)
	await click_name("DiscoveryEdit")
	await click_name("DiscoveryConfirm")
	check(discovery() == once,"reconfirm_same_design_does_not_duplicate_reward")
	await prepare_completed_chapters()
	if not failures.is_empty(): finish(); return
	await party_flow()
	if not failures.is_empty(): finish(); return
	await friends_flow()
	check(int(state.data.coins) == 30 and state.data.learning.is_empty(),"new_keepsakes_do_not_mutate_wallet_or_old_learning")
	check(state.data.journey.reward_receipts.size() == 2 and state.data.journey.p2.receipts.size() == 2,"original_chapter_and_photo_receipts_preserved")
	check(Journey.normalize(state.data.journey).ok,"combined_journey_normalizes")
	finish()

func experience(letter: String) -> void:
	for fact: String in Journey.LETTER_FACTS:
		Journey.record_letter(state.data.journey,letter,"landmark_"+letter,fact,"demonstration_viewed")

func prepare_completed_chapters() -> void:
	for letter: String in Journey.LETTERS: experience(letter)
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(state.data.journey,step,{},1000.0)
	for number: int in [2,3]:
		for step: Dictionary in Chapter.content().chapters[str(number)].steps:
			if step.kind == "question":
				fixture_event({"kind":"trial_begin","context":step.id,"room":step.room})
				var trial_id: String = state.data.journey.p2.trials[step.id].id
				fixture_event({"kind":"trial_help","context":step.id,"trial_id":trial_id,"level":3,"room":step.room})
				fixture_event({"kind":"trial_answer","context":step.id,"trial_id":trial_id,"answer":"__demonstrated__","room":step.room})
			elif step.kind == "mail":
				for recipient: String in ["textbook_lingling","textbook_tim"]:
					fixture_event({"kind":"mail","recipient":recipient,"mailbox":recipient,"room":step.room})
			elif step.kind == "seats": fixture_event({"kind":"seats","count":step.seat_count,"room":step.room})
			fixture_event({"kind":"chapter_step","chapter":number,"step":step.id,"room":step.room})
	check(state.save_state(),"u3_completed_fixture_saved")
	await game.change_room("home")
	check(state.data.journey.p2.party.memory.is_empty(),"old_u3_completion_does_not_invent_party")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await frames(5)
		print("LIFE photo start background=",game.application_backgrounded)
		await game.journey._take_photo("yellow")
		photo_path = str(state.data.journey.u1.photo.details.get("image_path",""))
		check(not photo_path.is_empty() and FileAccess.file_exists(photo_path),"real_test_photo_for_friend_memories")
		await game.change_room("home")

func fixture_event(event: Dictionary) -> void:
	check(Chapter.apply(state.data.journey,event,1000.0).ok,"fixture/"+str(event.kind)+"/"+str(event.get("step",event.get("context",""))))

func party_flow() -> void:
	game.ui.reduced_motion = size_id == "960x640"
	game.journey.show_hub()
	await click_action("journey:party")
	await click_name("PartyBegin")
	await click_name("PartyTheme_star")
	await click_name("PartyGuest_textbook_mingming")
	await click_name("PartySeat_seat_4")
	check(state.data.journey.p2.party.revision == 0,"party_draft_does_not_confirm_layout")
	await shot("07-party-table-draft")
	await click_name("PartyPause")
	state.load_state()
	await game.journey.party.show_wish()
	await click_name("PartyBegin")
	check(state.data.journey.p2.party.draft.theme == "star","party_layout_draft_recovers")
	await click_name("PartyConfirm")
	check(state.data.journey.p2.party.layout.seats.textbook_mingming == "seat_4","party_selected_seat_committed")
	check(state.data.journey.p2.party.memory.is_empty(),"arranging_is_not_watching")
	await shot("08-party-ready")
	await click_name("PartyPlay")
	await frames(15)
	await click_name("PartyPlaybackPause")
	var paused_step: int = state.data.journey.p2.party.playback.step
	await create_timer(4.5).timeout
	check(state.data.journey.p2.party.playback.step == paused_step,"paused_party_does_not_complete_beat")
	await shot("09-party-paused")
	await click_name("PartyPlaybackLeave")
	state.load_state()
	check(state.data.journey.p2.party.memory.is_empty(),"closing_unfinished_party_does_not_grant_memory")
	await game.journey.party.show_wish()
	await click_name("PartyPlay")
	await frames(25)
	await shot("10-party-actual-guests")
	for tick: int in 1500:
		await process_frame
		if not state.data.journey.p2.party.memory.is_empty(): break
	check(not state.data.journey.p2.party.memory.is_empty(),"four_visible_beats_create_party_memory")
	if state.data.journey.p2.party.memory.is_empty(): return
	check(state.data.journey.p2.party.memory.layout.theme == "star","memory_keeps_watched_theme")
	await frames(6)
	await shot("11-party-memory")
	var memory: Dictionary = state.data.journey.p2.party.memory.duplicate(true)
	await game.journey.party.show_wish()
	await click_name("PartyBegin")
	await click_name("PartyTheme_flowers")
	await click_name("PartyCancel")
	check(state.data.journey.p2.party.layout.theme == "star" and state.data.journey.p2.party.memory == memory,"cancel_does_not_replace_watched_memory")
	state.load_state()
	check(state.data.journey.p2.party.memory == memory,"party_memory_disk_restore")
	game._close()
	game.journey._build_story_props()
	await frames(8)
	await shot("12-home-completed-keepsakes")
	await walk_to("journey_party_table")
	check(find_name("PartyPlay") != null,"world_party_table_reachable")

func friends_flow() -> void:
	game.journey.show_hub()
	await click_action("journey:friends")
	await shot("13-friends-to-revisit")
	await click_name("MemoryVisit_textbook_anne")
	await wait_panel("friend_memory")
	await frames(8)
	check(game.room == "school" and game.ui.current_panel == "friend_memory","anne_response_opens_at_real_actor")
	check(game.journey.memories.memory_for("textbook_anne",state.data.journey).stage == "party_memory","anne_remembers_watched_party")
	await shot("14-friend-remembers-party")
	await click_name("MemoryRecall")
	check(game.ui.current_panel == "party","anne_recall_opens_party_memory")
	game.journey.memories.show_friends()
	await click_name("MemoryVisit_textbook_tim")
	await wait_panel("friend_memory")
	check(game.room == "landmark_M" and find_name("MemoryInvitation") != null,"tim_keeps_invitation_topic_after_party")
	await shot("15-tim-keeps-both-memories")
	await click_name("MemoryInvitation")
	check(game.ui.current_panel == "friend_memory" and find_name("CornerBackHome") != null,"tim_original_invitation_response_reachable")
	await game.change_room("landmark_F")
	check(state.journey_p2_event({"kind":"trial_begin","context":"U1-10","room":"landmark_F"}),"unfinished_optional_greeting_fixture")
	check(game.journey.intercept_interaction("actor:npc_rabbit_gardener"),"rabbit_direct_interaction_handled")
	await frames(6)
	check(game.journey.p2.context == "U1-10" and game.ui.current_panel == "journey_p2","unfinished_optional_greeting_keeps_priority")

func wait_panel(panel: String) -> void:
	for tick: int in 600:
		await frames(1)
		if not game.loading_room and game.ui.current_panel == panel: return
	check(false,"panel_timeout/"+panel)

func discovery() -> Dictionary:
	return state.data.journey.p2.discovery

func find_name(value: String) -> Button:
	return game.ui.panel_box.find_child(value,true,false) as Button

func find_action(value: String) -> Button:
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if str(button.get_meta("action_id","")) == value: return button
	return null

func click_name(value: String) -> void:
	await frames(3)
	await click_button(find_name(value),value)

func click_action(value: String) -> void:
	await frames(3)
	await click_button(find_action(value),value)

func click_button(button: Button, label: String) -> void:
	check(button != null,"button/"+label)
	if button == null: return
	var ancestor: Node = button.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await frames(3)
	check(not button.disabled,"enabled/"+label)
	var point := button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"click_visible/"+label)
	await motion(point)
	await mouse(point,true)
	await mouse(point,false)
	await frames(4)

func walk_to(id: String) -> void:
	game._close()
	await frames(3)
	var target: Dictionary = {}
	for entry: Dictionary in game.interactions:
		if entry.id == id: target = entry
	check(not target.is_empty(),"world_interaction/"+id)
	if target.is_empty(): return
	game._request_interaction(target,true)
	for tick: int in 900:
		await physics_frame
		if game.ui.modal.visible: return
	check(false,"world_walk_timeout/"+id)

func motion(point: Vector2) -> void:
	var input := InputEventMouseMotion.new()
	input.position = point
	input.global_position = point
	input.relative = point-last_mouse
	last_mouse = point
	root.push_input(input,true)
	await frames(1)

func mouse(point: Vector2, pressed: bool) -> void:
	var input := InputEventMouseButton.new()
	input.position = point
	input.global_position = point
	input.button_index = MOUSE_BUTTON_LEFT
	input.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	input.pressed = pressed
	root.push_input(input,true)
	await frames(1)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func shot(id: String) -> void:
	print("LIFE capture ",id)
	await frames(4)
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if not button.is_visible_in_tree(): continue
		var clipped := false
		var ancestor: Node = button.get_parent()
		while ancestor:
			if ancestor is ScrollContainer: clipped = true
			ancestor = ancestor.get_parent()
		var rect := button.get_global_rect()
		var inside := root.get_visible_rect().encloses(rect)
		if not clipped: check(inside,"layout/"+id+"/"+str(button.name))
		layouts.append({"screen":id,"button":str(button.name),"text":button.text,"inside":inside,"scrollable":clipped})
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(id+".png"))

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition: failures.append(label); print("FAIL ",label)

func finish() -> void:
	if finished: return
	finished = true
	for path: String in baseline: check(file_hash(path) == baseline[path],"production_preserved/"+path)
	var file := FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	if file:
		var canvas := root.get_visible_rect().size
		file.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","size":size_id,"window_size":[root.size.x,root.size.y],"canvas_size":[canvas.x,canvas.y],"renderer":DisplayServer.get_name(),"checks":checks,"failures":failures,"layout":layouts,"scope":"Native inputs and walking for discovery cards, district pages, drafts, save rollback, party seating and finite playback, real friends. Uses explicit first-station/district/U3-completed fixtures; not a new-game playthrough or learning-effect evaluation. The 960x640 window uses the project's aspect-preserving 960x600 canvas."},"  "))
		file.close()
	if not isolated_save.is_empty() and isolated_save == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(isolated_save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_save+suffix))
	if photo_path.begins_with("user://welcome-photo-%d-" % OS.get_process_id()) and FileAccess.file_exists(photo_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	print("LIFE_KEEPSAKES_NATIVE size=",size_id," checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
