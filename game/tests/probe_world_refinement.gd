extends "res://tests/probe_refinement_ssao.gd"
## Frozen-frame diagnosis of thin island paving artifacts, no production mutation.
func probe_root() -> String:
	return "res://../docs/verification/world-refinement"
func probe_baseline_path() -> String:
	var batch := "01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-batch="): batch = arg.trim_prefix("--probe-batch=")
	return probe_root()+"/before/"+batch+"/report.json"
func probe_name() -> String:
	return probe_room()+"-shading-probe"
func probe_room() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-room="): return arg.trim_prefix("--probe-room=")
	return "village"
func probe_camera_id() -> String:
	return probe_room()+"-production"
func probe_variants() -> Array[Dictionary]:
	return [
		{"id":"current","enabled":true,"intensity":0.55},
		{"id":"no-ssao","enabled":false,"intensity":0.55},
		{"id":"no-shadows","enabled":true,"intensity":0.55,"shadow_enabled":false},
		{"id":"cascades","enabled":true,"intensity":0.55,"shadow_mode":DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS},
		{"id":"orthographic","enabled":true,"intensity":0.55,"shadow_mode":DirectionalLight3D.SHADOW_ORTHOGONAL},
		{"id":"normal-bias-2","enabled":true,"intensity":0.55,"shadow_normal_bias":2.0},
		{"id":"normal-bias-0.2","enabled":true,"intensity":0.55,"shadow_normal_bias":0.2}
	]
