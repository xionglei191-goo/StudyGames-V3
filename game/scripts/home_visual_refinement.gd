extends RefCounted
## Shared lighting for the refined island and interiors. LivingWorld owns day/weather.
## Materials and silhouettes are edited in the versioned Blender source assets.

const REVISION := "world-visual-refinement-v1"
const OUTDOOR_ROOMS: Array[String] = ["village", "school", "playground", "football_field", "landmark_A", "landmark_B", "landmark_F", "home_estate", "home_balcony"]

static func apply_lighting(room: String, environment: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	var outdoor := room in OUTDOOR_ROOMS
	# A directional key, cooler fill and lower ambient reveal bevels and fabric folds.
	# Stay within the current Compatibility renderer and its existing hardware target.
	# Day/weather owns outdoor color; only the indoor baseline is softened here.
	if not outdoor:
		environment.ambient_light_color = Color("dfe8e8")
	environment.ambient_light_energy = 0.30 if outdoor else 0.27
	environment.adjustment_saturation = 0.94 if outdoor else 0.92
	environment.adjustment_contrast = 1.01
	environment.adjustment_brightness = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.65
	# Compatibility supports radius/intensity. Keep the contact shading restrained.
	environment.ssao_intensity = 0.55
	sun.light_energy = 0.42 if outdoor else 0.36
	sun.shadow_opacity = 0.55 if outdoor else 0.52
	# Smaller bias produced visible self-shadow speckling on the long flat floors.
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 100.0 if room == "village" else 58.0 if outdoor else 35.0
	# Only the courtyard's tested mesh layout uses one shadow region.
	# Broad island terrain needs cascades to avoid paving-edge artifacts.
	if room == "home_estate":
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	elif outdoor:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	fill.light_energy = 0.07 if outdoor else 0.08
	sun.set_meta("home_visual_revision", REVISION)
