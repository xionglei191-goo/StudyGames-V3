extends Node3D
## V4.5 Animal-Crossing-Style Free-Grid 3D Home & Courtyard Decoration Studio.
## Provides 0.5m snapped 3D floor grid placement, 90-degree rotation (`R` or UI button),
## mouse raycast & keyboard cursor nudging, 13 Toy-PBR 3D furniture/garden/trophy models,
## and automatic room-by-room persistence in `State.data.v4.free_decor_placed`.

const Style = preload("res://ui/island_theme.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const StoryDirector = preload("res://gameplay/unit_storyline_director.gd")

const GRID_STEP := 0.5
const SUPPORTED_ROOMS := ["home", "home_estate", "home_bedroom", "home_study"]

const FURNITURE_CATALOG := [
	{"id": "sunflower_rug", "name": "🌻 向日葵圆毯", "en": "sunflower rug", "price": 12, "cat": "all"},
	{"id": "tea_table", "name": "🍵 下午茶圆桌", "en": "tea table", "price": 18, "cat": "all"},
	{"id": "potted_monstera", "name": "🌿 阳光龟背竹", "en": "green plant", "price": 14, "cat": "all"},
	{"id": "reading_sofa", "name": "🛋️ 云朵双人沙发", "en": "cozy sofa", "price": 26, "cat": "indoor"},
	{"id": "walnut_bookshelf", "name": "📚 童话绘本架", "en": "bookshelf", "price": 24, "cat": "indoor"},
	{"id": "star_floor_lamp", "name": "🌟 摘星落地灯", "en": "star lamp", "price": 22, "cat": "all"},
	{"id": "music_gramophone", "name": "🎺 黄铜留声机", "en": "music box", "price": 28, "cat": "indoor"},
	{"id": "apple_cake_stand", "name": "🎂 苹果甜品台", "en": "cake stand", "price": 20, "cat": "all"},
	{"id": "courtyard_swing", "name": "🪵 森系木秋千", "en": "garden swing", "price": 32, "cat": "outdoor"},
	{"id": "garden_fountain", "name": "⛲ 晴空小喷泉", "en": "garden fountain", "price": 35, "cat": "outdoor"},
	{"id": "bunny_topiary", "name": "🐰 兔兔绿雕", "en": "bunny bush", "price": 18, "cat": "outdoor"},
	{"id": "trophy_craft_pedestal", "name": "🏆 地标手作展台", "en": "craft trophy", "price": 16, "cat": "trophy"},
	{"id": "trophy_chapter_easel", "name": "🏅 章节纪念画架", "en": "story medal", "price": 20, "cat": "trophy"},
]

var game: Node3D
var active := false
var selected_id := "sunflower_rug"
var current_rot_deg := 0
var cursor_pos := Vector3.ZERO

var _placed_root: Node3D
var _grid_overlay: MeshInstance3D
var _ghost_root: Node3D
var _hud_layer: CanvasLayer
var _status_lbl: Label
var _coins_lbl: Label
var _items_row: HBoxContainer

func setup(host: Node3D) -> void:
	game = host
	name = "FreeGridDecorStudio"
	_placed_root = Node3D.new()
	_placed_root.name = "PlacedFreeDecorItems"
	add_child(_placed_root)
	_build_hud()

static func is_decorable_room(room_id: String) -> bool:
	return room_id in SUPPORTED_ROOMS

static func catalog_entry(item_id: String) -> Dictionary:
	for it: Dictionary in FURNITURE_CATALOG:
		if str(it.id) == item_id:
			return it
	return FURNITURE_CATALOG[0]

static func bonus_trophy_stock(state: Node, item_id: String) -> int:
	if state == null:
		return 0
	var v4_dict: Dictionary = state.data.get("v4", {}) if state.data.get("v4") is Dictionary else {}
	if item_id == "trophy_craft_pedestal":
		var crafts: Dictionary = v4_dict.get("landmark_crafts", {}) if v4_dict.get("landmark_crafts") is Dictionary else {}
		var total_c := 0
		for v: Variant in crafts.values():
			total_c += int(v)
		return maxi(1, total_c / 2) if total_c > 0 else 0
	if item_id == "trophy_chapter_easel":
		return StoryDirector.total_completed_chapters(state)
	return 0

func attach_to_room(room_id: String) -> void:
	if active and not is_decorable_room(room_id):
		close_studio()
	rebuild_room_items(room_id)
	if active:
		if is_instance_valid(game) and is_instance_valid(game.ui) and is_instance_valid(game.ui.hud):
			game.ui.hud.hide()
		_rebuild_grid_overlay()
		_reset_cursor_near_player()
		_refresh_hud()

func rebuild_room_items(room_id: String) -> void:
	if not is_instance_valid(_placed_root):
		return
	for c: Node in _placed_root.get_children():
		_placed_root.remove_child(c)
		c.queue_free()
	if not is_decorable_room(room_id) or not is_instance_valid(game):
		return
	var state: Node = game.get_node_or_null("/root/State")
	if state == null:
		return
	var v4_dict: Dictionary = state.data.get("v4", {}) if state.data.get("v4") is Dictionary else {}
	var placed_map: Dictionary = v4_dict.get("free_decor_placed", {}) if v4_dict.get("free_decor_placed") is Dictionary else {}
	var room_items: Array = placed_map.get(room_id, []) if placed_map.get(room_id, []) is Array else []
	for idx in range(room_items.size()):
		var rec: Dictionary = room_items[idx]
		var iid := str(rec.get("id", ""))
		var mesh_node := build_furniture_mesh(iid)
		if mesh_node != null:
			mesh_node.name = "FreeDecor_%d_%s" % [idx, iid]
			mesh_node.position = Vector3(float(rec.get("x", 0.0)), float(rec.get("y", 0.0)), float(rec.get("z", 0.0)))
			mesh_node.rotation_degrees.y = float(rec.get("rot", 0))
			_placed_root.add_child(mesh_node)

func open_studio() -> void:
	if not is_instance_valid(game):
		return
	if not is_decorable_room(game.room):
		await game.change_room("home")
	game._close()
	active = true
	game.player.locked = true
	if is_instance_valid(game.ui) and is_instance_valid(game.ui.hud):
		game.ui.hud.hide()
	_rebuild_grid_overlay()
	_reset_cursor_near_player()
	_rebuild_ghost()
	_hud_layer.show()
	_refresh_hud()

func close_studio() -> void:
	if not active:
		return
	active = false
	if is_instance_valid(_grid_overlay):
		_grid_overlay.queue_free()
		_grid_overlay = null
	if is_instance_valid(_ghost_root):
		_ghost_root.queue_free()
		_ghost_root = null
	if is_instance_valid(_hud_layer):
		_hud_layer.hide()
	if is_instance_valid(game):
		if is_instance_valid(game.ui) and is_instance_valid(game.ui.hud) and not game.ui.modal.visible:
			game.ui.hud.show()
		if is_instance_valid(game.player):
			game.player.locked = false

func rotate_ghost(step_deg: int = 90) -> void:
	current_rot_deg = posmod(current_rot_deg + step_deg, 360)
	if is_instance_valid(_ghost_root):
		_ghost_root.rotation_degrees.y = float(current_rot_deg)
	if is_instance_valid(game) and is_instance_valid(game.audio_director):
		game.audio_director.play_foley("decor_rotate")
	_refresh_hud()

func select_furniture(item_id: String) -> void:
	selected_id = item_id
	var entry := catalog_entry(item_id)
	if is_instance_valid(game) and is_instance_valid(game.ai_bridge):
		game.ai_bridge.speak_text(str(entry.get("en", "")), "en", "warm")
	_rebuild_ghost()
	_refresh_hud()

func place_at_cursor() -> bool:
	if not is_instance_valid(game) or not is_decorable_room(game.room):
		return false
	var state: Node = game.get_node_or_null("/root/State")
	if state == null:
		return false
	var entry := catalog_entry(selected_id)
	var b_stock := bonus_trophy_stock(state, selected_id)
	if is_instance_valid(game.creation):
		var reason: String = game.creation.legacy_placement_error(selected_id,cursor_pos)
		if not reason.is_empty():
			game.ui.notify(reason)
			return false
	var avail: int = state.free_decor_owned_count(selected_id) + b_stock - state.free_decor_placed_total(selected_id)
	if avail <= 0:
		# Auto-purchase if player has enough coins!
		var price := int(entry.get("price", 15))
		if not state.buy_free_decor(selected_id, price):
			return false
	if state.place_free_decor_item(game.room, selected_id, cursor_pos, current_rot_deg, b_stock):
		if is_instance_valid(game.audio_director):
			game.audio_director.play_foley("decor_place")
		state.record_stealth_evidence({
			"word": str(entry.get("en", "chair")).split(" ")[-1],
			"support_level": 0,
			"correct": true,
			"context": "free_grid_decor:" + game.room
		})
		rebuild_room_items(game.room)
		_refresh_hud()
		return true
	return false

func undo_last_item() -> void:
	if not is_instance_valid(game):
		return
	var state: Node = game.get_node_or_null("/root/State")
	if state == null:
		return
	var popped: Dictionary = state.pop_last_free_decor_item(game.room)
	if not popped.is_empty():
		if is_instance_valid(game.audio_director):
			game.audio_director.play_foley("bubble_pop")
		rebuild_room_items(game.room)
		_refresh_hud()

func clear_room_items() -> void:
	if not is_instance_valid(game):
		return
	var state: Node = game.get_node_or_null("/root/State")
	if state != null and state.clear_room_free_decor(game.room):
		rebuild_room_items(game.room)
		_refresh_hud()

func handle_input(event: InputEvent) -> bool:
	if not active or not is_instance_valid(game):
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_studio()
			return true
		elif event.keycode == KEY_R:
			rotate_ghost(90)
			return true
		elif event.keycode in [KEY_Z, KEY_BACKSPACE]:
			undo_last_item()
			return true
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			place_at_cursor()
			return true
		elif event.keycode in [KEY_W, KEY_UP]:
			_nudge_cursor(Vector2(0, -GRID_STEP))
			return true
		elif event.keycode in [KEY_S, KEY_DOWN]:
			_nudge_cursor(Vector2(0, GRID_STEP))
			return true
		elif event.keycode in [KEY_A, KEY_LEFT]:
			_nudge_cursor(Vector2(-GRID_STEP, 0))
			return true
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			_nudge_cursor(Vector2(GRID_STEP, 0))
			return true
	elif event is InputEventMouseMotion:
		_update_cursor_from_screen(event.position)
		return false
	elif event is InputEventMouseButton and event.pressed:
		var vp_h := get_viewport().get_visible_rect().size.y
		if event.position.y < 86.0 or event.position.y > vp_h - 168.0:
			return false
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotate_ghost(90)
			return true
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_update_cursor_from_screen(event.position)
			place_at_cursor()
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			game.camera_base_size = maxf(10.0, game.camera_base_size - 1.2)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			game.camera_base_size = minf(32.0, game.camera_base_size + 1.2)
			return true
	return false

func _reset_cursor_near_player() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var p: Vector3 = (game.player as Node3D).global_position + Vector3(1.0, 0.0, 0.5)
	cursor_pos = _clamp_and_snap(p)
	if is_instance_valid(_ghost_root):
		_ghost_root.position = cursor_pos

func _nudge_cursor(delta_xz: Vector2) -> void:
	cursor_pos = _clamp_and_snap(cursor_pos + Vector3(delta_xz.x, 0.0, delta_xz.y))
	if is_instance_valid(_ghost_root):
		_ghost_root.position = cursor_pos
	_refresh_hud()

func _update_cursor_from_screen(screen_pos: Vector2) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.camera):
		return
	var cam: Camera3D = game.camera as Camera3D
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 350.0, 4)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		cursor_pos = _clamp_and_snap(hit.position as Vector3)
	elif absf(dir.y) > 0.001:
		var t: float = -origin.y / dir.y
		if t > 0.0:
			cursor_pos = _clamp_and_snap(origin + dir * t)
	if is_instance_valid(_ghost_root):
		_ghost_root.position = cursor_pos

func _clamp_and_snap(raw_pt: Vector3) -> Vector3:
	var bounds: Rect2 = game.player.bounds.grow(-0.55)
	var sx := clampf(snappedf(raw_pt.x, GRID_STEP), bounds.position.x, bounds.end.x)
	var sz := clampf(snappedf(raw_pt.z, GRID_STEP), bounds.position.y, bounds.end.y)
	var sy := 0.0
	if game.nav_ready:
		var cell := Vector2i(roundi(sx / game.NAV_CELL), roundi(sz / game.NAV_CELL))
		if game.nav_heights.has(cell):
			sy = float(game.nav_heights[cell])
	return Vector3(sx, sy, sz)

func _rebuild_grid_overlay() -> void:
	if is_instance_valid(_grid_overlay):
		_grid_overlay.queue_free()
	var bounds: Rect2 = game.player.bounds.grow(-0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var x := snappedf(bounds.position.x, GRID_STEP)
	while x <= bounds.end.x + 0.01:
		st.add_vertex(Vector3(x, 0.03, bounds.position.y))
		st.add_vertex(Vector3(x, 0.03, bounds.end.y))
		x += GRID_STEP
	var z := snappedf(bounds.position.y, GRID_STEP)
	while z <= bounds.end.y + 0.01:
		st.add_vertex(Vector3(bounds.position.x, 0.03, z))
		st.add_vertex(Vector3(bounds.end.x, 0.03, z))
		z += GRID_STEP
	_grid_overlay = MeshInstance3D.new()
	_grid_overlay.name = "DecorFloorGrid"
	_grid_overlay.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.46, 0.66, 0.44, 0.28)
	_grid_overlay.material_override = mat
	add_child(_grid_overlay)

func _rebuild_ghost() -> void:
	if is_instance_valid(_ghost_root):
		_ghost_root.queue_free()
	_ghost_root = Node3D.new()
	_ghost_root.name = "DecorGhostCursor"
	_ghost_root.position = cursor_pos
	_ghost_root.rotation_degrees.y = float(current_rot_deg)
	add_child(_ghost_root)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.54
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.04, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.32, 0.78, 0.48, 0.78)
	ring.material_override = rmat
	_ghost_root.add_child(ring)

	# Forward direction pointer arrow
	var arrow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.24, 0.22, 0.06)
	arrow.mesh = prism
	arrow.rotation_degrees = Vector3(90, 0, 0)
	arrow.position = Vector3(0.0, 0.06, 0.65)
	arrow.material_override = rmat
	_ghost_root.add_child(arrow)

	var preview_model := build_furniture_mesh(selected_id)
	if preview_model != null:
		_tint_translucent(preview_model)
		_ghost_root.add_child(preview_model)

func _tint_translucent(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			var dup := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color.a = 0.72
			mi.material_override = dup
	for c: Node in node.get_children():
		_tint_translucent(c)

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 28
	_hud_layer.hide()
	add_child(_hud_layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.theme = Style.make_theme()
	_hud_layer.add_child(root_ctrl)

	# Top Compact Studio Ribbon
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 24
	top_panel.offset_right = -24
	top_panel.offset_top = 14
	top_panel.offset_bottom = 76
	var tsb := Style.box(Color(0.98, 0.96, 0.91, 0.95), 20, 12)
	tsb.border_color = Color("cfd8c2")
	tsb.set_border_width_all(2)
	top_panel.add_theme_stylebox_override("panel", tsb)
	root_ctrl.add_child(top_panel)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_row)

	_status_lbl = Label.new()
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.add_theme_font_size_override("font_size", 17)
	_status_lbl.add_theme_color_override("font_color", Style.INK)
	top_row.add_child(_status_lbl)

	_coins_lbl = Label.new()
	_coins_lbl.add_theme_font_size_override("font_size", 17)
	_coins_lbl.add_theme_color_override("font_color", Color("628448"))
	top_row.add_child(_coins_lbl)

	top_row.add_child(_mini_btn("🔄 旋转 90° (R)", func(): rotate_ghost(90)))
	top_row.add_child(_mini_btn("↩ 收回一件 (Z)", func(): undo_last_item()))
	top_row.add_child(_mini_btn("🧹 清空本屋", func(): clear_room_items()))
	top_row.add_child(_mini_btn("🏡 切换小院/客厅", func():
		var target_r := "home_estate" if game.room != "home_estate" else "home"
		await game.change_room(target_r)
	))
	top_row.add_child(_mini_btn("✓ 完成布置", func(): close_studio(), true))

	# Bottom Furniture Palette Dock
	var bot_panel := PanelContainer.new()
	bot_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_panel.offset_left = 24
	bot_panel.offset_right = -24
	bot_panel.offset_top = -152
	bot_panel.offset_bottom = -14
	bot_panel.add_theme_stylebox_override("panel", tsb)
	root_ctrl.add_child(bot_panel)

	var bot_vbox := VBoxContainer.new()
	bot_vbox.add_theme_constant_override("separation", 6)
	bot_panel.add_child(bot_vbox)

	var hint_lbl := Label.new()
	hint_lbl.text = "✨ 左键点击地面（或按空格）即可在 0.5m 网格摆放；右键或按 R 旋转朝向；未拥有时点击摆放会自动用叶币添置！"
	hint_lbl.add_theme_font_size_override("font_size", 14)
	hint_lbl.add_theme_color_override("font_color", Style.MUTED)
	bot_vbox.add_child(hint_lbl)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_vbox.add_child(scroll)

	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 10)
	scroll.add_child(_items_row)

func _mini_btn(txt: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	var fill := Color("dce9cc") if primary else Color("f3efe3")
	var sb := Style.box(fill, 14, 10)
	sb.border_color = Color("8fb573") if primary else Color("d6cbb4")
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Style.INK)
	b.pressed.connect(cb)
	return b

func _refresh_hud() -> void:
	if not is_instance_valid(_hud_layer) or not is_instance_valid(game):
		return
	var state: Node = game.get_node_or_null("/root/State")
	if state == null:
		return
	var entry := catalog_entry(selected_id)
	_status_lbl.text = "🏡 自由网格工坊 · 当前：%s (%s) · 朝向 %d° · 坐标 (%.1f, %.1f)" % [
		str(entry.get("name", "")),
		str(entry.get("en", "")),
		current_rot_deg,
		cursor_pos.x,
		cursor_pos.z
	]
	_coins_lbl.text = "🍃 叶币：%d" % int(state.data.get("coins", 0))

	for c: Node in _items_row.get_children():
		_items_row.remove_child(c)
		c.queue_free()

	for item: Dictionary in FURNITURE_CATALOG:
		var iid := str(item.id)
		var b_stock := bonus_trophy_stock(state, iid)
		var owned: int = state.free_decor_owned_count(iid) + b_stock
		var placed: int = state.free_decor_placed_total(iid)
		var avail := maxi(0, owned - placed)
		var stock_txt := "库存 %d" % avail if avail > 0 else "🍃%d 添置" % int(item.price)
		var btn := Button.new()
		btn.text = "%s\n%s · %s" % [str(item.name), str(item.en), stock_txt]
		btn.custom_minimum_size = Vector2(162, 68)
		btn.add_theme_font_size_override("font_size", 14)
		var is_sel := (iid == selected_id)
		var fill := Color("dce9cc") if is_sel else Color("f8f5ec")
		var sb := Style.box(fill, 14, 8)
		sb.border_color = Color("6e9c52") if is_sel else Color("d8ceb8")
		sb.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Style.INK)
		btn.pressed.connect(func(): select_furniture(iid))
		_items_row.add_child(btn)

static func _mat(hex: String, rough: float = 0.45, emit_hex: String = "", emit_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	if not emit_hex.is_empty():
		m.emission_enabled = true
		m.emission = Color(emit_hex)
		m.emission_energy_multiplier = emit_energy
	return m

static func build_furniture_mesh(item_id: String) -> Node3D:
	var imported := preload("res://actors/tripo_prop_library.gd").create(item_id)
	if imported != null: return imported
	var root := Node3D.new()
	match item_id:
		"sunflower_rug":
			var outer := MeshInstance3D.new()
			var c1 := CylinderMesh.new()
			c1.top_radius = 1.05; c1.bottom_radius = 1.05; c1.height = 0.03
			outer.mesh = c1; outer.position = Vector3(0, 0.015, 0)
			outer.material_override = _mat("f5cb5c", 0.78)
			root.add_child(outer)
			var inner := MeshInstance3D.new()
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.56; c2.bottom_radius = 0.56; c2.height = 0.036
			inner.mesh = c2; inner.position = Vector3(0, 0.02, 0)
			inner.material_override = _mat("8c5835", 0.82)
			root.add_child(inner)
		"tea_table":
			var leg := MeshInstance3D.new()
			var lc := CylinderMesh.new()
			lc.top_radius = 0.09; lc.bottom_radius = 0.26; lc.height = 0.62
			leg.mesh = lc; leg.position = Vector3(0, 0.31, 0)
			leg.material_override = _mat("8b5a36", 0.48)
			root.add_child(leg)
			var top := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.62; tc.bottom_radius = 0.60; tc.height = 0.07
			top.mesh = tc; top.position = Vector3(0, 0.64, 0)
			top.material_override = _mat("a66e44", 0.40)
			root.add_child(top)
			var pot := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.13; sp.height = 0.22
			pot.mesh = sp; pot.position = Vector3(0.0, 0.77, 0.0)
			pot.material_override = _mat("f7f1e1", 0.25)
			root.add_child(pot)
		"potted_monstera":
			var pot := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.26; pc.bottom_radius = 0.20; pc.height = 0.42
			pot.mesh = pc; pot.position = Vector3(0, 0.21, 0)
			pot.material_override = _mat("d68759", 0.55)
			root.add_child(pot)
			for i in range(5):
				var leaf := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.24; sp.height = 0.12
				leaf.mesh = sp
				var ang := float(i) * TAU / 5.0
				leaf.position = Vector3(cos(ang) * 0.20, 0.62 + float(i % 2) * 0.12, sin(ang) * 0.20)
				leaf.rotation = Vector3(0.3, -ang, 0.2)
				leaf.material_override = _mat("5ca463", 0.46)
				root.add_child(leaf)
		"reading_sofa":
			var seat := MeshInstance3D.new()
			var sb := BoxMesh.new(); sb.size = Vector3(1.55, 0.36, 0.78)
			seat.mesh = sb; seat.position = Vector3(0, 0.24, 0)
			seat.material_override = _mat("f4ead5", 0.68)
			root.add_child(seat)
			var back := MeshInstance3D.new()
			var bb := BoxMesh.new(); bb.size = Vector3(1.55, 0.56, 0.22)
			back.mesh = bb; back.position = Vector3(0, 0.56, -0.28)
			back.material_override = _mat("ebd9b9", 0.68)
			root.add_child(back)
			for sx: float in [-0.68, 0.68]:
				var arm := MeshInstance3D.new()
				var ab := BoxMesh.new(); ab.size = Vector3(0.20, 0.46, 0.78)
				arm.mesh = ab; arm.position = Vector3(sx, 0.38, 0)
				arm.material_override = _mat("dfcba8", 0.68)
				root.add_child(arm)
			var pillow := MeshInstance3D.new()
			var pb := BoxMesh.new(); pb.size = Vector3(0.34, 0.30, 0.14)
			pillow.mesh = pb; pillow.position = Vector3(-0.36, 0.52, -0.10); pillow.rotation_degrees.z = 14
			pillow.material_override = _mat("e88d7d", 0.62)
			root.add_child(pillow)
		"walnut_bookshelf":
			var frame := MeshInstance3D.new()
			var fb := BoxMesh.new(); fb.size = Vector3(1.18, 1.32, 0.38)
			frame.mesh = fb; frame.position = Vector3(0, 0.66, 0)
			frame.material_override = _mat("7d4e2d", 0.46)
			root.add_child(frame)
			var colors: Array[String] = ["e56b55", "5fa8d3", "8ac926", "ffca3a", "b5838d"]
			for i in range(5):
				var bk := MeshInstance3D.new()
				var bb := BoxMesh.new(); bb.size = Vector3(0.14, 0.34, 0.28)
				bk.mesh = bb
				bk.position = Vector3(-0.36 + float(i) * 0.18, 0.92, 0.04)
				bk.material_override = _mat(colors[i], 0.42)
				root.add_child(bk)
		"star_floor_lamp":
			var pole := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.04; pc.bottom_radius = 0.18; pc.height = 1.45
			pole.mesh = pc; pole.position = Vector3(0, 0.72, 0)
			pole.material_override = _mat("c99b49", 0.30)
			root.add_child(pole)
			var shade := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.20; sc.bottom_radius = 0.34; sc.height = 0.34
			shade.mesh = sc; shade.position = Vector3(0, 1.48, 0)
			shade.material_override = _mat("fff3c4", 0.35, "ffe18c", 1.1)
			root.add_child(shade)
			if DisplayServer.get_name() != "headless":
				var omni := OmniLight3D.new()
				omni.position = Vector3(0, 1.42, 0)
				omni.light_color = Color("ffe6a3")
				omni.light_energy = 0.85
				omni.omni_range = 4.2
				root.add_child(omni)
		"music_gramophone":
			var box := MeshInstance3D.new()
			var bb := BoxMesh.new(); bb.size = Vector3(0.52, 0.42, 0.52)
			box.mesh = bb; box.position = Vector3(0, 0.21, 0)
			box.material_override = _mat("824f2b", 0.42)
			root.add_child(box)
			var horn := MeshInstance3D.new()
			var hc := CylinderMesh.new()
			hc.top_radius = 0.28; hc.bottom_radius = 0.05; hc.height = 0.46
			horn.mesh = hc; horn.position = Vector3(0, 0.64, 0.08); horn.rotation_degrees.x = 32
			horn.material_override = _mat("e6be5c", 0.25)
			root.add_child(horn)
		"apple_cake_stand":
			var ped := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.36; pc.bottom_radius = 0.24; pc.height = 0.56
			ped.mesh = pc; ped.position = Vector3(0, 0.28, 0)
			ped.material_override = _mat("f7efe0", 0.34)
			root.add_child(ped)
			var cake := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.24; cc.bottom_radius = 0.24; cc.height = 0.18
			cake.mesh = cc; cake.position = Vector3(0, 0.65, 0)
			cake.material_override = _mat("f3a683", 0.52)
			root.add_child(cake)
		"courtyard_swing":
			for sx: float in [-0.72, 0.72]:
				var post := MeshInstance3D.new()
				var pc := CylinderMesh.new()
				pc.top_radius = 0.06; pc.bottom_radius = 0.07; pc.height = 1.65
				post.mesh = pc; post.position = Vector3(sx, 0.82, 0)
				post.material_override = _mat("8c5a38", 0.50)
				root.add_child(post)
			var beam := MeshInstance3D.new()
			var bb := BoxMesh.new(); bb.size = Vector3(1.66, 0.10, 0.14)
			beam.mesh = bb; beam.position = Vector3(0, 1.64, 0)
			beam.material_override = _mat("8c5a38", 0.50)
			root.add_child(beam)
			var bench := MeshInstance3D.new()
			var sb := BoxMesh.new(); sb.size = Vector3(1.05, 0.08, 0.42)
			bench.mesh = sb; bench.position = Vector3(0, 0.52, 0)
			bench.material_override = _mat("c98d55", 0.46)
			root.add_child(bench)
		"garden_fountain":
			var basin := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.78; bc.bottom_radius = 0.72; bc.height = 0.34
			basin.mesh = bc; basin.position = Vector3(0, 0.17, 0)
			basin.material_override = _mat("dfd9ce", 0.55)
			root.add_child(basin)
			var water := MeshInstance3D.new()
			var wc := CylinderMesh.new()
			wc.top_radius = 0.68; wc.bottom_radius = 0.68; wc.height = 0.05
			water.mesh = wc; water.position = Vector3(0, 0.33, 0)
			water.material_override = _mat("6cc4e8", 0.16, "58b4dc", 0.35)
			root.add_child(water)
			var spire := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.12; sc.bottom_radius = 0.18; sc.height = 0.68
			spire.mesh = sc; spire.position = Vector3(0, 0.52, 0)
			spire.material_override = _mat("e8e2d7", 0.50)
			root.add_child(spire)
		"bunny_topiary":
			var pot := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.28; pc.bottom_radius = 0.22; pc.height = 0.36
			pot.mesh = pc; pot.position = Vector3(0, 0.18, 0)
			pot.material_override = _mat("c97c52", 0.56)
			root.add_child(pot)
			var body := MeshInstance3D.new()
			var bs := SphereMesh.new(); bs.radius = 0.34; bs.height = 0.68
			body.mesh = bs; body.position = Vector3(0, 0.66, 0)
			body.material_override = _mat("68b05c", 0.62)
			root.add_child(body)
			for ex: float in [-0.12, 0.12]:
				var ear := MeshInstance3D.new()
				var ec := CapsuleMesh.new(); ec.radius = 0.07; ec.height = 0.36
				ear.mesh = ec; ear.position = Vector3(ex, 1.12, 0)
				ear.material_override = _mat("68b05c", 0.62)
				root.add_child(ear)
		"trophy_craft_pedestal":
			var ped := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.30; pc.bottom_radius = 0.34; pc.height = 0.62
			ped.mesh = pc; ped.position = Vector3(0, 0.31, 0)
			ped.material_override = _mat("8f5f3b", 0.42)
			root.add_child(ped)
			var boat := Wardrobe.build_carried_prop("boat")
			if boat != null:
				boat.position = Vector3(0, 0.72, 0)
				root.add_child(boat)
		_: # trophy_chapter_easel
			var easel := MeshInstance3D.new()
			var eb := BoxMesh.new(); eb.size = Vector3(0.74, 0.96, 0.10)
			easel.mesh = eb; easel.position = Vector3(0, 0.56, 0); easel.rotation_degrees.x = -10
			easel.material_override = _mat("9e6b40", 0.45)
			root.add_child(easel)
			var canvas := MeshInstance3D.new()
			var cb := BoxMesh.new(); cb.size = Vector3(0.64, 0.52, 0.06)
			canvas.mesh = cb; canvas.position = Vector3(0, 0.68, 0.05); canvas.rotation_degrees.x = -10
			canvas.material_override = _mat("fff6dc", 0.35, "ffe494", 0.45)
			root.add_child(canvas)
	return root
