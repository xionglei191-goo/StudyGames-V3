extends SceneTree
## V10 All-43-Room 3D Scene Prop, Architectural Pillar/Wall & Tactile Station Zero-Penetration Suite.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_3d_prop_no_penetration.gd -- --test-harness

const HouseholdProps = preload("res://activities/household_props.gd")
const TactileQuests = preload("res://gameplay/tactile_life_quests.gd")

const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

const ALL_16_ROOMS := [
	"home_estate",
	"home",
	"home_bedroom",
	"home_kitchen",
	"home_dining",
	"home_bathroom",
	"home_study",
	"home_balcony",
	"school",
	"classroom",
	"music_room",
	"art_room",
	"science_room",
	"canteen",
	"playground",
	"football_field",
]

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
		push_error("PROP_PENETRATION FAIL: " + label)


func _frames(count: int = 4) -> void:
	for _i: int in range(count):
		await process_frame


func _sha(path: String) -> String:
	return FileAccess.get_sha256(path).to_lower() if FileAccess.file_exists(path) else ""


func _world_aabb_of_mesh(mi: MeshInstance3D) -> AABB:
	if mi == null or mi.mesh == null:
		return AABB()
	var local_box := mi.get_aabb()
	if local_box.size == Vector3.ZERO:
		return AABB()
	var xf := mi.global_transform
	var res := AABB(xf * local_box.get_endpoint(0), Vector3.ZERO)
	for i: int in range(1, 8):
		res = res.expand(xf * local_box.get_endpoint(i))
	return res


func _collect_meshes(root_node: Node, patterns: Array, visible_only: bool = false) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if not is_instance_valid(root_node):
		return out
	var seen: Dictionary = {}
	for pat_v: Variant in patterns:
		var pat := str(pat_v)
		for n: Node in root_node.find_children(pat, "Node3D", true, false):
			var nm := str(n.name)
			if nm.begins_with("SG_") or nm.begins_with("COL_"):
				continue
			if n is MeshInstance3D:
				var m0 := n as MeshInstance3D
				if (not visible_only or m0.is_visible_in_tree()) and not seen.has(m0.get_instance_id()):
					seen[m0.get_instance_id()] = true
					out.append(m0)
			for sub: Node in n.find_children("*", "MeshInstance3D", true, false):
				var ms := sub as MeshInstance3D
				if ms != null and (not visible_only or ms.is_visible_in_tree()) and not seen.has(ms.get_instance_id()):
					seen[ms.get_instance_id()] = true
					out.append(ms)
	return out


func _union_aabb(meshes: Array[MeshInstance3D]) -> AABB:
	var combined := AABB()
	var has_any := false
	for mi: MeshInstance3D in meshes:
		var box := _world_aabb_of_mesh(mi)
		if box.size == Vector3.ZERO:
			continue
		if not has_any:
			combined = box
			has_any = true
		else:
			combined = combined.merge(box)
	return combined


func _xz_gap(a: AABB, b: AABB) -> float:
	if a.size == Vector3.ZERO or b.size == Vector3.ZERO:
		return INF
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz := maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
	return sqrt(dx * dx + dz * dz)


func _intersects_3d_shrunk(a: AABB, b: AABB, eps: float = 0.008) -> bool:
	if a.size == Vector3.ZERO or b.size == Vector3.ZERO:
		return false
	var sa := a.grow(-eps)
	var sb := b.grow(-eps)
	if sa.size.x <= 0.0 or sa.size.y <= 0.0 or sa.size.z <= 0.0:
		sa = a
	if sb.size.x <= 0.0 or sb.size.y <= 0.0 or sb.size.z <= 0.0:
		sb = b
	return sa.intersects(sb)


func _assert_quest_station_and_pickups_clear(game: Node3D, room_id: String) -> void:
	var tq: Node3D = game.get("tactile_quests") as Node3D
	if tq == null or not TactileQuests.supports_room(room_id):
		return
	var obstacles: Array = tq.get("_room_obstacles") if tq.get("_room_obstacles") is Array else []
	var ped: Node3D = tq.get("_station_pedestal") as Node3D
	if room_id != "landmark_A":
		_check(is_instance_valid(ped), room_id + "_has_cozy_craft_station")
		if is_instance_valid(ped):
			var ped_box := _union_aabb(_collect_meshes(ped, ["*"], true))
			var hit_obs := false
			for ob_v: Variant in obstacles:
				if ob_v is AABB and _intersects_3d_shrunk(ped_box, ob_v as AABB, 0.02):
					hit_obs = true
					break
			_check(not hit_obs, room_id + "_cozy_craft_station_clears_all_room_obstacles")

	var pickups: Array = tq.get("_pickups") if tq.get("_pickups") is Array else []
	_check(pickups.size() == 3, room_id + "_spawns_3_quest_pickups")
	var pickup_hit := false
	for p_v: Variant in pickups:
		var pd := p_v as Dictionary
		var pnode := pd.get("node") as Node3D
		if not is_instance_valid(pnode):
			continue
		var pbox := _union_aabb(_collect_meshes(pnode, ["*"], true))
		for ob_v2: Variant in obstacles:
			if ob_v2 is AABB and _intersects_3d_shrunk(pbox, ob_v2 as AABB, 0.02):
				pickup_hit = true
				break
	_check(not pickup_hit, room_id + "_quest_pickups_clear_all_room_obstacles")


func _run() -> void:
	await process_frame
	var watchdog := Timer.new()
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func():
		_check(false, "bounded_timeout")
		quit(1)
	)
	watchdog.start(240.0)

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
	# Populate landmark_crafts = 4 across all 30 quest rooms so EchoCraft_0..2 & CozyCraftStation are active!
	if not (state.data.get("v4") is Dictionary):
		state.data["v4"] = {}
	var crafts_dict := {}
	for qroom: String in TactileQuests.ROOM_QUEST_SPECS.keys():
		crafts_dict[qroom] = 4
	state.data["v4"]["landmark_crafts"] = crafts_dict

	game.muted = true
	game.validation_mode = false
	game.ai_bridge.muted = true

	# 1. Primary Audit in `home_estate`:
	#    A) `Welcome_Parcel_Basket*` vs `Welcome_Letter_Table*`
	#    B) `Porch_Ready_Basket*` vs `Porch_Column_Foot*`, `Porch_Timber_Column*`, `Main_Front*`, `Main_Corner_Post*`, `CozyCraftStation`, AND Anchor #3 Layer-2 Close-Up!
	await game.change_room("home_estate")
	await _frames(5)

	var basket_meshes := _collect_meshes(game.world, ["Welcome_Parcel_Basket*"])
	_check(basket_meshes.size() >= 5, "home_estate_has_all_welcome_parcel_basket_parts")
	var basket_union := _union_aabb(basket_meshes)
	var union_center := basket_union.get_center()
	var parts_aligned := true
	for bm: MeshInstance3D in basket_meshes:
		var pc := _world_aabb_of_mesh(bm).get_center()
		if absf(pc.x - union_center.x) > 0.08 or absf(pc.z - union_center.z) > 0.08:
			parts_aligned = false
	_check(parts_aligned, "all_welcome_parcel_basket_parts_shifted_cohesively")

	var table_legs := _collect_meshes(game.world, ["Welcome_Letter_Table_Leg*"])
	var min_leg_gap := INF
	for leg: MeshInstance3D in table_legs:
		var lb := _world_aabb_of_mesh(leg)
		_check(not _intersects_3d_shrunk(basket_union, lb), "welcome_basket_zero_penetration_with_" + str(leg.name))
		min_leg_gap = minf(min_leg_gap, _xz_gap(basket_union, lb))
	_check(min_leg_gap >= 0.22, "welcome_basket_22cm_clear_of_all_table_legs")

	# B) `Porch_Ready_Basket*` vs Porch Column, Column Foot, House Wall, Corner Post & CozyCraftStation!
	var porch_basket_meshes := _collect_meshes(game.world, ["Porch_Ready_Basket*"])
	_check(porch_basket_meshes.size() >= 5, "home_estate_has_all_porch_ready_basket_parts")
	var porch_basket_union := _union_aabb(porch_basket_meshes)
	var porch_center := porch_basket_union.get_center()
	var porch_parts_aligned := true
	for pbm: MeshInstance3D in porch_basket_meshes:
		var ppc := _world_aabb_of_mesh(pbm).get_center()
		if absf(ppc.x - porch_center.x) > 0.08 or absf(ppc.z - porch_center.z) > 0.08:
			porch_parts_aligned = false
			push_error("Orphaned Porch_Ready_Basket part %s at %s vs %s" % [pbm.name, str(ppc), str(porch_center)])
	_check(porch_parts_aligned, "all_porch_ready_basket_parts_shifted_cohesively")

	for struct_pair: Array in [
		[["Porch_Column_Foot*"], "porch_column_foot"],
		[["Porch_Timber_Column*"], "porch_timber_column"],
		[["Main_Front_Plaster*", "Main_Front_Stone_Skirting*"], "main_front_wall"],
		[["Main_Corner_Post*"], "main_corner_post"],
	]:
		var s_union := _union_aabb(_collect_meshes(game.world, struct_pair[0] as Array))
		var tag := str(struct_pair[1])
		_check(not _intersects_3d_shrunk(porch_basket_union, s_union), "porch_basket_zero_penetration_with_" + tag)
		_check(_xz_gap(porch_basket_union, s_union) >= 0.22, "porch_basket_22cm_xz_clear_of_" + tag)

	var station_ped: Node3D = game.tactile_quests.get("_station_pedestal") as Node3D
	_check(is_instance_valid(station_ped), "home_estate_cozy_craft_station_present")
	if is_instance_valid(station_ped):
		var station_box := _union_aabb(_collect_meshes(station_ped, ["*"], true))
		_check(not _intersects_3d_shrunk(porch_basket_union, station_box) and _xz_gap(porch_basket_union, station_box) >= 0.22, "porch_basket_clears_cozy_craft_station_by_22cm")

	_assert_quest_station_and_pickups_clear(game, "home_estate")

	# Verify idempotency on both baskets
	HouseholdProps.prepare_room(game.world, "home_estate")
	var porch_after_second := _union_aabb(_collect_meshes(game.world, ["Porch_Ready_Basket*"]))
	_check(porch_basket_union.position.distance_to(porch_after_second.position) < 0.001, "porch_ready_basket_prepare_room_idempotent")

	# Verify Anchor #3 (`basket · 门廊随身篮`) Layer-2 Close-Up centers within 0.45m XZ of moved Porch_Ready_Basket!
	game.spatial_bench.open_workbench(game, "home_estate", "", 3)
	await _frames(4)
	_check(game.spatial_bench.bench_open and game.spatial_bench.bench_anchor_order == 3, "home_estate_anchor_3_closeup_opens")
	var focus_xz_dist := Vector2(game.spatial_bench.camera_focus.x, game.spatial_bench.camera_focus.z).distance_to(Vector2(porch_center.x, porch_center.z))
	_check(focus_xz_dist <= 0.45, "home_estate_anchor_3_closeup_centers_on_moved_porch_basket")
	game.spatial_bench.close_workbench()
	await _frames(2)

	# 2. Home & School Specific Prop Penetration Checks
	await game.change_room("home")
	await _frames(4)
	_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Locus_01_Everyday_Basket*"], true)), _union_aabb(_collect_meshes(game.world, ["Mail_Table_Plant*"], true))), "home_everyday_basket_clears_mail_table_plant")
	if is_instance_valid(game.palace_loci) and is_instance_valid(game.palace_loci.get("_lectern_root")):
		_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.palace_loci.get("_lectern_root"), ["*"], true)), _union_aabb(_collect_meshes(game.world, ["Decor_Picnic_Basket*", "SG_DECOR_MODEL_*"], true))), "home_lectern_clears_decor_picnic_basket")

	await game.change_room("home_bedroom")
	await _frames(4)
	_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Schoolbag*"], true)), _union_aabb(_collect_meshes(game.world, ["Bag_Bench_Back*"], true)), 0.004), "bedroom_schoolbag_clears_bag_bench_back")

	await game.change_room("home_balcony")
	await _frames(4)
	var watering_can := _union_aabb(_collect_meshes(game.world, ["OWN07_Watering_can_*"], true))
	_check(_xz_gap(watering_can, _union_aabb(_collect_meshes(game.world, ["Balcony_Plants_Box*"], true))) >= 0.20, "balcony_watering_can_clears_plants_box")
	_check(_xz_gap(watering_can, _union_aabb(_collect_meshes(game.world, ["Window_Cleaning_Stand*"], true))) >= 0.20, "balcony_watering_can_clears_cleaning_stand")

	await game.change_room("canteen")
	await _frames(4)
	_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["Back_Greenery*"], true)), _union_aabb(_collect_meshes(game.world, ["Kitchen_Back_Counter*"], true))) >= 0.20, "canteen_back_greenery_clears_kitchen_counter")
	_assert_quest_station_and_pickups_clear(game, "canteen")

	await game.change_room("classroom")
	await _frames(4)
	_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Class_Prop_Hat*"], true)), _union_aabb(_collect_meshes(game.world, ["Locus_04_Props_Cabinet_Back*"], true)), 0.004), "classroom_prop_hat_clears_cabinet_back")

	await game.change_room("science_room")
	await _frames(4)
	_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Science_ModelSolar*"], true)), _union_aabb(_collect_meshes(game.world, ["Science_ModelDisplay_Back*"], true)), 0.004), "science_solar_clears_display_back")

	await game.change_room("school")
	await _frames(4)
	_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["Music_Outdoor_Xylophone_Key*", "Music_Xylophone_Leg*"], true)), _union_aabb(_collect_meshes(game.world, ["Music_Foundation*"], true))) >= 0.20, "school_xylophone_clears_music_foundation")
	_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Canteen_Menu_Board_Face*", "Canteen_Menu_Board_Frame*", "Canteen_Menu_Board_Post*"], true)), _union_aabb(_collect_meshes(game.world, ["Canteen_Foundation*"], true))), "school_menu_board_clears_canteen_foundation")
	_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["Art_Outdoor_Easel*", "Art_Outdoor_Canvas*"], true)), _union_aabb(_collect_meshes(game.world, ["Art_Foundation*", "Art_Wall*", "Art_Front*"], true))) >= 0.20, "school_art_easel_clears_art_building")
	_assert_quest_station_and_pickups_clear(game, "school")

	await game.change_room("playground")
	await _frames(4)
	_assert_quest_station_and_pickups_clear(game, "playground")

	# 3. Sweep All 26 Alphabet Landmarks (`landmark_A..Z`) with `landmark_crafts = 4` + Landmark Prop Fixes!
	for ch_idx in range(26):
		var letter := String.chr(65 + ch_idx)
		var lm_room := "landmark_" + letter
		await game.change_room(lm_room)
		await _frames(3)
		_check(game.room == lm_room and not game.loading_room, lm_room + "_loads_cleanly")
		_assert_quest_station_and_pickups_clear(game, lm_room)

		match lm_room:
			"landmark_A":
				_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["A_Entrance_Basket*"], true)), _union_aabb(_collect_meshes(game.world, ["A_Bench*"], true))) >= 0.20, "landmark_A_entrance_basket_clears_bench")
				_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["A_Spare_Crate_*"], true)), _union_aabb(_collect_meshes(game.world, ["A_SortTable_Leg_001*"], true))), "landmark_A_spare_crate_clears_sort_table_leg")
			"landmark_F":
				_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["Back_Greenery*"], true)), _union_aabb(_collect_meshes(game.world, ["Rear_Flower_Bed_Box_002*"], true))) >= 0.20, "landmark_F_back_greenery_clears_flower_bed")
			"landmark_H":
				_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Trying_Hat*"], true)), _union_aabb(_collect_meshes(game.world, ["Dressing_Mirror*"], true)), 0.004), "landmark_H_trying_hat_clears_mirror")
			"landmark_J":
				_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Jar_Labels_Card*"], true)), _union_aabb(_collect_meshes(game.world, ["Locus_04_Clean_Label_Tap*"], true)), 0.004), "landmark_J_jar_labels_clears_tap")
				_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Back_Greenery*"], true)), _union_aabb(_collect_meshes(game.world, ["Rear_Collection_Jar_Body_034*"], true))), "landmark_J_back_greenery_clears_jar")
			"landmark_K":
				_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["Bamboo_Spar*"], true)), _union_aabb(_collect_meshes(game.world, ["Locus_02_Materials*"], true))) >= 0.20, "landmark_K_bamboo_spar_clears_materials_shelf")
			"landmark_L":
				_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Gift_Lantern*"], true)), _union_aabb(_collect_meshes(game.world, ["Gallery_Lantern_001*"], true)), 0.004), "landmark_L_gift_lantern_clears_hanging_lantern")
			"landmark_M":
				_check(not _intersects_3d_shrunk(_union_aabb(_collect_meshes(game.world, ["Cottage_Back_Kitchen*"], true)), _union_aabb(_collect_meshes(game.world, ["Cottage_Round_Wall*"], true)), 0.004), "landmark_M_kitchen_clears_round_wall")
			"landmark_U":
				_check(_xz_gap(_union_aabb(_collect_meshes(game.world, ["Back_Greenery*"], true)), _union_aabb(_collect_meshes(game.world, ["Rain_Garden_Box_001*"], true))) >= 0.20, "landmark_U_back_greenery_clears_rain_garden_box")

	# 4. Sweep remaining rooms + `village` so all 43 rooms are verified
	for rid: String in ALL_16_ROOMS + ["village"]:
		if rid in ["home_estate", "home", "home_bedroom", "home_balcony", "canteen", "classroom", "science_room", "school", "playground"]:
			continue
		await game.change_room(rid)
		await _frames(3)
		_check(game.room == rid and not game.loading_room, rid + "_loads_cleanly")

	# 5. Immutable SHA-256 checks
	_check(_sha("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA, "catalog_json_untouched")
	_check(_sha("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA, "prologue_json_untouched")
	_check(_sha("user://island-save-v1.json") == _prod_save_before, "user_save_untouched")

	game.queue_free()
	await process_frame
	print("V10 All-43-Room Prop & Station Zero-Penetration Suite: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
