extends RefCounted
## Small runtime props supplement the authored furniture; existing task meshes are reused.

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.68
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

static func prepare_room(world: Node3D, room: String) -> void:
	# These baked decorations occupied the same slots as the interactive objects.
	# Keep a single visible set of props in both the activity and the saved room.
	var hidden: Array[String] = []
	if room == "home": hidden = ["Home_Cup_Refined*", "Home_Plate*", "Letter", "Letter_Ribbon*", "Pencil_Cup*"]
	elif room == "home_study": hidden = ["Reading_Bookcase_Book_004", "Reading_Bookcase_Book_Label_004"]
	for pattern: String in hidden:
		for node: Node3D in world.find_children(pattern,"Node3D",true,false): node.hide()
	match room:
		"home_estate":
			# Move Welcome_Parcel_Basket (+WorldArt_basket child) onto the grass right of Welcome_Letter_Table,
			# move Porch_Ready_Basket (+WorldArt_basket child) onto the open lawn left of the porch post & corner post,
			# and clear Porch_Geranium from Main_Front_Opening_1_Flower_Box.
			_shift_nodes(world, ["Welcome_Parcel_Basket*"], Vector3(0.98, 0.0, 0.0))
			_shift_nodes(world, ["Porch_Ready_Basket*"], Vector3(-1.22, 0.0, 0.38))
			_shift_nodes(world, ["Porch_Geranium*"], Vector3(2.25, 0.0, 0.38))
			# The refined planter is wider than the old three small soil decals.
			for i in range(3):
				var name := "Damp_Soil" + ("" if i == 0 else "_%03d" % i)
				var patch := world.find_child(name,true,false) as MeshInstance3D
				if not patch or patch.has_meta("prop_depenetrated"): continue
				var shape := BoxMesh.new()
				shape.size = Vector3(0.94,0.015,0.90)
				patch.mesh = shape
				patch.material_override = material(Color("68503c"))
				var soil_xf := Transform3D(Basis.IDENTITY,Vector3(7.69+i*0.96,0.51,11.85))
				if patch.is_inside_tree():
					patch.global_transform = soil_xf
				else:
					patch.transform = soil_xf
				patch.set_meta("prop_depenetrated", true)
		"home":
			_shift_nodes(world, ["Locus_01_Everyday_Basket*"], Vector3(0.24, 0.0, 0.0))
		"home_bedroom":
			_shift_nodes(world, ["Schoolbag*"], Vector3(0.0, 0.07, 0.09))
		"home_balcony":
			_shift_nodes(world, ["OWN07_Watering_can_*"], Vector3(-1.08, -0.575, 0.25))
		"canteen":
			_shift_nodes(world, ["Back_Greenery*", "WR_Pottery_Lip_Back_Greenery_Pot*"], Vector3(0.55, 0.0, 0.0))
			_shift_mesh_region(world, ["CF08_InteriorHerbs_leaf*"], AABB(Vector3(6.0, 0.3, -6.4), Vector3(1.6, 1.0, 1.4)), Vector3(0.55, 0.0, 0.0))
		"classroom":
			_scale_and_shift_nodes(world, ["Class_Prop_Hat*"], Vector3(4.40, 0.30, -1.25), 0.66, Vector3(0.0, -0.058, 0.075))
		"science_room":
			_scale_and_shift_nodes(world, ["Science_ModelSolar*"], Vector3(-1.20, 1.28, -6.65), 0.62, Vector3(0.0, 0.012, 0.165))
		"school":
			_shift_nodes(world, ["Music_Outdoor_Xylophone_Key*", "Music_Xylophone_Leg*"], Vector3(-0.85, 0.0, 0.0))
			_shift_nodes(world, ["Art_Outdoor_Easel*", "Art_Outdoor_Canvas*", "Art_Painting_Color*"], Vector3(-0.66, 0.0, 0.0))
			_shift_nodes(world, ["Canteen_Menu_Board_Face*", "Canteen_Menu_Board_Frame*", "Canteen_Menu_Board_Post*", "Canteen_Menu_Board_Subtitle*", "Canteen_Menu_Board_Title*"], Vector3(0.45, 0.0, 0.0))
		"landmark_A":
			_shift_nodes(world, ["A_Entrance_Basket*", "A_Basket_Apple*"], Vector3(0.0, 0.0, 0.46))
			_shift_nodes(world, ["A_Spare_Crate_*"], Vector3(-0.34, 0.0, -0.18))
		"landmark_F":
			_shift_nodes(world, ["Back_Greenery*", "WR_Pottery_Lip_Back_Greenery_Pot*"], Vector3(0.55, 0.0, 1.05))
		"landmark_H":
			_scale_and_shift_nodes(world, ["Trying_Hat*", "OWN16_RibbonFold_001", "OWN16_RibbonKnot_001"], Vector3(1.08, 0.89, -1.598), 0.72, Vector3(0.12, 0.0, 0.218))
		"landmark_J":
			_shift_nodes(world, ["Jar_Labels_Card*", "Jar_Labels_Picture*"], Vector3(0.0, 0.56, -0.06))
			_shift_nodes(world, ["Back_Greenery*", "WR_Pottery_Lip_Back_Greenery_Pot*"], Vector3(0.35, 0.0, 0.95))
		"landmark_K":
			_shift_nodes(world, ["Bamboo_Spar*"], Vector3(2.65, -0.18, 0.0))
		"landmark_L":
			_scale_and_shift_nodes(world, ["Gift_Lantern*", "Detail_L_Bent_Lantern_Rib_08*", "Detail_L_Paper_Binding_024", "Detail_L_Paper_Binding_025", "Detail_L_Paper_Binding_026", "Detail_L_Upright_Bail_008", "Detail_L_Display_Base"], Vector3(5.20, 1.09, 5.15), 0.68, Vector3(0.0, 0.0, -0.12))
		"landmark_M":
			_shift_nodes(world, ["Cottage_Back_Kitchen*", "WR_Cabinet_*Cottage_Back_Kitchen*"], Vector3(-0.78, 0.0, 0.0))
		"landmark_U":
			_scale_and_shift_nodes(world, ["Folded_Umbrella", "Umbrella_Handle"], Vector3(-5.80, 0.20, -1.10), 0.36, Vector3(0.0, 0.042, 0.0))
			_scale_and_shift_nodes(world, ["Folded_Umbrella_001", "Umbrella_Handle_001"], Vector3(-5.10, 0.20, -1.10), 0.36, Vector3(0.0, 0.042, 0.0))
			_scale_and_shift_nodes(world, ["Folded_Umbrella_002", "Umbrella_Handle_002"], Vector3(-4.40, 0.20, -1.10), 0.36, Vector3(0.0, 0.042, 0.0))
			_shift_nodes(world, ["Back_Greenery*", "WR_Pottery_Lip_Back_Greenery_Pot*"], Vector3(0.42, 0.0, 1.25))
	if room != "home_study": return
	var after := world.find_child("HOME_TASK_AFTER",true,false) as Node3D
	if not after or after.has_meta("book_details"): return
	after.set_meta("book_details",true)
	for i in range(3):
		var pos := Vector3(1.5+i*0.19,0.45,-4.4)
		var height := 0.45+i*0.06
		var pages := box(after,Vector3(0.012,height-0.04,0.30),Vector3.ZERO,Color("f6efda"))
		pages.name = "Returned_Book_Detail_%d_Pages" % i
		pages.global_position = pos + Vector3(0.078,(height-0.45)/2,-0.025)
		for stripe in range(2):
			var label := box(after,Vector3(0.10,0.026,0.012),Vector3.ZERO,Color("f6efda"))
			label.name = "Returned_Book_Detail_%d_Label_%d" % [i,stripe]
			label.global_position = pos + Vector3(0,-0.1+stripe*0.18,0.194)

static func _collect_top_matched_nodes(world: Node3D, patterns: Array[String]) -> Array[Node3D]:
	var matched: Array[Node3D] = []
	var matched_ids: Dictionary = {}
	for pattern: String in patterns:
		for node: Node in world.find_children(pattern, "Node3D", true, false):
			var n3 := node as Node3D
			if n3 == null: continue
			var nm := str(n3.name)
			if nm.begins_with("SG_") or nm.begins_with("COL_"): continue
			var id := n3.get_instance_id()
			if not matched_ids.has(id):
				matched_ids[id] = true
				matched.append(n3)
	var top_nodes: Array[Node3D] = []
	for n3: Node3D in matched:
		var has_matched_ancestor := false
		var p: Node = n3.get_parent()
		while p != null and p != world:
			if matched_ids.has(p.get_instance_id()):
				has_matched_ancestor = true
				break
			p = p.get_parent()
		if not has_matched_ancestor:
			top_nodes.append(n3)
	return top_nodes

static func _shift_nodes(world: Node3D, patterns: Array[String], delta: Vector3) -> void:
	for node: Node3D in _collect_top_matched_nodes(world, patterns):
		if node.has_meta("prop_depenetrated"):
			continue
		if node.is_inside_tree():
			node.global_position += delta
		else:
			node.position += delta
		node.set_meta("prop_depenetrated", true)

static func _scale_and_shift_nodes(world: Node3D, patterns: Array[String], world_pivot: Vector3, scale_factor: float, delta: Vector3) -> void:
	for node: Node3D in _collect_top_matched_nodes(world, patterns):
		if node.has_meta("prop_depenetrated"):
			continue
		var xf := node.global_transform if node.is_inside_tree() else node.transform
		var new_origin := world_pivot + (xf.origin - world_pivot) * scale_factor + delta
		var new_xf := Transform3D(xf.basis * scale_factor, new_origin)
		if node.is_inside_tree():
			node.global_transform = new_xf
		else:
			node.transform = new_xf
		node.set_meta("prop_depenetrated", true)

static func _shift_mesh_region(world: Node3D, patterns: Array[String], region: AABB, delta: Vector3) -> void:
	for pattern: String in patterns:
		for node: Node in world.find_children(pattern, "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi == null or mi.has_meta("prop_depenetrated"):
				continue
			var src_mesh := mi.mesh as ArrayMesh
			if src_mesh == null:
				continue
			var xf := mi.global_transform if mi.is_inside_tree() else mi.transform
			var local_delta := xf.basis.inverse() * delta
			var new_mesh := ArrayMesh.new()
			var changed := false
			for s in range(src_mesh.get_surface_count()):
				var arrays := src_mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var new_verts := verts.duplicate()
				for vi in range(new_verts.size()):
					if region.has_point(xf * new_verts[vi]):
						new_verts[vi] += local_delta
						changed = true
				arrays[Mesh.ARRAY_VERTEX] = new_verts
				new_mesh.add_surface_from_arrays(src_mesh.surface_get_primitive_type(s), arrays)
				new_mesh.surface_set_name(s, src_mesh.surface_get_name(s))
				var surf_mat := src_mesh.surface_get_material(s)
				if surf_mat != null:
					new_mesh.surface_set_material(s, surf_mat)
			if changed:
				mi.mesh = new_mesh
			mi.set_meta("prop_depenetrated", true)

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = pos
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color)

static func sphere(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var node := mesh(parent, shape, pos, color)
	node.scale = size
	return node

static func clone_parts(world: Node3D, parent: Node3D, names: Array, origin: Vector3, group: String = "HOME_TASK_AFTER") -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = origin
	var source: Node = world.find_child(group, true, false)
	if source == null: return root
	for child: Node in source.find_children("*", "MeshInstance3D", true, false):
		var selected := false
		for pattern: String in names:
			if str(child.name).match(pattern): selected = true
		if not selected: continue
		var original := child as MeshInstance3D
		var copy := MeshInstance3D.new()
		copy.mesh = original.mesh
		copy.material_override = original.material_override
		for surface in range(original.get_surface_override_material_count()):
			copy.set_surface_override_material(surface, original.get_surface_override_material(surface))
		root.add_child(copy)
		copy.global_transform = original.global_transform
	return root

static func ghost(parent: Node3D, source: Node3D, target: Vector3) -> Node3D:
	var root := source.duplicate() as Node3D
	parent.add_child(root)
	root.position = target
	var mat := material(Color(0.40, 0.72, 0.58, 0.28))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		child.material_override = mat
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func ring(parent: Node3D, pos: Vector3, radius: float) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - 0.018
	shape.outer_radius = radius + 0.018
	shape.rings = 32
	shape.ring_segments = 8
	var node := mesh(parent, shape, pos, Color("7fce94"))
	(node.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(node.material_override as StandardMaterial3D).no_depth_test = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func tray(parent: Node3D, pos: Vector3, size: Vector2) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	box(root, Vector3(size.x, 0.09, size.y), Vector3.ZERO, Color("caa47a"))
	for x in [-1.0, 1.0]:
		box(root, Vector3(0.07, 0.14, size.y), Vector3(x * size.x / 2, 0.05, 0), Color("9e7856"))
		for z in [-1.0, 1.0]:
			box(root, Vector3(0.08, pos.y, 0.08), Vector3(x * size.x * 0.4, -pos.y / 2, z * size.y * 0.4), Color("9e7856"))
	return root

static func hands(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	for side in [-1.0, 1.0]:
		var hand := Node3D.new()
		root.add_child(hand)
		hand.position.x = side * 0.13
		sphere(hand, Vector3(0.22, 0.13, 0.28), Vector3.ZERO, Color("eac2a2"))
		for i in range(4):
			sphere(hand, Vector3(0.048, 0.07, 0.19), Vector3(-0.076 + i * 0.05, 0, -0.17), Color("eac2a2"))
		sphere(hand, Vector3(0.08, 0.09, 0.17), Vector3(-side * 0.12, 0, -0.04), Color("eac2a2"))
		sphere(hand, Vector3(0.15, 0.13, 0.26), Vector3(0, -0.035, 0.22), Color("eac2a2"))
		box(hand, Vector3(0.18, 0.16, 0.14), Vector3(0, -0.04, 0.36), Color("f1d28a"))
	return root

static func foam(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	for i in range(18):
		var angle := i * 2.399
		var radius := 0.06 + (i % 4) * 0.045
		sphere(root, Vector3.ONE * (0.07 + (i % 3) * 0.022), Vector3(cos(angle) * radius, 0.07 + (i % 2) * 0.035, sin(angle) * radius), Color(0.93, 0.98, 1.0, 0.85))
	return root

static func dirt(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	for i in range(7):
		var angle := i * 2.399
		sphere(root, Vector3(0.07, 0.025, 0.08), Vector3(cos(angle) * 0.14, 0.245, sin(angle) * 0.13), Color("795b38"))
	return root

static func stream(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	for i in range(16):
		sphere(root, Vector3(0.025, 0.075, 0.025), Vector3.ZERO, Color(0.53, 0.84, 0.95, 0.78))
	root.hide()
	return root

static func animate_stream(root: Node3D, start: Vector3, end: Vector3, seconds: float, reduced: bool) -> void:
	root.show()
	for i in range(root.get_child_count()):
		var fraction := fposmod(i / 16.0 + (0.0 if reduced else seconds * 1.9), 1.0)
		root.get_child(i).global_position = start.lerp(end, fraction) + Vector3(sin(i * 2.4) * 0.035, 0, cos(i * 2.4) * 0.035)
