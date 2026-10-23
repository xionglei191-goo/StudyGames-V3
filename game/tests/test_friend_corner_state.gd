extends SceneTree
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
const Corner = preload("res://scripts/friend_corner_progress.gd")
var checks: Array = []
var failures: Array = []
var now := 10000.25
var production_hashes: Dictionary = {}
var state: Node

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"id":label,"passed":condition})
	if not condition: failures.append(label); print("FAIL ",label)

func event(journey: Dictionary, data: Dictionary) -> Dictionary:
	var input := data.duplicate(true)
	if not input.has("room"): input.room = "home"
	now += 0.25
	return Chapter.apply(journey,input,now)

func ready_journey() -> Dictionary:
	var result := Journey.fresh()
	for step: String in Journey.HOME_STEPS: Journey.complete_home_step(result,step)
	for letter: String in Journey.LETTERS:
		for fact: String in Journey.LETTER_FACTS: Journey.record_letter(result,letter,"landmark_"+letter,fact,"companion_action")
	for step: String in Journey.U1_STEPS.slice(0,9): Journey.complete_u1_step(result,step,{},1000.0)
	return result

func complete_u2(journey: Dictionary, supported: bool) -> void:
	for step: Dictionary in Chapter.content().chapters["2"].steps:
		if step.kind == "question":
			event(journey,{"kind":"trial_begin","room":step.room,"context":step.id})
			var id: String = journey.p2.trials[step.id].id
			if supported: event(journey,{"kind":"trial_help","room":step.room,"context":step.id,"trial_id":id,"level":3})
			event(journey,{"kind":"trial_answer","room":step.room,"context":step.id,"trial_id":id,"answer":"__demonstrated__" if supported else step.question.correct})
		elif step.kind == "mail":
			for recipient: String in Corner.RECIPIENTS: event(journey,{"kind":"mail","room":step.room,"recipient":recipient,"mailbox":recipient})
		check(event(journey,{"kind":"chapter_step","room":step.room,"chapter":2,"step":step.id}).ok,"complete_u2/%s/%s"%[supported,step.id])
		check(Journey.normalize(journey).ok,"valid_each_step/%s/%s"%[supported,step.id])

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	create_timer(60.0).timeout.connect(func(): print("FAIL state_test_timeout"); quit(1))
	state = root.get_node("State")
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: production_hashes[path] = file_hash(path)
	var journey := ready_journey()
	check(Journey.normalize(journey).ok,"u1_complete_fixture_normalizes")
	check(not event(journey,{"kind":"corner_begin"}).ok,"cannot_claim_before_chapter")
	check(not event(journey,{"kind":"corner_cover","recipient":"textbook_tim","style":"star"}).ok,"cover_requires_post_office")
	check(event(journey,{"kind":"corner_cover","room":"landmark_Z","recipient":"textbook_lingling","style":"star"}).ok,"lingling_star_cover")
	check(event(journey,{"kind":"corner_cover","room":"landmark_Z","recipient":"textbook_tim","style":"flowers"}).ok,"tim_flower_cover")
	check(Journey.normalize(journey).ok,"cover_choice_roundtrip")
	var independent := journey.duplicate(true)
	complete_u2(journey,true)
	complete_u2(independent,false)
	var corner: Dictionary = journey.p2.friend_corner
	check(Corner.owns_replies(corner),"u2_atomically_owns_replies_and_clips")
	check(corner.reward_receipt.id == independent.p2.friend_corner.reward_receipt.id,"same_reward_for_help_and_independent")
	check(Corner.REWARD_ITEMS == ["reply_lingling","reply_tim","letter_clips"],"reward_item_set_is_fixed_not_per_answer")
	check(journey.p2.trials["U2-02"].result == "demonstrated" and independent.p2.trials["U2-02"].result == "independent_correct","learning_evidence_remains_distinct")
	check(journey.reward_receipts.size() == 2 and journey.p2.receipts.size() == 1,"existing_photo_and_chapter_receipts_stay_separate")
	var before := journey.duplicate(true)
	check(event(journey,{"kind":"chapter_step","chapter":2,"step":"U2-07"}).ok and before == journey,"duplicate_finish_does_not_grant_twice")
	check(not event(journey,{"kind":"corner_cover","room":"landmark_Z","recipient":"textbook_lingling","style":"flowers"}).ok,"mailed_cover_cannot_be_rewritten")
	check(corner.invitation_styles.textbook_lingling == "star","friend_remembers_actual_cover")
	check(not event(journey,{"kind":"corner_begin","room":"school"}).ok,"display_edits_require_home")
	check(event(journey,{"kind":"corner_begin"}).ok,"begin_layout")
	check(event(journey,{"kind":"corner_style","style":"star"}).ok,"draft_theme_choice")
	check(event(journey,{"kind":"corner_place","recipient":"textbook_lingling","slot":"left"}).ok,"place_first_reply")
	check(Corner.placed_count(corner.layout) == 0 and Corner.placed_count(corner.draft) == 1,"preview_does_not_change_display")
	var resumed: Dictionary = Journey.normalize(JSON.parse_string(JSON.stringify(journey))).value
	check(resumed.p2.friend_corner.draft == corner.draft and resumed.p2.friend_corner.layout == corner.layout,"unfinished_draft_survives_disk_shape")
	check(event(journey,{"kind":"corner_place","recipient":"textbook_tim","slot":"left"}).ok,"occupied_slot_moves_previous_card_back_to_tray")
	check(corner.draft.positions.textbook_lingling == "" and corner.draft.positions.textbook_tim == "left","no_overlapping_letters")
	check(event(journey,{"kind":"corner_place","recipient":"textbook_lingling","slot":"right"}).ok,"place_second_reply")
	check(event(journey,{"kind":"corner_confirm"}).ok,"confirm_two_replies")
	check(corner.draft.is_empty() and Corner.placed_count(corner.layout) == 2 and corner.revision == 1 and corner.displayed_at > 0,"confirmed_world_layout_and_first_display")
	before = journey.duplicate(true)
	check(event(journey,{"kind":"corner_confirm"}).ok and before == journey,"double_confirm_idempotent")
	event(journey,{"kind":"corner_begin"})
	event(journey,{"kind":"corner_style","style":"flowers"})
	event(journey,{"kind":"corner_place","recipient":"textbook_tim","slot":"lower"})
	check(event(journey,{"kind":"corner_cancel"}).ok and corner.layout == before.p2.friend_corner.layout,"cancel_restores_last_confirmed_display")
	var earned_at := float(corner.displayed_at)
	event(journey,{"kind":"corner_begin"})
	event(journey,{"kind":"corner_place","recipient":"textbook_tim","slot":""})
	event(journey,{"kind":"corner_confirm"})
	check(Corner.owns_replies(corner) and corner.displayed_at == earned_at and Corner.placed_count(corner.layout) == 1,"storing_reply_keeps_ownership_and_first_memory")
	check(not event(journey,{"kind":"corner_friend_seen","recipient":"textbook_tim","room":"school"}).ok,"friend_memory_requires_matching_place")
	check(event(journey,{"kind":"corner_friend_seen","recipient":"textbook_tim","room":"landmark_M"}).ok,"friend_memory_saved")
	before = journey.duplicate(true)
	check(event(journey,{"kind":"corner_friend_seen","recipient":"textbook_tim","room":"landmark_M"}).ok and before == journey,"friend_revisit_has_no_repeated_reward")
	check(Journey.normalize(journey).ok,"final_layout_normalizes")
	corruption_checks(journey)
	migration_checks(independent)
	await disk_checks(journey)
	finish()

func migration_checks(journey: Dictionary) -> void:
	var old := journey.duplicate(true)
	old.p2.erase("friend_corner")
	var result := Journey.normalize(old)
	check(result.ok,"pre_feature_completed_save_migrates")
	if result.ok:
		check(result.value.p2.friend_corner.reward_receipt.at == old.p2.receipts["unit-2/chapter"].at,"migration_uses_original_chapter_receipt")
		check(result.value.p2.trials == old.p2.trials,"migration_does_not_infer_learning")
		check(result.value.p2.friend_corner.invitation_styles.textbook_tim == "plain","old_unknown_cover_is_neutral")
		check(Corner.placed_count(result.value.p2.friend_corner.layout) == 0 and result.value.p2.friend_corner.displayed_at == 0,"migration_does_not_invent_arrangement")
	var fresh := ready_journey()
	fresh.p2.erase("friend_corner")
	result = Journey.normalize(fresh)
	check(result.ok and not Corner.owns_replies(result.value.p2.friend_corner),"unfinished_old_save_gets_no_reward")

func corruption_checks(journey: Dictionary) -> void:
	for change: Dictionary in [{"revision":-1},{"revision":1.5},{"displayed_at":NAN},{"schema_version":2},{"reward_receipt":{}},{"draft":{"style":"gold","positions":{}}}]:
		var bad := journey.duplicate(true)
		bad.p2.friend_corner.merge(change,true)
		check(not Journey.normalize(bad).ok,"reject_corrupt/"+str(change.keys()[0])+"/"+str(change.values()[0]))
	var bad := journey.duplicate(true)
	bad.p2.friend_corner.reward_receipt.at += 1
	check(not Journey.normalize(bad).ok,"forged_reward_timestamp_rejected")
	bad = journey.duplicate(true)
	bad.p2.friend_corner.layout.positions = {"textbook_lingling":"left","textbook_tim":"left"}
	check(not Journey.normalize(bad).ok,"overlapping_saved_layout_rejected")
	bad = journey.duplicate(true)
	bad.p2.friend_corner.conversations.unknown = 100
	check(not Journey.normalize(bad).ok,"unknown_friend_rejected")
	bad = ready_journey()
	bad.p2.friend_corner.reward_receipt = journey.p2.friend_corner.reward_receipt.duplicate(true)
	check(not Journey.normalize(bad).ok,"reward_without_chapter_rejected")
	for input: Dictionary in [{"kind":"corner_place","recipient":"textbook_tim","slot":"ceiling"},{"kind":"corner_style","style":"premium"},{"kind":"corner_place","recipient":"stranger","slot":"left"}]:
		var before := journey.duplicate(true)
		check(not event(journey,input).ok and journey == before,"invalid_action_does_not_mutate/"+str(input))

func disk_checks(journey: Dictionary) -> void:
	state.save_path = "user://validation-friend-corner-%d.json" % OS.get_process_id()
	state.data = state._default_state()
	state.data.journey = journey.duplicate(true)
	check(state.save_state(),"real_disk_save")
	state.load_state()
	check(state.data.journey.p2.friend_corner.layout == journey.p2.friend_corner.layout,"real_disk_layout_reload")
	var currency: int = state.data.coins
	var learning: Dictionary = state.data.learning.duplicate(true)
	check(state.journey_p2_event({"kind":"corner_begin","room":"home"}),"transaction_begin")
	check(state.journey_p2_event({"kind":"corner_place","room":"home","recipient":"textbook_tim","slot":"lower"}),"transaction_draft_saved")
	state.load_state()
	check(state.data.journey.p2.friend_corner.draft.positions.textbook_tim == "lower","actual_draft_recovery")
	var before: Dictionary = state.snapshot()
	var original_path: String = state.save_path
	var blocker := "user://validation-friend-corner-blocker-%d" % OS.get_process_id()
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("test blocker")
	file.close()
	state.save_path = blocker+"/unwritable.json"
	check(not state.journey_p2_event({"kind":"corner_confirm","room":"home"}),"disk_failure_does_not_confirm_reward_display")
	check(state.snapshot() == before,"failure_rolls_back_layout_revision_and_receipt")
	state.save_path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	check(state.journey_p2_event({"kind":"corner_confirm","room":"home"}),"retry_confirm_succeeds")
	check(state.data.coins == currency and state.data.learning == learning,"no_old_currency_or_learning_mutation")
	var snapshot: Dictionary = state.snapshot()
	check(state.journey_p2_event({"kind":"chapter_step","room":"home","chapter":2,"step":"U2-07"}) and state.snapshot() == snapshot,"real_transaction_repeat_chapter_is_noop")
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(original_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(original_path+suffix))

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func finish() -> void:
	for path: String in production_hashes: check(file_hash(path) == production_hashes[path],"production_preserved/"+path)
	var directory := ProjectSettings.globalize_path("res://../docs/verification/friend-corner")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory = argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	var report := FileAccess.open(directory+"/state.json",FileAccess.WRITE)
	if report == null: print("FAIL cannot_write_report"); quit(1); return
	report.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Pure state transitions, both learning support paths, old-save migration, real disk recovery and rollback. No child learning-efficacy claims."},"  "))
	report.close()
	print("FRIEND_CORNER_STATE checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
