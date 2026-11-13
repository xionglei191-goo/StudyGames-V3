extends SceneTree
## Load the formal main scene and exercise its actual actor registry.
const Art = preload("res://actors/character_art_v3.gd")
var checks: Array[Dictionary] = []
var output := ""
var capture := false

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"passed": value, "check": label})
	if not value: push_error("EXPANSION_WORLD " + label)

func _run() -> void:
	if output.is_empty(): output = "res://../docs/verification/textbook-expansion-v1/world"
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var protected := {}
	for path: String in ["user://island-save-v1.json", "user://island-save-v1.json.bak"]:
		protected[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame: int in range(6000):
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready, "formal main scene starts")
	if not game.scene_ready:
		quit(1)
		return
	game.muted = true
	game.ai_bridge.muted = true
	game.voice.stop()
	check(str(root.get_node("State").save_path).begins_with("user://validation-"), "isolated test save")
	if str(game.room) != "village": await game.change_room("village")
	for frame: int in range(5): await process_frame
	await physics_frame
	await physics_frame
	game.ui.visible = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.current = true
	var rows: Array[Dictionary] = []
	var anchor := Vector3.ZERO
	var found := false
	# Use the game's floor and obstacle checks; a fixed offset can land inside
	# the authored fountain and would make the native screenshots unusable.
	for radius: float in [4.0, 5.5, 7.0]:
		for i: int in range(16):
			var angle := TAU*float(i)/16.0
			var candidate: Vector3 = game.player.global_position + Vector3(sin(angle),0,cos(angle))*radius
			var floor_hit: Dictionary = game.living._find_spawn_floor(candidate)
			if floor_hit.is_empty(): continue
			candidate = floor_hit.position as Vector3
			if not game.living._spawn_clear(candidate): continue
			anchor = candidate + Vector3.UP*.02
			found = true
			break
		if found: break
	check(found, "production floor and obstacle checks find a clear preview position")
	if not found:
		quit(1)
		return
	for id: String in Art.expansion_characters():
		var entry := Art.character_entry(id)
		var actor: Node3D = game.living.spawn_actor(id, anchor)
		check(actor != null, "world spawns " + id)
		if actor == null: continue
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.face(anchor + Vector3(0, 0, 3), true)
		check(game.living.get_actor(id) == actor, "world registry identity " + id)
		check(actor.display_name == str(entry.profile.name), "world display name " + id)
		var interaction: Dictionary = actor.get_interaction()
		check(str(interaction.character_id) == id and str(interaction.label).contains(actor.display_name), "world interaction identity " + id)
		for action: String in entry.allowed_actions:
			check(game.living.play_actor_action(id, action), "world action " + id + "/" + action)
		if entry.allowed_actions.has("carry_item"):
			actor.set_held_prop("bread")
			check(not actor.find_children("TripoProp_bread", "Node3D", true, false).is_empty(), "human hand attaches imported prop " + id)
			actor.set_held_prop("")
		else:
			check(not game.living.play_actor_action(id, "give_item"), "species rejects human hand action " + id)
		game.living.play_actor_action(id, "greet_wave")
		actor.animation_player.seek(.92, true, true)
		actor.skeleton.force_update_all_bone_transforms()
		var height := float(entry.height)
		camera.size = maxf(2.0, height * 1.8)
		camera.global_position = anchor + Vector3(height * 1.2, height * .95, height * 3)
		camera.look_at(anchor + Vector3.UP * height * .6)
		if capture:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(id + ".png"))
		rows.append({"id": id, "name": str(actor.display_name), "actions": entry.allowed_actions.size(), "room": "village"})
		game.living.remove_actor(id)
		await process_frame
		check(game.living.get_actor(id) == null, "world removes " + id)
	check(rows.size() == 40, "all 40 characters exercised in main scene")
	for path: String in protected:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == protected[path], "formal save unchanged " + path)
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row.passed)
	var report := {"status": "PASS" if failures.is_empty() else "FAIL", "characters": rows.size(), "checks": checks.size(), "failures": failures, "rows": rows, "native_capture": capture}
	var file := FileAccess.open(output.path_join("world.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("EXPANSION_WORLD_RESULT ", report.status, " ", checks.size(), " ", failures)
	quit(0 if failures.is_empty() else 1)
