extends SceneTree
## Loads every lazily delivered interior from the exported main pack, not from source assets.
var checks: Array = []
var failures: Array = []
var build_dir := ""
var report_path := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, id: String) -> void:
	checks.append({"id":id,"passed":ok})
	if not ok:
		failures.append(id)
		push_error(id)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--web-build="): build_dir = arg.trim_prefix("--web-build=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	if build_dir.is_empty() or report_path.is_empty(): quit(2); return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(build_dir.path_join("build-info.json")))
	check(info.rooms.size() == 43, "43_room_packs")
	check(not ResourceLoader.exists("res://assets/interiors/home.glb"), "home_absent_from_initial_pack")
	check(ResourceLoader.exists("res://assets/world/island.glb"), "island_present_in_initial_pack")
	for room: String in info.rooms:
		var entry: Dictionary = info.rooms[room]
		var path := build_dir.path_join(str(entry.url))
		check(FileAccess.get_sha256(path) == str(entry.sha256), room+"_checksum")
		check(ProjectSettings.load_resource_pack(path, false), room+"_pack_loaded")
		var resource_path := "res://assets/interiors/%s.glb" % room
		check(ResourceLoader.exists(resource_path), room+"_resource_exists")
		var packed := ResourceLoader.load(resource_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		check(packed != null, room+"_scene_loads")
		if packed == null: continue
		var instance: Node3D = packed.instantiate()
		root.add_child(instance)
		check(instance.find_children("*", "MeshInstance3D", true, false).size() > 0, room+"_meshes_exist")
		instance.queue_free()
		await process_frame
		await process_frame
	var output := FileAccess.open(report_path, FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures, "engine":Engine.get_version_info().string}, "\t"))
		output.close()
	else:
		check(false, "report_written")
	print("WEB_PACKS checks=%d failures=%d" % [checks.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
