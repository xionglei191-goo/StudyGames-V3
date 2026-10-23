extends SceneTree
## Art refresh v1: original semantic playback checks, independent two-size native evidence.
const Content = preload("res://ui/memory_story_content.gd")
const Story = preload("res://ui/memory_story.gd")
var _checks := 0
var _failures: Array[String] = []
var _view: Control
var _cues: Array = []
var _frames: Array = []
var _captures: Array = []
var _production_hash := ""
var _backup_hash := ""
var _capture_enabled := false
var _output := ""
var _capture_directory := ""
var _window := Vector2i(1440,900)
var _variant := "1440x900"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Animation tests require -- --test-harness")
		quit(2)
		return
	_capture_enabled = OS.get_cmdline_user_args().has("--capture")
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--art-window=960x640":
			_window = Vector2i(960,640)
			_variant = "960x640"
	_output = ProjectSettings.globalize_path("res://../docs/verification/art-refresh-v1/native-"+_variant)
	_capture_directory = ProjectSettings.globalize_path("res://../docs/screenshots/art-refresh-v1/native-"+_variant)
	if _capture_enabled: DirAccess.make_dir_recursive_absolute(_capture_directory)
	DirAccess.make_dir_recursive_absolute(_output)
	_production_hash = _hash("user://island-save-v1.json")
	_backup_hash = _hash("user://island-save-v1.json.bak")
	var state := root.get_node_or_null("State")
	_check(state != null and state.has_method("journey_begin_memory"), "Real State autoload compiled")
	root.size = _window
	var host := Control.new()
	host.position = Vector2(70,40)
	host.size = Vector2(1300,820)
	root.add_child(host)
	_view = Story.new()
	host.add_child(_view)
	_view.help_shown.connect(func(value: Dictionary): _cues.append(value.duplicate(true)))
	var kinds: Dictionary = {}
	var all_events := 0
	for small: Dictionary in Content.load_catalog().entries:
		var full := Content.get_entry(str(small.entry_id))
		for beat: Dictionary in full.story_beats:
			var events := Content.animation_events(full,beat.letter_positions,beat.letter_positions,5)
			_check(events.size() == beat.letter_positions.size() and events.size() <= 4,"Action frame budget "+str(beat.beat_id))
			for event: Dictionary in events:
				kinds[str(event.action_kind)] = true
				all_events += 1
	_check(kinds.size() >= 15, "Curriculum actions use distinct semantic structures")
	for word: String in ["hello","nose","book","football"]:
		await _check_real_story(word)
	await _check_controls_and_restore()
	await _check_support_boundaries()
	await _check_reduced_motion()
	_check(_hash("user://island-save-v1.json") == _production_hash,"Production save unchanged")
	_check(_hash("user://island-save-v1.json.bak") == _backup_hash,"Production backup unchanged")
	var report := {"status":"passed" if _failures.is_empty() else "failed","checks":_checks,"failures":_failures,
		"art_revision":Content.STORY_ART_REVISION,"native_window":[_window.x,_window.y],"stage_sha256":_hash("res://ui/memory_story_stage.gd"),"content_sha256":_hash("res://ui/memory_story_content.gd"),"story_words":["hello","nose","book","football"],"action_kinds":kinds.keys(),"curriculum_action_events":all_events,
		"actual_playback_frames":_frames,"captures":_captures,"capture_enabled":_capture_enabled,
		"production_save_unchanged":_hash("user://island-save-v1.json") == _production_hash and _hash("user://island-save-v1.json.bak") == _backup_hash,
		"scope":"Semantic 2D action playback, pause/replay/step/restore, H0/H1/H3 boundaries, reduced-motion keyframes; no mastery or learning-effect claim"}
	var file := FileAccess.open(_output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify({"status":report.status,"checks":_checks,"failures":_failures,"actual_playback_frames":_frames.size(),"captures":_captures.size(),"action_kinds":kinds.size()}))
	host.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _check_real_story(word: String) -> void:
	var entry := _entry_for_word(word)
	_check(not entry.is_empty(),"Source target exists: "+word)
	var exposed_positions: Array = []
	for beat_index: int in range(entry.story_beats.size()):
		_view.setup(entry,{"invocation_id":"animation-test/"+word,"attempt_id":"attempt-1","current_beat":beat_index+1})
		await _layout()
		var player: Control = _view._story_player
		_view._scroll.ensure_control_visible(player)
		await _layout()
		_check(player.allowed_positions.size()<=4,"At most four actual actors: "+word)
		_check(player._textures.size()==player.allowed_positions.size(),"Only visible actors own texture resources: "+word)
		var before_cues := _animation_cues().size()
		_check(str(player.playback_status)=="paused","Opening a story waits for deliberate playback: "+word)
		var records: Dictionary = {}
		var first_poses: Dictionary = {}
		var last_poses: Dictionary = {}
		player.play()
		var frame_count := 0
		while str(player.playback_status)=="playing" and frame_count<1600:
			await process_frame
			frame_count+=1
			var event: Dictionary = player._current_event()
			var position := int(event.actor_position)
			var phase_value := float(player.phase)
			for sample_index: int in range(3):
				var threshold: float = [0.08,0.50,0.94][sample_index]
				var key := "%d-%d" % [position,sample_index]
				if phase_value>=threshold and not records.has(key):
					records[key]=true
					var visual: Dictionary = player.visual_state()
					var evidence := {"word":word,"beat":beat_index+1,"letter_position":position,"sample":sample_index,
						"phase":phase_value,"action":event.action_kind,"visible_letter_positions":player.visible_letter_positions(),
						"actor_poses":_serialize_actors(visual.actors),"prop_position":_v2(visual.prop.position),"prop_openness":visual.prop.openness}
					_frames.append(evidence)
					if sample_index==0: first_poses[position]=visual
					if sample_index==2: last_poses[position]=visual
					await _capture("%s-frame%d-position%d-%d.png" % [word,beat_index+1,position,sample_index])
		_check(str(player.playback_status)=="completed","Actual Tween reaches story page completion: "+word)
		_check(records.size()==player.events.size()*3,"Every action has three real playback samples: "+word)
		await _layout()
		_check(_animation_cues().size()==before_cues+player.events.size(),"Exactly one shown animation cue per played action: "+word)
		for event: Dictionary in player.events:
			var position := int(event.actor_position)
			exposed_positions.append(position)
			_check(bool(event.specialized),"Bespoke action chain: %s/%d" % [word,position])
			if not first_poses.has(position) or not last_poses.has(position):
				continue
			var start: Dictionary = first_poses[position]
			var end: Dictionary = last_poses[position]
			var kind := str(event.action_kind)
			var prop_distance: float = start.prop.position.distance_to(end.prop.position)
			if kind in ["boat_book","kite_book","ball_kick","ball_pass","train_ball","boat_ball","apple_kick","goal_far"]:
				_check(prop_distance>30.0,"Semantic carried object travels: "+kind)
			elif kind=="book_open":
				_check(float(end.prop.openness)-float(start.prop.openness)>0.7,"Book cover actually opens")
			elif kind=="nest_release":
				_check(start.actors["2"].center.distance_to(end.actors["2"].center)>180,"Owl actually travels out of nest")
			elif kind=="nose_lift":
				_check(float(start.actors["3"].center.y)-float(end.actors["3"].center.y)>50,"Nose action lifts the star")
			elif kind=="sneeze_star":
				_check(start.actors["3"].center.distance_to(end.actors["3"].center)>180,"Sneeze sends star into shell")
	_check(exposed_positions.size()==entry.letter_slots.size(),"Repeated letters retain every original position: "+word)
	for p: int in range(1,entry.letter_slots.size()+1):
		_check(exposed_positions.count(p)==1,"Exactly one distinct actor event: %s/%d" % [word,p])

func _check_controls_and_restore() -> void:
	var entry := _entry_for_word("hello")
	_view.setup(entry,{"invocation_id":"animation-controls","attempt_id":"attempt-1"})
	await _layout()
	await _click("播放故事")
	await _ticks(35)
	var player: Control = _view._story_player
	_check(player.phase>0.0 and str(player.playback_status)=="playing","Actual button starts visible movement")
	await _click("暂停")
	var paused_phase := float(player.phase)
	await _ticks(30)
	_check(is_equal_approx(player.phase,paused_phase) and str(player.playback_status)=="paused","Pause freezes motion phase")
	var snapshot: Dictionary = _view.get_resume()
	_check(snapshot.animation_state.step_position==1 and snapshot.animation_state.phase>0,"Resume saves a concrete letter action and phase")
	snapshot.animation_state.playback_status="playing"
	_view.setup(entry,snapshot)
	await _layout()
	player = _view._story_player
	_check(str(player.playback_status)=="paused" and is_equal_approx(player.phase,paused_phase),"Restored playing history opens paused at the same pose")
	await _click("逐步看")
	_check(player.phase>paused_phase and str(player.playback_status)=="paused","Step reveals the next meaningful pose without continuous motion")
	await _click("再看一次")
	await _ticks(10)
	_check(int(player.snapshot().step_position)==1 and player.phase<paused_phase,"Replay starts this page from its first action")
	_view.set_paused(true)
	_check(str(player.playback_status)=="paused","Outer UI focus pause propagates")
	player.play()
	await _ticks(8)
	_view.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(str(player.playback_status)=="paused","Application focus loss pauses story")
	var before := _animation_cues().size()
	_view._scroll.scroll_vertical = 0
	_view.hide()
	player.replay()
	await _ticks(150)
	_check(_animation_cues().size()==before,"Hidden playback cannot fabricate displayed-step exposure")
	player.pause()
	_view.show()
	await _layout()

func _check_support_boundaries() -> void:
	var entry := _entry_for_word("nose")
	_view.setup(entry,{"invocation_id":"animation-hints","attempt_id":"attempt-1"})
	await _layout()
	_view.set_support(3)
	await _layout()
	var player: Control = _view._story_player
	_view._scroll.ensure_control_visible(player)
	await _layout()
	_check(player.visible_letter_positions()==[1,3] and player._textures.keys()==[1,3],"H3 never constructs hidden owl or shell textures")
	var before := _animation_cues().size()
	player.play()
	for i: int in range(310):
		await process_frame
		_check(player.visual_state().actors.keys()==["1","3"],"H3 animation frame does not expose missing actors")
		_check(not str(player._caption.text).contains("猫头鹰") and not str(player._caption.text).contains("蛋壳"),"H3 caption does not disclose hidden neighbors")
	_check(str(player.playback_status)=="completed","H3 safe actions complete")
	for i: int in range(before,_animation_cues().size()):
		var event: Dictionary = _animation_cues()[i]
		_check(event.revealed_letter_positions==[1,3] and int(event.animated_letter_position) in [1,3],"H3 event provenance includes only shown actors")
		_check(str(event.animation_action)=="known_position","H3 avoids answer-leaking full story actions")
	_view._reveal_gap(2)
	await _layout()
	_check(_view._story_player.visible_letter_positions()==[1,2,3],"Explicit reveal adds exactly the requested actor")
	for level: int in [0,1]:
		_view.set_support(level)
		await _layout()
		_check(not is_instance_valid(_view._story_player),"H%d has no animation actor stage" % level)
		_check(not _all_text(_view).contains("nose") and not _all_text(_view).contains("猫头鹰"),"H%d keeps spelling actors hidden" % level)
		_check(_cues[-1].revealed_letter_positions.is_empty(),"H%d exposes no spelling positions" % level)
	var book_entry := _entry_for_word("book")
	_view.setup(book_entry,{"support_level":1})
	await _layout()
	_check(not _all_text(_view).contains("book"),"H1 cannot leak answer from an authored location prompt")

func _check_reduced_motion() -> void:
	_view.setup(_entry_for_word("book"),{"invocation_id":"animation-reduced","attempt_id":"attempt-1"})
	await _layout()
	_view.set_reduced_motion(true)
	var player: Control = _view._story_player
	_view._scroll.ensure_control_visible(player)
	await _layout()
	player.play()
	await _ticks(20)
	_check(is_zero_approx(player.phase),"Reduced motion holds an initial keyframe")
	await _ticks(25)
	_check(is_equal_approx(player.phase,0.55),"Reduced motion switches to a semantic middle keyframe")
	var middle: Dictionary = player.visual_state()
	await _ticks(15)
	_check(is_equal_approx(player.phase,0.55),"Reduced motion does not interpolate between keyframes")
	await _capture("book-reduced-middle.png")
	await _ticks(23)
	_check(is_equal_approx(player.phase,1.0),"Reduced motion shows a final semantic keyframe")
	_check(player.visual_state().prop.position.distance_to(middle.prop.position)>100,"Reduced keyframes preserve carried-book meaning")
	player.pause()
	_view.set_reduced_motion(false)
	_check(str(player.playback_status)=="paused" and not bool(player.reduced_motion),"Motion preference change waits for deliberate replay")

func _entry_for_word(word: String) -> Dictionary:
	for small: Dictionary in Content.list_entries("","",word):
		if str(small.spelling_display)==word:
			return Content.get_entry(str(small.entry_id))
	return {}

func _animation_cues() -> Array:
	return _cues.filter(func(event: Dictionary): return str(event.get("display_event",""))=="story_animation_step")

func _serialize_actors(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in value:
		result[key]={"center":_v2(value[key].center),"rotation":value[key].rotation,"scale":value[key].scale}
	return result

func _v2(value: Vector2) -> Array:
	return [value.x,value.y]

func _click(caption: String) -> void:
	var button := _find_button(_view,caption)
	_check(button!=null,"Button exists: "+caption)
	if button==null: return
	_view._scroll.ensure_control_visible(button)
	await _layout()
	var point: Vector2 = button.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
	await _layout()

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and str(node.text)==caption: return node
	for child: Node in node.get_children():
		var found := _find_button(child,caption)
		if found!=null: return found
	return null

func _all_text(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+=_all_text(child)
	return result

func _layout() -> void:
	await _ticks(6)

func _ticks(count: int) -> void:
	for i: int in range(count): await process_frame

func _capture(filename: String) -> void:
	if not _capture_enabled: return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := _capture_directory+"/"+filename
	_check(picture.save_png(path)==OK,"Rendered capture: "+filename)
	var native_size := picture.get_size()
	var expected := Vector2i(960,600) if _window.x==960 else Vector2i(1440,900)
	_check(native_size==expected,"Native content image dimensions: "+filename)
	_check(DisplayServer.window_get_size()==_window,"Native physical window dimensions: "+filename)
	_captures.append({"file":filename,"sha256":_hash(path),"native_size":[native_size.x,native_size.y],"native_window":[_window.x,_window.y]})

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(condition: bool, label: String) -> void:
	_checks+=1
	if not condition:
		_failures.append(label)
		push_error("FAIL: "+label)
