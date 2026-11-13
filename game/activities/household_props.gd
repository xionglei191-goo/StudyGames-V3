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
	if room == "home": hidden = ["Home_Cup_Refined*", "Home_Plate*"]
	elif room == "home_study": hidden = ["Reading_Bookcase_Book_004", "Reading_Bookcase_Book_Label_004"]
	for pattern: String in hidden:
		for node: Node3D in world.find_children(pattern,"Node3D",true,false): node.hide()
	if room == "home_estate":
		# The refined planter is wider than the old three small soil decals.
		for i in range(3):
			var name := "Damp_Soil" + ("" if i == 0 else "_%03d" % i)
			var patch := world.find_child(name,true,false) as MeshInstance3D
			if not patch: continue
			var shape := BoxMesh.new()
			shape.size = Vector3(0.94,0.015,0.90)
			patch.mesh = shape
			patch.material_override = material(Color("68503c"))
			patch.global_transform = Transform3D(Basis.IDENTITY,Vector3(7.69+i*0.96,0.51,11.85))
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
