extends SceneTree
const Stage = preload("res://ui/party_stage.gd")
const Party = preload("res://scripts/party_progress.gd")
var checks: Array = []
var failures: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition: failures.append(label); print("FAIL ",label)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	var layout := Party.empty_layout()
	for index: int in Party.GUESTS.size(): layout.seats[Party.GUESTS[index]] = Party.SEATS[index]
	var stage := Stage.new()
	root.add_child(stage)
	stage.setup(layout)
	stage.size = Vector2(800,520)
	await process_frame
	var evidence: Array = stage.seated_evidence()
	check(evidence.size() == 4,"four_existing_authored_characters_seated")
	for row: Dictionary in evidence:
		check(float(row.thigh_forward) > 0.20 and float(row.thigh_vertical) < 0.10,"thigh_horizontal_"+row.guest)
		check(float(row.shin_down) > 0.20 and float(row.shin_horizontal) < 0.05,"shin_vertical_"+row.guest)
		check(float(row.pelvis_height)-float(row.seat_height) > 0.08 and float(row.pelvis_height)-float(row.seat_height) < 0.20,"pelvis_above_chair_"+row.guest)
		check(row.source == Stage.Art.revision(),"active_character_resource_reused_"+row.guest)
	stage.set_beat(0)
	stage._process(1.0)
	var animated: Array = stage.seated_evidence()
	check(animated == evidence,"wave_does_not_reset_seated_legs")
	stage.reduced_motion = true
	stage.set_beat(1)
	stage._process(1.2)
	check(stage.seated_evidence() == evidence,"reduced_motion_keeps_seated_legs")
	stage.paused = true
	var elapsed: float = stage.elapsed
	stage._process(10.0)
	check(stage.elapsed == elapsed,"paused_stage_stays_still")
	layout.seats.textbook_mingming = "seat_4"
	layout.seats.textbook_anne = "seat_1"
	stage.set_layout(layout)
	check(stage.actors.textbook_anne.get_parent().get_meta("seat") == "seat_1","swapped_actor_moves_to_selected_real_chair")
	var controller: Script = load("res://scripts/party_controller.gd")
	check(controller != null,"controller_compiles_with_project_autoload")
	var directory := ProjectSettings.globalize_path("res://../docs/verification/life-keepsakes/party")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory+"/stage-%d.json" % OS.get_process_id()
	var report := FileAccess.open(path,FileAccess.WRITE)
	if report == null: print("FAIL report_write"); quit(1); return
	report.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"seated_evidence":evidence,"scope":"Headless skeleton geometry only; visible chair contact and framing require the separate native screenshot review."},"  "))
	report.close()
	stage.queue_free()
	await process_frame
	print("PARTY_STAGE checks=",checks.size()," failures=",failures.size()," report=",path)
	quit(0 if failures.is_empty() else 1)
