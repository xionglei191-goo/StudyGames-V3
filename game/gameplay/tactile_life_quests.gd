extends Node3D
## V4 All-Island Tactile 3D Cozy Life Quests & Persistent World Echoes!
## Covers ALL 26 Alphabet Landmarks (`landmark_A`..`landmark_Z`) + `home_estate` +
## `school` + `canteen` + `playground` (30 interactive rooms).
## Players walk up in 3D, hold Toy-PBR miniatures in their two-hand `CarrySocket`,
## deliver them to the room's glowing craft/basket station, and leave a permanent
## 3D keepsake display in the world while stealthily logging vocabulary mastery!

signal apple_picked(kind: String, word_en: String)
signal basket_delivered(total_delivered: int, word_en: String)
signal item_picked(kind: String, word_en: String, room_id: String)
signal station_delivered(room_id: String, craft_total: int, word_en: String)

const WorldArt = preload("res://scripts/world_art.gd")
const Wardrobe = preload("res://actors/modular_wardrobe.gd")
const Style = preload("res://ui/island_theme.gd")

const ROOM_QUEST_SPECS := {
	"landmark_A": {"station": "果园藤篮", "prop": "apple", "alt_prop": "golden_apple", "items": [["apple", "red apple", "🍎 Red Apple"], ["apple", "sweet apple", "🍎 Sweet Apple"], ["golden_apple", "yellow apple", "🌟 Golden Apple"]]},
	"landmark_B": {"station": "船坞起航台", "prop": "boat", "items": [["boat", "boat", "⛵ Little Boat"], ["boat", "blue boat", "⛵ Blue Boat"], ["boat", "sail boat", "⛵ Sail Boat"]]},
	"landmark_C": {"station": "烘焙甜点台", "prop": "cake", "items": [["cake", "cake", "🎂 Sweet Cake"], ["cake", "apple cake", "🎂 Apple Cake"], ["bread", "warm bread", "🥐 Warm Bread"]]},
	"landmark_D": {"station": "鼓点合奏台", "prop": "drum", "items": [["drum", "drum", "🥁 Red Drum"], ["drum", "big drum", "🥁 Big Drum"], ["drum", "music drum", "🥁 Music Drum"]]},
	"landmark_E": {"station": "暖绒孵蛋窝", "prop": "egg", "items": [["egg", "egg", "🥚 Warm Egg"], ["egg", "white egg", "🥚 White Egg"], ["egg", "little egg", "🥚 Little Egg"]]},
	"landmark_F": {"station": "阳光花艺台", "prop": "flower", "items": [["flower", "flower", "🌸 Pink Flower"], ["flower", "red flower", "🌺 Red Flower"], ["flower", "sweet flower", "🌷 Sweet Flower"]]},
	"landmark_G": {"station": "环球航线桌", "prop": "globe", "items": [["globe", "globe", "🌍 Blue Globe"], ["globe", "world globe", "🌎 World Globe"], ["book", "map book", "🗺️ Map Book"]]},
	"landmark_H": {"station": "制帽展示架", "prop": "hat", "items": [["hat", "hat", "👒 Straw Hat"], ["hat", "sunny hat", "👒 Sunny Hat"], ["hat", "nice hat", "🎩 Nice Hat"]]},
	"landmark_I": {"station": "冰爽甜筒车", "prop": "ice_cream", "items": [["ice_cream", "ice cream", "🍦 Ice Cream"], ["ice_cream", "pink ice cream", "🍧 Pink Cone"], ["ice_cream", "sweet cone", "🍨 Sweet Cone"]]},
	"landmark_J": {"station": "果酱陈列架", "prop": "jar", "items": [["jar", "jar", "🫙 Glass Jar"], ["jar", "apple jar", "🍯 Jam Jar"], ["jar", "star jar", "✨ Star Jar"]]},
	"landmark_K": {"station": "微风放飞台", "prop": "kite", "items": [["kite", "kite", "🪁 Sky Kite"], ["kite", "blue kite", "🪁 Blue Kite"], ["kite", "wind kite", "🎐 Wind Kite"]]},
	"landmark_L": {"station": "暖光灯笼架", "prop": "lantern", "items": [["lantern", "lantern", "🏮 Warm Lantern"], ["lantern", "gold lantern", "🏮 Gold Lantern"], ["lantern", "night lantern", "✨ Bright Lantern"]]},
	"landmark_M": {"station": "蘑菇采摘篮", "prop": "mushroom", "items": [["mushroom", "mushroom", "🍄 Red Mushroom"], ["mushroom", "cute mushroom", "🍄 Forest Mushroom"], ["mushroom", "soft mushroom", "🌿 Cozy Mushroom"]]},
	"landmark_N": {"station": "树冠护巢台", "prop": "nest", "items": [["nest", "nest", "🪹 Cozy Nest"], ["nest", "bird nest", "🐦 Bird Nest"], ["egg", "nest egg", "🥚 Nest Egg"]]},
	"landmark_O": {"station": "猫头鹰阅览桌", "prop": "owl_book", "items": [["owl_book", "owl book", "🦉 Owl Book"], ["book", "story book", "📖 Story Book"], ["owl_book", "wise owl", "📚 Night Book"]]},
	"landmark_P": {"station": "金秋南瓜车", "prop": "pumpkin", "items": [["pumpkin", "pumpkin", "🎃 Big Pumpkin"], ["pumpkin", "orange pumpkin", "🎃 Sweet Pumpkin"], ["pumpkin", "round pumpkin", "🍂 Autumn Pumpkin"]]},
	"landmark_Q": {"station": "拼布织布台", "prop": "quilt", "items": [["quilt", "quilt", "🧵 Soft Quilt"], ["quilt", "warm quilt", "🪡 Patch Quilt"], ["yarn", "cozy quilt", "🧶 Cozy Patch"]]},
	"landmark_R": {"station": "发条拼装台", "prop": "robot", "items": [["robot", "robot", "🤖 Toy Robot"], ["robot", "blue robot", "⚙️ Smart Robot"], ["robot", "little robot", "🔧 Helper Robot"]]},
	"landmark_S": {"station": "观星许愿台", "prop": "star", "items": [["star", "star", "⭐ Bright Star"], ["star", "yellow star", "🌟 Wishing Star"], ["star", "night star", "✨ Little Star"]]},
	"landmark_T": {"station": "小火车站台", "prop": "train", "items": [["train", "train", "🚂 Red Train"], ["train", "toy train", "🚃 Toy Train"], ["train", "fast train", "🎫 Express Train"]]},
	"landmark_U": {"station": "晴雨伞架台", "prop": "umbrella", "items": [["umbrella", "umbrella", "☂️ Blue Umbrella"], ["umbrella", "rain umbrella", "☔ Rain Umbrella"], ["umbrella", "sunny umbrella", "🌂 Cozy Umbrella"]]},
	"landmark_V": {"station": "火山晶石台", "prop": "volcano_gem", "items": [["volcano_gem", "volcano", "🌋 Warm Crystal"], ["volcano_gem", "red stone", "💎 Volcano Gem"], ["volcano_gem", "glow rock", "🔥 Lava Stone"]]},
	"landmark_W": {"station": "鲸歌海螺台", "prop": "whale_shell", "items": [["whale_shell", "whale", "🐋 Whale Shell"], ["whale_shell", "sea whale", "🐚 Ocean Shell"], ["boat", "sea boat", "🌊 Wave Boat"]]},
	"landmark_X": {"station": "海风木琴架", "prop": "xylophone_bar", "items": [["xylophone_bar", "xylophone", "🎶 Gold Note"], ["xylophone_bar", "music bar", "🎵 Clear Tone"], ["xylophone_bar", "sweet note", "🎼 Sunny Bar"]]},
	"landmark_Y": {"station": "绒线编织篮", "prop": "yarn", "items": [["yarn", "yarn", "🧶 Pink Yarn"], ["yarn", "soft yarn", "🧶 Soft Yarn"], ["yarn", "warm wool", "🎀 Cozy Wool"]]},
	"landmark_Z": {"station": "斑马邮筒台", "prop": "zebra_letter", "items": [["zebra_letter", "zebra", "🦓 Zebra Card"], ["zebra_letter", "post letter", "✉️ Friend Letter"], ["zebra_letter", "island stamp", "📮 Post Stamp"]]},
	"home_estate": {"station": "小院迎宾花台", "prop": "flower", "items": [["flower", "garden flower", "🌸 Garden Flower"], ["apple", "home apple", "🍎 Fresh Apple"], ["zebra_letter", "welcome card", "✉️ Morning Mail"]]},
	"school": {"station": "校园图书分享车", "prop": "book", "items": [["book", "book", "📖 Picture Book"], ["star", "welcome star", "⭐ Welcome Star"], ["flower", "campus flower", "🌼 Sunny Flower"]]},
	"canteen": {"station": "暖心餐盘分享台", "prop": "milk", "items": [["milk", "milk", "🥛 Warm Milk"], ["bread", "bread", "🥐 Soft Bread"], ["cake", "cake", "🍰 Berry Cake"]]},
	"playground": {"station": "课间活力收纳筐", "prop": "ball", "items": [["ball", "ball", "⚽ Playground Ball"], ["kite", "kite", "🪁 Sunny Kite"], ["star", "team star", "🌟 Team Star"]]},
}

var game: Node3D
var active_room := ""
var _pickups: Array[Dictionary] = []
var _basket_pos := Vector3.ZERO
var _has_basket := false
var held_kind := ""
var held_word := ""
var delivered_this_visit := 0
var _floating_ring: MeshInstance3D
var _station_pedestal: Node3D
var _echo_badge: Label3D

static func supports_room(room_id: String) -> bool:
	return ROOM_QUEST_SPECS.has(room_id)

func attach_to_room(owner_game: Node3D, room_id: String) -> void:
	game = owner_game
	active_room = room_id
	_pickups.clear()
	_has_basket = false
	_station_pedestal = null
	_echo_badge = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if is_instance_valid(game) and is_instance_valid(game.player) and game.player.has_method("set_carried_item"):
		game.player.set_carried_item("")
	held_kind = ""
	held_word = ""
	delivered_this_visit = 0

	if ROOM_QUEST_SPECS.has(room_id):
		_setup_room_tactile_station(room_id)
	_setup_chapter_keepsake_if_completed(room_id)

func _setup_room_tactile_station(room_id: String) -> void:
	var cfg: Dictionary = ROOM_QUEST_SPECS[room_id]
	var spawn: Vector3 = game.metadata.get("spawn", Vector3.ZERO)

	if room_id == "landmark_A":
		var basket_mesh := game.world.find_child("A_Entrance_Basket", true, false) as MeshInstance3D
		if basket_mesh != null:
			_basket_pos = basket_mesh.global_position
		else:
			_basket_pos = _snap_walkable(spawn + Vector3(1.6, 0.0, -1.8))
	else:
		var target_anchor := spawn + Vector3(1.8, 0.0, -2.0)
		for inter: Dictionary in game.interactions:
			if str(inter.get("id", "")) == "memory_03":
				target_anchor = (inter.position as Vector3) + Vector3(0.85, 0.0, 0.65)
				break
		_basket_pos = _snap_walkable(target_anchor)
		_build_cozy_station_pedestal(str(cfg.get("station", "手作分享台")), str(cfg.get("prop", "star")))

	_has_basket = true

	var offsets := [
		Vector3(-2.4, 0.0, -2.2),
		Vector3(2.2, 0.0, -3.1),
		Vector3(-0.6, 0.0, -4.2),
	]
	var item_defs: Array = cfg.get("items", [])
	for idx in range(mini(item_defs.size(), offsets.size())):
		var pair: Array = item_defs[idx]
		var kind_id := str(pair[0])
		var word_en := str(pair[1])
		var label_txt := str(pair[2])
		var world_pt := _snap_walkable(spawn + (offsets[idx] as Vector3))
		# Ensure pickup isn't right on top of the station
		if Vector2(world_pt.x - _basket_pos.x, world_pt.z - _basket_pos.z).length() < 1.35:
			world_pt = _snap_walkable(_basket_pos + Vector3(-2.2 + float(idx) * 1.9, 0.0, 1.8))

		var holder := Node3D.new()
		holder.position = world_pt + Vector3(0.0, 0.24, 0.0)
		add_child(holder)

		var prop := Wardrobe.build_carried_prop(kind_id)
		if prop != null:
			prop.scale = Vector3.ONE * 1.35
			holder.add_child(prop)

		var tag := Label3D.new()
		tag.text = label_txt
		tag.font = load("res://assets/fonts/IslandSans.otf")
		tag.font_size = 28
		tag.pixel_size = 0.0065
		tag.modulate = Color("fffaf0")
		tag.outline_modulate = Color("52422f")
		tag.outline_size = 6
		tag.position = Vector3(0.0, 0.50, 0.0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(tag)

		_pickups.append({
			"node": holder,
			"pos": world_pt,
			"kind": kind_id,
			"word": word_en,
			"picked": false
		})

	_floating_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.56
	_floating_ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color("ffd966")
	_floating_ring.material_override = rmat
	_floating_ring.position = _basket_pos + Vector3(0.0, 0.09, 0.0)
	_floating_ring.visible = false
	add_child(_floating_ring)

	_refresh_persistent_echo_visuals()

func _build_cozy_station_pedestal(station_title: String, prop_id: String) -> void:
	_station_pedestal = Node3D.new()
	_station_pedestal.name = "CozyCraftStation"
	_station_pedestal.position = _basket_pos
	add_child(_station_pedestal)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("b98552")
	wood_mat.roughness = 0.46
	wood_mat.clearcoat_enabled = true
	wood_mat.clearcoat = 0.24

	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color("fbf4e4")
	cloth_mat.roughness = 0.62

	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.46
	cyl.height = 0.52
	base.mesh = cyl
	base.position = Vector3(0.0, 0.26, 0.0)
	base.material_override = wood_mat
	_station_pedestal.add_child(base)

	var mat_disc := MeshInstance3D.new()
	var dcyl := CylinderMesh.new()
	dcyl.top_radius = 0.36
	dcyl.bottom_radius = 0.36
	dcyl.height = 0.03
	mat_disc.mesh = dcyl
	mat_disc.position = Vector3(0.0, 0.53, 0.0)
	mat_disc.material_override = cloth_mat
	_station_pedestal.add_child(mat_disc)

	var sample := Wardrobe.build_carried_prop(prop_id)
	if sample != null:
		sample.position = Vector3(0.0, 0.64, 0.0)
		_station_pedestal.add_child(sample)

	_echo_badge = Label3D.new()
	_echo_badge.font = load("res://assets/fonts/IslandSans.otf")
	_echo_badge.font_size = 26
	_echo_badge.pixel_size = 0.0062
	_echo_badge.modulate = Color("fffaf0")
	_echo_badge.outline_modulate = Color("4f3e2a")
	_echo_badge.outline_size = 6
	_echo_badge.position = Vector3(0.0, 1.05, 0.0)
	_echo_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_echo_badge.text = "✨ " + station_title
	_station_pedestal.add_child(_echo_badge)

func _refresh_persistent_echo_visuals() -> void:
	if not is_instance_valid(game):
		return
	var state_node := game.get_node_or_null("/root/State")
	if state_node == null:
		return
	var v4_dict: Dictionary = state_node.data.get("v4", {}) if state_node.data.get("v4") is Dictionary else {}
	var crafts: Dictionary = v4_dict.get("landmark_crafts", {}) if v4_dict.get("landmark_crafts") is Dictionary else {}
	var count := int(crafts.get(active_room, 0))
	var cfg: Dictionary = ROOM_QUEST_SPECS.get(active_room, {})
	var st_title := str(cfg.get("station", "手作分享台"))
	if is_instance_valid(_echo_badge):
		if count > 0:
			_echo_badge.text = "🌟 %s · 已共创 %d 件" % [st_title, count]
			_echo_badge.modulate = Color("ffe999")
		else:
			_echo_badge.text = "✨ " + st_title
	# Spawn up to 3 persistent miniature keepsakes on the station from past visits!
	if count > 0 and active_room != "landmark_A":
		var prop_id := str(cfg.get("prop", "star"))
		var shown := mini(count, 3)
		for idx in range(shown):
			var marker_name := "EchoCraft_" + str(idx)
			if get_node_or_null(marker_name) != null:
				continue
			var item_node := Wardrobe.build_carried_prop(prop_id)
			if item_node != null:
				item_node.name = marker_name
				item_node.scale = Vector3.ONE * 0.78
				var ang := float(idx) * 2.09
				item_node.position = _basket_pos + Vector3(cos(ang) * 0.22, 0.62, sin(ang) * 0.22)
				add_child(item_node)

func _setup_chapter_keepsake_if_completed(room_id: String) -> void:
	if not is_instance_valid(game):
		return
	var state_node := game.get_node_or_null("/root/State")
	if state_node == null:
		return
	var StoryDirector := load("res://gameplay/unit_storyline_director.gd")
	if StoryDirector == null:
		return
	var completed_titles: Array[String] = StoryDirector.completed_titles_for_room(state_node, room_id)
	if completed_titles.is_empty():
		return
	var spawn: Vector3 = game.metadata.get("spawn", Vector3.ZERO)
	var sign_pos := _snap_walkable(spawn + Vector3(-2.1, 0.0, -1.2))
	var board := Node3D.new()
	board.name = "ChapterWorldKeepsake"
	board.position = sign_pos
	add_child(board)

	var post := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.05
	pcyl.bottom_radius = 0.06
	pcyl.height = 1.05
	post.mesh = pcyl
	post.position = Vector3(0.0, 0.52, 0.0)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("8f6239")
	wmat.roughness = 0.50
	post.material_override = wmat
	board.add_child(post)

	var plaque := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(1.45, 0.56, 0.08)
	plaque.mesh = pbox
	plaque.position = Vector3(0.0, 1.08, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("f6ebd2")
	pmat.roughness = 0.42
	plaque.material_override = pmat
	board.add_child(plaque)

	var lbl := Label3D.new()
	lbl.font = load("res://assets/fonts/IslandSans.otf")
	lbl.font_size = 24
	lbl.pixel_size = 0.0055
	lbl.modulate = Color("4f3d28")
	lbl.position = Vector3(0.0, 1.10, 0.06)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.text = "🏅 章节纪念牌\n" + completed_titles[-1]
	board.add_child(lbl)

func _snap_walkable(pt: Vector3) -> Vector3:
	if not is_instance_valid(game) or not game.nav_ready:
		return Vector3(pt.x, 0.0, pt.z)
	var cell := Vector2i(roundi(pt.x / game.NAV_CELL), roundi(pt.z / game.NAV_CELL))
	cell = game._nearest_walkable_cell(cell, pt)
	if not game.navigation.is_in_boundsv(cell):
		return Vector3(pt.x, 0.0, pt.z)
	return Vector3(cell.x * game.NAV_CELL, float(game.nav_heights.get(cell, 0.0)), cell.y * game.NAV_CELL)

func _process(delta: float) -> void:
	if not ROOM_QUEST_SPECS.has(active_room) or not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	if game.player.locked or is_instance_valid(game.orchard_activity):
		return

	var t := float(Time.get_ticks_msec()) * 0.003
	var ppos: Vector3 = game.player.global_position

	for item: Dictionary in _pickups:
		if bool(item.picked):
			continue
		var node := item.node as Node3D
		if is_instance_valid(node):
			if not game.ui.reduced_motion:
				node.rotation.y += delta * 1.2
				node.position.y = float((item.pos as Vector3).y) + 0.24 + sin(t + node.position.x) * 0.04
			if held_kind.is_empty() and Vector2(ppos.x - node.position.x, ppos.z - node.position.z).length() < 1.08:
				_pick_up_item(item)
				break

	if not held_kind.is_empty() and _has_basket:
		if is_instance_valid(_floating_ring):
			_floating_ring.visible = true
			if not game.ui.reduced_motion:
				_floating_ring.scale = Vector3.ONE * (1.0 + sin(t * 2.0) * 0.08)
		if Vector2(ppos.x - _basket_pos.x, ppos.z - _basket_pos.z).length() < 1.50:
			_deposit_in_station()
	elif is_instance_valid(_floating_ring):
		_floating_ring.visible = false

func _pick_up_item(item: Dictionary) -> void:
	item.picked = true
	var node := item.node as Node3D
	if is_instance_valid(node):
		node.hide()
	held_kind = str(item.kind)
	held_word = str(item.word)
	if game.player.has_method("set_carried_item"):
		game.player.set_carried_item(held_kind)
	game.player.gesture("reach")
	item_picked.emit(held_kind, held_word, active_room)
	if active_room == "landmark_A":
		apple_picked.emit(held_kind, held_word)

func _deposit_in_station() -> void:
	var kind_done := held_kind
	var word := held_word
	held_kind = ""
	held_word = ""
	delivered_this_visit += 1
	if game.player.has_method("set_carried_item"):
		game.player.set_carried_item("")
	game.player.gesture("reach")

	var settled := Wardrobe.build_carried_prop(kind_done)
	if settled != null:
		settled.scale = Vector3.ONE * (0.85 if active_room != "landmark_A" else 1.0)
		var angle := float(delivered_this_visit) * 2.1
		var y_off := 0.22 if active_room == "landmark_A" else 0.62
		settled.position = _basket_pos + Vector3(cos(angle) * 0.16, y_off, sin(angle) * 0.16)
		add_child(settled)

	var state_node := game.get_node_or_null("/root/State")
	var craft_total := delivered_this_visit
	if state_node != null and state_node.has_method("record_landmark_craft"):
		craft_total = int(state_node.record_landmark_craft(active_room, 4 if active_room != "landmark_A" else 0))
	_refresh_persistent_echo_visuals()

	station_delivered.emit(active_room, craft_total, word)
	if active_room == "landmark_A":
		basket_delivered.emit(delivered_this_visit, word)
