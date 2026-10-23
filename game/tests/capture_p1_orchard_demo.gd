extends SceneTree
## Native continuous recording of the real main.tscn orchard activity.
## No replacement scene, manual action advancement, fabricated phase or prop motion.

const PROTECTED_PATHS := ["user://island-save-v1.json", "user://island-save-v1.json.bak"]
const EXPECTED_PHASES := ["ready", "walking_pick", "picking", "lifting", "carrying", "walking_place", "placing", "deposited"]
const OUTPUT := "res://../docs/screenshots/v0.6.0/orchard-motion"
const REPORT := "res://../docs/verification/v0.6.0/orchard-motion.json"
var game: Node3D
var state: Node
var activity: Node3D
var checks: Array[Dictionary] = []
var clips: Array[Dictionary] = []
var current_clip: Dictionary = {}
var phases: Array[Dictionary] = []
var contact_events: Array[Dictionary] = []
var protected: Dictionary = {}
var output: String = ProjectSettings.globalize_path(OUTPUT)
var report_path: String = ProjectSettings.globalize_path(REPORT)
var demo_clock_start := 0.0
var capturing := false
var finished := false

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		printerr("Orchard capture requires -- --test-harness")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
	_run.call_deferred()

func _run() -> void:
	create_timer(150).timeout.connect(func(): _check(false,"capture_timeout"); _finish())
	if DisplayServer.get_name() == "headless":
		printerr("Native GPU render required; --check-only may validate this script without a capture.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	protected = _protected_signature()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame: int in range(1800):
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready,"actual_main_scene_ready")
	if not game.scene_ready:
		_finish()
		return
	state = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-") and not str(state.save_path) in PROTECTED_PATHS,"isolated_state_path")
	if not checks[-1].passed:
		_finish()
		return
	game.muted = true
	game.sounds.enabled = false
	game.ui.reduced_motion = false
	root.gui_disable_input = true
	game.set_process_unhandled_input(false)
	for size: Vector2i in [Vector2i(1440,900), Vector2i(960,640)]:
		await _capture_resolution(size)
	_check(_protected_signature() == protected,"production_save_and_backup_unchanged")
	_finish()

func _capture_resolution(size: Vector2i) -> void:
	var id := "%dx%d" % [size.x,size.y]
	if is_instance_valid(game.orchard_activity):
		game._stop_orchard_activity()
	game._close()
	root.size = size
	DisplayServer.window_set_size(size)
	await _frames(4)
	state.data = state._default_state()
	_check(state.save_state(),id+"/fresh_isolated_save")
	for step: String in ["H01","H02","H03","H04"]:
		_check(state.journey_complete_home_step(step),id+"/legal_prerequisite/"+step)
	await game.change_room("landmark_A")
	await _frames(5)
	game.start_orchard_activity()
	await _frames(90)
	_check(is_instance_valid(game.orchard_activity),id+"/real_orchard_setup")
	if not is_instance_valid(game.orchard_activity):
		return
	activity = game.orchard_activity
	var original_rabbit := game.world.get_node_or_null("Rabbit") as Node3D
	_check(is_instance_valid(original_rabbit) and not original_rabbit.is_visible_in_tree(),id+"/original_rabbit_hidden_during_activity")
	_check(activity.actor.is_visible_in_tree() and int(activity.actor.get_status().skinned_meshes)>0,id+"/one_visible_skinned_activity_actor")
	var directory := output.path_join(id)
	DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
	phases = []
	contact_events = []
	demo_clock_start = float(activity.clock)
	current_clip = {"id":id,"requested_size":[size.x,size.y],"native_window_size":[root.size.x,root.size.y],"viewport_rect":_rect(root.get_visible_rect()),"camera_size":float(game.camera.size),"camera_position":_vector(game.camera.global_position),"frames":[],"ui":[],"scene":"res://main.tscn / landmark_A / real orchard_pick.gd","trigger":"start_demonstration()","audio_muted":true,"manual_pose_or_prop_animation":false,"actor_status":activity.actor.get_status(),"character_manifest_sha256":FileAccess.get_sha256("res://assets/characters/storybook_v3/manifest.json")}
	activity.phase_changed.connect(_phase_changed)
	activity.actor.action_contact.connect(_action_contact)
	_phase_changed(str(activity.phase))
	_check(activity.phase == "ready" and activity.apple.get_parent() == activity,id+"/ready_apple_owned_by_branch_scene")
	_check(str(activity.basket.name) == "A_Entrance_Basket",id+"/authored_basket")
	await _capture_still(directory.path_join("01-initial-ui.png"))
	current_clip.ui.append(_ui_bounds("initial"))
	capturing = true
	activity.start_demonstration()
	_check(activity.demonstration and activity.mode == "demonstration_viewed",id+"/starts_real_demonstration")
	var index := 0
	var final_seen_at := -1.0
	# Native update and physics continue normally; one PNG is read every six
	# rendered frames. The CLI uses --fixed-fps 60 only for repeatable video time,
	# never for performance evidence. Actual clock values remain in every row.
	while is_instance_valid(activity) and float(activity.clock) - demo_clock_start < 35.0:
		await RenderingServer.frame_post_draw
		var relative_time := float(activity.clock) - demo_clock_start
		var path := directory.path_join("frames/frame_%04d.png" % index)
		var image := root.get_texture().get_image()
		var saved := image.save_png(path)
		var row := {"index":index,"time":relative_time,"path":path,"save_error":saved,"resolution":[image.get_width(),image.get_height()],"phase":str(activity.phase),"phase_time":float(activity.phase_time),"actor_action":activity.actor.get_action_phase(),"actor_world":_vector(activity.actor.global_position),"apple_world":_vector(activity.apple.global_position),"hand_world":_vector(activity.actor.get_hand_socket_transform().origin),"apple_parent":str(activity.apple.get_parent().name),"discovery_visible":is_instance_valid(activity.discovery_panel)}
		current_clip.frames.append(row)
		index += 1
		if saved != OK:
			_check(false,id+"/save_frame_"+str(index),saved)
			break
		if activity.phase == "deposited" and is_instance_valid(activity.discovery_panel):
			if final_seen_at < 0.0:
				final_seen_at = relative_time
			elif relative_time-final_seen_at >= 0.7:
				break
		await _frames(6)
	capturing = false
	current_clip.duration = float(activity.clock) - demo_clock_start
	current_clip.phases = phases.duplicate(true)
	current_clip.contact_events = contact_events.duplicate(true)
	current_clip.final_activity = activity.get_status()
	current_clip.saved_orchard = state.journey_orchard_snapshot()
	current_clip.frame_count = current_clip.frames.size()
	current_clip.ui.append(_ui_bounds("final"))
	await _capture_still(directory.path_join("02-final-ui.png"))
	var observed: Array = phases.map(func(row: Dictionary): return str(row.phase))
	for expected: String in EXPECTED_PHASES:
		_check(expected in observed,id+"/phase/"+expected,observed)
	_check(observed == EXPECTED_PHASES,id+"/complete_phase_order",observed)
	_check(activity.phase == "deposited" and is_instance_valid(activity.discovery_panel),id+"/full_action_finished_and_discovery_visible")
	_check(activity.apple.get_parent() == activity and activity.apple.global_position.distance_to(activity.basket_target-Vector3.UP*0.15) < 0.01,id+"/apple_settled_in_real_basket")
	_check(state.journey_orchard_snapshot().completion_mode == "demonstration_viewed",id+"/saved_as_demonstration")
	_check(activity.contact_distances.size() == 2,id+"/exactly_pick_and_place_contacts")
	for contact: Dictionary in activity.contact_distances:
		_check(float(contact.distance) <= 0.22,id+"/contact/"+str(contact.action),contact.distance)
	_check(index >= 50,id+"/continuous_frames_recorded",index)
	_check(root.size == size,id+"/requested_native_resolution")
	_check(state.data.coins == 30 and state.data.learning.is_empty(),id+"/no_economy_or_mastery_award")
	_write_json(directory.path_join("capture-report.json"),current_clip)
	clips.append(current_clip.duplicate(true))
	print("ORCHARD_MOTION_CLIP "+JSON.stringify({"id":id,"frames":index,"seconds":current_clip.duration,"phases":observed,"contacts":activity.contact_distances}))
	game._stop_orchard_activity()
	await _frames(3)
	_check(is_instance_valid(original_rabbit) and original_rabbit.is_visible_in_tree(),id+"/activity_exit_restores_original_rabbit")

func _phase_changed(value: String) -> void:
	if not is_instance_valid(activity):
		return
	phases.append({"phase":value,"time":float(activity.clock)-demo_clock_start,"actor_action":activity.actor.get_action_phase()})

func _action_contact(_id: String, action: String, key: String, invocation: int, socket: Transform3D) -> void:
	if not capturing or not is_instance_valid(activity):
		return
	var target: Vector3 = activity.apple_target if action in ["pick","pick_item"] else activity.basket_target
	contact_events.append({"action":action,"time":float(activity.clock)-demo_clock_start,"event_key":key,"invocation":invocation,"socket_world":_vector(socket.origin),"target_world":_vector(target),"socket_to_target_m":socket.origin.distance_to(target),"actor_action":activity.actor.get_action_phase()})

func _ui_bounds(stage: String) -> Dictionary:
	var view := root.get_visible_rect()
	var buttons: Array[Dictionary] = []
	var overlapping: Array = []
	for node: Node in activity.panel_root.find_children("*","Button",true,false):
		var button := node as Button
		if not button.is_visible_in_tree():
			continue
		var rectangle := button.get_global_rect()
		var inside := view.grow(0.5).encloses(rectangle)
		var parent := button.get_parent() as Control
		var parent_inside := parent == null or parent.get_global_rect().grow(0.5).encloses(rectangle)
		var minimum := button.get_combined_minimum_size()
		var fits_text := button.size.x + 0.5 >= minimum.x and button.size.y + 0.5 >= minimum.y
		buttons.append({"text":button.text,"rect":_rect(rectangle),"minimum_size":[minimum.x,minimum.y],"disabled":button.disabled,"inside_viewport":inside,"inside_parent":parent_inside,"fits_minimum_text_size":fits_text})
		_check(inside and parent_inside and fits_text,str(current_clip.id)+"/"+stage+"/button_fits/"+button.text)
	for first: int in range(buttons.size()):
		for second: int in range(first+1,buttons.size()):
			var a: Array = buttons[first].rect
			var b: Array = buttons[second].rect
			if Rect2(a[0],a[1],a[2],a[3]).grow(-0.5).intersects(Rect2(b[0],b[1],b[2],b[3]).grow(-0.5)):
				overlapping.append([buttons[first].text,buttons[second].text])
	_check(overlapping.is_empty(),str(current_clip.id)+"/"+stage+"/buttons_do_not_overlap",overlapping)
	return {"stage":stage,"viewport":_rect(view),"buttons":buttons,"overlap_pairs":overlapping}

func _capture_still(path: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(path) == OK,"still_saved/"+path.get_file())

func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame

func _protected_signature() -> Dictionary:
	var result: Dictionary = {}
	for path: String in PROTECTED_PATHS:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	if not passed:
		printerr("ORCHARD_MOTION_CHECK "+label+" "+str(detail))

func _vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(value,"\t"))
	else:
		_check(false,"write_report/"+path)

func _finish() -> void:
	if finished:
		return
	finished = true
	var failures := checks.filter(func(row: Dictionary): return not bool(row.passed))
	var result := {"status":"PASS" if failures.is_empty() and clips.size() == 2 else "FAIL","checks":checks.size(),"failures":failures,"clips":clips,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info(),"render_timing":"fixed 60 simulation frames per second; captured every six rendered frames; not a performance measurement","protected_production_save_hashes":protected,"production_save_and_backup_unchanged":_protected_signature() == protected,"scope":"actual main.tscn orchard demo at two native resolutions, full action phases, contact geometry and button bounds; native pixel review recorded separately"}
	_write_json(report_path,result)
	print("ORCHARD_MOTION_RESULT "+JSON.stringify({"status":result.status,"checks":checks.size(),"clips":clips.size(),"failures":failures}))
	if is_instance_valid(game):
		game._stop_orchard_activity()
		game._close()
	quit(0 if result.status == "PASS" else 1)
