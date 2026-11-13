extends SceneTree
## Exercises the real room/controller/input path with an isolated validation save.
const Catalog = preload("res://scripts/home_catalog.gd")
const OUTPUT := "F:/LoveStudy/docs/verification/home-living-hub-20261113/household"
var game: Node
var state: Node
var passed := 0
var failed := 0
var captures := false
var cases: Array = []

func _initialize() -> void:
	run.call_deferred()

func _process(_delta: float) -> bool:
	# Capture tools may give focus back to the desktop. Scripted input stays foreground
	# here; the production focus-loss cancellation is tested explicitly below.
	if is_instance_valid(game): game.application_backgrounded = false
	return false

func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
	cases.append({"case":label,"passed":value})

func frames(count: int = 4) -> void:
	for i in range(count): await process_frame

func press(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = true
	game._unhandled_input(event)

func release(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = false
	game._unhandled_input(event)

func move_to(pos: Vector2, relative: Vector2 = Vector2(18,0)) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	game._unhandled_input(event)

func click(pos: Vector2) -> void:
	press(pos)
	release(pos)

func engine_button(pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	# parse_input_event takes window coordinates, before the viewport stretch.
	event.position = root.get_final_transform() * pos
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func engine_move(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * pos
	event.global_position = event.position
	event.relative = Vector2(16,0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await process_frame

func drag(activity: Node, source: Vector3, destination: Vector3) -> void:
	var start: Vector2 = game.camera.unproject_position(source)
	var end: Vector2 = game.camera.unproject_position(destination)
	press(start)
	for step in range(1,11): move_to(start.lerp(end,step/10.0),(end-start)/10.0)
	release(end)

func begin(room: String) -> Node:
	await game.change_room(room)
	var plan: Dictionary = Catalog.room(room)
	var marker: Node3D = game.metadata.marker_nodes["SG_MEMORY_%02d" % int(plan.task.anchor)]
	game.player.position = marker.global_position + Vector3(0,0.1,1.0)
	game.household.show_memory(int(plan.task.anchor))
	game.household.handle_action("home:begin")
	await frames(12)
	var activity: Node = game.household.activity
	check(is_instance_valid(activity), room + " opens from its actual memory anchor")
	check(not game.ui.modal.visible and not game.ui.hud.visible and game.player.locked, room + " leaves world visible and locks walking")
	return activity

func capture(label: String) -> void:
	if not captures: return
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	create_timer(180).timeout.connect(func(): push_error("Household tests timed out"); quit(1))
	captures = OS.get_cmdline_user_args().has("--capture-household")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440,900)
	AudioServer.set_bus_mute(0,true)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.scene_ready: await process_frame
	state = root.get_node("State")
	if not str(state.save_path).begins_with("user://validation-"):
		quit(2)
		return
	state.data = state._default_state()
	state.data.preferences.fixed_day = true
	game.ui.reduced_motion = true
	game.muted = true
	var learning_before: Dictionary = state.data.learning.duplicate(true)
	for room: String in ["home_dining","home","home_bedroom","home_study","home_balcony","home_kitchen","home_bathroom","home_estate"]:
		var a: Node = await begin(room)
		if not is_instance_valid(a): quit(1); return
		for entry: Dictionary in a.items: check(entry.node.get_child_count() > 0, room + " reuses actual prop meshes: " + str(entry.kind))
		await capture(room + "-before")
		click(Vector2(500,600))
		game.household.handle_action("home:step")
		check(not a.completed and not bool(state.data.life.home_tasks.get(str(a.task_id),false)), room + " arbitrary click / removed step action cannot finish")
		if room in ["home_dining","home","home_bedroom","home_study","home_balcony"]:
			var entry: Dictionary = a.items[0]
			drag(a,entry.node.position,entry.node.position + Vector3(7,0,5))
			check(not entry.placed and entry.node.position.is_equal_approx(entry.source), room + " invalid drop returns prop")
			var limit := 0
			while not a.completed and a.stage < a.stage_count and limit < 20:
				limit += 1
				if room == "home_bedroom" and a.stage == 2:
					await capture("bed-wrinkles-before-smoothing")
					var center: Vector2 = game.camera.unproject_position(Vector3(-4.2,1.12,-2.0))
					press(center)
					await frames()
					check(a.scrub == 0.0, "holding quilt without movement does not smooth it")
					for i in range(48): move_to(center + Vector2(25 if i % 2 == 0 else -25,0),Vector2(24,0))
					release(center)
				else:
					var current: int = a.stage
					for item: Dictionary in a.items:
						if item.stage == current and not item.placed:
							var target: Vector3 = item.target
							for slot: Dictionary in a.targets:
								if not slot.used and slot.stage == current and slot.kind == item.kind:
									target = slot.point
									break
							drag(a,item.node.position,target)
							await frames(1)
				await capture(room + "-stage-%d" % a.stage)
		elif room == "home_kitchen":
			var item: Dictionary = a.items[0]
			drag(a,item.node.position,item.target)
			check(not item.placed, "dirty vegetable rejected by basket")
			click(game.camera.unproject_position(a.tap_point))
			check(a.water_on, "physical tap opens water")
			for vegetable: Dictionary in a.items:
				press(game.camera.unproject_position(vegetable.node.position))
				var center: Vector2 = game.camera.unproject_position(a.sink)
				move_to(center,Vector2.ZERO)
				await frames()
				check(vegetable.clean == 0.0, "stationary vegetable under water remains dirty")
				for i in range(25): move_to(center + Vector2(-12 if i % 2 == 0 else 12,0),Vector2(24,0))
				check(vegetable.clean >= 1.0, "moving vegetable under stream removes dirt")
				await capture("vegetable-clean-" + str(a.items.find(vegetable)))
				move_to(game.camera.unproject_position(vegetable.target))
				release(game.camera.unproject_position(vegetable.target))
			check(not a.completed, "washing vegetables requires closing tap")
			click(game.camera.unproject_position(a.tap_point))
		elif room == "home_bathroom":
			click(game.camera.unproject_position(a.tap_point))
			click(game.camera.unproject_position(a.soap.position))
			var center: Vector2 = game.camera.unproject_position(a.hands.position)
			press(center)
			await frames()
			check(a.scrub == 0.0, "stationary hands do not scrub themselves")
			for i in range(36): move_to(center + Vector2(-18 if i % 2 == 0 else 18,0),Vector2(24,0))
			release(center)
			check(a.stage == 2, "scrubbing hands enters rinse stage")
			await capture("hands-rinsing")
			press(game.camera.unproject_position(a.hands.position))
			move_to(game.camera.unproject_position(a.sink + Vector3(0,0,-0.05)))
			await create_timer(2.0).timeout
			release(game.camera.unproject_position(a.sink))
			check(a.stage == 3 and not a.completed, "rinse needs time and tap must still be closed")
			click(game.camera.unproject_position(a.tap_point))
		elif room == "home_estate":
			var can: Dictionary = a.items[0]
			press(game.camera.unproject_position(can.node.position))
			for patch: Dictionary in a.soil:
				move_to(game.camera.unproject_position(patch.point + Vector3(-0.34,0.6,0)))
				await create_timer(1.7).timeout
				check(patch.amount >= 1.0, "pouring wets this patch of soil")
				await capture("watering-" + str(a.soil.find(patch)))
			check(not a.completed, "watering requires putting can back")
			move_to(game.camera.unproject_position(can.target))
			release(game.camera.unproject_position(can.target))
		check(a.completed and bool(state.data.life.home_tasks.get(str(a.task_id),false)), room + " physical action completes and saves")
		await capture(room + "-complete")
		game.household.cancel_task()
		await frames()
		check(game.ui.hud.visible and not game.household.is_active(), room + " exits back to walking HUD")
		await game.change_room("home_hall")
		await game.change_room(room)
		var after: Node3D = game.world.find_child("HOME_TASK_AFTER",true,false)
		var before: Node3D = game.world.find_child("HOME_TASK_BEFORE",true,false)
		check(after.visible and not before.visible, room + " finished room survives leaving and returning")
		print("ROOM TESTED: " + room)
	check(state.data.learning == learning_before, "household actions do not award English mastery")
	var recorded: Dictionary = state.data.life.home_tasks.duplicate(true)
	state.load_state()
	check(state.data.life.home_tasks == recorded and recorded.size() == 8, "all eight completed activities survive a save reload")
	# A cancelled replay restores the already completed room, never clears the record.
	var replay: Node = await begin("home_dining")
	var first: Dictionary = replay.items[0]
	drag(replay,first.node.position,first.target)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	await frames()
	check(not game.household.is_active() and state.data.life.home_tasks.set_dinner, "Escape cancels replay and preserves completed record")
	check(game.world.find_child("HOME_TASK_AFTER",true,false).visible, "cancelled replay restores completed props")
	# Persistence failure must not claim success, and retry must use the same finished work.
	state.data.life.home_tasks.erase("tidy_books")
	var save_path: String = state.save_path
	var a: Node = await begin("home_study")
	var blocker := "user://household-save-blocker-%d" % OS.get_process_id()
	var blocker_file := FileAccess.open(blocker,FileAccess.WRITE)
	blocker_file.store_string("A file deliberately blocks creation of a test save directory.")
	blocker_file.close()
	state.save_path = blocker + "/cannot-save.json"
	for entry: Dictionary in a.items: drag(a,entry.node.position,entry.target)
	check(a.ready_to_save and not a.completed and not state.data.life.home_tasks.has("tidy_books"), "save failure preserves record and leaves finished work retryable")
	state.save_path = save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	a.hud.retry_button.pressed.emit()
	check(a.completed and state.data.life.home_tasks.tidy_books, "save retry commits completed physical work")
	game.household.cancel_task()
	await frames()
	# Real engine input dispatch catches GUI interception, release above the HUD,
	# and the scaled viewport coordinates of a small desktop window.
	root.size = Vector2i(960,640)
	for room: String in ["home_dining","home","home_bedroom","home_study","home_balcony","home_kitchen","home_bathroom","home_estate"]:
		var active: Node = await begin(room)
		var viewport: Rect2 = root.get_visible_rect()
		check(viewport.encloses(active.hud.instruction.get_global_rect()) and viewport.encloses(active.hud.exit_button.get_global_rect()),room + " small-window controls stay visible")
		if room in ["home_kitchen","home_bathroom"]:
			var pos: Vector2 = game.camera.unproject_position(active.tap_point)
			await engine_move(pos)
			await engine_button(pos,true)
			await engine_button(pos,false)
			check(active.water_on,room + " engine mouse events reach faucet through HUD")
		elif not active.items.is_empty():
			var item: Dictionary = active.items[0]
			var start: Vector2 = game.camera.unproject_position(item.node.position)
			check(viewport.has_point(start),room + " source prop visible in small window")
			await engine_move(start)
			await engine_button(start,true)
			check(active.dragged == 0,room + " engine mouse press picks actual prop")
			await engine_move(start + Vector2(45,-35))
			check(item.node.position.distance_to(item.source) > 0.05,room + " engine mouse motion moves prop")
			await engine_button(Vector2(50,45),false)
			check(active.dragged == -1 and item.node.position.is_equal_approx(item.source),room + " release over HUD cancels invalid drop")
		await capture(room + "-small")
		game.application_backgrounded = true
		active.pressed = true
		active._process(0.1)
		check(not active.pressed and active.dragged == -1,room + " focus loss releases held action")
		game.application_backgrounded = false
		game.household.cancel_task()
		await frames()
	var report := {"passed":passed,"failed":failed,"cases":cases,"save":state.save_path}
	var output := FileAccess.open(OUTPUT + "/results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	print("HOUSEHOLD RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
