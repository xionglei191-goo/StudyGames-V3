extends "res://tests/test_movement.gd"
## Scene picking, nearby-target access and isolated native captures.

var output := "F:/LoveStudy/.local/interaction-spacing-20261113"
var audit_only := false
var capture := false
var finished := false
var rooms: Array[String] = []
const Targets = preload("res://scripts/interaction_targets.gd")

func _process(_delta: float) -> bool:
	if is_instance_valid(_main): _main.application_backgrounded = false
	return false

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Interaction access tests require -- --test-harness for an isolated save.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--access-output="): output = arg.trim_prefix("--access-output=")
		if arg.begins_with("--access-rooms="): rooms.assign(arg.trim_prefix("--access-rooms=").split(","))
		audit_only = audit_only or arg == "--access-audit"
		capture = capture or arg == "--access-capture"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440,900)
	_protected_before = _production_signature()
	_report["rooms"] = []
	_report["screenshots"] = []
	create_timer(600).timeout.connect(func(): _check("bounded_timeout",false); _finish())
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("scene_ready",false)
		_finish()
		return
	_main.muted = true
	_main.ai_bridge.muted = true
	_main.voice.stop()
	_main.ui.reduced_motion = true
	_check("isolated_save",str(root.get_node("State").save_path).begins_with("user://validation-"))
	if rooms.is_empty():
		rooms.append("village")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors_manifest.json"))
		for row: Dictionary in manifest.rooms:
			if str(row.room_id) != "home_hall": rooms.append(str(row.room_id))
	for room_id: String in rooms:
		await _main.change_room(room_id)
		await _wait_for_room(room_id)
		_main._close()
		for frame in range(8): await process_frame
		await _audit_room(room_id)
		print("INTERACTION_ROOM ",room_id)
	if not audit_only:
		await _input_regressions()
	_finish()

func _audit_room(room_id: String) -> void:
	var row := {"room":room_id,"entries":[],"close_pairs":[],"picks":[],"layout":_main.metadata.get("interaction_layout",[])}
	if not audit_only:
		_check("default_actors_spawn_safely/"+room_id,_main.living.get_status().spawn_failures.is_empty())
		for move: Dictionary in row.layout:
			_check("safe_resident_placement/"+room_id+"/"+str(move.id),bool(move.resolved))
	for entry: Dictionary in _main.interactions:
		row.entries.append({"id":str(entry.id),"type":str(entry.get("type","")),"label":str(entry.label),"position":_vector(entry.position),"radius":entry.get("radius",0)})
		if not audit_only and str(entry.id).begins_with("memory_"):
			var marker: Node3D = _main.metadata.get("marker_nodes",{}).get(str(entry.get("marker","")))
			_check("fixed_memory_anchor/"+room_id+"/"+str(entry.id),marker!=null and marker.global_position.distance_to(entry.position)<0.001)
	for i: int in range(_main.interactions.size()):
		var a: Dictionary = _main.interactions[i]
		for j: int in range(i+1,_main.interactions.size()):
			var b: Dictionary = _main.interactions[j]
			var distance := _distance_xz(a.position,b.position)
			if distance < 2.8:
				row.close_pairs.append({"a":str(a.id),"b":str(b.id),"distance":distance})
			if not audit_only and ((a.has("resident_id") and not str(b.get("type","")) in Targets.NPC_TYPES) or (b.has("resident_id") and not str(a.get("type","")) in Targets.NPC_TYPES)):
				_check("resident_clearance/"+room_id+"/"+str(a.id)+"/"+str(b.id),distance>=2.79)
	if capture:
		var focus := _entry("memory_01")
		if not focus.is_empty():
			var target: Vector3 = focus.position + Vector3(0,0,3.0)
			var cell: Vector2i = _main._nearest_walkable_cell(Vector2i(roundi(target.x/_main.NAV_CELL),roundi(target.z/_main.NAV_CELL)),target)
			_main.player.position = Vector3(cell.x*_main.NAV_CELL,float(_main.nav_heights.get(cell,0))+.15,cell.y*_main.NAV_CELL)
			_main.player.safe_position = _main.player.position
		_main.camera_base_size = 12.0
		for frame in range(45): await process_frame
	for entry: Dictionary in _main.interactions:
		var height := Targets.focus_height(entry)
		var pixel: Vector2 = _main.camera.unproject_position(entry.position+Vector3.UP*height)
		var selected: Dictionary = _main.feedback.pick(pixel,_main.camera)
		row.picks.append({"id":str(entry.id),"selected":str(selected.get("id","")),"pixel":[pixel.x,pixel.y]})
		if not audit_only:
			var choices := Targets.colocated(entry,_main.interactions)
			var ids: Array[String] = []
			for choice: Dictionary in choices: ids.append(str(choice.id))
			for offset: Vector2 in [Vector2.ZERO,Vector2(-6,0),Vector2(6,0)]:
				var hit: Dictionary = _main.feedback.pick(pixel+offset,_main.camera)
				_check("pointer_target/"+room_id+"/"+str(entry.id)+"/"+str(offset),ids.has(str(hit.get("id",""))))
			var route: PackedVector3Array = _main._preview_route(entry.position)
			_check("reachable_target/"+room_id+"/"+str(entry.id),not route.is_empty() and _distance_xz(route[-1],entry.position)<float(entry.get("radius",2.7)))
	if capture and DisplayServer.get_name() != "headless":
		var first_memory := _entry("memory_01")
		if not first_memory.is_empty():
			_main.greeting_clock = 999.0
			_main.ui.bubble_panel.hide()
			await _mouse_motion(_main.camera.unproject_position(first_memory.position+Vector3.UP*0.12))
		await RenderingServer.frame_post_draw
		var file := output.path_join(room_id+".png")
		root.get_texture().get_image().save_png(file)
		_report.screenshots.append(file)
	_report.rooms.append(row)

func _input_regressions() -> void:
	await _main.change_room("landmark_A")
	await _wait_for_room("landmark_A")
	_main._close()
	await _frames(35)
	# The exact orchard ground point previously selected the gardener's tall box.
	var memory := _entry("memory_01")
	await _click_at(_main.camera.unproject_position(memory.position+Vector3.UP*0.12))
	_check("click_ground_point_selects_memory_not_resident",str(_main.pending_interaction.get("id",""))=="memory_01")
	_check("walk_and_open_clicked_memory",await _wait_panel("memory"))
	_check("clicked_memory_is_the_requested_one",_discovered("landmark_A","memory_01"))
	_main._close()
	await _frames(30)
	var resident := _entry("gardener")
	await _click_at(_main.camera.unproject_position(resident.position+Vector3.UP*1.1))
	_check("click_resident_selects_resident",str(_main.pending_interaction.get("id",""))=="gardener" or str(_main.ui.current_panel)==str(resident.get("resident_id","gardener")))
	_check("walk_and_open_clicked_resident",await _wait_panel(str(resident.get("resident_id","gardener"))))
	_main._close()
	await _frames(30)
	await _walk_to_entry("memory_03","keyboard_nearby_target")
	await _frames(30)
	var far := _entry("memory_02")
	await _mouse_motion(_main.camera.unproject_position(far.position+Vector3.UP*0.12))
	_check("mouse_can_preview_a_different_distant_target",str(_main.hover_interaction.get("id","")) in ["memory_02","orchard"])
	_check("E_prompt_keeps_nearby_target",str(_main.nearest.get("id",""))=="memory_03" and str(_main.ui.prompt.text).begins_with(str(_entry("memory_03").label)))
	await _key(KEY_E)
	_check("E_ignores_distant_mouse_hover",await _wait_panel("memory") and _discovered("landmark_A","memory_03"))
	_main._close()
	await _frames(30)
	await _mouse_motion(_main.camera.unproject_position(resident.position+Vector3.UP*1.1))
	await _key(KEY_D)
	_check("manual_movement_clears_stale_hover",_main.hover_interaction.is_empty() and not _main._hover_pointer_active)
	await _walk_to_point("shared_object_actions",far.position,0.55)
	await _frames(25)
	_check("both_shared_object_actions_remain_accessible",_main.nearby_interactions.size()>=2 and _main.ui.prompt_cycle.visible)
	var old_id := str(_main.nearest.id)
	await _key(KEY_Q)
	var prompt_matches := str(_main.ui.prompt.text).begins_with(str(_main.nearest.label)) or (str(_main.nearest.id)=="orchard" and str(_main.ui.prompt.text).begins_with("采苹果"))
	_check("Q_changes_visible_nearby_target",str(_main.nearest.id)!=old_id and prompt_matches)
	var after_key := str(_main.nearest.id)
	await _click_at(_main.ui.prompt_cycle.get_global_rect().get_center())
	_check("touch_cycle_button_changes_target",str(_main.nearest.id)!=after_key)
	await _click_at(_main.camera.unproject_position(far.position+Vector3.UP*0.12))
	_check("shared_object_click_lists_actions",_main.ui.current_panel=="interaction_choices" and _main.pending_interaction.is_empty())
	_check("shared_object_choices_are_explicit",_button("interaction_choice:memory_02")!=null and _button("interaction_choice:orchard")!=null)
	await _capture_current("shared-actions-1440")
	root.size = Vector2i(960,640)
	await _frames(8)
	_check("small_window_choices_fit",root.get_visible_rect().encloses(_main.ui.panel.get_global_rect()))
	await _capture_current("shared-actions-960")
	var choice := _button("interaction_choice:memory_02")
	if choice:
		await _click_at(choice.get_global_rect().get_center())
		_check("chosen_shared_action_opens_correct_memory",await _wait_panel("memory") and _discovered("landmark_A","memory_02"))
	_main._close()
	root.size = Vector2i(1440,900)
	await _frames(20)
	await _mouse_motion(_main.camera.unproject_position(resident.position+Vector3.UP*1.1))
	_main.camera_base_size += 4.0
	await _frames(40)
	var expected: Dictionary = _main.feedback.pick(_main._hover_position,_main.camera)
	_check("hover_refreshes_after_camera_moves",str(_main.hover_interaction.get("id",""))==str(expected.get("id","")))
	_check("exploration_never_awards_learning_mastery",(root.get_node("State").data.learning as Dictionary).is_empty())

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	Input.parse_input_event(event)
	await _frames(2)

func _click_at(point: Vector2) -> void:
	await _mouse_motion(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event,true)
	await _frames(1)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	root.push_input(event,true)
	await _frames(2)

func _mouse_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(4,4)
	root.push_input(event,true)
	await _frames(3)

func _wait_panel(id: String) -> bool:
	for frame: int in range(1500):
		await _frames(1)
		if str(_main.ui.current_panel)==id and _main.ui.modal.visible: return true
	return false

func _discovered(room_id: String, id: String) -> bool:
	return (root.get_node("State").data.life.discoveries as Dictionary).has(room_id+"/"+id)

func _button(action: String) -> Button:
	for node: Node in _main.ui.panel.find_children("*","Button",true,false):
		if str(node.get_meta("action_id",""))==action: return node as Button
	return null

func _capture_current(id: String) -> void:
	if not capture or DisplayServer.get_name()=="headless": return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var file := output.path_join(id+".png")
	root.get_texture().get_image().save_png(file)
	_report.screenshots.append(file)

func _finish() -> void:
	if finished: return
	finished = true
	_check("production_save_unchanged",_production_signature()==_protected_before)
	_report["passed"] = _report.failures.is_empty()
	_report["complete"] = true
	_report["engine"] = Engine.get_version_info()["string"]
	_report["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	_report["production_save_unchanged"] = _production_signature()==_protected_before
	_report["audit_only"] = audit_only
	_report["native"] = capture
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(_report,"\t"))
	file.close()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	var validation_save := "user://validation-%s.json" % OS.get_process_id()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(validation_save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(validation_save+suffix))
	print("INTERACTION_ACCESS_RESULT ",JSON.stringify({"passed":_report.passed,"rooms":_report.rooms.size(),"checks":_report.checks.size(),"failures":_report.failures}))
	quit(0 if _report.passed else 1)
