extends SceneTree
## Focused native-input/layout acceptance; explicit fixtures, never the player's save.
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
var game: Node3D
var state: Node
var checks: Array = []
var failures: Array = []
var layouts: Array = []
var baseline: Dictionary = {}
var observed_actions: Array[String] = []
var input_trace: Array = []
var last_pointer := Vector2.ZERO
var output_dir := ""
var size_id := "1440x900"
var isolated_save := ""
var finished := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-size="): size_id = argument.trim_prefix("--ui-size=")
	output_dir = ProjectSettings.globalize_path("res://../docs/verification/main-ui/after/"+size_id)
	DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(180.0).timeout.connect(func(): check(false,"native_timeout"); finish())
	var dimensions := size_id.split("x")
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name() != "headless": root.grab_focus()
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: baseline[path] = file_hash(path)
	protect_photos()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for tick: int in 1200:
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready,"scene_ready")
	if not game.scene_ready: finish(); return
	state = root.get_node("State")
	game.ui.action.connect(func(id: String): observed_actions.append(id))
	isolated_save = state.save_path
	check(isolated_save == "user://validation-%d.json" % OS.get_process_id(),"isolated_save")
	if isolated_save != "user://validation-%d.json" % OS.get_process_id(): finish(); return
	state.data = state._default_state()
	state.data.preferences.fixed_day = true
	state.data.preferences.reduced_motion = true
	game.ui.reduced_motion = true
	game.muted = true
	check(state.save_state(),"fresh_fixture_saved")
	await game.change_room("home")
	await shot("01-home")
	await ground_click()
	for entry: Array in [["map","map","02-map"],["bag","bag","03-wardrobe"],["journey:hub","journey","04-travel-book-fresh"],["settings","settings","05-settings"],["quest","journey_home","06-dialogue"]]:
		await click_action(str(entry[0]),game.ui.hud)
		for tick: int in 300:
			await frames(1)
			if game.ui.modal.visible and not game.loading_room: break
		check(game.ui.current_panel == str(entry[1]),"hud_action/"+str(entry[0]))
		await shot(str(entry[2]))
		if str(entry[0]) == "journey:hub": await journal_entries()
		await close_native(str(entry[0]) == "settings")
	seed_completed_u3()
	check(Journey.normalize(state.data.journey).ok,"u3_fixture_normalizes")
	check(state.save_state(),"u3_fixture_saved")
	await game.change_room("village")
	await shot("07-island")
	await click_action("journey:hub",game.ui.hud)
	await shot("08-travel-book-u3")
	await journal_entries()
	for entry: Array in [["friends","journey_friends"],["discoveries","discovery"],["friend_corner","friend_corner"],["party","party"]]:
		await click_action("journey:"+str(entry[0]),game.ui.panel_box)
		check(game.ui.current_panel == str(entry[1]),"journal_action/"+str(entry[0]))
		await shot("09-"+str(entry[0]))
		await close_native()
		await click_action("journey:hub",game.ui.hud)
	await close_native()
	finish()

func seed_completed_u3() -> void:
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(state.data.journey,step)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(state.data.journey,letter,"landmark_"+letter,fact,"demonstration_viewed")
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(state.data.journey,step,{},1000.0)
	for number: int in [2,3]:
		for step: Dictionary in Chapter.content().chapters[str(number)].steps:
			if step.kind == "question":
				fixture_event({"kind":"trial_begin","context":step.id,"room":step.room})
				var trial_id: String = state.data.journey.p2.trials[step.id].id
				fixture_event({"kind":"trial_help","context":step.id,"trial_id":trial_id,"level":3,"room":step.room})
				fixture_event({"kind":"trial_answer","context":step.id,"trial_id":trial_id,"answer":"__demonstrated__","room":step.room})
			elif step.kind == "mail":
				for recipient: String in ["textbook_lingling","textbook_tim"]: fixture_event({"kind":"mail","recipient":recipient,"mailbox":recipient,"room":step.room})
			elif step.kind == "seats": fixture_event({"kind":"seats","count":step.seat_count,"room":step.room})
			fixture_event({"kind":"chapter_step","chapter":number,"step":step.id,"room":step.room})

func fixture_event(event: Dictionary) -> void:
	check(Chapter.apply(state.data.journey,event,1000.0).ok,"fixture/"+str(event.kind)+"/"+str(event.get("step",event.get("context",""))))

func journal_entries() -> void:
	for button: Button in game.ui.panel_box.find_children("*","Button",true,false):
		if not str(button.get_meta("action_id","")).begins_with("journey:"): continue
		await reveal(button)
		var id := str(button.get_meta("action_id"))
		check(is_fully_visible(button),"journal_entry_unclipped/"+id)
		check(not button.disabled and await hover_hits(button),"journal_entry_reachable/"+id)

func click_action(id: String, scope: Node) -> void:
	await frames(3)
	var found: Button
	for button: Button in scope.find_children("*","Button",true,false):
		if str(button.get_meta("action_id","")) == id and button.is_visible_in_tree(): found = button; break
	check(found != null,"button/"+id)
	if found == null: return
	await reveal(found)
	var disabled := found.disabled
	var unclipped := is_fully_visible(found)
	var hit := await hover_hits(found)
	var clickable := not disabled and unclipped and hit
	var diagnostic := {"kind":"click_preflight","action":id,"panel":game.ui.current_panel,"disabled":disabled,"unclipped":unclipped,"hit_at_motion":hit,"expected":control_info(found),"hovered_now":control_info(root.gui_get_hovered_control()),"mouse_now":str(root.get_mouse_position()),"window_focus":root.has_focus()}
	input_trace.append(diagnostic)
	check(clickable,"clickable/"+id)
	if not clickable:
		print("INPUT_DIAGNOSTIC ",JSON.stringify(diagnostic))
		return
	var action_count := observed_actions.size()
	await click_point(found.get_global_rect().get_center())
	input_trace.append({"kind":"click_result","requested":id,"received":observed_actions.slice(action_count),"panel":game.ui.current_panel})
	check(observed_actions.slice(action_count).has(id),"native_action_received/"+id)

func is_fully_visible(button: Button) -> bool:
	var visible_rect := root.get_visible_rect()
	var ancestor: Node = button.get_parent()
	while ancestor:
		if ancestor is Control and (ancestor.clip_contents or ancestor is ScrollContainer):
			var clip: Rect2 = ancestor.get_global_rect()
			if ancestor is ScrollContainer:
				var panel_style: StyleBox = ancestor.get_theme_stylebox("panel")
				clip.position += Vector2(panel_style.get_margin(SIDE_LEFT),panel_style.get_margin(SIDE_TOP))
				clip.size -= panel_style.get_minimum_size()
				for bar: ScrollBar in [ancestor.get_v_scroll_bar(),ancestor.get_h_scroll_bar()]:
					if not bar.is_visible_in_tree(): continue
					var bar_rect := bar.get_global_rect()
					if bar is VScrollBar: clip.size.x = minf(clip.size.x,bar_rect.position.x-clip.position.x)
					else: clip.size.y = minf(clip.size.y,bar_rect.position.y-clip.position.y)
			visible_rect = visible_rect.intersection(clip)
		ancestor = ancestor.get_parent()
	return button.is_visible_in_tree() and visible_rect.grow(0.5).encloses(button.get_global_rect())

func hover_hits(button: Button) -> bool:
	var point := button.get_global_rect().get_center()
	move_pointer(point)
	# push_input dispatches this event now. Later OS motion must not replace its hit result.
	var hovered := root.gui_get_hovered_control()
	var hit := hovered == button or (hovered != null and button.is_ancestor_of(hovered))
	var diagnostic := {"kind":"hover","action":str(button.get_meta("action_id","")),"panel":game.ui.current_panel,"point":str(point),"expected":control_info(button),"immediate":control_info(hovered),"hit_at_motion":hit}
	await frames(1)
	diagnostic["after_frame"] = control_info(root.gui_get_hovered_control())
	diagnostic["mouse_after_frame"] = str(root.get_mouse_position())
	diagnostic["focus_owner"] = control_info(root.gui_get_focus_owner())
	diagnostic["window_focus"] = root.has_focus()
	input_trace.append(diagnostic)
	return hit

func control_info(control: Control) -> Dictionary:
	if not is_instance_valid(control): return {}
	var rect := control.get_global_rect()
	return {"path":str(control.get_path()),"action":str(control.get_meta("action_id","")),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"visible":control.is_visible_in_tree(),"mouse_filter":control.mouse_filter}

func move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point; motion.relative = point-last_pointer
	last_pointer = point
	root.push_input(motion,true)

func reveal(button: Button) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await frames(3)

func close_native(escape: bool = false) -> void:
	check(game.ui.modal.visible and not game.ui.current_panel.is_empty(),"close_starts_from_modal")
	if escape:
		for pressed: bool in [true,false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE; key.physical_keycode = KEY_ESCAPE; key.pressed = pressed
			root.push_input(key,true)
			await frames(1)
	else: await click_action("close",game.ui.panel_box)
	await frames(4)
	check(not game.ui.modal.visible and game.ui.current_panel.is_empty() and game.ui.hud.visible and not game.player.locked,"close_restores_hud")

func click_point(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		# Keep the target motion and its button event together, including before release.
		move_pointer(point)
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await frames(1)
	await frames(4)

func ground_click() -> void:
	var before: Vector3 = game.player.position
	for offset: Vector3 in [Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2),Vector3(0,0,-2)]:
		var point: Vector2 = game.camera.unproject_position(before+offset)
		if not game.feedback.pick(point,game.camera).is_empty(): continue
		await click_point(point)
		await frames(24)
		if game.player.position.distance_to(before) > 0.2: break
	check(game.player.position.distance_to(before) > 0.2 and not game.ui.modal.visible,"hud_empty_space_allows_ground_walk")
	game._cancel_navigation()

func shot(id: String) -> void:
	await frames(5)
	var buttons: Array[Node] = game.ui.hud.find_children("*","Button",true,false) if game.ui.hud.visible else game.ui.panel_box.find_children("*","Button",true,false)
	var visible: Array[Button] = []
	for button: Button in buttons:
		if not button.is_visible_in_tree(): continue
		var rect := button.get_global_rect()
		layouts.append({"screen":id,"action":str(button.get_meta("action_id","")),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		if game.ui.hud.visible:
			check(root.get_visible_rect().encloses(rect),"hud_inside/"+id+"/"+str(button.get_meta("action_id","")))
			for previous: Button in visible: check(not rect.intersects(previous.get_global_rect()),"hud_no_overlap/"+id+"/"+str(button.name)+"/"+str(previous.name))
			visible.append(button)
	check(root.get_visible_rect().encloses(game.ui.panel.get_global_rect()) if game.ui.modal.visible else true,"panel_inside/"+id)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output_dir.path_join(id+".png")) == OK,"capture/"+id)

func frames(count: int) -> void:
	for tick: int in count: await physics_frame; await process_frame

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func protect_photos() -> void:
	var manifest_path := "res://../.local/backups/main-ui-20261024/manifest.json"
	if not FileAccess.file_exists(manifest_path): return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	check(manifest is Array,"production_photo_manifest_readable")
	if not manifest is Array: return
	var photo_count := 0
	for entry: Dictionary in manifest:
		var path := str(entry.get("path","")).replace("\\","/")
		if not path.get_file().begins_with("welcome-photo-") or path.get_extension() != "png": continue
		baseline[path] = str(entry.get("hash","")).to_lower()
		check(file_hash(path) == baseline[path],"production_photo_matches_backup/"+path.get_file())
		photo_count += 1
	check(photo_count >= 2,"two_production_photos_protected")

func check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition: failures.append(label); print("FAIL ",label)

func finish() -> void:
	if finished: return
	finished = true
	for path: String in baseline: check(file_hash(path) == baseline[path],"production_preserved/"+path)
	var canvas := root.get_visible_rect().size
	var file := FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","size":size_id,"window_size":[root.size.x,root.size.y],"canvas_size":[canvas.x,canvas.y],"renderer":DisplayServer.get_name(),"checks":checks,"failures":failures,"layout":layouts,"input_trace":input_trace,"scope":"Native HUD/panel input, layout, journal entry access, fresh and U3-completed fixtures, daylight screenshots. Focused UI acceptance; not a full gameplay regression."},"  ")); file.close()
	if isolated_save == "user://validation-%d.json" % OS.get_process_id():
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(isolated_save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_save+suffix))
	print("MAIN_UI_NATIVE size=",size_id," checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
