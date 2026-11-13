extends RefCounted
## V4 Modular Wardrobe & 3D Toy-PBR Accessory Builder.
## Supports 6 cozy storybook outfit palettes, 5 3D headwear accessories,
## 4 3D back accessories, and 3D CarrySocket hand-held items with bilingual tags.

const WorldArt = preload("res://scripts/world_art.gd")

const OUTFIT_CATALOG: Array[Dictionary] = [
	{"id": "yellow", "zh": "晨光柠檬背带装", "en": "yellow overalls", "word": "yellow", "color": Color("e6b946"), "swatch": "#e6b946"},
	{"id": "pink", "zh": "蜜桃草莓套装", "en": "pink outfit", "word": "pink", "color": Color("e2859b"), "swatch": "#e2859b"},
	{"id": "blue", "zh": "海风晴空水手装", "en": "blue outfit", "word": "blue", "color": Color("6da9cb"), "swatch": "#6da9cb"},
	{"id": "mint", "zh": "薄荷森林园艺装", "en": "green garden outfit", "word": "green", "color": Color("72bf9a"), "swatch": "#72bf9a"},
	{"id": "lavender", "zh": "星光薰衣草礼服", "en": "purple star outfit", "word": "star", "color": Color("9d8cd9"), "swatch": "#9d8cd9"},
	{"id": "caramel", "zh": "奶油焦糖烘焙装", "en": "warm brown apron", "word": "cake", "color": Color("cc9162"), "swatch": "#cc9162"},
]

const HAT_CATALOG: Array[Dictionary] = [
	{"id": "none", "zh": "自然清爽发型", "en": "natural hair", "word": "hair", "swatch": "#e8dfd1"},
	{"id": "straw_hat", "zh": "田园丝带草帽", "en": "straw hat", "word": "hat", "swatch": "#ebca78"},
	{"id": "ribbon_bow", "zh": "蜜桃蝴蝶结发箍", "en": "pink ribbon", "word": "red", "swatch": "#f08ca2"},
	{"id": "star_beret", "zh": "摘星画家贝雷帽", "en": "star beret", "word": "star", "swatch": "#9d8cd9"},
	{"id": "bunny_ears", "zh": "暖绒小兔发箍", "en": "rabbit ears", "word": "rabbit", "swatch": "#fff4e6"},
]

const BAG_CATALOG: Array[Dictionary] = [
	{"id": "none", "zh": "轻装漫步", "en": "hands free", "word": "walk", "swatch": "#e8dfd1"},
	{"id": "school_pack", "zh": "元气向日葵书包", "en": "school bag", "word": "bag", "swatch": "#ebb84b"},
	{"id": "picnic_basket", "zh": "藤编野餐花篮", "en": "picnic basket", "word": "apple", "swatch": "#c78e54"},
	{"id": "star_wings", "zh": "星光童话小翅膀", "en": "fairy wings", "word": "star", "swatch": "#d8ecff"},
]

static func outfit_color(id: String) -> Color:
	for item: Dictionary in OUTFIT_CATALOG:
		if str(item.id) == id:
			return item.color as Color
	return Color("e6b946")

static func outfit_info(id: String) -> Dictionary:
	for item: Dictionary in OUTFIT_CATALOG:
		if str(item.id) == id:
			return item
	return OUTFIT_CATALOG[0]

static func hat_info(id: String) -> Dictionary:
	for item: Dictionary in HAT_CATALOG:
		if str(item.id) == id:
			return item
	return HAT_CATALOG[0]

static func bag_info(id: String) -> Dictionary:
	for item: Dictionary in BAG_CATALOG:
		if str(item.id) == id:
			return item
	return BAG_CATALOG[0]

static func valid_hat(id: String) -> bool:
	for item: Dictionary in HAT_CATALOG:
		if str(item.id) == id:
			return true
	return false

static func valid_bag(id: String) -> bool:
	for item: Dictionary in BAG_CATALOG:
		if str(item.id) == id:
			return true
	return false

static func _toy_mat(color: Color, roughness: float = 0.48, clearcoat: float = 0.25, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = roughness
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if clearcoat > 0.01:
		mat.clearcoat_enabled = true
		mat.clearcoat = clearcoat
		mat.clearcoat_roughness = 0.32
	return mat

static func build_hat_mesh(hat_id: String) -> Node3D:
	if hat_id == "none" or hat_id.is_empty():
		return null
	var imported := preload("res://actors/tripo_prop_library.gd").create(hat_id,"hat")
	if imported != null: return imported
	var root := Node3D.new()
	root.name = "WardrobeHat_" + hat_id
	match hat_id:
		"straw_hat":
			var straw := _toy_mat(Color("efd084"), 0.62, 0.14)
			var ribbon := _toy_mat(Color("e87888"), 0.44, 0.28)
			var brim := MeshInstance3D.new()
			var b_cyl := CylinderMesh.new()
			b_cyl.top_radius = 0.34
			b_cyl.bottom_radius = 0.36
			b_cyl.height = 0.028
			b_cyl.radial_segments = 24
			brim.mesh = b_cyl
			brim.material_override = straw
			root.add_child(brim)

			var crown := MeshInstance3D.new()
			var c_cyl := CylinderMesh.new()
			c_cyl.top_radius = 0.19
			c_cyl.bottom_radius = 0.22
			c_cyl.height = 0.13
			c_cyl.radial_segments = 24
			crown.mesh = c_cyl
			crown.position = Vector3(0.0, 0.072, 0.0)
			crown.material_override = straw
			root.add_child(crown)

			var band := MeshInstance3D.new()
			var band_cyl := CylinderMesh.new()
			band_cyl.top_radius = 0.224
			band_cyl.bottom_radius = 0.226
			band_cyl.height = 0.032
			band.mesh = band_cyl
			band.position = Vector3(0.0, 0.032, 0.0)
			band.material_override = ribbon
			root.add_child(band)
			root.rotation_degrees = Vector3(-8.0, 0.0, 4.0)

		"ribbon_bow":
			var pink := _toy_mat(Color("f2829b"), 0.38, 0.35)
			var cream := _toy_mat(Color("fff4df"), 0.45, 0.20)
			var knot := MeshInstance3D.new()
			var ks := SphereMesh.new()
			ks.radius = 0.055
			ks.height = 0.10
			knot.mesh = ks
			knot.position = Vector3(0.0, 0.04, 0.02)
			knot.material_override = cream
			root.add_child(knot)
			for side: float in [-1.0, 1.0]:
				var loop_m := MeshInstance3D.new()
				var ls := SphereMesh.new()
				ls.radius = 0.11
				ls.height = 0.16
				loop_m.mesh = ls
				loop_m.scale = Vector3(1.15, 0.72, 0.55)
				loop_m.position = Vector3(side * 0.11, 0.05, 0.02)
				loop_m.rotation_degrees.z = side * -16.0
				loop_m.material_override = pink
				root.add_child(loop_m)

		"star_beret":
			var plush := _toy_mat(Color("9d88db"), 0.68, 0.12)
			var gold := _toy_mat(Color("ffd966"), 0.28, 0.45)
			var dome := MeshInstance3D.new()
			var ds := SphereMesh.new()
			ds.radius = 0.25
			ds.height = 0.18
			ds.radial_segments = 24
			dome.mesh = ds
			dome.position = Vector3(0.03, 0.04, -0.01)
			dome.rotation_degrees = Vector3(-6.0, 0.0, -11.0)
			dome.material_override = plush
			root.add_child(dome)

			var pom := MeshInstance3D.new()
			var ps := SphereMesh.new()
			ps.radius = 0.042
			ps.height = 0.084
			pom.mesh = ps
			pom.position = Vector3(0.05, 0.13, -0.01)
			pom.material_override = gold
			root.add_child(pom)

			var badge := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.045
			bs.height = 0.03
			badge.mesh = bs
			badge.position = Vector3(-0.12, 0.04, 0.18)
			badge.material_override = gold
			root.add_child(badge)

		"bunny_ears":
			var fur := _toy_mat(Color("fff8ee"), 0.66, 0.10)
			var inner := _toy_mat(Color("f7a8b8"), 0.52, 0.15)
			for side: float in [-1.0, 1.0]:
				var ear := MeshInstance3D.new()
				var cap := CapsuleMesh.new()
				cap.radius = 0.055
				cap.height = 0.28
				ear.mesh = cap
				ear.scale = Vector3(1.0, 1.0, 0.55)
				ear.position = Vector3(side * 0.10, 0.13, 0.0)
				ear.rotation_degrees = Vector3(-4.0, 0.0, side * -10.0)
				ear.material_override = fur
				root.add_child(ear)

				var pad := MeshInstance3D.new()
				var pcap := CapsuleMesh.new()
				pcap.radius = 0.032
				pcap.height = 0.18
				pad.mesh = pcap
				pad.scale = Vector3(1.0, 1.0, 0.35)
				pad.position = Vector3(side * 0.10, 0.13, 0.022)
				pad.rotation_degrees = Vector3(-4.0, 0.0, side * -10.0)
				pad.material_override = inner
				root.add_child(pad)
	return root

static func build_bag_mesh(bag_id: String) -> Node3D:
	if bag_id == "none" or bag_id.is_empty():
		return null
	var imported := preload("res://actors/tripo_prop_library.gd").create(bag_id,"bag")
	if imported != null: return imported
	var root := Node3D.new()
	root.name = "WardrobeBag_" + bag_id
	match bag_id:
		"school_pack":
			var body_m := _toy_mat(Color("ebb646"), 0.46, 0.28)
			var flap_m := _toy_mat(Color("fff1d0"), 0.50, 0.22)
			var buckle_m := _toy_mat(Color("d98245"), 0.35, 0.35)
			var pack := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.28, 0.30, 0.15)
			pack.mesh = box
			pack.material_override = body_m
			root.add_child(pack)

			var flap := MeshInstance3D.new()
			var fbox := BoxMesh.new()
			fbox.size = Vector3(0.29, 0.11, 0.16)
			flap.mesh = fbox
			flap.position = Vector3(0.0, 0.10, 0.0)
			flap.material_override = flap_m
			root.add_child(flap)

			var buckle := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.032
			bs.height = 0.064
			buckle.mesh = bs
			buckle.position = Vector3(0.0, 0.03, -0.085)
			buckle.material_override = buckle_m
			root.add_child(buckle)

		"picnic_basket":
			var basket := WorldArt.create_prop("basket")
			if basket != null:
				basket.scale = Vector3.ONE * 0.36
				basket.position = Vector3(0.0, -0.14, -0.02)
				root.add_child(basket)
			else:
				var b_mesh := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.16
				cyl.bottom_radius = 0.12
				cyl.height = 0.22
				b_mesh.mesh = cyl
				b_mesh.material_override = _toy_mat(Color("c98f55"), 0.58, 0.15)
				root.add_child(b_mesh)

		"star_wings":
			var wing_mat := _toy_mat(Color("eef7ff"), 0.22, 0.55, 0.86)
			var gold_mat := _toy_mat(Color("ffe082"), 0.28, 0.45)
			for side: float in [-1.0, 1.0]:
				var upper := MeshInstance3D.new()
				var us := SphereMesh.new()
				us.radius = 0.18
				us.height = 0.28
				upper.mesh = us
				upper.scale = Vector3(1.15, 0.72, 0.18)
				upper.position = Vector3(side * 0.17, 0.08, -0.02)
				upper.rotation_degrees = Vector3(0.0, side * 18.0, side * 24.0)
				upper.material_override = wing_mat
				root.add_child(upper)

				var lower := MeshInstance3D.new()
				var ls := SphereMesh.new()
				ls.radius = 0.12
				ls.height = 0.20
				lower.mesh = ls
				lower.scale = Vector3(1.05, 0.68, 0.16)
				lower.position = Vector3(side * 0.13, -0.06, -0.02)
				lower.rotation_degrees = Vector3(0.0, side * 14.0, side * -18.0)
				lower.material_override = wing_mat
				root.add_child(lower)

			var gem := MeshInstance3D.new()
			var gs := SphereMesh.new()
			gs.radius = 0.042
			gs.height = 0.084
			gem.mesh = gs
			gem.position = Vector3(0.0, 0.04, -0.02)
			gem.material_override = gold_mat
			root.add_child(gem)
	return root

static func build_carried_prop(prop_id: String) -> Node3D:
	if prop_id.is_empty() or prop_id == "none":
		return null
	var imported := preload("res://actors/tripo_prop_library.gd").create(prop_id,"carry")
	if imported != null: return imported
	var holder := Node3D.new()
	holder.name = "CarriedProp_" + prop_id
	match prop_id:
		"apple":
			var a := WorldArt.create_prop("apple")
			if a != null:
				a.scale = Vector3.ONE * 0.45
				holder.add_child(a)
		"green_apple", "golden_apple":
			var a := WorldArt.create_prop("apple")
			if a != null:
				a.scale = Vector3.ONE * 0.45
				var tint := Color("8cd16b") if prop_id == "green_apple" else Color("ffd45e")
				for m: Node in a.find_children("*", "MeshInstance3D", true, false):
					(m as MeshInstance3D).material_override = _toy_mat(tint, 0.30, 0.40)
				holder.add_child(a)
		"cake", "bread":
			var c := WorldArt.create_prop("cake")
			if c != null:
				c.scale = Vector3.ONE * (0.42 if prop_id == "cake" else 0.36)
				holder.add_child(c)
		"book", "owl_book":
			var b := WorldArt.create_prop("book")
			if b != null:
				b.scale = Vector3.ONE * 0.48
				holder.add_child(b)
		"boat":
			var hull := MeshInstance3D.new()
			var hbox := BoxMesh.new()
			hbox.size = Vector3(0.28, 0.10, 0.16)
			hull.mesh = hbox
			hull.material_override = _toy_mat(Color("c9844c"), 0.52, 0.22)
			holder.add_child(hull)
			var sail := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.18, 0.22, 0.03)
			sail.mesh = prism
			sail.position = Vector3(0.0, 0.15, 0.0)
			sail.material_override = _toy_mat(Color("fff8eb"), 0.42, 0.25)
			holder.add_child(sail)
		"drum", "jar", "milk":
			var cyl_m := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.11
			cyl.bottom_radius = 0.11
			cyl.height = 0.20 if prop_id != "drum" else 0.15
			cyl_m.mesh = cyl
			var col := Color("e26a5a") if prop_id == "drum" else (Color("9ad7e8") if prop_id == "jar" else Color("fffaf2"))
			cyl_m.material_override = _toy_mat(col, 0.32, 0.42)
			holder.add_child(cyl_m)
			var lid := MeshInstance3D.new()
			var lcyl := CylinderMesh.new()
			lcyl.top_radius = 0.118
			lcyl.bottom_radius = 0.118
			lcyl.height = 0.035
			lid.mesh = lcyl
			lid.position = Vector3(0.0, 0.10, 0.0)
			lid.material_override = _toy_mat(Color("f4d36b") if prop_id != "milk" else Color("6da9cb"), 0.36, 0.35)
			holder.add_child(lid)
		"egg", "ball", "globe", "yarn":
			var sph_m := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.12
			sph.height = 0.27 if prop_id == "egg" else 0.24
			sph_m.mesh = sph
			var scol := Color("fff3dc") if prop_id == "egg" else (Color("5ca7d8") if prop_id == "globe" else (Color("f08ca2") if prop_id == "yarn" else Color("f79f46")))
			sph_m.material_override = _toy_mat(scol, 0.36, 0.38)
			holder.add_child(sph_m)
		"flower":
			var stem := MeshInstance3D.new()
			var scyl := CylinderMesh.new()
			scyl.top_radius = 0.02
			scyl.bottom_radius = 0.022
			scyl.height = 0.18
			stem.mesh = scyl
			stem.material_override = _toy_mat(Color("68ad62"), 0.50, 0.20)
			holder.add_child(stem)
			var bloom := MeshInstance3D.new()
			var bsph := SphereMesh.new()
			bsph.radius = 0.095
			bsph.height = 0.16
			bloom.mesh = bsph
			bloom.position = Vector3(0.0, 0.12, 0.0)
			bloom.material_override = _toy_mat(Color("f5829d"), 0.35, 0.35)
			holder.add_child(bloom)
		"hat":
			var h := build_hat_mesh("straw_hat")
			if h != null:
				h.scale = Vector3.ONE * 0.68
				holder.add_child(h)
		"ice_cream":
			var cone := MeshInstance3D.new()
			var ccyl := CylinderMesh.new()
			ccyl.top_radius = 0.085
			ccyl.bottom_radius = 0.015
			ccyl.height = 0.18
			cone.mesh = ccyl
			cone.material_override = _toy_mat(Color("dba265"), 0.55, 0.18)
			holder.add_child(cone)
			var scoop := MeshInstance3D.new()
			var ssph := SphereMesh.new()
			ssph.radius = 0.095
			ssph.height = 0.18
			scoop.mesh = ssph
			scoop.position = Vector3(0.0, 0.12, 0.0)
			scoop.material_override = _toy_mat(Color("ff9eb5"), 0.34, 0.35)
			holder.add_child(scoop)
		"kite", "quilt", "xylophone_bar":
			var tile := MeshInstance3D.new()
			var tbox := BoxMesh.new()
			tbox.size = Vector3(0.24, 0.04, 0.24 if prop_id != "xylophone_bar" else 0.11)
			tile.mesh = tbox
			if prop_id == "kite":
				tile.rotation_degrees.y = 45.0
			var kcol := Color("6ec2e8") if prop_id == "kite" else (Color("c297e0") if prop_id == "quilt" else Color("f2be54"))
			tile.material_override = _toy_mat(kcol, 0.38, 0.32)
			holder.add_child(tile)
		"lantern", "star", "volcano_gem":
			var gem_m := MeshInstance3D.new()
			var gmesh := SphereMesh.new()
			gmesh.radius = 0.115
			gmesh.height = 0.24
			gmesh.radial_segments = 8
			gmesh.rings = 4
			gem_m.mesh = gmesh
			var gcol := Color("ffd45e") if prop_id != "volcano_gem" else Color("eb6b56")
			var gmat := _toy_mat(gcol, 0.24, 0.50)
			gmat.emission_enabled = true
			gmat.emission = gcol
			gmat.emission_energy_multiplier = 0.35
			gem_m.material_override = gmat
			holder.add_child(gem_m)
		"mushroom", "umbrella":
			var stalk := MeshInstance3D.new()
			var mcyl := CylinderMesh.new()
			mcyl.top_radius = 0.035 if prop_id == "mushroom" else 0.015
			mcyl.bottom_radius = 0.045 if prop_id == "mushroom" else 0.015
			mcyl.height = 0.18
			stalk.mesh = mcyl
			stalk.material_override = _toy_mat(Color("fff5e4"), 0.50, 0.18)
			holder.add_child(stalk)
			var cap_m := MeshInstance3D.new()
			var csph := SphereMesh.new()
			csph.radius = 0.13
			csph.height = 0.13
			csph.is_hemisphere = true
			cap_m.mesh = csph
			cap_m.position = Vector3(0.0, 0.08, 0.0)
			cap_m.material_override = _toy_mat(Color("e35d52") if prop_id == "mushroom" else Color("63b4e8"), 0.35, 0.38)
			holder.add_child(cap_m)
		"pumpkin":
			var pm := MeshInstance3D.new()
			var psph := SphereMesh.new()
			psph.radius = 0.13
			psph.height = 0.20
			pm.mesh = psph
			pm.material_override = _toy_mat(Color("eb8634"), 0.38, 0.34)
			holder.add_child(pm)
		"robot", "train":
			var body_b := MeshInstance3D.new()
			var rbox := BoxMesh.new()
			rbox.size = Vector3(0.22, 0.18, 0.16) if prop_id == "robot" else Vector3(0.26, 0.14, 0.14)
			body_b.mesh = rbox
			body_b.material_override = _toy_mat(Color("7aa8d6") if prop_id == "robot" else Color("d95f52"), 0.34, 0.40)
			holder.add_child(body_b)
		"nest", "whale_shell":
			var tr := MeshInstance3D.new()
			var tmesh := TorusMesh.new()
			tmesh.inner_radius = 0.055
			tmesh.outer_radius = 0.125
			tr.mesh = tmesh
			tr.material_override = _toy_mat(Color("b58350") if prop_id == "nest" else Color("7bc7db"), 0.48, 0.26)
			holder.add_child(tr)
		_:
			var inv := WorldArt.create_prop("invitation")
			if inv != null:
				inv.scale = Vector3.ONE * 0.55
				holder.add_child(inv)
	return holder
