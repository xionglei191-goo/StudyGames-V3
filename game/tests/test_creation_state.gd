extends SceneTree
const StateScript = preload("res://scripts/game_state.gd")
const Model = preload("res://gameplay/creation_state.gd")
const C = preload("res://gameplay/creation_catalog.gd")
const Canvas = preload("res://ui/creation_canvas.gd")
const Visual = preload("res://gameplay/creation_visuals.gd")
var failures: Array[String] = []
var checks := 0
var state: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, name_value: String) -> void:
	checks+=1
	if not condition:
		failures.append(name_value)
		push_error("CREATION_FAIL: "+name_value)

func action(name_value: String, args: Dictionary = {}, revision: int = -1) -> Dictionary:
	return state.creation_action(name_value,args,revision)

func design(recipe: String, text_value: String = "") -> String:
	var d := C.blank_design(recipe)
	d.text=text_value
	var result := action("design",{"design":d})
	check(result.ok,"save design "+recipe)
	return str(result.get("id",""))

func run() -> void:
	state=StateScript.new()
	state.save_path="user://creation-state-test-%s.json" % OS.get_process_id()
	root.add_child(state)
	check(not action("start").ok,"new home gates entry")
	state.data.journey.home_steps=["H01","H02","H03","H04"]
	var legacy: Dictionary = state.snapshot()
	legacy.erase("creation")
	legacy.coins=257
	legacy.apples=9
	legacy.cakes=4
	var migrated: Dictionary = state._normalize_state(legacy)
	check(migrated.ok and migrated.state.coins==257 and migrated.state.cakes==4,"legacy balances migrate intact")
	state.data=migrated.state
	check(action("start").ok,"start home with no letters")
	check(state.data.creation.materials.wood==6 and state.data.coins==257,"starter materials only")
	var before: Dictionary = state.snapshot()
	check(not action("start").ok and state.data==before,"starter never twice")
	var art := C.blank_design("frame")
	art.pattern="f".repeat(4096)
	art.text="MY HOME"
	check(action("draft",{"design":art}).ok,"draft saved without material use")
	check(state.data.creation.materials.wood==6 and state.data.coins==257,"draft free")
	state.load_state()
	check(state.data.creation.draft.pattern==art.pattern,"draft roundtrip")
	var did := str(action("design",{"design":art}).get("id",""))
	var revision: int = int(state.data.creation.revision)
	var first := action("craft",{"id":did},revision)
	check(first.ok,"craft once")
	check(state.data.creation.materials.wood==5 and state.data.creation.materials.fiber==3,"precise material debit")
	before=state.snapshot()
	check(not action("craft",{"id":did},revision).ok and state.data==before,"duplicate craft rejected")
	var second := action("craft",{"id":did})
	check(second.ok,"second physical instance")
	check(action("gift",{"id":first.id,"friend":"npc_bear_uncle"}).ok,"gift keeps provenance")
	art.color=9
	art.pattern="a".repeat(4096)
	check(action("design",{"id":did,"design":art}).ok,"revise existing design")
	check(action("apply_design",{"id":second.id,"design":did}).ok,"apply own instance")
	check(state.data.creation.items[first.id].design.color==2 and state.data.creation.items[second.id].design.color==9,"gift immutable snapshot")
	check(not action("apply_design",{"id":first.id,"design":did}).ok,"cannot revise gifted object")
	var learning: Dictionary = state.data.learning.duplicate(true)
	var events: Array = state.data.v4.stealth_events.duplicate(true)
	check(action("place",{"id":second.id,"room":"home","position":[2,0,-2],"rotation":90}).ok,"place instance")
	check(action("store",{"id":second.id}).ok,"store same instance")
	check(action("community",{"id":second.id,"room":"landmark_F"}).ok,"lend actual instance")
	check(not action("stock",{"id":second.id}).ok,"lent object cannot be sold simultaneously")
	check(action("store",{"id":second.id}).ok and state.data.creation.community_done,"recall preserves community fact")
	check(state.data.learning==learning and state.data.v4.stealth_events==events,"life actions never award language correctness")
	check(not action("visit_start",{"id":"textbook_anne","room":"home"}).ok,"unmet Anne unavailable")
	state.data.v4.free_decor_placed["home"]=[{"id":"reading_sofa","x":4,"y":0,"z":2,"rot":0}]
	var original_count: int=state.data.creation.items.size()
	check(action("visit_start",{"id":"npc_bear_uncle","room":"home"}).ok,"visit can use old furniture")
	var old_visit := action("visit_used",{"id":"legacy:home:0"})
	check(old_visit.ok,"old sofa is a real use target")
	check(state.data.creation.items.size()==original_count,"old furniture never duplicates into handmade inventory")
	check(action("visit_end").ok,"finish old furniture visit")
	var table_design := design("table")
	var table := action("craft",{"id":table_design})
	check(table.ok,"craft functional table")
	check(action("place",{"id":table.id,"room":"home","position":[4,0,-2],"rotation":0}).ok,"place table")
	check(action("learn",{"room":"landmark_C"}).ok,"Milo unlock")
	check(not state.data.quests.delivery_done,"Milo does not complete apple quest")
	var cake_id := design("cake")
	var cake := action("craft",{"id":cake_id})
	check(cake.ok and state.data.apples==6 and state.data.cakes==5,"cake shares old counters")
	check(action("place_on",{"id":cake.id,"support":table.id}).ok,"food can be placed on table")
	check(state.data.creation.items[cake.id].position[1]==0.98,"tabletop height retained")
	check(action("place",{"id":table.id,"room":"home","position":[5,0,-2],"rotation":90}).ok and state.data.creation.items[cake.id].position[0]==5,"table moves its actual contents")
	check(action("store",{"id":table.id}).ok and state.data.creation.items[cake.id].where=="inventory","storing table returns contents once")
	check(state.craft_cake() and state.data.apples==3 and state.data.cakes==6,"old workbench creates one recorded cake")
	var count: int = state.data.creation.items.size()
	check(state.sell_cake() and state.data.cakes==5 and state.data.creation.items.size()==count,"old sale takes legacy stock first")
	check(action("stock",{"id":cake.id}).ok,"stock cake")
	check(action("stall_open",{"room":"home_estate"}).ok,"open stall")
	revision=int(state.data.creation.revision)
	var coins: int = int(state.data.coins)
	check(action("sell",{"id":cake.id,"room":"home_estate"},revision).ok,"confirm sale")
	check(state.data.coins==coins+20 and state.data.cakes==4,"sale credits once and debits global cake")
	before=state.snapshot()
	check(not action("sell",{"id":cake.id,"room":"home_estate"},revision).ok and state.data==before,"replayed sale cannot credit")
	state.load_state()
	check(state.data.creation.stall.open and state.data.creation.stall.served==1 and state.data.creation.stall.income==20,"paused stall roundtrip")
	var order_id := ""
	for oid: String in state.data.creation.orders:
		if state.data.creation.orders[oid].kind==1: order_id=oid
	check(not order_id.is_empty(),"frame order exists")
	check(action("order_accept",{"id":order_id}).ok,"accept order")
	before=state.snapshot()
	check(action("order_cancel",{"id":order_id}).ok and state.data.creation.items==before.creation.items and state.data.creation.materials==before.creation.materials,"cancel order preserves work and materials")
	action("order_accept",{"id":order_id})
	check(not action("order_deliver",{"id":second.id,"order":order_id,"room":"home"}).ok,"orders require destination")
	check(action("order_deliver",{"id":second.id,"order":order_id,"room":"landmark_F"}).ok,"deliver frame")
	check(not action("order_deliver",{"id":second.id,"order":order_id,"room":"landmark_F"}).ok,"order cannot settle twice")
	for n in range(4): check(action("gather",{"id":"wood","room":"home_estate"}).ok,"daily wood "+str(n))
	check(not action("gather",{"id":"wood","room":"home_estate"}).ok,"daily cap")
	state.load_state()
	check(not action("gather",{"id":"wood","room":"home_estate"}).ok,"reload cannot refresh material")
	state.data.day+=5
	check(action("gather",{"id":"wood","room":"home_estate"}).ok and state.data.creation.gathered.wood.count==1,"skipped days produce only current batch")
	state.data.harvested=2
	check(action("gather",{"id":"apple","room":"landmark_A"}).ok and state.data.harvested==3,"apples share daily cap")
	check(not state.collect_apple(),"old gather also capped")
	check(state.data.creation.stamps.has("apple") and state.data.creation.stamps.has("check"),"earned stamps persisted")
	var bad := C.blank_design("frame")
	bad.pattern="corrupted"
	check(not action("draft",{"design":bad}).ok,"invalid pattern rejected")
	before=state.snapshot()
	var old_path: String = state.save_path
	state.save_path="res://project.godot/cannot-write.json"
	check(not action("buy",{"id":"wood"}).ok and state.data==before,"save failure rolls entire transaction back")
	state.save_path=old_path
	check(state.save_state(),"final valid state saves")
	var saved: Dictionary = state.snapshot()
	state.load_state()
	check(state.data.creation==saved.creation and state.data.coins==saved.coins,"full creation roundtrip")
	check(state.data.journey.u1.steps.is_empty() and not state.data.journey.u1.completed,"life never invents U1 progress")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.creation.items[first.id].where="inventory"
	malformed.creation.items[first.id].design.recipe="cake"
	malformed.cakes=0
	check(not state._normalize_state(malformed).ok,"reject impossible shared cake inventory")
	# An older completed journey may bring known companions; new life actions only
	# observe those facts and never manufacture them.
	state.data.journey.legacy_compatible=true
	for step in range(1,11):
		check(state.journey_complete_u1_step("U1-%02d" % step),"known-friend fixture step "+str(step))
	check(action("learn",{"room":"landmark_F"}).ok,"flower tutorial")
	var journey_before: Dictionary=state.data.journey.duplicate(true)
	for friend: String in ["textbook_lingling","textbook_anne"]:
		check(action("visit_start",{"id":friend,"room":"home"}).ok,"known companion invite "+friend)
		check(action("visit_used",{"id":"legacy:home:0"}).ok,"known companion uses original furniture "+friend)
		action("visit_end")
	check(state.data.creation.stamps.size()==8,"all eight stamps have obtainable sources")
	check(state.data.journey==journey_before,"companion visits preserve story facts")
	for recipe: String in C.RECIPES:
		var cost := 0
		for material: String in C.RECIPES[recipe].cost: cost+=int(C.RECIPES[recipe].cost[material])*int(C.MATERIALS[material].buy)
		check(int(C.RECIPES[recipe].recycle)<cost and int(C.RECIPES[recipe].sale)-cost in [2,3],"recipe economy "+recipe)
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.size=Vector2(320,320)
	var press_event := InputEventMouseButton.new()
	press_event.button_index=MOUSE_BUTTON_LEFT
	press_event.pressed=true
	press_event.position=Vector2(12,17)
	canvas._gui_input(press_event)
	press_event.pressed=false
	canvas._gui_input(press_event)
	check(canvas.pattern[3*64+2]=="9","brush maps input to real cell")
	canvas.undo()
	check(canvas.pattern=="0".repeat(4096),"gesture undo restores drawing")
	canvas.flood(Vector2i(0,0),4)
	check(canvas.pattern=="4".repeat(4096),"bounded flood fills complete region")
	canvas.tool="erase"
	canvas.paint_at(Vector2(17,17))
	check(canvas.pattern[3*64+3]=="0","eraser restores background pixel")
	for recipe: String in ["sign","table","rug","frame"]:
		var drawing:=C.blank_design(recipe)
		drawing.pattern="a".repeat(4096)
		var node:=Visual.build(drawing)
		var textured := false
		for mesh: Node in node.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_texture!=null:
				textured=true
				check(mesh.material_override.albedo_texture.get_image().get_pixel(0,0).is_equal_approx(Color(C.PALETTE[10])),"real painted texture "+recipe)
		check(textured,"painted surface exists "+recipe)
		node.free()
	canvas.queue_free()
	print("CREATION_STATE: %d checks, %d failures" % [checks,failures.size()])
	state.queue_free()
	quit(0 if failures.is_empty() else 1)
