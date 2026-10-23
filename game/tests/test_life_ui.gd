extends SceneTree
## Engine-dispatched input and persistent lifecycle regressions for v0.4.
## Requires -- --test-harness; never opens the production save for writing.

var game: Node3D
var state: Node
var checks: Array = []
var failures: Array[String] = []
var protected_before := ""
const PRODUCTION := "user://island-save-v1.json"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	root.size = Vector2i(1440,900)
	protected_before = FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame: int in 600:
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready,"scene_ready")
	if not game.scene_ready:
		_finish()
		return
	state = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-"),"isolated_save")
	state.data = state._default_state()
	game.muted = true
	game.voice.stop()
	game.ui.reduced_motion = true
	await _direct_interaction()
	await _map_pins()
	await _decorations()
	await _music()
	await _art()
	await _science()
	await _football()
	await _settings()
	_check(state.data.learning.is_empty() and state.data.completed_units.values().count(true)==0,"life_play_never_grants_english_mastery")
	var after := FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "missing"
	_check(protected_before==after,"production_save_unchanged")
	game._close()
	_finish()

func _direct_interaction() -> void:
	await game.change_room("landmark_C")
	await _frames(45)
	var baker := _entry("baker")
	var point: Vector2 = game.camera.unproject_position(baker.position+Vector3.UP)
	_check(str(game.feedback.pick(point,game.camera).get("id",""))=="baker","npc_scene_ray_selects_baker")
	await _click_at(point)
	_check(str(game.pending_interaction.get("id",""))=="baker","scene_mouse_click_starts_npc_route")
	for frame: int in 1200:
		await _frames(1)
		if game.ui.modal.visible:
			break
	_check(game.ui.current_panel=="baker","walking_to_npc_opens_dialogue_automatically")
	_check(game.player.path.is_empty(),"dialogue_arrival_stops_walking")
	await _click_id("close")
	await game.change_room("landmark_C")
	game._request_interaction(_entry("baker"),true)
	await _key(KEY_D)
	_check(game.pending_interaction.is_empty() and game.player.path.is_empty(),"manual_movement_cancels_pending_interaction")
	await _frames(120)
	_check(not game.ui.modal.visible,"cancelled_route_does_not_open_delayed_dialogue")
	game._request_interaction(_entry("baker"),true)
	await _key(KEY_ESCAPE)
	_check(game.pending_interaction.is_empty() and not game.ui.modal.visible,"escape_cancels_walk_without_opening_settings")
	await game.change_room("landmark_A")
	var count: int = state.data.apples
	await game.interact_id("orchard")
	_check(state.data.apples==count+1 and not game.ui.modal.visible,"harvesting_gives_item_in_scene_without_modal")
	_check(game.player.gesture_kind=="reach","harvesting_triggers_character_gesture")

func _map_pins() -> void:
	await game.change_room("village")
	game.show_map()
	await _frames(4)
	var island_map: Control = game.ui.map_view
	var overlaps := 0
	for first: int in island_map.pins.size():
		var rectangle: Rect2 = island_map.pins[first].get_rect()
		for second: int in range(first+1,island_map.pins.size()):
			if rectangle.intersects(island_map.pins[second].get_rect()):
				overlaps += 1
		if rectangle.has_point(island_map._point(island_map.player_position)):
			overlaps += 1
	_check(overlaps==0,"all_island_map_pins_and_current_position_remain_visible")
	game._close()
	await game.change_room("school")
	game.show_map()
	await _frames(4)
	var map: Control = game.ui.map_view
	var index := -1
	for number: int in map.entries.size():
		if str(map.entries[number].id)=="music_room_gate":
			index = number
	_check(index>=0,"spatial_map_has_music_destination")
	if index<0:
		return
	_check(map.viewport.world_3d==game.get_world_3d(),"map_uses_real_authored_world")
	_check(not map.routes.get("music_room_gate",PackedVector3Array()).is_empty(),"map_previews_walkable_route")
	var pin: Button = map.pins[index]
	await _click_at(pin.get_global_rect().get_center())
	_check(not game.ui.modal.visible and str(game.pending_interaction.get("id",""))=="music_room_gate","actual_spatial_pin_click_starts_route")
	_check(not game.pending_auto,"map_arrival_keeps_player_in_control_of_entry")
	game._cancel_navigation()

func _decorations() -> void:
	state.data.coins = 100
	state.save_state()
	await game._preview_purchase("flower_box")
	await _frames(3)
	var before: Dictionary = state.snapshot()
	_check(game.decor_preview and _flower_visible(),"purchase_preview_changes_world")
	await _click_id("close")
	_check(state.snapshot()==before and not _flower_visible(),"closing_purchase_reverts_preview_without_spending")
	await game._preview_purchase("flower_box")
	await _frames(3)
	await _click_id("buy:flower_box")
	_check(state.data.coins==75 and state.data.decorations_owned.flower_box and state.data.decorations_placed.flower_box,"buy_and_place_commits_together")
	await _click_id("preview_place:flower_box")
	_check(not _flower_visible() and state.data.decorations_placed.flower_box,"removal_preview_does_not_change_saved_state")
	await _click_id("cancel_place")
	_check(_flower_visible() and state.data.decorations_placed.flower_box,"cancel_restores_saved_decoration")
	await _click_id("preview_place:flower_box")
	await _click_id("confirm_place")
	_check(not _flower_visible() and not state.data.decorations_placed.flower_box,"confirmed_removal_updates_world_and_state")
	await _click_id("undo_place")
	_check(_flower_visible() and state.data.decorations_placed.flower_box,"undo_restores_previous_placement")
	state.load_state()
	_check(state.data.decorations_placed.flower_box,"undo_survives_reload")
	await _click_id("preview_place:flower_box")
	await _key(KEY_ESCAPE)
	_check(_flower_visible() and not game.ui.modal.visible,"escape_rolls_back_unconfirmed_removal")
	await game.change_room("home")
	_check(_flower_visible(),"decoration_persists_after_room_rebuild")

func _music() -> void:
	await game.change_room("music_room")
	game.start_activity("music")
	await _frames(3)
	var board: Node = game.ui.activity_board
	var coins: int = state.data.coins
	await _click_text("先听一遍")
	await _frames(135)
	_check(not state.data.life.activities.music and state.data.coins==coins,"listening_to_music_demo_does_not_complete_activity")
	for note: int in [0,2,4,2]:
		await _click_at(board.notes[note].get_global_rect().get_center())
	_check(state.data.life.activities.music and state.data.coins==coins+8,"actual_piano_clicks_complete_melody")
	for key: int in [KEY_1,KEY_3,KEY_5,KEY_3]:
		await _key(key)
	_check(state.data.coins==coins+8,"keyboard_melody_replay_has_no_extra_reward")
	await _click_text("先听一遍")
	await _click_id("close")
	await _frames(130)
	_check(not game.ui.modal.visible,"closing_during_music_demo_is_safe")

func _art() -> void:
	await game.change_room("art_room")
	game.start_activity("art")
	await _frames(3)
	var board: Node = game.ui.activity_board
	var canvas: Control = board.canvas
	var origin: Vector2 = canvas.get_global_rect().position+canvas.size*Vector2(0.35,0.4)
	await _move(origin)
	await _mouse(origin,true)
	_check(board.dirty,"first_paint_contact_marks_unsaved_changes_immediately")
	await _move(origin+Vector2(70,50),MOUSE_BUTTON_MASK_LEFT)
	await _mouse(origin+Vector2(70,50),false)
	_check(canvas.strokes.size()==1 and canvas.strokes[0].points.size()>=2,"actual_mouse_drag_creates_normalized_stroke")
	var draft: Array = canvas.strokes.duplicate(true)
	await _click_id("close")
	_check(game.ui.current_panel=="art_unsaved" and state.data.life.artwork.is_empty(),"unsaved_art_close_prompts_without_overwriting_saved_work")
	await _click_id("return_art")
	_check(game.ui.activity_board.canvas.strokes==draft and game.ui.activity_board.dirty,"continue_restores_unsaved_art")
	await _click_id("close")
	await _click_id("save_art_draft")
	_check(not game.ui.modal.visible and state.data.life.artwork==draft,"save_before_leaving_keeps_postcard")
	game.start_activity("art")
	await _frames(3)
	await _click_text("清空画纸")
	await _click_id("close")
	await _click_id("discard_art")
	_check(state.data.life.artwork==draft,"discarding_draft_preserves_previous_postcard")
	game.show_artwork()
	await _frames(3)
	_check(game.ui.current_panel=="postcard","saved_postcard_opens_in_memory_book")
	game._close()

func _science() -> void:
	await game.change_room("science_room")
	game.start_activity("science")
	await _frames(3)
	var board: Node = game.ui.activity_board
	for pair: Array in [[1,2],[0,1],[0,2]]:
		await _click_text("倒掉重来")
		for pigment: int in pair:
			await _click_at(board.pigments[pigment].get_global_rect().get_center())
		await _click_text("混合颜色")
	_check(state.data.life.activities.science,"three_actual_color_mixes_complete_science")
	await _click_id("close")

func _football() -> void:
	await game.change_room("football_field")
	await _frames(3)
	var origin: Vector3 = game.player.position
	game.start_activity("football")
	await _frames(50)
	_check(is_instance_valid(game.football),"football_uses_authored_goal")
	if not is_instance_valid(game.football):
		return
	var practice: Node = game.football
	var target: Vector2 = game.camera.unproject_position(practice.goal+practice.sideways*practice.half_width*0.4+Vector3.UP*0.9)
	await _click_at(target)
	_check(practice.aim>0.1,"scene_click_aims_at_goal")
	var aim: HSlider = game.ui.panel_box.find_child("AimSlider",true,false)
	# Keyboard adjustment is dispatched to the focused native slider.
	aim.grab_focus()
	var previous: float = practice.aim
	await _key(KEY_RIGHT)
	_check(practice.aim>previous,"keyboard_slider_adjusts_football_aim")
	practice.update_aim(0.0)
	practice.power = 0.3
	_check(not practice.predicted_goal(),"weak_shot_cannot_reach_goal")
	practice.power = 1.0
	_check(not practice.predicted_goal(),"overpowered_shot_goes_over_crossbar")
	practice.power = 0.65
	practice.update_aim(1.2)
	_check(not practice.predicted_goal(),"wide_shot_misses_posts")
	practice.update_aim(0.0)
	_check(practice.predicted_goal(),"centered_moderate_shot_fits_goal")
	var coins: int = state.data.coins
	for attempt: int in 5:
		await _click_id("football_shoot")
		_check(practice.busy and practice.attempts==attempt+1,"shot_starts_"+str(attempt+1))
		_check(not practice.shoot(),"cannot_double_shoot_"+str(attempt+1))
		await _frames(100)
	_check(practice.attempts==5 and practice.goals==5,"five_shot_round_scores_consistently")
	_check(state.data.life.activities.football and state.data.life.scores.football==5 and state.data.coins==coins+8,"completed_round_saves_best_score_and_first_reward")
	_check(not practice.shoot(),"sixth_shot_requires_restart")
	await _click_id("football_restart")
	_check(game.football.attempts==0,"restart_resets_round")
	await _click_id("football_shoot")
	await _click_id("close")
	await _frames(100)
	_check(not is_instance_valid(game.football) and not game.player.locked,"leaving_mid_flight_cleans_up_practice")
	_check(Vector2(game.player.position.x,game.player.position.z).distance_to(Vector2(origin.x,origin.z))<0.05,"leaving_practice_restores_player_position")
	_check(state.data.coins==coins+8,"incomplete_replay_grants_no_reward")

func _settings() -> void:
	game.show_settings()
	await _frames(3)
	await _click_id("toggle_effects")
	await _click_id("toggle_motion")
	state.load_state()
	_check(not state.data.preferences.effects and state.data.preferences.reduced_motion==game.ui.reduced_motion and not game.ui.reduced_motion,"settings_roundtrip")
	await _click_id("close")

func _flower_visible() -> bool:
	var flowers: Node = game.world.find_child("SG_DECOR_MODEL_FLOWER_BOX",true,false)
	if flowers==null:
		flowers = game.world.get_node_or_null("DecorationWindowFlowers")
	return flowers!=null and flowers.visible

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in game.interactions:
		if str(entry.id)==id:
			return entry
	return {}

func _click_id(id: String) -> void:
	for node: Node in game.ui.panel_box.find_children("*","Button",true,false):
		if str(node.get_meta("action_id",""))==id:
			_check(not node.disabled and node.is_visible_in_tree(),"enabled_action/"+id)
			await _click_at(node.get_global_rect().get_center())
			return
	_check(false,"missing_action/"+id)

func _click_text(value: String) -> void:
	for node: Node in game.ui.panel_box.find_children("*","Button",true,false):
		if node.text==value:
			await _click_at(node.get_global_rect().get_center())
			return
	_check(false,"missing_button/"+value)

func _click_at(point: Vector2) -> void:
	await _move(point)
	await _mouse(point,true)
	await _mouse(point,false)
	await _frames(2)

func _move(point: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = mask
	Input.parse_input_event(event)
	await process_frame

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)

func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame

func _check(condition: bool, id: String) -> void:
	checks.append({"id":id,"passed":condition})
	if not condition:
		failures.append(id)
		print("FAIL: ",id)

func _finish() -> void:
	var directory := ProjectSettings.globalize_path("res://../docs/verification/v0.4.0")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="):
			directory = argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("life-ui-report.json"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","version":ProjectSettings.get_setting("application/config/version"),"engine":Engine.get_version_info().string,"actual_mouse_and_keyboard_dispatch":true,"checks":checks,"failures":failures},"  "))
	print("LIFE_UI_RESULT checks=%d failures=%d actual_mouse_and_keyboard_dispatch=true" % [checks.size(),failures.size()])
	if is_instance_valid(state):
		for suffix: String in ["",".bak",".tmp"]:
			var path: String = state.save_path+suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)
