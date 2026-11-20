extends SceneTree
## Long-running saves and failed writes must not reset reward eligibility.
const StateScript = preload("res://scripts/game_state.gd")
const Ledger = preload("res://core/progression_ledger.gd")
var checks := 0
var failures: Array[String] = []
var test_dir := "user://progression-integrity-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("PROGRESSION_INTEGRITY: " + label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	_test_long_save()
	_test_long_commission_history()
	_test_daily_and_cooldown_history()
	_test_invalid_and_zero_rewards()
	_test_inventory_limit()
	var directory := DirAccess.open(test_dir)
	for file_name: String in directory.get_files():
		directory.remove(file_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))
	print("PROGRESSION_INTEGRITY: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_long_save() -> void:
	var state = StateScript.new()
	state.save_path = test_dir + "/large.json"
	for i in range(2105):
		state.data.progression.claimed_once["palace:entry-%04d" % i] = true
	state.data.progression.exp = 9000
	_check(state.save_state(), "large progressed save commits")
	state.load_state()
	_check(state.data.progression.claimed_once.size() == 2105, "all first-clear receipts survive reload")
	var reward: Dictionary = state.grant_exp({"key":"palace:entry-2104", "mode":"once", "base_exp":16, "coin_bonus":3})
	_check(int(reward.get("exp_gained", 0)) == 0, "late first-clear receipt prevents duplicate reward")
	var before: Dictionary = state.snapshot()
	var started := Time.get_ticks_usec()
	for i in range(100):
		state.level()
		state.exp_total()
		state.progression_summary()
	print("PROGRESSION_READ_BENCHMARK_US=", Time.get_ticks_usec() - started)
	_check(state.snapshot() == before, "HUD queries leave progression untouched")
	state.free()

func _test_long_commission_history() -> void:
	var state = StateScript.new()
	state.save_path = test_dir + "/commissions.json"
	for i in range(280):
		state.data.v4.completed_commissions.append("unit-commission-%03d" % i)
	_check(state.save_state(), "large commission ledger commits")
	state.load_state()
	_check(state.data.v4.completed_commissions.size() == 280, "completed commissions never expire after 240 entries")
	var coins: int = state.data.coins
	_check(state.complete_v4_commission("unit-commission-000", 6) and state.data.coins == coins, "old commission cannot pay again")
	_check(state.record_stealth_evidence({"word":"apple", "commission_id":"unit-commission-000", "coin_bonus":6}) and state.data.coins == coins, "evidence settlement respects complete commission history")
	var good: Dictionary = state.snapshot()
	state.save_state()
	var broken: Dictionary = good.duplicate(true)
	broken.progression.exp = ["not a number"]
	var file := FileAccess.open(state.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(broken))
	file.close()
	state.load_state()
	_check(state.snapshot() == good, "malformed progression recovers known-good save backup")
	state.free()

	var prog := Ledger.fresh()
	var prefix := "palace:" + "a".repeat(76)
	prog.claimed_once[prefix + "one"] = true
	prog.claimed_once[prefix + "two"] = true
	var normalized: Dictionary = Ledger.normalize(prog)
	_check(normalized.ok and normalized.value.claimed_once.size() == 2, "distinct long event IDs never collapse")

func _test_daily_and_cooldown_history() -> void:
	var state = StateScript.new()
	for i in range(520):
		Ledger.apply_exp_event(state.data, {"key":"palace:%04d" % i, "mode":"daily_repeat", "base_exp":16, "repeat_exp":8}, 1000)
	var repeat: Dictionary = Ledger.apply_exp_event(state.data, {"key":"palace:0000", "mode":"daily_repeat", "repeat_exp":8}, 1020)
	_check(int(repeat.exp_gained) == 0, "same-day cap survives more than 500 visited stories")
	state.data.day = 2
	repeat = Ledger.apply_exp_event(state.data, {"key":"palace:0000", "mode":"daily_repeat", "repeat_exp":8}, 1100)
	_check(int(repeat.exp_gained) == 8, "next-day review still rewards once")
	state.data = state._default_state()
	for i in range(1020):
		Ledger.apply_exp_event(state.data, {"key":"word_study:%04d" % i, "mode":"word_study"}, 2000)
	repeat = Ledger.apply_exp_event(state.data, {"key":"word_study:0000", "mode":"word_study"}, 2020)
	_check(int(repeat.exp_gained) == 0, "active cooldown survives more than 1000 studied words")
	repeat = Ledger.apply_exp_event(state.data, {"key":"word_study:0000", "mode":"word_study", "repeat_exp":1}, 2400)
	_check(int(repeat.exp_gained) == 1, "expired cooldown still permits practice")
	state.free()

func _test_invalid_and_zero_rewards() -> void:
	for malformed: Dictionary in [{"exp":"ten"}, {"exp":-2}, {"claimed_once":[]}, {"claimed_once":{"a":"false"}}, {"daily_claims":{"a":{"day":1,"count":-1}}}]:
		_check(not Ledger.normalize(malformed).ok, "malformed progression rejected: " + str(malformed))
	var state = StateScript.new()
	state.save_path = test_dir + "/zero.json"
	var empty_reward: Dictionary = state.grant_exp({"key":"no_gift", "mode":"once", "base_exp":0})
	_check(bool(empty_reward.get("changed", false)), "zero-value receipt is committed")
	state.load_state()
	_check(bool(state.data.progression.claimed_once.get("no_gift", false)), "zero-value receipt survives reload")
	var blocker := FileAccess.open(test_dir + "/blocked", FileAccess.WRITE)
	blocker.store_string("fixture")
	blocker.close()
	state.save_path = test_dir + "/blocked/save.json"
	var before: Dictionary = state.snapshot()
	state.grant_exp({"key":"no_gift_failed", "mode":"once", "base_exp":0})
	_check(state.snapshot() == before, "failed zero-value receipt rolls back")
	state.free()

func _test_inventory_limit() -> void:
	var state = StateScript.new()
	state.save_path = test_dir + "/inventory.json"
	state.data.v4.free_decor_owned.sunflower_rug = 99
	var before: Dictionary = state.snapshot()
	_check(not state.buy_free_decor("sunflower_rug", 12), "full furniture stack rejects another purchase")
	_check(state.snapshot() == before, "full furniture stack preserves wallet")
	state.free()
