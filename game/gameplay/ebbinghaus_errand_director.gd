extends Node3D
## V8 Ebbinghaus Spaced-Repetition Errand Director (`EbbinghausErrandDirector`).
## Connects per-word forgetting curves (`V8MemoryLedger`) to natural in-world family/teacher
## errands, floating 3D golden NPC badges, a compact HUD sticky note, and 3-tier blind recall.

const CastDirector = preload("res://gameplay/home_school_cast_director.gd")
const V8Memory = preload("res://core/v8_memory_ledger.gd")
const Style = preload("res://ui/island_theme.gd")
const FONT_PATH := "res://assets/fonts/IslandSans.otf"

var game: Node3D
var active_room := ""
var _npc_badge: Label3D
var _npc_target_actor_id := ""
var _npc_fallback_pos := Vector3.INF
var _bob_clock := 0.0

var _sticky_panel: PanelContainer
var _sticky_title: Label
var _sticky_items_box: VBoxContainer
var _sticky_go_btn: Button
var _sticky_speak_btn: Button


func _exit_tree() -> void:
	if is_instance_valid(_sticky_panel):
		_sticky_panel.queue_free()
		_sticky_panel = null


func attach_to_room(owner_game: Node3D, room_id: String) -> void:
	game = owner_game
	active_room = room_id
	_clear_npc_badge()
	if not is_instance_valid(game):
		return

	var st := game.get_node_or_null("/root/State")
	var BenchScript = load("res://gameplay/spatial_cluster_bench_3d.gd")
	if st != null and BenchScript != null and BenchScript.has_cluster(room_id):
		st.v8_record_room_visit(room_id)

	_ensure_sticky_ui()
	refresh_visuals()


func is_claiming_actor_label(actor_id: String) -> bool:
	return is_instance_valid(_npc_badge) and not _npc_target_actor_id.is_empty() and _npc_target_actor_id == actor_id


func _is_overlay_active() -> bool:
	if not is_instance_valid(game):
		return false
	var bench_open: bool = is_instance_valid(game.get("spatial_bench")) and bool(game.spatial_bench.bench_open)
	var diegetic_open: bool = is_instance_valid(game.get("ui")) and is_instance_valid(game.ui.get("diegetic")) and bool(game.ui.diegetic.visible)
	var modal_open: bool = is_instance_valid(game.get("ui")) and is_instance_valid(game.ui.get("modal")) and bool(game.ui.modal.visible)
	var decor_open: bool = is_instance_valid(game.get("free_decor_studio")) and bool(game.free_decor_studio.active)
	return bench_open or diegetic_open or modal_open or decor_open


func _restore_claimed_actor_label() -> void:
	if _npc_target_actor_id.is_empty() or not is_instance_valid(game) or not is_instance_valid(game.get("living")):
		return
	if not game.living.has_method("get_actor"):
		return
	var actor: Node3D = game.living.get_actor(_npc_target_actor_id)
	if is_instance_valid(actor):
		var nlbl: Variant = actor.get("name_label")
		if nlbl is Label3D and is_instance_valid(nlbl):
			var lbl := nlbl as Label3D
			if bool(lbl.get_meta("hidden_by_errand_badge", false)):
				lbl.remove_meta("hidden_by_errand_badge")
			if _is_overlay_active():
				lbl.set_meta("wll_hidden_by_overlay", true)
				lbl.visible = false
			else:
				lbl.visible = true


func _clear_npc_badge() -> void:
	_restore_claimed_actor_label()
	if is_instance_valid(_npc_badge):
		_npc_badge.queue_free()
	_npc_badge = null
	_npc_target_actor_id = ""
	_npc_fallback_pos = Vector3.INF


func refresh_visuals() -> void:
	_clear_npc_badge()
	if not is_instance_valid(game) or game.validation_mode:
		if is_instance_valid(_sticky_panel):
			_sticky_panel.hide()
		return

	var st := game.get_node_or_null("/root/State")
	if st == null:
		return

	var mem := V8Memory.ensure(st.data)
	var ae: Dictionary = mem.get("active_errand", {})
	if ae.is_empty() and can_offer_errand(st, active_room):
		_spawn_npc_errand_badge()

	_rebuild_sticky_note(ae)


static func domain_for_room(room_id: String) -> String:
	if room_id.begins_with("home"):
		return "home"
	if room_id in CastDirector.SCHOOL_ROOMS:
		return "school"
	return ""


static func can_offer_errand(state_node: Node, room_id: String, now_sec: int = -1) -> bool:
	if state_node == null or not state_node.has_method("v8_due_words"):
		return false
	var dom := domain_for_room(room_id)
	if dom.is_empty():
		return false
	var mem := V8Memory.ensure(state_node.data)
	if not (mem.get("active_errand", {}) as Dictionary).is_empty():
		return false
	var due_local: Array[Dictionary] = state_node.v8_due_words(dom, now_sec)
	if not due_local.is_empty():
		return true
	var due_any: Array[Dictionary] = state_node.v8_due_words("", now_sec)
	return not due_any.is_empty()


static func resolve_room_giver(room_id: String) -> Dictionary:
	var cast_arr: Array = CastDirector.ROOM_CAST.get(room_id, [])
	for c_v: Variant in cast_arr:
		if c_v is Dictionary:
			var cd := c_v as Dictionary
			var cid := str(cd.get("id", ""))
			if cid not in ["textbook_kitty", "textbook_doggie"]:
				return {"id": cid, "name": str(cd.get("display_name", "伙伴"))}
	if room_id.begins_with("home"):
		return {"id": "textbook_role_lingling_mother", "name": "妈妈 · Mom"}
	return {"id": "textbook_miss_li", "name": "李老师 · Miss Li"}


static func build_errand_proposal(
	state_node: Node,
	room_id: String,
	giver_npc_id: String = "",
	giver_name: String = "",
	now_sec: int = -1
) -> Dictionary:
	if state_node == null:
		return {}
	var dom := domain_for_room(room_id)
	if dom.is_empty():
		dom = "home"
	var due_list: Array[Dictionary] = state_node.v8_due_words(dom, now_sec)
	if due_list.is_empty():
		due_list = state_node.v8_due_words("", now_sec)
	if due_list.is_empty():
		return {}

	var giver := resolve_room_giver(room_id)
	var final_npc := giver_npc_id if not giver_npc_id.is_empty() else str(giver.get("id", "textbook_role_lingling_mother"))
	var final_name := giver_name if not giver_name.is_empty() else str(giver.get("name", "妈妈 · Mom"))

	var BenchScript = load("res://gameplay/spatial_cluster_bench_3d.gd")
	var picked_targets: Array = []
	for rec: Dictionary in due_list.slice(0, 2):
		var t_room := str(rec.get("room_id", "home"))
		var t_order := int(rec.get("anchor_order", 1))
		var cl: Dictionary = BenchScript.cluster_for_room(t_room) if BenchScript != null else {}
		var r_zh := str(cl.get("room_name_zh", t_room))
		var r_en := str(cl.get("room_name_en", "room"))
		var m_dict: Dictionary = BenchScript.macro_item_for_anchor(t_room, t_order) if BenchScript != null else {}
		var a_zh := str(m_dict.get("zh", "家具"))
		var a_en := str(m_dict.get("word", "spot"))
		picked_targets.append({
			"word": str(rec.get("word", "")),
			"zh": str(rec.get("zh", "")),
			"room_id": t_room,
			"room_zh": r_zh,
			"room_en": r_en,
			"anchor_order": t_order,
			"anchor_zh": a_zh,
			"anchor_en": a_en,
			"found": false,
			"hint_tier": 0,
		})

	var t0: Dictionary = picked_targets[0]
	var prompt_en := ""
	var prompt_zh := ""
	if picked_targets.size() == 1:
		prompt_en = "Could you help me find the %s? I left it near the %s in the %s!" % [
			str(t0["word"]),
			str(t0["anchor_en"]).to_lower(),
			str(t0["room_en"]).to_lower(),
		]
		prompt_zh = "能帮我把「%s」找回来吗？就在「%s」的家具旁——先不看文字盲找 3D 实物，一次找对享双倍温故 EXP！" % [
			str(t0["word"]),
			str(t0["room_zh"]),
		]
	else:
		var t1: Dictionary = picked_targets[1]
		var r0_en := str(t0["room_en"]).to_lower()
		var r1_en := str(t1["room_en"]).to_lower()
		if r0_en == r1_en:
			prompt_en = "Could you find the %s and the %s for me? Check the %s!" % [
				str(t0["word"]),
				str(t1["word"]),
				r0_en,
			]
			prompt_zh = "能帮我找回「%s」和「%s」两件物品吗？去「%s」翻开家具盲找，一次找准有双倍温故 EXP 和叶币奖励！" % [
				str(t0["word"]),
				str(t1["word"]),
				str(t0["room_zh"]),
			]
		else:
			prompt_en = "Could you find the %s and the %s for me? Check the %s and the %s!" % [
				str(t0["word"]),
				str(t1["word"]),
				r0_en,
				r1_en,
			]
			prompt_zh = "能帮我找回「%s」和「%s」两件物品吗？去「%s」与「%s」翻开家具盲找，一次找准有双倍温故 EXP 和叶币奖励！" % [
				str(t0["word"]),
				str(t1["word"]),
				str(t0["room_zh"]),
				str(t1["room_zh"]),
			]

	return {
		"domain": dom,
		"giver_npc_id": final_npc,
		"giver_name": final_name,
		"created_sec": now_sec if now_sec >= 0 else int(Time.get_unix_time_from_system()),
		"prompt_en": prompt_en,
		"prompt_zh": prompt_zh,
		"targets": picked_targets,
	}


func accept_errand_for_room(
	room_id: String = "",
	giver_npc_id: String = "",
	giver_name: String = "",
	now_sec: int = -1,
	speak_now: bool = true
) -> Dictionary:
	if not is_instance_valid(game):
		return {"ok": false}
	var st := game.get_node_or_null("/root/State")
	if st == null:
		return {"ok": false}
	var rid := room_id if not room_id.is_empty() else active_room
	var prop := build_errand_proposal(st, rid, giver_npc_id, giver_name, now_sec)
	if prop.is_empty():
		return {"ok": false}
	if not st.v8_start_errand(prop):
		return {"ok": false}

	if speak_now and is_instance_valid(game.ai_bridge):
		game.ai_bridge.speak_text(str(prop.get("prompt_en", "")), "en", str(prop.get("giver_npc_id", "warm")))
	if speak_now and is_instance_valid(game.audio_director):
		game.audio_director.play_foley("bubble_pop")

	refresh_visuals()
	return {"ok": true, "errand": prop}


func _spawn_npc_errand_badge() -> void:
	if not is_instance_valid(game):
		return
	var giver := resolve_room_giver(active_room)
	var cid := str(giver.get("id", ""))
	var actor_title := str(giver.get("name", "伙伴")).strip_edges()
	if is_instance_valid(game.get("living")) and game.living.has_method("get_actor"):
		var actor: Node3D = game.living.get_actor(cid)
		if is_instance_valid(actor):
			_npc_target_actor_id = cid
			var dname := str(actor.get("display_name")).strip_edges()
			if not dname.is_empty():
				actor_title = dname
	if _npc_target_actor_id.is_empty():
		for entry: Dictionary in game.interactions:
			if str(entry.get("id", "")) in ["teacher", "lunch", "sports"]:
				_npc_fallback_pos = entry.get("position", Vector3.ZERO) + Vector3(0.0, 2.55, 0.0)
				break
	if _npc_target_actor_id.is_empty() and _npc_fallback_pos == Vector3.INF:
		return

	_npc_badge = Label3D.new()
	_npc_badge.name = "V8ErrandNPCBadge"
	_npc_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_npc_badge.no_depth_test = true
	_npc_badge.fixed_size = false
	_npc_badge.pixel_size = 0.0040
	_npc_badge.font_size = 64
	_npc_badge.line_spacing = 10.0
	_npc_badge.outline_size = 7
	_npc_badge.modulate = Color("fff6cf")
	_npc_badge.outline_modulate = Color("5c3d14")
	_npc_badge.text = ("◈ 温故寻物委托\n" + actor_title) if not _npc_target_actor_id.is_empty() else "◈ 温故寻物委托"
	if ResourceLoader.exists(FONT_PATH):
		var fnt := load(FONT_PATH) as Font
		if fnt != null:
			_npc_badge.font = fnt
	add_child(_npc_badge)
	_sync_badge_position(0.0)


func _sync_badge_position(delta: float) -> void:
	if not is_instance_valid(_npc_badge) or not is_instance_valid(game):
		return
	_bob_clock += delta
	var bob := sin(_bob_clock * 3.2) * 0.05
	var overlay_open := _is_overlay_active()
	if not _npc_target_actor_id.is_empty() and is_instance_valid(game.get("living")):
		var actor: Node3D = game.living.get_actor(_npc_target_actor_id)
		if is_instance_valid(actor):
			var nlbl: Variant = actor.get("name_label")
			var head_y := 2.62
			if nlbl is Label3D and is_instance_valid(nlbl):
				var base_lp: Vector3 = (nlbl as Label3D).get_meta("wll_base_local_pos", (nlbl as Label3D).position)
				head_y = base_lp.y + 0.18
			var base_world := actor.global_position + Vector3(0.0, head_y + bob, 0.0)
			var local_base := to_local(base_world)
			_npc_badge.set_meta("wll_base_local_pos", local_base)
			var wll_off: Vector3 = _npc_badge.get_meta("wll_applied_offset", Vector3.ZERO)
			_npc_badge.position = local_base + wll_off
			_npc_badge.visible = not overlay_open
			if nlbl is Label3D and is_instance_valid(nlbl):
				var lbl := nlbl as Label3D
				if _npc_badge.visible:
					lbl.set_meta("hidden_by_errand_badge", true)
					lbl.visible = false
				elif overlay_open:
					lbl.set_meta("wll_hidden_by_overlay", true)
					lbl.visible = false
				else:
					lbl.visible = true
			return
	if _npc_fallback_pos != Vector3.INF:
		var fb_world := _npc_fallback_pos + Vector3(0.0, bob, 0.0)
		var fb_local := to_local(fb_world)
		_npc_badge.set_meta("wll_base_local_pos", fb_local)
		var fb_off: Vector3 = _npc_badge.get_meta("wll_applied_offset", Vector3.ZERO)
		_npc_badge.position = fb_local + fb_off
		_npc_badge.visible = not overlay_open


func _ensure_sticky_ui() -> void:
	if is_instance_valid(_sticky_panel) or not is_instance_valid(game) or not is_instance_valid(game.ui) or not is_instance_valid(game.ui.root):
		return
	var ui: CanvasLayer = game.ui
	_sticky_panel = PanelContainer.new()
	_sticky_panel.name = "ErrandStickyCard"
	_sticky_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_sticky_panel.offset_left = -296
	_sticky_panel.offset_right = -16
	_sticky_panel.offset_top = 92
	_sticky_panel.offset_bottom = 228
	var sb := Style.pill(Color(0.998, 0.985, 0.935, 0.95), Color("dfb860"), Color("c69c3e"), 18, 12, 10)
	sb.shadow_size = 8
	_sticky_panel.add_theme_stylebox_override("panel", sb)
	ui.root.add_child(_sticky_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_sticky_panel.add_child(col)

	_sticky_title = ui.label("◈ 温故寻物小便签", 15, Color("614313"))
	_sticky_title.add_theme_font_override("font", Style.heading_font())
	col.add_child(_sticky_title)

	_sticky_items_box = VBoxContainer.new()
	_sticky_items_box.add_theme_constant_override("separation", 4)
	col.add_child(_sticky_items_box)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	col.add_child(btn_row)

	_sticky_speak_btn = ui.button("♪ 听委托", "", false, Vector2(96, 30))
	_sticky_speak_btn.add_theme_font_size_override("font_size", 13)
	_sticky_speak_btn.pressed.connect(_speak_active_errand)
	btn_row.add_child(_sticky_speak_btn)

	_sticky_go_btn = ui.button("▷ 去找物品", "", true, Vector2(124, 30))
	_sticky_go_btn.add_theme_font_size_override("font_size", 13)
	_sticky_go_btn.pressed.connect(_jump_to_next_errand_target)
	btn_row.add_child(_sticky_go_btn)
	_sticky_panel.hide()


func _rebuild_sticky_note(ae: Dictionary) -> void:
	if not is_instance_valid(_sticky_panel) or not is_instance_valid(game):
		return
	if ae.is_empty() or not (ae.get("targets", []) is Array) or (ae["targets"] as Array).is_empty():
		_sticky_panel.hide()
		return

	_sticky_title.text = "◈ %s 的寻物便签" % str(ae.get("giver_name", "伙伴"))
	for ch: Node in _sticky_items_box.get_children():
		_sticky_items_box.remove_child(ch)
		ch.queue_free()

	for tv: Variant in ae["targets"]:
		if not (tv is Dictionary):
			continue
		var td := tv as Dictionary
		var w := str(td.get("word", ""))
		var r_zh := str(td.get("room_zh", "房间"))
		var found := bool(td.get("found", false))
		var h_tier := int(td.get("hint_tier", 0))
		var zh_tail := ("（%s）" % str(td.get("zh", ""))) if (found or h_tier >= 2) else ""
		var line_txt := ("%s %s%s · %s" % ["✓" if found else "◈", w, zh_tail, "已找回" if found else ("去" + r_zh)])
		var lbl: Label = game.ui.label(line_txt, 14, Color("2f6b3e") if found else Style.INK)
		_sticky_items_box.add_child(lbl)

	_update_sticky_visibility()


func _update_sticky_visibility() -> void:
	if not is_instance_valid(_sticky_panel) or not is_instance_valid(game):
		return
	var st := game.get_node_or_null("/root/State")
	if st == null or game.validation_mode:
		_sticky_panel.hide()
		return
	var ae: Dictionary = V8Memory.ensure(st.data).get("active_errand", {})
	if ae.is_empty():
		_sticky_panel.hide()
		return
	var modal_open: bool = is_instance_valid(game.ui) and is_instance_valid(game.ui.modal) and bool(game.ui.modal.visible)
	var diegetic_open: bool = is_instance_valid(game.ui) and is_instance_valid(game.ui.diegetic) and bool(game.ui.diegetic.visible)
	var decor_open: bool = is_instance_valid(game.get("free_decor_studio")) and bool(game.free_decor_studio.active)
	_sticky_panel.visible = not (modal_open or diegetic_open or decor_open)


func _speak_active_errand() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.ai_bridge):
		return
	var st := game.get_node_or_null("/root/State")
	if st == null:
		return
	var ae: Dictionary = V8Memory.ensure(st.data).get("active_errand", {})
	if ae.is_empty():
		return
	var targets: Array = ae.get("targets", [])
	var words: Array[String] = []
	for tv: Variant in targets:
		if tv is Dictionary and not bool((tv as Dictionary).get("found", false)):
			words.append(str((tv as Dictionary).get("word", "")))
	if words.is_empty():
		return
	var en := "Please help me find the %s!" % (" and the ".join(words))
	game.ai_bridge.speak_text(en, "en", str(ae.get("giver_npc_id", "warm")))


func _jump_to_next_errand_target() -> void:
	if not is_instance_valid(game):
		return
	var st := game.get_node_or_null("/root/State")
	if st == null:
		return
	var ae: Dictionary = V8Memory.ensure(st.data).get("active_errand", {})
	for tv: Variant in ae.get("targets", []):
		if tv is Dictionary and not bool((tv as Dictionary).get("found", false)):
			var td := tv as Dictionary
			var tr := str(td.get("room_id", "home"))
			var to := int(td.get("anchor_order", 1))
			game._on_action("v6_bench_open:%s:%d" % [tr, to])
			return


static func format_masked_callout(word_disp: String, zh_disp: String, hint_tier: int, is_done: bool) -> String:
	if is_done:
		return "✓ %s · %s" % [word_disp, zh_disp]
	if hint_tier <= 0:
		return "★ ？"
	if hint_tier == 1:
		return "★ %s" % skeleton_word(word_disp)
	return "★ %s · %s" % [word_disp, zh_disp]


static func skeleton_word(word: String) -> String:
	var w := word.strip_edges()
	if w.length() <= 2:
		return w.left(1) + " _"
	var parts: Array[String] = [w.substr(0, 1)]
	for i in range(1, w.length() - 1):
		var ch := w.substr(i, 1)
		parts.append("-" if ch == "-" else "_")
	parts.append(w.substr(w.length() - 1, 1))
	return " ".join(parts)


func _process(delta: float) -> void:
	_sync_badge_position(delta)
	_update_sticky_visibility()
