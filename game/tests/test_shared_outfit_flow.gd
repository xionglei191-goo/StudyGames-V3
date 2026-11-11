extends SceneTree
## Exercise the actual game/client/wardrobe/exit-save path in an isolated harness.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("This test requires -- --test-harness to isolate the game save")
		quit(2)
		return
	var game: Node3D = load("res://scripts/main.gd").new()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 20000
	while not game.scene_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(game.scene_ready, "Actual game scene loads in the isolated harness")
	if not game.scene_ready:
		quit(1)
		return
	var state: Node = root.get_node("State")
	_check(str(state.save_path).begins_with("user://validation-"), "Harness uses only a validation save")
	state.set_outfit("blue")
	var online: Node = load("res://scripts/online_client.gd").new()
	game.add_child(online)
	online.setup(game, {"shared_save":true,"profile_id":"0123456789abcdef01234567","profile_nickname":"测试"})
	await online.act({"type":"outfit","outfit":"pink"})
	_check(state.data.outfit == "pink", "Client outfit command commits pink in State")
	_check(JSON.parse_string(FileAccess.get_file_as_string(state.save_path)).outfit == "pink", "Client outfit command writes pink before publish")
	_check(online.snapshot().members[0].outfit == "pink", "Solo report reads latest pink State")
	for frame: int in range(10):
		game._refresh()
		game.ui.update_outfit("blue") # A stale visual refresh cannot mutate State.
		await process_frame
	_check(state.data.outfit == "pink", "Stale wardrobe visual updates never write blue back into State")
	_check(game.journey.close_memory(), "Normal exit preflight succeeds")
	_check(state.data.outfit == "pink" and state.save_state(), "Exit save retains the committed outfit")
	state.load_state()
	_check(state.data.outfit == "pink", "Exit save reload is still pink")
	game.queue_free()
	await process_frame
	for suffix: String in ["", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path) + suffix)
	for failure: String in failures:
		push_error(failure)
	print("SHARED_OUTFIT_FLOW checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
