extends SceneTree

const House = preload("res://scripts/home_catalog.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(label: String, value: bool) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.save_path = "user://home-state-validation-%d.json" % OS.get_process_id()
	var old: Dictionary = state.snapshot()
	old.life.erase("home_tasks")
	var migrated: Dictionary = state._normalize_state(old)
	check("old_save_has_empty_household_experiences", migrated.ok and migrated.state.life.home_tasks.is_empty())
	check("migration_preserves_journey", migrated.state.journey == old.journey)
	check("migration_preserves_learning", migrated.state.learning == old.learning)
	var all_rooms: Array[String] = House.ROOMS.duplicate()
	all_rooms.append_array(["school","classroom","music_room","art_room","science_room","canteen","playground","football_field"])
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ": all_rooms.append("landmark_" + letter)
	var full: Dictionary = state.snapshot()
	for rid: String in all_rooms:
		for i in range(1, 6): full.life.discoveries["%s/memory_%02d" % [rid, i]] = true
	check("all_210_memory_points_fit_save", full.life.discoveries.size() == 210 and state._normalize_state(full).ok)
	full.life.discoveries["home_unknown/memory_01"] = true
	check("unknown_room_rejected", not state._normalize_state(full).ok)
	var before: Dictionary = state.snapshot()
	check("wrong_room_task_rejected", not state.complete_home_task("make_bed", "home_kitchen"))
	check("unknown_task_rejected", not state.complete_home_task("invented_task", "home"))
	check("invalid_requests_unchanged", state.snapshot() == before)
	for entry: Dictionary in House.all().rooms:
		check("task_commit/" + str(entry.room_id), state.complete_home_task(str(entry.task.id), str(entry.room_id)))
	check("all_tasks_saved", state.data.life.home_tasks.size() == 8)
	check("learning_unchanged", state.data.learning == before.learning and state.data.completed_units == before.completed_units)
	check("economy_unchanged", state.data.coins == before.coins)
	var completed: Dictionary = state.snapshot()
	state.load_state()
	check("household_save_reload", state.snapshot() == completed)
	check("replay_is_idempotent", state.complete_home_task("make_bed", "home_bedroom") and state.snapshot() == completed)
	var malformed: Dictionary = completed.duplicate(true)
	malformed.life.home_tasks.make_bed = "true"
	check("malformed_experience_rejected", not state._normalize_state(malformed).ok)
	malformed = completed.duplicate(true)
	malformed.life.home_tasks.unknown = true
	check("unknown_experience_rejected", not state._normalize_state(malformed).ok)
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = state.save_path + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.queue_free()
	var report := {"status":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures}
	var file := FileAccess.open("res://../docs/verification/home-hierarchy-v1/state-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
