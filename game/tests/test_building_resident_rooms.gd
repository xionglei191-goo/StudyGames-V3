extends SceneTree
## Real room loading, host lookup, name labels and conversation routing.
const Residents = preload("res://actors/building_resident_catalog.gd")
const Art = preload("res://actors/character_art_v3.gd")
var game: Node3D
var checks: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var output := ""
var capture := false
var selected: Array[String] = []

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg.begins_with("--only="): selected.assign(arg.trim_prefix("--only=").split(","))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok: push_error("RESIDENT_ROOM "+label+" "+str(detail))

func _run() -> void:
	if output.is_empty(): output=ProjectSettings.globalize_path("res://../docs/verification/building-residents-v1")
	DirAccess.make_dir_recursive_absolute(output.path_join("rooms"))
	var protected := {}
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]:
		protected[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for frame: int in range(6000):
		await process_frame
		if game.scene_ready: break
	check(game.scene_ready,"main scene starts")
	if not game.scene_ready:
		quit(1)
		return
	game.muted=true
	game.ai_bridge.muted=true
	game.voice.stop()
	check(str(root.get_node("State").save_path).begins_with("user://validation-"),"isolated test save")
	for id: String in Residents.all():
		if not selected.is_empty() and not selected.has(id): continue
		var resident := Residents.profile(id)
		var room_id := str(resident.room_id)
		await game.change_room(room_id)
		for frame: int in range(4): await process_frame
		var hosts: Dictionary=game.world._resident_hosts
		check(hosts.size()==1,"one resident host "+room_id,hosts.size())
		if hosts.is_empty(): continue
		var host_id := str(hosts.keys()[0])
		var actor: Node3D=hosts[host_id]
		check(str(actor.character_id)==id,"correct model "+room_id,str(actor.character_id))
		check(str(actor.name_label.text)==str(resident.name),"correct name "+room_id,str(actor.name_label.text))
		var entries: Array=[]
		for entry: Dictionary in game.interactions:
			if entry.get("resident_id","")==id: entries.append(entry)
		check(entries.size()==1,"one identity-bound interaction "+room_id)
		if entries.is_empty(): continue
		check((entries[0].position as Vector3).distance_to(actor.global_position)<.01,"host remains at authored marker "+room_id)
		check(str(entries[0].label).contains(str(resident.name)),"interaction label names resident "+room_id)
		game.interact_id(host_id)
		await process_frame
		check(str(game.ui.current_panel)==id,"interaction opens resident dialogue "+room_id,str(game.ui.current_panel))
		var commission: Dictionary=game.CurriculumDirector.build_daily_commission(root.get_node("State"),id)
		check(str(commission.get("speaker","")).contains(str(resident.name)),"commission uses resident identity "+room_id,commission.get("speaker"))
		check(actor.current_action=="greet_wave","host greets on interaction "+room_id,str(actor.current_action))
		game._close()
		# Exercise the production diegetic branch while keeping the sidecar muted.
		game.validation_mode=false
		game.show_building_resident(id)
		check(str(game.ui.diegetic.current_npc_id)==id and game.ui.diegetic.visible,"production conversation identity "+room_id)
		check(str(game.ui.diegetic._speaker_badge.text).contains(str(resident.name)),"production speaker name "+room_id)
		game.validation_mode=true
		game._close()
		if capture:
			game.ui.visible=false
			var camera:=Camera3D.new()
			camera.projection=Camera3D.PROJECTION_ORTHOGONAL
			camera.size=6.2
			root.add_child(camera)
			camera.global_position=actor.global_position+Vector3(3.8,3.1,6.0)
			camera.look_at(actor.global_position+Vector3.UP*1.05)
			camera.current=true
			actor.play_action("idle")
			for frame: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("rooms").path_join(room_id+".png"))
			camera.queue_free()
			game.camera.current=true
			game.ui.visible=true
		rows.append({"id":id,"room":room_id,"host_interaction":host_id,"name":str(actor.name_label.text)})
		print("RESIDENT_ROOM_VALIDATED ",room_id)
	for path: String in protected:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing")==protected[path],"formal save unchanged "+path)
	var failed:=checks.filter(func(row: Dictionary) -> bool: return not row.passed)
	var report:={"status":"PASS" if failed.is_empty() else "FAIL","rooms":rows.size(),"checks":checks.size(),"failures":failed,"rows":rows,"native_capture":capture}
	var file:=FileAccess.open(output.path_join("rooms.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RESIDENT_ROOM_RESULT ",JSON.stringify({"status":report.status,"rooms":rows.size(),"checks":checks.size(),"failures":failed}))
	quit(0 if failed.is_empty() else 1)
