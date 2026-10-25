extends SceneTree
const Review = preload("res://scripts/review_progress.gd")
const Observations = preload("res://scripts/parent_observations.gd")
const StateScript = preload("res://scripts/game_state.gd")
const Journey = preload("res://scripts/journey_progress.gd")
var checks: Array = []
var failures: Array = []
var now := 1800000000.0
var directory := "user://revisits-state-%d" % OS.get_process_id()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, id: String) -> void:
	checks.append({"id":id,"passed":ok})
	if not ok: failures.append(id); print("FAIL ",id)

func fixture(letters: String = "AB") -> Dictionary:
	var state := StateScript.new()
	var data := state._default_state()
	state.free()
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(data.journey,step)
	for letter: String in letters:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(data.journey,letter,"landmark_"+letter,fact,"independent_action")
	return data

func ready(letters: String = "AB", imported: bool = false) -> Dictionary:
	var data := fixture(letters)
	Review.tick(data.reviews,now)
	Review.sync(data,{} if imported else fixture(""),now)
	Review.refresh(data.reviews,now+Review.DAY+1)
	return data

func apply(review: Dictionary, id: String, kind: String, at: float, extra: Dictionary = {}) -> Dictionary:
	extra.id = id
	extra.kind = kind
	extra.room = Review.context(review.opportunities[id]).room
	return Review.apply(review,extra,at)

func run() -> void:
	create_timer(90.0).timeout.connect(func(): check(false,"test_timeout"); finish())
	check(Review.catalog().size()==62,"bounded_62_targets")
	for spec: Dictionary in Review.catalog().values():
		check(spec.contexts.size()==3,"three_contexts/"+spec.id)
		check(spec.dimension in ["letter_case_association","letter_landmark_association","written_situation_choice"],"legal_dimensions/"+spec.id)
		for context: Dictionary in spec.contexts:
			check(context.options.size()==3 and (context.options as Array).filter(func(x: Dictionary): return x.id==context.correct).size()==1,"one_valid_answer/"+spec.id+"/"+context.room)
	var initial := fixture("")
	Review.sync(initial,{},now)
	Review.refresh(initial.reviews,now+Review.DAY*20)
	check(initial.reviews.targets.is_empty() and initial.reviews.batch.ids.is_empty(),"new_save_has_no_invented_learning")
	var all := fixture(Journey.LETTERS)
	all.completed_units = {"1":true,"2":true,"3":true}
	Review.sync(all,{},now)
	check(all.reviews.targets.size()==62,"all_26_letters_and_3_units_unlock")
	check(all.reviews.targets.values().all(func(target: Dictionary): return target.last_exposure==-1 and target.imported_unknown),"legacy_times_stay_unknown")
	Review.refresh(all.reviews,now+Review.DAY+2)
	check(all.reviews.batch.ids.size()==2 and all.reviews.opportunities[all.reviews.batch.ids[0]].target.begins_with("letter/") and all.reviews.opportunities[all.reviews.batch.ids[1]].target.begins_with("unit/"),"mixed_outing_offers_letter_and_unit")
	var first := fixture("A")
	Review.sync(first,fixture(""),now)
	check(first.reviews.targets["letter/A/case"].last_exposure==now,"new_completion_records_real_time")
	Review.refresh(first.reviews,now+10)
	check(first.reviews.batch.ids.is_empty(),"no_immediate_repeat")
	var before := first.duplicate(true)
	first.day += 9
	Review.sync(first,before,now+120)
	Review.refresh(first.reviews,now+120)
	check(first.reviews.batch.ids.is_empty(),"game_sleep_is_not_real_time_or_separating_activity")
	before = first.duplicate(true)
	first.life.activities.music = true
	Review.sync(first,before,now+121)
	Review.refresh(first.reviews,now+121)
	check(first.reviews.batch.ids.size()==1,"distinct_life_activity_offers_one_same_session_invite")
	var id: String = first.reviews.batch.ids[0]
	apply(first.reviews,id,"begin",now+122)
	apply(first.reviews,id,"answer",now+123,{"answer":"A"})
	check(first.reviews.opportunities[id].result=="supported_correct","same_session_contact_not_delayed_independence")
	check(not first.reviews.opportunities[id].delayed_recall_claimed,"no_learning_effect_claim")
	var data := ready()
	var review: Dictionary = data.reviews
	check(review.batch.ids.size()==2,"no_more_than_two_invitations")
	var batch: Dictionary = review.batch.duplicate(true)
	Review.refresh(review,now+Review.DAY+20)
	check(batch==review.batch,"reopening_keeps_batch_and_ids")
	id = review.batch.ids[0]
	var answer: String = Review.context(review.opportunities[id]).correct
	check(not Review.apply(review,{"kind":"begin","id":id,"room":"wrong"},now+Review.DAY+2).ok,"begin_requires_real_destination")
	check(not apply(review,id,"answer",now+Review.DAY+2,{"answer":answer}).ok,"answer_requires_started_opportunity")
	apply(review,id,"begin",now+Review.DAY+2)
	check(review.targets["letter/A/image"].last_exposure==now+Review.DAY+2,"case_stimulus_tracks_sibling_image_target_exposure")
	apply(review,id,"answer",now+Review.DAY+3,{"answer":answer})
	check(review.opportunities[id].result=="independent_correct" and review.opportunities[id].answers[0].first,"unassisted_first_correct_separate")
	check(review.opportunities[id].elapsed_real_seconds>=Review.DAY,"elapsed_seconds_recorded")
	var frozen := review.duplicate(true)
	apply(review,id,"answer",now+Review.DAY+4,{"answer":answer})
	check(frozen==review,"duplicate_answer_does_not_duplicate_outcome")
	var target_id: String = review.opportunities[id].target
	check(not Review.eligible(review,target_id,now+Review.DAY+4),"completion_schedules_later_no_catchup_loop")
	check(Review.eligible(review,target_id,now+Review.DAY*2+4),"next_real_day_opens_next_round")
	check(Review.normalize(review).ok,"completed_round_normalizes")
	var parsed: Variant = JSON.parse_string(JSON.stringify(review))
	check(Review.normalize(parsed).ok,"json_roundtrip_normalizes")
	var next_id: String = review.batch.ids[1]
	apply(review,next_id,"begin",now+Review.DAY+2)
	apply(review,next_id,"help",now+Review.DAY+3,{"level":1})
	apply(review,next_id,"defer",now+Review.DAY+4)
	var normalized: Dictionary = Review.normalize(JSON.parse_string(JSON.stringify(review)))
	if not normalized.ok: check(false,"resume_normalizes"); finish(); return
	var recovered: Dictionary = normalized.value
	apply(recovered,next_id,"begin",now+Review.DAY*2)
	check(recovered.opportunities[next_id].help==1 and recovered.opportunities[next_id].help_events.size()==1,"hint_survives_reload_and_resume")
	apply(recovered,next_id,"answer",now+Review.DAY*2+1,{"answer":Review.context(recovered.opportunities[next_id]).correct})
	check(recovered.opportunities[next_id].result=="supported_correct","hinted_answer_never_independent")
	check(Review.normalize(recovered).ok,"hinted_record_normalizes")
	data = ready("C")
	review = data.reviews
	id = review.batch.ids[0]
	apply(review,id,"begin",now+Review.DAY+2)
	var spec := Review.context(review.opportunities[id])
	var wrong: String = spec.options.filter(func(x: Dictionary): return x.id!=spec.correct)[0].id
	apply(review,id,"answer",now+Review.DAY+3,{"answer":wrong})
	check(not review.opportunities[id].answers[0].correct and review.opportunities[id].answers[0].unassisted,"independent_wrong_attempt_preserved")
	var row: Dictionary = Observations.rows(data).filter(func(item: Dictionary): return item.id==id)[0]
	check(row.result=="not_correct","unfinished_error_is_not_displayed_as_unattempted")
	apply(review,id,"answer",now+Review.DAY+4,{"answer":spec.correct})
	check(review.opportunities[id].result=="supported_correct" and not review.opportunities[id].answers[0].correct,"retry_does_not_rewrite_first_error")
	data = ready("D")
	review = data.reviews
	id = review.batch.ids[0]
	apply(review,id,"begin",now+Review.DAY+2)
	check(not apply(review,id,"demonstrated",now+Review.DAY+3).ok,"no_demo_receipt_without_exposure")
	apply(review,id,"help",now+Review.DAY+3,{"level":5})
	apply(review,id,"help",now+Review.DAY+4,{"level":1})
	check(review.opportunities[id].help==5,"help_never_downgrades")
	apply(review,id,"demonstrated",now+Review.DAY+5)
	check(review.opportunities[id].answers.is_empty() and review.opportunities[id].result=="demonstrated","watching_is_not_answering")
	data = ready("E",true)
	review = data.reviews
	id = review.batch.ids[0]
	apply(review,id,"begin",now+Review.DAY+2)
	check(review.opportunities[id].elapsed_real_seconds==-1,"old_save_does_not_invent_gap")
	apply(review,id,"skip",now+Review.DAY+3)
	check(review.opportunities[id].answers.is_empty() and review.opportunities[id].result=="skipped","skip_is_not_incorrect_or_mastered")
	_clock_checks()
	_schedule_checks()
	_source_checks()
	_transaction_checks()
	var saved := all.duplicate(true)
	Observations.rows(all)
	Observations.overview(all)
	check(all==saved,"parent_projection_is_read_only")
	check(Observations.overview(all).attempted_targets==0,"experienced_is_not_attempted")
	finish()

func _clock_checks() -> void:
	var data := ready("F")
	var review: Dictionary = data.reviews
	var id: String = review.batch.ids[0]
	Review.tick(review,now+Review.DAY+2)
	apply(review,id,"begin",now+Review.DAY+2)
	check(Review.tick(review,now+Review.DAY*3,2.0),"foreground_clock_forward_detected")
	check(review.opportunities[id].elapsed_real_seconds==-1,"clock_jump_invalidates_open_interval")
	check(Review.tick(review,now+100,1.0),"clock_backward_detected")
	check(review.clock.anomalies==2,"clock_anomalies_counted")
	check(review.batch.at==now+100 and Review.eligible(review,review.opportunities[id].target,now+110),"rollback_does_not_freeze_optional_invites_in_future")
	check(Review.normalize(review).ok,"anomaly_still_allows_save")
	apply(review,id,"answer",now+110,{"answer":Review.context(review.opportunities[id]).correct})
	check(review.opportunities[id].result=="supported_correct","clock_anomaly_never_creates_independent_delay_claim")
	var fresh := Review.fresh()
	Review.tick(fresh,now)
	check(not Review.tick(fresh,now+Review.DAY*3),"normal_three_day_offline_gap_is_device_estimate")
	check(Review.tick(fresh,now+Review.DAY*90),"ambiguous_long_gap_conservatively_unknown")
	var invalid := review.duplicate(true)
	invalid.opportunities[id].delayed_recall_claimed = true
	check(not Review.normalize(invalid).ok,"fabricated_delayed_mastery_flag_rejected")
	invalid = review.duplicate(true)
	invalid.opportunities[id].result = "independent_correct"
	check(not Review.normalize(invalid).ok,"forged_independent_result_rejected")
	invalid = review.duplicate(true)
	invalid.opportunities[id].round = 1.5
	check(not Review.normalize(invalid).ok,"fractional_round_rejected")

func _schedule_checks() -> void:
	var data := ready("Z")
	var review: Dictionary = data.reviews
	review.targets.erase("letter/Z/image")
	var id: String = review.batch.ids[0]
	var target_id: String = review.opportunities[id].target
	var time := now+Review.DAY+2
	for expected_delay: float in [Review.DAY,3.0*Review.DAY,7.0*Review.DAY,7.0*Review.DAY]:
		apply(review,id,"begin",time)
		apply(review,id,"skip",time+1)
		check(not Review.eligible(review,target_id,time+expected_delay),"interval_not_early/"+str(review.targets[target_id].round))
		check(Review.eligible(review,target_id,time+expected_delay+2),"interval_due/"+str(review.targets[target_id].round))
		time += expected_delay+2
		# Keep this targeted scheduling test on one dimension; other dimensions have their own turn.
		Review.refresh(review,time)
		var matches: Array = review.opportunities.values().filter(func(item: Dictionary): return item.target==target_id and item.result.is_empty())
		check(matches.size()==1,"one_pending_per_round/"+str(review.targets[target_id].round))
		if matches.is_empty(): return
		id = matches[0].id
	check(Review.normalize(review).ok,"multi_round_schedule_roundtrip")

func _source_checks() -> void:
	check(Review.targets_in_text(["Hello!"])==["unit/hello"],"visible_hello_does_not_touch_unseen_expressions")
	check(Review.targets_in_text(["角色卡 10"])==["unit/10"],"numeric_exposure_uses_whole_tokens")
	check(Review.targets_in_text(["What's your name?"])==["unit/name"],"question_phrase_identity_matches")
	var data := fixture("")
	data.completed_units={"1":true,"2":true,"3":true}
	Review.sync(data,{},now)
	var before := data.duplicate(true)
	data.learning["u3_birthday"]={"exposed":1,"assisted":0,"independent":0,"attempts":0,"last_seen":now+1}
	Review.sync(data,before,now+1)
	check(data.reviews.targets["unit/8"].last_exposure==now+1 and data.reviews.targets["unit/hello"].last_exposure==-1,"legacy_exposure_only_touches_related_targets")

func _transaction_checks() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var state := StateScript.new()
	state.save_path = directory+"/save.json"
	state.data = fixture("A")
	var old := state.snapshot()
	old.erase("reviews")
	var migrated: Dictionary = state._normalize_state(old)
	check(migrated.ok and migrated.state.journey==old.journey and migrated.state.coins==old.coins,"legacy_migration_preserves_life_and_economy")
	state.data = migrated.state
	check(state.review_refresh(),"state_refresh_saved_atomically")
	var expected := state.snapshot()
	state.load_state()
	if state.snapshot()!=expected:
		for key: String in expected:
			if expected[key]!=state.data[key]: print("ROUNDTRIP_DIFF ",key," expected=",JSON.stringify(expected[key])," actual=",JSON.stringify(state.data[key]))
	check(state.snapshot()==expected,"state_roundtrip_keeps_reviews")
	var blocker := FileAccess.open(directory+"/blocked",FileAccess.WRITE)
	blocker.store_string("fixture")
	blocker.close()
	state.save_path = directory+"/blocked/save.json"
	check(not state.review_expose("letter/") and state.snapshot()==expected,"failed_save_rolls_back_exposure_and_clock")
	state.free()
	for path: String in ["save.json","save.json.bak","save.json.tmp","blocked"]:
		if FileAccess.file_exists(directory+"/"+path): DirAccess.remove_absolute(ProjectSettings.globalize_path(directory+"/"+path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

func finish() -> void:
	var output := FileAccess.open("res://../docs/verification/revisits/state-report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Synthetic clock and state tests, including legacy migration and write-failure rollback. No learning efficacy measurement."},"  "))
	output.close()
	print("REVISIT_STATE checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
