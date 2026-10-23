extends SceneTree
const Progress = preload("res://scripts/discovery_progress.gd")
var checks: Array = []
var failures: Array = []
var now := 10000.0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, name: String) -> void:
	checks.append({"id":name,"passed":condition})
	if not condition: failures.append(name); printerr("FAIL ",name)

func fixture(letters: String = "", mode: String = "demonstration_viewed") -> Dictionary:
	var result := {"letters":{},"p2":{"discovery":Progress.fresh()},"memory":{"sessions":{}},"coins":37}
	for letter: String in Progress.LETTERS:
		result.letters[letter] = {"visited":letters.contains(letter),"experienced":letters.contains(letter),"completion_mode":mode if letters.contains(letter) else ""}
	return result

func event(journey: Dictionary, kind: String, item_type: String = "card", id: String = "A", extra: Dictionary = {}) -> Dictionary:
	now += 0.5
	var value := {"kind":kind,"item_type":item_type,"item_id":id}
	value.merge(extra)
	return Progress.apply(journey,value,now)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"): quit(2); return
	create_timer(40.0).timeout.connect(func(): printerr("FAIL discovery_state_timeout"); quit(1))
	var journey := fixture()
	check(Progress.normalize(null,journey).value == Progress.fresh(),"old_empty_save_has_no_invented_choices")
	check(Progress.eligible_letters(journey).is_empty() and Progress.eligible_districts(journey).is_empty(),"fresh_has_no_rewards")
	var before := journey.duplicate(true)
	check(not event(journey,"discovery_begin").ok and journey == before,"unexperienced_card_rejected_without_mutation")
	journey.letters.A.visited = true
	check(not event(journey,"discovery_begin").ok,"visit_alone_never_unlocks_card")
	journey = fixture("A")
	var learning: Dictionary = journey.letters.duplicate(true)
	check(Progress.eligible_letters(journey) == ["A"],"first_station_has_first_card_without_26_gate")
	check(Progress.eligible_districts(journey).is_empty(),"one_station_does_not_complete_district")
	check(event(journey,"discovery_begin").ok,"first_card_begin")
	var own: Dictionary = journey.p2.discovery
	check(own.cards.is_empty() and own.display.card.is_empty(),"preview_does_not_create_or_display_confirmed_work")
	check(event(journey,"discovery_theme","card","A",{"theme":"sea"}).ok,"choose_theme")
	check(event(journey,"discovery_layout","card","A",{"layout":"postcard"}).ok,"choose_layout")
	check(event(journey,"discovery_display","card","A",{"display":true}).ok,"choose_display_at_first_station")
	var recovered := Progress.normalize(JSON.parse_string(JSON.stringify(own)),{"letters":journey.letters})
	check(recovered.ok and recovered.value.drafts == own.drafts and recovered.value.display.card == "","draft_roundtrip_without_p2_dependency")
	before = journey.duplicate(true)
	check(not event(journey,"discovery_image","card","A",{"image_letter":"B"}).ok and journey == before,"card_image_is_fixed_to_its_letter")
	check(event(journey,"discovery_confirm").ok,"first_card_confirm")
	check(own.cards.A.design == {"image_letter":"A","theme":"sea","layout":"postcard"} and own.display.card == "A","confirmed_design_and_home_display")
	check(own.cards.size() == 1 and own.cards.A.revision == 1 and own.drafts.is_empty(),"one_card_one_result")
	before = journey.duplicate(true)
	check(event(journey,"discovery_confirm").ok and journey == before,"double_confirm_idempotent")
	check(event(journey,"discovery_begin").ok,"edit_existing")
	event(journey,"discovery_theme","card","A",{"theme":"meadow"})
	check(own.cards.A.design.theme == "sea","draft_cannot_replace_world_theme")
	check(event(journey,"discovery_cancel").ok and own.cards.A.design.theme == "sea" and own.display.card == "A","cancel_preserves_confirmed_work")
	event(journey,"discovery_begin")
	event(journey,"discovery_theme","card","A",{"theme":"meadow"})
	event(journey,"discovery_confirm")
	check(own.cards.size() == 1 and own.cards.A.revision == 2,"style_edit_updates_same_card_no_extra_reward")
	check(journey.letters == learning and journey.coins == 37 and journey.memory.sessions.is_empty(),"decoration_never_changes_learning_or_currency")
	check(Progress.normalize(own,journey).ok,"confirmed_state_normalizes")
	var independent := fixture("A","independent_action")
	check(Progress.eligible_letters(independent) == Progress.eligible_letters(journey),"demonstration_and_independent_get_same_eligibility")
	for mode: String in ["independent_action","hinted_action","companion_action","demonstration_viewed"]:
		var supported := fixture("ABCDEF",mode)
		check(Progress.eligible_districts(supported) == ["morning_village"],"district_same_reward_mode/"+mode)
	var partial := fixture("ABCDE")
	partial.letters.F.visited = true
	check(not event(partial,"discovery_begin","page","morning_village").ok,"district_requires_all_experienced_not_visited")
	journey = fixture("ABCDEFG")
	own = journey.p2.discovery
	check(event(journey,"discovery_begin","page","morning_village").ok,"complete_district_page_begin")
	check(event(journey,"discovery_image","page","morning_village",{"image_letter":"F"}).ok,"choose_real_district_image")
	before = journey.duplicate(true)
	check(not event(journey,"discovery_image","page","morning_village",{"image_letter":"G"}).ok and journey == before,"experienced_other_district_cannot_be_main_image")
	check(not event(journey,"discovery_image","page","morning_village",{"image_letter":"Z"}).ok and journey == before,"unexperienced_image_rejected")
	event(journey,"discovery_display","page","morning_village",{"display":true})
	event(journey,"discovery_confirm","page","morning_village")
	check(own.pages.morning_village.design.image_letter == "F" and own.display.page == "morning_village","confirmed_page_keeps_actual_selected_image")
	check(Progress.normalize(own,journey).ok,"page_roundtrip")
	var all := fixture(Progress.LETTERS)
	check(Progress.eligible_letters(all).size() == 26 and Progress.eligible_districts(all).size() == 5,"all_five_districts_supported")
	var migrated := Progress.normalize(null,{"letters":all.letters})
	check(migrated.ok and migrated.value == Progress.fresh(),"old_completed_save_restores_eligibility_without_fabricated_designs")
	for id: String in Progress.DISTRICTS:
		check(event(all,"discovery_begin","page",id).ok and event(all,"discovery_confirm","page",id).ok,"all_district_creation/"+id)
	check(all.p2.discovery.pages.size() == 5 and Progress.normalize(all.p2.discovery,all).ok,"all_five_pages_roundtrip")
	corruption_checks(journey)
	replacement_checks()
	var controller: Script = load("res://scripts/discovery_controller.gd")
	var artwork: Script = load("res://ui/discovery_artwork.gd")
	check(controller != null and controller.can_instantiate(),"controller_script_parses")
	check(artwork != null and artwork.can_instantiate(),"artwork_script_parses")
	var directory := ProjectSettings.globalize_path("res://../docs/verification/life-keepsakes/discovery")
	DirAccess.make_dir_recursive_absolute(directory)
	var report := {"scope":"pure state and script parsing; no graphical run or player save writes","passed":checks.size()-failures.size(),"failed":failures.size(),"checks":checks}
	var path := directory+"/state-%d-%d.json" % [int(Time.get_unix_time_from_system()),OS.get_process_id()]
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: failures.append("report_write_failed")
	print("DISCOVERY_STATE ",checks.size()-failures.size()," passed / ",failures.size()," failed; report=",path)
	quit(1 if not failures.is_empty() else 0)

func replacement_checks() -> void:
	var journey := fixture("AB")
	for letter: String in "AB":
		event(journey,"discovery_begin","card",letter)
		event(journey,"discovery_display","card",letter,{"display":true})
		event(journey,"discovery_confirm","card",letter)
	var own: Dictionary = journey.p2.discovery
	check(own.cards.size() == 2 and own.display.card == "B","replace_display_keeps_previous_card_in_collection")
	event(journey,"discovery_begin","card","B")
	event(journey,"discovery_display","card","B",{"display":false})
	event(journey,"discovery_confirm","card","B")
	check(own.cards.size() == 2 and own.display.card.is_empty(),"store_display_keeps_all_owned_works")
	check(Progress.normalize(own,journey).ok,"stored_collection_normalizes")

func corruption_checks(journey: Dictionary) -> void:
	for change: Dictionary in [{"theme":"premium"},{"layout":"freeform"},{"image_letter":"G"},{"image_letter":""}]:
		var bad: Dictionary = journey.p2.discovery.duplicate(true)
		bad.pages.morning_village.design.merge(change,true)
		check(not Progress.normalize(bad,journey).ok,"invalid_design_rejected/"+str(change))
	var bad: Dictionary = journey.p2.discovery.duplicate(true)
	bad.display.card = "Z"
	check(not Progress.normalize(bad,journey).ok,"forged_display_rejected")
	bad = journey.p2.discovery.duplicate(true)
	bad.pages.morning_village.confirmed_at = NAN
	check(not Progress.normalize(bad,journey).ok,"nonfinite_timestamp_rejected")
	bad = journey.p2.discovery.duplicate(true)
	bad.pages.morning_village.revision = 1.5
	check(not Progress.normalize(bad,journey).ok,"fractional_revision_rejected")
	bad = journey.p2.discovery.duplicate(true)
	bad.drafts["page/morning_village"] = {"item_type":"page","item_id":"morning_village","design":{"image_letter":"G","theme":"sea","layout":"portrait"},"display":true}
	check(not Progress.normalize(bad,journey).ok,"forged_draft_image_rejected")
	for extra: Dictionary in [{"theme":"premium"},{"theme":null},{"layout":"unknown"},{"display":"yes"}]:
		event(journey,"discovery_begin","page","morning_village")
		var before := journey.duplicate(true)
		var key: String = extra.keys()[0]
		check(not event(journey,"discovery_"+key,"page","morning_village",extra).ok and journey == before,"invalid_event_atomic/"+key+"/"+str(extra[key]))
