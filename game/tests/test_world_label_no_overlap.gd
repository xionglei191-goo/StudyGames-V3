extends SceneTree
## V9 Global 3D/2D World Label De-Overlap & Overlay Suppression Verification Suite.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_world_label_no_overlap.gd -- --test-harness

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

var passed := 0
var failed := 0
var _prod_save_before := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("NO_OVERLAP FAIL: " + label)


func _frames(count: int = 6) -> void:
	for _i: int in range(count):
		await process_frame


func _sha(path: String) -> String:
	return FileAccess.get_sha256(path).to_lower() if FileAccess.file_exists(path) else ""


func _assert_zero_overlaps(game: Node3D, context_label: String) -> void:
	var wll: Node = game.get("world_label_layout")
	_check(wll != null, context_label + "_has_world_label_layout")
	if wll == null:
		return

	var label3d_items: Array[Dictionary] = wll.compute_visible_label_screen_rects()
	var prompt2d_items: Array[Dictionary] = wll.compute_visible_2d_prompt_rects()

	var all_items: Array[Dictionary] = []
	for d: Dictionary in label3d_items:
		var r: Rect2 = d["rect"]
		if r.position.x < -1.0 or r.end.x > 1441.0 or r.position.y < -1.0 or r.end.y > 901.0:
			_check(false, "%s_oob_%s(%.1f..%.1f,%.1f..%.1f)" % [context_label, str(d["text"]).replace("\n", "/"), r.position.x, r.end.x, r.position.y, r.end.y])
		all_items.append({
			"tag": "3D:" + str(d["name"]) + "[" + str(d["text"]).replace("\n", "/") + "]",
			"rect": r,
		})

	for p: Dictionary in prompt2d_items:
		all_items.append({
			"tag": "2D:" + str(p["kind"]),
			"rect": p["rect"] as Rect2,
		})

	var collisions: Array[String] = []
	for i: int in range(all_items.size()):
		var ri: Rect2 = all_items[i]["rect"]
		for j: int in range(i + 1, all_items.size()):
			var rj: Rect2 = all_items[j]["rect"]
			if ri.intersects(rj):
				collisions.append("%s <-> %s" % [str(all_items[i]["tag"]), str(all_items[j]["tag"])])

	# Also verify zero 3D labels collide with top-left / top-right HUD pills when HUD is visible
	if is_instance_valid(game.ui) and is_instance_valid(game.ui.hud) and game.ui.hud.visible:
		var hud_tl := Rect2(12.0, 12.0, 332.0, 200.0)
		var hud_tr := Rect2(1440.0 - 364.0, 12.0, 352.0, 72.0)
		for d: Dictionary in label3d_items:
			var lr: Rect2 = d["rect"]
			if lr.intersects(hud_tl):
				collisions.append("HUD_TL <-> 3D:" + str(d["text"]).replace("\n", "/"))
			if lr.intersects(hud_tr):
				collisions.append("HUD_TR <-> 3D:" + str(d["text"]).replace("\n", "/"))

	if not collisions.is_empty():
		push_error("OVERLAP DETECTED [" + context_label + "]: " + " | ".join(collisions))
	_check(collisions.is_empty(), "zero_pairwise_rect_overlaps_" + context_label)


func _run() -> void:
	await process_frame
	var watchdog := Timer.new()
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func():
		_check(false, "bounded_timeout")
		quit(1)
	)
	watchdog.start(180.0)

	_prod_save_before = _sha("user://island-save-v1.json")
	root.size = Vector2i(1440, 900)

	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for _f: int in range(1200):
		await process_frame
		if game.scene_ready:
			break
	_check(game.scene_ready, "scene_ready")

	var state: Node = root.get_node("State")
	state.data = state._default_state()
	state.set_preference("fixed_day", true)
	game.muted = true
	game.validation_mode = false
	game.ai_bridge.muted = true

	# Seed 5 words + 2 room hops so Mom's V8ErrandNPCBadge activates in `home`!
	state.v8_record_room_visit("home_bathroom")
	state.v8_record_word_exposure("soap", "香皂", "home_bathroom", 2, 1000)
	state.v8_record_word_exposure("towel", "擦手巾", "home_bathroom", 2, 1005)
	state.v8_record_word_exposure("coat", "外套", "home_bedroom", 3, 1010)
	state.v8_record_word_exposure("pen", "钢笔", "home_study", 1, 1015)
	state.v8_record_word_exposure("globe", "地球仪", "home_study", 2, 1020)
	await game.change_room("home_bedroom")
	await _frames(4)

	# 1. `home` with Mom's unified V8ErrandNPCBadge + Kitty + 5 furniture WordTags + MemoryPalaceLoci3D
	await game.change_room("home")
	await _frames(8)
	game.errand_director.refresh_visuals()
	await _frames(8)

	var npc_badge: Label3D = game.errand_director._npc_badge
	var mom_actor: Node3D = game.living.get_actor("textbook_role_lingling_mother")
	var kitty_actor: Node3D = game.living.get_actor("textbook_kitty")
	_check(is_instance_valid(npc_badge) and npc_badge.visible, "home_mom_errand_badge_visible")
	if is_instance_valid(npc_badge):
		_check(npc_badge.text.contains("温故寻物委托") and npc_badge.text.contains("妈妈"), "home_mom_errand_badge_unifies_actor_name")
	if is_instance_valid(mom_actor) and mom_actor.get("name_label") != null:
		var mom_lbl := mom_actor.get("name_label") as Label3D
		_check(mom_lbl.get_parent() == mom_actor and not mom_lbl.visible, "mom_separate_name_label_hidden_while_errand_badge_active")
	if is_instance_valid(kitty_actor) and kitty_actor.get("name_label") != null:
		_check((kitty_actor.get("name_label") as Label3D).visible, "kitty_name_label_remains_visible")
	_check(game.spatial_bench.macro_plaques.size() == 5, "home_keeps_5_macro_plaques_invariant")
	if is_instance_valid(game.palace_loci) and is_instance_valid(game.palace_loci.get("_badge_label")):
		var pl_lbl := game.palace_loci.get("_badge_label") as Label3D
		_check(not pl_lbl.text.contains("\n"), "memory_palace_badge_is_compact_single_line")

	var home_rects: Array[Dictionary] = game.world_label_layout.compute_visible_label_screen_rects()
	_check(home_rects.size() >= 6, "home_displays_multiple_deoverlapped_2d_pills")
	var overlay_ctrl := game.ui.root.get_child(0) as Control
	_check(overlay_ctrl != null and overlay_ctrl.name == "WorldLabel2DOverlay", "world_label_2d_overlay_inserted_at_root_index_0")
	var seen_kinds := {}
	var all_pills_valid := true
	for item_d: Dictionary in home_rects:
		seen_kinds[str(item_d.get("kind", ""))] = true
		var pill_node := item_d.get("pill") as PanelContainer
		var lbl3d_node := item_d.get("node") as Label3D
		if pill_node == null or not pill_node.is_visible_in_tree() or lbl3d_node == null or not lbl3d_node.visible or lbl3d_node.transparency < 0.99:
			all_pills_valid = false
	_check(all_pills_valid, "home_2d_pills_visible_and_3d_blurry_meshes_suppressed")
	_check(seen_kinds.has("errand") and seen_kinds.has("npc") and seen_kinds.has("plaque") and seen_kinds.has("shrine"), "home_renders_all_4_storybook_pill_styles")
	_assert_zero_overlaps(game, "home_with_mom_errand_badge")

	# 2. Opening `DiegeticDialogue` hides ALL background 3D labels; closing restores them cleanly!
	game.interact_id("actor:textbook_role_lingling_mother")
	await _frames(5)
	_check(game.ui.diegetic.visible, "mom_diegetic_dialogue_open")
	_check(game.world_label_layout.compute_visible_label_screen_rects().is_empty(), "diegetic_dialogue_suppresses_all_bg_3d_labels")

	game._close()
	await _frames(6)
	_check(not game.ui.diegetic.visible, "mom_diegetic_dialogue_closed")
	_check(game.world_label_layout.compute_visible_label_screen_rects().size() >= 6, "closing_dialogue_restores_room_3d_labels")
	if is_instance_valid(mom_actor) and mom_actor.get("name_label") != null:
		_check(not (mom_actor.get("name_label") as Label3D).visible and npc_badge.visible, "closing_dialogue_keeps_mom_name_claimed_by_errand_badge")
	_assert_zero_overlaps(game, "home_after_dialogue_close")

	# 3. Simultaneous `[E]` prompt + proximity speech bubble + hover prompt when standing next to Kitty!
	if is_instance_valid(kitty_actor):
		game.player.path.clear()
		game.player.position = Vector3(kitty_actor.position.x - 0.9, game.player.position.y, kitty_actor.position.z + 0.7)
	await _frames(4)
	var screen_anchor := Vector2(720.0, 520.0)
	if is_instance_valid(kitty_actor):
		game.bubble_world_position = kitty_actor.global_position + Vector3(0.0, 1.8, 0.0)
		screen_anchor = game.camera.unproject_position(game.bubble_world_position)
	game.ui.show_prompt("和小猫 Kitty 打招呼", screen_anchor, 2, 0)
	game.ui.say("Meow! Kitty is resting on the soft warm sofa!", "喵～小猫正窝在柔软温暖的沙发上休息呢！", screen_anchor)
	game.ui.show_hover_prompt("小猫 · Kitty", screen_anchor)
	game.world_label_layout.solve_now(0.016, true)
	_check(game.ui.prompt.visible and game.ui.bubble_panel.visible, "simultaneous_prompt_and_bubble_stay_visible")
	_check(not game.ui.hover_prompt.visible, "colliding_hover_prompt_auto_suppressed")
	_assert_zero_overlaps(game, "home_simultaneous_prompt_and_bubble_immediate")
	await _frames(4)
	_assert_zero_overlaps(game, "home_simultaneous_prompt_and_bubble_after_frames")
	game.ui.hide_interaction_prompts()
	game.ui.bubble_panel.hide()
	await _frames(3)

	# 4. `classroom` (Miss Li, Mingming, Tim, Amy + spawned Dino + 5 furniture WordTags + shrine)
	await game.change_room("classroom")
	await _frames(6)
	var dino_pos: Vector3 = (game.player.position as Vector3) + Vector3(1.4, 0.0, -0.5)
	game.living.spawn_actor("textbook_dino", dino_pos, {
		"display_name": "小恐龙 · Dino",
		"validate_position": false,
	})
	game.living.refresh_interactions(game.interactions)
	await _frames(8)
	var cls_rects: Array[Dictionary] = game.world_label_layout.compute_visible_label_screen_rects()
	_check(cls_rects.size() >= 8, "classroom_crowded_labels_visible")
	_assert_zero_overlaps(game, "classroom_crowded_cast_and_plaques")

	# 5. `home_estate` (Doggie + 5 outdoor plaques + shrine)
	await game.change_room("home_estate")
	await _frames(8)
	_check(game.living.get_actor("textbook_doggie") != null, "home_estate_spawns_doggie")
	_check(game.world_label_layout.compute_visible_label_screen_rects().size() >= 5, "home_estate_labels_visible")
	_assert_zero_overlaps(game, "home_estate_garden")

	# 6. `village` (island hub NPCs & landmarks)
	await game.change_room("village")
	await _frames(8)
	_assert_zero_overlaps(game, "village_hub")

	# 7. Immutable SHA-256 checks
	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_untouched")
	_check(_sha("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA, "prologue_json_untouched")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "user_save_untouched")

	game.queue_free()
	await process_frame
	print("V9 World Label Zero-Overlap Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
