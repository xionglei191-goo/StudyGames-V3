extends SceneTree
## Production HUD/map/wardrobe input checks and screenshots for the v3 character wrapper.
var game: Node3D
var state: Node
var requested := Vector2i(1440,900)
var capture := false
var output := ""
var images := ""
var evidence_version := "art-finish-v3"
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var protected: Dictionary = {}
const PRODUCTION := ["user://island-save-v1.json","user://island-save-v1.json.bak"]

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg.begins_with("--art-width="): requested.x = arg.trim_prefix("--art-width=").to_int()
		if arg.begins_with("--art-height="): requested.y = arg.trim_prefix("--art-height=").to_int()
		if arg.begins_with("--art-output="): evidence_version = arg.trim_prefix("--art-output=")
	_run.call_deferred()

func _run() -> void:
	create_timer(120).timeout.connect(func(): printerr("ART_GAMEPLAY_V3_TIMEOUT"); quit(2))
	for path: String in PRODUCTION: protected[path] = _hash(path)
	output = ProjectSettings.globalize_path("res://../docs/verification/"+evidence_version)
	images = ProjectSettings.globalize_path("res://../docs/screenshots/%s/%dx%d/gameplay" % [evidence_version,requested.x,requested.y])
	DirAccess.make_dir_recursive_absolute(output)
	if capture: DirAccess.make_dir_recursive_absolute(images)
	root.size = requested
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame: int in range(1200):
		await process_frame
		if game.scene_ready: break
	_check(game.scene_ready,"production scene becomes ready")
	if not game.scene_ready:
		await _finish()
		return
	state = root.get_node("State")
	_check(str(state.save_path) == "user://validation-%d.json" % OS.get_process_id(),"production harness isolates save")
	state.data = state._default_state()
	game.muted = true
	game.voice.stop()
	game.sounds.enabled = false
	game._refresh()
	await _frames(12)
	if capture: _check(DisplayServer.window_get_size() == requested,"actual requested physical window")
	_check(_skins(game.player.visual) > 0,"actual world player uses real skin")
	await _capture("01-island-hud.png")
	game.show_map()
	# Capture after the production modal's entry animation has settled.
	await _frames(24)
	_check(is_instance_valid(game.ui.map_view) and game.ui.map_view.viewport.world_3d == game.get_world_3d(),"map renders the actual current world")
	await _capture("02-island-map.png")
	game._close()
	await game.change_room("home")
	await _frames(12)
	await _capture("03-home.png")
	game.show_bag()
	await _frames(8)
	var preview: Control = game.ui.wardrobe_preview
	_check(is_instance_valid(preview) and _skins(preview.model) > 0,"real wardrobe preview uses skinned model")
	if is_instance_valid(preview):
		var start_position: Vector3 = game.player.position
		var source_materials := _source_colors(preview.model)
		var world_model: Node3D = game.player.visual
		var colors := {"yellow":Color("e6b946"),"pink":Color("d87e93"),"blue":Color("79aeca")}
		for id: String in ["pink","blue","yellow"]:
			await _click_action("outfit:"+id)
			_check(state.data.outfit == id,"real wardrobe click persists selected outfit: "+id)
			_check(_matches_outfit(game.player.visual,colors[id]),"world skin changes selected outfit: "+id)
			_check(_matches_outfit(preview.model,colors[id]),"preview skin changes selected outfit: "+id)
			_check(_source_colors(preview.model) == source_materials,"outfit override preserves shared authored materials: "+id)
			await _capture("04-wardrobe-"+id+".png")
		var angle_before: float = preview.model.rotation.y
		var center := preview.get_global_rect().get_center()
		await _mouse(center,true)
		await _motion(center+Vector2(90,0),MOUSE_BUTTON_MASK_LEFT)
		await _mouse(center+Vector2(90,0),false)
		await _frames(3)
		_check(absf(preview.model.rotation.y-angle_before) > 0.3,"actual pointer drag rotates the wardrobe model")
		_check(not preview.spinning,"pointer release ends wardrobe drag")
		_check(game.player.visual == world_model and game.player.position.is_equal_approx(start_position),"wardrobe drag leaves the world player intact")
		await _capture("05-wardrobe-rotated.png")
	game._close()
	await _frames(3)
	_check(not game.ui.modal.visible,"closing wardrobe returns to the scene")
	await _capture("06-home-after-wardrobe.png")
	await _finish()

func _source_colors(node: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null: result[str(node.get_path_to(mesh))+"/"+str(surface)] = material.albedo_color
			var shader_material := mesh.mesh.surface_get_material(surface) as ShaderMaterial
			if shader_material != null: result[str(node.get_path_to(mesh))+"/"+str(surface)] = [shader_material.get_shader_parameter("outfit_color"),shader_material.get_shader_parameter("recolor")]
	return result

func _matches_outfit(node: Node3D, color: Color) -> bool:
	var found := false
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		var shader_material := mesh.get_active_material(0) as ShaderMaterial
		if shader_material != null and str(mesh.get_meta("source_asset","")) == "player":
			found = true
			if not (shader_material.get_shader_parameter("outfit_color") as Color).is_equal_approx(color): return false
			continue
		if str(child.name) != "Outfit": continue
		found = true
		var material := mesh.get_active_material(0) as BaseMaterial3D
		if material == null or not material.albedo_color.is_equal_approx(color): return false
	return found

func _skins(node: Node) -> int:
	var count := 0
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if mesh.mesh != null and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D: count += 1
	return count

func _click_action(id: String) -> void:
	var button: Button
	for node: Node in game.ui.panel_box.find_children("*","Button",true,false):
		if str(node.get_meta("action_id","")) == id:
			button = node
			break
	_check(button != null and not button.disabled and button.is_visible_in_tree(),"enabled production button exists: "+id)
	if button == null or button.disabled: return
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point),"production button is reachable: "+id)
	await _motion(point)
	await _mouse(point,true)
	await _mouse(point,false)
	await _frames(3)

func _mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event,true)
	await process_frame

func _motion(point: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = mask
	root.push_input(event,true)
	await process_frame

func _frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame

func _capture(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := images.path_join(name)
	_check(image.save_png(path) == OK,"native gameplay frame saved: "+name)
	captures.append({"path":path,"sha256":_hash(path),"size":[image.get_width(),image.get_height()]})

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(value: bool, label: String) -> void:
	checks.append({"check":label,"passed":value})
	if not value:
		failures.append(label)
		push_error("ART_GAMEPLAY_V3_FAIL: "+label)

func _finish() -> void:
	for path: String in PRODUCTION: _check(_hash(path) == str(protected[path]),"formal save unchanged: "+path)
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"requested_window":[requested.x,requested.y],"actual_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"logical_viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"scope":"Production main scene HUD, real world map, home, real wardrobe three-colour input and shared-material protection, pointer drag; separate movement/orchard tests cover navigation and action contacts."}
	var prefix := "native" if capture else "headless"
	var file := FileAccess.open(output.path_join("%s-%dx%d-gameplay.json" % [prefix,requested.x,requested.y]),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("ART_GAMEPLAY_V3 "+JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures,"captures":captures.size()}))
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	quit(0 if failures.is_empty() else 1)
