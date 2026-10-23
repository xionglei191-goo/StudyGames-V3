extends SceneTree
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
const Corner = preload("res://scripts/friend_corner_progress.gd")
var game: Node3D
var state: Node
var checks: Array = []
var failures: Array = []
var layout_checks: Array = []
var baseline: Dictionary = {}
var resolution := "1440x900"
var independent := false
var output_dir := ""
var last_mouse := Vector2.ZERO
var isolated_save := ""
var photo_path := ""
var finished := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--friend-size="): resolution = arg.trim_prefix("--friend-size=")
		if arg == "--independent": independent = true
	output_dir = ProjectSettings.globalize_path("res://../docs/verification/friend-corner/"+resolution)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output_dir = arg.trim_prefix("--report-dir=").path_join(resolution)
	DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(240.0).timeout.connect(func(): check(false,"integration_timeout"); finish())
	var dimensions := resolution.split("x")
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name() != "headless": root.grab_focus()
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: baseline[path] = file_hash(path)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for index: int in 1200:
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready,"scene_ready")
	if not game.scene_ready: finish(); return
	state = root.get_node("State")
	isolated_save = state.save_path
	check(isolated_save.begins_with("user://validation-"),"isolated_runtime_save")
	state.data = state._default_state()
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(state.data.journey,step)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(state.data.journey,letter,"landmark_"+letter,fact,"companion_action")
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(state.data.journey,step,{},1000.0)
	check(state.save_state(),"u1_complete_fixture_saved")
	game.ui.reduced_motion = true
	game.muted = true
	if DisplayServer.get_name() != "headless":
		await game.journey._take_photo("yellow")
		photo_path = str(state.data.journey.u1.photo.details.get("image_path",""))
		check(not photo_path.is_empty() and FileAccess.file_exists(photo_path),"real_engine_welcome_photo")
		if not photo_path.is_empty(): DirAccess.copy_absolute(ProjectSettings.globalize_path(photo_path),output_dir.path_join("welcome-photo.png"))
	game.journey.show_hub()
	await click_text("我的朋友角 · 小岛心愿")
	check(game.ui.current_panel == "friend_corner" and not Corner.owns_replies(corner()),"wish_preview_does_not_grant_reward")
	await shot("01-wish-preview")
	await click_name("CornerContinue")
	await wait_step("U2-01")
	await click_name("CornerCover_textbook_lingling_star")
	await wait_step("U2-01")
	await click_name("CornerCover_textbook_tim_flowers")
	await wait_step("U2-01")
	state.load_state()
	check(corner().invitation_styles == {"textbook_lingling":"star","textbook_tim":"flowers"},"chosen_invitation_covers_persist")
	await game.journey.p2.show_chapter()
	await shot("02-personal-invitations")
	for recipient: String in Corner.RECIPIENTS:
		var title: Label = game.ui.panel_box.find_child("CornerInvitationTitle_"+recipient,true,false)
		check(title != null and title.get_line_count() == 1,"invitation_title_readable_on_one_line/"+recipient)
	for step: Dictionary in Chapter.content().chapters["2"].steps:
		await wait_step(step.id)
		check(game.room == step.room and game.living.get_actor(step.actor) != null,"real_scene_and_actor/"+step.id)
		match str(step.kind):
			"question":
				await click_text("和朋友回应")
				if not independent and step.id == "U2-02":
					await click_text("Goodbye!")
					await click_text("小提示")
					await click_text("完整示范")
					await click_text("看过示范，继续")
				else:
					for option: Dictionary in step.question.options:
						if option.id == step.question.correct: await click_text(option.text)
				await click_text("继续")
			"mail":
				await click_text("邀请给 Tim")
				await click_text("Lingling 的信格")
				check(state.data.journey.p2.mail.is_empty(),"wrong_mailbox_keeps_letter")
				await drag(find_text("邀请给 Lingling"),find_text("Lingling 的信格"))
				await wait_step(step.id)
				await click_text("邀请给 Tim")
				await click_text("Tim 的信格")
				await wait_step(step.id)
				check(state.data.journey.p2.mail.size() == 2,"invitation_native_drag_and_click")
				await click_text("两封都送好了")
			"letters": await click_text("收进旅行册")
			"complete": await click_text("收下回信，完成这一章")
			_: await click_text("一起继续")
		check(state.data.journey.p2.chapters["2"].steps.has(step.id),"u2_step_saved/"+step.id)
		if not state.data.journey.p2.chapters["2"].steps.has(step.id): finish(); return
	check(Corner.owns_replies(corner()),"replies_and_clip_reward_saved")
	check(state.data.journey.p2.chapters["3"].steps.is_empty() and game.journey.friend_corner.mode == "reward","chapter_end_is_a_choice_not_auto_next")
	check(state.data.journey.p2.trials["U2-02"].result == ("independent_correct" if independent else "demonstrated"),"learning_support_remains_honest")
	check(state.data.coins == 30 and state.data.learning.is_empty(),"no_new_currency_or_legacy_assessment")
	await shot("03-replies-arrive")
	await click_name("CornerBegin")
	await click_name("CornerReply_textbook_lingling")
	await click_name("CornerSlot_left")
	check(corner().draft.positions.textbook_lingling == "left" and Corner.placed_count(corner().layout) == 0,"native_click_places_draft_only")
	await click_name("CornerPause")
	state.load_state()
	game.journey._build_story_props()
	check(corner().draft.positions.textbook_lingling == "left","pause_and_disk_resume_keeps_draft")
	check(world_board().get_meta("letters_displayed") == 0,"world_does_not_show_unconfirmed_letters")
	await walk_to_board()
	await click_name("CornerBegin")
	await drag(find_name("CornerReply_textbook_tim"),find_name("CornerSlot_right"))
	check(Corner.placed_count(corner().draft) == 2,"native_drag_hangs_second_reply")
	await click_name("CornerStyle_star")
	check(corner().draft.style == "star","native_theme_selection")
	await shot("04-layout-preview")
	await save_failure_check()
	await click_name("CornerConfirm")
	check(corner().draft.is_empty() and Corner.placed_count(corner().layout) == 2,"confirm_persists_two_letters")
	check(world_board().get_meta("letters_displayed") == 2 and not world_board().get_meta("draft_visible"),"real_world_uses_committed_layout")
	await shot("05-saved-friend-corner")
	var confirmed: Dictionary = corner().layout.duplicate(true)
	var receipts: Dictionary = corner().reward_receipt.duplicate(true)
	await click_name("CornerBegin")
	await click_name("CornerStyle_flowers")
	await click_name("CornerReply_textbook_lingling")
	await click_name("CornerSlot_lower")
	await click_name("CornerCancel")
	check(corner().layout == confirmed and corner().reward_receipt == receipts,"cancel_preserves_display_and_single_reward")
	await click_name("CornerReply_textbook_lingling")
	check(all_text().contains("很高兴认识你"),"reply_readable_in_large_text")
	await shot("06-read-reply")
	await click_name("CornerReplyBack")
	await click_name("CornerVisitLingling")
	await wait_panel("friend_memory")
	check(game.room == "school" and game.living.get_actor("textbook_lingling") != null,"revisit_real_friend")
	check(all_text().contains("星星邀请"),"friend_recalls_actual_invitation_cover")
	check(corner().conversations.has("textbook_lingling"),"friend_revisit_saved")
	await shot("07-friend-remembers")
	await click_name("CornerTellFriend")
	check(all_text().contains("回信留了位置"),"friend_responds_to_confirmed_display")
	await click_name("CornerBackHome")
	await wait_panel("friend_corner")
	check(game.room == "home","return_to_own_home")
	await click_name("CornerLeave")
	await walk_to_board()
	await click_name("CornerLeave")
	await frames(20)
	await shot("08-home-world")
	if DisplayServer.get_name() != "headless":
		var canvas: SubViewport = world_board().get_node("KeepsakeCanvas")
		var image := canvas.get_texture().get_image()
		check(not image.is_empty(),"world_board_texture_rendered")
		image.save_png(output_dir.path_join("09-world-board-detail.png"))
	state.load_state()
	check(corner().layout == confirmed and corner().reward_receipt == receipts,"final_reload_preserves_display_and_ownership")
	check(state.data.coins == 30 and state.data.learning.is_empty(),"all_keepsake_actions_leave_economy_and_learning_unchanged")
	check(corner().revision == 1,"preview_and_cancel_do_not_increment_confirmed_revision")
	finish()

func corner() -> Dictionary:
	return state.data.journey.p2.friend_corner

func world_board() -> Node3D:
	return game.journey.story_room_root.get_node("FriendCorner")

func save_failure_check() -> void:
	var before: Dictionary = state.snapshot()
	var blocker := "user://friend-corner-ui-blocker-%d" % OS.get_process_id()
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("test blocker")
	file.close()
	state.save_path = blocker+"/failed-save.json"
	await click_name("CornerConfirm")
	check(state.snapshot() == before and game.journey.friend_corner.mode == "editor","ui_save_failure_preserves_draft_and_does_not_celebrate")
	check(world_board().get_meta("letters_displayed") == 0,"failed_save_does_not_change_world")
	state.save_path = isolated_save
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))

func walk_to_board() -> void:
	var entry: Dictionary = {}
	for item: Dictionary in game.interactions:
		if item.id == "journey_friend_corner": entry = item
	check(not entry.is_empty(),"physical_board_has_interaction")
	if entry.is_empty(): return
	game._request_interaction(entry,true)
	for index: int in 1600:
		await frames(1)
		if game.ui.current_panel == "friend_corner": break
	check(game.ui.current_panel == "friend_corner","walk_to_physical_board_opens_wish")
	check(game.player.position.distance_to(entry.position) <= float(entry.radius)+1.0,"board_is_physically_reachable")

func wait_step(id: String) -> void:
	for index: int in 600:
		await frames(1)
		if game.ui.current_panel == "journey_p2" and game.journey.p2.presented_step == id:
			await frames(3)
			return
	check(false,"step_timeout/"+id)

func wait_panel(id: String) -> void:
	for index: int in 600:
		await frames(1)
		if game.ui.current_panel == id:
			await frames(4)
			return
	check(false,"panel_timeout/"+id)

func find_name(value: String) -> Button:
	return game.ui.panel_box.find_child(value,true,false) as Button

func find_text(value: String) -> Button:
	for node: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if node.text == value and node.is_visible_in_tree(): return node
	return null

func click_name(value: String) -> void:
	await click(find_name(value),value)

func click_text(value: String) -> void:
	await click(find_text(value),value)

func click(button: Button, label: String) -> void:
	await frames(2)
	check(is_instance_valid(button),"button_exists/"+label)
	if not is_instance_valid(button): return
	check(not button.disabled and button.is_visible_in_tree(),"button_enabled/"+label)
	var point := button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"button_reachable/"+label)
	await move(point)
	await mouse(point,true)
	await mouse(point,false)
	await frames(4)

func drag(source: Button, target: Button) -> void:
	check(is_instance_valid(source) and is_instance_valid(target),"drag_targets_exist")
	if not is_instance_valid(source) or not is_instance_valid(target): return
	var from := source.get_global_rect().get_center()
	var to := target.get_global_rect().get_center()
	await move(from)
	await mouse(from,true)
	for index: int in range(1,11): await move(from.lerp(to,float(index)/10),true)
	await mouse(to,false)
	await frames(6)

func move(point: Vector2, pressed: bool = false) -> void:
	var input := InputEventMouseMotion.new()
	input.position = point
	input.global_position = point
	input.relative = point-last_mouse
	input.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
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

func all_text() -> String:
	var result := ""
	for node: Node in game.ui.panel_box.find_children("*","Label",true,false): result += str(node.text)+"\n"
	return result

func shot(id: String) -> void:
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if not button.is_visible_in_tree(): continue
		var rect := button.get_global_rect()
		var inside := root.get_visible_rect().encloses(rect)
		check(inside,"layout/"+id+"/"+str(button.name))
		layout_checks.append({"screen":id,"name":str(button.name),"text":button.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"inside_viewport":inside})
	if DisplayServer.get_name() == "headless": return
	await frames(4)
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
		file.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","size":resolution,"independent_path":independent,"renderer":DisplayServer.get_name(),"checks":checks,"failures":failures,"layout":layout_checks,"scope":"Starts from a U1-complete fixture; real U2 actor/scene progression and engine mouse input, invitation choices, letter drag/click, persistent preview, save rollback, world walking and friend response. No complete-new-game or learning-efficacy claim."},"  "))
		file.close()
	else: check(false,"report_write_failed")
	if not isolated_save.is_empty() and isolated_save == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(isolated_save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_save+suffix))
	if photo_path.begins_with("user://welcome-photo-%d-" % OS.get_process_id()) and FileAccess.file_exists(photo_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	print("FRIEND_CORNER_GAME size=",resolution," checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
