extends "res://tests/test_creation_flow.gd"
## Native layout and real pointer events with an isolated, disposable test profile.
var protected_before: Dictionary = {}
var captures: Array[String] = []
var layout_records: Array[Dictionary] = []
var finished := false

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("Use -- --test-harness for an isolated profile.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--creation-captures="): capture_dir=arg.trim_prefix("--creation-captures=")
	if capture_dir.is_empty(): capture_dir=ProjectSettings.globalize_path("res://../.local/creation-workspace-check")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(1440,900)
	AudioServer.set_bus_mute(0,true)
	protected_before = protected_signatures()
	create_timer(300).timeout.connect(func(): check(false,"bounded_timeout"); finish())
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene=game
	state=root.get_node("State")
	if not await wait_ready(): check(false,"scene_ready"); finish(); return
	game.application_backgrounded=false
	game.ui.reduced_motion=true
	game.muted=true
	game.ai_bridge.muted=true
	game.voice.stop()
	studio=game.creation
	state.data.journey.home_steps=["H01","H02","H03","H04"]
	check(str(state.save_path).begins_with("user://validation-"),"isolated_save")
	studio.show_home()
	await frames(12)
	await click_text("领取材料，开始创作")
	await frames(12)
	check(state.data.creation.started,"starter_materials_through_visible_button")
	await shot("01-wishes-1440")
	check_panel("home-1440")
	check_visible("WishNextStep","next_step_is_visible")
	await click_text("更多生活 ▾")
	var more: MenuButton=game.ui.panel_box.find_child("MoreLifePages",true,false)
	check(more.get_popup().visible,"more_navigation_opens")
	more.get_popup().hide()
	more.get_popup().id_pressed.emit(0)
	await frames(8)
	check(studio._workspace.section=="订单","orders_remain_accessible")
	studio.edit("",C.blank_design("stool"))
	await frames(12)
	check(not studio._painter.visible,"non_paintable_stool_does_not_show_empty_canvas")
	check(studio._preview_view.size.x>450 and studio._preview_view.size.y>300,"stool_preview_is_primary_workspace")
	var first_angle: float=studio._preview_model.rotation.y
	await click_text("转一转")
	check(not is_equal_approx(studio._preview_model.rotation.y,first_angle),"turn_preview_button_works")
	await click_text("方形")
	check(studio._draft.shape==1,"shape_choice_updates_draft")
	await click_text("圆形")
	var palette: GridContainer=game.ui.panel_box.find_child("ObjectColors",true,false)
	await click_point((palette.get_child(9) as Control).get_global_rect().get_center())
	check(studio._draft.color==9,"object_palette_changes_draft")
	await shot("02-stool-1440")
	check_editor("stool-1440")
	check(studio._name_field.is_visible_in_tree(),"object_name_visible_beside_preview")
	studio._name_field.text="森林小凳"
	studio._name_field.text_changed.emit("森林小凳")
	await click_text("保存设计")
	await frames(5)
	check(state.data.creation.designs.size()==1,"save_design_from_footer")
	if state.data.creation.designs.is_empty(): finish(); return
	check(state.data.creation.designs.values()[0].name=="森林小凳","saved_name_matches_editor")
	studio.edit("",C.blank_design("sign"))
	await frames(12)
	check(studio._painter.visible,"sign_has_drawing_canvas")
	var canvas: Control=studio._painter
	await paint_line(canvas)
	check(studio._painter.pattern!="0".repeat(4096),"pointer_drawing_changes_pattern")
	var drawing: String=studio._painter.pattern
	await click_text("撤销")
	check(studio._painter.pattern=="0".repeat(4096),"visible_undo_restores_canvas")
	studio._painter.set_pattern(drawing)
	studio._mark_dirty()
	await click_text("印章")
	var stamp_picker: OptionButton=game.ui.panel_box.find_child("StampSelector",true,false)
	check(stamp_picker.visible and studio._painter.tool=="stamp","stamp_tool_has_visible_selected_state")
	studio._painter.stamp="star"
	studio._painter.ink=7
	studio._painter.paint_at(studio._painter.size*Vector2(0.65,0.4))
	await click_text("名字与文字")
	studio._text_field.text="MY LITTLE ISLAND"
	studio._text_field.text_changed.emit(studio._text_field.text)
	await click_text("外观")
	await click_text("画笔")
	await frames(12)
	await shot("03-painted-sign-1440")
	check_editor("sign-1440")
	var draft_pattern: String=studio._painter.pattern
	await click_text("保存后确认制作")
	await frames(8)
	check(game.ui.current_panel=="creation","craft_confirmation_opens")
	await click_text("确认")
	await frames(12)
	check(state.data.creation.items.size()==1,"craft_after_confirm_still_works")
	check(state.data.creation.items.values()[0].design.pattern==draft_pattern,"crafted_item_keeps_drawing")
	studio.show_recipes()
	await frames(24)
	await shot("04-template-gallery-1440")
	check_panel("gallery-1440")
	for size_value: Vector2i in [Vector2i(1194,940),Vector2i(960,640)]:
		root.size=size_value
		await frames(12)
		studio.show_home()
		await frames(16)
		check_panel("home-"+str(size_value))
		check_visible("WishNextStep","next_step_visible_"+str(size_value))
		await shot("05-wishes-"+str(size_value.x))
		studio.edit("",C.blank_design("stool"))
		await frames(16)
		check_editor("stool-"+str(size_value))
		await shot("06-stool-"+str(size_value.x))
		studio.edit("",C.blank_design("frame"))
		await frames(16)
		check_editor("drawing-"+str(size_value))
		await shot("07-canvas-"+str(size_value.x))
		await click_text("名字与文字")
		studio._name_field.text="小窗口里的新作品"
		studio._name_field.text_changed.emit(studio._name_field.text)
		await click_text("保存设计")
		check(state.data.creation.designs.values().any(func(d: Dictionary): return d.name=="小窗口里的新作品"),"save_button_clickable_"+str(size_value))
	game._close()
	check(state.data.creation.draft.name=="小窗口里的新作品","closing_flushes_draft")
	check((state.data.learning as Dictionary).is_empty(),"no_learning_progress_invented")
	finish()

func _process(_delta: float) -> bool:
	if is_instance_valid(game): game.application_backgrounded=false
	return false

func check_panel(id: String) -> void:
	var bounds := Rect2(Vector2.ZERO,game.ui.root.size)
	var panel_rect: Rect2=game.ui.panel.get_global_rect()
	check(bounds.grow(-16).encloses(panel_rect),"panel_fits_with_margin_"+id)
	layout_records.append({"screen":id,"window":[root.size.x,root.size.y],"ui":[game.ui.root.size.x,game.ui.root.size.y],"panel":str(panel_rect),"minimum":str(game.ui.panel.get_combined_minimum_size())})

func check_editor(id: String) -> void:
	check_panel(id)
	check_visible("SaveDesign","save_visible_"+id)
	check_visible("SaveAndCraft","craft_visible_"+id)
	check_visible("CreationClose","close_visible_"+id)
	check(game.ui.panel.get_global_rect().encloses(studio._preview_view.get_global_rect()),"preview_fits_"+id)
	if studio._painter.visible:
		check(game.ui.panel.get_global_rect().encloses(studio._painter.get_global_rect()),"canvas_fits_"+id)
		check(studio._painter.size.x>=220 and studio._painter.size.y>=220,"usable_canvas_size_"+id)

func check_visible(node_name: String, title: String) -> void:
	var node: Control=game.ui.panel_box.find_child(node_name,true,false)
	check(node!=null and node.is_visible_in_tree() and game.ui.panel.get_global_rect().encloses(node.get_global_rect()),title)

func click_text(value: String) -> void:
	for node: Node in game.ui.panel_box.find_children("*","Button",true,false):
		if node.text==value and node.is_visible_in_tree() and not node.disabled:
			await click_point(node.get_global_rect().get_center())
			return
	check(false,"visible_button_"+value)

func click_point(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.global_position=point
		event.pressed=down
		root.push_input(event,true)
		await frames(2)

func paint_line(canvas: Control) -> void:
	var start := canvas.get_global_rect().position+canvas.size*Vector2(0.2,0.65)
	var down := InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.position=start
	down.global_position=start
	down.pressed=true
	down.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(down,true)
	for index: int in range(12):
		var move := InputEventMouseMotion.new()
		move.position=start+Vector2(index*canvas.size.x*0.05,0)
		move.global_position=move.position
		move.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(move,true)
		await frames(1)
	var up := InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT
	up.position=start+Vector2(canvas.size.x*0.55,0)
	up.global_position=up.position
	root.push_input(up,true)
	await frames(3)

func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.ui.toast_timer=0
	await frames(40)
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join(id+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"screenshot_"+id)
	captures.append(path)

func protected_signatures() -> Dictionary:
	var result := {}
	for suffix: String in ["",".bak"]:
		var path := "user://island-save-v1.json"+suffix
		result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func finish() -> void:
	if finished: return
	finished=true
	check(protected_before==protected_signatures(),"production_save_unchanged")
	var result := {"checks":checks,"failures":failures,"passed":failures.is_empty(),"screenshots":captures,"layouts":layout_records}
	var file := FileAccess.open(capture_dir.path_join("workspace-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("CREATION_WORKSPACE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	if is_instance_valid(game):
		game.queue_free()
		await frames(3)
	for suffix: String in ["",".bak",".tmp"]:
		var path := "user://validation-%s.json" % OS.get_process_id()+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)
