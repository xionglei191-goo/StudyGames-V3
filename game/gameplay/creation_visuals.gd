extends RefCounted
const C = preload("res://gameplay/creation_catalog.gd")
const Canvas = preload("res://ui/creation_canvas.gd")
const Style = preload("res://ui/island_theme.gd")
const Finishes = preload("res://actors/layer2_prop_library.gd")
static var _models: Dictionary = {}

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
	var recipe: String = d.recipe
	var model_id := recipe
	match recipe:
		"stool","table":
			model_id += "_round" if int(d.shape) == 0 else "_square"
		"vase":
			model_id += "_round" if int(d.shape) == 0 else "_tall"
	if not _models.has(model_id):
		var model_path := "res://assets/props/handcrafted_furniture/l2_%s.glb" % model_id
		if ResourceLoader.exists(model_path):
			_models[model_id] = load(model_path) as PackedScene
	var source := _models.get(model_id) as PackedScene
	if source != null:
		var art := source.instantiate() as Node3D
		root.add_child(art)
		Finishes.apply_finishes(art,color)
		if recipe in ["cake","plate"]:
			art.rotation.y = int(d.shape)*0.4
	match recipe:
		"table","stand":
			surface(root,d,Vector2(1.02,1.02),Vector3(0,C.TABLETOP_HEIGHT,0))
		"sign","frame":
			surface(root,d,Vector2(1.25,0.90),Vector3(0,1.25,0.083),true)
		"rug":
			surface(root,d,Vector2(1.80,1.35),Vector3(0,0.036,0))
		"cake","plate":
			surface(root,d,Vector2.ONE,Vector3(0,0.003,0))
		"lantern":
			var light := OmniLight3D.new()
			light.position = Vector3(0,1.30,0)
			light.light_color = color.lightened(0.38)
			light.light_energy = 1.4 if lit else 0.0
			light.omni_range = 4
			root.add_child(light)
	if int(d.trim) > 0:
		var inlay := cylinder(root,0.037,0.008,_trim_position(recipe,int(d.shape)),Color("dbaa4c") if int(d.trim)==1 else Color("54a89f"))
		var mat := inlay.material_override as StandardMaterial3D
		mat.metallic = 0.65
		mat.roughness = 0.36
		if recipe in ["frame","sign","shelf","basket","lantern","vase"]:
			inlay.rotation.x = PI/2
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

static func _trim_position(recipe: String, shape: int) -> Vector3:
	match recipe:
		"stool": return Vector3(0.255,0.628 if shape == 0 else 0.618,0.23)
		"table","stand": return Vector3(0.56,C.TABLETOP_HEIGHT,0.42)
		"sign","frame": return Vector3(0.672,1.26,0.091)
		"rug": return Vector3(0.93,0.044,0.62)
		"basket": return Vector3(0,0.32,0.347)
		"vase": return Vector3(0,0.24,0.252 if shape == 0 else 0.205)
		"lantern": return Vector3(0,0.075,0.31)
		"shelf": return Vector3(-0.508,1.24,0.276)
	return Vector3(0.38,0.060,0.20)

static func footprint(recipe: String) -> Vector3:
	if recipe in ["table","stand"]: return Vector3(1.55,1.0,1.55)
	if recipe == "rug": return Vector3(1.95,0.04,1.5)
	if recipe in ["sign","frame","shelf"]: return Vector3(1.45,1.75,0.6)
	return Vector3(0.8,0.65 if recipe == "stool" else 1.0,0.8)
