extends Node3D
## Surrounds every interior and landmark room with a handcrafted Toy Diorama Plinth
## and gentle surrounding scenery so no scene ever floats in a flat empty void.

const DioramaEnv = preload("res://world/diorama_environment.gd")
const WaterShader = preload("res://shaders/toy_water.gdshader")
const FoliageShader = preload("res://shaders/toy_foliage_wind.gdshader")

var _clouds: Array[Node3D] = []
var _water_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial
var _elapsed := 0.0
var reduced_motion := false

func setup(room_id: String, scene_info: Dictionary) -> void:
	name = "DioramaBackdrop"
	if room_id == "village":
		_build_island_horizon_ring()
		return

	var bounds: Rect2 = scene_info.get("scene_bounds", Rect2(-10.0, -10.0, 20.0, 20.0))
	if bounds.size.x < 4.0 or bounds.size.y < 4.0:
		bounds = Rect2(-10.0, -10.0, 20.0, 20.0)

	var outdoor := DioramaEnv.is_outdoor(room_id)
	_build_wooden_plinth(bounds, outdoor)
	if outdoor:
		_build_outdoor_surroundings(room_id, bounds)
	else:
		_build_indoor_surroundings(room_id, bounds)
	_build_drifting_clouds(bounds, outdoor)

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_elapsed += delta
	if _water_mat != null:
		_water_mat.set_shader_parameter("world_time", _elapsed)
	if _foliage_mat != null:
		_foliage_mat.set_shader_parameter("wind_time", _elapsed)
	for i in range(_clouds.size()):
		var cloud := _clouds[i]
		if is_instance_valid(cloud):
			var base_pos: Vector3 = cloud.get_meta("base_pos", cloud.position)
			var speed: float = float(cloud.get_meta("speed", 0.35))
			var span: float = float(cloud.get_meta("span", 26.0))
			var offset := fmod(_elapsed * speed + float(i) * 5.7, span * 2.0) - span
			cloud.position = Vector3(base_pos.x + offset, base_pos.y + sin(_elapsed * 0.7 + float(i)) * 0.12, base_pos.z)

func _toy_mat(color: Color, roughness: float = 0.62, metallic: float = 0.0, clearcoat: float = 0.15) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if clearcoat > 0.01:
		mat.clearcoat_enabled = true
		mat.clearcoat = clearcoat
		mat.clearcoat_roughness = 0.35
	return mat

func _build_wooden_plinth(bounds: Rect2, outdoor: bool) -> void:
	var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var pad := 1.35 if outdoor else 0.95
	var w := bounds.size.x + pad * 2.0
	var d := bounds.size.y + pad * 2.0

	# Upper creamy limestone / warm oak bezel right below y = -0.03 (never Z-fighting with y=0 floor)
	var upper := MeshInstance3D.new()
	var upper_box := BoxMesh.new()
	upper_box.size = Vector3(w, 0.28, d)
	upper.mesh = upper_box
	upper.position = center + Vector3(0.0, -0.17, 0.0)
	upper.material_override = _toy_mat(Color("d9ebc8") if outdoor else Color("ebd4b7"), 0.58, 0.0, 0.20)
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(upper)

	# Lower rich walnut diorama base frame
	var lower := MeshInstance3D.new()
	var lower_box := BoxMesh.new()
	lower_box.size = Vector3(w + 0.75, 0.46, d + 0.75)
	lower.mesh = lower_box
	lower.position = center + Vector3(0.0, -0.54, 0.0)
	lower.material_override = _toy_mat(Color("8c5e3c") if not outdoor else Color("9d6e48"), 0.46, 0.02, 0.35)
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(lower)

	# Warm brass miniature badge plate on front rim
	var plaque := MeshInstance3D.new()
	var plaque_box := BoxMesh.new()
	plaque_box.size = Vector3(minf(3.4, w * 0.24), 0.18, 0.10)
	plaque.mesh = plaque_box
	plaque.position = center + Vector3(0.0, -0.50, d * 0.5 + 0.40)
	plaque.material_override = _toy_mat(Color("e6be6a"), 0.28, 0.65, 0.40)
	add_child(plaque)

func _build_outdoor_surroundings(room_id: String, bounds: Rect2) -> void:
	var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var max_span := maxf(bounds.size.x, bounds.size.y)

	# Soft pastel meadow tabletop terrace beneath the diorama plinth
	var meadow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = max_span * 1.45 + 14.0
	cyl.bottom_radius = max_span * 1.52 + 15.0
	cyl.height = 0.50
	cyl.radial_segments = 48
	meadow.mesh = cyl
	meadow.position = center + Vector3(0.0, -1.02, 0.0)
	var is_sea_room := room_id in ["landmark_B", "landmark_F", "landmark_I", "landmark_O", "landmark_S", "landmark_U", "landmark_W"]
	meadow.material_override = _toy_mat(Color("dfcfa8") if is_sea_room else Color("a9d48b"), 0.72, 0.0, 0.08)
	add_child(meadow)

	# Sparkling turquoise toy sea skirt beyond the meadow
	var sea := MeshInstance3D.new()
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(max_span * 5.0 + 90.0, max_span * 5.0 + 90.0)
	sea_plane.subdivide_width = 32
	sea_plane.subdivide_depth = 32
	sea.mesh = sea_plane
	sea.position = center + Vector3(0.0, -0.92 if is_sea_room else -1.18, 0.0)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WaterShader
	_water_mat.set_shader_parameter("shallow_color", Color(0.49, 0.86, 0.81, 0.88))
	_water_mat.set_shader_parameter("deep_color", Color(0.24, 0.63, 0.74, 0.95))
	sea.material_override = _water_mat
	add_child(sea)

	# Shared wind-swaying foliage material for surrounding miniature hills & trees
	_foliage_mat = ShaderMaterial.new()
	_foliage_mat.shader = FoliageShader
	_foliage_mat.set_shader_parameter("albedo_tint", Color("66b067"))
	_foliage_mat.set_shader_parameter("tip_warmth", Color("b4dc73"))

	var hill_mat := _toy_mat(Color("8ec878"), 0.70, 0.0, 0.08)
	var trunk_mat := _toy_mat(Color("916240"), 0.65, 0.0, 0.12)
	var blossom_colors := [Color("f59ca9"), Color("ffd46b"), Color("fff6e3"), Color("b79ced")]

	var ring_rx := bounds.size.x * 0.5 + 5.2
	var ring_rz := bounds.size.y * 0.5 + 5.2
	var seed_val := absi(room_id.hash())

	for i in range(18):
		var angle := float(i) * TAU / 18.0 + 0.17
		# Leave front-south camera sightline open so isometric view is never occluded!
		if sin(angle) > 0.58:
			continue
		var dist_boost := 1.0 + float((seed_val + i * 19) % 5) * 0.14
		var pos := center + Vector3(cos(angle) * ring_rx * dist_boost, -0.76, sin(angle) * ring_rz * dist_boost)

		if i % 3 == 0:
			var hill := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 2.4 + float(i % 3) * 0.65
			sphere.height = sphere.radius * 1.15
			sphere.radial_segments = 20
			sphere.rings = 10
			hill.mesh = sphere
			hill.scale = Vector3(1.35, 0.58, 1.15)
			hill.position = pos + Vector3(0.0, -0.15, 0.0)
			hill.material_override = hill_mat
			add_child(hill)

		# Miniature toy tree
		var tree := Node3D.new()
		tree.position = pos
		add_child(tree)

		var trunk := MeshInstance3D.new()
		var t_cyl := CylinderMesh.new()
		t_cyl.top_radius = 0.14
		t_cyl.bottom_radius = 0.22
		t_cyl.height = 1.15
		trunk.mesh = t_cyl
		trunk.position = Vector3(0.0, 0.55, 0.0)
		trunk.material_override = trunk_mat
		tree.add_child(trunk)

		for puff_idx in range(2):
			var crown := MeshInstance3D.new()
			var c_sphere := SphereMesh.new()
			c_sphere.radius = (0.92 - float(puff_idx) * 0.24)
			c_sphere.height = c_sphere.radius * 1.75
			c_sphere.radial_segments = 16
			c_sphere.rings = 10
			crown.mesh = c_sphere
			crown.position = Vector3(0.0, 1.32 + float(puff_idx) * 0.62, 0.0)
			crown.material_override = _foliage_mat
			tree.add_child(crown)

		# Tiny decorative fruit / blossom dots on outer trees
		var dot := MeshInstance3D.new()
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = 0.13
		dot_mesh.height = 0.26
		dot.mesh = dot_mesh
		dot.position = Vector3(0.45, 1.42, 0.35)
		dot.material_override = _toy_mat(blossom_colors[i % blossom_colors.size()], 0.42, 0.0, 0.25)
		tree.add_child(dot)

func _build_indoor_surroundings(_room_id: String, bounds: Rect2) -> void:
	var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var max_span := maxf(bounds.size.x, bounds.size.y)

	# Warm sunlit tabletop mat beneath the miniature room box (like a storybook dollhouse on a cozy desk!)
	var desk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = max_span * 1.55 + 14.0
	cyl.bottom_radius = max_span * 1.60 + 14.5
	cyl.height = 0.40
	cyl.radial_segments = 48
	desk.mesh = cyl
	desk.position = center + Vector3(0.0, -0.98, 0.0)
	desk.material_override = _toy_mat(Color("e6d7be"), 0.66, 0.0, 0.14)
	desk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(desk)

	# Soft sage-cream woven table runner ring around the dollhouse plinth
	var runner := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(bounds.size.x + 5.2, 0.06, bounds.size.y + 5.2)
	runner.mesh = r_box
	runner.position = center + Vector3(0.0, -0.76, 0.0)
	runner.material_override = _toy_mat(Color("cfdec4"), 0.82, 0.0, 0.0)
	add_child(runner)

	# Potted miniature garden planters outside north/west/east edges so windows look out onto greenery
	var pot_mat := _toy_mat(Color("d4845a"), 0.55, 0.0, 0.15)
	var leaf_mat := _toy_mat(Color("6cb56d"), 0.58, 0.0, 0.15)
	var offsets := [
		Vector3(-bounds.size.x * 0.35, -0.72, -bounds.size.y * 0.5 - 1.6),
		Vector3(bounds.size.x * 0.32, -0.72, -bounds.size.y * 0.5 - 1.6),
		Vector3(-bounds.size.x * 0.5 - 1.6, -0.72, -bounds.size.y * 0.22),
		Vector3(bounds.size.x * 0.5 + 1.6, -0.72, -bounds.size.y * 0.22)
	]
	for p_offset: Vector3 in offsets:
		var planter := Node3D.new()
		planter.position = center + p_offset
		add_child(planter)
		var pot := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = 0.48
		p_cyl.bottom_radius = 0.36
		p_cyl.height = 0.52
		pot.mesh = p_cyl
		pot.position = Vector3(0.0, 0.26, 0.0)
		pot.material_override = pot_mat
		planter.add_child(pot)

		var bush := MeshInstance3D.new()
		var b_sph := SphereMesh.new()
		b_sph.radius = 0.62
		b_sph.height = 1.05
		bush.mesh = b_sph
		bush.position = Vector3(0.0, 0.78, 0.0)
		bush.material_override = leaf_mat
		planter.add_child(bush)

	# Warm golden interior fill OmniLight3D so indoor corners feel inviting and sunlit
	var cozy_bounce := OmniLight3D.new()
	cozy_bounce.name = "DioramaIndoorWarmBounce"
	cozy_bounce.position = center + Vector3(0.0, 3.4, 0.0)
	cozy_bounce.light_color = Color("ffefd2")
	cozy_bounce.light_energy = 0.42
	cozy_bounce.omni_range = max_span * 0.95 + 6.0
	cozy_bounce.omni_attenuation = 1.25
	cozy_bounce.shadow_enabled = false
	add_child(cozy_bounce)

func _build_drifting_clouds(bounds: Rect2, outdoor: bool) -> void:
	_clouds.clear()
	var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var span := maxf(bounds.size.x, bounds.size.y) * 0.9 + 14.0
	var cloud_mat := _toy_mat(Color("fffaf0"), 0.85, 0.0, 0.05)
	var count := 6 if outdoor else 3
	for i in range(count):
		var holder := Node3D.new()
		var z_off := -bounds.size.y * 0.5 - 6.5 - float(i % 3) * 4.2
		var x_off := (float(i) - float(count - 1) * 0.5) * 6.5
		var y_off := (4.8 + float(i % 2) * 1.4) if outdoor else (3.6 + float(i % 2) * 0.9)
		var base := center + Vector3(x_off, y_off, z_off)
		holder.position = base
		holder.set_meta("base_pos", base)
		holder.set_meta("speed", 0.22 + float(i % 3) * 0.08)
		holder.set_meta("span", span)
		add_child(holder)

		for puff in [Vector3(-0.65, 0.0, 0.0), Vector3(0.0, 0.24, 0.0), Vector3(0.68, -0.04, 0.0)]:
			var m := MeshInstance3D.new()
			var s := SphereMesh.new()
			var r := 0.72 if puff.y > 0.1 else 0.56
			s.radius = r
			s.height = r * 1.45
			s.radial_segments = 14
			s.rings = 8
			m.mesh = s
			m.position = puff
			m.material_override = cloud_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(m)
		_clouds.append(holder)

func _build_island_horizon_ring() -> void:
	# Expands the main island ocean horizon & adds distant storybook cloud puffs
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420.0, 420.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	sea.mesh = plane
	sea.position = Vector3(0.0, -0.58, 0.0)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WaterShader
	_water_mat.set_shader_parameter("shallow_color", Color(0.45, 0.84, 0.79, 0.90))
	_water_mat.set_shader_parameter("deep_color", Color(0.20, 0.58, 0.70, 0.96))
	_water_mat.set_shader_parameter("foam_distance", 0.85)
	sea.material_override = _water_mat
	add_child(sea)
	_build_drifting_clouds(Rect2(-48.0, -48.0, 96.0, 96.0), true)
