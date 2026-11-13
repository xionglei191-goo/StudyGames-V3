extends RefCounted
const C = preload("res://gameplay/creation_catalog.gd")
const Canvas = preload("res://ui/creation_canvas.gd")
const Style = preload("res://ui/island_theme.gd")

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent,shape,pos,color)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	return mesh(parent,shape,pos,color)

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	node.material_override = mat
	parent.add_child(node)
	return node

static func surface(parent: Node3D, d: Dictionary, size: Vector2, pos: Vector3, vertical: bool = false) -> void:
	var shape := PlaneMesh.new()
	shape.size = size
	var node := mesh(parent,shape,pos,Color.WHITE)
	if vertical: node.rotation_degrees.x = 90
	var mat := node.material_override as StandardMaterial3D
	mat.albedo_texture = Canvas.texture_for(d.pattern,bool(d.repeat))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if d.keepsake.begins_with("user://") and FileAccess.file_exists(d.keepsake):
		var image := Image.load_from_file(d.keepsake)
		if image: mat.albedo_texture = ImageTexture.create_from_image(image)
	if not str(d.text).is_empty():
		var label := Label3D.new()
		label.text = d.text
		label.font = Style.body_font()
		label.font_size = 52
		label.pixel_size = minf(0.007,size.x/maxf(200, str(d.text).length()*42))
		label.modulate = Color("292f3a")
		label.outline_size = 6
		label.outline_modulate = Color("fff9eb")
		label.position = pos + (Vector3(0,0,0.015) if vertical else Vector3(0,0.015,0))
		if not vertical: label.rotation_degrees.x = -90
		parent.add_child(label)

static func build(d: Dictionary, collision: bool = false, lit: bool = true) -> Node3D:
	var root := Node3D.new()
	var color := Color(C.PALETTE[int(d.color)])
	var wood := Color("ae8058")
	var accent := color.lightened(0.25)
	var recipe: String = d.recipe
	match recipe:
		"stool", "table", "stand":
			var width := 0.8 if recipe == "stool" else 1.55
			var height := 0.55 if recipe == "stool" else 0.9
			if int(d.shape) == 0 and recipe != "stand": cylinder(root,width/2,0.15,Vector3(0,height,0),color)
			else: box(root,Vector3(width,0.15,width),Vector3(0,height,0),color)
			for x in [-1,1]:
				for z in [-1,1]:
					box(root,Vector3(0.11,height,0.11),Vector3(x*width*0.28,height/2,z*width*0.28),wood)
			if recipe in ["table","stand"]: surface(root,d,Vector2(width*0.66,width*0.66),Vector3(0,height+0.08,0))
		"sign", "frame":
			box(root,Vector3(0.12,1.15,0.12),Vector3(0,0.57,0),wood)
			box(root,Vector3(0.85,0.09,0.6),Vector3(0,0.045,0),wood)
			box(root,Vector3(1.45,1.08,0.15),Vector3(0,1.25,0),color)
			surface(root,d,Vector2(1.25,0.9),Vector3(0,1.25,0.083),true)
		"rug":
			box(root,Vector3(1.95,0.03,1.5),Vector3(0,0.018,0),color)
			surface(root,d,Vector2(1.8,1.35),Vector3(0,0.036,0))
		"vase":
			cylinder(root,0.23,0.5,Vector3(0,0.25,0),color)
			for x in [-1,0,1]:
				cylinder(root,0.025,0.5,Vector3(x*0.11,0.65,0),Color("54775e"))
				var flower := SphereMesh.new()
				flower.radius = 0.14
				flower.height = 0.28
				mesh(root,flower,Vector3(x*0.15,0.9+abs(x)*0.08,int(d.shape)*0.08),Color("e78d8d") if x != 0 else Color("efb951"))
		"basket":
			cylinder(root,0.36,0.42,Vector3(0,0.21,0),color)
			for y in range(4): cylinder(root,0.37,0.035,Vector3(0,0.07+y*0.1,0),wood)
		"lantern":
			cylinder(root,0.34,0.1,Vector3(0,0.05,0),wood)
			box(root,Vector3(0.1,1.3,0.1),Vector3(0,0.65,0),wood)
			var globe := SphereMesh.new()
			globe.radius = 0.34
			globe.height = 0.68
			mesh(root,globe,Vector3(0,1.3,0),accent)
			var light := OmniLight3D.new()
			light.position = Vector3(0,1.3,0)
			light.light_color = accent
			light.light_energy = 1.4 if lit else 0.0
			light.omni_range = 4
			root.add_child(light)
		"shelf":
			box(root,Vector3(1.1,1.3,0.12),Vector3(0,0.65,-0.22),color)
			for y in [0.1,0.65,1.2]:
				box(root,Vector3(1.1,0.09,0.55),Vector3(0,y,0),wood)
				if y < 1:
					for n in range(5): box(root,Vector3(0.12,0.35,0.3),Vector3(-0.38+n*0.19,y+0.22,0),Color(C.PALETTE[5+n]))
		"cake", "plate":
			surface(root,d,Vector2(1.0,1.0),Vector3(0,0.009,0))
			cylinder(root,0.45,0.05,Vector3(0,0.025,0),accent)
			if recipe == "cake": cylinder(root,0.34,0.28,Vector3(0,0.18,0),Color("efc88f"))
			for n in range(5):
				var angle := n*TAU/5.0 + int(d.shape)*0.4
				var fruit := SphereMesh.new()
				fruit.radius = 0.09
				fruit.height = 0.14
				mesh(root,fruit,Vector3(cos(angle)*0.23,0.37 if recipe == "cake" else 0.1,sin(angle)*0.23),color)
	if int(d.trim) > 0:
		cylinder(root,0.09,0.06,Vector3(0.32,0.08,0.3),Color("efb951") if int(d.trim)==1 else Color("8acac2"))
	if collision and recipe not in ["rug","cake","plate"]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = footprint(recipe)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = shape.size.y/2
		body.add_child(collider)
		root.add_child(body)
	return root

static func footprint(recipe: String) -> Vector3:
	if recipe in ["table","stand"]: return Vector3(1.55,1.0,1.55)
	if recipe == "rug": return Vector3(1.95,0.04,1.5)
	if recipe in ["sign","frame","shelf"]: return Vector3(1.45,1.75,0.6)
	return Vector3(0.8,0.65 if recipe == "stool" else 1.0,0.8)
