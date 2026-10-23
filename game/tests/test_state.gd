extends SceneTree
## Run: Godot --headless --path game --script res://tests/test_state.gd

const STATE_SCRIPT = preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _test_directory: String = "user://state-tests-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_roundtrip_and_backup()
	_test_quest_and_inventory_guards()
	_test_learning_and_progress()
	_test_invalid_data()
	_test_life_compatibility_and_transactions()
	_cleanup()
	if _failures.is_empty():
		print("PASS: state persistence, recovery, rewards, inventory, learning, legacy migration, life activities and atomic purchase guards")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _test_roundtrip_and_backup() -> void:
	var state = STATE_SCRIPT.new()
	state.save_path = _test_directory + "/roundtrip.json"
	state.load_state()
	_check(state.data["coins"] == 30 and state.data["day"] == 1, "Fresh state defaults")
	_check(state.mark_greeted(), "Greeting commits")
	_check(state.collect_apple(), "Apple commits")
	var expected: Dictionary = state.snapshot()
	var detached: Dictionary = state.snapshot()
	detached["quests"]["greet_done"] = false
	_check(state.data["quests"]["greet_done"], "Snapshot is deeply detached")
	var loaded = STATE_SCRIPT.new()
	loaded.save_path = state.save_path
	loaded.load_state()
	_check(loaded.snapshot() == expected, "Save roundtrip preserves all fields")
	# The backup contains the previous committed revision: greeting, before apple harvest.
	_write_file(state.save_path, "{broken json")
	loaded.load_state()
	_check(loaded.data["coins"] == 35 and loaded.data["apples"] == 0, "Malformed primary recovers previous valid backup")
	var recovered = STATE_SCRIPT.new()
	recovered.save_path = state.save_path
	recovered.load_state()
	_check(recovered.snapshot() == loaded.snapshot(), "Recovery repairs primary for next launch")
	state.free()
	loaded.free()
	recovered.free()


func _test_quest_and_inventory_guards() -> void:
	var state = STATE_SCRIPT.new()
	state.save_path = _test_directory + "/inventory.json"
	_check(not state.deliver_apples(), "Cannot deliver before greeting")
	_check(not state.sell_cake(), "Cannot sell missing cake")
	_check(not state.craft_cake(), "Recipe starts locked")
	_check(not state.place_decoration("lamp", true), "Cannot place unowned decoration")
	_check(not state.buy_decoration("unknown"), "Unknown shop ID rejected")
	_check(not state.set_outfit("unknown"), "Unknown wardrobe ID rejected")
	_check(state.mark_greeted(), "Greeting grants reward once")
	_check(not state.mark_greeted() and state.data["coins"] == 35, "Greeting replay cannot mint coins")
	for index: int in range(3):
		_check(state.collect_apple(), "Daily apple %d" % index)
	_check(not state.collect_apple() and state.data["apples"] == 3, "Daily harvest capped at three")
	_check(state.deliver_apples(), "Delivery consumes apples and grants reward")
	_check(state.data["apples"] == 0 and state.data["cakes"] == 1 and state.data["coins"] == 55, "Delivery reward totals")
	_check(not state.deliver_apples() and state.data["coins"] == 55, "Delivery replay cannot mint reward")
	_check(state.sell_cake() and state.data["coins"] == 70, "Cake sale consumes inventory")
	_check(not state.sell_cake(), "Cake cannot be sold twice")
	_check(state.buy_decoration("lamp") and state.data["coins"] == 25, "Decoration uses published price")
	_check(not state.buy_decoration("lamp") and state.data["coins"] == 25, "Owned decoration cannot be purchased again")
	_check(not state.buy_decoration("picnic") and state.data["coins"] == 25, "Insufficient funds cannot go negative")
	_check(state.place_decoration("lamp", true), "Owned decoration can be placed")
	_check(state.place_decoration("lamp", false), "Owned decoration can be removed")
	_check(state.set_outfit("pink") and state.data["outfit"] == "pink", "Wardrobe selection saves")
	_check(state.next_day() and state.data["day"] == 2 and state.data["harvested"] == 0, "Rest advances day and resets harvest")
	for index: int in range(3):
		state.collect_apple()
	_check(state.craft_cake() and state.data["cakes"] == 1 and state.data["apples"] == 0, "Unlocked cake recipe consumes three apples")
	_check(not state.craft_cake(), "Cannot craft from insufficient inventory")
	state.free()


func _test_learning_and_progress() -> void:
	var state = STATE_SCRIPT.new()
	state.save_path = _test_directory + "/learning.json"
	state.exposed("u1_greeting")
	_check(state.data["learning"]["u1_greeting"]["independent"] == 0, "Exposure is not independent success")
	_check(not state.finish_unit(1), "Exposure cannot complete unit")
	_check(not state.finish_unit(0) and not state.finish_unit(4), "Out-of-bounds units rejected")
	_check(not state.finish_unit(2), "Locked unit cannot complete")
	state.begin_question("u1_greeting")
	state.use_hint("u1_greeting")
	state.record_answer("u1_greeting", true, false)
	_check(state.data["learning"]["u1_greeting"]["assisted"] == 1 and state.data["learning"]["u1_greeting"]["independent"] == 0, "Used hint overrides false assisted argument")
	state.begin_question("u1_morning")
	state.record_answer("u1_morning", false, false)
	state.record_answer("u1_morning", true, false)
	_check(state.data["learning"]["u1_morning"]["assisted"] == 1 and state.data["learning"]["u1_morning"]["independent"] == 0, "Wrong-then-correct is assisted")
	state.begin_question("u1_goodbye")
	state.record_answer("u1_goodbye", true, false)
	_check(state.finish_unit(1) and state.data["unit"] == 2 and state.data["coins"] == 45, "Completed practice unlocks next unit and rewards once")
	_check(not state.finish_unit(1) and state.data["coins"] == 45, "Unit reward replay rejected")
	state.begin_question("u1_greeting")
	state.record_answer("u1_greeting", true, false)
	_check(state.data["learning"]["u1_greeting"]["independent"] == 1, "Fresh independent review is recorded separately")
	for unit_id: int in [2, 3]:
		for id: String in state.UNIT_QUESTIONS[unit_id]:
			state.begin_question(id)
			state.record_answer(id, true, false)
		_check(state.finish_unit(unit_id), "Sequential unit %d completes" % unit_id)
	_check(state.data["unit"] == 3 and state.data["coins"] == 75, "Final unit caps unlock at three")
	var before: Dictionary = state.snapshot()
	state.record_answer("invented", true, false)
	_check(state.snapshot() == before, "Unknown question IDs cannot enter records")
	var loaded = STATE_SCRIPT.new()
	loaded.save_path = state.save_path
	loaded.load_state()
	_check(loaded.snapshot() == before, "Learning counters and completion survive reload")
	loaded.free()
	state.free()


func _test_invalid_data() -> void:
	var state = STATE_SCRIPT.new()
	state.save_path = _test_directory + "/invalid.json"
	_check(state.save_state(), "Initial valid save succeeds")
	var valid: Dictionary = state.snapshot()
	state.data["coins"] = -1
	_check(not state.save_state(), "Negative currency cannot overwrite save")
	state.data = valid.duplicate(true)
	state.data["coins"] = "999"
	_check(not state.save_state(), "Numeric string injection rejected")
	state.data = valid.duplicate(true)
	state.data["unit"] = 3
	_check(not state.save_state(), "Unproven unlock rejected")
	state.data = valid.duplicate(true)
	state.data["decorations_placed"]["lamp"] = true
	_check(not state.save_state(), "Placed-but-unowned state rejected")
	state.data = valid.duplicate(true)
	state.data["quests"]["delivery_done"] = "false"
	_check(not state.save_state(), "Truthy non-boolean quest flags rejected")
	# A syntactically valid but invalid primary must also recover from backup.
	var invalid: Dictionary = valid.duplicate(true)
	invalid["coins"] = -8
	_write_file(state.save_path, JSON.stringify(invalid))
	state.load_state()
	_check(state.snapshot() == valid, "Invalid schema recovers from known-good backup")
	# An unknown top-level field is dropped rather than loaded into the game state.
	invalid = valid.duplicate(true)
	invalid["injected"] = {"coins": -9}
	_write_file(state.save_path, JSON.stringify(invalid))
	state.load_state()
	_check(not state.data.has("injected"), "Unknown top-level data is not imported")
	state.free()


func _test_life_compatibility_and_transactions() -> void:
	var state = STATE_SCRIPT.new()
	state.save_path = _test_directory + "/life.json"
	state.mark_greeted()
	state.collect_apple()
	state.begin_question("u1_greeting")
	state.record_answer("u1_greeting",true,false)
	var legacy: Dictionary = state.snapshot()
	legacy.erase("life")
	legacy.erase("preferences")
	_write_file(state.save_path,JSON.stringify(legacy))
	state.load_state()
	for key: String in legacy:
		_check(state.data[key]==legacy[key],"Legacy save preserves field: "+key)
	_check(state.data.life.artwork.is_empty() and state.data.preferences.voice,"Legacy save receives safe optional defaults")
	var learning: Dictionary = state.data.learning.duplicate(true)
	var coins: int = state.data.coins
	_check(state.discover("music_room",1),"Discovery persists")
	_check(state.discover("music_room",1) and state.data.life.discoveries.size()==1,"Discovery replay is idempotent")
	_check(not state.discover("unknown",1) and not state.discover("home",6),"Invalid discoveries rejected")
	_check(state.complete_activity("music") and state.data.coins==coins+8,"First activity grants eight coins")
	_check(state.complete_activity("music") and state.data.coins==coins+8,"Activity replay grants no additional coins")
	_check(not state.complete_activity("unknown") and not state.complete_activity("football",6),"Invalid activity and score rejected")
	_check(state.complete_activity("football",4),"Football best score commits")
	_check(state.complete_activity("football",2) and state.data.life.scores.football==4,"Football retains best score")
	_check(state.save_artwork([]) and not state.data.life.activities.art,"Blank art earns no completion")
	var painting: Array = [{"color":2,"points":[[0.1,0.2],[0.8,0.7]]}]
	coins = state.data.coins
	_check(state.save_artwork(painting) and state.data.coins==coins+8,"Nonempty postcard earns first reward")
	_check(state.save_artwork(painting) and state.data.coins==coins+8,"Repeated postcard saves cannot mint coins")
	_check(state.data.learning==learning,"Life activities never alter English records")
	_check(state.set_preference("effects",false) and state.set_preference("reduced_motion",true),"Preferences commit")
	var expected: Dictionary = state.snapshot()
	state.load_state()
	_check(state.snapshot()==expected,"Life state and preferences survive reload")
	_check(not state.save_artwork([{"color":5,"points":[[0.2,0.3]]}]),"Out-of-range paint color rejected")
	_check(not state.save_artwork([{"color":0,"points":[[INF,0.3]]}]),"Nonfinite paint coordinates rejected")
	_check(not state.save_artwork([{"color":0,"points":[[-0.1,0.3]]}]),"Out-of-canvas coordinates rejected")
	_check(not state.save_artwork([{"color":0,"points":[["0.1",0.3]]}]),"String coordinates rejected")
	var oversized: Array = []
	for index: int in 201:
		oversized.append(painting[0].duplicate(true))
	_check(not state.save_artwork(oversized),"More than 200 strokes rejected")
	_check(state.snapshot()==expected,"Rejected artwork leaves committed state intact")
	var malformed: Dictionary = expected.duplicate(true)
	malformed.preferences.effects = "false"
	_check(not state._normalize_state(malformed).ok,"Malformed preference cannot coerce into bool")
	malformed = expected.duplicate(true)
	malformed.life.scores.football = 6
	_check(not state._normalize_state(malformed).ok,"Invalid persisted best score rejected")
	# A file as the parent directory makes all saves fail without changing a real save.
	var original_path: String = state.save_path
	var blocker: String = _test_directory + "/blocked-parent"
	_write_file(blocker,"fixture")
	state.save_path = blocker+"/save.json"
	_check(not state.buy_decoration("flower_box",true),"Failed purchase and placement reports failure")
	_check(state.snapshot()==expected,"Failed save rolls back money, ownership and placement together")
	_check(not state.complete_activity("science") and state.snapshot()==expected,"Failed activity save rolls back reward and completion")
	state.save_path = original_path
	coins = state.data.coins
	_check(state.buy_decoration("flower_box",true),"Atomic purchase and placement commits")
	state.load_state()
	_check(state.data.coins==coins-25 and state.data.decorations_owned.flower_box and state.data.decorations_placed.flower_box,"Reload sees complete purchase and placement")
	state.free()


func _write_file(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Unable to write test fixture: " + path)
		return
	file.store_string(content)
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	var directory: DirAccess = DirAccess.open(_test_directory)
	if directory == null:
		return
	for filename: String in directory.get_files():
		directory.remove(filename)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_directory))
