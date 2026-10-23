extends SceneTree
## Temporary narrow-window supplement. Product files and original tests stay unchanged.
const Content = preload("res://ui/memory_story_content.gd")
const WORDS := ["I'm", "café", "International Children's Day", "rain", "book"]
const IDS := ["occ-54714ff6c169", "occ-c78e37d13730", "occ-6d34310992be", "occ-def745ac2248", "occ-5605ac34c5f2"]
var game: Node3D
var state: Node
var view: Control
var checks: Array = []
var failures: Array[String] = []
var frames: Array = []
var captures: Array = []
var resume_evidence: Dictionary = {}
var rain_evidence: Dictionary = {}
var capture_enabled := false
var output := ""
var capture_directory := ""
var production_hash := ""
var backup_hash := ""
var only_word := -1
var button_targets: Array = []
var window_geometry: Dictionary = {}
const BASE_TEST_SHA256 := "1145d17f055a75358f84984f05ffa792c2f0616da0ff47b99e3fbcf9a446b9a3"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	capture_enabled = OS.get_cmdline_user_args().has("--capture")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only-word="): only_word = argument.trim_prefix("--only-word=").to_int()
	output = ProjectSettings.globalize_path("res://../docs/verification/v0.6.0")
	capture_directory = ProjectSettings.globalize_path("res://../docs/screenshots/v0.6.0/story-narrow")
	DirAccess.make_dir_recursive_absolute(output)
	if capture_enabled: DirAccess.make_dir_recursive_absolute(capture_directory)
	production_hash = _hash("user://island-save-v1.json")
	backup_hash = _hash("user://island-save-v1.json.bak")
	root.size = Vector2i(960,640)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for index: int in range(1200):
		await process_frame
		if game.scene_ready: break
	_check(game.scene_ready,"Production scene ready")
	if not game.scene_ready:
		await _finish()
		return
	state = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-"),"Validation save is isolated")
	state.data = state._default_state()
	game.muted = true
	game.ui.reduced_motion = false
	state.set_preference("reduced_motion",false)
	await game.change_room("village")
	game._close()
	game.journey_phase = "p1_specials_fixture"
	game.player.set_physics_process(false)
	game.player.path.clear()
	game.player.velocity = Vector3.ZERO
	game.living.set_context({"auto_cycle":false,"fixed_day":false,"fixed_weather":false,"guided_prologue":false})
	for index: int in range(WORDS.size()):
		if only_word>=0 and index!=only_word: continue
		await _check_word(index)
		if not failures.is_empty(): break
	await _finish()

func _check_word(index: int) -> void:
	var word: String = WORDS[index]
	var entry := Content.get_entry(IDS[index])
	_check(str(entry.get("spelling_display",""))==word,"Exact source target: "+word)
	if word=="rain":
		game._close()
		game.living.set_weather("light_rain",true)
		game.living.set_context({"story_weather":"light_rain"})
		await _ticks(35)
	game.journey.open_story(IDS[index],false)
	await _ticks(10)
	view = game.journey.current_memory
	_check(is_instance_valid(view) and game.ui.current_panel=="word_story","Production controller opens target: "+word)
	if not is_instance_valid(view): return
	_check(_all_text(view).contains(word),"H5 displays exact punctuation and accent: "+word)
	_check(view.support_level==5,"Target opens with recorded H5: "+word)
	if word=="I'm":
		_check(entry.letter_slots.size()==2 and entry.orthography_events.size()==1,"Apostrophe is a separate surface event, not a third actor")
		_check(str(entry.letter_slots[1].raw_character)=="m" and int(entry.steps[1].surface_position)==3,"I'm retains lowercase m after apostrophe")
	elif word=="café":
		_check(str(entry.letter_slots[3].letter)=="E" and str(entry.letter_slots[3].raw_character)=="é","Accented é retains E anchor and exact source glyph")
	elif index==2:
		_check(entry.story_beats.size()==7 and entry.letter_slots.size()==25,"Long target uses seven pages and 25 separate letter positions")
	elif word=="book":
		_check(entry.letter_slots.size()==4 and str(entry.letter_slots[1].raw_character)=="o" and str(entry.letter_slots[2].raw_character)=="o","Book retains two separate O letter positions")
		_check(int(entry.letter_slots[1].occurrence)==1 and int(entry.letter_slots[2].occurrence)==2,"Repeated O occurrences remain independently numbered")
	var unique_positions: Array = []
	for beat: int in range(entry.story_beats.size()):
		if beat>0: await _click("下一页")
		_check(int(view.current_beat)==beat+1,"Actual next-page input selects page %d: %s" % [beat+1,word])
		_check(_all_text(view).contains("第 %d / %d 页" % [beat+1,entry.story_beats.size()]),"Visible page text agrees with current page: "+word)
		await _play_page(index,beat,unique_positions)
	_check(unique_positions.size()==entry.letter_slots.size(),"Every original letter position actually animated: "+word)
	for position: int in range(1,entry.letter_slots.size()+1):
		_check(unique_positions.has(position),"Played original position %d: %s" % [position,word])
	await _click("看完整字母串")
	_check(_all_text(view).contains("完整拼写："+word),"Explicit reconstruction retains exact full form: "+word)
	if index==0: _check(_all_text(view).contains("I · ' · m"),"Reconstruction shows apostrophe at original surface position")
	if index==1: _check(_all_text(view).contains("c · a · f · é"),"Reconstruction preserves accented é")
	if index==2: _check(_all_text(view).count("[空格]")==2 and _all_text(view).contains("'"),"Long reconstruction retains both spaces and apostrophe")
	await _capture("%s-reconstruction.png" % _slug(index))
	await _check_hidden_boundaries(index,entry)
	await _click("以后再练")
	await _ticks(4)
	_check(game.ui.current_panel=="journey_library","Actual close returns to story library: "+word)

func _play_page(word_index: int, beat: int, unique_positions: Array) -> void:
	var word: String = WORDS[word_index]
	var player: Control = view._story_player
	_check(is_instance_valid(player),"Actual animation stage exists: "+word)
	if not is_instance_valid(player): return
	_check(player.allowed_positions.size()<=4 and player._textures.size()==player.allowed_positions.size(),"Only this page's actors are instantiated: "+word)
	var expected: Array = player.allowed_positions.duplicate()
	var before: int = _animation_cues().size()
	var samples: Dictionary = {}
	var did_restore := false
	var rain_start: Dictionary = {}
	if word=="rain":
		rain_start = {"world_time":game.living.world_time,"performance_time":game.living.performance_time,"drop":_rain_drop(),"status":game.living.get_status()}
		_check(not bool(rain_start.status.world_running) and bool(game.living.context.memory_open),"Production main marks story open and freezes world clock")
		_check(bool(rain_start.status.rain_visible),"Actual outdoor rain remains visible at its frozen pose")
		if capture_enabled: _check(rain_start.drop!=[0.0,0.0,0.0],"Native rain probe is a populated instance transform")
	await _click("播放故事")
	for tick: int in range(1800):
		await process_frame
		var event: Dictionary = player._current_event()
		var position := int(event.actor_position)
		if not unique_positions.has(position): unique_positions.append(position)
		for sample: int in range(2):
			var threshold: float = [0.15,0.80][sample]
			var key := "%d-%d" % [position,sample]
			if float(player.phase)>=threshold and not samples.has(key):
				samples[key] = true
				var visible: Array = player.visible_letter_positions()
				_check(visible==expected,"Visible actor positions agree with page %d: %s" % [beat+1,word])
				_check(str(player._caption.text).contains(str(event.caption)),"Visible action caption agrees with active event: %s/%d" % [word,position])
				var cues := _animation_cues()
				_check(not cues.is_empty() and int(cues[-1].animated_letter_position)==position and cues[-1].revealed_letter_positions==visible,"Authoritative shown-action cue agrees with rendered actors: %s/%d" % [word,position])
				frames.append({"word":word,"page":beat+1,"position":position,"phase":player.phase,"sample":sample,"caption":str(player._caption.text),"action":str(event.action_kind),"positions":visible,"pose":_pose(player),"world_time":game.living.world_time,"performance_time":game.living.performance_time})
				await _capture("%s-page%d-position%d-%d.png" % [_slug(word_index),beat+1,position,sample])
		if word_index==2 and beat==3 and position==14 and float(player.phase)>=0.35 and not did_restore:
			did_restore = true
			await _check_long_restore()
			player = view._story_player
		if str(player.playback_status)!="playing": break
	_check(str(player.playback_status)=="completed","Real Tween completes page %d: %s" % [beat+1,word])
	_check(samples.size()==expected.size()*2,"Two actual motion samples per letter: %s/page%d" % [word,beat+1])
	var cues := _animation_cues()
	_check(cues.size()>=before+expected.size(),"Every played action reaches authoritative cue history: "+word)
	if word=="rain":
		var final_drop := _rain_drop()
		rain_evidence = {"before":rain_start,"after":{"world_time":game.living.world_time,"performance_time":game.living.performance_time,"drop":final_drop,"status":game.living.get_status()},"instruction_captions":frames.filter(func(value: Dictionary): return value.word=="rain").map(func(value: Dictionary): return value.caption)}
		_check(is_equal_approx(float(rain_start.world_time),game.living.world_time),"World clock remains frozen throughout rain lesson")
		_check(rain_start.drop==final_drop,"Actual 3D rain instance remains frozen throughout lesson")
		_check(game.living.performance_time>float(rain_start.performance_time)+1.0,"Teaching performance clock advances while world is frozen")
		_check(_all_text(view).contains("雨；下雨") and _all_text(view).contains("雨滴"),"Rain meaning and teaching action text remain visible during world freeze")

func _check_long_restore() -> void:
	await _click("暂停")
	var player: Control = view._story_player
	var saved: Dictionary = view.get_resume()
	var before_pose := _pose(player)
	var invocation: String = game.journey.memory_invocation
	await _ticks(20)
	_check(is_equal_approx(player.phase,float(saved.animation_state.phase)),"Long page 4 pause freezes exact action phase")
	_check(int(saved.current_beat)==4 and int(saved.animation_state.step_position)==14,"Long pause is genuinely page 4 second action")
	await _capture("long-page4-paused.png")
	await _click("以后再练")
	state.load_state()
	game.journey.open_story(IDS[2],false)
	await _ticks(10)
	view = game.journey.current_memory
	player = view._story_player
	_check(game.journey.memory_invocation==invocation,"Disk reload resumes the same long-story invocation")
	_check(int(view.current_beat)==4 and int(player.snapshot().step_position)==14,"Reopen restores exact page and action position")
	_check(str(player.playback_status)=="paused" and is_equal_approx(player.phase,float(saved.animation_state.phase)),"Reopen stays paused at exact saved phase")
	_check(_pose(player)==before_pose,"Restored actor and prop pose exactly matches saved pose")
	_check(_all_text(view).contains("第 4 / 7 页"),"Restored UI page text agrees with persistent state")
	resume_evidence = {"invocation_id":invocation,"saved":saved.animation_state,"restored":player.snapshot(),"saved_pose":before_pose,"restored_pose":_pose(player),"current_page":view.current_beat,"loaded_from_disk":true}
	await _capture("long-page4-restored.png")
	await _click(str(view._play_button.text))

func _check_hidden_boundaries(index: int, entry: Dictionary) -> void:
	await _click("一起补空格")
	var player: Control = view._story_player
	var allowed: Array = player.visible_letter_positions()
	_check(not _all_text(view).contains(WORDS[index]),"H3 removes full target spelling: "+WORDS[index])
	_check(player._textures.keys()==allowed,"H3 creates only allowed image resources: "+WORDS[index])
	for position: Variant in player.frame_positions:
		if not allowed.has(int(position)):
			_check(not _all_text(view).contains(str(entry.steps[int(position)-1].action)),"H3 hides missing actor's original action: %s/%d" % [WORDS[index],int(position)])
	var before := _animation_cues().size()
	if not allowed.is_empty():
		await _click("播放故事")
		await _ticks(38)
		await _click("暂停")
		var cues := _animation_cues()
		_check(cues.size()>before and cues[-1].revealed_letter_positions==allowed and str(cues[-1].animation_action)=="known_position","H3 playback cue exposes only known positions: "+WORDS[index])
	await _capture("%s-h3.png" % _slug(index))
	for caption: String in ["自己想一想","想想它住哪里"]:
		await _click(caption)
		_check(not is_instance_valid(view._story_player),"No animation stage at "+caption+": "+WORDS[index])
		_check(not _all_text(view).contains(WORDS[index]),"No target spelling at "+caption+": "+WORDS[index])
		var session: Dictionary = _session()
		_check(session.cue_events[-1].revealed_letter_positions.is_empty(),"No invented visual letters at "+caption+": "+WORDS[index])

func _session() -> Dictionary:
	return state.journey_snapshot().memory.sessions[game.journey.memory_invocation]

func _animation_cues() -> Array:
	return _session().cue_events.filter(func(cue: Dictionary): return str(cue.get("display_event",""))=="story_animation_step")

func _pose(player: Control) -> Dictionary:
	var visual: Dictionary = player.visual_state()
	var actors: Dictionary = {}
	for key: String in visual.actors:
		var item: Dictionary = visual.actors[key]
		actors[key] = {"center":[item.center.x,item.center.y],"rotation":item.rotation,"scale":item.scale}
	return {"actors":actors,"prop":{"position":[visual.prop.position.x,visual.prop.position.y],"openness":visual.prop.openness,"rotation":visual.prop.rotation}}

func _rain_drop() -> Array:
	var transform: Transform3D = game.living._rain.multimesh.get_instance_transform(0)
	return [transform.origin.x,transform.origin.y,transform.origin.z]

func _click(caption: String) -> void:
	var button := _find_button(view,caption)
	_check(button!=null,"Actual UI button available: "+caption)
	if button==null: return
	var ancestor: Node = button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _ticks(4)
	var point: Vector2 = button.get_global_rect().get_center()
	var clip: Rect2 = root.get_visible_rect()
	ancestor = button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: clip = clip.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	var minimum: Vector2 = button.get_combined_minimum_size()
	var reachable := button.is_visible_in_tree() and not button.disabled and clip.has_point(point)
	var fully_visible := clip.encloses(button.get_global_rect().grow(-0.5))
	var text_fits := button.size.x+0.5>=minimum.x and button.size.y+0.5>=minimum.y
	_check(reachable and fully_visible and text_fits,"Narrow actual button is reachable, unclipped and fits text: "+caption)
	button_targets.append({"word":str(view.entry.get("spelling_display","")),"page":view.current_beat,"caption":caption,"center":[point.x,point.y],"rect":_rect(button.get_global_rect()),"clip_rect":_rect(clip),"minimum_size":[minimum.x,minimum.y],"reachable":reachable,"fully_visible":fully_visible,"text_fits":text_fits})
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await _ticks(6)
	if is_instance_valid(view) and is_instance_valid(view._story_player):
		view._scroll.ensure_control_visible(view._story_player)
		await _ticks(3)

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and str(node.text)==caption: return node
	for child: Node in node.get_children():
		var result := _find_button(child,caption)
		if result!=null: return result
	return null

func _all_text(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += _all_text(child)
	return result

func _ticks(count: int) -> void:
	for index: int in range(count): await process_frame

func _capture(filename: String) -> void:
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	var path := capture_directory.path_join(filename)
	var picture := root.get_texture().get_image()
	var image_size := picture.get_size()
	var physical_size := DisplayServer.window_get_size()
	var logical_rect: Rect2 = root.get_visible_rect()
	_check(root.size==Vector2i(960,640) and physical_size==Vector2i(960,640),"Requested 960x640 native window is preserved: "+filename)
	_check(image_size==Vector2i(960,600),"16:10 native content is 960x600 inside narrow window: "+filename)
	window_geometry = {"requested_window":[960,640],"root_window_size":[root.size.x,root.size.y],"display_server_window_size":[physical_size.x,physical_size.y],"logical_viewport_rect":_rect(logical_rect),"native_content_image_size":[image_size.x,image_size.y],"project_stretch_mode":ProjectSettings.get_setting("display/window/stretch/mode"),"scope":"Native 960x640 window, project 16:10 content expected at 960x600; no synthetic borders or UI scaling overrides."}
	_check(picture.save_png(path)==OK,"Native rendered capture: "+filename)
	captures.append({"file":filename,"sha256":_hash(path),"image_size":[image_size.x,image_size.y],"native_window_size":[physical_size.x,physical_size.y]})

func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func _slug(index: int) -> String:
	return ["im","cafe","long","rain","book"][index]

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(condition: bool, label: String) -> void:
	checks.append({"check":label,"passed":condition})
	if not condition:
		failures.append(label)
		push_error("SPECIALS_FAIL: "+label)

func _finish() -> void:
	_check(_hash("user://island-save-v1.json")==production_hash and _hash("user://island-save-v1.json.bak")==backup_hash,"Production save and backup unchanged")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"check_details":checks,
		"story_words":WORDS,"actual_playback_frames":frames,"captures":captures,"capture_enabled":capture_enabled,"long_story_resume":resume_evidence,"rain_world_freeze":rain_evidence,
		"validation_variant":"narrow_960x640","base_test_sha256":BASE_TEST_SHA256,"window_geometry":window_geometry,"button_targets":button_targets,
		"production_save_and_backup_unchanged":_hash("user://island-save-v1.json")==production_hash and _hash("user://island-save-v1.json.bak")==backup_hash,
		"scope":"Actual production scene/controller/UI and authoritative save: special orthography, all seven long-word pages, page-four disk resume, actual world/rain freeze with teaching Tween advance, H0/H1/H3 exposure boundaries. Generic source-derived animations, not bespoke recreation or child learning-effect validation."}
	var filename := "story-narrow-native-report.json" if capture_enabled else "story-narrow-headless-report.json"
	var report_directory := output
	if only_word>=0:
		filename = "story-narrow-diagnostic-%s.json" % _slug(only_word)
		report["targeted_word"] = WORDS[only_word]
		report_directory = ProjectSettings.globalize_path("res://../.local/validation")
		DirAccess.make_dir_recursive_absolute(report_directory)
	var file := FileAccess.open(report_directory.path_join(filename),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures,"frames":frames.size(),"captures":captures.size()}))
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
