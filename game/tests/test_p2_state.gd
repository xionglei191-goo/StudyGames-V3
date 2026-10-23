extends SceneTree
const Journey = preload("res://scripts/journey_progress.gd")
const Progress = preload("res://scripts/p2_progress.gd")
var checks: Array = []
var failures: Array = []
var now := 1000.0
var report_dir := "res://../docs/verification/p2"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): report_dir = argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var journey := Journey.fresh()
	_check(Journey.normalize(journey).ok,"fresh_normalizes")
	var old := journey.duplicate(true)
	old.erase("p2")
	_check(Journey.normalize(old).ok and Journey.normalize(old).value.p2.letters.size()==26,"pre_p2_save_migrates_without_reset")
	_check(not _event(journey,{"kind":"home_choice","choice":"flowers"}).ok,"home_choice_requires_greeting")
	Journey.complete_home_step(journey,"H01")
	_check(_event(journey,{"kind":"home_choice","choice":"flowers"}).ok and journey.home_steps==["H01","H02"],"home_choice_commits_without_spend")
	Journey.complete_home_step(journey,"H03")
	Journey.complete_home_step(journey,"H04")
	for letter: String in Progress.LETTERS:
		_check(not _event(journey,{"kind":"letter_glyph","letter":letter,"room":"landmark_"+letter}).ok,"cannot_observe_unvisited/"+letter)
		Journey.record_letter(journey,letter,"landmark_"+letter,"visited","independent_action")
		var record: Dictionary = journey.p2.letters[letter]
		_event(journey,{"kind":"letter_help","letter":letter,"room":"landmark_"+letter,"level":3})
		_event(journey,{"kind":"letter_help","letter":letter,"room":"landmark_"+letter,"level":0})
		_check(record.help==3,"help_does_not_downgrade/"+letter)
		_event(journey,{"kind":"letter_glyph","letter":letter,"room":"landmark_"+letter})
		for index: int in Progress.content().letters[letter].operations.size():
			var operation := str(Progress.content().letters[letter].operations[index].id)
			var event := {"kind":"letter_action","letter":letter,"room":"landmark_"+letter,"expected_step":index,"operation":operation,"choice":1 if letter=="U" else 0,"placement":[0.4,0.6]}
			_check(_event(journey,event).ok,"actual_config_transition/"+letter+"/"+operation)
			var after := journey.duplicate(true)
			_check(_event(journey,event).ok and after==journey,"duplicate_action_idempotent/"+letter+"/"+operation)
			_check(Journey.normalize(journey).ok,"mid_action_roundtrip/"+letter+"/"+operation)
		for fact: String in Journey.LETTER_FACTS:
			Journey.record_letter(journey,letter,"landmark_"+letter,fact,"demonstration_viewed")
	_check(journey.p2.letters.X.receipts==["long","short"],"xylophone_requires_long_and_short")
	_check(journey.p2.letters.J.receipts==["open","close"],"jar_closes_after_open")
	_check(not _event(journey,{"kind":"letter_audio","letter":"A","room":"landmark_A","role":"letter","played":false}).ok,"no_playback_no_audio_evidence")
	for dimension: String in ["case_pair","landmark","letter_name"]:
		var context := "recall/A/"+dimension
		_event(journey,{"kind":"trial_begin","context":context,"room":"home"})
		var trial: Dictionary = journey.p2.trials[context]
		_event(journey,{"kind":"trial_answer","context":context,"trial_id":trial.id,"room":"home","answer":"__spoken__" if dimension=="letter_name" else "A"})
		_check(trial.completed and trial.mastery_awarded==false,"optional_recall_separate/"+dimension)
		_check(trial.result==("self_report_unassessed" if dimension=="letter_name" else "independent_correct"),"dimension_result/"+dimension)
	var bad := journey.duplicate(true)
	bad.p2.trials["recall/A/letter_name"].attempts[0].independent=true
	_check(not Journey.normalize(bad).ok,"forged_spoken_assessment_rejected")
	_boundary_checks(journey)
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(journey,step,{},now)
	_check(Journey.summary(journey).phase=="u2","u1_hands_off_to_u2")
	_event(journey,{"kind":"trial_begin","context":"U1-10","room":"landmark_F"})
	var transfer: Dictionary = journey.p2.trials["U1-10"]
	_event(journey,{"kind":"trial_answer","context":"U1-10","trial_id":transfer.id,"room":"landmark_F","answer":"thanks"})
	_event(journey,{"kind":"trial_answer","context":"U1-10","trial_id":transfer.id,"room":"landmark_F","answer":"hello"})
	_check(transfer.result=="supported_correct","retry_is_not_independent")
	_event(journey,{"kind":"u1_transfer","room":"landmark_F"})
	_check(journey.u1.step_details["U1-10"].delayed_recall_claimed==false,"same_day_transfer_not_claimed_delayed")
	var fractional := journey.duplicate(true)
	fractional.u1.steps.erase("U1-10")
	fractional.u1.step_details.erase("U1-10")
	_check(Progress.apply(fractional,{"kind":"u1_transfer","room":"landmark_F"},1792680000.123).ok and Journey.normalize(fractional).ok,"real_fractional_clock_and_old_receipt_normalize")
	for number: int in [2,3]:
		for step: Dictionary in Progress.content().chapters[str(number)].steps:
			_check(not _event(journey,{"kind":"chapter_step","chapter":number,"step":step.id,"room":"wrong_room"}).ok,"wrong_room_rejected/"+step.id)
			if step.kind=="question":
				_check(not _event(journey,{"kind":"chapter_step","chapter":number,"step":step.id,"room":step.room}).ok,"no_response_no_step/"+step.id)
				_event(journey,{"kind":"trial_begin","context":step.id,"room":step.room})
				var trial: Dictionary = journey.p2.trials[step.id]
				_event(journey,{"kind":"trial_help","context":step.id,"trial_id":trial.id,"room":step.room,"level":3})
				_event(journey,{"kind":"trial_answer","context":step.id,"trial_id":trial.id,"room":step.room,"answer":"__demonstrated__"})
			elif step.kind=="mail":
				_check(not _event(journey,{"kind":"mail","room":step.room,"recipient":"textbook_tim","mailbox":"textbook_lingling"}).ok,"wrong_mailbox_no_delivery")
				for actor: String in ["textbook_lingling","textbook_tim"]: _event(journey,{"kind":"mail","room":step.room,"recipient":actor,"mailbox":actor})
			elif step.kind=="seats":
				_event(journey,{"kind":"seats","room":step.room,"count":10})
				_check(not _event(journey,{"kind":"chapter_step","chapter":number,"step":step.id,"room":step.room}).ok,"age_ten_not_seat_count/"+step.id)
				_event(journey,{"kind":"seats","room":step.room,"count":step.seat_count})
			var event := {"kind":"chapter_step","chapter":number,"step":step.id,"room":step.room}
			_check(_event(journey,event).ok,"chapter_step/"+step.id)
			var saved := journey.duplicate(true)
			_check(_event(journey,event).ok and saved==journey,"chapter_step_idempotent/"+step.id)
			_check(Journey.normalize(journey).ok,"chapter_disk_shape/"+step.id)
	_check(Journey.summary(journey).phase=="p2_complete" and journey.reward_receipts.size()==2 and journey.p2.receipts.size()==2,"separate_four_chapter_photo_receipts")
	var state: Node = root.get_node("State")
	var production := "user://island-save-v1.json"
	var hash := FileAccess.get_sha256(production) if FileAccess.file_exists(production) else "missing"
	state.save_path="user://validation-p2-state-%d.json"%OS.get_process_id()
	state.data=state._default_state()
	state.data.journey=journey
	_check(state.save_state(),"real_disk_write")
	state.load_state()
	if state.journey_snapshot().phase!="p2_complete" or not _equivalent(state.data.journey.p2,journey.p2):
		var diagnostic := FileAccess.open(report_dir.path_join("state-roundtrip-debug.json"),FileAccess.WRITE)
		diagnostic.store_string(JSON.stringify({"expected":journey.p2,"actual":state.data.journey.p2,"phase":state.journey_snapshot().phase},"  "))
	_check(state.journey_snapshot().phase=="p2_complete" and _equivalent(state.data.journey.p2,journey.p2),"real_disk_restore")
	var fixture_photo := "user://welcome-photo-p2-state-%d.png"%OS.get_process_id()
	var fixture_image := Image.create(4,4,false,Image.FORMAT_RGBA8)
	fixture_image.fill(Color.WHITE)
	fixture_image.save_png(fixture_photo)
	var receipts_before: Dictionary = state.data.journey.reward_receipts.duplicate(true)
	_check(state.journey_p2_event({"kind":"photo_retake","path":fixture_photo,"frame":"blue"}),"retake_from_legacy_empty_photo_metadata")
	_check(state.data.journey.reward_receipts==receipts_before,"retake_preserves_original_receipts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_photo))
	var saved_data: Dictionary = state.snapshot()
	var blocker := "user://validation-p2-blocker-%d"%OS.get_process_id()
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("test")
	file.close()
	var save_path: String=state.save_path
	state.save_path=blocker+"/save.json"
	_check(not state.journey_p2_event({"kind":"home_choice","choice":"star"}) and state.data==saved_data,"failed_save_rolls_back_p2_and_old_state")
	state.save_path=save_path
	_check((FileAccess.get_sha256(production) if FileAccess.file_exists(production) else "missing")==hash,"official_save_untouched")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures}
	var report_file := FileAccess.open(report_dir.path_join("state-report.json"),FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"  "))
	print("P2_STATE checks=%d failures=%d"%[checks.size(),failures.size()])
	for path: String in [save_path,save_path+".bak",save_path+".tmp",blocker]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if failures.is_empty() else 1)

func _event(journey: Dictionary, event: Dictionary) -> Dictionary:
	now+=1.0
	return Progress.apply(journey,event,now)

func _boundary_checks(journey: Dictionary) -> void:
	_check(_event(journey,{"kind":"trip","letters":["A","M","Z"]}).ok,"three_stop_trip")
	_check(not _event(journey,{"kind":"trip","letters":["A","B","C","D"]}).ok,"four_stops_rejected")
	_check(not _event(journey,{"kind":"trip","letters":["A","A"]}).ok,"duplicate_stops_rejected")
	var context := "recall/B/case_pair"
	_event(journey,{"kind":"trial_begin","context":context,"room":"home"})
	var trial: Dictionary=journey.p2.trials[context]
	for i: int in 32: _event(journey,{"kind":"trial_answer","context":context,"trial_id":trial.id,"room":"home","answer":"I"})
	_check(trial.attempts.size()==32 and not trial.completed,"wrong_answer_attempt_limit_reached")
	_event(journey,{"kind":"trial_help","context":context,"trial_id":trial.id,"room":"home","level":3})
	_check(_event(journey,{"kind":"trial_answer","context":context,"trial_id":trial.id,"room":"home","answer":"__demonstrated__"}).ok and trial.completed,"demonstration_still_works_after_attempt_limit")
	_check(Journey.normalize(journey).ok,"bounded_final_demonstration_normalizes")
	var old_id: String=trial.id
	_event(journey,{"kind":"trial_begin","context":context,"room":"home","again":true})
	trial=journey.p2.trials[context]
	_check(not _event(journey,{"kind":"trial_answer","context":context,"trial_id":old_id,"room":"home","answer":"B"}).ok,"stale_trial_cannot_answer_new_round")
	_event(journey,{"kind":"trial_answer","context":context,"trial_id":trial.id,"room":"home","answer":"B"})
	_check(trial.result=="supported_correct","repeat_after_demo_not_independent")
	var invalid := journey.duplicate(true)
	invalid.p2.trial_sequence=0
	_check(not Journey.normalize(invalid).ok,"invalid_trial_sequence_rejected")
	invalid=journey.duplicate(true)
	invalid.p2.trials[context].room="wrong_room"
	_check(not Journey.normalize(invalid).ok,"invalid_trial_location_rejected")

func _equivalent(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float): return float(left)==float(right)
	if left is Dictionary and right is Dictionary:
		if left.size()!=right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _equivalent(left[key],right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size()!=right.size(): return false
		for index: int in left.size():
			if not _equivalent(left[index],right[index]): return false
		return true
	return left==right

func _check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition:
		failures.append(label)
		print("FAIL ",label)

