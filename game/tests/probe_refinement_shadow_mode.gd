extends "res://tests/probe_refinement_ssao.gd"
## Fixed native production camera; compares cascades with one orthogonal shadow map.

func probe_name() -> String:
	return "shadow-mode-probe"

func probe_room() -> String:
	return "home_estate"

func probe_camera_id() -> String:
	return "home_estate-production"

func probe_measures_performance() -> bool:
	return true

func probe_variants() -> Array[Dictionary]:
	return [
		{"id":"current-cascades", "enabled":true, "intensity":0.55},
		{"id":"orthogonal", "enabled":true, "intensity":0.55, "shadow_mode":DirectionalLight3D.SHADOW_ORTHOGONAL}
	]
