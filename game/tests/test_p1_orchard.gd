extends SceneTree
## Real A-room geometry, physical actors, engine-dispatched clicks and durable ownership.
var game: Node3D
var state: Node
var checks: Array=[]
var failures: Array[String]=[]
var capture_directory:=""
var production_hash:=""
var production_backup_hash:=""
var requested_size:=Vector2i(1440,900)
var trace: Array=[]
const PRODUCTION:="user://island-save-v1.json"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--orchard-capture="): capture_directory=arg.trim_prefix("--orchard-capture=")
		if arg.begins_with("--art-width="): requested_size.x=arg.trim_prefix("--art-width=").to_int()
		if arg.begins_with("--art-height="): requested_size.y=arg.trim_prefix("--art-height=").to_int()
	root.size=requested_size
	production_hash=FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing"
	production_backup_hash=FileAccess.get_sha256(PRODUCTION+".bak") if FileAccess.file_exists(PRODUCTION+".bak") else "missing"
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for frame: int in 1800:
		await process_frame
		if game.scene_ready: break
	_check(game.scene_ready,"scene_ready")
	if not game.scene_ready:
		_finish()
		return
	state=root.get_node("State")
	state.data=state._default_state()
	state.save_state()
	for step: String in ["H01","H02","H03","H04"]:
		_check(state.journey_complete_home_step(step),"home_prerequisite/"+step)
	game.ui.reduced_motion=false
	game.muted=true
	await game.change_room("landmark_A")
	await _frames(5)
	var original_rabbit := game.world.get_node_or_null("Rabbit") as Node3D
	_check(is_instance_valid(original_rabbit) and original_rabbit.visible,"authored_rabbit_wrapper_keeps_original_identity_and_visibility")
	game.start_orchard_activity()
	await _frames(80)
	_check(is_instance_valid(game.orchard_activity),"actual_scene_setup")
	if not is_instance_valid(game.orchard_activity):
		_finish()
		return
	var activity: Node3D=game.orchard_activity
	_check(is_instance_valid(original_rabbit) and not original_rabbit.is_visible_in_tree(),"activity_hides_original_rabbit_visual")
	_check(activity.actor.is_visible_in_tree(),"only_activity_rabbit_remains_visible")
	print("ORCHARD ",activity.get_status())
	_check(activity.phase=="ready","new_round_ready")
	_check(activity.apple.get_parent()==activity,"apple_on_original_tree_branch")
	_check(activity.basket.name=="A_Entrance_Basket","uses_authored_basket")
	await _capture("01-ready")
	await _world_click(activity.apple.global_position)
	_check(activity.phase=="walking_pick","click_actual_apple_starts_walk")
	await _until(activity,"picking",1200)
	await _frames(24)
	activity.set_paused(true)
	await _frames(2)
	var before: Dictionary=activity.actor.get_status()
	var held: Vector3=activity.apple.global_position
	var t: float=activity.clock
	await _frames(18)
	_check(activity.clock==t and activity.apple.global_position.is_equal_approx(held),"pause_freezes_activity_and_prop")
	_check(activity.actor.get_status().visual_time==before.visual_time,"pause_freezes_actor_animation")
	activity.set_paused(false)
	await _until(activity,"carrying",600)
	await _frames(15)
	_check(activity.apple.get_parent()==activity.actor.hand_socket,"apple_reparents_at_contact")
	_check(state.journey_orchard_snapshot().stage=="carrying","contact_saved_before_ownership_changes")
	await _capture("02-carrying")
	var first_round: String=activity.round_id
	trace.append(activity.get_status())
	game._stop_orchard_activity()
	await _frames(3)
	_check(is_instance_valid(original_rabbit) and original_rabbit.is_visible_in_tree(),"interruption_restores_original_rabbit_visual")
	state.load_state()
	game.start_orchard_activity()
	await _frames(5)
	activity=game.orchard_activity
	_check(is_instance_valid(original_rabbit) and not original_rabbit.is_visible_in_tree(),"resumed_activity_hides_original_rabbit_again")
	_check(activity.phase=="carrying" and activity.round_id==first_round,"resume_carrying_same_round")
	_check(activity.apple.get_parent()==activity.actor.hand_socket,"resume_prop_ownership")
	var save_path: String=state.save_path
	var blocker:="user://orchard-blocker-%d" % OS.get_process_id()
	var file:=FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("isolated failure fixture")
	file.close()
	state.save_path=blocker+"/save.json"
	await _world_click(activity.basket_target)
	_check(activity.phase=="walking_place","click_actual_basket_starts_carry_walk")
	await _until(activity,"placing",1200)
	await _capture("03-place-approach")
	await _until(activity,"save_place",600)
	_check(activity.apple.get_parent()==activity.actor.hand_socket and state.journey_orchard_snapshot().stage=="carrying","failed_save_keeps_apple_in_hand")
	state.save_path=save_path
	await _click_button(activity.main_button)
	await _until(activity,"deposited",600)
	await _frames(90)
	_check(activity.apple.get_parent()==activity,"apple_released_only_on_saved_contact")
	_check(activity.apple.global_position.distance_to(activity.basket_target-Vector3.UP*.15)<.01,"apple_settles_inside_authored_basket")
	_check(is_instance_valid(activity.discovery_panel),"discovery_after_physical_action")
	await _capture("04-deposited-discovery")
	trace.append(activity.get_status())
	for row: Dictionary in activity.contact_distances:
		_check(float(row.distance)<=.22,"contact_distance/"+str(row.action))
	_check(state.data.coins==30 and state.data.learning.is_empty(),"orchard_does_not_grant_economy_or_course_mastery")
	var letter_facts: Dictionary=state.journey_snapshot().letters.duplicate(true)
	activity.set_paused(true)
	activity.replay()
	await _frames(5)
	_check(activity.phase=="ready" and activity.round_id!=first_round,"replay_gets_new_round")
	_check(activity.apple.global_transform.is_equal_approx(activity._apple_on_branch),"replay_restores_branch_orientation_and_position")
	_check(activity.paused and activity.main_button.disabled and activity.detail.text.contains("继续"),"paused_replay_keeps_clear_resume_instruction")
	_check(state.journey_snapshot().letters==letter_facts,"replay_preserves_discoveries")
	activity.set_paused(false)
	activity.start_demonstration()
	await _until(activity,"deposited",2200)
	await _frames(90)
	_check(state.journey_orchard_snapshot().completion_mode=="demonstration_viewed","demonstration_recorded_separately")
	trace.append(activity.get_status())
	for button: Node in activity.discovery_panel.find_children("*","Button",true,false):
		if button.text=="收下这次发现":
			await _click_button(button)
			break
	_check(not is_instance_valid(game.orchard_activity) and not state.journey_snapshot().letters.A.experienced,"receiving_physical_discovery_waits_for_glyph_observation")
	await _frames(3)
	for button: Button in game.journey.letter_activity.find_children("*","Button",true,false):
		if button.text=="看看建筑里的 A":
			await _click_button(button)
			break
	await _frames(3)
	_check(state.journey_snapshot().letters.A.experienced,"discover_A_after_receiving_and_real_model_observation")
	if is_instance_valid(game.orchard_activity): print("DISCOVERY NOT CLOSED ",state.journey_snapshot().letters.A," PENDING ",game.journey.letter_pending," TOAST ",game.ui.toast_label.text)
	# Observing the glyph leaves its discovery panel open, which intentionally
	# hides the HUD. Return through the real close control before checking it.
	_check(game.player.visual.visible,"orchard_exit_restores_player_while_discovery_panel_is_open")
	var close_control: Button
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if str(button.get_meta("action_id",""))=="close":
			close_control=button
			break
	_check(close_control!=null,"discovery_panel_exposes_close_control")
	if close_control!=null: await _click_button(close_control)
	await _frames(3)
	_check(game.player.visual.visible and game.ui.hud.visible,"exit_restores_player_and_hud")
	_check(game.living.get_actor("npc_rabbit_gardener")==null,"activity_actor_removed_on_exit")
	_check(is_instance_valid(original_rabbit) and original_rabbit.is_visible_in_tree(),"discovery_exit_restores_original_rabbit_visual")
	_check((FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing")==production_hash,"production_save_unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	game._close()
	_finish()
func _until(activity: Node,phase: String,frames: int) -> void:
	for frame: int in frames:
		await _frames(1)
		if activity.phase==phase: break
	_check(activity.phase==phase,"reached/"+phase)
	if activity.phase!=phase: print("STUCK ",activity.get_status())
func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame
func _world_click(point: Vector3) -> void:
	await _frames(3)
	var location: Vector2=game.camera.unproject_position(point)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=location
		event.global_position=location
		event.pressed=pressed
		Input.parse_input_event(event)
		await _frames(1)
func _click_button(button: Button) -> void:
	_check(button.is_visible_in_tree() and not button.disabled,"clickable/"+button.text)
	print("CLICK ",button.text," ",button.get_global_rect()," ROOT ",root.size," VIEW ",root.get_visible_rect())
	var location:=button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=location
		event.global_position=location
		event.pressed=pressed
		Input.parse_input_event(event)
		await _frames(1)
	await _frames(2)
func _capture(name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join(name+".png"))
func _check(value: bool,id: String) -> void:
	checks.append({"id":id,"passed":value})
	if not value:
		failures.append(id)
		print("FAIL: ",id)
func _finish() -> void:
	var directory:=ProjectSettings.globalize_path("res://../docs/verification/v0.6.0")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): directory=arg.trim_prefix("--report-dir=")
	_check((FileAccess.get_sha256(PRODUCTION+".bak") if FileAccess.file_exists(PRODUCTION+".bak") else "missing")==production_backup_hash,"production_backup_unchanged")
	DirAccess.make_dir_recursive_absolute(directory)
	var file:=FileAccess.open(directory.path_join("orchard-integration.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"trace":trace,"requested_window":[requested_size.x,requested_size.y],"actual_display_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"actual_viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y]},"  "))
	print("P1 ORCHARD ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
