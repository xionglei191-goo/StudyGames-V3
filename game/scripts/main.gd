extends Node3D

const WorldScript = preload("res://scripts/world_builder.gd")
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/ui.gd")
const FeedbackScript = preload("res://scripts/world_feedback.gd")
const SoundScript = preload("res://scripts/feedback_audio.gd")
const FootballScript = preload("res://activities/football_practice.gd")
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
const ROOM_LABELS := {"village":"字母岛", "school":"山丘学园 · 校园", "classroom":"阳光教室", "music_room":"音乐教室", "art_room":"美术教室", "science_room":"科学教室", "canteen":"校园餐厅", "playground":"青草操场", "football_field":"绿茵足球场", "home":"家里的客厅", "home_estate":"我的家 · 小院与住宅"}
const NAV_CELL := 0.75
var nav_heights: Dictionary = {}
var navigation_cache: Dictionary = {}
var feedback: Node3D
var sounds: Node
var pending_interaction: Dictionary = {}
var hover_interaction: Dictionary = {}
var pending_auto := false
var pending_time := 0.0
var journey_target := ""
var journey_auto := false
var conversation_position := Vector3.ZERO
var camera_base_size := 22.0
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
	for arg in OS.get_cmdline_user_args():
		if arg == "--validate" or arg.begins_with("--capture-dir="):
			validation_mode = true
		if arg == "--test-harness":
			validation_mode = true
			test_harness = true
	if validation_mode:
		State.save_path = "user://validation-%s.json" % OS.get_process_id()
	ui = UIScript.new()
	add_child(ui)
	ui.action.connect(_on_action)
	State.notice.connect(ui.notify)
	State.changed.connect(_refresh)
	State.load_state()
	muted = not bool(State.data.preferences.voice)
	ui.reduced_motion = bool(State.data.preferences.reduced_motion)
	sounds = SoundScript.new()
	add_child(sounds)
	sounds.enabled = bool(State.data.preferences.effects) and not test_harness
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
	ui.speaker_provider = _dialogue_speaker
	var start_room := "village" if validation_mode or State.journey_snapshot().legacy_compatible else "home"
	await change_room(start_room)
	_refresh()
	scene_ready = true
	if test_harness and OS.get_cmdline_user_args().has("--release-smoke"):
		var smoke: Node = load("res://scripts/release_smoke.gd").new()
		smoke.game = self
		add_child(smoke)
	elif validation_mode and not test_harness:
		_run_validation.call_deferred()
	elif not test_harness:
		if not State.journey_snapshot().legacy_compatible:
			journey.continue_journey()
		else:
			ui.notify("欢迎回来，今天也在小岛上慢慢逛吧。")

func _dialogue_speaker(panel_id: String) -> String:
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
	var keys := {"walk_left":[KEY_A,KEY_LEFT], "walk_right":[KEY_D,KEY_RIGHT], "walk_up":[KEY_W,KEY_UP], "walk_down":[KEY_S,KEY_DOWN], "interact":[KEY_E], "map":[KEY_M], "bag":[KEY_B], "journal":[KEY_J]}
	for action_name in keys:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key in keys[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action_name, event)

func change_room(next_room: String, return_id: String = "") -> void:
	if loading_room:
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
	feedback.highlight({})
	nav_ready = false
	player.locked = true
	player.path.clear()
	voice.stop()
	ui.close_panel()
	ui.bubble_panel.hide()
	if next_room != room:
		visit_return[room] = player.position
	room = next_room
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
		camera_base_size = 18.0
	camera.size = camera_base_size
	conversation_position = player.position
	feedback.bind_interactions(interactions)
	camera.position = player.position + camera_offset
	camera.look_at(player.position + Vector3(0,0.5,0), Vector3.UP)
	await get_tree().physics_frame
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
	if is_instance_valid(journey):
		journey.on_room_ready()
	_refresh()
	if not ui.reduced_motion:
		ui.fade.color.a = 0.55
		var transition := create_tween()
		transition.tween_property(ui.fade,"color:a",0.0,0.22)
		await transition.finished

func _build_navigation() -> void:
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
	player.locked = ui.modal.visible or is_instance_valid(football) or is_instance_valid(orchard_activity)
	if is_instance_valid(living):
		living.set_context({"dialogue_open":ui.modal.visible,"learning_open":ui.current_panel=="question","memory_open":ui.current_panel=="word_story","paused":ui.current_panel=="settings" or (is_instance_valid(orchard_activity) and orchard_activity.paused),"backgrounded":application_backgrounded,"reduced_motion":ui.reduced_motion,"fixed_day":bool(State.data.preferences.get("fixed_day",false)),"guided_prologue":journey_phase in ["home","prologue"],"story_day_phase":"dawn" if ui.current_panel=="journey_u1" and journey.u1_visible_step=="U1-01" else "","active_actor_ids":journey.active_actor_ids if ui.modal.visible else []})
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
	if is_instance_valid(football):
		focus = football.start.lerp(football.goal,0.5)+Vector3(0,-2.8,0)
		desired_size = 17.5
	if is_instance_valid(orchard_activity):
		focus=orchard_activity.camera_focus
		desired_size=orchard_activity.camera_size
	if is_instance_valid(journey) and journey.handoff_busy:
		var giver: Node3D = living.get_actor("textbook_peter")
		if giver:
			focus=(giver.position+player.position)/2.0+Vector3(0,-1.5,0)
			desired_size=8.5
	var smoothing := 1.0 if ui.reduced_motion else 1.0-exp(-delta*5)
	camera.position = camera.position.lerp(focus+camera_offset,smoothing)
	camera.look_at(camera.position-camera_offset+Vector3(0,0.5,0),Vector3.UP)
	camera.size = lerpf(camera.size,desired_size,smoothing)
	if is_instance_valid(orchard_activity):
		ui.prompt.hide()
		ui.bubble_panel.hide()
		return
	greeting_clock -= delta
	step_clock -= delta
	if player.velocity.length()>1.5 and player.is_on_floor() and not player.locked and step_clock<=0:
		sounds.play("step")
		step_clock = 0.34
	if ui.bubble_panel.visible:
		ui.bubble_panel.position = camera.unproject_position(bubble_world_position)+Vector2(-100,-106)
	nearest = {}
	var nearest_distance := INF
	for entry: Dictionary in interactions:
		var distance := Vector2(player.position.x,player.position.z).distance_to(Vector2(entry.position.x,entry.position.z))
		if distance<float(entry.get("radius",2.7)) and distance<nearest_distance:
			nearest = entry
			nearest_distance = distance
		if distance<3.5 and not ui.modal.visible and greeting_clock<=0 and not voice.playing and not str(entry.get("greeting","")).is_empty():
			var greeting_id := room+"/"+str(entry.id)
			if Time.get_ticks_msec()-int(greetings.get(greeting_id,-60000))>45000:
				var phrase_key := str(entry.greeting)
				if not curriculum.phrases.has(phrase_key):
					phrase_key = "good_morning"
				var phrase: Dictionary = curriculum.phrases[phrase_key]
				play_phrase(phrase_key)
				bubble_world_position = entry.position+Vector3(0,2.4,0)
				ui.say(phrase.en,phrase.zh,camera.unproject_position(bubble_world_position))
				greetings[greeting_id] = Time.get_ticks_msec()
				greeting_clock = 8
	if not ui.modal.visible and not is_instance_valid(football):
		var selected: Dictionary = hover_interaction if not hover_interaction.is_empty() else nearest
		feedback.highlight(selected)
		if not selected.is_empty() and not camera.is_position_behind(selected.position):
			var text := str(selected.label)
			if str(selected.id)=="orchard":
				text = "采苹果  %d/3" % int(State.data.harvested) if int(State.data.harvested)<3 else "苹果已采完"
			ui.show_prompt(text,camera.unproject_position(selected.position+Vector3(0,2.4,0)))
		else:
			ui.prompt.hide()
		_update_navigation(delta)
	else:
		ui.prompt.hide()
		feedback.highlight({})



func _unhandled_input(event: InputEvent) -> void:
	if loading_room or not is_instance_valid(ui):
		return
	if is_instance_valid(orchard_activity):
		orchard_activity.handle_input(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if ui.modal.visible:
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
		return
	if event.is_action_pressed("interact"):
		if not hover_interaction.is_empty():
			_request_interaction(hover_interaction,true)
		else:
			interact_nearest()
	elif event.is_action_pressed("map"):
		show_map()
	elif event.is_action_pressed("bag"):
		show_bag()
	elif event.is_action_pressed("journal"):
		show_journal()
	elif event is InputEventKey and event.pressed:
		for key: String in ["walk_left","walk_right","walk_up","walk_down"]:
			if event.is_action_pressed(key):
				_cancel_navigation()
				break
	elif event is InputEventMouseMotion:
		hover_interaction = feedback.pick(event.position,camera)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not hover_interaction.is_empty() else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			camera_base_size = maxf(10,camera_base_size-1.2)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			camera_base_size = minf(34,camera_base_size+1.2)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			_cancel_navigation()
			ui.notify("在这里歇一会儿。")
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var selected: Dictionary = feedback.pick(event.position,camera)
			if not selected.is_empty():
				_request_interaction(selected,true)
				return
			_cancel_navigation()
			var origin := camera.project_ray_origin(event.position)
			var direction := camera.project_ray_normal(event.position)
			var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*400.0,4)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and navigate_to(hit.position):
				feedback.show_path(player.path)
				ui.navigation("沿着小路走走 · 右键停下 / 方向键接着走")



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
		player.set_outfit(d.outfit)
		ui.update_outfit(str(d.outfit))
	if is_instance_valid(world) and world.has_method("set_decoration"):
		for id in ["flower_box","picnic","lamp"]:
			if decor_preview and decor_selected==id:
				world.set_decoration(id,decor_enabled)
			else:
				world.set_decoration(id,bool(d.decorations_placed.get(id,false)))

func _close() -> void:
	if is_instance_valid(journey) and not journey.close_memory(): return
	if is_instance_valid(household): household.cancel_task()
	_stop_orchard_activity()
	_rollback_decoration()
	_stop_football()

	_cancel_navigation()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

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
	var body := str(anchor.get("activity", "看看这里的物件，下次回来时试着想起它的名字。"))
	var focus: Array = plan.get("english_focus", [])
	if not focus.is_empty():
		body += "\n"+" · ".join(focus.slice(0,2))
	State.discover(room,sequence)
	var actions: Array = [{"label":"继续探索","id":"close","primary":true}]
	var activity := _room_activity()
	if not activity.is_empty():
		actions.push_front({"label":_activity_label(activity),"id":"activity:"+activity,"primary":true})
	if room == "landmark_A" and sequence == 2:
		actions.push_front({"label":"摘一颗苹果","id":"harvest","primary":true})
	elif room == "landmark_C" and sequence in [1,3,5]:
		actions.push_front({"label":"看看熊叔的订单","id":"talk_baker","primary":true})
	elif room == "classroom":
		actions.push_front({"label":"开始今天的课程","id":"lessons","primary":true})
	elif room == "home" and sequence == 4:
		actions.push_front({"label":"睡到明天","id":"next_day","primary":true})
	elif room == "home" and sequence == 2:
		actions.push_front({"label":"装扮我的小屋","id":"decorate","primary":true})
	var visited := 0
	for index: int in range(1,6):
		if State.data.life.discoveries.has("%s/memory_%02d" % [room,index]):
			visited += 1
	ui.show_panel("memory",str(anchor.get("label","小岛回忆")),"%s · 已发现 %d / 5" % [_room_label(),visited],body,actions)

func interact_nearest() -> void:
	if not nearest.is_empty():
		interact_id(str(nearest.id))

func interact_id(id: String) -> void:
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
			ui.show_panel("gardener","兔兔的果园","邻居   /   苹果屋","Hello!  欢迎你来果园。\n树上的苹果今天熟了，采三颗送给熊叔吧。\n累了也可以来我的花园坐一会儿。",[{"label":"听听 apple 的读音","id":"audio:apple","primary":true},{"label":"去采苹果","id":"navigate:orchard"}])
		"orchard": show_orchard()
		"school_gate": await change_room("school")
		"home_gate": await change_room("home_estate")
		"house_entry": household.show_entry()
		"village_exit":
			var door := "school_gate" if room=="school" else (room if room.begins_with("landmark_") else "home_gate")
			await change_room("village", door)
		"teacher": show_lessons()
		"lunch":
			play_phrase("milk")
			ui.show_panel("lunch","今天想吃点什么？","校园食堂   /   生活英语","和食堂阿姨一起认识食物。\n点选食物，就能听到它的英文名字。",[{"label":"牛奶  milk","id":"audio:milk","primary":true},{"label":"面包  bread","id":"audio:bread"},{"label":"蛋糕  cake","id":"audio:cake"},{"label":"谢谢阿姨  Thank you.","id":"audio:thank_you"}],"这里是自由体验，不计为独立掌握。")
		"sports":
			play_phrase("how_old")
			ui.show_panel("sports","操场上认识新朋友","课间   /   自由对话","How old are you?\n小伙伴想知道你几岁了。听一听示范，再试着说自己的年龄。",[{"label":"听听 I'm nine.","id":"audio:im_nine","primary":true},{"label":"回教室看看课程","id":"navigate:school_exit"}],"第一版不录音、不评判口语；听过或跟读不记为独立掌握。")
		"bed":
			ui.show_panel("bed","今天也是充实的一天","我的小屋   /   休息","睡一觉，明天的苹果就成熟了。\n小屋、装饰、叶币和学习记录都会保留。",[{"label":"睡到明天","id":"next_day","primary":true},{"label":"再玩一会儿","id":"close"}])
		"decorate": show_decorate()
		"host":
			var activity := _room_activity()
			if not activity.is_empty():
				start_activity(activity)
			else:
				show_place()

func show_baker(play_greeting: bool = true) -> void:
	var d: Dictionary = State.data
	if play_greeting:
		play_phrase("good_morning")
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
		if room in ["school", "home_estate"]:
			if entry.get("type","") in ["travel", "house_entry"]:
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
	for entry: Dictionary in interactions:
		if str(entry.id)==target_id:
			_request_interaction(entry,auto_interact)
			return
	if room!="village" and target_id in ["baker","orchard","school_gate","home_gate"]:
		var exit_id: String = {"school":"school_exit", "home_estate":"home_exit"}.get(str(metadata.get("parent_room","")), "village_exit")
		for entry: Dictionary in interactions:
			if str(entry.id)==exit_id:
				_request_interaction(entry,true)
				journey_target = target_id
				journey_auto = auto_interact
				return
	ui.notify("这个地点不在当前场景，请先看看地图。")



func show_settings() -> void:
	if not _prepare_screen(): return
	ui.show_panel("settings","歇一会儿也没关系","声音与操作","点地面散步，点人物走近聊聊，右键随时停下。\nWASD / 方向键移动 · E 互动 · M 地图 · B 背包 · J 回忆册\n滚轮拉近或拉远，Esc 返回或取消行走。",[
		{"label":"语音："+("关" if muted else "开"),"id":"toggle_audio"},
		{"label":"音效："+("开" if State.data.preferences.effects else "关"),"id":"toggle_effects"},
		{"label":"减少动态："+("开" if ui.reduced_motion else "关"),"id":"toggle_motion"},
		{"label":"固定白昼："+("开" if State.data.preferences.get("fixed_day",false) else "关"),"id":"toggle_day"},
		{"label":"窗口 / 全屏","id":"fullscreen"},
		{"label":"保存并继续","id":"save","primary":true},
		{"label":"保存并退出","id":"quit"}
	],"物品与任务会自动保存。画好的明信片需要点击保存。")



func _on_action(id: String) -> void:
	if is_instance_valid(sounds) and not id.begins_with("note:"):
		sounds.play("click")
	if is_instance_valid(journey) and await journey.handle_action(id):
		return
	if is_instance_valid(household) and await household.handle_action(id):
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
			ui.update_outfit(outfit)
			sounds.play("place")
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
	elif id.begins_with("unit:"):
		start_unit(int(id.trim_prefix("unit:")))
	elif id.begins_with("answer:"):
		answer_question(id.trim_prefix("answer:"))
	else:
		match id:
			"close": _request_close()
			"interact":
				if not hover_interaction.is_empty():
					_request_interaction(hover_interaction,true)
				else:
					interact_nearest()
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
					voice.stop()
				show_settings()
			"toggle_effects":
				if State.set_preference("effects",not State.data.preferences.effects):
					sounds.enabled = bool(State.data.preferences.effects) and not test_harness
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
	if id!=_room_activity():
		ui.notify("到对应的校园场所，和老师一起开始吧。")
		return
	if not _prepare_screen(): return
	voice.stop()
	if id=="football":
		_start_football()
	else:
		ui.show_activity(id,State.data.life)

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
	var board: Node = ui.show_activity("art",draft)
	board.dirty = true

func _finish_art_close() -> void:
	art_draft.clear()
	_close()
	if _closing_for_quit:
		_closing_for_quit = false
		_request_quit()

func _request_quit() -> void:
	if is_instance_valid(journey) and not journey.close_memory(): return
	if is_instance_valid(ui.activity_board) and ui.activity_board.kind=="art" and ui.activity_board.dirty:
		_closing_for_quit = true
		_request_close()
	elif ui.current_panel=="art_unsaved":
		_closing_for_quit = true
	elif State.save_state():
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
		ui.football_feedback(attempts,goals,"进球啦！再试一个角度。" if scored else "差一点点。调整方向和力度，再试试。")
	)
	football.round_finished.connect(func(goals: int):
		State.complete_activity("football",goals)
		ui.football_feedback(5,goals,"五次射门完成！本轮进球 %d，最好成绩 %d。" % [goals,State.data.life.scores.football])
	)
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
