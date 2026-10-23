extends SceneTree

func _initialize() -> void:
	var script: Script = load("res://scripts/world_builder.gd") as Script
	if script == null or not script.can_instantiate():
		quit(1)
		return
	print("WORLD_ART_SCRIPT_LOAD_OK")
	if "--build" in OS.get_cmdline_user_args() or "--preview" in OS.get_cmdline_user_args():
		_run_builds.call_deferred(script)
	else:
		quit(0)

func _run_builds(script: Script) -> void:
	var world: Node3D = script.new() as Node3D
	root.add_child(world)
	var rooms: Array[String] = ["village", "school", "classroom", "canteen", "playground", "home"]
	if "--preview" in OS.get_cmdline_user_args():
		rooms = ["village"]
	for room: String in rooms:
		var data: Dictionary = world.call("build", room)
		await process_frame
		var meshes: int = world.find_children("*", "MeshInstance3D", true, false).size()
		var colliders: int = world.find_children("*", "StaticBody3D", true, false).size()
		assert(data.has("spawn") and data.has("bounds") and data.has("interactions"))
		assert(meshes > 10 and colliders > 0)
		print("WORLD_ROOM_OK ", room, " meshes=", meshes, " colliders=", colliders, " interactions=", data.interactions.size())
		if room == "home":
			var decorations: Dictionary = world.get("_decorations")
			assert(decorations.size() == 3)
			for id: String in ["flower_box", "picnic", "lamp"]:
				world.call("set_decoration", id, true)
				for other_id: String in decorations:
					assert((decorations[other_id] as Node3D).visible == (id == other_id))
				world.call("set_decoration", id, false)
			print("WORLD_DECORATION_INDEPENDENCE_OK")
	if "--preview" in OS.get_cmdline_user_args():
		var player: Node3D = world.call("make_character", "player") as Node3D
		player.position = Vector3(0, 0, 5.3)
		root.add_child(player)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 28
		camera.position = Vector3(18, 25, 27)
		root.add_child(camera)
		camera.look_at(Vector3(0, 0.5, -1))
		camera.current = true
		root.size = Vector2i(1440, 900)
		for frame: int in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		var output_dir: String = ProjectSettings.globalize_path("res://../.local/art-previews")
		DirAccess.make_dir_recursive_absolute(output_dir)
		var preview_path: String = output_dir.path_join("village-%s.png" % int(Time.get_unix_time_from_system()))
		var error: Error = screenshot.save_png(preview_path)
		print("WORLD_PREVIEW_SAVED ", error, " ", preview_path)
	quit(0)
