extends "res://tests/probe_refinement_ssao.gd"
## AO disabled throughout so this isolates shadow noise from AO.

func probe_name() -> String:
	return "shadow-probe"

func probe_variants() -> Array[Dictionary]:
	return [
		{"id":"current-bias", "enabled":false, "intensity":1.15},
		{"id":"shadows-off", "enabled":false, "intensity":1.15, "shadow_enabled":false},
		{"id":"bias-0.1-normal-1.0", "enabled":false, "intensity":1.15, "shadow_bias":0.1, "shadow_normal_bias":1.0}
	]
