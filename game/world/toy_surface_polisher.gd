extends Node3D
## Non-destructively upgrades runtime materials across all 44 scenes into tactile Toy-PBR
## surfaces (glossy jelly water with shoreline foam, satin wood, soft plush textiles,
## warm foliage backlight, glowing evening lamps, and floating sunlit dust/pollen motes).

const DioramaEnv = preload("res://world/diorama_environment.gd")
const ToyWaterShader = preload("res://shaders/toy_water.gdshader")

var _animated_waters: Array[ShaderMaterial] = []
var _lamp_materials: Array[StandardMaterial3D] = []
var _lamp_lights: Array[OmniLight3D] = []
var _motes: GPUParticles3D
var _elapsed := 0.0
var reduced_motion := false

func polish_scene(scene_root: Node3D, room_id: String, scene_info: Dictionary) -> Dictionary:
	name = "ToySurfacePolisher"
	_animated_waters.clear()
	_lamp_materials.clear()
	_lamp_lights.clear()
	if not is_instance_valid(scene_root):
		return {"polished_materials": 0, "water_surfaces": 0}

	var seen_materials: Dictionary = {}
	var water_count := 0
	var lamp_count := 0

	for node: Node in scene_root.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.mesh == null or not inst.visible or inst.layers == 0:
			continue
		var label := str(inst.name)
		if label.begins_with("SG_"):
			continue
		var lower := label.to_lower()

		# Upgrade water planes/volumes with Forward+ shoreline-foam ToyWater shader
		if _is_water_mesh(label, lower):
			var wmat := ShaderMaterial.new()
			wmat.shader = ToyWaterShader
			var is_river := "river" in lower or "stream" in lower
			wmat.set_shader_parameter("flow_direction", Vector2(0.22, 1.0) if is_river else Vector2(0.65, 0.42))
			wmat.set_shader_parameter("foam_distance", 0.48 if is_river else 0.72)
			inst.material_override = wmat
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_animated_waters.append(wmat)
			water_count += 1
			continue

		var surface_count := inst.mesh.get_surface_count()
		for s in range(surface_count):
			var mat := inst.get_active_material(s)
			if mat is BaseMaterial3D:
				var base := mat as BaseMaterial3D
				var key := "%d:%s" % [base.get_instance_id(), _surface_category(lower)]
				if not seen_materials.has(key):
					var upgraded := base.duplicate() as BaseMaterial3D
					_tune_toy_pbr(upgraded, lower)
					seen_materials[key] = upgraded
				var applied := seen_materials[key] as BaseMaterial3D
				inst.set_surface_override_material(s, applied)
				if applied is StandardMaterial3D and _is_lamp_mesh(lower) and lamp_count < 8:
					if not _lamp_materials.has(applied):
						_lamp_materials.append(applied as StandardMaterial3D)
					if inst.get_node_or_null("ToyLampGlow") == null:
						var glow := OmniLight3D.new()
						glow.name = "ToyLampGlow"
						glow.light_color = Color("ffdca6")
						glow.light_energy = 0.36
						glow.omni_range = 3.8
						glow.shadow_enabled = false
						glow.position = inst.get_aabb().get_center()
						inst.add_child(glow)
						_lamp_lights.append(glow)
						lamp_count += 1

	_spawn_sunlit_motes(room_id, scene_info)
	return {
		"polished_materials": seen_materials.size(),
		"water_surfaces": water_count,
		"warm_lamps": lamp_count
	}

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_elapsed += delta
	for wmat: ShaderMaterial in _animated_waters:
		if is_instance_valid(wmat):
			wmat.set_shader_parameter("world_time", _elapsed)

func set_day_phase(phase: String) -> void:
	var night_factor := 1.0 if phase == "night" else 0.65 if phase in ["dawn", "dusk"] else 0.22
	for mat: StandardMaterial3D in _lamp_materials:
		if is_instance_valid(mat):
			mat.emission_enabled = true
			mat.emission = Color("ffda9e")
			mat.emission_energy_multiplier = 0.35 + night_factor * 1.15
	for light: OmniLight3D in _lamp_lights:
		if is_instance_valid(light):
			light.light_energy = 0.22 + night_factor * 0.72
	if is_instance_valid(_motes):
		_motes.emitting = not reduced_motion and phase != "night"

func _is_water_mesh(label: String, lower: String) -> bool:
	if label in ["ALPHA_River_Water", "ALPHA_V3_Lake_Deep_To_Shallow", "ALPHA_Ocean_Presentation", "Harbour_Water", "A_Wash_Water"]:
		return true
	return ("water" in lower or "ocean" in lower or "pond" in lower or "lake_surface" in lower) and not ("watering" in lower or "bottle" in lower or "cup" in lower or "bucket" in lower)

func _is_lamp_mesh(lower: String) -> bool:
	return ("lamp" in lower or "lantern" in lower or "sconce" in lower or "light_bulb" in lower or "chandelier" in lower) and not ("post" in lower or "stand" in lower or "cord" in lower)

func _surface_category(lower: String) -> String:
	if _is_lamp_mesh(lower):
		return "lamp"
	if "leaf" in lower or "foliage" in lower or "canopy" in lower or "crown" in lower or "bush" in lower or "hedge" in lower or "grass" in lower or "vine" in lower:
		return "foliage"
	if "wood" in lower or "plank" in lower or "desk" in lower or "table" in lower or "shelf" in lower or "cabinet" in lower or "chair" in lower or "floor" in lower or "trunk" in lower or "bridge" in lower:
		return "wood"
	if "rug" in lower or "carpet" in lower or "sofa" in lower or "bed" in lower or "pillow" in lower or "cushion" in lower or "curtain" in lower or "cloth" in lower:
		return "fabric"
	if "apple" in lower or "fruit" in lower or "cake" in lower or "berry" in lower or "ceramic" in lower or "plate" in lower or "teapot" in lower or "roof" in lower:
		return "glossy_toy"
	return "matte_toy"

func _tune_toy_pbr(mat: BaseMaterial3D, lower: String) -> void:
	var cat := _surface_category(lower)
	match cat:
		"foliage":
			mat.roughness = clampf(mat.roughness, 0.52, 0.74)
			mat.metallic_specular = 0.28
			mat.backlight_enabled = true
			mat.backlight = Color(0.72, 0.88, 0.48) * 0.30
		"wood":
			mat.roughness = clampf(mat.roughness * 0.82, 0.42, 0.68)
			mat.metallic_specular = 0.44
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				sm.clearcoat_enabled = true
				sm.clearcoat = 0.18
				sm.clearcoat_roughness = 0.42
		"fabric":
			mat.roughness = clampf(mat.roughness, 0.76, 0.92)
			mat.metallic_specular = 0.18
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				sm.rim_enabled = true
				sm.rim = 0.32
				sm.rim_tint = 0.65
		"glossy_toy":
			mat.roughness = clampf(mat.roughness * 0.72, 0.26, 0.54)
			mat.metallic_specular = 0.58
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				sm.clearcoat_enabled = true
				sm.clearcoat = 0.30
				sm.clearcoat_roughness = 0.25
		"lamp":
			mat.roughness = 0.35
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				sm.emission_enabled = true
				sm.emission = Color("ffe0a8")
				sm.emission_energy_multiplier = 0.55
		_:
			# Toy ceramic / painted plaster feel: never chalky 1.0 roughness
			mat.roughness = clampf(mat.roughness * 0.88, 0.46, 0.78)
			mat.metallic_specular = maxf(mat.metallic_specular, 0.34)

func _spawn_sunlit_motes(room_id: String, scene_info: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var bounds: Rect2 = scene_info.get("scene_bounds", Rect2(-12.0, -12.0, 24.0, 24.0))
	var center := Vector3(bounds.get_center().x, 2.2, bounds.get_center().y)
	if room_id == "village":
		center = Vector3(0.0, 2.6, 8.0)
		bounds = Rect2(-26.0, -18.0, 52.0, 52.0)

	_motes = GPUParticles3D.new()
	_motes.name = "SunlitCozyMotes"
	_motes.amount = 36 if room_id != "village" else 64
	_motes.lifetime = 6.5
	_motes.preprocess = 2.0
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.position = center

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(minf(bounds.size.x * 0.45, 22.0), 2.2, minf(bounds.size.y * 0.45, 22.0))
	proc.gravity = Vector3(0.02, 0.03, 0.01)
	proc.initial_velocity_min = 0.05
	proc.initial_velocity_max = 0.16
	proc.scale_min = 0.65
	proc.scale_max = 1.25
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 0.25
	proc.turbulence_noise_scale = 2.5
	_motes.process_material = proc

	var quad := SphereMesh.new()
	quad.radius = 0.028
	quad.height = 0.056
	quad.radial_segments = 6
	quad.rings = 4
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.albedo_color = Color(1.0, 0.96, 0.80, 0.58 if DioramaEnv.is_outdoor(room_id) else 0.38)
	quad.material = qmat
	_motes.draw_pass_1 = quad
	add_child(_motes)
