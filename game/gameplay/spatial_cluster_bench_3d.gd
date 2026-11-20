extends Node3D
## V6 Two-Tier Spatial Word Cluster & True In-Scene Layer-2 Unfolding (`SpatialClusterBench3D`).
## 1. Layer 1 (Walk Into Room): Places warm visual bilingual `Label3D` word prompts directly above the
##    room's 5 real 3D furniture pieces (`SG_MEMORY_01..05`, e.g. `washbasin · 洗手台`, `desk · 书桌`, `wardrobe · 大衣柜`),
##    and makes each real 3D furniture piece directly hoverable/clickable.
## 2. Layer 2 (Click Layer-1 Furniture -> Unfold In-Place): Never spawns a separate fake display table!
##    Instead, the real 3D room camera zooms directly onto THAT exact furniture piece (swinging wardrobe
##    doors open where needed) and unfolds its 3-5 Layer-2 3D objects directly ON / IN / BESIDE the real
##    washbasin, desk, bookcase, bed, dining table, or wardrobe with non-overlapping 2D callout pills!

const CLUSTERS_PATH := "res://data/learning/spatial_word_clusters_v6.json"
const FONT_PATH := "res://assets/fonts/IslandSans.otf"
const Style = preload("res://ui/island_theme.gd")
const TripoProps = preload("res://actors/tripo_prop_library.gd")
const Layer2Props = preload("res://actors/layer2_prop_library.gd")
const HomeCatalog = preload("res://scripts/home_catalog.gd")
const WorldArt = preload("res://scripts/world_art.gd")
const CLOSET_ROD_Y := 2.03

const HOME_TASK_LABELS := {
	"home_estate": "★ 动手浇花圃",
	"home": "★ 动手摆茶几",
	"home_bedroom": "★ 动手理床铺",
	"home_kitchen": "★ 动手洗蔬菜",
	"home_dining": "★ 动手摆餐桌",
	"home_bathroom": "★ 动手洗洗手",
	"home_study": "★ 动手收好书",
	"home_balcony": "★ 动手晾袜子",
}

static var _loaded := false
static var _rooms_data: Dictionary = {}

var game: Node3D
var active_room := ""
var macro_plaques: Array[Label3D] = []
var _plaque_holders: Dictionary = {}
var _anchor_positions: Array[Dictionary] = []
var _furniture_pick_areas: Array[Area3D] = []
var _whispered_in_room: Dictionary = {}
var _anim_time := 0.0

# Active In-Scene Layer-2 Close-Up State
var bench_open := false
var bench_room_id := ""
var bench_anchor_order := 1
var camera_focus := Vector3.ZERO
var camera_size := 4.2
var selected_word := ""
var task_index := 0
var tasks_completed := false

var _stage_root: Node3D
var _selected_halo: MeshInstance3D
var _anchor_world_pos := Vector3.ZERO
var _stage_origin := Vector3.ZERO
var _base_prop_yaw := 0.0
var _prop_nodes: Dictionary = {}
var _prop_home_pos: Dictionary = {}
var _ordered_layer2_keys: Array[String] = []
var _placed_keys: Dictionary = {}
var _word_lookup: Dictionary = {}
var _callout_buttons: Dictionary = {}
var _hidden_ui_nodes: Array[Dictionary] = []
var _hidden_anchor_meshes: Array[Dictionary] = []
var _saved_cam_yaw := 0.0
var _saved_cam_yaw_target := 0.0
var _has_saved_cam_yaw := false

var _overlay_root: Control
var _callout_layer: Control
var _top_anchor_title_btn: Button
var _top_sub_lbl: Label
var _special_action_btn: Button
var _special_action_id := ""
var _selected_title_lbl: Label
var _selected_en_lbl: Label
var _selected_zh_lbl: Label
var _palace_btn: Button
var _task_prompt_lbl: Label
var _task_feedback_lbl: Label

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rooms_data.clear()
	if not FileAccess.file_exists(CLUSTERS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CLUSTERS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("rooms") is Dictionary:
		_rooms_data = (parsed as Dictionary).get("rooms") as Dictionary

static func has_cluster(room_id: String) -> bool:
	_ensure_loaded()
	return _rooms_data.has(room_id)

static func cluster_for_room(room_id: String) -> Dictionary:
	_ensure_loaded()
	if not _rooms_data.has(room_id):
		return {}
	return (_rooms_data[room_id] as Dictionary).duplicate(true)

static func all_cluster_words(room_id: String) -> Array[Dictionary]:
	var cluster := cluster_for_room(room_id)
	var out: Array[Dictionary] = []
	for m: Variant in cluster.get("macro_items", []):
		if m is Dictionary:
			var d := (m as Dictionary).duplicate(true)
			d["tier"] = "macro"
			out.append(d)
	for u: Variant in cluster.get("micro_items", []):
		if u is Dictionary:
			var d := (u as Dictionary).duplicate(true)
			d["tier"] = "micro"
			out.append(d)
	return out

static func macro_item_for_anchor(room_id: String, anchor_order: int) -> Dictionary:
	var cluster := cluster_for_room(room_id)
	for m: Variant in cluster.get("macro_items", []):
		if m is Dictionary and int((m as Dictionary).get("anchor_order", 0)) == anchor_order:
			return (m as Dictionary).duplicate(true)
	return {}

static func interaction_prompt_for(room_id: String, entry_id: String, fallback_label: String, is_hover: bool = false) -> String:
	if not entry_id.begins_with("memory_") or not has_cluster(room_id):
		return fallback_label
	var seq := int(entry_id.trim_prefix("memory_"))
	var m := macro_item_for_anchor(room_id, seq)
	if m.is_empty():
		return fallback_label
	var w := str(m.get("word", "")).strip_edges()
	var zh := str(m.get("zh", "")).strip_edges()
	var l2_cnt := (m.get("layer2_items", []) as Array).size()
	if w.is_empty():
		return fallback_label
	if is_hover:
		return "%s · %s\n点击走近 · 在原处展开第 2 层（%d 件关联物品）" % [w, zh, maxi(1, l2_cnt)]
	return "展开 %s · %s（看第 2 层物品）" % [w, zh]

static func _vec3(raw: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if raw is Vector3:
		return raw as Vector3
	if raw is Array and (raw as Array).size() >= 3:
		var arr := raw as Array
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback

func attach_to_room(owner_game: Node3D, room_id: String) -> void:
	close_workbench()
	game = owner_game
	active_room = room_id
	macro_plaques.clear()
	_plaque_holders.clear()
	_anchor_positions.clear()
	_whispered_in_room.clear()
	for old_area: Area3D in _furniture_pick_areas:
		if is_instance_valid(old_area):
			old_area.queue_free()
	_furniture_pick_areas.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	if not has_cluster(room_id) or not is_instance_valid(game):
		return

	var cluster := cluster_for_room(room_id)
	var font := load(FONT_PATH) as Font
	for m_v: Variant in cluster.get("macro_items", []):
		if not (m_v is Dictionary):
			continue
		var item: Dictionary = m_v as Dictionary
		var order := int(item.get("anchor_order", 0))
		if order <= 0:
			continue
		var world_pos := _resolve_anchor_world_pos(order)
		if world_pos == Vector3.INF:
			continue
		var spec: Dictionary = item.get("stage_spec", {}) if item.get("stage_spec") is Dictionary else {}
		var plaque_world := _vec3(spec.get("plaque_pos", []), world_pos + Vector3(0.0, 1.58, 0.0))

		var holder := Node3D.new()
		holder.name = "MacroPlaque_%02d" % order
		holder.position = world_pos
		add_child(holder)
		_plaque_holders[order] = holder

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34
		torus.outer_radius = 0.43
		ring.mesh = torus
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color.from_string(str(item.get("color", "d9a85b")), Color("d9a85b")).lightened(0.22)
		rmat.roughness = 0.62
		rmat.emission_enabled = true
		rmat.emission = rmat.albedo_color * 0.26
		ring.material_override = rmat
		ring.position = Vector3(0.0, 0.04, 0.0)
		holder.add_child(ring)

		var lbl := Label3D.new()
		lbl.name = "WordTag"
		lbl.text = "%s · %s" % [str(item.get("word", "")), str(item.get("zh", ""))]
		lbl.font = font
		lbl.font_size = 34
		lbl.pixel_size = 0.0088
		lbl.position = plaque_world - world_pos
		lbl.set_meta("base_y", lbl.position.y)
		lbl.modulate = Color("fffdf6")
		lbl.outline_modulate = Color("2b2118")
		lbl.outline_size = 12
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.render_priority = 8
		holder.add_child(lbl)
		macro_plaques.append(lbl)

		_register_furniture_pick_area(order, plaque_world)

		_anchor_positions.append({
			"order": order,
			"position": world_pos,
			"plaque_world": plaque_world,
			"word": str(item.get("word", "")),
			"zh": str(item.get("zh", "")),
			"sentence_en": str(item.get("sentence_en", "")),
			"companion_npc_id": str(cluster.get("companion_npc_id", "warm")),
		})

func _register_furniture_pick_area(order: int, plaque_world: Vector3) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.get("feedback")):
		return
	var pick_root: Node3D = game.feedback.get("pick_root") as Node3D
	if not is_instance_valid(pick_root):
		return
	var inter_id := "memory_%02d" % order
	var matched_entry: Dictionary = {}
	var interactions: Array = game.interactions if game.get("interactions") is Array else []
	for entry_v: Variant in interactions:
		if entry_v is Dictionary and str((entry_v as Dictionary).get("id", "")) == inter_id:
			matched_entry = entry_v as Dictionary
			break
	if matched_entry.is_empty():
		return
	var area := Area3D.new()
	area.name = "FurniturePick_%02d" % order
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interaction", matched_entry)
	area.position = Vector3(plaque_world.x, maxf(0.95, plaque_world.y - 0.85), plaque_world.z)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.0, 1.65)
	col.shape = box
	area.add_child(col)
	pick_root.add_child(area)
	_furniture_pick_areas.append(area)

func _resolve_anchor_world_pos(order: int) -> Vector3:
	if not is_instance_valid(game):
		return Vector3.INF
	var markers: Dictionary = game.metadata.get("marker_nodes", {}) if game.metadata.get("marker_nodes") is Dictionary else {}
	var interactions: Array = game.interactions if game.get("interactions") is Array else []
	var inter_id := "memory_%02d" % order
	for entry_v: Variant in interactions:
		if entry_v is Dictionary and str((entry_v as Dictionary).get("id", "")) == inter_id:
			var p: Variant = (entry_v as Dictionary).get("position", Vector3.INF)
			if p is Vector3:
				return p as Vector3
	var marker_key := "SG_MEMORY_%02d" % order
	if markers.has(marker_key):
		var mk: Variant = markers[marker_key]
		if mk is Node3D and is_instance_valid(mk):
			return (mk as Node3D).global_position
	return Vector3.INF

func _process(delta: float) -> void:
	_anim_time += delta
	if bench_open:
		_update_closeup_visuals(delta)
		return

	for i: int in range(macro_plaques.size()):
		var lbl := macro_plaques[i]
		if is_instance_valid(lbl):
			var base_y := float(lbl.get_meta("base_y", 1.58))
			lbl.position.y = base_y + sin(_anim_time * 1.9 + float(i) * 0.9) * 0.04

	if not is_instance_valid(game) or game.validation_mode:
		return
	if game.ui.modal.visible or (is_instance_valid(game.ui.diegetic) and game.ui.diegetic.visible):
		return
	if game.greeting_clock > 0.0:
		return
	for entry: Dictionary in _anchor_positions:
		var order := int(entry.get("order", 0))
		if _whispered_in_room.has(order):
			continue
		var pos: Vector3 = entry.get("position", Vector3.INF)
		var dist := Vector2(game.player.position.x, game.player.position.z).distance_to(Vector2(pos.x, pos.z))
		if dist < 2.15:
			_whispered_in_room[order] = true
			var w := str(entry.get("word", ""))
			var zh := str(entry.get("zh", ""))
			var bubble_origin: Vector3 = entry.get("plaque_world", pos + Vector3(0.0, 1.95, 0.0))
			game.bubble_world_position = bubble_origin + Vector3(0.0, 0.28, 0.0)
			game.ui.say("%s — %s" % [w, str(entry.get("sentence_en", ""))], "第一层场景：%s（%s）· 点击或按 E 在原处展开第 2 层物品！" % [w, zh], game.camera.unproject_position(game.bubble_world_position))
			if is_instance_valid(game.ai_bridge):
				game.ai_bridge.speak_text(w, "en", str(entry.get("companion_npc_id", "warm")))
			game.greeting_clock = 4.5
			break

func _update_closeup_visuals(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.camera) or not is_instance_valid(_overlay_root):
		return
	var cam: Camera3D = game.camera as Camera3D
	if cam == null:
		return
	var vp_size := _overlay_root.size
	if vp_size.x <= 10.0:
		vp_size = Vector2(game.get_viewport().get_visible_rect().size)

	var layout_items: Array[Dictionary] = []
	var prop_keepout: Dictionary = {}
	for i: int in range(_ordered_layer2_keys.size()):
		var key := _ordered_layer2_keys[i]
		if not _prop_nodes.has(key) or not is_instance_valid(_prop_nodes[key]):
			continue
		var prop: Node3D = _prop_nodes[key]
		if key == selected_word and not _placed_keys.has(key):
			if is_instance_valid(_selected_halo) and _selected_halo.visible and not game.ui.reduced_motion:
				var pulse := 1.0 + sin(_anim_time * 3.4) * 0.06
				_selected_halo.scale = Vector3(pulse, 0.16, pulse)
		var bounds: AABB = prop.get_meta("art_bounds")
		var body_world := prop.to_global(bounds.get_center())
		if not cam.is_position_behind(body_world):
			prop_keepout[key] = _screen_bounds(cam,prop,bounds).grow(3)

		if not _callout_buttons.has(key) or not is_instance_valid(_callout_buttons[key]):
			continue
		var btn: Button = _callout_buttons[key]
		var world_head := prop.to_global(bounds.get_center() + Vector3.UP * bounds.size.y * 0.5)
		if cam.is_position_behind(world_head) or not prop_keepout.has(key):
			btn.hide()
			continue
		btn.show()
		var screen_pt: Vector2 = cam.unproject_position(world_head)
		var bsize := btn.size if btn.size.x > 8.0 else btn.get_combined_minimum_size()
		layout_items.append({
			"key": key,
			"idx": i,
			"btn": btn,
			"pt": screen_pt,
			"size": bsize,
		})

	layout_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a["pt"] as Vector2).x) < float((b["pt"] as Vector2).x)
	)

	var placed_rects: Array[Rect2] = []
	var usable := Rect2(18,80,vp_size.x-36,maxf(60,vp_size.y-262))
	for item: Dictionary in layout_items:
		var key: String = item.key
		var btn: Button = item.btn
		var size_px: Vector2 = item.size
		var body: Rect2 = prop_keepout[key]
		var middle := body.get_center()
		var above := Vector2(middle.x-size_px.x/2,body.position.y-size_px.y-12)
		var below := Vector2(above.x,body.end.y+12)
		var low_shelf := bool(_prop_nodes[key].get_meta("on_shelf",false))
		var candidates: Array[Vector2] = [above,below]
		if low_shelf:
			candidates.reverse()
		candidates.append(Vector2(body.position.x-size_px.x-12,middle.y-size_px.y/2))
		candidates.append(Vector2(body.end.x+12,middle.y-size_px.y/2))
		for shift in [-0.68,0.68,-1.12,1.12]:
			candidates.append(above + Vector2(size_px.x*float(shift),0))
			candidates.append(below + Vector2(size_px.x*float(shift),0))
		var best := Rect2()
		var best_score := INF
		for n in candidates.size():
			var pos := candidates[n].clamp(usable.position,(usable.end-size_px).max(usable.position))
			var rect := Rect2(pos,size_px)
			var score := n*3.0 + middle.distance_to(rect.get_center())*0.1
			for prior: Rect2 in placed_rects:
				score += rect.intersection(prior.grow(5)).get_area()*5.0
			for keepout: Rect2 in prop_keepout.values():
				score += rect.intersection(keepout).get_area()
			if score < best_score:
				best = rect
				best_score = score
		btn.position = best.position
		placed_rects.append(best)
		var start := middle.clamp(best.position+Vector2.ONE*3,best.end-Vector2.ONE*3)
		var end := best.get_center().clamp(body.position,body.end)
		var leader := btn.get_node("Leader") as Line2D
		leader.points = PackedVector2Array([start-best.position,end-best.position])

func _restore_anchor_meshes() -> void:
	for entry: Dictionary in _hidden_anchor_meshes:
		var n: Variant = entry.get("node", null)
		if n is Node3D and is_instance_valid(n):
			(n as Node3D).visible = bool(entry.get("visible", true))
	_hidden_anchor_meshes.clear()

func _apply_anchor_mesh_hides(patterns: Array) -> void:
	_restore_anchor_meshes()
	if patterns.is_empty() or not is_instance_valid(game) or not is_instance_valid(game.get("world")):
		return
	for node: Node in (game.world as Node).find_children("*", "MeshInstance3D", true, false):
		if not (node is Node3D):
			continue
		var n3 := node as Node3D
		var p_name: String = str(n3.get_parent().name) if n3.get_parent() != null else ""
		var matched := false
		for pat_v: Variant in patterns:
			var pat := str(pat_v).strip_edges()
			if pat.is_empty():
				continue
			if n3.name.matchn(pat) or (not p_name.is_empty() and p_name.matchn(pat)):
				matched = true
				break
		if matched:
			_hidden_anchor_meshes.append({"node": n3, "visible": n3.visible})
			n3.hide()

func close_workbench() -> void:
	var was_open := bench_open
	bench_open = false
	_special_action_id = ""
	_restore_anchor_meshes()
	if is_instance_valid(_stage_root):
		_stage_root.queue_free()
	_stage_root = null
	_selected_halo = null
	if is_instance_valid(_overlay_root):
		_overlay_root.hide()
		_overlay_root.queue_free()
	_overlay_root = null
	_callout_layer = null
	_prop_nodes.clear()
	_prop_home_pos.clear()
	_ordered_layer2_keys.clear()
	_placed_keys.clear()
	_word_lookup.clear()
	_callout_buttons.clear()

	for order_k: Variant in _plaque_holders:
		var holder: Variant = _plaque_holders[order_k]
		if holder is Node3D and is_instance_valid(holder):
			(holder as Node3D).show()

	for entry: Dictionary in _hidden_ui_nodes:
		var n: Variant = entry.get("node", null)
		if n is CanvasItem and is_instance_valid(n):
			(n as CanvasItem).visible = bool(entry.get("visible", true))
		elif n is Node3D and is_instance_valid(n):
			(n as Node3D).visible = bool(entry.get("visible", true))
	_hidden_ui_nodes.clear()

	if _has_saved_cam_yaw and is_instance_valid(game):
		game.set("_camera_yaw_target", _saved_cam_yaw_target)
		if is_instance_valid(game.get("ui")) and bool(game.ui.get("reduced_motion")):
			game.set("_camera_yaw", _saved_cam_yaw)
		_has_saved_cam_yaw = false

	if was_open:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		if is_instance_valid(game):
			game.player.locked = false

func open_workbench(owner_game: Node3D, room_override: String = "", initial_word: String = "", anchor_order: int = 0) -> bool:
	game = owner_game
	if not is_instance_valid(game):
		return false
	var target_room := room_override if not room_override.is_empty() else str(game.room)
	if not has_cluster(target_room):
		return false

	if is_instance_valid(game.journey) and not game.journey.close_memory():
		return false
	if is_instance_valid(game.free_decor_studio) and game.free_decor_studio.active:
		game.free_decor_studio.close_studio()
	if is_instance_valid(game.household):
		game.household.cancel_task()
	if is_instance_valid(game.ui.diegetic) and game.ui.diegetic.visible:
		game.ui.diegetic.dismiss()
	game.ui.close_panel()
	game._cancel_navigation()
	game._clear_hover_target()
	game.feedback.highlight({})
	game.ui.bubble_panel.hide()

	var cluster := cluster_for_room(target_room)
	var resolved_order := _resolve_requested_anchor(cluster, initial_word, anchor_order)

	if not bench_open:
		_saved_cam_yaw = float(game.get("_camera_yaw"))
		_saved_cam_yaw_target = float(game.get("_camera_yaw_target"))
		_has_saved_cam_yaw = true
		game.set("_camera_yaw_target", 0.0)
		if is_instance_valid(game.get("ui")) and bool(game.ui.get("reduced_motion")):
			game.set("_camera_yaw", 0.0)
		_capture_and_hide_room_chrome()

	bench_open = true
	bench_room_id = target_room
	game.player.locked = true
	_activate_anchor_stage(cluster, resolved_order, initial_word, true)
	return true

func cycle_anchor(step: int) -> void:
	if not bench_open or not is_instance_valid(game):
		return
	var cluster := cluster_for_room(bench_room_id)
	var macro_items: Array = cluster.get("macro_items", [])
	if macro_items.is_empty():
		return
	var count := macro_items.size()
	var next_order := ((bench_anchor_order - 1 + step + count) % count) + 1
	if is_instance_valid(game.audio_director):
		game.audio_director.play_foley("bubble_pop")
	_activate_anchor_stage(cluster, next_order, "", true)

func _resolve_requested_anchor(cluster: Dictionary, initial_word: String, anchor_order: int) -> int:
	var macro_items: Array = cluster.get("macro_items", [])
	if anchor_order >= 1 and anchor_order <= macro_items.size():
		return anchor_order
	var needle := initial_word.strip_edges().to_lower()
	if not needle.is_empty():
		for m_v: Variant in macro_items:
			if not (m_v is Dictionary):
				continue
			var md: Dictionary = m_v as Dictionary
			if str(md.get("word", "")).to_lower() == needle:
				return int(md.get("anchor_order", 1))
			for u_v: Variant in md.get("layer2_items", []):
				if u_v is Dictionary and str((u_v as Dictionary).get("word", "")).to_lower() == needle:
					return int(md.get("anchor_order", 1))
	return clampi(int(cluster.get("default_anchor", 1)), 1, maxi(1, macro_items.size()))

func _capture_and_hide_room_chrome() -> void:
	_hidden_ui_nodes.clear()
	if not is_instance_valid(game) or not is_instance_valid(game.ui):
		return
	var targets: Array = [
		game.ui.hud,
		game.ui.prompt,
		game.ui.prompt_cycle,
		game.ui.hover_prompt,
		game.ui.controls_hint,
		game.ui.bubble_panel,
		game.player.visual if is_instance_valid(game.player) else null,
		game.palace_loci if is_instance_valid(game.get("palace_loci")) else null,
		game.tactile_quests if is_instance_valid(game.get("tactile_quests")) else null,
	]
	if is_instance_valid(game.get("living")):
		for lbl_node: Node in (game.living as Node).find_children("*", "Label3D", true, false):
			targets.append(lbl_node)
	if is_instance_valid(game.get("world")):
		for lbl_node: Node in (game.world as Node).find_children("*", "Label3D", true, false):
			targets.append(lbl_node)
	for n: Variant in targets:
		if n is CanvasItem and is_instance_valid(n):
			_hidden_ui_nodes.append({"node": n, "visible": (n as CanvasItem).visible})
			(n as CanvasItem).hide()
		elif n is Node3D and is_instance_valid(n):
			_hidden_ui_nodes.append({"node": n, "visible": (n as Node3D).visible})
			(n as Node3D).hide()

func _activate_anchor_stage(cluster: Dictionary, order: int, initial_word: String, announce_voice: bool) -> void:
	_restore_anchor_meshes()
	bench_anchor_order = order
	task_index = 0
	tasks_completed = false
	_placed_keys.clear()
	_word_lookup.clear()
	_prop_nodes.clear()
	_prop_home_pos.clear()
	_ordered_layer2_keys.clear()
	_callout_buttons.clear()
	_selected_halo = null

	if is_instance_valid(_stage_root):
		_stage_root.queue_free()
		_stage_root = null
	if is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
		_overlay_root = null

	var state_node := game.get_node_or_null("/root/State") if is_instance_valid(game) else null
	if state_node != null and state_node.has_method("discover"):
		state_node.discover(bench_room_id, bench_anchor_order)
	if state_node != null and state_node.has_method("grant_exp"):
		state_node.grant_exp({
			"key": "anchor_open:%s:%d" % [bench_room_id, bench_anchor_order],
			"mode": "once",
			"base_exp": 8,
		})
	if is_instance_valid(game.household):
		game.household._sequence = bench_anchor_order

	for order_k: Variant in _plaque_holders:
		var holder: Variant = _plaque_holders[order_k]
		if holder is Node3D and is_instance_valid(holder):
			(holder as Node3D).visible = false

	var anchor_dict := macro_item_for_anchor(bench_room_id, bench_anchor_order)
	if anchor_dict.is_empty():
		var macros: Array = cluster.get("macro_items", [])
		if not macros.is_empty() and macros[0] is Dictionary:
			anchor_dict = (macros[0] as Dictionary).duplicate(true)

	var macro_copy := anchor_dict.duplicate(true)
	macro_copy["tier"] = "macro"
	var macro_key := str(macro_copy.get("word", "")).to_lower()
	if not macro_key.is_empty():
		_word_lookup[macro_key] = macro_copy

	var layer2_items: Array = anchor_dict.get("layer2_items", [])
	for u_v: Variant in layer2_items:
		if u_v is Dictionary:
			var ud := (u_v as Dictionary).duplicate(true)
			ud["tier"] = "micro"
			var uk := str(ud.get("word", "")).to_lower()
			if not uk.is_empty():
				_word_lookup[uk] = ud
				_ordered_layer2_keys.append(uk)

	_build_in_room_3d_showcase(cluster, anchor_dict)
	_build_floating_overlay(cluster, anchor_dict)

	var default_pick := initial_word.strip_edges().to_lower()
	if default_pick.is_empty() or not _word_lookup.has(default_pick):
		if not _ordered_layer2_keys.is_empty():
			default_pick = _ordered_layer2_keys[0]
		else:
			default_pick = macro_key
	_refresh_task_prompt(anchor_dict)
	if not default_pick.is_empty():
		select_bench_item(default_pick, false)

	if announce_voice and is_instance_valid(game) and is_instance_valid(game.ai_bridge):
		var comp_id := str(cluster.get("companion_npc_id", "warm"))
		var mw := str(anchor_dict.get("word", ""))
		var m_sent := str(anchor_dict.get("sentence_en", ""))
		if not mw.is_empty():
			game.ai_bridge.speak_text("%s. %s" % [mw, m_sent], "en", comp_id)
	if is_instance_valid(game) and is_instance_valid(game.audio_director):
		game.audio_director.play_foley("bubble_pop")

func _build_in_room_3d_showcase(_cluster: Dictionary, anchor_dict: Dictionary) -> void:
	_stage_root = Node3D.new()
	_stage_root.name = "Layer2ShowcaseStage"
	add_child(_stage_root)

	_anchor_world_pos = _resolve_anchor_world_pos(bench_anchor_order)
	if _anchor_world_pos == Vector3.INF:
		_anchor_world_pos = game.player.position if is_instance_valid(game) else Vector3.ZERO

	var bounds: Rect2 = game.player.bounds if is_instance_valid(game) else Rect2(-8.0, -8.0, 16.0, 16.0)
	var safe_bounds := bounds.grow(-1.25)
	if safe_bounds.size.x < 1.5 or safe_bounds.size.y < 1.5:
		safe_bounds = bounds
	var room_center := Vector3(bounds.get_center().x, _anchor_world_pos.y, bounds.get_center().y)
	_position_player_near_anchor(_anchor_world_pos, room_center, safe_bounds)

	var spec: Dictionary = anchor_dict.get("stage_spec", {}) if anchor_dict.get("stage_spec") is Dictionary else {}
	var mode := str(spec.get("mode", "surface"))
	var hide_patterns: Array = spec.get("hide_meshes", []) if spec.get("hide_meshes") is Array else []
	_apply_anchor_mesh_hides(hide_patterns)

	camera_focus = _vec3(spec.get("focus", []), _anchor_world_pos + Vector3(0.0, 0.48, 0.0))
	camera_size = clampf(float(spec.get("camera_size", 4.2)), 3.2, 6.8)
	_stage_origin = camera_focus + Vector3(0.0, 0.55, 0.0)
	_base_prop_yaw = deg_to_rad(float(spec.get("prop_yaw_deg", 18.0)))
	var prop_scale := clampf(float(spec.get("prop_scale", 0.96)), 0.55, 1.45)

	# Warm golden close-up key light illuminating the real 3D Layer-1 furniture surface
	var spot := OmniLight3D.new()
	spot.light_color = Color("fff5e0")
	spot.light_energy = 0.46
	spot.omni_range = 5.8
	spot.position = _stage_origin + Vector3(0.85, 2.25, 1.35)
	_stage_root.add_child(spot)

	if mode == "wardrobe" and spec.get("wardrobe_box") is Array:
		_build_open_wardrobe_interior(_stage_root, spec.get("wardrobe_box") as Array, bench_room_id == "home_kitchen")

	# Thin subtle golden halo ring right on the furniture surface under the selected item (zero fake table/coaster!)
	_selected_halo = MeshInstance3D.new()
	_selected_halo.name = "SelectedFurnitureHalo"
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.145
	halo_mesh.outer_radius = 0.185
	_selected_halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.albedo_color = Color(0.98, 0.84, 0.44, 0.88)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selected_halo.material_override = halo_mat
	_selected_halo.scale = Vector3(1.0, 0.16, 1.0)
	_selected_halo.hide()
	_stage_root.add_child(_selected_halo)

	var layer2_items: Array = anchor_dict.get("layer2_items", [])
	var slots: Array = spec.get("slots", []) if spec.get("slots") is Array else []
	var count := maxi(1, layer2_items.size())

	for idx: int in range(layer2_items.size()):
		if not (layer2_items[idx] is Dictionary):
			continue
		var u_it: Dictionary = layer2_items[idx] as Dictionary
		var w := str(u_it.get("word", ""))
		var key := w.to_lower()

		var fallback_slot := _stage_origin + Vector3((float(idx) - float(count - 1) * 0.5) * 0.62, 0.45, 0.0)
		var world_p := _vec3(slots[idx], fallback_slot) if idx < slots.size() else fallback_slot

		var prop_holder := Node3D.new()
		prop_holder.name = "Layer2_" + key
		prop_holder.position = world_p
		prop_holder.rotation.y = _base_prop_yaw
		_stage_root.add_child(prop_holder)

		var art := _build_layer2_prop(str(u_it.get("shape", "book")), str(u_it.get("color", "5b9bd5")), key, mode)
		art.name = "ArtMesh"
		art.scale *= prop_scale
		prop_holder.add_child(art)
		var bounds_local := _art_bounds(prop_holder)
		var heights: Dictionary = spec.get("item_heights",{})
		if heights.has(key) and bounds_local.size.y > 0.001:
			var factor := float(heights[key]) / bounds_local.size.y
			art.scale *= factor
			bounds_local = AABB(bounds_local.position * factor,bounds_local.size * factor)
		var cabinet: Array = spec.get("wardrobe_box",[])
		if cabinet.size() == 6 and key in ["coat","shirt","dress"]:
			# The underside of the hook rests on the top of the 4 cm diameter rod.
			world_p.y = CLOSET_ROD_Y + 0.029 - bounds_local.end.y
			world_p.z = (float(cabinet[2])+float(cabinet[5]))*0.5 + 0.05
			prop_holder.position = world_p
			prop_holder.set_meta("hanging",true)
		elif mode == "wardrobe":
			prop_holder.set_meta("on_shelf",true)
		prop_holder.set_meta("art_bounds", bounds_local)

		if not game.ui.reduced_motion:
			prop_holder.scale = Vector3.ONE * 0.08
			var tw := create_tween()
			tw.tween_interval(0.03 * float(idx))
			tw.tween_property(prop_holder, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		_prop_nodes[key] = prop_holder
		_prop_home_pos[key] = world_p

func _art_bounds(holder: Node3D) -> AABB:
	var combined := AABB()
	var inverse := holder.global_transform.affine_inverse()
	for node: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if node.mesh != null:
			var box: AABB = (inverse * node.global_transform) * node.get_aabb()
			combined = box if combined.size == Vector3.ZERO else combined.merge(box)
	return combined

func _screen_bounds(cam: Camera3D, holder: Node3D, bounds: AABB) -> Rect2:
	var rect := Rect2(cam.unproject_position(holder.to_global(bounds.get_endpoint(0))),Vector2.ZERO)
	for i in range(1,8):
		rect = rect.expand(cam.unproject_position(holder.to_global(bounds.get_endpoint(i))))
	return rect

func _build_open_wardrobe_interior(parent: Node3D, wbox: Array, is_pantry: bool) -> void:
	if wbox.size() < 6:
		return
	var x0 := float(wbox[0])
	var y0 := float(wbox[1])
	var z0 := float(wbox[2])
	var x1 := float(wbox[3])
	var y1 := float(wbox[4])
	var z1 := float(wbox[5])

	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var cz := (z0 + z1) * 0.5
	var w := maxf(1.2, x1 - x0)
	var h := maxf(1.8, y1 - y0)
	var d := maxf(0.6, z1 - z0)
	var th := 0.08
	var plinth_h := 0.16
	var crown_h := 0.12

	var oak := Color("c59563")
	var oak_trim := Color("b0804f")
	var liner := Color("f8f1e2")
	var brass := Color("d7af5e")

	var cab := Node3D.new()
	cab.name = "OpenWardrobeCarcass"
	parent.add_child(cab)

	# 5-sided hollow oak wardrobe shell replacing the closed GLB solid block
	_box(cab, Vector3(cx, y0 + plinth_h * 0.5, cz), Vector3(w, plinth_h, d), oak_trim)
	_box(cab, Vector3(cx, y1 - crown_h * 0.5, cz), Vector3(w + 0.06, crown_h, d + 0.05), oak_trim)
	_box(cab, Vector3(cx, cy, z0 + th * 0.5), Vector3(w, h, th), oak)
	_box(cab, Vector3(x0 + th * 0.5, cy, cz), Vector3(th, h, d), oak)
	_box(cab, Vector3(x1 - th * 0.5, cy, cz), Vector3(th, h, d), oak)

	# Warm cream interior liner panels
	var in_h := h - plinth_h - crown_h - 0.02
	var in_cy := (y0 + plinth_h + y1 - crown_h) * 0.5
	_box(cab, Vector3(cx, in_cy, z0 + th + 0.012), Vector3(w - th * 2.0 - 0.02, in_h, 0.02), liner)
	_box(cab, Vector3(x0 + th + 0.012, in_cy, cz + 0.02), Vector3(0.02, in_h, d - th - 0.04), liner.darkened(0.03))
	_box(cab, Vector3(x1 - th - 0.012, in_cy, cz + 0.02), Vector3(0.02, in_h, d - th - 0.04), liner.darkened(0.03))

	# Lower storage shelf (top at y = 0.878, supporting folded items at y = 0.88)
	_box(cab, Vector3(cx, 0.855, cz + 0.02), Vector3(w - th * 2.0, 0.045, d - th - 0.05), oak.lightened(0.06))

	if is_pantry:
		# Upper pantry shelf for milk & eggs at y = 1.52
		_box(cab, Vector3(cx, 1.495, cz + 0.02), Vector3(w - th * 2.0, 0.045, d - th - 0.05), oak.lightened(0.06))
	else:
		# Brushed brass closet rod at y = 2.03 so coat, shirt, and dress hangers hook directly onto it!
		var rod := _cyl(cab, Vector3(cx, CLOSET_ROD_Y, cz + 0.05), 0.020, w - th * 2.0 - 0.02, brass)
		(rod.material_override as StandardMaterial3D).metallic = 0.78
		(rod.material_override as StandardMaterial3D).roughness = 0.32
		rod.rotation_degrees.z = 90.0
		_cyl(cab, Vector3(x0 + th + 0.02, 2.03, cz + 0.05), 0.034, 0.03, brass.darkened(0.1))
		_cyl(cab, Vector3(x1 - th - 0.02, 2.03, cz + 0.05), 0.034, 0.03, brass.darkened(0.1))

	# Two swung-open inset-panel doors hinged at front left/right edges
	var door_w := minf(0.56, w * 0.28)
	var door_h := in_h - 0.04

	var hinge_l := Node3D.new()
	hinge_l.position = Vector3(x0 + 0.04, in_cy, z1 - 0.02)
	hinge_l.rotation_degrees.y = -118.0
	cab.add_child(hinge_l)
	_box(hinge_l, Vector3(door_w * 0.5, 0.0, 0.0), Vector3(door_w, door_h, 0.045), oak)
	_box(hinge_l, Vector3(door_w * 0.5, 0.0, 0.015), Vector3(door_w - 0.14, door_h - 0.22, 0.022), liner)
	_sphere(hinge_l, Vector3(door_w - 0.09, -0.05, 0.048), 0.032, brass)

	var hinge_r := Node3D.new()
	hinge_r.position = Vector3(x1 - 0.04, in_cy, z1 - 0.02)
	hinge_r.rotation_degrees.y = 118.0
	cab.add_child(hinge_r)
	_box(hinge_r, Vector3(-door_w * 0.5, 0.0, 0.0), Vector3(door_w, door_h, 0.045), oak)
	_box(hinge_r, Vector3(-door_w * 0.5, 0.0, 0.015), Vector3(door_w - 0.14, door_h - 0.22, 0.022), liner)
	_sphere(hinge_r, Vector3(-door_w + 0.09, -0.05, 0.048), 0.032, brass)

	var closet_light := OmniLight3D.new()
	closet_light.light_color = Color("fff6e3")
	closet_light.light_energy = 0.30
	closet_light.omni_range = 3.4
	closet_light.position = Vector3(cx, y1 - 0.38, cz + 0.22)
	cab.add_child(closet_light)
	# Cut the grain along each board. Cabinet sides and the long horizontal
	# shelf use their own local coordinates as the doors swing open.
	for board: MeshInstance3D in cab.find_children("*","MeshInstance3D",true,false):
		if not board.mesh is BoxMesh:
			continue
		var mat := board.material_override as StandardMaterial3D
		if mat.albedo_color.r - mat.albedo_color.b < 0.21:
			continue
		WorldArt.set_surface_detail(mat,"wood",0.15)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(1.0,2.0,1.0)

func _position_player_near_anchor(anchor_pos: Vector3, room_center: Vector3, safe_bounds: Rect2) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var dist := Vector2(game.player.position.x, game.player.position.z).distance_to(Vector2(anchor_pos.x, anchor_pos.z))
	if dist <= 2.35:
		return
	var dir := room_center - anchor_pos
	dir.y = 0.0
	var stand := anchor_pos + (dir.normalized() * 1.05 if dir.length() > 0.05 else Vector3(0.0, 0.0, 0.9))
	stand.x = clampf(stand.x, safe_bounds.position.x, safe_bounds.end.x)
	stand.z = clampf(stand.z, safe_bounds.position.y, safe_bounds.end.y)
	if game.nav_ready and game.has_method("_nearest_walkable_cell"):
		var cell: Vector2i = game._nearest_walkable_cell(Vector2i(roundi(stand.x / 0.75), roundi(stand.z / 0.75)), stand)
		if game.navigation.is_in_boundsv(cell):
			stand = Vector3(cell.x * 0.75, float(game.nav_heights.get(cell, game.player.position.y)) + 0.15, cell.y * 0.75)
	game.player.position = Vector3(stand.x, game.player.position.y, stand.z)

func _build_floating_overlay(cluster: Dictionary, anchor_dict: Dictionary) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.ui) or not is_instance_valid(game.ui.root):
		return
	var ui: CanvasLayer = game.ui
	_overlay_root = Control.new()
	_overlay_root.name = "V6Layer2CloseupOverlay"
	_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.theme = Style.make_theme()
	ui.root.add_child(_overlay_root)

	# 1. Floating 2D Callout Pill Layer (projected directly above each real-scene Layer-2 item!)
	_callout_layer = Control.new()
	_callout_layer.name = "Layer2CalloutLayer"
	_callout_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_callout_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(_callout_layer)

	for u_v: Variant in anchor_dict.get("layer2_items", []):
		if not (u_v is Dictionary):
			continue
		var u_it: Dictionary = u_v as Dictionary
		var w := str(u_it.get("word", ""))
		var zh := str(u_it.get("zh", ""))
		var key := w.to_lower()
		var chip := Button.new()
		chip.name = "Callout_" + key
		chip.text = "★ %s · %s" % [w, zh]
		chip.custom_minimum_size = Vector2(124, 36)
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_callout_chip(chip, false, false)
		chip.pressed.connect(func(): select_bench_item(w, true))
		_callout_layer.add_child(chip)
		var leader := Line2D.new()
		leader.name = "Leader"
		leader.width = 1.5
		leader.antialiased = true
		leader.default_color = Color(0.35,0.27,0.15,0.72)
		leader.show_behind_parent = true
		chip.add_child(leader)
		_callout_buttons[key] = chip

	# 2. Top Floating Header Bar (Layer-1 Real Scene Identity + Room Action + Prev/Next + Return)
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopFloatingBar"
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 16
	top_bar.offset_top = 14
	top_bar.offset_right = -16
	top_bar.offset_bottom = 70
	top_bar.add_theme_constant_override("separation", 8)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(top_bar)

	var l1_card := PanelContainer.new()
	var l1_sb := Style.pill(Color(0.996, 0.982, 0.942, 0.96), Color("d9be86"), Color("c3a160"), 20, 12, 6)
	l1_card.add_theme_stylebox_override("panel", l1_sb)
	top_bar.add_child(l1_card)

	var l1_row := HBoxContainer.new()
	l1_row.add_theme_constant_override("separation", 8)
	l1_card.add_child(l1_row)

	var macro_word := str(anchor_dict.get("word", ""))
	var macro_zh := str(anchor_dict.get("zh", ""))
	var total_anchors := maxi(1, (cluster.get("macro_items", []) as Array).size())
	_top_anchor_title_btn = ui.button(
		"♪ 第一层 %d/%d：%s · %s" % [bench_anchor_order, total_anchors, macro_word, macro_zh],
		"",
		false,
		Vector2(196, 36)
	)
	_top_anchor_title_btn.pressed.connect(func(): select_bench_item(macro_word, true))
	l1_row.add_child(_top_anchor_title_btn)

	_top_sub_lbl = ui.label(
		_format_top_sub_text(cluster),
		13,
		Style.MUTED
	)
	l1_row.add_child(_top_sub_lbl)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_spacer)

	var spec := _resolve_special_anchor_action(bench_room_id, bench_anchor_order)
	_special_action_id = str(spec.get("id", ""))
	if not _special_action_id.is_empty():
		_special_action_btn = ui.button(str(spec.get("label", "★ 房间互动")), "", true, Vector2(126, 40))
		_special_action_btn.pressed.connect(_trigger_special_action)
		top_bar.add_child(_special_action_btn)

	var prev_btn: Button = ui.button("◁ 上一处", "", false, Vector2(88, 40))
	prev_btn.pressed.connect(func(): cycle_anchor(-1))
	top_bar.add_child(prev_btn)

	var next_btn: Button = ui.button("下一处 ▶", "", false, Vector2(88, 40))
	next_btn.pressed.connect(func(): cycle_anchor(1))
	top_bar.add_child(next_btn)

	var exit_btn: Button = ui.button("× 返回房间 [Esc]", "", false, Vector2(138, 40))
	exit_btn.pressed.connect(close_workbench)
	top_bar.add_child(exit_btn)

	# 3. Bottom Floating Layer-2 Inspection & Placement Dock
	var bottom_dock := PanelContainer.new()
	bottom_dock.name = "BottomFloatingDock"
	bottom_dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_dock.offset_left = -465
	bottom_dock.offset_right = 465
	bottom_dock.offset_top = -168
	bottom_dock.offset_bottom = -14
	var dock_sb := Style.pill(Color(0.996, 0.984, 0.948, 0.96), Color("dfd0b2"), Color("cbb68e"), 22, 18, 12)
	dock_sb.shadow_size = 12
	bottom_dock.add_theme_stylebox_override("panel", dock_sb)
	_overlay_root.add_child(bottom_dock)

	var dock_col := VBoxContainer.new()
	dock_col.add_theme_constant_override("separation", 6)
	bottom_dock.add_child(dock_col)

	var word_row := HBoxContainer.new()
	word_row.add_theme_constant_override("separation", 8)
	dock_col.add_child(word_row)

	_selected_title_lbl = ui.label("", 20, Style.INK)
	_selected_title_lbl.name = "SelectedWordTitle"
	_selected_title_lbl.add_theme_font_override("font", Style.heading_font())
	_selected_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_row.add_child(_selected_title_lbl)

	var speak_en_btn: Button = ui.button("♪ 听英文", "", true, Vector2(104, 34))
	speak_en_btn.pressed.connect(_speak_selected_en)
	word_row.add_child(speak_en_btn)

	var speak_zh_btn: Button = ui.button("· 听中文", "", false, Vector2(98, 34))
	speak_zh_btn.pressed.connect(_speak_selected_zh)
	word_row.add_child(speak_zh_btn)

	_palace_btn = ui.button("◈ 记忆宫殿", "", false, Vector2(148, 34))
	_palace_btn.pressed.connect(_open_selected_palace)
	word_row.add_child(_palace_btn)

	var domain := "home" if bench_room_id.begins_with("home") else "school"
	var chat_btn: Button = ui.button("◈ 练课本对话", "", false, Vector2(132, 34))
	chat_btn.pressed.connect(func():
		close_workbench()
		if is_instance_valid(game):
			game._on_action("v6_ladder_open:" + domain)
	)
	word_row.add_child(chat_btn)

	var sent_row := HBoxContainer.new()
	sent_row.add_theme_constant_override("separation", 14)
	dock_col.add_child(sent_row)

	_selected_en_lbl = ui.label("", 16, Style.INK)
	_selected_en_lbl.name = "SelectedSentenceEn"
	_selected_en_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_en_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sent_row.add_child(_selected_en_lbl)

	_selected_zh_lbl = ui.label("", 14, Style.MUTED)
	_selected_zh_lbl.name = "SelectedSentenceZh"
	_selected_zh_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_zh_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sent_row.add_child(_selected_zh_lbl)

	var task_strip := PanelContainer.new()
	task_strip.name = "PlacementTaskBox"
	var ts_sb := Style.keycap(Color("edf5e8"), Color("bcd4b1"), 2, 12, 12, 5)
	ts_sb.shadow_size = 0
	task_strip.add_theme_stylebox_override("panel", ts_sb)
	dock_col.add_child(task_strip)

	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override("separation", 10)
	task_strip.add_child(task_row)

	_task_prompt_lbl = ui.label("", 15, Style.INK)
	_task_prompt_lbl.name = "PlacementPrompt"
	_task_prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_row.add_child(_task_prompt_lbl)

	_task_feedback_lbl = ui.label("点选场景中的第 2 层物品（或词卡）即可互动归位！", 13, Style.SAGE)
	_task_feedback_lbl.name = "PlacementFeedback"
	task_row.add_child(_task_feedback_lbl)

	var task_audio_btn: Button = ui.button("♪ 听指令", "", false, Vector2(96, 30))
	task_audio_btn.pressed.connect(_speak_current_task)
	task_row.add_child(task_audio_btn)

	_update_closeup_visuals(0.0)

func _style_callout_chip(btn: Button, is_selected: bool, is_placed: bool) -> void:
	var bg := Color("4f7d5c") if is_selected else (Color("eaf4e5") if is_placed else Color(0.998, 0.988, 0.952, 0.96))
	var bd := Color("3b6347") if is_selected else (Color("8ebc84") if is_placed else Color("d8be86"))
	var sh := Color("2e4f38") if is_selected else Color("bfa268")
	var sb := Style.pill(bg, bd, sh, 18, 12, 6)
	sb.shadow_size = 6
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	var fg := Color("fffdf7") if is_selected else (Color("2f5d3c") if is_placed else Style.INK)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_focus_color", fg)
	btn.add_theme_font_override("font", Style.heading_font())
	btn.add_theme_font_size_override("font_size", 15)

func _resolve_special_anchor_action(room_id: String, order: int) -> Dictionary:
	if HomeCatalog.is_home_space(room_id) and room_id in HomeCatalog.ROOMS:
		var plan: Dictionary = HomeCatalog.room(room_id)
		if order == int(plan.get("task", {}).get("anchor", -1)):
			return {"label": str(HOME_TASK_LABELS.get(room_id, "★ 动手做家务")), "id": "home:begin"}
		if room_id == "home_estate" and order == 1:
			return {"label": "★ 晨间温故信", "id": "v5_wake_mailbox"}
		if room_id == "home" and order == 2:
			return {"label": "★ 装扮小屋", "id": "decorate"}
		if room_id == "home_bedroom" and order == 3:
			return {"label": "★ 试穿换装", "id": "home:outfit"}
		if room_id == "home_bedroom" and order in [1, 5]:
			return {"label": "★ 睡到明天", "id": "next_day"}
		if room_id == "home_study" and order == 5:
			return {"label": "★ 画明信片", "id": "activity:art"}
	match room_id:
		"music_room":
			return {"label": "★ 弹一段旋律", "id": "activity:music"}
		"art_room":
			return {"label": "★ 画一张明信片", "id": "activity:art"}
		"science_room":
			return {"label": "★ 科学调色实验", "id": "activity:science"}
		"football_field":
			return {"label": "★ 开始射门练习", "id": "activity:football"}
	return {}

func _trigger_special_action() -> void:
	if _special_action_id.is_empty() or not is_instance_valid(game):
		return
	var act := _special_action_id
	var saved_order := bench_anchor_order
	close_workbench()
	if is_instance_valid(game.household):
		game.household._sequence = saved_order
	game._on_action(act)

func handle_input(event: InputEvent) -> bool:
	if not bench_open or not is_instance_valid(game):
		return false
	if event.is_action_pressed("ui_cancel"):
		close_workbench()
		return true
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kev := event as InputEventKey
		match kev.keycode:
			KEY_LEFT, KEY_A:
				cycle_anchor(-1)
				return true
			KEY_RIGHT, KEY_D:
				cycle_anchor(1)
				return true
			KEY_1, KEY_KP_1:
				_select_slot(0)
				return true
			KEY_2, KEY_KP_2:
				_select_slot(1)
				return true
			KEY_3, KEY_KP_3:
				_select_slot(2)
				return true
			KEY_4, KEY_KP_4:
				_select_slot(3)
				return true
			KEY_5, KEY_KP_5:
				_select_slot(4)
				return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var hit_k := _pick_3d_prop_at_screen(mm.position)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not hit_k.is_empty() else Input.CURSOR_ARROW)
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var picked := _pick_3d_prop_at_screen(mb.position)
			if not picked.is_empty():
				select_bench_item(picked, true)
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			close_workbench()
			return true
	return true

func _select_slot(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < _ordered_layer2_keys.size():
		select_bench_item(_ordered_layer2_keys[slot_idx], true)

func _pick_3d_prop_at_screen(screen_pos: Vector2) -> String:
	if not is_instance_valid(game) or not is_instance_valid(game.camera):
		return ""
	var cam: Camera3D = game.camera as Camera3D
	if cam == null:
		return ""
	var best_key := ""
	var best_dist := INF
	for key: String in _prop_nodes:
		var node: Node3D = _prop_nodes[key]
		if not is_instance_valid(node):
			continue
		var bounds: AABB = node.get_meta("art_bounds")
		var world_center := node.to_global(bounds.get_center())
		if cam.is_position_behind(world_center):
			continue
		if not _screen_bounds(cam,node,bounds).grow(14).has_point(screen_pos):
			continue
		var pt: Vector2 = cam.unproject_position(world_center)
		var d: float = pt.distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best_key = key
	return best_key

func select_bench_item(word_raw: String, user_initiated: bool = true) -> Dictionary:
	var key := word_raw.strip_edges().to_lower()
	if not _word_lookup.has(key):
		return {"ok": false}
	selected_word = key
	var info: Dictionary = _word_lookup[key]
	var word_disp := str(info.get("word", key))
	var zh_disp := str(info.get("zh", ""))
	var is_macro := str(info.get("tier", "")) == "macro"
	var tier_tag := "第一层原场景" if is_macro else "第二层场景实物"
	if is_instance_valid(_selected_title_lbl):
		_selected_title_lbl.text = "%s %s  ·  %s（%s）" % ["◆" if is_macro else "★", word_disp, zh_disp, tier_tag]
	if is_instance_valid(_selected_en_lbl):
		_selected_en_lbl.text = str(info.get("sentence_en", ""))
	if is_instance_valid(_selected_zh_lbl):
		_selected_zh_lbl.text = str(info.get("sentence_zh", ""))
	if is_instance_valid(_palace_btn):
		var peid := str(info.get("palace_entry_id", "")).strip_edges()
		_palace_btn.disabled = peid.is_empty()
		_palace_btn.text = ("◈ 记忆宫殿 · " + word_disp) if not peid.is_empty() else "· 生活常备词"

	var word_exp_gained := 0
	if user_initiated and is_instance_valid(game):
		var st_w := game.get_node_or_null("/root/State")
		if st_w != null and st_w.has_method("grant_exp"):
			var is_due := false
			var rev_dict: Dictionary = st_w.data.get("reviews", {}) if st_w.data.get("reviews") is Dictionary else {}
			var targets: Dictionary = rev_dict.get("targets", {}) if rev_dict.get("targets") is Dictionary else {}
			for tid: Variant in targets.keys():
				if str(tid).ends_with(":" + key) or str(tid) == key:
					var trec: Dictionary = targets[tid] if targets[tid] is Dictionary else {}
					if str(trec.get("state", "")) == "due":
						is_due = true
						break
			var w_res: Dictionary = st_w.grant_exp({
				"key": "word_study:" + key,
				"mode": "word_study",
				"base_exp": 10,
				"review_exp": 6,
				"repeat_exp": 1,
				"is_due_review": is_due,
			})
			word_exp_gained = int(w_res.get("exp_gained", 0))

	var placed := false
	if user_initiated and not tasks_completed:
		placed = _try_advance_placement(key, word_exp_gained)
	elif user_initiated and word_exp_gained > 0 and is_instance_valid(_task_feedback_lbl):
		_task_feedback_lbl.text = "★ 认读「%s（%s）」+%d EXP！" % [word_disp, zh_disp, word_exp_gained]
	_refresh_top_econ_label()

	for chip_k: String in _callout_buttons:
		var btn: Button = _callout_buttons[chip_k]
		if is_instance_valid(btn):
			var u_info: Dictionary = _word_lookup.get(chip_k, {})
			var uw := str(u_info.get("word", chip_k))
			var uzh := str(u_info.get("zh", ""))
			var p_done := _placed_keys.has(chip_k)
			btn.text = ("%s %s · %s" % ["✓" if p_done else "★", uw, uzh])
			_style_callout_chip(btn, chip_k == selected_word, p_done)

	if is_instance_valid(_selected_halo):
		if _prop_nodes.has(key) and is_instance_valid(_prop_nodes[key]) and not is_macro:
			var sel_node: Node3D = _prop_nodes[key]
			if bool(sel_node.get_meta("hanging",false)):
				_selected_halo.hide()
			else:
				_selected_halo.position = sel_node.position + Vector3(0.0, 0.012, 0.0)
				_selected_halo.show()
		else:
			_selected_halo.hide()

	if _prop_nodes.has(key) and is_instance_valid(_prop_nodes[key]) and not placed and not game.ui.reduced_motion:
		var prop: Node3D = _prop_nodes[key]
		prop.scale = Vector3.ONE * 1.20
		var tw := create_tween()
		tw.tween_property(prop, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var cluster := cluster_for_room(bench_room_id)
	var comp_id := str(cluster.get("companion_npc_id", "warm"))
	if user_initiated and is_instance_valid(game):
		if is_instance_valid(game.audio_director) and not placed:
			game.audio_director.play_foley("bubble_pop")
		if is_instance_valid(game.ai_bridge):
			game.ai_bridge.speak_text("%s. %s" % [word_disp, str(info.get("sentence_en", ""))], "en", comp_id)

	_update_closeup_visuals(0.0)

	return {
		"ok": true,
		"word": word_disp,
		"placed": placed,
		"anchor_order": bench_anchor_order,
		"task_index": task_index,
		"tasks_completed": tasks_completed,
	}

func _format_top_sub_text(cluster: Dictionary) -> String:
	var st := game.get_node_or_null("/root/State") if is_instance_valid(game) else null
	if st != null and st.has_method("progression_summary"):
		var s: Dictionary = st.progression_summary()
		return "▶ 展开 %d 件 · Lv.%d（%d/%d EXP）· %d 币" % [
			_ordered_layer2_keys.size(),
			int(s.get("level", 1)),
			int(s.get("into_level", 0)),
			int(s.get("level_span", 60)),
			int(st.data.get("coins", 0)),
		]
	return "▶ 原场景展开（%d 件）· %s" % [_ordered_layer2_keys.size(), str(cluster.get("companion_label", "伙伴"))]

func _refresh_top_econ_label() -> void:
	if is_instance_valid(_top_sub_lbl):
		_top_sub_lbl.text = _format_top_sub_text(cluster_for_room(bench_room_id))

func _try_advance_placement(picked_key: String, word_exp_gained: int = 0) -> bool:
	var anchor_dict := macro_item_for_anchor(bench_room_id, bench_anchor_order)
	var task: Dictionary = anchor_dict.get("placement_task", {}) if anchor_dict.get("placement_task") is Dictionary else {}
	if task.is_empty():
		return false
	var expected_item := str(task.get("item", "")).strip_edges().to_lower()
	if expected_item.is_empty() or picked_key != expected_item:
		if is_instance_valid(_task_feedback_lbl) and _word_lookup.has(picked_key):
			var picked_zh := str((_word_lookup[picked_key] as Dictionary).get("zh", picked_key))
			var exp_suffix := (" +%d EXP" % word_exp_gained) if word_exp_gained > 0 else ""
			_task_feedback_lbl.text = "刚认识了「%s（%s）」%s · 试试点选「%s」归位吧！" % [picked_key, picked_zh, exp_suffix, expected_item]
		return false

	_placed_keys[picked_key] = true
	var spec: Dictionary = anchor_dict.get("stage_spec", {}) if anchor_dict.get("stage_spec") is Dictionary else {}
	if _prop_nodes.has(picked_key) and is_instance_valid(_prop_nodes[picked_key]):
		var item_node: Node3D = _prop_nodes[picked_key]
		var dest := _vec3(spec.get("target_pos", []), _stage_origin + Vector3(0.0, 0.42, 0.0))
		if bool(item_node.get_meta("hanging",false)):
			dest.y = item_node.position.y
			dest.z = item_node.position.z
		var arc_mid := (item_node.position + dest) * 0.5 + Vector3(0.0, 0.36, 0.0)
		var tw := create_tween()
		tw.tween_property(item_node, "position", arc_mid, 0.18).set_trans(Tween.TRANS_SINE)
		tw.tween_property(item_node, "position", dest, 0.20).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if is_instance_valid(_selected_halo) and _selected_halo.visible:
			_selected_halo.position = dest + Vector3(0.0, 0.012, 0.0)

	var state_node := game.get_node_or_null("/root/State") if is_instance_valid(game) else null
	var gained := 0
	var place_exp := 0
	if state_node != null:
		state_node.record_stealth_evidence({
			"word": expected_item,
			"support_level": 0,
			"correct": true,
			"context": "spatial_bench:%s:%d" % [bench_room_id, bench_anchor_order],
		})
		var v4: Dictionary = state_node.data.get("v4", {}) if state_node.data.get("v4") is Dictionary else {}
		var done_arr: Array = v4.get("completed_commissions", []) if v4.get("completed_commissions") is Array else []
		var room_receipt := "v6_bench_%s" % bench_room_id
		var anchor_receipt := "v6_anchor_%s_%d" % [bench_room_id, bench_anchor_order]
		if not done_arr.has(room_receipt):
			if state_node.complete_v4_commission(room_receipt, 4):
				gained += 4
			state_node.complete_v4_commission(anchor_receipt, 0)
		elif not done_arr.has(anchor_receipt):
			if state_node.complete_v4_commission(anchor_receipt, 2):
				gained += 2
		if state_node.has_method("grant_exp"):
			var p_res: Dictionary = state_node.grant_exp({
				"key": "place:%s:%d" % [bench_room_id, bench_anchor_order],
				"mode": "daily_repeat",
				"base_exp": 18,
				"repeat_exp": 5,
				"coin_bonus": 0,
			})
			place_exp = int(p_res.get("exp_gained", 0)) + word_exp_gained
			gained += int(p_res.get("gift_coins", 0))

	task_index = 1
	tasks_completed = true
	if is_instance_valid(game) and is_instance_valid(game.audio_director):
		game.audio_director.play_foley("wardrobe_sparkle")
	if is_instance_valid(_task_prompt_lbl):
		_task_prompt_lbl.text = "✓ 已在原场景归位：%s  ·  %s" % [str(task.get("prompt_en", "")), str(task.get("prompt_zh", ""))]
	if is_instance_valid(_task_feedback_lbl):
		if gained > 0 or place_exp > 0:
			_task_feedback_lbl.text = "★ 归位奖励 +%d EXP · +%d 叶币！点「下一处 ▶」继续探索" % [place_exp, gained]
		else:
			_task_feedback_lbl.text = "★ 归位完成！可继续点选其他物品或看下一处场景"
	return true

func _refresh_task_prompt(anchor_dict: Dictionary) -> void:
	if not is_instance_valid(_task_prompt_lbl):
		return
	var task: Dictionary = anchor_dict.get("placement_task", {}) if anchor_dict.get("placement_task") is Dictionary else {}
	if task.is_empty():
		tasks_completed = true
		_task_prompt_lbl.text = "点选场景中的第 2 层实物或词卡，听地道发音与课本例句！"
		return
	_task_prompt_lbl.text = "【动手摆一摆】%s  ·  %s" % [
		str(task.get("prompt_en", "")),
		str(task.get("prompt_zh", "")),
	]

func _speak_selected_en() -> void:
	if not _word_lookup.has(selected_word) or not is_instance_valid(game) or not is_instance_valid(game.ai_bridge):
		return
	var info: Dictionary = _word_lookup[selected_word]
	var cluster := cluster_for_room(bench_room_id)
	game.ai_bridge.speak_text("%s. %s" % [str(info.get("word", "")), str(info.get("sentence_en", ""))], "en", str(cluster.get("companion_npc_id", "warm")))

func _speak_selected_zh() -> void:
	if not _word_lookup.has(selected_word) or not is_instance_valid(game) or not is_instance_valid(game.ai_bridge):
		return
	var info: Dictionary = _word_lookup[selected_word]
	var cluster := cluster_for_room(bench_room_id)
	game.ai_bridge.speak_text("%s，意思是%s。%s" % [str(info.get("word", "")), str(info.get("zh", "")), str(info.get("sentence_zh", ""))], "zh", str(cluster.get("companion_npc_id", "warm")))

func _speak_current_task() -> void:
	var anchor_dict := macro_item_for_anchor(bench_room_id, bench_anchor_order)
	var task: Dictionary = anchor_dict.get("placement_task", {}) if anchor_dict.get("placement_task") is Dictionary else {}
	if task.is_empty() or not is_instance_valid(game) or not is_instance_valid(game.ai_bridge):
		return
	var cluster := cluster_for_room(bench_room_id)
	game.ai_bridge.speak_text(str(task.get("prompt_en", "")), "en", str(cluster.get("companion_npc_id", "warm")))

func _open_selected_palace() -> void:
	if not _word_lookup.has(selected_word) or not is_instance_valid(game):
		return
	var peid := str((_word_lookup[selected_word] as Dictionary).get("palace_entry_id", "")).strip_edges()
	if peid.is_empty():
		return
	close_workbench()
	game._on_action("open_palace:" + peid)

# ---------------------------------------------------------------------------
# Blender 5.2 Storybook GLB Layer-2 Props + Tripo PBR Asset Integration
# ---------------------------------------------------------------------------

func _build_layer2_prop(shape: String, hex_color: String, word_key: String = "", stage_mode: String = "") -> Node3D:
	var wkey := word_key.strip_edges().to_lower()
	var tripo_map := {
		"tripo_bag": "school_pack",
		"tripo_bread": "bread",
		"tripo_gramophone": "music_gramophone",
		"tripo_hat": "star_beret",
		"tripo_ice_cream": "ice_cream",
		"tripo_lantern": "lantern",
		"tripo_nest": "nest",
		"tripo_pumpkin": "pumpkin",
		"tripo_straw_hat": "straw_hat",
		"tripo_train": "train",
		"tripo_yarn": "yarn",
		"shell": "whale_shell",
		"basket": "picnic_basket",
	}
	# Route "chicken" to its dedicated roast-drumstick Blender GLB instead of sharing tripo_bread
	if wkey != "chicken" and tripo_map.has(shape):
		var tkey := str(tripo_map[shape])
		var tnode := TripoProps.create(tkey, "display")
		if tnode != null:
			var entries := TripoProps.entries()
			var max_dim := float((entries.get(tkey, {}) as Dictionary).get("max_dimension", 0.42))
			var sc := 0.40 / clampf(max_dim, 0.16, 2.2)
			tnode.scale = Vector3.ONE * sc
			return tnode

	var l2_node := Layer2Props.create(shape, hex_color, wkey, stage_mode)
	if l2_node != null:
		return l2_node

	var root_n := Node3D.new()
	var col := Color.from_string(hex_color, Color("5b9bd5"))
	_box(root_n, Vector3(0.0, 0.08, 0.0), Vector3(0.22, 0.14, 0.18), col)
	_box(root_n, Vector3(0.0, 0.155, 0.0), Vector3(0.16, 0.025, 0.12), Color("fbf6ea"))
	return root_n

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.78
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.94
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _cone(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _torus(parent: Node3D, pos: Vector3, inner_r: float, outer_r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	mi.mesh = tm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi
