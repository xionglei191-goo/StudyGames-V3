extends SceneTree
## Full-scene test with a process-specific profile; never reads the player's profile.
const C = preload("res://gameplay/creation_catalog.gd")
const Model = preload("res://gameplay/creation_state.gd")
const Visual = preload("res://gameplay/creation_visuals.gd")
var failures: Array[String] = []
var checks := 0
var game: Node3D
var state: Node
var studio: Node3D
var capture_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks+=1
	if not condition:
		failures.append(title)
		push_error("CREATION_FLOW_FAIL: "+title)

func frames(count: int = 3) -> void:
	for n in range(count): await process_frame

func wait_ready() -> bool:
	for n in range(1200):
		await process_frame
		if game.scene_ready and not game.loading_room and game.nav_ready: return true
	return false

func press(text_value: String) -> bool:
	for node: Node in game.ui.panel_box.find_children("*","Button",true,false):
		if node.text == text_value and not node.disabled:
			node.pressed.emit()
			return true
	check(false,"button present: "+text_value)
	return false

func capture(file_name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(capture_dir.path_join(file_name+".png"))
	check(error==OK,"capture "+file_name)

func find_position(id: String) -> Vector3:
	var bounds: Rect2 = game.player.bounds.grow(-2)
	for z in range(floori(bounds.position.y),ceili(bounds.end.y)):
		for x in range(floori(bounds.position.x),ceili(bounds.end.x)):
			var position_value := Vector3(x,0,z)
			if studio.placement_error(id,position_value,0).is_empty(): return position_value
	return Vector3(INF,INF,INF)

func create_work(recipe: String) -> String:
	var saved: Dictionary = state.creation_action("design",{"design":C.blank_design(recipe)})
	if not saved.ok: check(false,"create design "+recipe); return ""
	var made: Dictionary = state.creation_action("craft",{"id":saved.id})
	check(made.ok,"create work "+recipe)
	return str(made.get("id",""))

func run() -> void:
	root.size=Vector2i(1440,900)
	AudioServer.set_bus_mute(0,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--creation-captures="): capture_dir=arg.trim_prefix("--creation-captures=")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	check(await wait_ready(),"main scene ready")
	state=root.get_node("State")
	studio=game.creation
	check(state.save_path.begins_with("user://validation-"),"isolated test profile")
	state.data.journey.home_steps=["H01","H02","H03","H04"]
	check(state.save_state(),"home fixture valid")
	game.journey.show_hub()
	check(press("生活工坊 · 设计、制作与小摊"),"travel-book entry")
	await frames()
	check(game.ui.current_panel=="creation","opens creation UI")
	press("领取材料，开始创作")
	await frames()
	check(state.data.creation.started,"starter through UI")
	await capture("01-wishes")
	studio.show_recipes()
	await frames()
	check(game.ui.panel_box.find_children("*","Button",true,false).size()>12,"recipes visible")
	studio.edit("",C.blank_design("sign"))
	await frames()
	studio._painter.tool="stamp"
	studio._painter.stamp="star"
	studio._painter.ink=7
	studio._painter.paint_at(Vector2(140,140))
	studio._text_field.text="MY HOME"
	studio._text_field.text_changed.emit("MY HOME")
	studio._name_field.text="星星阅读角"
	studio._name_field.text_changed.emit("星星阅读角")
	check(studio._stash(),"editor autosave")
	var pixels: String=state.data.creation.draft.pattern
	check(pixels!="0".repeat(4096),"stamp changes real pixels")
	var did: String=studio.save_design(false)
	check(not did.is_empty(),"save design UI")
	await frames()
	await capture("02-workshop")
	studio.craft_confirm(did)
	await frames()
	press("确认")
	await frames()
	check(state.data.creation.items.size()==1,"craft from confirmation")
	var sign_id: String=state.data.creation.items.keys()[0]
	check(state.data.creation.items[sign_id].design.text=="MY HOME","accurate sign text snapshot")
	studio.show_designs()
	await capture("03-design-book")
	game._close()
	await game.change_room("home")
	await frames(8)
	check(game.room=="home","home room loaded")
	var sign_pos := find_position(sign_id)
	check(sign_pos.is_finite(),"find valid place for sign")
	if sign_pos.is_finite():
		await studio.start_placement(sign_id)
		studio.cursor_pos=sign_pos
		studio.update_ghost()
		await frames()
		await capture("04-placement")
		studio.place()
		await frames(12)
		check(state.data.creation.items[sign_id].where=="placed","placed from UI")
		check(studio.world_items.get_node_or_null(sign_id)!=null,"real sign mesh in room")
		check(not studio.placement_error(sign_id,game.metadata.spawn,0).is_empty(),"entry space protected")
		await capture("05-home-sign")
	# Fixture supplies resources only; recipes still follow the normal unlock actions.
	for material: String in state.data.creation.materials: state.data.creation.materials[material]=80
	state.data.apples=24
	state.creation_action("learn",{"room":"landmark_F"})
	state.creation_action("learn",{"room":"landmark_C"})
	var stool_id := create_work("stool")
	var stool_pos := find_position(stool_id)
	check(stool_pos.is_finite(),"valid seat placement")
	if stool_pos.is_finite():
		await studio.start_placement(stool_id)
		studio.cursor_pos=stool_pos
		studio.update_ghost()
		studio.place()
		await frames(12)
		check(not studio.placement_error(sign_id,stool_pos,0).is_empty(),"overlap blocked")
		studio.invite("npc_bear_uncle")
		if is_instance_valid(studio._visit_actor):
			studio._visit_actor.set_clock_state(false,false,false,false)
			var elapsed_before: float=studio._visit_elapsed
			studio._process(50)
			check(is_instance_valid(studio._visit_actor) and studio._visit_elapsed==elapsed_before,"paused visit does not time out")
			studio._visit_actor.set_clock_state(true,true,false,false)
		# Headless mode can run faster than wall time; advance bounded frames explicitly.
		for n in range(2400):
			game.application_backgrounded=false
			game.living._focus_backgrounded=false
			await physics_frame
			if state.data.creation.visit.get("status", "")=="using": break
		check(state.data.creation.visit.get("status", "")=="using","guest walks to and uses seat")
		if is_instance_valid(studio._visit_actor):
			check(studio._visit_actor.current_action=="sit","real seated pose")
			check(studio._visit_actor.animation_player.has_animation("life/sit"),"retargeted seated animation")
		await capture("06-guest-using-seat")
		if DisplayServer.get_name()!="headless" and state.data.creation.visit.get("status", "")=="using":
			await studio.take_photo()
			check(state.data.creation.visit.has("photo_path"),"real visit photograph saved")
			check(FileAccess.file_exists(state.data.creation.visit.get("photo_path","")),"photograph file exists")
		state.creation_action("visit_end")
		studio.clear_visitor()
	var before_learning: Dictionary = state.data.learning.duplicate(true)
	var before_events: Array = state.data.v4.stealth_events.duplicate(true)
	state.creation_action("store",{"id":sign_id})
	check(state.creation_action("store",{"id":stool_id}).ok,"recall seat before lending")
	check(state.creation_action("community",{"id":stool_id,"room":"landmark_F"}).ok,"lend seat")
	await game.change_room("landmark_F")
	await frames(12)
	check(studio.world_items.get_node_or_null(stool_id)!=null,"community displays actual work")
	studio.invite("npc_bear_uncle")
	for n in range(1800):
		game.application_backgrounded=false
		game.living._focus_backgrounded=false
		await physics_frame
		if state.data.creation.visit.get("status", "")=="using": break
	check(state.data.creation.visit.get("status", "")=="using","community seat is reachable and usable")
	await capture("07-community")
	state.creation_action("visit_end")
	studio.clear_visitor()
	state.creation_action("store",{"id":stool_id})
	check(state.data.creation.community_done,"community history remains after recall")
	for recipe: String in C.RECIPES:
		check(state.data.creation.recipes.has(recipe),"recipe available "+recipe)
		var visual := Visual.build(C.blank_design(recipe))
		check(visual.get_child_count()>0,"physical form "+recipe)
		visual.free()
	var cake_id := create_work("cake")
	state.creation_action("stock",{"id":cake_id})
	await game.change_room("home_estate")
	await frames(12)
	studio.show_stall()
	press("开始营业")
	await frames(12)
	check(state.data.creation.stall.open,"open stall UI")
	check(is_instance_valid(studio._customer),"customer present in scene")
	await capture("08-stall")
	game._close()
	for n in range(600):
		game.application_backgrounded=false
		game.living._focus_backgrounded=false
		await physics_frame
		if is_instance_valid(studio._customer) and studio._customer.motion_path.is_empty(): break
	check(is_instance_valid(studio._customer) and studio._customer.position.distance_to(studio.stall_position()+Vector3(0,0,1.5))<1.0,"customer walks to actual stall")
	await capture("11-stall-world")
	studio.show_stall()
	press("介绍作品并确认成交")
	var coins: int=int(state.data.coins)
	press("确认")
	await frames(12)
	check(state.data.coins==coins+20 and state.data.creation.items[cake_id].where=="sold","sale UI settles one cake")
	check(state.data.learning==before_learning and state.data.v4.stealth_events==before_events,"full life flow adds no fake English answers")
	studio.show_inventory()
	await capture("09-inventory")
	studio.show_memories()
	await capture("10-memories")
	# Closing an edited draft flushes it before the modal disappears.
	studio.edit(did,state.data.creation.designs[did])
	await frames()
	root.size=Vector2i(960,640)
	await frames(5)
	await capture("12-small-workshop")
	check(game.ui.panel.get_global_rect().end.x<=game.ui.root.size.x and game.ui.panel.get_global_rect().end.y<=game.ui.root.size.y,"workshop fits minimum window")
	studio._name_field.text="明天继续的设计"
	studio._name_field.text_changed.emit(studio._name_field.text)
	game._close()
	check(state.data.creation.draft.name=="明天继续的设计","close flushes draft")
	var saved: Dictionary=state.snapshot()
	state.load_state()
	check(state.data.creation==saved.creation,"complete flow save roundtrip")
	print("CREATION_FLOW: %d checks, %d failures" % [checks,failures.size()])
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("flow-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"save_path":state.save_path},"\t"))
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
