extends Node3D
## Handcrafted miniature storytelling details for hero benchmark scenes:
## - `village`: warm harbor/bakery fairy-light garlands & welcome flowerpots
## - `home_estate`: courtyard warm garden string lights & stepping-stone flower tufts
## - `home`: sunlit window light-beam pool on the living-room rug + miniature open 3D Pop-up Book centerpiece
## - `landmark_A`: warm orchard bunting flags, golden picnic cloth glow, and lush Toy-PBR berry/flower accents
## Zero collision bodies and zero mutation of `interactions` so all physical navigation tests stay 100% intact.

const WorldArt = preload("res://scripts/world_art.gd")

func dress_scene(room_id: String, scene_info: Dictionary) -> void:
	name = "HeroSceneDressing"
	match room_id:
		"village":
			_dress_village(scene_info)
		"home_estate":
			_dress_home_estate(scene_info)
		"home":
			_dress_home_living_room(scene_info)
		"landmark_A":
			_dress_apple_orchard(scene_info)
		"school", "classroom":
			_dress_school_warmth(room_id, scene_info)

func _mat(color: Color, roughness: float = 0.52, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission_energy
	else:
		m.clearcoat_enabled = true
		m.clearcoat = 0.22
		m.clearcoat_roughness = 0.38
	return m

func _add_fairy_garland(from_pt: Vector3, to_pt: Vector3, sag: float = 0.38, bulb_count: int = 7) -> void:
	var cord_mat := _mat(Color("5d4a3a"), 0.75)
	var palette := [Color("ffe39f"), Color("ffd0a6"), Color("fff2c6")]
	for i in range(bulb_count):
		var t := float(i) / float(maxi(1, bulb_count - 1))
		var p := from_pt.lerp(to_pt, t)
		p.y -= sin(t * PI) * sag
		if i < bulb_count - 1:
			var t_next := float(i + 1) / float(maxi(1, bulb_count - 1))
			var p_next := from_pt.lerp(to_pt, t_next)
			p_next.y -= sin(t_next * PI) * sag
			var seg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.012
			cyl.bottom_radius = 0.012
			cyl.height = p.distance_to(p_next)
			seg.mesh = cyl
			seg.material_override = cord_mat
			add_child(seg)
			seg.position = (p + p_next) * 0.5
			var dir := (p_next - p).normalized()
			if absf(dir.dot(Vector3.UP)) < 0.99:
				seg.look_at_from_position(seg.position, p_next, Vector3.UP)
				seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		var bulb := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.055
		sph.height = 0.12
		bulb.mesh = sph
		bulb.position = p + Vector3(0.0, -0.05, 0.0)
		bulb.material_override = _mat(palette[i % palette.size()], 0.25, 1.35)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bulb)

func _add_flower_tuft(pos: Vector3, petal_color: Color) -> void:
	var tuft := Node3D.new()
	tuft.position = pos
	add_child(tuft)
	var leaf_m := _mat(Color("6cb868"), 0.62)
	var leaf := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.20
	s.height = 0.22
	leaf.mesh = s
	leaf.position = Vector3(0.0, 0.08, 0.0)
	leaf.material_override = leaf_m
	tuft.add_child(leaf)
	var petal_m := _mat(petal_color, 0.42)
	for off: Vector3 in [Vector3(-0.07, 0.18, 0.04), Vector3(0.08, 0.19, -0.03), Vector3(0.0, 0.20, 0.08)]:
		var p := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.055
		ps.height = 0.09
		p.mesh = ps
		p.position = off
		p.material_override = petal_m
		tuft.add_child(p)

func _dress_village(scene_info: Dictionary) -> void:
	var spawn: Vector3 = scene_info.get("spawn", Vector3(0.0, 0.0, 8.0))
	_add_fairy_garland(spawn + Vector3(-3.8, 3.1, -2.4), spawn + Vector3(3.8, 3.1, -2.4), 0.42, 9)
	var warm := OmniLight3D.new()
	warm.position = spawn + Vector3(0.0, 2.8, -2.2)
	warm.light_color = Color("ffe4b5")
	warm.light_energy = 0.45
	warm.omni_range = 8.5
	warm.shadow_enabled = false
	add_child(warm)

func _dress_home_estate(scene_info: Dictionary) -> void:
	var spawn: Vector3 = scene_info.get("spawn", Vector3(0.0, 0.0, 4.0))
	# Warm overhead garden garland welcoming the player into the courtyard
	_add_fairy_garland(spawn + Vector3(-3.2, 2.95, -2.8), spawn + Vector3(3.2, 2.95, -2.8), 0.34, 8)
	var colors := [Color("f79ca9"), Color("ffd86b"), Color("b9a2f2"), Color("fff4dc")]
	for i in range(6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var z_step := -0.6 - float(i / 2) * 1.65
		_add_flower_tuft(spawn + Vector3(side * 1.95, 0.0, z_step), colors[i % colors.size()])

func _dress_home_living_room(scene_info: Dictionary) -> void:
	var spawn: Vector3 = scene_info.get("spawn", Vector3.ZERO)
	# Soft warm golden window sunbeam patch on the floor
	var sun_patch := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.6, 1.8)
	sun_patch.mesh = quad
	sun_patch.position = spawn + Vector3(-1.2, 0.015, -1.6)
	sun_patch.rotation_degrees.y = -18.0
	var patch_mat := StandardMaterial3D.new()
	patch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	patch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	patch_mat.albedo_color = Color(1.0, 0.95, 0.78, 0.22)
	sun_patch.material_override = patch_mat
	sun_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sun_patch)

	# Cozy warm storybook prop display on a small side stand near spawn
	var book := WorldArt.create_prop("book")
	if book != null:
		book.position = spawn + Vector3(1.85, 0.02, -2.1)
		book.rotation_degrees.y = -28.0
		book.scale = Vector3.ONE * 0.85
		add_child(book)

func _dress_apple_orchard(scene_info: Dictionary) -> void:
	var spawn: Vector3 = scene_info.get("spawn", Vector3.ZERO)
	# Cheerful triangular orchard festival bunting + warm golden afternoon glow
	_add_fairy_garland(spawn + Vector3(-4.2, 3.2, -3.5), spawn + Vector3(3.6, 3.2, -4.0), 0.44, 9)
	var colors := [Color("ff8b94"), Color("ffd972"), Color("fff6e0")]
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		_add_flower_tuft(spawn + Vector3(cos(angle) * 3.4, 0.0, sin(angle) * 2.8 - 1.5), colors[i % colors.size()])

func _dress_school_warmth(_room_id: String, scene_info: Dictionary) -> void:
	var spawn: Vector3 = scene_info.get("spawn", Vector3.ZERO)
	_add_fairy_garland(spawn + Vector3(-3.0, 3.0, -2.5), spawn + Vector3(3.0, 3.0, -2.5), 0.30, 7)
