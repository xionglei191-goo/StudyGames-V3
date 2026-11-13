extends Node3D
## V5 3D Room Memory Palace Locus Shrine (`MemoryPalaceLoci3D`).
## Places a cozy Toy-PBR Walnut Storybook Lectern inside walkable rooms that host
## Memory Palace stories (`memory_palace_v5.json`).
## Uses visual-only meshes + crisp billboard `Label3D` (zero physics colliders) so
## navigation grids, raycast target picking, and `test_interaction_access.gd` are untouched.

const Content = preload("res://ui/memory_story_content.gd")
const PALACE_V5_PATH := "res://data/learning/memory_palace_v5.json"
const FONT_PATH := "res://assets/fonts/IslandSans.otf"

static var _built_index := false
static var _room_stories: Dictionary = {}
static var _all_palace_items: Array[Dictionary] = []

var game: Node3D
var active_room := ""
var shrine_pos := Vector3.ZERO
var has_shrine := false
var _lectern_root: Node3D
var _floating_star: MeshInstance3D
var _badge_label: Label3D
var _anim_t := 0.0
var _near_notified := false

static func _ensure_index() -> void:
	if _built_index:
		return
	_built_index = true
	_room_stories.clear()
	_all_palace_items.clear()
	if not FileAccess.file_exists(PALACE_V5_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALACE_V5_PATH))
	if not (parsed is Dictionary):
		return
	var stories_map: Dictionary = (parsed as Dictionary).get("stories", {}) if (parsed as Dictionary).get("stories") is Dictionary else {}
	if stories_map.is_empty():
		return

	var catalog := Content.load_catalog()
	var by_story: Dictionary = {}
	for entry_v: Variant in catalog.get("entries", []):
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v as Dictionary
		var sid := str(entry.get("story_id", "")).strip_edges()
		if sid.is_empty() or not stories_map.has(sid):
			continue
		var sdata: Dictionary = stories_map[sid] as Dictionary
		var rid := str(sdata.get("palace_room_id", "")).strip_edges()
		if rid.is_empty():
			continue
		var eid := str(entry.get("entry_id", "")).strip_edges()
		var src: Dictionary = entry.get("source_unit", {}) if entry.get("source_unit") is Dictionary else {}
		var bid := str(src.get("book_id", "")).strip_edges()
		var uids: Array = src.get("unit_ids", []) if src.get("unit_ids") is Array else []

		if not by_story.has(sid):
			var rec := {
				"story_id": sid,
				"entry_id": eid,
				"entry_by_book": {bid: eid},
				"unit_by_book": {bid: uids.duplicate()},
				"word": str(entry.get("spelling_display", "")).strip_edges(),
				"meaning_zh": str(entry.get("meaning_zh", "")).strip_edges(),
				"palace_room_id": rid,
				"palace_room_zh": str(sdata.get("palace_room_zh", "")).strip_edges(),
				"palace_locus_zh": str(sdata.get("palace_locus_zh", "")).strip_edges(),
				"title_zh": str(sdata.get("title_zh", "")).strip_edges(),
				"example_en": str(sdata.get("example_en", "")).strip_edges(),
				"example_zh": str(sdata.get("example_zh", "")).strip_edges(),
			}
			by_story[sid] = rec
			if not _room_stories.has(rid):
				_room_stories[rid] = []
			(_room_stories[rid] as Array).append(rec)
			_all_palace_items.append(rec)
		else:
			var existing: Dictionary = by_story[sid]
			(existing["entry_by_book"] as Dictionary)[bid] = eid
			(existing["unit_by_book"] as Dictionary)[bid] = uids.duplicate()

static func stories_for_room(room_id: String) -> Array:
	_ensure_index()
	return _room_stories.get(room_id, []) as Array

static func all_palace_items() -> Array[Dictionary]:
	_ensure_index()
	return _all_palace_items

static func best_entry_id_for_state(item: Dictionary, state_node: Node) -> String:
	var by_book: Dictionary = item.get("entry_by_book", {}) if item.get("entry_by_book") is Dictionary else {}
	if state_node != null and state_node.get("data") is Dictionary:
		var j: Dictionary = state_node.data.get("journey", {}) if state_node.data.get("journey") is Dictionary else {}
		var sel_book := str(j.get("selected_book_id", "")).strip_edges()
		if not sel_book.is_empty() and by_book.has(sel_book):
			return str(by_book[sel_book])
	return str(item.get("entry_id", ""))

static func illuminated_word_set(state_node: Node) -> Dictionary:
	var lit: Dictionary = {}
	if state_node == null or not (state_node.get("data") is Dictionary):
		return lit
	var d: Dictionary = state_node.data
	var v4: Dictionary = d.get("v4", {}) if d.get("v4") is Dictionary else {}
	for ev: Variant in v4.get("stealth_events", []):
		if ev is Dictionary and bool((ev as Dictionary).get("correct", false)):
			var w := str((ev as Dictionary).get("word", "")).strip_edges().to_lower()
			if not w.is_empty():
				lit[w] = true
	var j: Dictionary = d.get("journey", {}) if d.get("journey") is Dictionary else {}
	var mem: Dictionary = j.get("memory", {}) if j.get("memory") is Dictionary else {}
	var sessions: Dictionary = mem.get("sessions", {}) if mem.get("sessions") is Dictionary else {}
	var cat := Content.load_catalog()
	var eid_to_word: Dictionary = {}
	for e_v: Variant in cat.get("entries", []):
		if e_v is Dictionary:
			eid_to_word[str((e_v as Dictionary).get("entry_id", ""))] = str((e_v as Dictionary).get("spelling_display", "")).strip_edges().to_lower()
	for s_v: Variant in sessions.values():
		if s_v is Dictionary:
			var eid := str((s_v as Dictionary).get("entry_id", ""))
			if eid_to_word.has(eid):
				lit[str(eid_to_word[eid])] = true
	return lit

func attach_to_room(owner_game: Node3D, room_id: String) -> void:
	game = owner_game
	active_room = room_id
	has_shrine = false
	_lectern_root = null
	_floating_star = null
	_badge_label = null
	_near_notified = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var list := stories_for_room(room_id)
	if list.is_empty() or not is_instance_valid(game):
		return

	shrine_pos = _pick_shrine_spot()
	has_shrine = true
	_build_lectern_visuals(list.size())
	refresh_badge()

func _pick_shrine_spot() -> Vector3:
	var spawn: Vector3 = game.metadata.get("spawn", Vector3.ZERO)
	var candidates := [
		spawn + Vector3(-2.15, 0.0, -1.75),
		spawn + Vector3(-2.35, 0.0, 1.55),
		spawn + Vector3(2.25, 0.0, 1.65),
		spawn + Vector3(-1.85, 0.0, -3.15),
		spawn + Vector3(2.05, 0.0, -2.95),
		spawn + Vector3(0.0, 0.0, -2.75),
	]
	var best_pt := _snap_walkable(candidates[0])
	var best_score := -999.0
	var basket_pt := Vector3(9999.0, 0.0, 9999.0)
	if is_instance_valid(game.get("tactile_quests")) and bool(game.tactile_quests.get("_has_basket")):
		basket_pt = game.tactile_quests._basket_pos

	for cand: Vector3 in candidates:
		var snapped := _snap_walkable(cand)
		var min_clear := Vector2(snapped.x - spawn.x, snapped.z - spawn.z).length()
		var d_basket := Vector2(snapped.x - basket_pt.x, snapped.z - basket_pt.z).length()
		min_clear = minf(min_clear, d_basket)
		for inter_v: Variant in game.interactions:
			if inter_v is Dictionary and (inter_v as Dictionary).has("position"):
				var ipos: Vector3 = (inter_v as Dictionary).position
				var di := Vector2(snapped.x - ipos.x, snapped.z - ipos.z).length()
				min_clear = minf(min_clear, di)
		if min_clear > best_score:
			best_score = min_clear
			best_pt = snapped
	return best_pt

func _snap_walkable(target: Vector3) -> Vector3:
	if not is_instance_valid(game) or not game.nav_ready:
		return target
	var cell_sz := 0.75
	var raw_key := Vector2i(roundi(target.x / cell_sz), roundi(target.z / cell_sz))
	var best_key: Vector2i = game._nearest_walkable_cell(raw_key, target)
	if game.navigation.is_in_boundsv(best_key) and not game.navigation.is_point_solid(best_key):
		var h := float(game.nav_heights.get(best_key, target.y))
		return Vector3(float(best_key.x) * cell_sz, h, float(best_key.y) * cell_sz)
	return target

func _mat(col: Color, rough: float = 0.50, coat: float = 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if coat > 0.01:
		m.clearcoat_enabled = true
		m.clearcoat = coat
		m.clearcoat_roughness = 0.34
	return m

func _build_lectern_visuals(total_words: int) -> void:
	_lectern_root = Node3D.new()
	_lectern_root.name = "MemoryPalaceShrine"
	_lectern_root.position = shrine_pos
	add_child(_lectern_root)

	var walnut := _mat(Color("8c5d38"), 0.48, 0.26)
	var honey := _mat(Color("be8b57"), 0.46, 0.22)
	var brass := _mat(Color("e5bd62"), 0.30, 0.42)
	var coral := _mat(Color("cb6d5b"), 0.54, 0.18)
	var cream := _mat(Color("fcf7eb"), 0.70, 0.08)

	# Plinth & column
	var plinth := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.34
	pcyl.bottom_radius = 0.40
	pcyl.height = 0.12
	plinth.mesh = pcyl
	plinth.position = Vector3(0.0, 0.06, 0.0)
	plinth.material_override = walnut
	_lectern_root.add_child(plinth)

	var pillar := MeshInstance3D.new()
	var col_cyl := CylinderMesh.new()
	col_cyl.top_radius = 0.12
	col_cyl.bottom_radius = 0.15
	col_cyl.height = 0.68
	pillar.mesh = col_cyl
	pillar.position = Vector3(0.0, 0.44, 0.0)
	pillar.material_override = honey
	_lectern_root.add_child(pillar)

	var collar := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.17
	ring.bottom_radius = 0.17
	ring.height = 0.05
	collar.mesh = ring
	collar.position = Vector3(0.0, 0.74, 0.0)
	collar.material_override = brass
	_lectern_root.add_child(collar)

	# Slanted reading desk + open miniature pop-up book
	var desk_pivot := Node3D.new()
	desk_pivot.position = Vector3(0.0, 0.82, 0.0)
	desk_pivot.rotation_degrees.x = 22.0
	_lectern_root.add_child(desk_pivot)

	var board := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(0.76, 0.05, 0.52)
	board.mesh = bbox
	board.material_override = walnut
	desk_pivot.add_child(board)

	for side: float in [-1.0, 1.0]:
		var cov := MeshInstance3D.new()
		var cbox := BoxMesh.new()
		cbox.size = Vector3(0.32, 0.02, 0.40)
		cov.mesh = cbox
		cov.position = Vector3(side * 0.17, 0.035, 0.0)
		cov.rotation_degrees.z = side * -4.0
		cov.material_override = coral
		desk_pivot.add_child(cov)

		var pg := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.30, 0.025, 0.37)
		pg.mesh = pbox
		pg.position = Vector3(side * 0.16, 0.052, 0.0)
		pg.rotation_degrees.z = side * -5.0
		pg.material_override = cream
		desk_pivot.add_child(pg)

	# Miniature pop-up card standing from the crease
	var mini_card := MeshInstance3D.new()
	var mc_box := BoxMesh.new()
	mc_box.size = Vector3(0.20, 0.22, 0.02)
	mini_card.mesh = mc_box
	mini_card.position = Vector3(0.0, 0.16, -0.02)
	mini_card.material_override = cream
	desk_pivot.add_child(mini_card)

	_floating_star = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.20, 0.20, 0.05)
	_floating_star.mesh = prism
	_floating_star.position = Vector3(0.0, 1.16, 0.0)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("ffe078")
	smat.emission_enabled = true
	smat.emission = Color("ffd257")
	smat.emission_energy_multiplier = 0.55
	smat.roughness = 0.28
	_floating_star.material_override = smat
	_lectern_root.add_child(_floating_star)

	if DisplayServer.get_name() != "headless":
		var glow := OmniLight3D.new()
		glow.light_color = Color("ffe8ab")
		glow.light_energy = 0.55
		glow.omni_range = 2.6
		glow.position = Vector3(0.0, 1.12, 0.15)
		_lectern_root.add_child(glow)

	_badge_label = Label3D.new()
	_badge_label.font = load(FONT_PATH)
	_badge_label.font_size = 24
	_badge_label.pixel_size = 0.0058
	_badge_label.modulate = Color("fffaf0")
	_badge_label.outline_modulate = Color("4b3b28")
	_badge_label.outline_size = 6
	_badge_label.position = Vector3(0.0, 1.52, 0.0)
	_badge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_label.text = "◈ 记忆宫殿展台 · 本屋 %d 词\n走近或按 G 巡游角落奇象" % total_words
	_lectern_root.add_child(_badge_label)

func refresh_badge() -> void:
	if not has_shrine or not is_instance_valid(_badge_label) or not is_instance_valid(game):
		return
	var list := stories_for_room(active_room)
	if list.is_empty():
		return
	var state_node := game.get_node_or_null("/root/State")
	var lit_words := illuminated_word_set(state_node)
	var lit_count := 0
	for item_v: Variant in list:
		if item_v is Dictionary:
			var w := str((item_v as Dictionary).get("word", "")).to_lower()
			if lit_words.has(w):
				lit_count += 1
	if lit_count > 0:
		_badge_label.text = "★ 记忆宫殿展台 · 已点亮 %d / %d 词\n按 G 巡游本屋角落奇象" % [lit_count, list.size()]
		_badge_label.modulate = Color("ffe99c")
	else:
		_badge_label.text = "◈ 记忆宫殿展台 · 本屋 %d 词\n走近或按 G 巡游角落奇象" % list.size()
		_badge_label.modulate = Color("fffaf0")

func _process(delta: float) -> void:
	if not has_shrine or not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	if game.loading_room:
		return
	if is_instance_valid(_floating_star) and not game.ui.reduced_motion:
		_anim_t += delta
		_floating_star.position.y = 1.16 + sin(_anim_t * 2.4) * 0.045
		_floating_star.rotation.y = _anim_t * 1.15

	if game.validation_mode or game.player.locked:
		return
	if is_instance_valid(game.ui.diegetic) and game.ui.diegetic.visible:
		return
	var d2 := Vector2(game.player.position.x - shrine_pos.x, game.player.position.z - shrine_pos.z).length()
	if d2 < 1.38:
		if not _near_notified:
			_near_notified = true
			refresh_badge()
			game.ui.notify("◈ 已走近本屋记忆宫殿展台 · 按 G 键巡游角落奇象与遮罩回想")
	elif d2 > 2.25:
		_near_notified = false

func ranked_room_stories(room_id: String, state_node: Node) -> Array[Dictionary]:
	var raw := stories_for_room(room_id)
	var out: Array[Dictionary] = []
	if raw.is_empty():
		return out
	var sel_book := "xiangshao-g3-1"
	var sel_unit := "unit-1"
	if state_node != null and state_node.get("data") is Dictionary:
		var j: Dictionary = state_node.data.get("journey", {}) if state_node.data.get("journey") is Dictionary else {}
		sel_book = str(j.get("selected_book_id", sel_book))
		var v4: Dictionary = state_node.data.get("v4", {}) if state_node.data.get("v4") is Dictionary else {}
		sel_unit = str(v4.get("active_unit_id", sel_unit))
	var lit_words := illuminated_word_set(state_node)

	var tier_a: Array[Dictionary] = []
	var tier_b: Array[Dictionary] = []
	var tier_c: Array[Dictionary] = []
	var tier_d: Array[Dictionary] = []

	for item_v: Variant in raw:
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v as Dictionary
		var by_book: Dictionary = item.get("entry_by_book", {}) if item.get("entry_by_book") is Dictionary else {}
		var u_by_book: Dictionary = item.get("unit_by_book", {}) if item.get("unit_by_book") is Dictionary else {}
		var in_book := by_book.has(sel_book)
		var in_unit := in_book and (u_by_book.get(sel_book, []) as Array).has(sel_unit)
		var is_lit := lit_words.has(str(item.get("word", "")).to_lower())
		if in_unit:
			tier_a.append(item)
		elif in_book:
			tier_b.append(item)
		elif not is_lit:
			tier_c.append(item)
		else:
			tier_d.append(item)

	out.append_array(tier_a)
	out.append_array(tier_b)
	out.append_array(tier_c)
	out.append_array(tier_d)
	return out

func open_room_palace_tour(page_offset: int = 0) -> bool:
	if not is_instance_valid(game):
		return false
	var state_node := game.get_node_or_null("/root/State")
	var ranked := ranked_room_stories(active_room, state_node)
	if ranked.is_empty():
		game.ui.notify("当前户外广场适合散步，走进任意字母馆、教室或家里的房间即可开启记忆宫殿角落巡游。")
		return false

	var lit_words := illuminated_word_set(state_node)
	var lit_count := 0
	for it: Dictionary in ranked:
		if lit_words.has(str(it.get("word", "")).to_lower()):
			lit_count += 1

	var page_size := 3
	var total := ranked.size()
	var safe_offset := posmod(page_offset, total)
	var slice_items: Array[Dictionary] = []
	for i in range(mini(page_size, total)):
		slice_items.append(ranked[(safe_offset + i) % total])

	var room_zh := str(slice_items[0].get("palace_room_zh", game._room_label()))
	var lines_zh: Array[String] = [
		"这座房间一共安放了 %d 个记忆宫殿角落奇象（已点亮 %d 个）：" % [total, lit_count]
	]
	var actions: Array = []
	for idx in range(slice_items.size()):
		var it: Dictionary = slice_items[idx]
		var eid := best_entry_id_for_state(it, state_node)
		var word := str(it.get("word", ""))
		var m_zh := str(it.get("meaning_zh", ""))
		var locus := str(it.get("palace_locus_zh", "房间角落"))
		var title := str(it.get("title_zh", ""))
		var mark := "★" if lit_words.has(word.to_lower()) else "◈"
		lines_zh.append("%s 【%s】%s（%s）—《%s》" % [mark, locus, word, m_zh, title])
		actions.append({
			"label": "%s %s · %s（%s）" % [mark, word, m_zh, locus],
			"id": "open_palace:" + eid,
			"primary": idx == 0
		})

	var lead_it: Dictionary = slice_items[0]
	var lead_eid := best_entry_id_for_state(lead_it, state_node)
	actions.append({
		"label": "★ 角落遮罩回想 · %s（%s）" % [str(lead_it.get("word", "")), str(lead_it.get("palace_locus_zh", ""))],
		"id": "open_palace_gap:" + lead_eid
	})
	if total > page_size:
		var page_idx := int(floor(float(safe_offset) / float(page_size))) + 1
		var page_total := maxi(1, ceili(float(total) / float(page_size)))
		actions.append({
			"label": "换一批本屋角落词（%d/%d）" % [page_idx, page_total],
			"id": "v5_palace_tour:" + str((safe_offset + page_size) % total)
		})
	actions.append({"label": "继续在屋内散步", "id": "close"})

	var anchor_pos: Vector3 = shrine_pos if has_shrine else (game.player.position as Vector3)
	game.conversation_position = anchor_pos
	game.player.face(anchor_pos)
	if is_instance_valid(game.audio_director):
		game.audio_director.play_foley("bubble_pop")

	var en_line := "Welcome to the Memory Palace of %s! Try recalling \"%s\" at the corner!" % [room_zh, str(lead_it.get("word", ""))]
	var zh_body := "\n".join(lines_zh)

	if is_instance_valid(game.ui.diegetic) and not game.validation_mode:
		if game.ui.modal.visible:
			game._close()
		game.ui.current_panel = "v5_palace_tour"
		game.ui.diegetic.open_conversation({
			"npc_id": "npc_owl_tutor",
			"speaker": "%s · 记忆宫殿角落展台" % room_zh,
			"en": en_line,
			"zh": zh_body,
			"world_pos": anchor_pos,
			"show_zh_immediately": true,
			"auto_speak": true,
			"actions": actions
		})
	else:
		game.ui.show_panel(
			"v5_palace_tour",
			"%s · 记忆宫殿角落展台" % room_zh,
			"本屋共 %d 词 · 已点亮 %d 词" % [total, lit_count],
			en_line + "\n\n" + zh_body,
			actions
		)
	return true
