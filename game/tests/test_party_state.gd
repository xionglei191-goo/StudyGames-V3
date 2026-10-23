extends SceneTree
const Party = preload("res://scripts/party_progress.gd")
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
var checks: Array = []
var failures: Array = []
var now := 10000.0
var protected_hashes: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition: failures.append(label); print("FAIL ",label)

func event(journey: Dictionary, data: Dictionary, elapsed: float = 0.25) -> Dictionary:
	now += elapsed
	var input := data.duplicate(true)
	input.room = input.get("room","home")
	return Party.apply(journey,input,now)

func fixture(completed: bool = true) -> Dictionary:
	return {"p2":{"chapters":{"3":{"completed":completed}},"party":Party.fresh(),"receipts":{"unit-3/chapter":{"at":100.0,"step":"U3-09"}},"trials":{"prior":{"help":3,"result":"demonstrated"}}},"coins":30,"learning":{"test":{"help":2}}}

func full_journey() -> Dictionary:
	var result := Journey.fresh()
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(result,step)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(result,letter,"landmark_"+letter,fact,"companion_action")
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(result,step,{},1000.0)
	for number: int in [2,3]:
		for step: Dictionary in Chapter.content().chapters[str(number)].steps:
			if step.kind == "question":
				Chapter.apply(result,{"kind":"trial_begin","room":step.room,"context":step.id},now)
				var id: String = result.p2.trials[step.id].id
				Chapter.apply(result,{"kind":"trial_help","room":step.room,"context":step.id,"trial_id":id,"level":3},now)
				Chapter.apply(result,{"kind":"trial_answer","room":step.room,"context":step.id,"trial_id":id,"answer":"__demonstrated__"},now)
			elif step.kind == "mail":
				for id: String in ["textbook_lingling","textbook_tim"]: Chapter.apply(result,{"kind":"mail","room":step.room,"recipient":id,"mailbox":id},now)
			elif step.kind == "seats": Chapter.apply(result,{"kind":"seats","room":step.room,"count":step.seat_count},now)
			Chapter.apply(result,{"kind":"chapter_step","room":step.room,"chapter":number,"step":step.id},now)
	return result

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: protected_hashes[path] = _hash(path)
	var journey := fixture(false)
	check(Party.normalize(JSON.parse_string(JSON.stringify(Party.fresh())),journey.p2).ok,"pre_u3_fresh_json_float_normalizes")
	check(Party.normalize(JSON.parse_string(JSON.stringify(Party.fresh())),journey.p2).value == Party.fresh(),"fresh_party_json_roundtrip_preserves_canonical_numeric_types")
	check(Journey.normalize(JSON.parse_string(JSON.stringify(Journey.fresh()))).ok,"fresh_journey_json_disk_shape_normalizes_before_u3")
	check(not event(journey,{"kind":"party_begin"}).ok,"unfinished_u3_cannot_arrange")
	check(Party.normalize(null,journey.p2).value == Party.fresh(),"missing_feature_returns_empty_no_invented_party")
	journey = fixture()
	check(not event(journey,{"kind":"party_begin","room":"classroom"}).ok,"arrangement_requires_home")
	check(event(journey,{"kind":"party_begin"}).ok,"begin_draft")
	var party: Dictionary = journey.p2.party
	check(Party.is_arranged(party.draft) and party.layout == Party.empty_layout(),"first_auto_seating_is_only_unconfirmed_preview")
	check(event(journey,{"kind":"party_theme","theme":"star"}).ok,"draft_theme_change")
	check(event(journey,{"kind":"party_seat","guest":"textbook_anne","seat":"seat_1"}).ok,"swap_anne_and_mingming")
	check(party.draft.seats.textbook_anne == "seat_1" and party.draft.seats.textbook_mingming == "seat_4","occupied_seat_swaps_without_overlap")
	var reloaded := Party.normalize(JSON.parse_string(JSON.stringify(party)),journey.p2)
	check(reloaded.ok and reloaded.value.draft == party.draft,"draft_roundtrip_recovers_theme_and_seats")
	check(event(journey,{"kind":"party_cancel"}).ok and party.layout == Party.empty_layout() and party.draft.is_empty(),"cancel_keeps_empty_committed_layout")
	event(journey,{"kind":"party_begin"})
	event(journey,{"kind":"party_theme","theme":"star"})
	check(event(journey,{"kind":"party_confirm"}).ok,"confirm_arrangement")
	check(party.revision == 1 and Party.is_arranged(party.layout) and not Party.watched(party),"arranged_does_not_mean_watched")
	var before := journey.duplicate(true)
	check(event(journey,{"kind":"party_confirm"}).ok and before == journey,"confirm_is_idempotent")
	check(not event(journey,{"kind":"party_finish","id":"party-1"}).ok,"finish_without_playback_is_rejected")
	check(event(journey,{"kind":"party_play"}).ok,"begin_finite_performance")
	var id: String = party.playback.id
	check(not event(journey,{"kind":"party_beat","id":id,"step":1,"beat":"names"},10.0).ok,"out_of_order_beat_rejected")
	check(not event(journey,{"kind":"party_finish","id":id}).ok,"early_finish_does_not_invent_memory")
	check(not event(journey,{"kind":"party_begin"}).ok,"unfinished_performance_protects_resume_layout")
	check(event(journey,{"kind":"party_beat","id":id,"step":0,"beat":"welcome"},4.1).ok,"first_visible_beat_commits")
	before = journey.duplicate(true)
	check(event(journey,{"kind":"party_beat","id":id,"step":0,"beat":"welcome"}).ok and before == journey,"duplicate_beat_noop")
	check(not event(journey,{"kind":"party_beat","id":id,"step":1,"beat":"names"},0.1).ok,"too_fast_beat_rejected")
	reloaded = Party.normalize(JSON.parse_string(JSON.stringify(party)),journey.p2)
	check(reloaded.ok and reloaded.value.playback.step == 1 and reloaded.value.memory.is_empty(),"close_mid_playback_preserves_resume_without_memory")
	check(event(journey,{"kind":"party_play"}).ok and party.playback.id == id,"resume_does_not_start_extra_session")
	for index: int in range(1,4):
		check(event(journey,{"kind":"party_beat","id":id,"step":index,"beat":Party.BEATS[index]},Party.DURATIONS[index]+0.1).ok,"complete_visible_beat_%d" % index)
	check(not Party.watched(party),"all_beats_await_atomic_memory_commit")
	check(event(journey,{"kind":"party_finish","id":id}).ok,"finished_four_beats_records_memory")
	check(Party.watched(party) and party.memory.views == 1 and party.playback.finished,"first_party_saved")
	var first_at := float(party.memory.first_at)
	before = journey.duplicate(true)
	check(event(journey,{"kind":"party_finish","id":id}).ok and before == journey,"double_finish_has_no_extra_reward_or_memory")
	event(journey,{"kind":"party_begin"})
	event(journey,{"kind":"party_theme","theme":"flowers"})
	check(event(journey,{"kind":"party_cancel"}).ok and party.layout.theme == "star","cancel_after_watching_keeps_theme")
	event(journey,{"kind":"party_play"})
	id = str(party.playback.id)
	check(not event(journey,{"kind":"party_beat","id":"party-1","step":0,"beat":"welcome"},5.0).ok,"stale_session_id_rejected")
	event(journey,{"kind":"party_abandon"})
	check(party.playback.is_empty() and party.memory.views == 1,"abandoned_replay_keeps_original_memory")
	event(journey,{"kind":"party_begin"})
	event(journey,{"kind":"party_theme","theme":"flowers"})
	event(journey,{"kind":"party_confirm"})
	event(journey,{"kind":"party_play"})
	id = str(party.playback.id)
	for index: int in 4: event(journey,{"kind":"party_beat","id":id,"step":index,"beat":Party.BEATS[index]},Party.DURATIONS[index]+0.1)
	event(journey,{"kind":"party_finish","id":id})
	check(party.memory.first_at == first_at and party.memory.views == 2 and party.memory.layout.theme == "flowers","replay_preserves_first_memory_and_updates_last_theme")
	check(journey.coins == 30 and journey.learning == fixture().learning and journey.p2.trials == fixture().p2.trials and journey.p2.receipts == fixture().p2.receipts,"party_never_mutates_currency_learning_or_chapter_receipts")
	check(Party.normalize(party,journey.p2).ok,"final_state_normalizes")
	corruption(journey)
	await disk_and_migration()
	finish()

func corruption(journey: Dictionary) -> void:
	for change: Dictionary in [{"schema_version":2},{"revision":-1},{"revision":0.5},{"sequence":-1},{"confirmed_at":NAN},{"draft":{"theme":"gold","seats":{}}}]:
		var bad: Dictionary = journey.p2.party.duplicate(true)
		bad.merge(change,true)
		check(not Party.normalize(bad,journey.p2).ok,"reject_corrupt_"+str(change.keys()[0])+str(change.values()[0]))
	var bad: Dictionary = journey.p2.party.duplicate(true)
	bad.layout.seats.textbook_mingming = bad.layout.seats.textbook_tim
	check(not Party.normalize(bad,journey.p2).ok,"reject_overlapping_layout")
	bad = journey.p2.party.duplicate(true)
	bad.memory.views = 500
	check(not Party.normalize(bad,journey.p2).ok,"reject_impossible_view_count")
	bad = journey.p2.party.duplicate(true)
	bad.playback.step = 2
	check(not Party.normalize(bad,journey.p2).ok,"reject_finish_with_missing_beats")
	bad = journey.p2.party.duplicate(true)
	bad.playback.last_at = bad.playback.started_at
	check(not Party.normalize(bad,journey.p2).ok,"reject_unelapsed_performance")
	check(not Party.normalize(journey.p2.party,fixture(false).p2).ok,"reject_party_before_u3_completion")
	for input: Dictionary in [{"kind":"party_theme","theme":"gold"},{"kind":"party_seat","guest":"unknown","seat":"seat_1"},{"kind":"party_beat","id":"invalid","step":0,"beat":"welcome"}]:
		var before := journey.duplicate(true)
		check(not event(journey,input).ok and journey == before,"invalid_event_does_not_mutate_"+str(input.kind))

func disk_and_migration() -> void:
	var journey := full_journey()
	check(Journey.normalize(journey).ok,"supported_full_u3_fixture_is_valid")
	var old := journey.duplicate(true)
	old.p2.erase("party")
	var normalized := Journey.normalize(old)
	check(normalized.ok and normalized.value.p2.party == Party.fresh(),"old_u3_save_unlocks_no_fake_party")
	check(normalized.ok and normalized.value.p2.trials == old.p2.trials,"old_save_keeps_help_records_unchanged")
	var state: Node = root.get_node("State")
	var save_path := "user://validation-party-%d.json" % OS.get_process_id()
	state.save_path = save_path
	state.data = state._default_state()
	state.data.journey = journey
	var currency: int = state.data.coins
	var learning: Dictionary = state.data.learning.duplicate(true)
	check(state.journey_p2_event({"kind":"party_begin","room":"home"}),"transaction_begin")
	check(state.journey_p2_event({"kind":"party_theme","room":"home","theme":"star"}),"transaction_draft_theme")
	state.load_state()
	check(state.data.journey.p2.party.draft.theme == "star" and state.data.journey.p2.party.layout == Party.empty_layout(),"real_disk_draft_resume_keeps_world_unconfirmed")
	var before: Dictionary = state.snapshot()
	var blocker := "user://validation-party-blocker-%d" % OS.get_process_id()
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("test blocker")
	file.close()
	state.save_path = blocker+"/unwritable.json"
	check(not state.journey_p2_event({"kind":"party_confirm","room":"home"}) and state.snapshot() == before,"failed_save_rolls_back_confirmation")
	state.save_path = save_path
	check(state.journey_p2_event({"kind":"party_confirm","room":"home"}),"transaction_confirm_retry")
	check(state.data.coins == currency and state.data.learning == learning and state.data.journey.p2.trials == journey.p2.trials,"transaction_leaves_learning_currency_help_unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func finish() -> void:
	for path: String in protected_hashes: check(_hash(path) == protected_hashes[path],"production_preserved_"+path)
	var directory := ProjectSettings.globalize_path("res://../docs/verification/life-keepsakes/party")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory+"/state-%d.json" % OS.get_process_id()
	var report := FileAccess.open(path,FileAccess.WRITE)
	if report == null: print("FAIL report_write"); quit(1); return
	report.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"State order, draft/cancel/recovery, timing gates, replay idempotency, old U3 migration, isolated disk rollback and untouched learning/currency. No visual or child-efficacy claim."},"  "))
	report.close()
	print("PARTY_STATE checks=",checks.size()," failures=",failures.size()," report=",path)
	quit(0 if failures.is_empty() else 1)
