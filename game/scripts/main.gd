extends Node3D

const WorldScript = preload("res://scripts/world_builder.gd")
const Residents = preload("res://actors/building_resident_catalog.gd")
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/ui.gd")
const FeedbackScript = preload("res://scripts/world_feedback.gd")
const InteractionTargets = preload("res://scripts/interaction_targets.gd")
const SoundScript = preload("res://scripts/feedback_audio.gd")
const FootballScript = preload("res://activities/football_practice.gd")
const HomeCatalog = preload("res://scripts/home_catalog.gd")
const OnlineClient = preload("res://scripts/online_client.gd")
const WebRooms = preload("res://scripts/web_rooms.gd")
const SharedProfile = preload("res://scripts/shared_profile.gd")
const AudioDirectorScript = preload("res://core/audio_director.gd")
const AICompanionBridgeScript = preload("res://core/ai_companion_bridge.gd")
const TactileQuestsScript = preload("res://gameplay/tactile_life_quests.gd")
const CurriculumDirector = preload("res://gameplay/curriculum_quest_director.gd")
const StoryDirector = preload("res://gameplay/unit_storyline_director.gd")
const ParentAIPortal = preload("res://ui_v4/parent_ai_portal.gd")
const ChapterAtlasView = preload("res://ui_v4/chapter_atlas_view.gd")
const FreeGridDecorScript = preload("res://gameplay/free_grid_decor_studio.gd")
const ThematicPlay = preload("res://gameplay/chapter_thematic_play.gd")
const PalaceLociScript = preload("res://gameplay/memory_palace_loci_3d.gd")
const RoleplayDirector = preload("res://gameplay/situational_roleplay.gd")
const WakeMailbox = preload("res://gameplay/morning_wake_mailbox.gd")
var online: Node
var audio_director: Node
var ai_bridge: Node
var tactile_quests: Node3D
var palace_loci: Node3D
var free_decor_studio: Node3D
var creation: Node3D
var _commission_hint_used := false
var _pending_chapter_popup_key := ""
var _thematic_session: Dictionary = {}
var online_config: Dictionary = {}
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var ui: CanvasLayer
var voice: AudioStreamPlayer
var curriculum: Dictionary
var room := "village"
var metadata: Dictionary = {}
var interactions: Array = []
var nearest: Dictionary = {}
var navigation := AStarGrid2D.new()
var nav_ready := false
var loading_room := false
var greetings: Dictionary = {}
var greeting_clock := 0.0
var bubble_world_position := Vector3.ZERO
var muted := false
var quiz_unit := 1
var quiz_index := 0
var quiz_questions: Array = []
var quiz_current: Dictionary = {}
var quiz_hinted := false
var quiz_answered := false
var visit_return: Dictionary = {}
var validation_mode := false
var scene_ready := false
var test_harness := false
var camera_offset := Vector3(18, 25, 24)
const ROOM_LABELS := {"village":"字母岛", "school":"山丘学园 · 校园", "classroom":"阳光教室", "music_room":"音乐教室", "art_room":"美术教室", "science_room":"科学教室", "canteen":"校园餐厅", "playground":"青草操场", "football_field":"绿茵足球场", "home":"家里的客厅", "home_estate":"我的家 · 小院与住宅", "home_hall":"我的家 · 门厅与走廊"}
const NAV_CELL := 0.75
var nav_heights: Dictionary = {}
var navigation_cache: Dictionary = {}
var navigation_generation := 0
var feedback: Node3D
var sounds: Node
var pending_interaction: Dictionary = {}
var hover_interaction: Dictionary = {}
var nearby_interactions: Array[Dictionary] = []
var _nearby_choice := ""
var _nearby_choice_position := Vector3.ZERO
var _hover_pointer_active := false
var _hover_position := Vector2.ZERO
var _interaction_choice_ids: Array[String] = []
var pending_auto := false
var pending_time := 0.0
var journey_target := ""
var journey_auto := false
var conversation_position := Vector3.ZERO
var camera_base_size := 22.0
var _camera_zoom_target := 22.0
var _camera_yaw := 0.0
var _camera_yaw_target := 0.0
var _rmb_dragging := false
var _rmb_drag_dist := 0.0
var _rmb_last_pos := Vector2.ZERO
var _lmb_held := false
var _lmb_hold_time := 0.0
var _lmb_screen_pos := Vector2.ZERO
var step_clock := 0.0
var decor_selected := ""
var decor_preview := false
var decor_enabled := false
var decor_undo: Array = []
var art_draft: Array = []
var football: Node3D
var football_return := Vector3.ZERO
var _closing_for_quit := false
var journey: Node
var living: Node3D
var application_backgrounded := false
var journey_phase := "home"
var capturing_photo := false
var orchard_activity: Node3D
var household: Node

func _ready() -> void:
	_configure_input()
	online_config = OnlineClient.configuration()
	for arg in OS.get_cmdline_user_args():
		if arg == "--validate" or arg.begins_with("--capture-dir="):
			validation_mode = true
		if arg == "--test-harness":
			validation_mode = true
			test_harness = true
	var profile_result := SharedProfile.prepare(State, online_config, OS.get_cmdline_user_args(), validation_mode)
	if not profile_result.ok:
		push_error(str(profile_result.message))
		if OS.has_feature("web"):
			get_tree().paused = true
			JavaScriptBridge.eval("window.AlphabetIslandOnline.startupFailed(" + JSON.stringify(str(profile_result.message)) + ");", true)
		else:
			if DisplayServer.get_name() != "headless":
				OS.alert(str(profile_result.message), "字母岛 · 无法读取角色")
			get_tree().quit(1)
		return
	if profile_result.has("nickname") and not OS.has_feature("web"):
		DisplayServer.window_set_title("字母岛 · " + str(profile_result.nickname))
	if not validation_mode and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_move_to_foreground()
	ui = UIScript.new()
	add_child(ui)
	ui.action.connect(_on_action)
	State.notice.connect(ui.notify)
	State.changed.connect(_refresh)
	State.load_state()
	if bool(profile_result.get("fresh", false)):
		State.set_outfit(str(profile_result.get("outfit", "yellow")))
		if not State.save_state():
			if DisplayServer.get_name() != "headless":
				OS.alert("新角色暂时无法保存，请检查磁盘空间后重新进入。", "字母岛 · 保存失败")
			get_tree().quit(1)
			return
	if OS.has_feature("web_online"):
		print("WEB_PROFILE_STORAGE mounted=", DirAccess.dir_exists_absolute(State.save_path.get_base_dir()), " restored=", FileAccess.file_exists(State.save_path))
	if not online_config.is_empty() and bool(online_config.get("apply_outfit", false)) and str(online_config.get("outfit", "")) in ["yellow", "pink", "blue"]:
		State.set_outfit(str(online_config.outfit))
	if State.shared_web_save:
		# New profiles and one-time browser imports must also reach the canonical store.
		State.save_state()
	muted = not bool(State.data.preferences.voice)
	ui.reduced_motion = bool(State.data.preferences.reduced_motion)
	sounds = SoundScript.new()
	add_child(sounds)
	sounds.enabled = bool(State.data.preferences.effects) and not test_harness
	audio_director = AudioDirectorScript.new()
	add_child(audio_director)
	audio_director.set_enabled(bool(State.data.preferences.effects) and not validation_mode)
	ai_bridge = AICompanionBridgeScript.new()
	add_child(ai_bridge)
	ai_bridge.muted = muted or validation_mode
	ai_bridge.chat_reply_ready.connect(func(_npc_id: String, reply: Dictionary):
		if is_instance_valid(ui) and is_instance_valid(ui.diegetic) and ui.diegetic.visible:
			ui.diegetic.show_ai_reply(reply)
	)
	ai_bridge.speech_encouragement_ready.connect(func(reply: Dictionary):
		State.record_voice_cheer()
		var target_w := str(reply.get("target_text", "")).strip_edges().split(" ")[0].to_lower()
		if not target_w.is_empty():
			State.record_stealth_evidence({"word": target_w, "support_level": 1, "correct": true, "context": "voice_follow_along"})
		if is_instance_valid(audio_director):
			audio_director.play_foley("wardrobe_sparkle")
		if is_instance_valid(ui) and is_instance_valid(ui.diegetic) and ui.diegetic.visible:
			ui.diegetic.show_speech_encouragement(reply)
		else:
			ui.notify("♪ " + str(reply.get("encouragement_zh", "读得真棒！")))
	)
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.stealth_evidence_observed.connect(func(payload: Dictionary): State.record_stealth_evidence(payload))
		bus.tts_speak_requested.connect(func(t: String, l: String, vh: String):
			if is_instance_valid(ai_bridge):
				ai_bridge.speak_text(t, l, vh)
		)
	feedback = FeedbackScript.new()
	add_child(feedback)
	feedback.reduced_motion = ui.reduced_motion
	get_tree().auto_accept_quit = false
	curriculum = JSON.parse_string(FileAccess.get_file_as_string("res://data/curriculum.json"))
	voice = AudioStreamPlayer.new()
	voice.volume_db = -5
	add_child(voice)
	world = WorldScript.new()
	add_child(world)
	player = PlayerScript.new()
	add_child(player)
	player.visual = world.make_character("player")
	player.add_child(player.visual)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 28
	camera.near = 0.1
	camera.far = 360
	add_child(camera)
	player.camera = camera
	player.reduced_motion = ui.reduced_motion
	living = load("res://scripts/living_world.gd").new()
	add_child(living)
	journey = load("res://scripts/journey_controller.gd").new()
	add_child(journey)
	journey.setup(self)
	household = preload("res://scripts/home_controller.gd").new()
	add_child(household)
	household.setup(self)
	free_decor_studio = FreeGridDecorScript.new()
	add_child(free_decor_studio)
	free_decor_studio.setup(self)
	creation = preload("res://gameplay/creation_controller.gd").new()
	add_child(creation)
	creation.setup(self)
	tactile_quests = TactileQuestsScript.new()
	tactile_quests.name = "TactileLifeQuests"
	add_child(tactile_quests)
	palace_loci = PalaceLociScript.new()
	palace_loci.name = "MemoryPalaceLoci3D"
	add_child(palace_loci)
	tactile_quests.apple_picked.connect(func(_kind: String, word_en: String):
		if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
		if is_instance_valid(ai_bridge): ai_bridge.speak_text(word_en, "en", "warm")
		ui.notify("双手捧起了香甜的 %s！快走到果篮边放进去吧 " % word_en)
	)
	tactile_quests.basket_delivered.connect(func(total_deliv: int, word_en: String):
		State.collect_apple()
		State.record_stealth_evidence({"word": word_en.split(" ")[-1], "support_level": 0, "correct": true, "context": "tactile_orchard_basket"})
		if is_instance_valid(audio_director): audio_director.play_foley("wardrobe_sparkle")
		feedback.pickup(player.position, player.position, "apple", "+1 鲜果入篮")
		ui.notify("太棒啦！亲手把第 %d 颗果实放进了藤编果篮！" % total_deliv)
	)
	tactile_quests.item_picked.connect(func(_kind: String, word_en: String, room_id: String):
		if room_id == "landmark_A": return
		if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
		if is_instance_valid(ai_bridge): ai_bridge.speak_text(word_en, "en", "warm")
		ui.notify("双手捧起了 %s！快走到发光工坊分享台放好吧 " % word_en)
	)
	tactile_quests.station_delivered.connect(func(room_id: String, craft_total: int, word_en: String):
		if room_id == "landmark_A": return
		State.record_stealth_evidence({"word": word_en.to_lower(), "support_level": 0, "correct": true, "context": "tactile_station:" + room_id})
		if is_instance_valid(audio_director): audio_director.play_foley("wardrobe_sparkle")
		var badge_text := "+4 叶币" if craft_total <= 3 else " 共创纪念"
		feedback.pickup(player.position, player.position, "leaf", badge_text)
		var active_chap := StoryDirector.active_chapter(State)
		var ckey := str(active_chap.get("chapter_key", ""))
		if not ckey.is_empty() and str(active_chap.get("primary_room", "")) == room_id and State.v4_chapter_stage(ckey) == 1:
			State.advance_v4_chapter(ckey, 2, 0)
			ui.notify("★ 亲手放好了 %s，本章第 2 幕共创完成！快找伙伴点亮终幕纪念牌吧！" % word_en)
		else:
			ui.notify("太棒啦！这里新增了你亲手安放的 %s（累计共创 %d 件）！" % [word_en, craft_total])
	)
	if is_instance_valid(ui.diegetic):
		ui.diegetic.camera = camera
		ui.diegetic.speak_requested.connect(func(t: String, l: String):
			if is_instance_valid(ai_bridge): ai_bridge.speak_text(t, l, "warm")
		)
		ui.diegetic.follow_along_submitted.connect(func(target_text: String, mode: String, rms_peak: float, duration_ms: int):
			if is_instance_valid(ai_bridge):
				ai_bridge.request_speech_encouragement(target_text, mode, rms_peak, duration_ms, ui.diegetic.last_captured_wav_b64)
		)
		ui.diegetic.hint_toggled.connect(func(_npc: String, shown: bool):
			if shown: _commission_hint_used = true
		)
		ui.diegetic.ai_chat_submitted.connect(func(npc_id: String, msg: String):
			var w_dict: Dictionary = State.data.get("wardrobe", {}) if State.data.get("wardrobe") is Dictionary else {}
			var comm := CurriculumDirector.build_daily_commission(State, npc_id)
			ai_bridge.request_npc_chat(npc_id, msg, {
				"outfit": str(State.data.get("outfit", "yellow")),
				"hat": str(w_dict.get("hat", "none")),
				"bag": str(w_dict.get("bag", "none")),
				"held_item": tactile_quests.held_kind if is_instance_valid(tactile_quests) else "",
				"room": room,
				"target_word": str(comm.get("target_word", "apple")),
				"target_meaning_zh": str(comm.get("target_meaning_zh", "苹果"))
			})
		)
	ui.speaker_provider = _dialogue_speaker
	var start_room := "village" if validation_mode or not online_config.is_empty() or State.journey_snapshot().legacy_compatible else "home"
	await change_room(start_room)
	_refresh()
	scene_ready = true
	if not online_config.is_empty():
		online = OnlineClient.new()
		online.name = "OnlineClient"
		add_child(online)
		online.setup(self, online_config)
	if test_harness and OS.get_cmdline_user_args().has("--release-smoke"):
		var smoke: Node = load("res://scripts/release_smoke.gd").new()
		smoke.game = self
		add_child(smoke)
	elif validation_mode and not test_harness:
		_run_validation.call_deferred()
	elif not test_harness and online_config.is_empty():
		if not State.journey_snapshot().legacy_compatible:
			journey.continue_journey()
		else:
			ui.notify("欢迎回来，今天也在小岛上慢慢逛吧。")

func _dialogue_speaker(panel_id: String) -> String:
	if panel_id.begins_with("resident_"): return panel_id
	var local_speakers := {"baker":"npc_bear_uncle","lunch":"npc_bear_uncle","gardener":"npc_rabbit_gardener","sports":"textbook_miss_li","correct":"textbook_miss_li"}
	if local_speakers.has(panel_id): return str(local_speakers[panel_id])
	if panel_id not in ["journey_home","journey_u1","journey_talk","journey_name","journey_p2","friend_memory"]:
		return ""
	if not is_instance_valid(journey) or not is_instance_valid(living): return ""
	for actor_id: String in journey.active_actor_ids:
		var actor: Node3D = living.get_actor(actor_id)
		if is_instance_valid(actor):
			conversation_position = actor.position
			actor.face(player.position)
			player.face(actor.position)
			return actor_id
	return ""

func _configure_input() -> void:
	var keys := {"walk_left":[KEY_A,KEY_LEFT], "walk_right":[KEY_D,KEY_RIGHT], "walk_up":[KEY_W,KEY_UP], "walk_down":[KEY_S,KEY_DOWN], "interact":[KEY_E], "cycle_interaction":[KEY_Q], "map":[KEY_M], "bag":[KEY_B], "journal":[KEY_J]}
	for action_name in keys:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key in keys[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action_name, event)

func change_room(next_room: String, return_id: String = "") -> void:
	if next_room == "home_hall":
		next_room = HomeCatalog.canonical_room(next_room)
		if return_id == "home_gate": return_id = "courtyard_exit"
	if is_instance_valid(creation) and not creation.before_close(): return
	if loading_room:
		return
	if OS.has_feature("web_online") and next_room != "village":
		loading_room = true
		player.locked = true
		var ready := await WebRooms.ensure_room(self, next_room)
		loading_room = false
		player.locked = false
		if not ready:
			ui.notify("这个场景暂时没有加载好，仍留在原处；稍后可以再试。")
			return
	if next_room != "village" and not WorldScript.InteriorScript.available(next_room):
		ui.notify("这个场景暂时无法打开，请检查游戏文件是否完整。")
		return
	if is_instance_valid(journey) and not journey.close_memory(): return
	if is_instance_valid(household): household.cancel_task()
	_stop_orchard_activity()
	_rollback_decoration()
	_stop_football()
	_cancel_navigation()
	loading_room = true
	hover_interaction = {}
	_hover_pointer_active = false
	nearby_interactions.clear()
	nearest = {}
	_nearby_choice = ""
	_interaction_choice_ids.clear()
	navigation_generation += 1
	feedback.highlight({})
	nav_ready = false
	player.locked = true
	player.path.clear()
	voice.stop()
	ui.close_panel()
	ui.bubble_panel.hide()
	if is_instance_valid(ui.diegetic): ui.diegetic.dismiss()
	if next_room != room:
		visit_return[room] = player.position
	if is_instance_valid(creation): creation.prepare_room_change()
	room = next_room
	camera_offset = Vector3(8, 28, 28) if room == "home" else Vector3(18, 25, 24)
	if is_instance_valid(living): living.prepare_room_change()
	metadata = world.build(room)
	if is_instance_valid(household): household.refresh_visuals()
	interactions = metadata.get("interactions", [])
	player.bounds = metadata.get("bounds", Rect2(-24,-20,48,40))
	player.terrain = bool(metadata.get("terrain", false))
	player.safe_position_ready = false
	player.velocity = Vector3.ZERO
	player.position = metadata.get("spawn", Vector3(0,0.1,4)) + Vector3(0,0.1,0)
	if not return_id.is_empty():
		for entry in interactions:
			if entry.id == return_id:
				player.position = entry.get("return_position", entry.position) + Vector3(0,0.15,0)
	camera_base_size = float(metadata.get("camera_size",28.0))*0.78
	if room == "home":
		camera_base_size = 20.5
	_camera_zoom_target = camera_base_size
	_camera_yaw = 0.0
	_camera_yaw_target = 0.0
	_lmb_held = false
	_rmb_dragging = false
	player.pointer_steer = Vector2.ZERO
	player.auto_sprint = false
	camera.size = camera_base_size
	conversation_position = player.position
	feedback.bind_interactions(interactions)
	camera.position = player.position + camera_offset
	camera.look_at(player.position + Vector3(0,0.5,0), Vector3.UP)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.separate_interaction_points(metadata,camera_offset)
	await get_tree().physics_frame
	if is_instance_valid(living):
		living.configure(world,room,{"world_info":metadata,"player":player,"reduced_motion":ui.reduced_motion,"fixed_day":bool(State.data.preferences.get("fixed_day",false)),"guided_prologue":str(State.journey_snapshot().phase) in ["home","prologue"]})
		interactions.append_array(living.get_interactions())
		feedback.bind_interactions(interactions)
	await _build_navigation()
	var start_cell := _nearest_walkable_cell(Vector2i(roundi(player.position.x/NAV_CELL),roundi(player.position.z/NAV_CELL)), player.position)
	if navigation.is_in_boundsv(start_cell):
		player.position = Vector3(start_cell.x*NAV_CELL, float(nav_heights.get(start_cell,player.position.y))+0.15, start_cell.y*NAV_CELL)
	player.safe_position = player.position
	player.safe_position_ready = true
	camera.position = player.position + camera_offset
	camera.look_at(player.position + Vector3(0,0.5,0), Vector3.UP)
	loading_room = false
	player.locked = false
	if is_instance_valid(tactile_quests):
		tactile_quests.attach_to_room(self, room)
	if is_instance_valid(palace_loci):
		palace_loci.attach_to_room(self, room)
	if is_instance_valid(free_decor_studio):
		free_decor_studio.attach_to_room(room)
	if is_instance_valid(audio_director):
		audio_director.apply_room_soundscape(room, str(living.weather_id) if is_instance_valid(living) else "clear")
	if is_instance_valid(journey):
		journey.on_room_ready()
	if is_instance_valid(creation):
		await creation.room_changed()
	_refresh()
	if not ui.reduced_motion:
		ui.fade.color.a = 0.55
		var transition := create_tween()
		transition.tween_property(ui.fade,"color:a",0.0,0.22)
		await transition.finished

func _build_navigation() -> void:
	navigation_generation += 1
	var generation := navigation_generation
	var build_room := room
	nav_ready = false
	if navigation_cache.has(room):
		navigation = navigation_cache[room].grid
		nav_heights = navigation_cache[room].heights
		nav_ready = true
		return
	var bounds: Rect2 = player.bounds
	var cell := NAV_CELL
	navigation = AStarGrid2D.new()
	nav_heights = {}
	var grid_begin := Vector2i(floori(bounds.position.x/cell),floori(bounds.position.y/cell))
	var grid_end := Vector2i(ceili(bounds.end.x/cell),ceili(bounds.end.y/cell))
	navigation.region = Rect2i(grid_begin, grid_end-grid_begin+Vector2i.ONE)
	navigation.cell_size = Vector2(cell, cell)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.update()
	var probe := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.5
	probe.shape = capsule
	probe.collision_mask = 1
	var space := get_world_3d().direct_space_state
	var terrain: bool = bool(metadata.get("terrain", false))
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 4)
	var water_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 8)
	for x in range(navigation.region.position.x, navigation.region.end.x):
		for z in range(navigation.region.position.y, navigation.region.end.y):
			var key := Vector2i(x,z)
			var height := 0.0
			var blocked := not bounds.grow(-0.38).has_point(Vector2(x*cell,z*cell))
			if terrain and not blocked:
				floor_ray.from = Vector3(x*cell, 100, z*cell)
				floor_ray.to = Vector3(x*cell, -50, z*cell)
				var hit := space.intersect_ray(floor_ray)
				blocked = hit.is_empty()
				if not blocked:
					height = hit.position.y
					blocked = (hit.normal as Vector3).dot(Vector3.UP) < cos(player.floor_max_angle)
					water_ray.from = floor_ray.from
					water_ray.to = floor_ray.to
					var water := space.intersect_ray(water_ray)
					if not water.is_empty() and height < float(water.position.y) - 0.002:
						blocked = true
			probe.transform.origin = Vector3(x*cell, height+0.8, z*cell)
			if not blocked:
				blocked = not space.intersect_shape(probe, 1).is_empty()
			navigation.set_point_solid(key, blocked)
			if not blocked:
				nav_heights[key] = height
		if x % 16 == 0:
			await get_tree().process_frame
			if generation != navigation_generation or room != build_room:
				return
	# AStarGrid has no per-edge height filter. Block cells bordering abrupt drops;
	# ordinary ramps remain traversable and the character follows actual physics.
	if terrain:
		var steep: Array[Vector2i] = []
		for key: Vector2i in nav_heights:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbour: Vector2i = key + offset
				if nav_heights.has(neighbour) and absf(float(nav_heights[key])-float(nav_heights[neighbour])) > 0.6:
					steep.append(key)
					break
		for key in steep:
			navigation.set_point_solid(key, true)
	navigation_cache[room] = {"grid":navigation,"heights":nav_heights}
	nav_ready = true

func navigate_to(target: Vector3) -> bool:
	if not nav_ready:
		return false
	var from := Vector2i(roundi(player.position.x/NAV_CELL), roundi(player.position.z/NAV_CELL))
	var to := Vector2i(roundi(target.x/NAV_CELL), roundi(target.z/NAV_CELL))
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(to):
		return false
	if navigation.is_point_solid(from):
		from = _nearest_walkable_cell(from, player.position)
	if navigation.is_point_solid(to):
		to = _nearest_walkable_cell(to, target)
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(to):
		return false
	var route := navigation.get_point_path(from,to)
	player.path.clear()
	for point in route:
		var key := Vector2i(roundi(point.x/NAV_CELL),roundi(point.y/NAV_CELL))
		player.path.append(Vector3(point.x,float(nav_heights.get(key,0.0)),point.y))
	return not route.is_empty()

func _nearest_walkable_cell(origin: Vector2i, point: Vector3) -> Vector2i:
	var best := Vector2i(1000000,1000000)
	var distance := INF
	for dx in range(-4,5):
		for dz in range(-4,5):
			var candidate := origin + Vector2i(dx,dz)
			if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate):
				var candidate_distance := Vector2(candidate.x*NAV_CELL,candidate.y*NAV_CELL).distance_squared_to(Vector2(point.x,point.z))
				if candidate_distance < distance:
					distance = candidate_distance
					best = candidate
	return best

func _process(delta: float) -> void:
	if not is_instance_valid(player) or loading_room or metadata.is_empty() or capturing_photo:
		return
	var studio_open: bool = is_instance_valid(free_decor_studio) and bool(free_decor_studio.active)
	var household_open: bool = is_instance_valid(household) and household.is_active()
	var diegetic_open_now: bool = is_instance_valid(ui.diegetic) and bool(ui.diegetic.visible)
	player.locked = ui.modal.visible or is_instance_valid(football) or is_instance_valid(orchard_activity) or studio_open or household_open
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or player.locked or diegetic_open_now:
		_lmb_held = false
		player.pointer_steer = Vector2.ZERO
	elif _lmb_held:
		_lmb_hold_time += delta
		if _lmb_hold_time >= 0.18:
			var ground_plane := Plane(Vector3.UP, player.position.y)
			var r_orig := camera.project_ray_origin(_lmb_screen_pos)
			var r_dir := camera.project_ray_normal(_lmb_screen_pos)
			var hit_pt: Variant = ground_plane.intersects_ray(r_orig, r_dir)
			if hit_pt is Vector3:
				var gp := hit_pt as Vector3
				var diff := Vector2(gp.x - player.position.x, gp.z - player.position.z)
				if diff.length() > 0.35:
					_cancel_navigation()
					player.pointer_steer = diff.normalized()
				else:
					player.pointer_steer = Vector2.ZERO
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rmb_dragging = false
	if is_instance_valid(living):
		living.set_context({"dialogue_open":ui.modal.visible,"learning_open":ui.current_panel=="question","memory_open":ui.current_panel=="word_story","paused":ui.current_panel=="settings" or (is_instance_valid(orchard_activity) and orchard_activity.paused),"backgrounded":application_backgrounded,"reduced_motion":ui.reduced_motion,"fixed_day":bool(State.data.preferences.get("fixed_day",false)),"guided_prologue":journey_phase in ["home","prologue"],"story_day_phase":"dawn" if ui.current_panel=="journey_u1" and journey.u1_visible_step=="U1-01" else "","active_actor_ids":journey.active_actor_ids if ui.modal.visible else []})
		if household_open: living.set_context({"paused":true})
		living.refresh_interactions(interactions)
		feedback.update_dynamic_targets()
		var weather: Dictionary = living.get_status()
		ui.status.text = "第 %d 天 · %s · %s" % [int(State.data.day),str(weather.get("weather_label","晴")),str(weather.get("phase_label","白天"))]
	var focus := player.position+player.velocity*Vector3(0.16,0,0.16)
	var bounds: Rect2 = player.bounds
	if room not in ["village","school","football_field","playground"]:
		var center := Vector3(bounds.get_center().x,player.position.y,bounds.get_center().y)
		focus = center.lerp(player.position,0.12 if room=="home" else 0.3)
	var desired_size := camera_base_size
	if ui.modal.visible and ui.layout_kind in ["dialogue","lesson"]:
		# Fit the full pair above the dialogue card, including hats and name labels.
		# A fixed zoom clipped the farther character in rooms with deeper staging.
		var screen := get_viewport().get_visible_rect().size
		var stage_top := 36.0
		var stage_bottom := maxf(stage_top+160.0,ui.panel.position.y-24.0)
		var up := camera.global_basis.y
		var right := camera.global_basis.x
		var highest := -INF
		var lowest := INF
		var leftmost := INF
		var rightmost := -INF
		for foot: Vector3 in [player.position,conversation_position]:
			for point: Vector3 in [foot,foot+Vector3.UP*3.35]:
				highest = maxf(highest,point.dot(up))
				lowest = minf(lowest,point.dot(up))
				leftmost = minf(leftmost,point.dot(right))
				rightmost = maxf(rightmost,point.dot(right))
		desired_size = maxf(9.5,(highest-lowest)*screen.y/(stage_bottom-stage_top))
		desired_size = maxf(desired_size,(rightmost-leftmost)*screen.y/(screen.x-96.0))
		focus = (player.position+conversation_position)/2.0
		focus += up*((highest+lowest)/2.0-focus.dot(up))
		focus += up*((stage_top+stage_bottom-screen.y)/2.0)*desired_size/screen.y
		focus -= Vector3.UP*0.5
	if ui.current_panel=="decorate" or ui.current_panel=="purchase":
		focus = Vector3(bounds.get_center().x,-4.3,bounds.get_center().y)
		desired_size = 26
	if studio_open:
		var room_c := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
		focus = free_decor_studio.cursor_pos.lerp(room_c, 0.35) + Vector3(0.0, -1.2, 0.0)
		desired_size = 22.0 if room == "home_estate" else 18.5
	if is_instance_valid(football):
		focus = football.start.lerp(football.goal,0.5)+Vector3(0,-2.8,0)
		desired_size = 17.5
	if is_instance_valid(orchard_activity):
		focus=orchard_activity.camera_focus
		desired_size=orchard_activity.camera_size
	if household_open:
		focus = household.activity.camera_focus
		desired_size = household.activity.camera_size
	if is_instance_valid(journey) and journey.handoff_busy:
		var giver: Node3D = living.get_actor("textbook_peter")
		if giver:
			focus=(giver.position+player.position)/2.0+Vector3(0,-1.5,0)
			desired_size=8.5
	var cam_blend := 1.0 if ui.reduced_motion else 1.0 - exp(-delta * 10.0)
	_camera_yaw = lerpf(_camera_yaw, _camera_yaw_target, cam_blend)
	camera_base_size = lerpf(camera_base_size, _camera_zoom_target, cam_blend)
	var active_cam_offset := camera_offset.rotated(Vector3.UP, _camera_yaw)
	var smoothing := 1.0 if ui.reduced_motion else 1.0-exp(-delta*6.0)
	camera.position = camera.position.lerp(focus+active_cam_offset,smoothing)
	camera.look_at(camera.position-active_cam_offset+Vector3(0,0.5,0),Vector3.UP)
	camera.size = lerpf(camera.size,desired_size,smoothing)
	if not player.path.is_empty():
		feedback.trim_passed_path(player.position)
	if is_instance_valid(orchard_activity) or household_open:
		ui.hide_interaction_prompts()
		ui.bubble_panel.hide()
		return
	greeting_clock -= delta
	step_clock -= delta
	if player.velocity.length()>1.5 and player.is_on_floor() and not player.locked and step_clock<=0:
		sounds.play("step")
		if is_instance_valid(audio_director):
			audio_director.play_footstep_for_room(room)
		step_clock = 0.34
	if ui.bubble_panel.visible:
		ui.bubble_panel.position = camera.unproject_position(bubble_world_position)+Vector2(-100,-106)
	_update_nearby_target()
	for entry: Dictionary in interactions:
		var distance := Vector2(player.position.x,player.position.z).distance_to(Vector2(entry.position.x,entry.position.z))
		if distance<3.5 and not ui.modal.visible and greeting_clock<=0 and not voice.playing and not str(entry.get("greeting","")).is_empty():
			var greeting_id := room+"/"+str(entry.id)
			if Time.get_ticks_msec()-int(greetings.get(greeting_id,-60000))>45000:
				var phrase_key := str(entry.greeting)
				if not curriculum.phrases.has(phrase_key):
					phrase_key = "good_morning"
				var phrase: Dictionary = curriculum.phrases[phrase_key]
				play_phrase(phrase_key)
				if entry.has("resident_id"): world.greet_resident(str(entry.id),player.global_position)
				bubble_world_position = entry.position+Vector3(0,2.4,0)
				ui.say(phrase.en,phrase.zh,camera.unproject_position(bubble_world_position))
				greetings[greeting_id] = Time.get_ticks_msec()
				greeting_clock = 8
	player.look_target = nearest.position if not nearest.is_empty() else Vector3.INF
	var diegetic_open: bool = is_instance_valid(ui.diegetic) and bool(ui.diegetic.visible)
	if not ui.modal.visible and not diegetic_open and not studio_open and not is_instance_valid(football):
		_refresh_hover_target()
		var selected: Dictionary = hover_interaction if not hover_interaction.is_empty() else nearest
		feedback.highlight(selected)
		if not nearest.is_empty() and not camera.is_position_behind(nearest.position):
			var text := str(nearest.label)
			if str(nearest.id)=="orchard":
				text = "采苹果  %d/3" % int(State.data.harvested) if int(State.data.harvested)<3 else "苹果已采完"
			ui.show_prompt(text,camera.unproject_position(nearest.position+Vector3(0,2.4,0)),nearby_interactions.size(),maxi(0,nearby_interactions.find(nearest)))
		else:
			ui.prompt.hide()
			ui.prompt_cycle.hide()
		_update_navigation(delta)
	else:
		ui.hide_interaction_prompts()
		feedback.highlight({})

func _update_nearby_target() -> void:
	nearby_interactions = InteractionTargets.nearby(interactions,player.position)
	if not _nearby_choice.is_empty():
		if Vector2(player.position.x-_nearby_choice_position.x,player.position.z-_nearby_choice_position.z).length()<0.8:
			for entry: Dictionary in nearby_interactions:
				if str(entry.id)==_nearby_choice:
					nearest = entry
					return
		_nearby_choice = ""
	nearest = InteractionTargets.select_nearby(nearby_interactions,player.position,nearest)

func _cycle_nearby_target() -> void:
	_update_nearby_target()
	if nearby_interactions.size()<2: return
	_cancel_navigation()
	_clear_hover_target()
	var index := nearby_interactions.find(nearest)
	nearest = nearby_interactions[(index+1)%nearby_interactions.size()]
	_nearby_choice = str(nearest.id)
	_nearby_choice_position = player.position

func _clear_hover_target() -> void:
	hover_interaction = {}
	_hover_pointer_active = false
	if is_instance_valid(ui): ui.hover_prompt.hide()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _refresh_hover_target() -> void:
	var hovered_control := get_viewport().gui_get_hovered_control()
	if not _hover_pointer_active or (hovered_control!=null and hovered_control.mouse_filter!=Control.MOUSE_FILTER_IGNORE):
		hover_interaction = {}
		ui.hover_prompt.hide()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	hover_interaction = feedback.pick(_hover_position,camera)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not hover_interaction.is_empty() else Input.CURSOR_ARROW)
	if hover_interaction.is_empty():
		ui.hover_prompt.hide()
		return
	var entries := InteractionTargets.colocated(hover_interaction,interactions)
	var text := "这里有 %d 件事 · 点击选择" % entries.size() if entries.size()>1 else str(hover_interaction.label)+"\n点击互动 / 自动走近"
	var height := 2.7 if str(hover_interaction.get("type","")) in InteractionTargets.NPC_TYPES else 0.65
	ui.show_hover_prompt(text,camera.unproject_position(hover_interaction.position+Vector3.UP*height))

func _choose_pointer_target(entry: Dictionary) -> void:
	var choices := InteractionTargets.colocated(entry,interactions)
	_clear_hover_target()
	if choices.size()<=1:
		_request_interaction(entry,true)
		return
	_cancel_navigation()
	_interaction_choice_ids.clear()
	for choice: Dictionary in choices: _interaction_choice_ids.append(str(choice.id))
	ui.show_interaction_choices(choices)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(household) and household.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(creation) and creation.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if loading_room or not is_instance_valid(ui):
		return
	if is_instance_valid(orchard_activity):
		orchard_activity.handle_input(event)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(free_decor_studio) and free_decor_studio.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(ui.diegetic) and ui.diegetic.visible:
			ui.diegetic.dismiss()
		elif ui.modal.visible:
			_request_close()
		elif not player.path.is_empty():
			_cancel_navigation()
		else:
			show_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(football):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			football.aim_from_screen(event.position,camera)
			var slider := ui.panel_box.find_child("AimSlider",true,false) as HSlider
			if slider:
				slider.set_value_no_signal(football.aim)
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
			_shoot_football()
		return
	if ui.modal.visible:
		if (event.is_action_pressed("map") and ui.current_panel=="map") or (event.is_action_pressed("bag") and ui.current_panel=="bag") or (event.is_action_pressed("journal") and ui.current_panel=="journal"):
			_request_close()
		elif ui.current_panel == "v4_thematic_play" and event is InputEventKey and event.pressed and not event.echo:
			var t_slot := -1
			match event.keycode:
				KEY_1, KEY_KP_1: t_slot = 0
				KEY_2, KEY_KP_2: t_slot = 1
				KEY_3, KEY_KP_3: t_slot = 2
				KEY_4, KEY_KP_4: t_slot = 3
				KEY_5, KEY_KP_5: t_slot = 4
			if t_slot >= 0:
				var crow: Node = ui.panel_box.find_child("ThematicChoiceCardsRow", true, false)
				if crow != null and t_slot < crow.get_child_count():
					var cbtn := crow.get_child(t_slot) as Button
					if is_instance_valid(cbtn) and not cbtn.disabled:
						cbtn.pressed.emit()
						get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_clear_hover_target()
		interact_nearest()
	elif event.is_action_pressed("cycle_interaction"):
		_cycle_nearby_target()
	elif event.is_action_pressed("map"):
		show_map()
	elif event.is_action_pressed("bag"):
		show_bag()
	elif event.is_action_pressed("journal"):
		show_journal()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if is_instance_valid(palace_loci):
			palace_loci.open_room_palace_tour(0)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var max_yaw := 0.82 if room in ["village", "school", "football_field", "playground", "home_estate"] else 0.42
		if event.keycode == KEY_BRACKETLEFT:
			_camera_yaw_target = clampf(_camera_yaw_target - 0.22, -max_yaw, max_yaw)
		elif event.keycode == KEY_BRACKETRIGHT:
			_camera_yaw_target = clampf(_camera_yaw_target + 0.22, -max_yaw, max_yaw)
		elif event.keycode in [KEY_HOME, KEY_C]:
			_camera_yaw_target = 0.0
			_camera_zoom_target = 20.5 if room == "home" else float(metadata.get("camera_size", 28.0)) * 0.78
		for key: String in ["walk_left","walk_right","walk_up","walk_down"]:
			if event.is_action_pressed(key):
				_cancel_navigation()
				_clear_hover_target()
				break
	elif event is InputEventMouseMotion:
		_lmb_screen_pos = event.position
		if _rmb_dragging:
			_rmb_drag_dist += event.relative.length()
			var max_yaw := 0.82 if room in ["village", "school", "football_field", "playground", "home_estate"] else 0.42
			_camera_yaw_target = clampf(_camera_yaw_target - event.relative.x * 0.0045, -max_yaw, max_yaw)
			return
		_hover_position = event.position
		_hover_pointer_active = true
		_refresh_hover_target()
	elif event is InputEventMouseButton:
		if not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_lmb_held = false
				player.pointer_steer = Vector2.ZERO
			elif event.button_index == MOUSE_BUTTON_RIGHT and _rmb_dragging:
				_rmb_dragging = false
				if _rmb_drag_dist < 6.0 and not player.path.is_empty():
					_cancel_navigation()
			return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			_camera_zoom_target = maxf(10.0, _camera_zoom_target - 1.5)
			if ui.reduced_motion: camera_base_size = _camera_zoom_target
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			_camera_zoom_target = minf(34.0, _camera_zoom_target + 1.5)
			if ui.reduced_motion: camera_base_size = _camera_zoom_target
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			if event.double_click:
				_camera_yaw_target = 0.0
				_camera_zoom_target = 20.5 if room == "home" else float(metadata.get("camera_size", 28.0)) * 0.78
				_rmb_dragging = false
			else:
				_rmb_dragging = true
				_rmb_drag_dist = 0.0
				_rmb_last_pos = event.position
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var selected: Dictionary = feedback.pick(event.position,camera)
			if not selected.is_empty():
				player.auto_sprint = event.double_click
				_choose_pointer_target(selected)
				return
			_lmb_held = true
			_lmb_hold_time = 0.0
			_lmb_screen_pos = event.position
			_cancel_navigation()
			_clear_hover_target()
			var origin := camera.project_ray_origin(event.position)
			var direction := camera.project_ray_normal(event.position)
			var space := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*400.0,4)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				# Fallback: if player clicked on a tree/fence/prop collider, project straight down to walkable ground
				var prop_q := PhysicsRayQueryParameters3D.create(origin,origin+direction*400.0,5)
				var prop_hit := space.intersect_ray(prop_q)
				if not prop_hit.is_empty():
					var ppos: Vector3 = prop_hit.position
					var down_q := PhysicsRayQueryParameters3D.create(Vector3(ppos.x, ppos.y + 8.0, ppos.z), Vector3(ppos.x, ppos.y - 12.0, ppos.z), 4)
					hit = space.intersect_ray(down_q)
			if not hit.is_empty() and navigate_to(hit.position):
				player.auto_sprint = event.double_click
				feedback.spawn_click_ripple(player.path[-1] if not player.path.is_empty() else hit.position)
				feedback.show_path(player.path)
				ui.navigation("沿着小路漫步中" if not player.auto_sprint else "轻快小跑前往中")



func _refresh() -> void:
	if not is_instance_valid(ui):
		return
	var d: Dictionary = State.data
	ui.status.text = "第 %d 天 · 晴" % int(d.day)
	ui.currency.text = str(d.coins)
	ui.location_label.text = _room_label()
	if not d.quests.greet_done:
		ui.objective.text = "和熊叔打个招呼"
	elif not d.quests.delivery_done:
		ui.objective.text = "为蛋糕坊送苹果  %d / 3" % mini(d.apples,3)
	elif not true in d.decorations_placed.values():
		ui.objective.text = "把喜欢的装饰带回家"
	elif _completed_count()==0:
		ui.objective.text = "去学校，认识新朋友"
	else:
		ui.objective.text = "装扮小屋，继续小镇生活"
	if is_instance_valid(journey):
		journey_phase = str(State.journey_snapshot().phase)
		var wish: String = journey.objective()
		ui.objective.text = wish.split(" · ",true,1)[-1]
	if is_instance_valid(player):
		player.apply_wardrobe(d)
		ui.update_wardrobe(d)
	if is_instance_valid(world) and world.has_method("set_decoration"):
		for id in ["flower_box","picnic","lamp"]:
			if decor_preview and decor_selected==id:
				world.set_decoration(id,decor_enabled)
			else:
				world.set_decoration(id,bool(d.decorations_placed.get(id,false)))

func _close() -> void:
	if is_instance_valid(creation) and not creation.before_close(): return
	if is_instance_valid(journey) and not journey.close_memory(): return
	if is_instance_valid(household): household.cancel_task()
	if is_instance_valid(ui) and is_instance_valid(ui.diegetic):
		ui.diegetic.dismiss()
	if is_instance_valid(free_decor_studio) and free_decor_studio.active:
		free_decor_studio.close_studio()
	_stop_orchard_activity()
	_rollback_decoration()
	_stop_football()

	_cancel_navigation()
	_clear_hover_target()

	ui.close_panel()
	voice.stop()
	player.locked = false
	quiz_current = {}

func _completed_count() -> int:
	var count := 0
	for done in State.data.completed_units.values():
		if done:
			count += 1
	return count

func play_phrase(id: String) -> void:
	if muted or not curriculum.get("phrases",{}).has(id):
		return
	voice.stop()
	var path: String = curriculum.phrases[id].audio
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		voice.stream = stream
		voice.play()

func show_welcome() -> void:
	ui.show_panel("welcome", "早上好，小岛的新邻居。", "字母岛   /   我的第一天", "今天，先去和熊叔打个招呼。\n帮蛋糕坊采苹果，去学校认识朋友，\n再带一份喜欢的装饰回家。", [{"label":"开始今天的生活", "id":"close", "primary":true},{"label":"看看小镇地图", "id":"map"}], "进度会自动保存。你可以随时闲逛、换装和回家。")

func _room_label() -> String:
	return str(ROOM_LABELS.get(room, metadata.get("room_label", "字母岛")))

func show_place() -> void:
	if is_instance_valid(household) and household.handles_room():
		household.show_overview()
		return
	var plan: Dictionary = world.room_plan(room)
	var title := str(plan.get("name", _room_label()))
	var body := str(plan.get("theme", "在这里慢慢走走，认识邻居和周围的物件。"))
	if room == "school":
		ui.show_panel("place", "欢迎来到山丘学园", "校园   /   入校导览", "从校门沿小路进入校园。\n普通教室、音乐教室、美术教室、科学教室、餐厅、操场和足球场都有自己的入口。\n走到门前按 E，进入后再慢慢探索。", [{"label":"看看校园导览","id":"map","primary":true},{"label":"继续逛校园","id":"close"}])
		return
	body += "\n\n先逛一圈，看看这里的五个固定位置。"
	var actions: Array = [{"label":"看看这里的五处回忆","id":"map","primary":true},{"label":"继续逛逛","id":"close"}]
	var activity := _room_activity()
	if not activity.is_empty():
		actions.push_front({"label":_activity_label(activity),"id":"activity:"+activity,"primary":true})
	ui.show_panel("place",title,str(plan.get("english_word",""))+" / 小岛生活",body,actions)

func show_memory(sequence: int) -> void:
	if is_instance_valid(household) and household.handles_room():
		household.show_memory(sequence)
		return
	var plan: Dictionary = world.room_plan(room)
	var anchors: Array = plan.get("anchors", [])
	if sequence < 1 or sequence > anchors.size():
		show_place()
		return
	var anchor: Dictionary = anchors[sequence-1]
	var content: Dictionary = preload("res://ui/memory_card_content.gd").build(plan, anchor)
	State.discover(room,sequence)
	var actions: Array = []
	var activity := _room_activity()
	if not activity.is_empty():
		actions.append({"label":str({"art":"画一画", "music":"奏一奏", "science":"试一试", "football":"踢一踢"}.get(activity, "试一试")),"id":"activity:"+activity,"primary":true})
	if room == "landmark_A" and sequence == 2:
		actions.append({"label":"摘苹果","id":"harvest","primary":true})
	elif room == "landmark_C" and sequence in [1,3,5]:
		actions.append({"label":"看订单","id":"talk_baker","primary":true})
	elif room == "classroom":
		actions.append({"label":"开始上课","id":"lessons","primary":true})
	elif room == "home" and sequence == 4:
		actions.append({"label":"睡到明天","id":"next_day","primary":true})
	elif room == "home" and sequence == 2:
		actions.append({"label":"装扮我的小屋","id":"decorate","primary":true})
	var p_eid := str(content.get("palace_entry_id", "")).strip_edges()
	var p_word := str(content.get("palace_word", "")).strip_edges()
	if not p_eid.is_empty() and not p_word.is_empty():
		actions.append({"label":"立体书记词 · " + p_word, "id":"open_palace:" + p_eid, "icon":"book", "primary":actions.is_empty()})
	if not PalaceLociScript.stories_for_room(room).is_empty():
		actions.append({"label":"本屋宫殿角落展台", "id":"v5_palace_tour:0", "icon":"compass"})
	actions.append({"label":"退出","id":"close"})
	var visited := 0
	for index: int in range(1,6):
		if State.data.life.discoveries.has("%s/memory_%02d" % [room,index]):
			visited += 1
	ui.show_memory_card(self,str(anchor.get("label","小岛回忆")),"%s · 已发现 %d / 5" % [_room_label(),visited],content,actions)

func interact_nearest() -> void:
	_update_nearby_target()
	if not nearest.is_empty():
		interact_id(str(nearest.id))

func interact_id(id: String) -> void:
	if is_instance_valid(creation) and creation.handle_action(id): return
	player.path.clear()
	pending_interaction = {}
	feedback.clear_path()
	ui.navigation("")
	for entry: Dictionary in interactions:
		if str(entry.id)==id:
			conversation_position = entry.position
			player.face(entry.position)
			break
	player.gesture("wave")
	if is_instance_valid(journey) and journey.intercept_interaction(id):
		return
	for entry: Dictionary in interactions:
		if str(entry.id) == id and entry.has("resident_id"):
			world.greet_resident(id,player.global_position)
			show_building_resident(str(entry.resident_id))
			return
	if id.begins_with("landmark_"):
		if not WorldScript.InteriorScript.available(id):
			ui.notify("这里正在布置，先在岛上逛一逛吧。")
			return
		await change_room(id)
		return
	if id.begins_with("memory_"):
		show_memory(int(id.trim_prefix("memory_")))
		return
	for entry in interactions:
		if entry.id == id and entry.has("destination"):
			await change_room(str(entry.destination), str(entry.get("return_id", "")))
			return
	match id:
		"baker", "bakery": show_baker()
		"gardener":
			play_phrase("hello")
			if not validation_mode and is_instance_valid(ui.diegetic):
				if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
				ui.diegetic.open_conversation({
					"npc_id": "npc_rabbit_gardener",
					"speaker": "兔兔园丁 · A 苹果果园",
					"en": "Hello! Sweet apples are ripe on the grass — pick one in your hands and bring it to my basket!",
					"zh": "你好呀！香甜的 3D 红苹果已经掉落在草地上了，走过去双手捧起来放进发光藤篮，或者接一个今日单元小委托吧！",
					"world_pos": conversation_position,
					"auto_speak": false,
					"actions": [
						{"label": "★ 今日单元小委托", "id": "v4_commission:npc_rabbit_gardener", "primary": true},
						{"label": "◈ 情境三轮英语对话", "id": "v5_roleplay_start:" + RoleplayDirector.scenario_id_for_context(room, "gardener")},
						{"label": "· 听听 apple", "id": "audio:apple"},
						{"label": "· 摘一颗苹果", "id": "navigate:orchard"},
						{"label": "继续逛果园", "id": "close"}
					]
				})
			else:
				ui.show_panel("gardener","兔兔的果园","邻居   /   苹果屋","Hello!  欢迎你来果园。\n树上的苹果今天熟了，采三颗送给熊叔吧。\n累了也可以来我的花园坐一会儿。",[{"label":"听听 apple 的读音","id":"audio:apple","primary":true},{"label":"去采苹果","id":"navigate:orchard"}])
		"orchard": show_orchard()
		"school_gate": await change_room("school")
		"home_gate": await change_room("home_estate")
		"village_exit":
			var door := "school_gate" if room=="school" else (room if room.begins_with("landmark_") else "home_gate")
			await change_room("village", door)
		"teacher":
			if not validation_mode and is_instance_valid(ui.diegetic):
				play_phrase("good_morning")
				if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
				var chap := StoryDirector.active_chapter(State)
				ui.diegetic.open_conversation({
					"npc_id": "textbook_miss_li",
					"speaker": "李老师 · 阳光故事圈",
					"en": "Good morning! No exams here — let's share today's cozy story \"%s\" or try a storybook sticker together!" % str(chap.get("source_title", "Hello")),
					"zh": "早上好呀！阳光教室没有考试题板，只有温馨故事会！今天想开启「%s · U%d %s」三幕共创，还是贴一张单元手账贴纸？" % [str(chap.get("book_title", "三年级上册")), int(chap.get("unit_number", 1)), str(chap.get("event_title", "小岛故事"))],
					"world_pos": conversation_position,
					"auto_speak": false,
					"actions": [
						{"label": "★ 开启本章三幕共创", "id": "v4_chap_open_here", "primary": true},
						{"label": "◈ 情境三轮英语对话", "id": "v5_roleplay_start:classroom"},
						{"label": "· 贴一张单元手账贴纸", "id": "v4_commission:textbook_miss_li"},
						{"label": "· 八册 81 章故事画册", "id": "v4_chapter_atlas"},
						{"label": "· Good morning!", "id": "audio:good_morning"},
						{"label": "先在教室逛逛", "id": "close"}
					]
				})
			else:
				show_lessons()
		"lunch":
			play_phrase("milk")
			if not validation_mode and is_instance_valid(ui.diegetic):
				if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
				ui.diegetic.open_conversation({
					"npc_id": "npc_bear_uncle",
					"speaker": "食堂主厨 · 暖香餐台",
					"en": "Welcome to our sunny canteen! Would you like warm milk, soft bread, or a sweet cake? You can also carry tray items on the floor!",
					"zh": "欢迎来到校园阳光餐厅！点选食物听听英文发音，或者走过去双手捧起地面上的牛奶盒和面包送到餐盘分享台吧！",
					"world_pos": conversation_position,
					"auto_speak": false,
					"actions": [
						{"label": "★ 情境点餐三轮对话", "id": "v5_roleplay_start:canteen", "primary": true},
						{"label": "· 牛奶 milk", "id": "audio:milk"},
						{"label": "· 面包 bread", "id": "audio:bread"},
						{"label": "· 蛋糕 cake", "id": "audio:cake"},
						{"label": "· 谢谢 Thank you!", "id": "audio:thank_you"},
						{"label": "去端餐盘好物", "id": "close"}
					]
				})
			else:
				ui.show_panel("lunch","今天想吃点什么？","校园食堂   /   生活英语","和食堂阿姨一起认识食物。\n点选食物，就能听到它的英文名字。",[{"label":"牛奶  milk","id":"audio:milk","primary":true},{"label":"面包  bread","id":"audio:bread"},{"label":"蛋糕  cake","id":"audio:cake"},{"label":"谢谢阿姨  Thank you.","id":"audio:thank_you"}],"这里是自由体验，不计为独立掌握。")
		"sports":
			play_phrase("how_old")
			if not validation_mode and is_instance_valid(ui.diegetic):
				if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
				ui.diegetic.open_conversation({
					"npc_id": "textbook_peter",
					"speaker": "操场伙伴 · 青草运动角",
					"en": "Hi friend! How old are you? Come pick up a colorful ball on the grass and play with us!",
					"zh": "嗨！小伙伴想认识你！你可以听听示范、点气泡上的「♪ 跟读试试」大胆开口，也可以去草地上双手捧起彩球放进收纳台！",
					"world_pos": conversation_position,
					"auto_speak": false,
					"actions": [
						{"label": "★ 操场运动三轮对话", "id": "v5_roleplay_start:playground", "primary": true},
						{"label": "· 听听 I'm nine.", "id": "audio:im_nine"},
						{"label": "· 本章生活故事", "id": "v4_chap_open_here"},
						{"label": "· 今日手账小委托", "id": "v4_commission:textbook_peter"},
						{"label": "去草地捡球玩", "id": "close"}
					]
				})
			else:
				ui.show_panel("sports","操场上认识新朋友","课间   /   自由对话","How old are you?\n小伙伴想知道你几岁了。听一听示范，再试着说自己的年龄。",[{"label":"听听 I'm nine.","id":"audio:im_nine","primary":true},{"label":"回教室看看课程","id":"navigate:school_exit"}],"第一版不录音、不评判口语；听过或跟读不记为独立掌握。")
		"bed":
			if not validation_mode and is_instance_valid(ui.diegetic):
				if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
				ui.diegetic.open_conversation({
					"npc_id": "npc_bear_uncle",
					"speaker": "松软小床 · 晚安时光",
					"en": "Good night, little explorer! Sleep tight — tomorrow fresh apples and sunny adventures await!",
					"zh": "今天也是充实又温暖的一天！睡一觉，明天的果园苹果又会熟透啦，所有装饰、叶币和成长手账都会稳稳保留。",
					"world_pos": conversation_position,
					"show_zh_immediately": true,
					"auto_speak": true,
					"actions": [
						{"label": "☆ 晚安，睡到明天", "id": "next_day", "primary": true},
						{"label": " 再玩一会儿", "id": "close"}
					]
				})
			else:
				ui.show_panel("bed","今天也是充实的一天","我的小屋   /   休息","睡一觉，明天的苹果就成熟了。\n小屋、装饰、叶币和学习记录都会保留。",[{"label":"睡到明天","id":"next_day","primary":true},{"label":"再玩一会儿","id":"close"}])
		"decorate":
			if not validation_mode and is_instance_valid(free_decor_studio):
				await free_decor_studio.open_studio()
			else:
				await show_decorate()
		"host":
			var activity := _room_activity()
			if not activity.is_empty():
				start_activity(activity)
			elif not validation_mode and is_instance_valid(ui.diegetic) and room.begins_with("landmark_"):
				var letter_code := room.trim_prefix("landmark_")
				var spec: Dictionary = TactileQuestsScript.ROOM_QUEST_SPECS.get(room, {})
				var word_en := str(spec.get("word", letter_code))
				var st_name := str(spec.get("station", "手作分享台"))
				if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
				ui.diegetic.open_conversation({
					"npc_id": "npc_bear_uncle",
					"speaker": "%s 馆主理人 · %s" % [letter_code, st_name],
					"en": "Welcome to Landmark %s! \"%s\" starts with %s! Pick up the 3D %s items nearby and place them on our %s!" % [letter_code, word_en, letter_code, word_en.to_lower(), st_name],
					"zh": "欢迎来到 %s 字母馆！在房间里走近发光的 3D「%s」就能双手捧起，送到「%s」会留下永久小岛手作纪念哦！" % [letter_code, word_en, st_name],
					"world_pos": conversation_position,
					"show_zh_immediately": true,
					"auto_speak": true,
					"actions": [
						{"label": "★ 收集 %s 字母发现卡" % letter_code, "id": "journey:inspect:" + letter_code, "primary": true},
						{"label": "◈ 情境三轮英语对话", "id": "v5_roleplay_start:" + RoleplayDirector.scenario_id_for_context(room, "host")},
						{"label": "· 本屋记忆宫殿角落", "id": "v5_palace_tour:0"},
						{"label": "· 本章三幕共创", "id": "v4_chap_open_here"},
						{"label": "· 今日手账小委托", "id": "v4_commission:npc_bear_uncle"},
						{"label": "去捧起 3D 好物", "id": "close"}
					]
				})
			else:
				show_place()

func show_building_resident(resident_id: String) -> void:
	var resident := Residents.profile(resident_id)
	if resident.is_empty(): return
	var actions: Array = []
	var activity := _room_activity()
	if not activity.is_empty(): actions.append({"label":_activity_label(activity),"id":"activity:"+activity,"primary":true})
	if room == "landmark_A":
		actions.append({"label":"去采苹果","id":"navigate:orchard","primary":true})
	elif room == "landmark_C":
		actions.append({"label":"跟米洛学点心与包装", "id":"creation:teach"})
		actions.append({"label":"制作苹果蛋糕","id":"craft","primary":true,"disabled":int(State.data.apples)<3})
		actions.append({"label":"售出一份蛋糕","id":"sell","disabled":int(State.data.cakes)<1})
	elif room == "landmark_F":
		actions.append({"label":"跟花婆婆学花艺", "id":"creation:teach"})
	elif room == "canteen":
		for word: String in ["milk","bread","cake"]: actions.append({"label":"听听 "+word,"id":"audio:"+word})
	if room.begins_with("landmark_"):
		if room in ["landmark_A","landmark_C","landmark_F"]:
			actions.append({"label":"材料采集与生活工坊", "id":"creation:materials"})
		var letter := room.trim_prefix("landmark_")
		actions.append({"label":"收集 %s 字母发现卡" % letter,"id":"journey:inspect:"+letter})
	actions.append({"label":"◈ 情境三轮英语对话","id":"v5_roleplay_start:" + RoleplayDirector.scenario_id_for_context(room, resident_id)})
	if not PalaceLociScript.stories_for_room(room).is_empty():
		actions.append({"label":"★ 本屋记忆宫殿角落","id":"v5_palace_tour:0"})
	actions.append({"label":"今日单元小委托","id":"v4_commission:"+resident_id})
	actions.append({"label":"本章生活故事","id":"v4_chap_open_here"})
	actions.append({"label":"继续逛逛","id":"close"})
	var en := "Hello! I'm %s. Welcome! Let's explore together." % str(resident.name_en)
	var zh := "你好，我是%s，这里的%s。欢迎来到%s！" % [str(resident.name),str(resident.role),str(resident.building_name)]
	var title := "%s · %s" % [str(resident.name),str(resident.role)]
	if not validation_mode and is_instance_valid(ui.diegetic):
		ui.diegetic.open_conversation({"npc_id":resident_id,"speaker":title,"en":en,"zh":zh,"world_pos":conversation_position,"auto_speak":true,"actions":actions})
	else:
		ui.show_panel(resident_id,title,str(resident.building_name),en+"\n"+zh,actions)

func show_baker(play_greeting: bool = true) -> void:
	if room == "landmark_C":
		show_building_resident("resident_c")
		return
	var d: Dictionary = State.data
	if play_greeting:
		play_phrase("good_morning")
	if not validation_mode and is_instance_valid(ui.diegetic):
		if is_instance_valid(audio_director): audio_director.play_foley("bubble_pop")
		if not d.quests.greet_done:
			ui.diegetic.open_conversation({
				"npc_id": "npc_bear_uncle",
				"speaker": "熊叔 · 暖香蛋糕坊",
				"en": "Good morning! Welcome to Alphabet Island! Would you like to help me bake an apple cake today?",
				"zh": "早上好！欢迎搬来晨光村！今天愿意帮熊叔一起烤一份香喷喷的苹果蛋糕吗？",
				"world_pos": conversation_position,
				"auto_speak": false,
				"actions": [
					{"label": "Hello! 很高兴认识你", "id": "greet", "primary": true},
					{"label": "★ 今日单元小委托", "id": "v4_commission:npc_bear_uncle"},
					{"label": "♪ 再听一遍", "id": "audio:good_morning"},
					{"label": "先逛一逛", "id": "close"}
				]
			})
		elif not d.quests.delivery_done:
			ui.diegetic.open_conversation({
				"npc_id": "npc_bear_uncle",
				"speaker": "熊叔 · 暖香蛋糕坊",
				"en": "Could you bring 3 sweet apples from the orchard? Let's bake our first cake together! (%d / 3)" % int(d.apples),
				"zh": "帮我从果园带回 3 颗红苹果吧，送到后我们一起烤第一份蛋糕！（当前背包：%d 颗）" % int(d.apples),
				"world_pos": conversation_position,
				"auto_speak": false,
				"actions": [
					{"label": "· 交给熊叔 3 颗苹果", "id": "deliver", "primary": true, "disabled": d.apples < 3},
					{"label": "· 带我去苹果树", "id": "navigate:orchard"},
					{"label": "★ 今日单元小委托", "id": "v4_commission:npc_bear_uncle"},
					{"label": "先聊到这里", "id": "close"}
				]
			})
		else:
			ui.diegetic.open_conversation({
				"npc_id": "npc_bear_uncle",
				"speaker": "熊叔 · 暖香蛋糕坊",
				"en": "Our bakery is open and warm! Bake an apple cake or pick a cozy storybook sticker with me! (Apples: %d · Cakes: %d)" % [int(d.apples), int(d.cakes)],
				"zh": "蛋糕坊热气腾腾开张啦！3 颗苹果烤 1 份蛋糕，售出可得 15 叶币；也可以接今日教材手账小委托！",
				"world_pos": conversation_position,
				"auto_speak": false,
				"actions": [
					{"label": "★ 制作苹果蛋糕", "id": "craft", "primary": true, "disabled": d.apples < 3},
					{"label": "· 售出一份蛋糕", "id": "sell", "disabled": d.cakes < 1},
					{"label": "◈ 点心坊三轮英语对话", "id": "v5_roleplay_start:bakery"},
					{"label": "· 今日单元小委托", "id": "v4_commission:npc_bear_uncle", "primary": d.apples < 3},
					{"label": "· 挑选家园装饰", "id": "shop"},
					{"label": "先聊到这里", "id": "close"}
				]
			})
		return
	if not d.quests.greet_done:
		ui.show_panel("baker","Good morning!","熊叔   /   蛋糕烘焙坊","早上好！我是熊叔，欢迎你搬来晨光村。\n我正在准备苹果蛋糕，你愿意来帮忙吗？",[{"label":"Hello! 很高兴认识你","id":"greet","primary":true},{"label":"再听一遍","id":"audio:good_morning"}],"先和邻居熟悉起来。听到问候不计为学习过关。")
	elif not d.quests.delivery_done:
		ui.show_panel("baker","一份苹果味的欢迎礼","熊叔的委托   /   苹果屋 → 蛋糕坊","帮我从果园带来 3 颗苹果吧。\n送到之后，我们一起做第一份蛋糕。\n现在背包里有 %d 颗苹果。" % d.apples,[{"label":"交给熊叔 3 颗苹果","id":"deliver","primary":true,"disabled":d.apples<3},{"label":"带我去苹果树","id":"navigate:orchard"},{"label":"听听 apple","id":"audio:apple"}])
	else:
		ui.show_panel("baker","蛋糕坊开张啦","熊叔   /   小镇经营","用 3 颗苹果做一份蛋糕，招待小镇的客人。\n背包：%d 颗苹果 · %d 份蛋糕\n制作：3 苹果 → 1 蛋糕   /   售出：1 蛋糕 → 15 叶币" % [d.apples,d.cakes],[{"label":"制作苹果蛋糕","id":"craft","primary":true,"disabled":d.apples<3},{"label":"售出一份蛋糕","id":"sell","disabled":d.cakes<1},{"label":"挑选家园装饰","id":"shop"},{"label":"听听 cake","id":"audio:cake"}])

func show_orchard() -> void:
	_collect_apple()



func show_bag() -> void:
	if not _prepare_screen(): return
	ui.show_inventory(State.data)



func show_shop() -> void:
	if not _prepare_screen(): return
	ui.show_shop(State.data)



func show_decorate() -> void:
	if not _prepare_screen(): return
	if room!="home":
		await change_room("home")
	ui.show_decoration_tray(State.data,decor_selected,decor_preview,decor_enabled,not decor_undo.is_empty())



func show_lessons() -> void:
	var actions: Array = []
	for unit in curriculum.units:
		var number: int = int(unit.number)
		var complete: bool = bool(State.data.completed_units.get(str(number),false))
		actions.append({"label":"%d. %s%s" % [number,str(unit.title),"  ✓" if complete else ""],"id":"unit:%d" % number,"primary":number==State.data.unit,"disabled":number>State.data.unit})
	actions.append({"label":"看看回忆册","id":"journal"})
	ui.show_panel("lessons","今天，认识一个新朋友","阳光教室   /   湘少版三年级上册","从打招呼开始，再介绍名字和年龄。\n每一课有 3 个小情境。需要时可以听一遍、看中文。\n完成课程会解锁下一课，也能得到 15 叶币。",actions,"提示后答对也能推进故事；回忆册会如实区分有提示和独立答对。")

func start_unit(number: int) -> void:
	if number<1 or number>int(State.data.unit):
		ui.notify("先完成前面的一课，再认识新的表达。")
		return
	quiz_unit = number
	quiz_index = 0
	quiz_questions = []
	for question in curriculum.questions:
		if int(question.unit)==number:
			quiz_questions.append(question)
	_next_question()

func _next_question() -> void:
	if quiz_index>=quiz_questions.size():
		var already_complete: bool = bool(State.data.completed_units.get(str(quiz_unit),false))
		var saved: bool = State.finish_unit(quiz_unit)
		if not saved and not already_complete:
			ui.show_panel("lesson_save_failed","这次进度还没有保存成功","请保留游戏窗口","可以重试保存。保存成功后才会发放本课奖励并解锁下一课。",[{"label":"重试保存本课","id":"retry_finish","primary":true},{"label":"暂时返回","id":"close"}])
			return
		quiz_current = {}
		ui.show_panel("lesson_done","今天又多认识了一点点","课程完成","把刚才的问候带到小镇生活里吧。\n下一次遇到邻居时，试着先想一想，再听示范。",[{"label":"看看下一课","id":"lessons","primary":true},{"label":"继续逛校园","id":"close"}],"三次答对只是这次任务的记录，不代表已经长期掌握。")
		return
	quiz_current = quiz_questions[quiz_index].duplicate(true)
	quiz_current.choices.shuffle()
	quiz_hinted = false
	quiz_answered = false
	State.begin_question(quiz_current.id)
	_show_question()
	play_phrase(quiz_current.audio)

func _show_question() -> void:
	var actions: Array = []
	for choice in quiz_current.choices:
		actions.append({"label":str(choice.text)+( "  /  "+str(choice.zh) if quiz_hinted else ""),"id":"answer:"+str(choice.id)})
	actions.append({"label":"再听一遍","id":"quiz_replay"})
	actions.append({"label":"显示中文提示" if not quiz_hinted else "中文提示已显示","id":"quiz_hint","disabled":quiz_hinted})
	var body: String = str(quiz_current.get("instruction","听一听，选一句合适的回应。"))
	if quiz_hinted:
		body += "\n"+str(quiz_current.prompt)+"\n"+str(quiz_current.zh)
	ui.show_panel("question","听听朋友的话","第 %d 课   /   小情境 %d / 3" % [quiz_unit,quiz_index+1],body,actions,"可以随时离开。看提示、试错后答对会记录为有提示完成。")

func answer_question(choice_id: String) -> void:
	if quiz_current.is_empty() or quiz_answered:
		return
	var correct := choice_id == str(quiz_current.answer)
	State.record_answer(quiz_current.id, correct, quiz_hinted)
	if not correct:
		ui.notify("再听一听，想想这位朋友在问什么。也可以看看中文提示。")
		play_phrase(quiz_current.audio)
		return
	quiz_answered = true
	var correct_text := ""
	for choice in quiz_current.choices:
		if choice.id==choice_id:
			correct_text = str(choice.text)+"\n"+str(choice.zh)
	ui.show_panel("correct","朋友听懂你的意思了","做得好，继续这段对话",correct_text,[{"label":"继续","id":"quiz_next","primary":true},{"label":"重听问题","id":"quiz_replay"}])

func show_learning_record() -> void:
	var independent := 0
	var assisted := 0
	var seen := 0
	for record in State.data.learning.values():
		seen += int(record.exposed)
		independent += int(record.independent)
		assisted += int(record.assisted)
	ui.show_panel("journal","留住每一次小小的进步","我的回忆册", "已完成 %d / 3 课\n独立答对 %d 次  ·  有提示或试错后答对 %d 次\n情境接触 %d 次\n\n固定地点：苹果屋想起 apple，蛋糕坊想起 cake。\n明天回到这些地方时，试着先回忆，再听一遍。" % [_completed_count(),independent,assisted,seen],[{"label":"听听 apple","id":"audio:apple"},{"label":"听听 cake","id":"audio:cake"},{"label":"教材与语音说明","id":"sources"},{"label":"继续生活","id":"close","primary":true}],"这是游玩记录，不是能力评级；听过、看过、跟读均不自动算掌握。")

func show_map() -> void:
	if not _prepare_screen(): return
	var points: Array = []
	var extras: Array = []
	for entry: Dictionary in interactions:
		if room in ["school", "home_estate", "home_hall"]:
			if entry.get("type","")=="travel":
				points.append(entry)
		elif room=="village":
			if str(entry.id).begins_with("landmark_") or str(entry.id) in ["home_gate","school_gate","baker","orchard"]:
				points.append(entry)
		else:
			if entry.get("type","")=="travel" or str(entry.id).begins_with("memory_") or str(entry.id) in ["teacher","lunch","sports","bed","decorate"]:
				points.append(entry)
	if room=="school":
		extras.append({"label":"校园里的五个探索位置","id":"campus_memories"})
	elif room=="home_estate":
		extras.append({"label":"小院里的五个生活位置","id":"home_memories"})
		extras.append({"label":"在家的一天","id":"home:day"})
	var routes: Dictionary = {}
	for entry: Dictionary in points:
		routes[str(entry.id)] = _preview_route(entry.position)
	ui.show_world_map(_room_label()+" · 地图",get_world_3d(),player.bounds,points,player.position,routes,extras)



func show_campus_memories() -> void:
	if room != "school":
		show_map()
		return
	var actions: Array = []
	for entry in interactions:
		if str(entry.id).begins_with("memory_"):
			actions.append({"label":str(entry.label),"id":"navigate:"+str(entry.id)})
	actions.append({"label":"返回校园导览","id":"map","primary":true})
	ui.show_panel("campus_memories", "在校园里慢慢逛", "山丘学园   /   五个探索位置", "看看导览牌、教学楼、花园和生活设施。\n选择位置后会沿校园道路步行前往。", actions)


func show_home_memories() -> void:
	if room != "home_estate":
		show_map()
		return
	var actions: Array = []
	for entry: Dictionary in interactions:
		if str(entry.id).begins_with("memory_"):
			actions.append({"label":str(entry.label),"id":"navigate:"+str(entry.id)})
	actions.append({"label":"返回住宅导览","id":"map","primary":true})
	ui.show_panel("home_memories", "在小院里慢慢逛", "我的家 · 五个生活位置", "看看信箱、花圃、随身篮、日程板和门廊小树。", actions)

func show_district(letters: String) -> void:
	var actions: Array = []
	for letter in letters:
		var id: String = "landmark_" + letter
		for entry in interactions:
			if entry.id == id:
				actions.append({"label":str(entry.label),"id":"navigate:"+id})
	actions.append({"label":"返回全岛导览","id":"map"})
	ui.show_panel("district","沿着小路去拜访",letters+"   /   地标导览","每个入口都有独特的生活场所。\n选择一个地方，走到门前再按 E 进入。",actions,"步行途中可以随时打开地图，更换目的地。")

func _navigate_to_id(target_id: String, auto_interact: bool = false) -> void:
	_close()
	if room == "home" and target_id == "home_gate": return
	for entry: Dictionary in interactions:
		if str(entry.id)==target_id:
			_request_interaction(entry,auto_interact)
			return
	var exit_id := ""
	if HomeCatalog.is_home_space(room) and target_id.ends_with("_gate") and target_id.trim_suffix("_gate") in HomeCatalog.CHILD_ROOMS:
		# Continue through the living room, walking to each physical doorway.
		exit_id = "house_entry" if room == "home_estate" else ("home_exit" if room in HomeCatalog.CHILD_ROOMS else "")
	elif room!="village" and target_id in ["baker","orchard","school_gate","home_gate"]:
		exit_id = "courtyard_exit" if room == "home" else str({"school":"school_exit", "home":"home_exit", "home_hall":"home_exit"}.get(str(metadata.get("parent_room","")), "village_exit"))
	if not exit_id.is_empty():
		for entry: Dictionary in interactions:
			if str(entry.id)==exit_id:
				_request_interaction(entry,true)
				journey_target = target_id
				journey_auto = auto_interact
				return
	ui.notify("这个地点不在当前场景，请先看看地图。")



func show_settings() -> void:
	if not _prepare_screen(): return
	ui.show_panel("settings","歇一会儿也没关系","声音、视角与生活操作","左键点按或长按地面自由漫步（双击或按住 Shift 轻快小跑）；右键按住拖动旋转视角（双击右键或按 C 复位）。\nWASD / 方向键移动 · E 互动 · 滚轮平滑缩放 · M 地图 · B 换装 · J 旅行册",[
		{"label":"语音播报："+("关" if muted else "开"),"id":"toggle_audio","icon":"speaker"},
		{"label":"环境音效："+("开" if State.data.preferences.effects else "关"),"id":"toggle_effects","icon":"music"},
		{"label":"减少动态："+("开" if ui.reduced_motion else "关"),"id":"toggle_motion","icon":"sun"},
		{"label":"固定白昼："+("开" if State.data.preferences.get("fixed_day",false) else "关"),"id":"toggle_day","icon":"lamp"},
		{"label":"窗口 / 全屏切换","id":"fullscreen"},
		{"label":"自由网格家园布置","id":"v4_free_decor","icon":"home"},
		{"label":"家长 AI 成长观察室 & 八册同步","id":"v4_parent_ai","primary":true,"icon":"compass"},
		{"label":"成长明细手账","id":"journey:parent","icon":"journal"},
		{"label":"保存并继续","id":"save","primary":true,"icon":"check"},
		{"label":"保存并退出","id":"quit"}
	],"角色穿搭、家园家具与章节进度都会自动保存。")



func _open_v4_commission(npc_id: String) -> void:
	if not is_instance_valid(ui.diegetic):
		return
	_commission_hint_used = false
	var comm := CurriculumDirector.build_daily_commission(State, npc_id)
	if comm.is_empty():
		return
	var actions: Array = []
	for opt: Dictionary in comm.get("options", []):
		var ok_flag := "1" if bool(opt.get("correct", false)) else "0"
		var act_id := "v4_comm_pick:%s:%s:%s:%s:%s" % [
			ok_flag,
			str(opt.get("word", "")),
			str(comm.get("commission_id", "")),
			npc_id,
			str(comm.get("target_entry_id", ""))
		]
		actions.append({"label": str(opt.get("label", "")), "id": act_id, "primary": true})
	var target_eid := str(comm.get("target_entry_id", ""))
	if not target_eid.is_empty():
		actions.append({"label": "◈ 打开 3D 立体翻翻书", "id": "open_popup_story:" + target_eid})
	actions.append({"label": "先逛一逛", "id": "close"})
	if is_instance_valid(audio_director):
		audio_director.play_foley("bubble_pop")
	ui.diegetic.open_conversation({
		"npc_id": npc_id,
		"speaker": str(comm.get("speaker", "小岛邻居")),
		"en": str(comm.get("prompt_en", "")),
		"zh": str(comm.get("prompt_zh", "")),
		"world_pos": conversation_position,
		"show_zh_immediately": false,
		"auto_speak": true,
		"actions": actions
	})

func _handle_v4_commission_pick(payload: String) -> void:
	var parts := payload.split(":", true, 4)
	if parts.size() < 5:
		return
	var is_ok := parts[0] == "1"
	var chosen_word := parts[1]
	var commission_id := parts[2]
	var npc_id := parts[3]
	var target_eid := parts[4]
	var support_lv := 1 if _commission_hint_used else 0
	State.record_stealth_evidence({
		"word": chosen_word,
		"support_level": support_lv,
		"correct": is_ok,
		"context": "diegetic_commission:" + npc_id
	})
	if is_instance_valid(ai_bridge):
		ai_bridge.observe_stealth_mastery(chosen_word, support_lv, is_ok, 1800, npc_id)
	if is_ok:
		State.complete_v4_commission(commission_id, 6)
		if is_instance_valid(audio_director):
			audio_director.play_foley("wardrobe_sparkle")
		player.gesture("wave")
		feedback.pickup(player.position, player.position, "leaf", "+6 叶币")
		if is_instance_valid(ui.diegetic):
			ui.diegetic.open_conversation({
				"npc_id": npc_id,
				"speaker": "小岛邻居 · 暖心回礼",
				"en": "Wonderful! \"%s\" fits our cozy card! Here are 6 leaf coins for you!" % chosen_word,
				"zh": "太棒啦！「%s」正好贴进小岛手账里，送你 6 枚叶币作为感谢！还想再试一张或翻开 3D 立体书吗？" % chosen_word,
				"world_pos": conversation_position,
				"show_zh_immediately": true,
				"auto_speak": true,
				"actions": [
					{"label": "★ 再接一张单元贴纸", "id": "v4_commission:" + npc_id, "primary": true},
					{"label": "◈ 翻开 3D 立体翻翻书", "id": "open_popup_story:" + target_eid},
					{"label": "开心收下", "id": "close"}
				]
			})
	else:
		_commission_hint_used = true
		if is_instance_valid(audio_director):
			audio_director.play_foley("bubble_pop")
		ui.notify("差一点点！点一下气泡右上角的「中文贴士」或打开 3D 立体翻翻书看看吧 ")

func open_active_v4_chapter() -> void:
	var chap := StoryDirector.active_chapter(State)
	if chap.is_empty():
		return
	_close()
	var target_room := str(chap.get("primary_room", "village"))
	if not target_room.is_empty() and room != target_room:
		await change_room(target_room)
	var host_npc := str(chap.get("host_npc_id", "npc_bear_uncle"))
	var anchor_pos := player.position + Vector3(1.1, 0.0, -1.0)
	if is_instance_valid(living):
		var actor_node: Node3D = living.get_actor(host_npc)
		if is_instance_valid(actor_node):
			anchor_pos = actor_node.position
			actor_node.face(player.position)
	for entry: Dictionary in interactions:
		if str(entry.get("id", "")) in ["host", "teacher", "baker", "gardener", "lunch", "sports"]:
			anchor_pos = entry.position
			break
	conversation_position = anchor_pos
	player.face(anchor_pos)
	if is_instance_valid(audio_director):
		audio_director.play_foley("bubble_pop")
	if is_instance_valid(ui.diegetic):
		ui.diegetic.open_conversation(StoryDirector.build_stage_dialogue(State, chap, anchor_pos))

func _handle_v4_chapter_step(payload: String) -> void:
	var parts := payload.split(":", true, 1)
	if parts.size() < 2:
		return
	var target_stage := int(parts[0])
	var ckey := parts[1]
	var chap := StoryDirector.get_chapter_by_key(ckey)
	if chap.is_empty():
		return
	var prev_stage := State.v4_chapter_stage(ckey)
	var bonus := 12 if (target_stage >= 3 and prev_stage < 3) else 0
	State.advance_v4_chapter(ckey, target_stage, bonus)
	var lead_w := str(chap.get("lead_word", "")).to_lower()
	if not lead_w.is_empty():
		State.record_stealth_evidence({
			"word": lead_w,
			"support_level": 1 if target_stage < 3 else 0,
			"correct": true,
			"context": "v4_chapter_stage_%d:%s" % [target_stage, ckey]
		})
	if target_stage >= 3:
		if is_instance_valid(audio_director):
			audio_director.play_foley("wardrobe_sparkle")
		player.gesture("wave")
		feedback.pickup(player.position, player.position, "leaf", "★ +12 叶币 · 章节纪念牌" if bonus > 0 else "★ 章节纪念牌")
		if is_instance_valid(tactile_quests):
			tactile_quests.attach_to_room(self, room)
		ui.notify("★ 恭喜点亮「%s · U%d %s」！场景里已立起永久章节纪念牌！" % [str(chap.get("book_title", "")), int(chap.get("unit_number", 1)), str(chap.get("event_title", ""))])
	else:
		if is_instance_valid(audio_director):
			audio_director.play_foley("bubble_pop")
	_refresh()
	if is_instance_valid(ui.diegetic):
		ui.diegetic.open_conversation(StoryDirector.build_stage_dialogue(State, chap, conversation_position))

func open_v4_thematic_play(ckey: String) -> void:
	var chap := StoryDirector.get_chapter_by_key(ckey)
	if chap.is_empty():
		chap = StoryDirector.active_chapter(State)
	if chap.is_empty() or not _prepare_screen():
		return
	var real_key := str(chap.get("chapter_key", ckey))
	State.journey_select_book(str(chap.get("book_id", "xiangshao-g3-1")))
	State.set_active_unit(str(chap.get("unit_id", "unit-1")))
	State.advance_v4_chapter(real_key, 1, 0)
	_thematic_session = {"ckey": real_key, "filled": 0, "hint": false, "note": ""}
	ThematicPlay.build(ui, State, chap, _thematic_session)
	var targets := ThematicPlay.target_cards_for_chapter(chap)
	if not targets.is_empty() and is_instance_valid(ai_bridge):
		ai_bridge.speak_text(str(targets[0].get("word", "")), "en", "warm")

func _handle_v4_thematic_pick(payload: String) -> void:
	var parts := payload.split(":", true, 1)
	if parts.size() < 2:
		return
	var ckey := parts[0]
	var chosen_word := parts[1]
	var chap := StoryDirector.get_chapter_by_key(ckey)
	if chap.is_empty():
		return
	var targets := ThematicPlay.target_cards_for_chapter(chap)
	var filled := clampi(int(_thematic_session.get("filled", 0)), 0, targets.size())
	if filled >= targets.size():
		return
	var expected := str(targets[filled].get("word", ""))
	var hint_used := bool(_thematic_session.get("hint", false))
	if is_instance_valid(ai_bridge):
		ai_bridge.speak_text(chosen_word, "en", "warm")
	if chosen_word.to_lower() == expected.to_lower():
		_thematic_session["filled"] = filled + 1
		_thematic_session["hint"] = false
		_thematic_session["note"] = "★ 放对啦！「%s」（%s）已经稳稳摆上托盘！" % [expected, str(targets[filled].get("zh", ""))]
		State.record_stealth_evidence({
			"word": expected.to_lower(),
			"support_level": 1 if hint_used else 0,
			"correct": true,
			"context": "v4_thematic_play:" + ckey
		})
		if is_instance_valid(audio_director):
			audio_director.play_foley("wardrobe_sparkle" if filled + 1 >= targets.size() else "bell_ding")
		if filled + 1 < targets.size() and is_instance_valid(ai_bridge):
			var next_w := str(targets[filled + 1].get("word", ""))
			get_tree().create_timer(0.65).timeout.connect(func():
				if is_instance_valid(ai_bridge) and ui.current_panel == "v4_thematic_play":
					ai_bridge.speak_text(next_w, "en", "warm")
			)
	else:
		var tapped_zh := chosen_word
		for item: Dictionary in ThematicPlay.choice_pool_for_chapter(chap, targets):
			if str(item.get("word", "")).to_lower() == chosen_word.to_lower():
				tapped_zh = str(item.get("zh", chosen_word))
				break
		_thematic_session["note"] = "◇ 这张卡是「%s」（%s）哦～听听读音，再找找哪张是【%s】吧 " % [
			chosen_word, tapped_zh, str(targets[filled].get("zh", ""))
		]
		if is_instance_valid(audio_director):
			audio_director.play_foley("bubble_pop")
	ThematicPlay.build(ui, State, chap, _thematic_session)

func _handle_v4_thematic_done(ckey: String) -> void:
	var chap := StoryDirector.get_chapter_by_key(ckey)
	if chap.is_empty():
		return
	var prev_st := State.v4_chapter_stage(ckey)
	var bonus := 6 if prev_st < 2 else 2
	State.advance_v4_chapter(ckey, 2, bonus)
	if is_instance_valid(audio_director):
		audio_director.play_foley("wardrobe_sparkle")
	await open_active_v4_chapter()
	feedback.pickup(player.position, player.position, "leaf", "+%d 叶币 · 共创完成" % bonus)

func _on_action(id: String) -> void:
	if is_instance_valid(creation) and creation.handle_action(id): return
	if is_instance_valid(sounds) and not id.begins_with("note:"):
		sounds.play("click")
	if is_instance_valid(journey) and await journey.handle_action(id):
		return
	if is_instance_valid(household) and await household.handle_action(id):
		return
	if id.begins_with("open_palace:"):
		var target_eid := id.trim_prefix("open_palace:").strip_edges()
		if is_instance_valid(ui.diegetic) and ui.diegetic.visible:
			ui.diegetic.dismiss()
		if is_instance_valid(journey) and not target_eid.is_empty():
			journey.open_story_from_world(target_eid)
		return
	if id.begins_with("open_palace_gap:"):
		var gap_eid := id.trim_prefix("open_palace_gap:").strip_edges()
		if is_instance_valid(ui.diegetic) and ui.diegetic.visible:
			ui.diegetic.dismiss()
		if is_instance_valid(journey) and not gap_eid.is_empty():
			journey.open_story_gap_from_world(gap_eid)
		return
	if id == "v5_palace_tour" or id.begins_with("v5_palace_tour:"):
		var off := 0
		if id.begins_with("v5_palace_tour:"):
			off = int(id.trim_prefix("v5_palace_tour:"))
		if is_instance_valid(palace_loci):
			palace_loci.open_room_palace_tour(off)
		return
	if id.begins_with("v5_palace_goto:"):
		var dest_room := id.trim_prefix("v5_palace_goto:").strip_edges()
		if not dest_room.is_empty():
			_close()
			if room != dest_room:
				await change_room(dest_room)
			if is_instance_valid(palace_loci):
				palace_loci.open_room_palace_tour(0)
		return
	if id.begins_with("v5_roleplay_start:"):
		var scen_id := id.trim_prefix("v5_roleplay_start:").strip_edges()
		RoleplayDirector.open_turn(self, scen_id, 0)
		return
	if id.begins_with("v5_roleplay_pick:"):
		RoleplayDirector.handle_pick(self, id.trim_prefix("v5_roleplay_pick:"))
		return
	if id == "v5_wake_mailbox":
		WakeMailbox.open_mailbox(self)
		return
	if id.begins_with("audio:"):
		play_phrase(id.trim_prefix("audio:"))
	elif id.begins_with("navigate:"):
		await _navigate_to_id(id.trim_prefix("navigate:"))
	elif id.begins_with("district:"):
		show_district(id.trim_prefix("district:"))
	elif id.begins_with("outfit:"):
		var outfit := id.trim_prefix("outfit:")
		if State.set_outfit(outfit):
			player.apply_wardrobe(State.data)
			ui.update_wardrobe(State.data)
			sounds.play("place")
			if is_instance_valid(audio_director): audio_director.play_foley("wardrobe_sparkle")
			if ui.current_panel == "bag":
				ui.show_inventory(State.data, "outfit")
	elif id.begins_with("hat:"):
		var hat_id := id.trim_prefix("hat:")
		if State.set_hat(hat_id):
			player.apply_wardrobe(State.data)
			ui.update_wardrobe(State.data)
			if is_instance_valid(audio_director): audio_director.play_foley("wardrobe_sparkle")
			if ui.current_panel == "bag":
				ui.show_inventory(State.data, "hat")
	elif id.begins_with("bag:"):
		var bag_id := id.trim_prefix("bag:")
		if State.set_bag(bag_id):
			player.apply_wardrobe(State.data)
			ui.update_wardrobe(State.data)
			if is_instance_valid(audio_director): audio_director.play_foley("wardrobe_sparkle")
			if ui.current_panel == "bag":
				ui.show_inventory(State.data, "bag")
	elif id.begins_with("wardrobe_tab:"):
		ui.show_inventory(State.data, id.trim_prefix("wardrobe_tab:"))
	elif id.begins_with("wardrobe_spin:"):
		if is_instance_valid(ui.wardrobe_preview) and ui.wardrobe_preview.has_method("spin_by"):
			var dir_s := id.trim_prefix("wardrobe_spin:")
			ui.wardrobe_preview.spin_by(-0.62 if dir_s == "left" else 0.62)
	elif id.begins_with("wardrobe_speak:"):
		if is_instance_valid(ai_bridge):
			ai_bridge.speak_text(id.trim_prefix("wardrobe_speak:"), "en", "warm")
	elif id == "v4_free_decor":
		if is_instance_valid(free_decor_studio):
			await free_decor_studio.open_studio()
	elif id.begins_with("v4_thematic_open:"):
		open_v4_thematic_play(id.trim_prefix("v4_thematic_open:"))
	elif id.begins_with("v4_thematic_speak:"):
		if is_instance_valid(ai_bridge):
			ai_bridge.speak_text(id.trim_prefix("v4_thematic_speak:"), "en", "warm")
	elif id.begins_with("v4_thematic_hint:"):
		var hkey := id.trim_prefix("v4_thematic_hint:")
		var hchap := StoryDirector.get_chapter_by_key(hkey)
		if not hchap.is_empty():
			_thematic_session["hint"] = true
			ThematicPlay.build(ui, State, hchap, _thematic_session)
	elif id.begins_with("v4_thematic_pick:"):
		_handle_v4_thematic_pick(id.trim_prefix("v4_thematic_pick:"))
	elif id.begins_with("v4_thematic_done:"):
		await _handle_v4_thematic_done(id.trim_prefix("v4_thematic_done:"))
	elif id == "v4_parent_ai":
		if _prepare_screen():
			ParentAIPortal.build(ui, State, ai_bridge)
	elif id == "v4_chapter_atlas":
		if _prepare_screen():
			ChapterAtlasView.build(ui, State)
	elif id.begins_with("v4_atlas_book:"):
		var bid := id.trim_prefix("v4_atlas_book:")
		State.journey_select_book(bid)
		State.set_active_unit("unit-1")
		if _prepare_screen():
			ChapterAtlasView.build(ui, State)
	elif id.begins_with("v4_atlas_unit:"):
		var uparts := id.trim_prefix("v4_atlas_unit:").split(":", true, 1)
		if uparts.size() == 2:
			State.journey_select_book(uparts[0])
			State.set_active_unit(uparts[1])
			if _prepare_screen():
				ChapterAtlasView.build(ui, State)
	elif id.begins_with("v4_chap_go:"):
		var gparts := id.trim_prefix("v4_chap_go:").split(":", true, 1)
		if gparts.size() == 2:
			State.journey_select_book(gparts[0])
			State.set_active_unit(gparts[1])
			await open_active_v4_chapter()
	elif id == "v4_chap_open_here":
		await open_active_v4_chapter()
	elif id.begins_with("v4_chap_step:"):
		_handle_v4_chapter_step(id.trim_prefix("v4_chap_step:"))
	elif id.begins_with("v4_chap_popup:"):
		var pparts := id.trim_prefix("v4_chap_popup:").split(":", true, 1)
		if pparts.size() == 2 and not pparts[1].is_empty():
			State.advance_v4_chapter(pparts[0], 1, 0)
			_pending_chapter_popup_key = pparts[0]
			if is_instance_valid(ui.diegetic):
				ui.diegetic.dismiss()
			if is_instance_valid(journey):
				journey.open_story(pparts[1], false)
	elif id.begins_with("open_popup_story:"):
		var entry_id := id.trim_prefix("open_popup_story:")
		if is_instance_valid(ui.diegetic):
			ui.diegetic.dismiss()
		if is_instance_valid(journey) and not entry_id.is_empty():
			journey.open_story(entry_id, false)
	elif id.begins_with("v4_commission:"):
		_open_v4_commission(id.trim_prefix("v4_commission:"))
	elif id.begins_with("v4_comm_pick:"):
		_handle_v4_commission_pick(id.trim_prefix("v4_comm_pick:"))
	elif id.begins_with("preview_buy:"):
		await _preview_purchase(id.trim_prefix("preview_buy:"))
	elif id.begins_with("buy:"):
		var decoration := id.trim_prefix("buy:")
		_rollback_decoration()
		if State.buy_decoration(decoration,true):
			decor_undo.append({"id":decoration,"before":false})
			sounds.play("place")
			await show_decorate()
	elif id.begins_with("preview_place:"):
		_preview_decoration(id.trim_prefix("preview_place:"))
	elif id.begins_with("place:"):
		_preview_decoration(id.trim_prefix("place:"))
	elif id.begins_with("activity:"):
		start_activity(id.trim_prefix("activity:"))
	elif id.begins_with("activity_complete:"):
		var activity := id.trim_prefix("activity_complete:")
		if State.complete_activity(activity):
			sounds.play("success")
	elif id.begins_with("note:"):
		sounds.note(int(id.trim_prefix("note:")))
	elif id.begins_with("sound:"):
		sounds.play(id.trim_prefix("sound:"))
	elif id.begins_with("interaction_choice:"):
		var target_id := id.trim_prefix("interaction_choice:")
		if ui.current_panel != "interaction_choices" or not _interaction_choice_ids.has(target_id): return
		for entry: Dictionary in interactions:
			if str(entry.id)==target_id:
				_close()
				_interaction_choice_ids.clear()
				_request_interaction(entry,true)
				break
	elif id.begins_with("unit:"):
		start_unit(int(id.trim_prefix("unit:")))
	elif id.begins_with("answer:"):
		answer_question(id.trim_prefix("answer:"))
	else:
		match id:
			"close": _request_close()
			"interact": interact_nearest()
			"cycle_interaction": _cycle_nearby_target()
			"quest": journey.continue_journey() if is_instance_valid(journey) else _follow_quest()
			"map": show_map()
			"campus_memories": show_campus_memories()
			"home_memories": show_home_memories()
			"bag": show_bag()
			"journal": show_journal()
			"learning_details": show_learning_record()
			"view_art": show_artwork()
			"settings": show_settings()
			"shop": show_shop()
			"decorate": await show_decorate()
			"confirm_place": _confirm_decoration()
			"cancel_place":
				_rollback_decoration()
				ui.show_decoration_tray(State.data,"",false,false,not decor_undo.is_empty())
			"undo_place": _undo_decoration()
			"lessons": show_lessons()
			"talk_baker": show_baker()
			"greet":
				if State.mark_greeted():
					sounds.play("success")
					player.gesture("wave")
				show_baker(false)
				play_phrase("hello")
			"harvest": _collect_apple()
			"deliver":
				if State.deliver_apples():
					play_phrase("thank_you")
					sounds.play("success")
					feedback.pickup(player.position,player.position,"cake","+1 蛋糕")
					player.gesture("reach")
				show_baker(false)
			"craft":
				if State.craft_cake():
					_close()
					player.gesture("reach")
					play_phrase("cake")
					sounds.play("success")
					feedback.pickup(conversation_position,player.position,"cake","+1 蛋糕")
			"sell":
				if State.sell_cake():
					play_phrase("thank_you")
					sounds.play("pickup")
					feedback.pickup(player.position,player.position,"leaf","+15 叶币")
				show_baker(false)
			"next_day":
				if State.next_day():
					_close()
					greetings.clear()
					if not ui.reduced_motion:
						ui.fade.color.a = 1
						create_tween().tween_property(ui.fade,"color:a",0.0,0.7)
			"save_art":
				if is_instance_valid(ui.activity_board) and is_instance_valid(ui.activity_board.canvas):
					if State.save_artwork(ui.activity_board.canvas.strokes):
						ui.activity_board.mark_saved()
						sounds.play("success")
			"save_art_draft":
				if State.save_artwork(art_draft):
					_finish_art_close()
			"discard_art": _finish_art_close()
			"return_art": _restore_art_draft()
			"football_shoot": _shoot_football()
			"football_restart":
				if is_instance_valid(football) and not football.busy:
					football.restart()
					ui.show_football(football)
			"quiz_hint":
				if not quiz_current.is_empty():
					State.use_hint(quiz_current.id)
					quiz_hinted = true
					_show_question()
			"quiz_replay":
				if not quiz_current.is_empty():
					play_phrase(quiz_current.audio)
			"quiz_next":
				if quiz_answered and not quiz_current.is_empty():
					quiz_index += 1
					_next_question()
			"retry_finish": _next_question()
			"toggle_audio":
				if State.set_preference("voice",muted):
					muted = not muted
					if is_instance_valid(ai_bridge):
						ai_bridge.muted = muted or validation_mode
					voice.stop()
				show_settings()
			"toggle_effects":
				if State.set_preference("effects",not State.data.preferences.effects):
					sounds.enabled = bool(State.data.preferences.effects) and not test_harness
					if is_instance_valid(audio_director):
						audio_director.set_enabled(bool(State.data.preferences.effects) and not validation_mode)
				show_settings()
			"toggle_motion":
				if State.set_preference("reduced_motion",not ui.reduced_motion):
					ui.reduced_motion = bool(State.data.preferences.reduced_motion)
					feedback.reduced_motion = ui.reduced_motion
					player.reduced_motion = ui.reduced_motion
				show_settings()
			"toggle_day":
				State.set_preference("fixed_day",not bool(State.data.preferences.get("fixed_day",false)))
				show_settings()
			"fullscreen":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			"save":
				if State.save_state():
					_close()
					ui.notify("今天的小小进步已经保存。")
			"quit": _request_quit()
			"sources":
				ui.show_panel("sources","从教材走进生活","内容与语音","原情境课保留三年级上册前三单元的 9 个新编任务。旅行册另有 26 字母探索、Unit 1 欢迎会和八册 1,314 条词表记录的可选图像故事。\n语音为本地合成缓存。看示范、探索和生活成果不等于独立掌握；词故事保存具体提示和当次作答。",[{"label":"打开词故事库","id":"journey:library","primary":true},{"label":"返回回忆册","id":"journal"}],"其他单元的完整生活主线、故事编辑复核和儿童试玩仍在后续计划中；当前没有口语自动评分。")



func _run_validation() -> void:
	# Real scene integration route in a separate save; never touches the player's game.
	var report := {"version":ProjectSettings.get_setting("application/config/version", "unknown"),"engine":Engine.get_version_info().string,"checks":[],"failures":[]}
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	await get_tree().create_timer(0.5).timeout
	await _capture(capture_dir,"01-village")
	_validate_check(report,"village_has_six_interactions",interactions.size()>=6)
	for entry in interactions:
		_validate_check(report,"walkable_route_"+str(entry.id),navigate_to(entry.position))
	player.path.clear()
	interact_id("baker")
	_on_action("greet")
	_validate_check(report,"greeting_quest",bool(State.data.quests.greet_done))
	for i in range(3):
		State.collect_apple()
	_on_action("deliver")
	_validate_check(report,"delivery_reward",bool(State.data.quests.delivery_done) and State.data.cakes==1)
	await _capture(capture_dir,"02-baker")
	_on_action("sell")
	State.buy_decoration("flower_box")
	State.place_decoration("flower_box",true)
	State.set_outfit("pink")
	await change_room("school")
	await _capture(capture_dir,"03-school")
	var school_doors := 0
	for entry in interactions:
		if entry.get("destination", "") in ["classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field"]:
			school_doors += 1
	_validate_check(report,"school_has_seven_child_places",school_doors==7 and int(metadata.get("scene_level",0))==2)
	for child_room in ["music_room", "art_room", "science_room", "football_field"]:
		await interact_id(str(child_room)+"_gate")
		_validate_check(report,str(child_room)+"_level_three",room==child_room and int(metadata.get("scene_level",0))==3 and metadata.get("parent_room", "")=="school")
		await _capture(capture_dir,"03-"+str(child_room))
		await interact_id("school_exit")
		var correct_return := false
		for entry in interactions:
			if entry.id == str(child_room)+"_gate":
				correct_return = room=="school" and Vector2(player.position.x,player.position.z).distance_to(Vector2(entry.position.x,entry.position.z)) < 1.0
		_validate_check(report,str(child_room)+"_returns_to_campus_door",correct_return)
	await change_room("classroom")
	await _capture(capture_dir,"04-classroom")
	for unit in range(1,4):
		start_unit(unit)
		for index in range(3):
			if unit==1 and index==0:
				_on_action("quiz_hint")
				await _capture(capture_dir,"05-lesson")
			answer_question(str(quiz_current.answer))
			_on_action("quiz_next")
	_validate_check(report,"three_units_complete",_completed_count()==3)
	_validate_check(report,"hint_is_assisted",State.data.learning.u1_greeting.assisted==1 and State.data.learning.u1_greeting.independent==0)
	for phrase in curriculum.phrases.values():
		var clip: AudioStream = load(phrase.audio) as AudioStream
		_validate_check(report,"audio_"+str(phrase.en),clip!=null and clip.get_length()>0)
	await change_room("canteen")
	await _capture(capture_dir,"06-canteen")
	await change_room("playground")
	await _capture(capture_dir,"07-playground")
	await change_room("home")
	await _capture(capture_dir,"08-home")
	_validate_check(report,"home_interactions",interactions.size()>=3)
	State.next_day()
	State.collect_apple()
	var saved: Dictionary = State.snapshot()
	State.load_state()
	_validate_check(report,"save_round_trip",State.data==saved)
	report["save_path"] = State.save_path
	report["result"] = "PASS" if report.failures.is_empty() else "FAIL"
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("integration-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if report.failures.is_empty() else 1)

func _validate_check(report: Dictionary, id: String, condition: bool) -> void:
	report.checks.append({"id":id,"pass":condition})
	if not condition:
		report.failures.append(id)

func _capture(directory: String, name: String) -> void:
	if directory.is_empty() or DisplayServer.get_name()=="headless":
		return
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
func _prepare_screen() -> bool:
	if is_instance_valid(journey) and not journey.close_memory(): return false
	if is_instance_valid(free_decor_studio) and free_decor_studio.active:
		free_decor_studio.close_studio()
	_stop_orchard_activity()
	_cancel_navigation()
	_rollback_decoration()
	_stop_football()
	player.path.clear()
	hover_interaction = {}
	return true

func _cancel_navigation(clear_journey: bool = true) -> void:
	pending_interaction = {}
	pending_time = 0
	if clear_journey:
		journey_target = ""
	if is_instance_valid(player):
		player.path.clear()
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	if is_instance_valid(feedback):
		feedback.clear_path()
	if is_instance_valid(ui):
		ui.navigation("")

func _request_interaction(entry: Dictionary, automatic: bool = true) -> void:
	if loading_room or entry.is_empty():
		return
	_cancel_navigation()
	pending_interaction = entry.duplicate()
	pending_auto = automatic
	pending_time = 0
	if navigate_to(entry.position):
		feedback.show_path(player.path)
		ui.navigation("前往 "+str(entry.label)+" · 右键可停下")
	else:
		pending_interaction = {}
		ui.notify("这里暂时走不过去，试试沿小路换个方向。")

func _update_navigation(delta: float) -> void:
	if pending_interaction.is_empty():
		if player.path.is_empty() and feedback.destination_ring.visible:
			feedback.clear_path()
			ui.navigation("")
		return
	pending_time += delta
	var entry: Dictionary = pending_interaction
	var distance := Vector2(player.position.x,player.position.z).distance_to(Vector2(entry.position.x,entry.position.z))
	var radius := float(entry.get("radius",2.3))
	if distance<radius-0.12 and player.path.size()<=3:
		var automatic := pending_auto
		var next_target := journey_target
		var next_auto := journey_auto
		_cancel_navigation()
		_nearby_choice = str(entry.id)
		_nearby_choice_position = player.position
		player.face(entry.position)
		if automatic:
			await interact_id(str(entry.id))
			if not next_target.is_empty() and not loading_room:
				await _navigate_to_id(next_target,next_auto)
	elif player.path.is_empty() or pending_time>100:
		_cancel_navigation()
		ui.notify("已经走到附近。可以换个方向靠近，或点地图重新带路。")

func _preview_route(target: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	if not nav_ready:
		return points
	var from := Vector2i(roundi(player.position.x/NAV_CELL),roundi(player.position.z/NAV_CELL))
	var to := Vector2i(roundi(target.x/NAV_CELL),roundi(target.z/NAV_CELL))
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(to):
		return points
	if navigation.is_point_solid(from):
		from = _nearest_walkable_cell(from,player.position)
	if navigation.is_point_solid(to):
		to = _nearest_walkable_cell(to,target)
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(to):
		return points
	for point: Vector2 in navigation.get_point_path(from,to):
		var key := Vector2i(roundi(point.x/NAV_CELL),roundi(point.y/NAV_CELL))
		points.append(Vector3(point.x,float(nav_heights.get(key,0)),point.y))
	return points

func _follow_quest() -> void:
	if not State.data.quests.greet_done:
		await _navigate_to_id("baker",true)
	elif not State.data.quests.delivery_done:
		await _navigate_to_id("orchard" if int(State.data.apples)<3 else "baker",true)
	elif not true in State.data.decorations_placed.values():
		await show_decorate()
	elif _completed_count()==0:
		if room=="classroom":
			await _navigate_to_id("teacher",true)
		elif room=="school":
			await _navigate_to_id("classroom_gate",true)
		else:
			await _navigate_to_id("school_gate",true)
	else:
		show_journal()

func _collect_apple() -> void:
	var source := player.position
	for entry: Dictionary in interactions:
		if str(entry.id)=="orchard":
			source = entry.position
			break
	if State.collect_apple():
		_close()
		player.gesture("reach")
		play_phrase("apple")
		sounds.play("pickup")
		feedback.pickup(source,player.position,"apple","+1 苹果")
		if int(State.data.apples)>=3 and not State.data.quests.delivery_done:
			ui.notify("三颗苹果收好了，点击小心愿去找熊叔吧。")

func _preview_purchase(id: String) -> void:
	if not State.DECORATION_PRICES.has(id):
		return
	if not _prepare_screen(): return
	if room!="home":
		await change_room("home")
	decor_selected = id
	decor_preview = true
	decor_enabled = true
	world.set_decoration(id,true)
	var names := {"flower_box":"窗边花箱","picnic":"野餐角","lamp":"暖光小灯"}
	var price: int = State.DECORATION_PRICES[id]
	ui.show_panel("purchase",str(names[id]),"先看看摆进家里的样子","%d 叶币 · 你有 %d 叶币\n喜欢这个位置，就把它带回家。" % [price,State.data.coins],[{"label":"买下并摆好","id":"buy:"+id,"primary":true,"disabled":int(State.data.coins)<price or State.data.decorations_owned[id]},{"label":"再看看其他装饰","id":"shop"}])

func _preview_decoration(id: String) -> void:
	if not State.data.decorations_owned.get(id,false):
		ui.notify("先去杂货架挑选这件装饰吧。")
		return
	_rollback_decoration()
	decor_selected = id
	decor_enabled = not bool(State.data.decorations_placed[id])
	decor_preview = true
	world.set_decoration(id,decor_enabled)
	sounds.play("place")
	ui.show_decoration_tray(State.data,id,true,decor_enabled,not decor_undo.is_empty())

func _rollback_decoration() -> void:
	if decor_preview and is_instance_valid(world):
		world.set_decoration(decor_selected,bool(State.data.decorations_placed.get(decor_selected,false)))
	decor_preview = false
	decor_selected = ""

func _confirm_decoration() -> void:
	if not decor_preview:
		return
	var id := decor_selected
	var before: bool = State.data.decorations_placed[id]
	if State.place_decoration(id,decor_enabled):
		decor_undo.append({"id":id,"before":before})
		decor_preview = false
		sounds.play("place")
		ui.show_decoration_tray(State.data,id,false,false,true)

func _undo_decoration() -> void:
	if decor_undo.is_empty():
		return
	_rollback_decoration()
	var last: Dictionary = decor_undo.back()
	if State.place_decoration(str(last.id),bool(last.before)):
		decor_undo.pop_back()
		sounds.play("place")
		ui.show_decoration_tray(State.data,"",false,false,not decor_undo.is_empty())

func _room_activity() -> String:
	return str({"music_room":"music","art_room":"art","science_room":"science","football_field":"football"}.get(room,""))

func _activity_label(id: String) -> String:
	return str({"music":"弹一段小岛旋律","art":"画一张明信片","science":"动手调配颜色","football":"开始射门练习"}.get(id,"动手试一试"))

func start_activity(id: String) -> void:
	if id!=_room_activity() and not (id=="art" and room=="home_study"):
		ui.notify("到对应的校园场所，和老师一起开始吧。")
		return
	if not _prepare_screen(): return
	voice.stop()
	if id=="football":
		_start_football()
	else:
		ui.show_activity(id,State.data.life,room=="home_study")

func _request_close() -> void:
	if ui.current_panel=="art_unsaved":
		_restore_art_draft()
		return
	if is_instance_valid(ui.activity_board) and ui.activity_board.kind=="art" and ui.activity_board.dirty:
		art_draft = ui.activity_board.canvas.strokes.duplicate(true)
		ui.show_panel("art_unsaved","把这张画收好再走？","明信片还没保存","可以收入回忆册，也可以继续画。",[{"label":"保存后离开","id":"save_art_draft","primary":true},{"label":"继续画","id":"return_art"},{"label":"放弃这次修改","id":"discard_art"}])
		return
	_close()

func _restore_art_draft() -> void:
	_closing_for_quit = false
	var draft: Dictionary = State.data.life.duplicate(true)
	draft.artwork = art_draft.duplicate(true)
	var board: Node = ui.show_activity("art",draft,room=="home_study")
	board.dirty = true

func _finish_art_close() -> void:
	art_draft.clear()
	_close()
	if _closing_for_quit:
		_closing_for_quit = false
		_request_quit()

func _request_quit() -> void:
	if is_instance_valid(creation) and not creation.before_close(): return
	if is_instance_valid(journey) and not journey.close_memory(): return
	if is_instance_valid(ui.activity_board) and ui.activity_board.kind=="art" and ui.activity_board.dirty:
		_closing_for_quit = true
		_request_close()
	elif ui.current_panel=="art_unsaved":
		_closing_for_quit = true
	elif State.save_state():
		if OS.has_feature("web_online") and is_instance_valid(online):
			# Pause writes while the shell commits this profile's IDBFS transaction.
			# Browser navigation avoids the web runtime's shutdown allocator stall.
			get_tree().paused = true
			JavaScriptBridge.eval("window.AlphabetIslandOnline.finishSession();", true)
		else:
			get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_backgrounded = true
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		application_backgrounded = false
	if is_instance_valid(journey) and is_instance_valid(journey.letter_activity):
		journey.letter_activity.suspended = application_backgrounded
	if what==NOTIFICATION_WM_CLOSE_REQUEST and scene_ready:
		_request_quit()

func start_orchard_activity() -> void:
	var progress: Dictionary=State.journey_snapshot()
	if progress.home_steps.size()<4 and not progress.legacy_compatible:
		journey.show_home()
		return
	if room!="landmark_A": await change_room("landmark_A")
	if not _prepare_screen(): return
	ui.close_panel()
	var activity: Node3D=load("res://activities/orchard_pick.gd").new()
	add_child(activity)
	if not activity.setup(self):
		activity.teardown()
		activity.queue_free()
		ui.notify("果园的互动位置暂时没有准备好，请稍后再试。")
		return
	orchard_activity=activity
	activity.leave_requested.connect(func():
		_stop_orchard_activity()
		ui.notify("进度已保留，下次可以继续和兔兔采苹果。")
	)
	activity.discovery_finished.connect(func(mode: String):
		for fact: String in ["visited","representative_image_presented","micro_action_feedback_seen","case_pair_presented"]:
			journey.letter_pending.append({"letter":"A","room":"landmark_A","fact":fact,"mode":mode})
		if not journey._flush_letter_facts():
			ui.notify("发现页还没有保存好，请保留这一页再试一次。")
			return
		for index: int in 2:
			if not State.journey_p2_event({"kind":"letter_action","letter":"A","room":"landmark_A","expected_step":index,"operation":"pick" if index==0 else "place"}): return
		if mode=="demonstration_viewed": State.journey_p2_event({"kind":"letter_help","letter":"A","room":"landmark_A","level":3})
		_stop_orchard_activity()
		journey.show_letter_card("A")
	)
	player.locked=true

func _stop_orchard_activity() -> void:
	if not is_instance_valid(orchard_activity): return
	var activity: Node3D=orchard_activity
	orchard_activity=null
	activity.teardown()
	activity.queue_free()
	if is_instance_valid(player): player.locked=false

func _start_football() -> void:
	football = FootballScript.new()
	add_child(football)
	if not football.setup(world,interactions):
		football.queue_free()
		football = null
		ui.notify("没有找到球门，请检查场景文件。")
		return
	football_return = player.position
	player.position = football.start-football.forward*1.2
	player.position.y += 0.2
	player.velocity = Vector3.ZERO
	player.face(football.goal)
	player.locked = true
	football.shot_finished.connect(func(scored: bool,attempts: int,goals: int):
		sounds.play("success" if scored else "miss")
		if is_instance_valid(ai_bridge):
			ai_bridge.speak_text("Goal! Great shot!" if scored else "Nice try! Kick again!", "en", "warm")
		ui.football_feedback(attempts,goals,"Goal! Great shot! · 进球啦！再试一个角度。" if scored else "Nice try! · 差一点点，调整方向和力度再试试。")
	)
	football.round_finished.connect(func(goals: int):
		State.complete_activity("football",goals)
		if is_instance_valid(ai_bridge):
			ai_bridge.speak_text("Five shots finished! Fantastic job!", "en", "warm")
		ui.football_feedback(5,goals,"Fantastic job! · 五次射门完成！本轮进球 %d，最好成绩 %d。" % [goals,State.data.life.scores.football])
	)
	if is_instance_valid(ai_bridge):
		ai_bridge.speak_text("Let's kick the football into the goal!", "en", "warm")
	ui.show_football(football)

func _shoot_football() -> void:
	if is_instance_valid(football) and football.shoot():
		player.gesture("kick")
		sounds.play("kick")

func _stop_football() -> void:
	if is_instance_valid(football):
		football.queue_free()
		football = null
		if is_instance_valid(player):
			player.position = football_return
			player.velocity = Vector3.ZERO
			player.locked = false

func show_journal() -> void:
	if not _prepare_screen(): return
	var counts: Dictionary = {}
	for key: String in State.data.life.discoveries:
		var id := key.get_slice("/",0)
		counts[id] = int(counts.get(id,0))+1
	var places: Array = []
	for id: String in counts:
		places.append({"name":str(world.room_plan(id).get("name",id)),"count":counts[id]})
	ui.show_memory_book(State.data,places)

func show_artwork() -> void:
	if not _prepare_screen(): return
	ui.show_postcard(State.data.life.artwork)
