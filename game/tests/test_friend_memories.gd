extends SceneTree
## Read-only story branches: no State mutation, save writes, or graphical scene.
const Memories = preload("res://scripts/friend_memories_controller.gd")
const Journey = preload("res://scripts/journey_progress.gd")
const Chapter = preload("res://scripts/p2_progress.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); print("FAIL ",label)

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	var memories := Memories.new()
	var state := Journey.fresh()
	for actor: String in Memories.FRIENDS:
		check(memories.memory_for(actor,state).is_empty(),"unmet_friend_hidden/"+actor)
	state.home_steps = ["H01","H02","H03","H04"]
	check(memories.memory_for("npc_bear_uncle",state).facts.has("travel_book"),"bear_remembers_received_book")
	check(not memories.memory_for("npc_bear_uncle",state).text.contains("合照"),"no_photo_claim_before_photo")
	state.u1.steps = ["U1-01","U1-02","U1-03","U1-04","U1-05","U1-06","U1-07"]
	state.phase = "u1"
	state.next_u1_step = "U1-08"
	for actor: String in ["textbook_lingling","textbook_peter","textbook_anne"]:
		check(memories.task_owns_actor(actor,state),"photo_task_keeps_actor/"+actor)
	check(not memories.task_owns_actor("npc_bear_uncle",state),"idle_actor_can_remember_during_u1")
	check(memories.memory_for("textbook_peter",state).facts.has("travel_book_gift"),"peter_remembers_gift")
	state.u1.photo = {"created":true,"details":{"frame":"blue","image_path":"user://missing-friend-memory-photo.png"}}
	check(not memories.memory_for("textbook_peter",state).text.contains("合照"),"missing_photo_file_never_claimed")
	state.u1.photo.details.image_path = "res://assets/learning/story_props_v3/envelope.png"
	check(memories.memory_for("textbook_peter",state).facts.has("real_photo:blue"),"actual_photo_file_enables_frame_memory")
	state.phase = "u2"
	state.u1.completed = true
	state.p2.chapters["2"].steps = ["U2-01"]
	check(memories.task_owns_actor("textbook_lingling",state),"u2_current_actor_has_priority")
	check(not memories.task_owns_actor("textbook_peter",state),"u2_idle_actor_not_blocked")
	state.p2.chapters["2"].steps = ["U2-01","U2-02","U2-03","U2-04","U2-05"]
	state.p2.mail = ["textbook_lingling","textbook_tim"]
	state.p2.friend_corner.invitation_styles.textbook_tim = "star"
	state.p2.friend_corner.layout.positions.textbook_tim = "left"
	var invitation := memories.memory_for("textbook_tim",state)
	check(invitation.facts.has("invitation:star") and invitation.facts.has("reply_displayed:left"),"specific_invitation_and_confirmed_reply_kept")
	state.p2.friend_corner.layout.positions.textbook_tim = ""
	state.p2.friend_corner.draft = {"positions":{"textbook_tim":"left"}}
	check(not memories.memory_for("textbook_tim",state).facts.has("reply_displayed:left"),"draft_reply_not_claimed")
	check(memories.memory_for("textbook_anne",state).facts.has("campus_goodbye"),"anne_remembers_u2_goodbye")
	check(memories.memory_for("textbook_mingming",state).is_empty(),"mingming_hidden_until_met")
	state.p2.chapters["2"].completed = true
	state.phase = "u3"
	state.p2.chapters["3"].steps = ["U3-01","U3-02"]
	check(memories.memory_for("textbook_mingming",state).facts.has("age_card:8"),"mingming_remembers_own_card")
	check(memories.task_owns_actor("textbook_dongdong",state),"u3_current_actor_has_priority")
	state.p2.chapters["3"].steps.append("U3-03")
	check(memories.memory_for("textbook_dongdong",state).facts.has("age_card:9"),"dongdong_remembers_own_card")
	state.p2.chapters["3"].steps.append("U3-04")
	check(not memories.task_owns_actor("textbook_tim",state),"completed_tim_task_releases_friend")
	state.p2.chapters["3"].completed = true
	state.phase = "p2_complete"
	var ready := memories.memory_for("textbook_mingming",state)
	check(ready.stage == "table_ready" and not ready.text.contains("那次聚会"),"chapter_complete_only_prepared")
	check(memories.should_use_corner("textbook_tim",state),"tim_keeps_invitation_before_party")
	state.p2["party"] = {"confirmed_at":10.0,"layout":{"theme":"star","seats":{"textbook_mingming":"seat_3"}},"draft":{"theme":"flowers","seats":{}},"memory":{}}
	var arranged := memories.memory_for("textbook_mingming",state)
	check(arranged.text.contains("星星桌面") and arranged.text.contains("3号椅") and not arranged.text.contains("那次聚会"),"confirmed_table_specific_but_not_party")
	check(memories.should_use_corner("textbook_tim",state),"arranging_table_does_not_replace_tim_invitation")
	state.p2.party.memory = {"id":"party-memory-v1","views":1,"layout":{"theme":"flowers","seats":{"textbook_mingming":"seat_2","textbook_dongdong":"seat_4","textbook_tim":"seat_1","textbook_anne":"seat_3"}}}
	var watched := memories.memory_for("textbook_mingming",state)
	check(watched.stage == "party_memory" and watched.text.contains("2号椅") and watched.text.contains("花朵桌面"),"party_remembers_watched_layout_not_latest_edit")
	check(not memories.should_use_corner("textbook_tim",state) and memories.memory_for("textbook_tim",state).text.contains("1号椅"),"tim_revisit_selects_actual_party_memory")
	check(memories.should_use_corner("textbook_lingling",state),"lingling_keeps_original_invitation_branch")
	check(not memories.memory_for("npc_bear_uncle",state).text.contains("我坐在"),"non_guest_does_not_claim_attendance")
	state.p2["discovery"] = {"cards":{},"pages":{},"drafts":{"card:A":{"design":{"theme":"sunrise"}}},"display":{"card":"A","page":""}}
	check(not memories.memory_for("textbook_peter",state).get("discovery_action",false),"discovery_draft_not_claimed")
	state.p2.discovery.cards["A"] = {"design":{"image_letter":"A","theme":"sunrise","layout":"portrait"},"revision":1,"confirmed_at":15.0}
	check(memories.memory_for("textbook_peter",state).facts.has("discovery_displayed:card:A"),"displayed_letter_card_remembered")
	state.p2.discovery.display.card = ""
	check(not memories.memory_for("textbook_peter",state).get("discovery_action",false),"stored_card_not_claimed_as_displayed")
	state.p2.discovery.pages["morning_village"] = {"design":{},"revision":1,"confirmed_at":16.0}
	state.p2.discovery.display.page = "morning_village"
	check(memories.memory_for("npc_bear_uncle",state).text.contains("晨光村纪念页"),"displayed_district_page_remembered")
	check(memories.memory_for("npc_rabbit_gardener",state).is_empty(),"rabbit_not_met_by_unrelated_progress")
	state.p2.trials["U1-10"] = {"completed":true,"result":"skipped"}
	check(memories.memory_for("npc_rabbit_gardener",state).is_empty(),"skipped_greeting_does_not_meet_rabbit")
	state.p2.trials["U1-10"] = {"completed":false,"result":""}
	check(memories.task_owns_actor("npc_rabbit_gardener",state),"unfinished_transfer_keeps_rabbit")
	state.p2.trials["U1-10"] = {"completed":true,"result":"demonstrated"}
	check(not memories.memory_for("npc_rabbit_gardener",state).text.contains("送进篮子"),"greeting_not_apple_completion")
	state.experiences.orchard_pick.stage = "carrying"
	check(memories.memory_for("npc_rabbit_gardener",state).facts.has("orchard_carrying"),"rabbit_remembers_unfinished_apple")
	state.experiences.orchard_pick.completed_once = true
	check(memories.memory_for("npc_rabbit_gardener",state).facts.has("orchard_deposited"),"rabbit_remembers_real_deposit")
	var before := state.duplicate(true)
	for actor: String in Memories.FRIENDS:
		memories.memory_for(actor,state)
		memories.task_owns_actor(actor,state)
	check(before == state,"all_queries_leave_saved_facts_unchanged")
	check(memories.memory_for("textbook_unknown",state).is_empty(),"unknown_actor_has_no_invented_resource")
	memories.free()
	print(JSON.stringify({"suite":"friend_memories","checks":checks,"failures":failures,"read_only":true}))
	quit(0 if failures.is_empty() else 1)
