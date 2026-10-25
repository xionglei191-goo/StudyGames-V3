extends "res://tests/test_school_hierarchy.gd"
## Physical island door -> all five loci -> physical return, for every letter room.
## Campus and household use their existing complete circulation/task suites.
var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
var world_finishing := false
var asset_hashes: Dictionary = {}

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--letters="): letters = arg.trim_prefix("--letters=")
	root.size = Vector2i(1440,900)
	_report_name = "world-refinement-" + letters + ".json"
	_report["coverage"] = "Real CharacterBody3D walking from island spawn through each requested letter door, all five room memory points and the matching return door. No teleportation or forced nearest interaction."
	_report["letters"] = letters
	_report["visited_rooms"] = []
	_report["memory_panels"] = []
	_report["actual_door_key_dispatch"] = true
	_protected_before = _production_signature()
	create_timer(1500).timeout.connect(func(): _check("tour_timeout",false); _finish())
	_main = load("res://main.tscn").instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	if not await _wait_for_room("village"):
		_check("initial_scene_ready",false)
		await _finish()
		return
	var state: Node = root.get_node("State")
	_check("save_isolation",str(state.save_path)=="user://validation-%d.json" % OS.get_process_id())
	if str(state.save_path)!="user://validation-%d.json" % OS.get_process_id():
		await _finish()
		return
	_main.muted=true
	_main.voice.stop()
	_main.sounds.enabled=false
	_main.ui.reduced_motion=true
	_main.application_backgrounded=false
	state.set_preference("effects",false)
	state.set_preference("reduced_motion",true)
	var learning_before: Dictionary = state.data.learning.duplicate(true)
	var units_before: Dictionary = state.data.completed_units.duplicate(true)
	asset_hashes["res://assets/world/island.glb"]=FileAccess.get_sha256("res://assets/world/island.glb")
	for letter: String in letters:
		var room_id := "landmark_" + letter
		var path := "res://assets/interiors/" + room_id + ".glb"
		asset_hashes[path]=FileAccess.get_sha256(path)
		if _main.room != "village":
			_check("island_before_door/"+room_id,false)
			break
		if not await _walk_to_entry(room_id,"island_to_letter") or not await _transition(room_id,room_id): continue
		_report.visited_rooms.append(room_id)
		for number: int in range(1,6):
			var id := "memory_%02d" % number
			if await _walk_to_entry(id,"five_fixed_loci"):
				await _open_memory(id)
				_report.memory_panels.append({"room":room_id,"id":id})
		if await _walk_to_entry("village_exit","return_to_own_island_door"):
			await _transition("village_exit","village")
	_check("all_requested_rooms_visited",_report.visited_rooms.size()==letters.length())
	_check("all_five_loci_opened",_report.memory_panels.size()==letters.length()*5)
	_check("tour_returns_to_island",_main.room=="village")
	_check("no_learning_grade_written",state.data.learning==learning_before and state.data.completed_units==units_before)
	await _finish()

func _transition(id: String, destination_room: String) -> bool:
	var origin: String = _main.room
	var entry := _entry(id)
	var selected := str(_main.nearest.get("id",""))==id
	_check("door_selected/"+origin+"/"+id,selected)
	if not selected: return false
	var event := InputEventKey.new()
	event.physical_keycode=KEY_E
	event.keycode=KEY_E
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new()
	event.physical_keycode=KEY_E
	event.keycode=KEY_E
	event.pressed=false
	Input.parse_input_event(event)
	var ok := await _wait_for_room(destination_room)
	var record := {"from":origin,"to":destination_room,"interaction":id,"input":"physical_E_key","passed":ok}
	if ok and destination_room=="village":
		var target := _entry(str(entry.get("return_id",origin)))
		var distance := _distance_xz(_main.player.position,target.get("return_position",target.get("position",Vector3(INF,INF,INF))))
		record["return_distance"]=distance
		_check("matching_return_door/"+origin,not target.is_empty() and distance<=2.0)
	_report.transitions.append(record)
	_check("transition/"+origin+"/"+id,ok)
	return ok

func _finish() -> void:
	if world_finishing: return
	world_finishing=true
	for path: String in asset_hashes:
		_check("runtime_asset_stable/"+path,FileAccess.get_sha256(path)==asset_hashes[path])
	_check("production_save_unchanged",_production_signature()==_protected_before)
	_report["source_sha256"]=asset_hashes
	_report["passed"]=_report.failures.is_empty()
	_report["complete"]=true
	_report["actual_physics_movement"]=true
	_report["production_save_unchanged"]=_production_signature()==_protected_before
	_report["engine"]=Engine.get_version_info()["string"]
	var folder := ProjectSettings.globalize_path("res://../docs/verification/world-refinement")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join(_report_name),FileAccess.WRITE)
	file.store_string(JSON.stringify(_report,"  "))
	file.close()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
	var save := "user://validation-%d.json" % OS.get_process_id()
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
	print("WORLD_REFINEMENT_TOUR "+JSON.stringify({"letters":letters,"checks":_report.checks.size(),"routes":_report.routes.size(),"transitions":_report.transitions.size(),"failures":_report.failures}))
	quit(0 if _report.failures.is_empty() else 1)
