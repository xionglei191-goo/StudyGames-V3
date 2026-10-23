extends SceneTree
## Anatomical greeting regression on production actor playback, including
## interruptions which must release the wrist before semantic hand contacts.
const Actor = preload("res://scripts/textbook_actor.gd")
const Art = preload("res://actors/character_art_v3.gd")
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(60).timeout.connect(func(): printerr("WAVE_REFINEMENT_TIMEOUT"); quit(2))
	Art.use_manifest("res://assets/characters/tripo_v1/manifest.json")
	root.get_node("State").save_path = "user://validation-tripo-wave-%d.json" % OS.get_process_id()
	var gestures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Art.GESTURE_PATH))
	for id: String in Actor.PROFILES:
		var actor := Actor.new()
		actor.configure(id)
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		await process_frame
		var hand := actor.skeleton.find_bone("Hand_R")
		var elbow := actor.skeleton.find_bone("LowerArm_R")
		var normal_array: Array = gestures.characters[id].palm_rest_normal
		var palm_normal := Vector3(normal_array[0],normal_array[1],normal_array[2])
		var finger := (actor.skeleton.get_bone_global_rest(elbow).origin+Art.hand_socket(id,"R")-Vector3(0,0,.035)-actor.skeleton.get_bone_global_rest(hand).origin).normalized()
		for reduced: bool in [false,true]:
			actor.set_clock_state(true,true,false,reduced)
			# Each complete greeting starts empty-handed. The separate interruption
			# cases below intentionally exercise take/carry state transitions.
			actor.play_action("idle")
			actor.play_action("wave")
			var front_min := 1.0
			var straight_min := 1.0
			var consecutive_max := 0.0
			var jump_frame := -1
			var previous := actor.skeleton.get_bone_global_pose(hand).basis.get_rotation_quaternion()
			for frame: int in range(132):
				actor.advance_visual(1.0/60.0)
				var hand_pose := actor.skeleton.get_bone_global_pose(hand)
				var rotation := hand_pose.basis.get_rotation_quaternion()
				if previous.angle_to(rotation) > consecutive_max:
					consecutive_max = previous.angle_to(rotation)
					jump_frame = frame
				previous = rotation
				if frame >= 39 and frame <= 86:
					var forearm := (hand_pose.origin-actor.skeleton.get_bone_global_pose(elbow).origin).normalized()
					front_min = minf(front_min,(hand_pose.basis*palm_normal).normalized().dot(Vector3.BACK))
					straight_min = minf(straight_min,(hand_pose.basis*finger).normalized().dot(forearm))
			var row := {"id":id,"reduced":reduced,"palm_front_min_dot":front_min,"wrist_forearm_min_dot":straight_min,"maximum_frame_rotation_degrees":rad_to_deg(consecutive_max),"maximum_rotation_frame":jump_frame}
			measurements.append(row)
			_check(front_min>.70,"palm faces outward throughout the greeting: "+id+str(reduced),row)
			_check(straight_min>.85,"wrist follows the forearm without folding backward: "+id+str(reduced),row)
			_check(consecutive_max<deg_to_rad(16),"greeting has no sudden palm flip: "+id+str(reduced),row)
			for next_action: String in ["idle","give","take","carry","talk","point"]:
				actor.play_action("wave")
				for frame: int in range(48): actor.advance_visual(1.0/60.0)
				actor.play_action(next_action)
				actor.advance_visual(.08)
				_check(actor.skeleton.get_bone_pose_rotation(hand).angle_to(Quaternion.IDENTITY)<.001,"interrupted wave releases wrist for "+next_action+": "+id+str(reduced))
		actor.queue_free()
		await process_frame
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"measurements":measurements,"check_details":checks,"gesture_sha256":FileAccess.get_sha256(Art.GESTURE_PATH),"scope":"11 production NPCs in normal and reduced motion; palm orientation, wrist alignment, frame continuity and six interrupted-action transitions. Visual mesh acceptance uses separate native captures."}
	var output := FileAccess.open("res://../docs/verification/tripo-wave-refinement/wave-regression.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print("TRIPO_WAVE_REGRESSION "+JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	if not passed:
		failures.append(label)
		push_error(label)
