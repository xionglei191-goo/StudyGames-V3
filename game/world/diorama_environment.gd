extends RefCounted
## Forward+ Toy Diorama lighting, ProceduralSky, AgX tonemapping, SSAO/SSIL, and soft shadows.
## Designed for the warm tactile miniature aesthetic (Link's Awakening / Animal Crossing).

const OUTDOOR_SCENES := [
	"village", "home_estate", "home_terrace", "home_greenhouse",
	"school", "playground", "football_field",
	"landmark_A", "landmark_B", "landmark_F", "landmark_G", "landmark_H",
	"landmark_I", "landmark_J", "landmark_K", "landmark_L", "landmark_M",
	"landmark_N", "landmark_O", "landmark_P", "landmark_Q", "landmark_R",
	"landmark_S", "landmark_T", "landmark_U", "landmark_V", "landmark_W",
	"landmark_X", "landmark_Y", "landmark_Z"
]

static func is_outdoor(room_id: String) -> bool:
	return room_id in OUTDOOR_SCENES

static func build_lighting(parent: Node3D, room_id: String) -> Dictionary:
	var outdoor := is_outdoor(room_id)
	var is_island := room_id == "village"

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7fc4e8") if outdoor else Color("a8cee0")
	sky_mat.sky_horizon_color = Color("f6ead4") if outdoor else Color("f7efe0")
	sky_mat.ground_horizon_color = Color("dce8d6") if outdoor else Color("e8dfd0")
	sky_mat.ground_bottom_color = Color("9fc2a4") if outdoor else Color("cbbba6")
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.62 if outdoor else 0.45
	env.ambient_light_color = Color("fff4e2")
	env.ambient_light_energy = 0.88 if outdoor else 0.95
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# AgX filmic tonemapping keeps pastel highlights creamy without clipping whites
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.04 if outdoor else 1.08
	env.tonemap_white = 5.8

	# Tactile miniature contact grounding via Forward+ SSAO & SSIL
	if DisplayServer.get_name() != "headless":
		env.ssao_enabled = true
		env.ssao_radius = 0.72 if not is_island else 1.05
		env.ssao_intensity = 1.45 if outdoor else 1.65
		env.ssao_power = 1.35
		env.ssao_detail = 0.5
		env.ssao_light_affect = 0.18

		env.ssil_enabled = true
		env.ssil_radius = 2.2
		env.ssil_intensity = 0.42

		env.glow_enabled = true
		env.glow_normalized = true
		env.glow_intensity = 0.20
		env.glow_strength = 0.85
		env.glow_bloom = 0.05
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		env.glow_hdr_threshold = 1.08

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.03
	env.adjustment_saturation = 1.08 if outdoor else 1.04

	# Gentle atmospheric aerial perspective on the main island
	if is_island:
		env.fog_enabled = true
		env.fog_light_color = Color("e8f2ec")
		env.fog_light_energy = 0.95
		env.fog_sun_scatter = 0.18
		env.fog_density = 0.0012
		env.fog_sky_affect = 0.14

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = env

	# Subtle miniature tabletop depth-of-field blur ONLY in the far distance
	if DisplayServer.get_name() != "headless":
		var cam_attr := CameraAttributesPractical.new()
		cam_attr.dof_blur_far_enabled = is_island
		cam_attr.dof_blur_far_distance = 62.0
		cam_attr.dof_blur_far_transition = 28.0
		cam_attr.dof_blur_amount = 0.035
		env_node.camera_attributes = cam_attr

	parent.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "DioramaSunLight"
	sun.rotation_degrees = Vector3(-50.0, -34.0, 0.0) if outdoor else Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff5e0")
	sun.light_energy = 0.82 if outdoor else 0.58
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.44 if outdoor else 0.36
	sun.shadow_blur = 1.45
	sun.directional_shadow_max_distance = 82.0 if is_island else 48.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.15
	parent.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "DioramaSkyBounceFill"
	fill.rotation_degrees = Vector3(-36.0, 144.0, 0.0)
	fill.light_color = Color("dff0f5") if outdoor else Color("f7ead9")
	fill.light_energy = 0.24 if outdoor else 0.28
	fill.shadow_enabled = false
	parent.add_child(fill)

	# Preserve room-specific metadata (e.g. home_visual_revision & orthogonal courtyard shadow)
	preload("res://scripts/home_visual_refinement.gd").apply_lighting(room_id, env, sun, fill)

	# Re-assert rich Forward+ Toy Diorama lighting on top of legacy compatibility defaults
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.62 if outdoor else 0.45
	env.ambient_light_color = Color("fff4e2")
	env.ambient_light_energy = 0.88 if outdoor else 0.96
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05 if outdoor else 1.10
	env.adjustment_saturation = 1.08 if outdoor else 1.05
	env.adjustment_contrast = 1.03
	env.adjustment_brightness = 1.02
	if DisplayServer.get_name() != "headless":
		env.ssao_enabled = true
		env.ssao_radius = 0.72 if not is_island else 1.05
		env.ssao_intensity = 1.45 if outdoor else 1.65
	sun.light_color = Color("fff5e0")
	sun.light_energy = 0.86 if outdoor else 0.62
	sun.shadow_opacity = 0.44 if outdoor else 0.36
	sun.shadow_blur = 1.45
	fill.light_color = Color("dff0f5") if outdoor else Color("f7ead9")
	fill.light_energy = 0.24 if outdoor else 0.28

	return {
		"world_environment": env_node,
		"environment": env,
		"sky_material": sky_mat,
		"sun": sun,
		"fill": fill
	}

static func apply_dynamic_mood(
	env: Environment,
	sun: DirectionalLight3D,
	fill: DirectionalLight3D,
	room_id: String,
	weather: String,
	phase: String,
	blend: float
) -> void:
	if env == null:
		return
	var outdoor := is_outdoor(room_id)
	var sky_tops := {
		"dawn": Color("8fbbe0"),
		"day": Color("7cc3e8"),
		"dusk": Color("7b84b8"),
		"night": Color("2d4369")
	}
	var sky_horizons := {
		"dawn": Color("f9d7ba"),
		"day": Color("f6ecd8"),
		"dusk": Color("f4b496"),
		"night": Color("536d91")
	}
	var sun_colors := {
		"dawn": Color("ffd7ad"),
		"day": Color("fff5e0"),
		"dusk": Color("ffb98a"),
		"night": Color("b8cef0")
	}
	var sun_scales := {"dawn": 0.78, "day": 1.0, "dusk": 0.74, "night": 0.36}
	var amb_scales := {"dawn": 0.94, "day": 1.0, "dusk": 0.92, "night": 0.78}

	var top_col: Color = sky_tops.get(phase, sky_tops.day)
	var hor_col: Color = sky_horizons.get(phase, sky_horizons.day)
	var sun_col: Color = sun_colors.get(phase, sun_colors.day)
	var direct_scale := float(sun_scales.get(phase, 1.0))
	var ambient_scale := float(amb_scales.get(phase, 1.0))

	if weather in ["cloudy", "light_rain", "mist"]:
		top_col = top_col.lerp(Color("9eb8c2"), 0.42)
		hor_col = hor_col.lerp(Color("dce6e7"), 0.46)
		direct_scale *= 0.68 if weather == "cloudy" else 0.54

	if not outdoor:
		# Keep cozy indoor rooms warm and readable at all hours
		ambient_scale = maxf(ambient_scale, 0.92)
		direct_scale = maxf(direct_scale, 0.65)
		hor_col = hor_col.lerp(Color("f7efe0"), 0.45)

	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sm := env.sky.sky_material as ProceduralSkyMaterial
		sm.sky_top_color = sm.sky_top_color.lerp(top_col, blend)
		sm.sky_horizon_color = sm.sky_horizon_color.lerp(hor_col, blend)
		sm.ground_horizon_color = sm.ground_horizon_color.lerp(hor_col.darkened(0.06), blend)

	var bg_colors := {
		"dawn": Color("e3ddc9"),
		"day": Color("d5e2d6"),
		"dusk": Color("cfc4b8"),
		"night": Color("25364d")
	}
	var bg_target: Color = bg_colors.get(phase, bg_colors.day)
	env.background_color = env.background_color.lerp(bg_target, blend)

	env.ambient_light_energy = lerpf(env.ambient_light_energy, (0.88 if outdoor else 0.95) * ambient_scale, blend)

	var target_fog := 0.0055 if weather == "mist" and outdoor else 0.0020 if weather == "light_rain" and outdoor else (0.0010 if room_id == "village" else 0.0004 if outdoor else 0.0)
	var cur_fog := env.fog_density if env.fog_enabled else 0.0
	env.fog_density = lerpf(cur_fog, target_fog, blend)
	env.fog_enabled = env.fog_density > 0.0001
	env.fog_light_color = env.fog_light_color.lerp(hor_col, blend)

	if is_instance_valid(sun):
		sun.light_color = sun.light_color.lerp(sun_col, blend)
		var base_e := 0.82 if outdoor else 0.58
		sun.light_energy = lerpf(sun.light_energy, base_e * direct_scale, blend)
		var pitch := -32.0 if phase == "dawn" else -50.0 if phase == "day" else -28.0 if phase == "dusk" else -44.0
		sun.rotation_degrees.x = lerpf(sun.rotation_degrees.x, pitch, blend)

	if is_instance_valid(fill):
		var fill_target := Color("dff0f5") if phase != "night" else Color("9db4d4")
		if not outdoor:
			fill_target = Color("f7ead9")
		fill.light_color = fill.light_color.lerp(fill_target, blend)
