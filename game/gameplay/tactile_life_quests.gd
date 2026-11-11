extends Node3D
## V4 In-World Tactile Cozy Life Quests!
## Spawns hands-on 3D fruits & basket drop-zones directly inside `landmark_A` (Apple Orchard)
## so the player walks freely in 3D, picks a Red or Sweet Golden Apple into their 3D CarrySocket,
## carries it across the grass, and drops it into the wicker basket with joyful sparkles
## while stealthily logging vocabulary mastery (`apple`, `red`, `yellow`, `three`)!

signal apple_picked(kind: String, word_en: String)
signal basket_delivered(total_delivered: int, word_en: String)

const WorldArt = preload("res://scripts/world_art.gd")
const Style = preload("res://ui/island_theme.gd")

var game: Node3D
var active_room := ""
var _pickups: Array[Dictionary] = []
var _basket_pos := Vector3.ZERO
var _has_basket := false
var held_kind := ""
var held_word := ""
var delivered_this_visit := 0
var _floating_ring: MeshInstance3D

func attach_to_room(owner_game: Node3D, room_id: String) -> void:
	game = owner_game
	active_room = room_id
	_pickups.clear()
	_has_basket = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if is_instance_valid(game) and is_instance_valid(game.player) and game.player.has_method("set_carried_item"):
		game.player.set_carried_item("")
	held_kind = ""
	held_word = ""
	delivered_this_visit = 0

	if room_id == "landmark_A":
		_setup_tactile_orchard()

func _setup_tactile_orchard() -> void:
	var spawn: Vector3 = game.metadata.get("spawn", Vector3.ZERO)
	var basket_mesh := game.world.find_child("A_Entrance_Basket", true, false) as MeshInstance3D
	if basket_mesh != null:
		_basket_pos = basket_mesh.global_position
		_has_basket = true
	else:
		_basket_pos = spawn + Vector3(1.6, 0.0, -1.8)
		_has_basket = true

	var specs := [
		{"kind": "apple", "word": "red apple", "label": "🍎 Red Apple", "offset": Vector3(-2.4, 0.24, -2.2), "tint": null},
		{"kind": "apple", "word": "apple", "label": "🍎 Sweet Apple", "offset": Vector3(2.2, 0.24, -3.1), "tint": null},
		{"kind": "golden_apple", "word": "yellow apple", "label": "🌟 Golden Apple", "offset": Vector3(-0.6, 0.24, -4.2), "tint": Color("ffd45e")},
	]

	for spec: Dictionary in specs:
		var world_pt := _snap_walkable(spawn + (spec.offset as Vector3))
		var holder := Node3D.new()
		holder.position = world_pt + Vector3(0.0, 0.22, 0.0)
		add_child(holder)

		var prop := WorldArt.create_prop("apple")
		if prop != null:
			prop.scale = Vector3.ONE * 0.72
			if spec.tint != null:
				var gm := StandardMaterial3D.new()
				gm.albedo_color = spec.tint as Color
				gm.roughness = 0.28
				gm.clearcoat_enabled = true
				gm.clearcoat = 0.40
				for m: Node in prop.find_children("*", "MeshInstance3D", true, false):
					(m as MeshInstance3D).material_override = gm
			holder.add_child(prop)

		var tag := Label3D.new()
		tag.text = str(spec.label)
		tag.font = load("res://assets/fonts/IslandSans.otf")
		tag.font_size = 30
		tag.pixel_size = 0.0065
		tag.modulate = Color("fffaf0")
		tag.outline_modulate = Color("52422f")
		tag.outline_size = 6
		tag.position = Vector3(0.0, 0.52, 0.0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(tag)

		_pickups.append({
			"node": holder,
			"pos": world_pt,
			"kind": str(spec.kind),
			"word": str(spec.word),
			"picked": false
		})

	# Soft glowing golden ring around the wicker basket when carrying fruit!
	_floating_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.54
	_floating_ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color("ffd966")
	_floating_ring.material_override = rmat
	_floating_ring.position = _basket_pos + Vector3(0.0, 0.08, 0.0)
	_floating_ring.visible = false
	add_child(_floating_ring)

func _snap_walkable(pt: Vector3) -> Vector3:
	if not is_instance_valid(game) or not game.nav_ready:
		return Vector3(pt.x, 0.0, pt.z)
	var cell := Vector2i(roundi(pt.x / game.NAV_CELL), roundi(pt.z / game.NAV_CELL))
	cell = game._nearest_walkable_cell(cell, pt)
	return Vector3(cell.x * game.NAV_CELL, float(game.nav_heights.get(cell, 0.0)), cell.y * game.NAV_CELL)

func _process(delta: float) -> void:
	if active_room != "landmark_A" or not is_instance_valid(game) or not is_instance_valid(game.player):
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
				node.position.y = float((item.pos as Vector3).y) + 0.22 + sin(t + node.position.x) * 0.04
			if held_kind.is_empty() and Vector2(ppos.x - node.position.x, ppos.z - node.position.z).length() < 1.05:
				_pick_up_fruit(item)
				break

	if not held_kind.is_empty() and _has_basket:
		if is_instance_valid(_floating_ring):
			_floating_ring.visible = true
			if not game.ui.reduced_motion:
				_floating_ring.scale = Vector3.ONE * (1.0 + sin(t * 2.0) * 0.08)
		if Vector2(ppos.x - _basket_pos.x, ppos.z - _basket_pos.z).length() < 1.45:
			_deposit_in_basket()
	elif is_instance_valid(_floating_ring):
		_floating_ring.visible = false

func _pick_up_fruit(item: Dictionary) -> void:
	item.picked = true
	var node := item.node as Node3D
	if is_instance_valid(node):
		node.hide()
	held_kind = str(item.kind)
	held_word = str(item.word)
	if game.player.has_method("set_carried_item"):
		game.player.set_carried_item(held_kind)
	game.player.gesture("reach")
	apple_picked.emit(held_kind, held_word)

func _deposit_in_basket() -> void:
	var word := held_word
	held_kind = ""
	held_word = ""
	delivered_this_visit += 1
	if game.player.has_method("set_carried_item"):
		game.player.set_carried_item("")
	game.player.gesture("reach")

	# Visually place a real miniature 3D apple inside the orchard basket!
	var settled := WorldArt.create_prop("apple")
	if settled != null:
		settled.scale = Vector3.ONE * 0.45
		var angle := float(delivered_this_visit) * 2.1
		settled.position = _basket_pos + Vector3(cos(angle) * 0.14, 0.22, sin(angle) * 0.14)
		add_child(settled)

	basket_delivered.emit(delivered_this_visit, word)
