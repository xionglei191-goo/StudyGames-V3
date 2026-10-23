extends Node3D
## In-world orchard activity. Durable ownership changes only after State commits.
signal discovery_finished(mode: String)
signal leave_requested
signal phase_changed(phase: String)
const Style = preload("res://ui/island_theme.gd")
const WorldArt = preload("res://scripts/world_art.gd")
const ACTOR_ID := "npc_rabbit_gardener"
var game: Node3D
var actor: Node3D
var apple: Node3D
var branch: Node3D
var basket: MeshInstance3D
var apple_target: Vector3
var basket_target: Vector3
var pick_stand: Vector3
var place_stand: Vector3
var start_stand: Vector3
var pick_facing := Vector3(0,0,-1)
var place_facing := Vector3(0,0,1)
var camera_focus: Vector3
var camera_size := 13.0
var phase := "ready"
var round_id := ""
var mode := "independent_action"
var paused := false
var demonstration := false
var clock := 0.0
var phase_time := 0.0
var contact_distances: Array[Dictionary] = []
var saved_player_position: Vector3
var saved_player_visible := true
var saved_player_collision_layer := 0
var saved_player_collision_mask := 0
var _player_taken := false
var panel_root: Control
var instruction: Label
var detail: Label
var main_button: Button
var pause_button: Button
var demo_button: Button
var close_button: Button
var discovery_panel: PanelContainer
var target_label: Label3D
var target_ring: MeshInstance3D
var _apple_hit: Area3D
var _basket_hit: Area3D
var _settle_start := Vector3.ZERO
var _settle_elapsed := -1.0
var _apple_on_branch := Transform3D.IDENTITY
var _original_rabbit: Array[Node3D] = []
var _configured := false

func setup(owner_game: Node3D) -> bool:
	game = owner_game
	if game.room!="landmark_A": return false
	var source := game.world.find_child("A_Tree_3_Fruit_0",true,false) as MeshInstance3D
	var trunk := game.world.find_child("A_Tree_3_Trunk",true,false) as MeshInstance3D
	basket = game.world.find_child("A_Entrance_Basket",true,false) as MeshInstance3D
	if source==null or trunk==null or basket==null:
		push_warning("Orchard authored props missing: "+str([source,trunk,basket]))
		return false
	var anchor := Vector3(-6.95,0,-0.5)
	for entry: Dictionary in game.interactions:
		if str(entry.id)=="memory_02": anchor=entry.position
	var to_tree := trunk.global_position-anchor
	to_tree.y=0
	# The near tree's low branch stays visible from the authored isometric camera.
	pick_stand = _walkable(anchor+Vector3(0.75,0,0.8))
	start_stand = _walkable(anchor+Vector3(2.5,0,2.0))
	# This activity temporarily hands control to the rabbit at the guide's arrival.
	# The hidden player must not block that actor or its validated navigation cells.
	saved_player_position=game.player.position
	saved_player_visible=game.player.visual.visible
	saved_player_collision_layer=game.player.collision_layer
	saved_player_collision_mask=game.player.collision_mask
	_player_taken=true
	game.player.visual.hide()
	game.player.collision_layer=0
	game.player.collision_mask=0
	actor = game.living.spawn_actor(ACTOR_ID,start_stand,{"movement_speed":1.9,"validate_position":false})
	if actor==null or not actor.has_method("get_action_contact_transform"):
		push_warning("Orchard actor spawn failed at "+str(start_stand))
		return false
	pick_facing=trunk.global_position-pick_stand
	pick_facing.y=0
	pick_facing=pick_facing.normalized()
	actor.face(actor.global_position+pick_facing,true)
	var contact: Transform3D = actor.get_action_contact_transform("pick")
	apple_target = Transform3D(actor.global_basis,pick_stand)*contact.origin
	var basket_box := basket.get_aabb()
	basket_target = basket.global_transform*(basket_box.position+Vector3(basket_box.size.x*0.5,basket_box.size.y-0.07,basket_box.size.z*0.5))+Vector3.UP*0.16
	actor.face(actor.global_position+Vector3(0,0,1),true)
	var place_contact: Transform3D = actor.get_action_contact_transform("place")
	var best := INF
	for angle: float in [0.0,PI*0.5,PI,-PI*0.5]:
		var local_offset: Vector3 = Basis(Vector3.UP,angle)*place_contact.origin
		var candidate := _clear_stand(basket_target-local_offset)
		if candidate==Vector3.INF: continue
		var hand_point := candidate+local_offset
		var error := hand_point.distance_to(basket_target)
		if error<best:
			best=error
			place_stand=candidate
			place_facing=Basis(Vector3.UP,angle)*Vector3(0,0,1)
	if best>0.40:
		push_warning("Orchard basket contact needs a reachable placement pose: "+str(best))
		return false
	actor.face(actor.global_position+pick_facing,true)
	game.player.path.clear()
	game.player.velocity=Vector3.ZERO
	game.ui.hud.hide()
	game.ui.prompt.hide()
	game.ui.controls_hint.hide()
	game.ui.bubble_panel.hide()
	game.ui.toast_label.hide()
	game.feedback.highlight({})
	for node: Node in game.world.get_children():
		if node is Node3D and (str(node.name)=="Rabbit" or node is Label3D) and Vector2(node.position.x+0.8,node.position.z-2.4).length()<0.5:
			_original_rabbit.append(node)
			node.hide()
	apple=Node3D.new()
	apple.name="InteractiveApple"
	add_child(apple)
	var fruit := WorldArt.create_prop("apple")
	if fruit != null:
		apple.add_child(fruit)
		# The detailed fruit keeps the original activity's 0.8 m picking hit area.
		fruit.scale = Vector3.ONE * 0.90
	apple.global_position=apple_target
	_apple_on_branch=apple.global_transform
	branch=Node3D.new()
	branch.name="LowPickingBranch"
	add_child(branch)
	var branch_start := Vector3(trunk.global_position.x,apple_target.y+0.65,trunk.global_position.z)
	_cylinder_between(branch,branch_start,apple_target+Vector3.UP*0.26,0.065,Color("966c46"))
	_cylinder_between(branch,apple_target+Vector3.UP*0.26,apple_target+Vector3.UP*0.14,0.025,Color("66835c"))
	_apple_hit=_hit_area(apple,Vector3.ZERO,Vector3(0.8,0.8,0.8),"apple")
	_basket_hit=_hit_area(self,basket_target+Vector3(0,-0.15,0),Vector3(1.1,0.8,1.1),"basket")
	target_label=Label3D.new()
	target_label.font=load("res://assets/fonts/IslandSans.otf")
	target_label.font_size=42
	target_label.pixel_size=0.007
	target_label.modulate=Style.PAPER
	target_label.outline_modulate=Style.INK
	target_label.outline_size=9
	target_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	target_label.no_depth_test=true
	add_child(target_label)
	target_ring=MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius=0.38
	ring.outer_radius=0.43
	target_ring.mesh=ring
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color=Color("e5bd69")
	ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	target_ring.material_override=ring_material
	add_child(target_ring)
	camera_focus=pick_stand.lerp(place_stand,0.5)+Vector3(0,-0.5,0)
	_build_hud()
	actor.action_contact.connect(_contact)
	actor.action_finished.connect(_action_finished)
	var stored: Dictionary = State.journey_orchard_snapshot()
	round_id=str(stored.round_id)
	if str(stored.get("completion_mode",""))!="": mode=str(stored.completion_mode)
	if round_id.is_empty(): round_id=_new_round()
	if stored.stage=="carrying":
		actor.global_position=start_stand
		_attach_apple()
		actor.play_action("carry")
		_set_phase("carrying")
	elif stored.stage=="deposited":
		apple.global_position=basket_target-Vector3.UP*0.15
		actor.global_position=place_stand
		_set_phase("deposited")
		_show_discovery()
	else:
		_set_phase("ready")
	_configured=true
	return true

func _new_round() -> String:
	return "orchard-"+str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())

func _walkable(point: Vector3) -> Vector3:
	var cell := Vector2i(roundi(point.x/game.NAV_CELL),roundi(point.z/game.NAV_CELL))
	cell=game._nearest_walkable_cell(cell,point)
	return Vector3(cell.x*game.NAV_CELL,float(game.nav_heights.get(cell,0.0))+0.03,cell.y*game.NAV_CELL)

func _clear_stand(point: Vector3) -> Vector3:
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*5,point-Vector3.UP*5,4)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return Vector3.INF
	var candidate: Vector3=hit.position+Vector3.UP*0.03
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=(actor.get_node("ActorCollision") as CollisionShape3D).shape
	query.transform=Transform3D(Basis.IDENTITY,candidate+Vector3.UP*0.84)
	query.collision_mask=1
	return candidate if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty() else Vector3.INF

func _path_to(destination: Vector3) -> PackedVector3Array:
	var from := Vector2i(roundi(actor.position.x/game.NAV_CELL),roundi(actor.position.z/game.NAV_CELL))
	var to := Vector2i(roundi(destination.x/game.NAV_CELL),roundi(destination.z/game.NAV_CELL))
	from=game._nearest_walkable_cell(from,actor.position)
	to=game._nearest_walkable_cell(to,destination)
	var result := PackedVector3Array()
	for point: Vector2 in game.navigation.get_point_path(from,to):
		var key := Vector2i(roundi(point.x/game.NAV_CELL),roundi(point.y/game.NAV_CELL))
		result.append(Vector3(point.x,float(game.nav_heights.get(key,0.0))+0.03,point.y))
	if not result.is_empty(): result.append(destination)
	return result

func _build_hud() -> void:
	panel_root=Control.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.ui.root.add_child(panel_root)
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	header.offset_left=-390
	header.offset_right=390
	header.offset_top=22
	header.offset_bottom=130
	header.add_theme_stylebox_override("panel",Style.box(Style.PAPER,22,18))
	panel_root.add_child(header)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	header.add_child(column)
	instruction=Style.text("和兔兔一起采苹果",26)
	instruction.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(instruction)
	detail=Style.text("",18,Style.MUTED)
	detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left=-440
	footer.offset_right=440
	footer.offset_top=-110
	footer.offset_bottom=-22
	footer.add_theme_stylebox_override("panel",Style.box(Style.PAPER,22,14))
	panel_root.add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	footer.add_child(row)
	main_button=_button(row,"点苹果",func(): primary_action())
	main_button.theme_type_variation="PrimaryButton"
	demo_button=_button(row,"请兔兔示范",func(): start_demonstration())
	pause_button=_button(row,"暂停",func(): set_paused(not paused))
	close_button=_button(row,"下次再来",func(): leave_requested.emit())
	panel_root.resized.connect(_fit_hud.bind(header,footer))
	_fit_hud.call_deferred(header,footer)

func _fit_hud(header: Control,footer: Control) -> void:
	if not is_instance_valid(panel_root): return
	var half := minf(440,(panel_root.size.x-32)*0.5)
	footer.offset_left=-half
	footer.offset_right=half
	header.offset_left=-minf(390,half)
	header.offset_right=minf(390,half)

func _button(parent: Node,text: String,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(120,52)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _set_phase(value: String) -> void:
	phase=value
	phase_time=0
	var words := {
		"ready":["① 点枝头的红苹果","兔兔会走近低枝，伸手摘下这颗苹果。","摘苹果"],
		"walking_pick":["兔兔正走向苹果树","看看它怎样绕过树干，走到低枝旁。","正在走近…"],
		"picking":["伸手，轻轻摘下来","苹果碰到手后，才会离开树枝。","正在摘取…"],
		"lifting":["摘到了，先拿稳苹果","兔兔把苹果抱稳后，再送去篮子。","正在拿稳…"],
		"carrying":["② 把苹果送到篮子里","点场景中的篮子，兔兔会拿着苹果走过去。","放进篮子"],
		"walking_place":["拿稳苹果，走向篮子","苹果一直跟着兔兔的手移动。","正在搬运…"],
		"placing":["弯下身，把苹果轻轻放好","等苹果碰到篮口，再松开手。","正在放下…"],
		"deposited":["③ 苹果已经在篮子里啦！","Apple，从这颗苹果认识 A 和 a。","看看 Aa"],
		"save_pick":["苹果还在枝头，先等一等","记录还没保存成功。点“再试一次”后继续。","再试一次"],
		"save_place":["先拿稳苹果，等记录保存好","点“再试一次”，保存后才会松手。","再试一次"]
	}
	var text: Array=words.get(value,words.ready)
	instruction.text=str(text[0])
	detail.text=str(text[1])
	main_button.text=str(text[2])
	main_button.disabled=paused or value in ["walking_pick","picking","lifting","walking_place","placing","deposited"]
	demo_button.disabled=paused or value not in ["ready","carrying"]
	target_label.visible=value in ["ready","carrying"]
	target_label.text="点这颗苹果" if value=="ready" else "点这个篮子"
	target_label.global_position=(apple_target if value=="ready" else basket_target)+Vector3.UP*0.65
	target_ring.visible=value in ["ready","carrying"]
	target_ring.global_position=(apple_target if value=="ready" else basket_target)-Vector3.UP*0.19
	phase_changed.emit(value)

func primary_action() -> void:
	if paused: return
	match phase:
		"ready": _start_walk(pick_stand,"walking_pick")
		"carrying": _start_walk(place_stand,"walking_place")
		"save_pick":
			_set_phase("picking")
			actor.play_action("pick",round_id+":pick")
		"save_place":
			_set_phase("placing")
			actor.play_action("place",round_id+":place")
		"deposited": _show_discovery()

func _start_walk(destination: Vector3,next_phase: String) -> void:
	var points:=_path_to(destination)
	if points.is_empty() or not actor.set_path(points):
		detail.text="这条路暂时走不通，换个位置再来试试。"
		return
	_set_phase(next_phase)

func _process(delta: float) -> void:
	if not _configured or paused or game.application_backgrounded: return
	clock+=delta
	phase_time+=delta
	if phase in ["walking_pick","walking_place"]:
		var destination:=pick_stand if phase=="walking_pick" else place_stand
		var flat:=actor.global_position-destination
		flat.y=0
		if flat.length()<0.16:
			actor.set_path(PackedVector3Array())
			actor.face(actor.global_position+(pick_facing if phase=="walking_pick" else place_facing),true)
			var action:="pick" if phase=="walking_pick" else "place"
			_set_phase("picking" if action=="pick" else "placing")
			actor.play_action(action,round_id+":"+action)
		elif actor.motion_path.is_empty() or phase_time>20:
			_set_phase("ready" if phase=="walking_pick" else "carrying")
			detail.text="兔兔停在路边了，再点一次目标继续。"
	if demonstration and phase=="carrying" and phase_time>0.65:
		primary_action()
	if _settle_elapsed>=0:
		_settle_elapsed+=delta
		var amount:=clampf(_settle_elapsed/0.35,0,1)
		apple.global_position=_settle_start.lerp(basket_target-Vector3.UP*0.15,amount*amount)
		if amount>=1: _settle_elapsed=-1

func _contact(_id: String,action: String,key: String,_invocation: int,_socket: Transform3D) -> void:
	if key!=round_id+":pick" and key!=round_id+":place": return
	if phase=="picking": _commit_pick()
	elif phase=="placing": _commit_place()

func _commit_pick() -> void:
	var socket: Transform3D=actor.get_hand_socket_transform()
	var distance:=socket.origin.distance_to(apple.global_position)
	contact_distances.append({"action":"pick","distance":distance,"round_id":round_id})
	if distance>0.22:
		_set_phase("ready")
		detail.text="兔兔还没够到苹果，先调整站位再试一次。"
		return
	if not State.journey_orchard_commit("ready","carrying",round_id,mode):
		_set_phase("save_pick")
		return
	_attach_apple()
	game.sounds.play("collect")
	_set_phase("lifting")

func _attach_apple() -> void:
	if apple.get_parent()!=actor.hand_socket: apple.reparent(actor.hand_socket)
	apple.transform=Transform3D.IDENTITY
	_apple_hit.collision_layer=0

func _commit_place() -> void:
	var distance:=apple.global_position.distance_to(basket_target)
	contact_distances.append({"action":"place","distance":distance,"round_id":round_id})
	if distance>0.22:
		_set_phase("carrying")
		detail.text="篮子还没接住苹果，调整一下位置再放。"
		actor.play_action("carry")
		return
	if not State.journey_orchard_commit("carrying","deposited",round_id,mode):
		_set_phase("save_place")
		actor.play_action("carry")
		return
	apple.reparent(self)
	_settle_start=apple.global_position
	_settle_elapsed=0
	game.sounds.play("collect")
	_set_phase("deposited")
	demonstration=false

func _action_finished(_id: String,action: String) -> void:
	if phase=="lifting" and action in ["pick","pick_item","take_item"]:
		actor.play_action("carry")
		_set_phase("carrying")
	if phase=="deposited": _show_discovery()

func start_demonstration() -> void:
	if paused or phase not in ["ready","carrying"]: return
	if phase=="carrying" and not State.journey_orchard_commit("ready","carrying",round_id,"demonstration_viewed"):
		detail.text="记录还没有保存好，先拿稳苹果，稍后再请兔兔示范。"
		return
	demonstration=true
	mode="demonstration_viewed"
	primary_action()

func set_paused(value: bool) -> void:
	paused=value
	pause_button.text="继续" if paused else "暂停"
	game.living.set_context({"paused":paused})
	if paused:
		detail.text="先歇一会儿。点“继续”后，兔兔会接着刚才的动作。"
		main_button.disabled=true
		demo_button.disabled=true
	else:
		var old_time:=phase_time
		_set_phase(phase)
		phase_time=old_time

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not paused)
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		primary_action()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var origin: Vector3=game.camera.project_ray_origin(event.position)
		var direction: Vector3=game.camera.project_ray_normal(event.position)
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*400,64)
		query.collide_with_areas=true
		query.collide_with_bodies=false
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var target:=str(hit.collider.get_meta("orchard_target",""))
			if (target=="apple" and phase=="ready") or (target=="basket" and phase=="carrying"): primary_action()
		return true
	return true

func _show_discovery() -> void:
	if is_instance_valid(discovery_panel): return
	discovery_panel=PanelContainer.new()
	discovery_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	discovery_panel.offset_left=-310
	discovery_panel.offset_right=-24
	discovery_panel.offset_top=156
	discovery_panel.offset_bottom=500
	discovery_panel.add_theme_stylebox_override("panel",Style.box(Style.PAPER,22,18))
	panel_root.add_child(discovery_panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	discovery_panel.add_child(column)
	var letters:=Style.text("A a",58)
	letters.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(letters)
	var picture:=TextureRect.new()
	picture.texture=load("res://ui/memory_story_content.gd").icon("A",2)
	picture.custom_minimum_size=Vector2(180,120)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(picture)
	var word:=Style.text("Apple · 苹果",24)
	word.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(word)
	_button(column,"听一听 A",func(): game.journey._play_letter_audio("A","letter"))
	_button(column,"听一听 Apple",func(): game.journey._play_letter_audio("A","word"))
	_button(column,"收下这次发现",func(): discovery_finished.emit(mode)).theme_type_variation="PrimaryButton"
	_button(column,"再玩一次",replay)
	main_button.disabled=true

func replay() -> void:
	var next_round:=_new_round()
	if not State.journey_orchard_commit("deposited","ready",next_round,mode): return
	round_id=next_round
	mode="independent_action"
	demonstration=false
	if is_instance_valid(discovery_panel):
		discovery_panel.queue_free()
		discovery_panel=null
	if apple.get_parent()!=self: apple.reparent(self)
	apple.global_transform=_apple_on_branch
	_apple_hit.collision_layer=64
	actor.play_action("idle")
	_set_phase("ready")
	if paused: set_paused(true)

func teardown() -> void:
	_configured=false
	if is_instance_valid(apple) and apple.get_parent()!=self: apple.reparent(self)
	if is_instance_valid(game):
		game.living.remove_actor(ACTOR_ID)
		game.living.set_context({"paused":false})
		if _player_taken:
			game.player.visual.visible=saved_player_visible
			game.player.collision_layer=saved_player_collision_layer
			game.player.collision_mask=saved_player_collision_mask
		game.ui.hud.show()
		game.ui.nav_controls.show()
		game.ui.controls_hint.show()
	for node: Node3D in _original_rabbit:
		if is_instance_valid(node): node.show()
	if is_instance_valid(panel_root): panel_root.queue_free()

func get_status() -> Dictionary:
	return {"phase":phase,"round_id":round_id,"paused":paused,"mode":mode,"actor_position":actor.global_position if is_instance_valid(actor) else Vector3.ZERO,"apple_position":apple.global_position if is_instance_valid(apple) else Vector3.ZERO,"pick_stand":pick_stand,"place_stand":place_stand,"apple_target":apple_target,"basket_target":basket_target,"contacts":contact_distances.duplicate(true)}

func _hit_area(parent: Node,point: Vector3,size: Vector3,target: String) -> Area3D:
	var area:=Area3D.new()
	area.collision_layer=64
	area.collision_mask=0
	area.set_meta("orchard_target",target)
	parent.add_child(area)
	area.position=point
	var collider:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	collider.shape=box
	area.add_child(collider)
	return area

func _cylinder_between(parent: Node3D,from: Vector3,to: Vector3,radius: float,color: Color) -> void:
	var instance:=MeshInstance3D.new()
	var shape:=CylinderMesh.new()
	shape.top_radius=radius*0.75
	shape.bottom_radius=radius
	shape.height=from.distance_to(to)
	instance.mesh=shape
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	instance.material_override=material
	parent.add_child(instance)
	instance.position=(from+to)*0.5
	var direction:=(to-from).normalized()
	instance.quaternion=Quaternion(Vector3.UP,direction)
