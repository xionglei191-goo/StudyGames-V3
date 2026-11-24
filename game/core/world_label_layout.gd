extends Node
## V9 Global 2D CanvasLayer Storybook Pill Renderer & Real-Time De-Overlap Solver (`WorldLabelLayout`).
## Runs at `process_priority = 50` (after camera, actors, plaques, errands, and 2D HUD/prompts update):
##   1. Renders active room `Label3D`s as crisp 2D `CanvasLayer` Storybook Pills inside `WorldLabel2DOverlay`
##      (at index 0 of `game.ui.root`, behind HUD, prompts, speech bubbles, `DiegeticDialogue`, and modals),
##      hiding blurry 3D scene-space text via `lbl.transparency = 1.0` while keeping `lbl.visible` & `lbl.text` untouched!
##   2. Suppresses all background room pills whenever `DiegeticDialogue`, `modal`, `SpatialClusterBench3D`, or `FreeGridDecorStudio` is open.
##   3. Solves exact 2D `PanelContainer` pixel rectangles against HUD corners/dock, `[E]`/`[Q]` prompts, proximity bubbles,
##      and sticky errand notes so ZERO pairwise `Rect2` overlaps ever occur.
##   4. Complete no-op when `game.validation_mode` is true (restoring `lbl.transparency = 0.0`).

const Style = preload("res://ui/island_theme.gd")

const PIXEL_OFFSETS_2D: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(0.0, -34.0),
	Vector2(0.0, 34.0),
	Vector2(-68.0, -18.0),
	Vector2(68.0, -18.0),
	Vector2(0.0, -68.0),
	Vector2(-96.0, 0.0),
	Vector2(96.0, 0.0),
	Vector2(-88.0, 28.0),
	Vector2(88.0, 28.0),
	Vector2(0.0, 68.0),
	Vector2(-128.0, -24.0),
	Vector2(128.0, -24.0),
	Vector2(-128.0, 26.0),
	Vector2(128.0, 26.0),
	Vector2(0.0, -102.0),
	Vector2(-76.0, -56.0),
	Vector2(76.0, -56.0),
	Vector2(-76.0, 56.0),
	Vector2(76.0, 56.0),
	Vector2(0.0, 102.0),
	Vector2(-168.0, 0.0),
	Vector2(168.0, 0.0),
	Vector2(-160.0, -54.0),
	Vector2(160.0, -54.0),
	Vector2(-160.0, 54.0),
	Vector2(160.0, 54.0),
	Vector2(0.0, -136.0),
	Vector2(-208.0, -22.0),
	Vector2(208.0, -22.0),
]

var game: Node3D
var _active_room := ""
var _snap_frames := 3
var _validation_restored := true
var _overlay_2d: Control
var _pill_pool: Dictionary = {} # lbl_id (int) -> {"pill_id": int, "label_id": int, "kind": String, "text": String, "size": Vector2, "offset": Vector2, "has_offset": bool}


func _ready() -> void:
	name = "WorldLabelLayout"
	process_priority = 50


func _exit_tree() -> void:
	_clear_all_pills()
	if is_instance_valid(_overlay_2d):
		_overlay_2d.queue_free()
		_overlay_2d = null


func setup(owner_game: Node3D) -> void:
	game = owner_game
	process_priority = 50
	_ensure_overlay_layer()
	if not is_instance_valid(game) or not is_instance_valid(game.get("ui")):
		return
	var ui_node: Node = game.ui
	var dieg: Variant = ui_node.get("diegetic")
	if dieg is Node and is_instance_valid(dieg) and (dieg as Node).has_signal("overlay_visibility_changed"):
		(dieg as Node).connect("overlay_visibility_changed", func(is_open: bool):
			if is_open:
				_hide_overlay_pills()
			else:
				restore_overlay_suppression()
		)
	var mod: Variant = ui_node.get("modal")
	if mod is CanvasItem and is_instance_valid(mod):
		(mod as CanvasItem).visibility_changed.connect(func():
			if is_instance_valid(mod) and (mod as CanvasItem).visible:
				_hide_overlay_pills()
			else:
				restore_overlay_suppression()
		)


func _ensure_overlay_layer() -> Control:
	if is_instance_valid(_overlay_2d):
		if is_instance_valid(game) and is_instance_valid(game.get("ui")):
			var ui_root := game.ui.get("root") as Control
			if is_instance_valid(ui_root) and _overlay_2d.get_parent() == ui_root and _overlay_2d.get_index() != 0:
				ui_root.move_child(_overlay_2d, 0)
		return _overlay_2d
	if not is_instance_valid(game) or not is_instance_valid(game.get("ui")):
		return null
	var root_ctrl := game.ui.get("root") as Control
	if not is_instance_valid(root_ctrl):
		return null
	_overlay_2d = Control.new()
	_overlay_2d.name = "WorldLabel2DOverlay"
	_overlay_2d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_overlay_2d)
	root_ctrl.move_child(_overlay_2d, 0)
	return _overlay_2d


func on_room_changed(room_id: String) -> void:
	_active_room = room_id
	_snap_frames = 3
	_prune_stale_pills(true)


func restore_overlay_suppression() -> void:
	if is_instance_valid(game):
		var errand_dir: Node = game.get("errand_director") if is_instance_valid(game.get("errand_director")) else null
		for lbl: Label3D in _collect_all_room_labels():
			if is_instance_valid(lbl) and bool(lbl.get_meta("wll_hidden_by_overlay", false)):
				lbl.remove_meta("wll_hidden_by_overlay")
				var actor_id := _actor_id_for_name_label(lbl)
				if not actor_id.is_empty() and errand_dir != null and errand_dir.has_method("is_claiming_actor_label") and bool(errand_dir.is_claiming_actor_label(actor_id)):
					lbl.visible = false
				else:
					lbl.visible = true
	_snap_frames = maxi(_snap_frames, 2)


func is_overlay_active() -> bool:
	if not is_instance_valid(game):
		return false
	var diegetic_open: bool = is_instance_valid(game.get("ui")) and is_instance_valid(game.ui.get("diegetic")) and bool(game.ui.diegetic.visible)
	var modal_open: bool = is_instance_valid(game.get("ui")) and is_instance_valid(game.ui.get("modal")) and bool(game.ui.modal.visible)
	var bench_open: bool = is_instance_valid(game.get("spatial_bench")) and bool(game.spatial_bench.bench_open)
	var decor_open: bool = is_instance_valid(game.get("free_decor_studio")) and bool(game.free_decor_studio.active)
	return diegetic_open or modal_open or bench_open or decor_open


func _pill_from_rec(rec: Dictionary) -> PanelContainer:
	var pid := int(rec.get("pill_id", 0))
	if pid != 0 and is_instance_id_valid(pid):
		return instance_from_id(pid) as PanelContainer
	return null


func _text_lbl_from_rec(rec: Dictionary) -> Label:
	var lid := int(rec.get("label_id", 0))
	if lid != 0 and is_instance_id_valid(lid):
		return instance_from_id(lid) as Label
	return null


func _hide_overlay_pills() -> void:
	if is_instance_valid(_overlay_2d):
		_overlay_2d.hide()
	for iid: Variant in _pill_pool.keys():
		var rec: Dictionary = _pill_pool[iid]
		var pill := _pill_from_rec(rec)
		if pill != null:
			pill.hide()


func _restore_3d_labels_for_validation() -> void:
	for lbl: Label3D in _collect_all_room_labels():
		if is_instance_valid(lbl) and bool(lbl.get_meta("wll_suppressed_3d", false)):
			lbl.remove_meta("wll_suppressed_3d")
			lbl.transparency = 0.0
			lbl.modulate.a = float(lbl.get_meta("wll_orig_mod_a", 1.0))
			lbl.outline_modulate.a = float(lbl.get_meta("wll_orig_out_a", 1.0))
	_hide_overlay_pills()
	_validation_restored = true


func _clear_all_pills() -> void:
	for iid: Variant in _pill_pool.keys():
		var rec: Dictionary = _pill_pool[iid]
		var pill := _pill_from_rec(rec)
		if pill != null:
			pill.queue_free()
	_pill_pool.clear()


func _prune_stale_pills(reset_offsets: bool = false) -> void:
	var stale: Array = []
	for iid_v: Variant in _pill_pool.keys():
		var iid := int(iid_v)
		var rec: Dictionary = _pill_pool[iid_v]
		var pill := _pill_from_rec(rec)
		var lbl: Label3D = instance_from_id(iid) as Label3D if (iid != 0 and is_instance_id_valid(iid)) else null
		if lbl == null or not lbl.is_inside_tree() or pill == null:
			if pill != null:
				pill.queue_free()
			stale.append(iid_v)
		elif reset_offsets:
			rec["has_offset"] = false
			pill.hide()
	for k: Variant in stale:
		_pill_pool.erase(k)


func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	if bool(game.get("validation_mode")):
		if not _validation_restored:
			_restore_3d_labels_for_validation()
		return
	if bool(game.get("loading_room")):
		_hide_overlay_pills()
		return

	_validation_restored = false
	_ensure_overlay_layer()
	_suppress_all_3d_room_meshes()

	# Hide all background room pills when any dialogue/modal/workbench/mini-activity overlay is active
	var hh: Variant = game.get("household")
	var hh_open: bool = hh is Node and is_instance_valid(hh) and is_instance_valid((hh as Node).get("activity"))
	if is_overlay_active() or is_instance_valid(game.get("orchard_activity")) or hh_open:
		_hide_overlay_pills()
		return

	solve_now(delta, _snap_frames > 0 or (is_instance_valid(game.get("ui")) and bool(game.ui.get("reduced_motion"))))
	if _snap_frames > 0:
		_snap_frames -= 1


func _suppress_all_3d_room_meshes() -> void:
	for lbl: Label3D in _collect_all_room_labels():
		if is_instance_valid(lbl):
			if not lbl.has_meta("wll_orig_mod_a"):
				lbl.set_meta("wll_orig_mod_a", lbl.modulate.a)
			if not lbl.has_meta("wll_orig_out_a"):
				lbl.set_meta("wll_orig_out_a", lbl.outline_modulate.a)
			lbl.set_meta("wll_suppressed_3d", true)
			lbl.transparency = 1.0
			lbl.modulate.a = 0.0
			lbl.outline_modulate.a = 0.0


func solve_now(delta: float = 0.016, snap_immediate: bool = false) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.get("camera")):
		return
	var cam: Camera3D = game.camera as Camera3D
	if cam == null:
		return
	var layer := _ensure_overlay_layer()
	if layer == null:
		return
	if is_overlay_active():
		_hide_overlay_pills()
		return

	if is_instance_valid(game.get("ui")) and game.ui.has_method("resolve_floating_2d_overlaps"):
		game.ui.resolve_floating_2d_overlaps()

	_suppress_all_3d_room_meshes()
	_prune_stale_pills(false)
	layer.show()

	var vp := _viewport_size()
	var safe_screen := Rect2(14.0, 14.0, maxf(120.0, vp.x - 28.0), maxf(120.0, vp.y - 104.0))
	var occupied_rects: Array[Rect2] = _seed_occupied_2d_rects(vp)

	var active_ids: Dictionary = {}
	var entries := _gather_prioritized_labels()

	for entry: Dictionary in entries:
		var lbl: Label3D = entry["lbl"]
		var kind_str: String = entry["kind"]
		var world_pos: Vector3 = entry["world_pos"]
		var iid := lbl.get_instance_id()

		if cam.is_position_behind(world_pos):
			if _pill_pool.has(iid):
				var hidden_p := _pill_from_rec(_pill_pool[iid] as Dictionary)
				if hidden_p != null:
					hidden_p.hide()
			continue

		var rec := _ensure_pill_for_label(lbl, kind_str)
		var pill := _pill_from_rec(rec)
		if pill == null:
			continue
		var psize: Vector2 = rec["size"]
		var anchor_2d := cam.unproject_position(world_pos)

		var found_fit := false
		var chosen_off := Vector2.ZERO
		var chosen_rect := Rect2()

		for off: Vector2 in PIXEL_OFFSETS_2D:
			var tl := (anchor_2d - psize * 0.5 + off).round()
			var cand_rect := Rect2(tl, psize)
			if not safe_screen.encloses(cand_rect):
				continue
			var padded := cand_rect.grow(3.0)
			var hit := false
			for occ: Rect2 in occupied_rects:
				if padded.intersects(occ):
					hit = true
					break
			if not hit:
				found_fit = true
				chosen_off = off
				chosen_rect = cand_rect
				break

		if not found_fit:
			pill.hide()
			continue

		var final_off := chosen_off
		var final_rect := chosen_rect
		var has_prev := bool(rec.get("has_offset", false))
		var prev_off: Vector2 = rec.get("offset", chosen_off)
		if not snap_immediate and has_prev and prev_off.distance_to(chosen_off) > 0.5:
			var blended_off := prev_off.lerp(chosen_off, minf(1.0, delta * 14.0))
			var blend_tl := (anchor_2d - psize * 0.5 + blended_off).round()
			var blend_rect := Rect2(blend_tl, psize)
			if safe_screen.encloses(blend_rect):
				var blend_ok := true
				var blend_pad := blend_rect.grow(2.5)
				for occ: Rect2 in occupied_rects:
					if blend_pad.intersects(occ):
						blend_ok = false
						break
				if blend_ok:
					final_off = blended_off
					final_rect = blend_rect

		rec["offset"] = final_off
		rec["has_offset"] = true
		pill.position = final_rect.position
		pill.size = psize
		pill.show()
		active_ids[iid] = true
		occupied_rects.append(final_rect.grow(3.0))

	for iid: Variant in _pill_pool.keys():
		if not active_ids.has(iid):
			var unused_pill := _pill_from_rec(_pill_pool[iid] as Dictionary)
			if unused_pill != null:
				unused_pill.hide()


func _ensure_pill_for_label(lbl: Label3D, kind_str: String) -> Dictionary:
	var iid := lbl.get_instance_id()
	var rec: Dictionary = _pill_pool.get(iid, {})
	var pill := _pill_from_rec(rec)
	var text_lbl := _text_lbl_from_rec(rec)

	if pill == null or text_lbl == null:
		pill = PanelContainer.new()
		pill.name = "WorldPill_" + str(lbl.name)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_lbl = Label.new()
		text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill.add_child(text_lbl)
		_overlay_2d.add_child(pill)
		rec = {
			"pill_id": pill.get_instance_id(),
			"label_id": text_lbl.get_instance_id(),
			"kind": "",
			"text": "",
			"size": Vector2.ZERO,
			"offset": Vector2.ZERO,
			"has_offset": false,
		}
		_pill_pool[iid] = rec

	var dirty := false
	if str(rec.get("kind", "")) != kind_str:
		_apply_pill_style(pill, text_lbl, kind_str)
		rec["kind"] = kind_str
		dirty = true
	if str(rec.get("text", "")) != lbl.text:
		text_lbl.text = lbl.text
		rec["text"] = lbl.text
		dirty = true
	if dirty or (rec["size"] as Vector2).x <= 1.0:
		pill.reset_size()
		var min_sz := pill.get_combined_minimum_size().ceil()
		pill.size = min_sz
		rec["size"] = min_sz
	return rec


func _apply_pill_style(pill: PanelContainer, text_lbl: Label, kind_str: String) -> void:
	var sb := StyleBoxFlat.new()
	if kind_str == "errand":
		sb.bg_color = Color(0.998, 0.968, 0.855, 0.96)
		sb.border_color = Color("d8a43a")
		sb.set_border_width_all(2)
		sb.border_width_bottom = 3
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 5
		sb.shadow_color = Color(0.24, 0.17, 0.06, 0.14)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		text_lbl.add_theme_font_override("font", Style.heading_font())
		text_lbl.add_theme_font_size_override("font_size", 14)
		text_lbl.add_theme_color_override("font_color", Color("4d3108"))
		text_lbl.add_theme_constant_override("line_spacing", 2)
	elif kind_str == "npc":
		sb.bg_color = Color(0.996, 0.988, 0.962, 0.92)
		sb.border_color = Color("d9ccb2")
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.shadow_color = Color(0.20, 0.16, 0.09, 0.10)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 1)
		text_lbl.add_theme_font_override("font", Style.heading_font())
		text_lbl.add_theme_font_size_override("font_size", 13)
		text_lbl.add_theme_color_override("font_color", Color("3a3128"))
		text_lbl.add_theme_constant_override("line_spacing", 2)
	elif kind_str == "plaque":
		sb.bg_color = Color(0.968, 0.978, 0.952, 0.90)
		sb.border_color = Color("bccbb4")
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.shadow_color = Color(0.16, 0.22, 0.16, 0.09)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 1)
		text_lbl.add_theme_font_override("font", Style.heading_font())
		text_lbl.add_theme_font_size_override("font_size", 13)
		text_lbl.add_theme_color_override("font_color", Color("2f4634"))
		text_lbl.add_theme_constant_override("line_spacing", 2)
	else:
		sb.bg_color = Color(0.988, 0.972, 0.932, 0.91)
		sb.border_color = Color("d5be93")
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 7
		sb.content_margin_right = 7
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.shadow_color = Color(0.20, 0.16, 0.09, 0.09)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, 1)
		text_lbl.add_theme_font_override("font", Style.body_font())
		text_lbl.add_theme_font_size_override("font_size", 12)
		text_lbl.add_theme_color_override("font_color", Color("544027"))
		text_lbl.add_theme_constant_override("line_spacing", 2)
	pill.add_theme_stylebox_override("panel", sb)


func compute_visible_label_screen_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_instance_valid(_overlay_2d) or not _overlay_2d.visible:
		return out
	for iid_v: Variant in _pill_pool.keys():
		var iid := int(iid_v)
		if iid == 0 or not is_instance_id_valid(iid):
			continue
		var l := instance_from_id(iid) as Label3D
		if l == null or not l.is_inside_tree():
			continue
		var rec: Dictionary = _pill_pool[iid_v]
		var p := _pill_from_rec(rec)
		if p == null or not p.is_visible_in_tree() or p.modulate.a <= 0.05:
			continue
		var sz := p.size if p.size.x > 1.0 else p.get_combined_minimum_size()
		out.append({
			"node": l,
			"pill": p,
			"name": str(l.name),
			"kind": str(rec.get("kind", "label2d")),
			"text": l.text,
			"rect": Rect2(p.position, sz),
		})
	return out


func compute_visible_2d_prompt_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_instance_valid(game) or not is_instance_valid(game.get("ui")):
		return out
	var ui_n: Node = game.ui
	for pair: Array in [
		[ui_n.get("prompt"), "prompt"],
		[ui_n.get("prompt_cycle"), "prompt_cycle"],
		[ui_n.get("bubble_panel"), "bubble_panel"],
		[ui_n.get("hover_prompt"), "hover_prompt"],
	]:
		var ctrl: Variant = pair[0]
		if ctrl is Control and is_instance_valid(ctrl) and (ctrl as Control).is_visible_in_tree():
			var c := ctrl as Control
			var sz := c.size if c.size.x > 1.0 else c.get_combined_minimum_size()
			out.append({
				"node": c,
				"name": str(c.name),
				"kind": str(pair[1]),
				"rect": Rect2(c.global_position, sz),
			})
	var ed: Variant = game.get("errand_director")
	if ed is Node and is_instance_valid(ed):
		var sp: Variant = (ed as Node).get("_sticky_panel")
		if sp is Control and is_instance_valid(sp) and (sp as Control).is_visible_in_tree():
			var sc := sp as Control
			var ssz := sc.size if sc.size.x > 1.0 else sc.get_combined_minimum_size()
			out.append({
				"node": sc,
				"name": str(sc.name),
				"kind": "sticky_panel",
				"rect": Rect2(sc.global_position, ssz),
			})
	return out


static func label_screen_rect(lbl: Label3D, camera: Camera3D, vp: Vector2) -> Rect2:
	if not is_instance_valid(lbl) or not is_instance_valid(camera):
		return Rect2()
	if camera.is_position_behind(lbl.global_position):
		return Rect2()
	var fnt: Font = lbl.font if lbl.font != null else ThemeDB.fallback_font
	if fnt == null:
		return Rect2()
	var fsize := maxi(8, lbl.font_size)
	var raw_px := fnt.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	var px_per_meter := vp.y / maxf(0.1, camera.size) if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else (vp.y * 0.5) / (maxf(0.5, lbl.global_position.distance_to(camera.global_position)) * maxf(0.05, tan(deg_to_rad(camera.fov * 0.5))))
	var screen_size := raw_px * (lbl.pixel_size * px_per_meter)
	var center := camera.unproject_position(lbl.global_position)
	return Rect2(center - screen_size * 0.5, screen_size)


func _viewport_size() -> Vector2:
	if is_instance_valid(game) and is_instance_valid(game.get("ui")):
		var r: Variant = game.ui.get("root")
		if r is Control and is_instance_valid(r) and (r as Control).size.x > 10.0:
			return (r as Control).size
	if is_instance_valid(game) and game.get_viewport() != null:
		var vs := game.get_viewport().get_visible_rect().size
		if vs.x > 10.0:
			return vs
	return Vector2(1440, 900)


func _seed_occupied_2d_rects(vp: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not is_instance_valid(game) or not is_instance_valid(game.get("ui")):
		return rects
	var ui_n: Node = game.ui
	var hud_v: Variant = ui_n.get("hud")
	if hud_v is Control and is_instance_valid(hud_v) and (hud_v as Control).visible:
		rects.append(Rect2(12.0, 12.0, 340.0, 204.0))
		rects.append(Rect2(vp.x - 364.0, 12.0, 352.0, 74.0))
		var hud_c := hud_v as Control
		for sub_name: String in ["dock", "level_banner"]:
			var sub: Variant = hud_c.get(sub_name)
			if sub is Control and is_instance_valid(sub) and (sub as Control).visible:
				var sc := sub as Control
				var ssz := sc.size if sc.size.x > 1.0 else sc.get_combined_minimum_size()
				rects.append(Rect2(sc.global_position, ssz).grow(4.0))
		for ui_sub_name: String in ["controls_hint", "navigation_label"]:
			var usub: Variant = ui_n.get(ui_sub_name)
			if usub is Control and is_instance_valid(usub) and (usub as Control).visible:
				var uc := usub as Control
				var usz := uc.size if uc.size.x > 1.0 else uc.get_combined_minimum_size()
				rects.append(Rect2(uc.global_position, usz).grow(4.0))

	var toast_v: Variant = ui_n.get("toast_label")
	if toast_v is Control and is_instance_valid(toast_v) and (toast_v as Control).visible:
		var tc := toast_v as Control
		var tsz := tc.size if tc.size.y > 4.0 else Vector2(maxf(260.0, tc.size.x), 42.0)
		rects.append(Rect2(tc.global_position, tsz).grow(4.0))

	for pdict: Dictionary in compute_visible_2d_prompt_rects():
		rects.append((pdict["rect"] as Rect2).grow(4.0))
	return rects


func _actor_id_for_name_label(lbl: Label3D) -> String:
	var p := lbl.get_parent()
	if p != null and p.has_meta("character_id"):
		return str(p.get_meta("character_id"))
	if p != null and ("character_id" in p):
		return str(p.get("character_id"))
	return ""


func _collect_all_room_labels() -> Array[Label3D]:
	var out: Array[Label3D] = []
	var seen: Dictionary = {}
	if not is_instance_valid(game):
		return out

	var add_lbl := func(candidate: Variant) -> void:
		if not (candidate is Label3D) or not is_instance_valid(candidate):
			return
		var l := candidate as Label3D
		if l.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
			return
		var iid := l.get_instance_id()
		if seen.has(iid):
			return
		seen[iid] = true
		out.append(l)

	var ed: Variant = game.get("errand_director")
	if ed is Node and is_instance_valid(ed):
		add_lbl.call((ed as Node).get("_npc_badge"))

	var liv: Variant = game.get("living")
	if liv is Node and is_instance_valid(liv):
		for n: Node in (liv as Node).find_children("*", "Label3D", true, false):
			add_lbl.call(n)

	var sb: Variant = game.get("spatial_bench")
	if sb is Node and is_instance_valid(sb) and (sb as Node).get("macro_plaques") is Array:
		for l_v: Variant in (sb as Node).get("macro_plaques"):
			add_lbl.call(l_v)

	var pl: Variant = game.get("palace_loci")
	if pl is Node and is_instance_valid(pl):
		add_lbl.call((pl as Node).get("_badge_label"))

	for container_prop: String in ["tactile_quests", "world", "journey"]:
		var cn: Variant = game.get(container_prop)
		if cn is Node and is_instance_valid(cn):
			for n: Node in (cn as Node).find_children("*", "Label3D", true, false):
				add_lbl.call(n)

	return out


func _gather_prioritized_labels() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not is_instance_valid(game):
		return items

	var nearest_dict: Dictionary = game.nearest if (game.get("nearest") is Dictionary) else {}
	var nearest_id := str(nearest_dict.get("id", ""))
	var nearest_pos: Vector3 = nearest_dict.get("position", Vector3.INF) if nearest_dict.get("position") is Vector3 else Vector3.INF
	var player_xz := Vector2(game.player.global_position.x, game.player.global_position.z) if is_instance_valid(game.get("player")) else Vector2.ZERO
	var errand_dir: Node = game.get("errand_director") if is_instance_valid(game.get("errand_director")) else null
	var plaques: Array = game.spatial_bench.macro_plaques if (is_instance_valid(game.get("spatial_bench")) and game.spatial_bench.get("macro_plaques") is Array) else []

	for lbl: Label3D in _collect_all_room_labels():
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			continue
		var actor_id := _actor_id_for_name_label(lbl)
		if not actor_id.is_empty() and errand_dir != null and errand_dir.has_method("is_claiming_actor_label") and bool(errand_dir.is_claiming_actor_label(actor_id)):
			continue
		if not lbl.is_visible_in_tree():
			continue
		if lbl.text.strip_edges().is_empty():
			continue

		var world_pos := lbl.global_position
		var dist := Vector2(world_pos.x, world_pos.z).distance_to(player_xz)

		var kind_str := "shrine"
		var prio := 4
		if lbl.name == "V8ErrandNPCBadge":
			kind_str = "errand"
			prio = 0
		elif not actor_id.is_empty() or (is_instance_valid(game.get("world")) and (game.world as Node).is_ancestor_of(lbl)):
			kind_str = "npc"
			prio = 2
		elif plaques.has(lbl) or lbl.name == "WordTag":
			kind_str = "plaque"
			prio = 3

		if prio > 0 and not nearest_id.is_empty():
			if (not actor_id.is_empty() and nearest_id == "actor:" + actor_id) or (nearest_pos != Vector3.INF and Vector2(world_pos.x, world_pos.z).distance_to(Vector2(nearest_pos.x, nearest_pos.z)) < 0.75):
				prio = 1

		items.append({
			"lbl": lbl,
			"kind": kind_str,
			"world_pos": world_pos,
			"prio": prio,
			"dist": dist,
			"iid": lbl.get_instance_id(),
		})

	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a["prio"])
		var pb := int(b["prio"])
		if pa != pb:
			return pa < pb
		var da := float(a["dist"])
		var db := float(b["dist"])
		if absf(da - db) > 0.05:
			return da < db
		return int(a["iid"]) < int(b["iid"])
	)
	return items
