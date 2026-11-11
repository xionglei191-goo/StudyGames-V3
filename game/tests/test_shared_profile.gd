extends SceneTree
## Tests bootstrapping and refusal without loading the world or a real profile.

const Profile = preload("res://scripts/shared_profile.gd")
const StateScript = preload("res://scripts/game_state.gd")
var failures: Array[String] = []
var checks := 0
var test_root := "user://shared-profile-tests-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main_script: Script = load("res://scripts/main.gd")
	var online_script: Script = load("res://scripts/online_client.gd")
	_check(main_script.can_instantiate() and online_script.can_instantiate(), "Game and online bridge compile with autoloads ready")
	var state := StateScript.new()
	var absolute_root := ProjectSettings.globalize_path(test_root)
	var profile_id := "0123456789abcdef01234567"
	state.save_path = absolute_root.path_join(profile_id).path_join("progress.json")
	_check(state.save_state(), "Prepare isolated canonical fixture")
	var before: String = FileAccess.get_file_as_string(state.save_path)
	_check(not Profile.install_initial_save(state, "{bad").ok, "Reject invalid canonical payload")
	_check(FileAccess.get_file_as_string(state.save_path) == before, "Invalid payload preserves local progress")
	var changed: Dictionary = state.snapshot()
	changed.coins = 87
	changed.outfit = "pink"
	_check(Profile.install_initial_save(state, JSON.stringify(changed)).ok, "Install a complete validated canonical payload")
	state.load_state()
	_check(state.data.coins == 87 and state.data.outfit == "pink", "Load installed canonical state")
	_check(FileAccess.get_file_as_string(state.save_path + ".before-shared-copy") == before, "Preserve exact pre-import browser bytes")
	var session_path := state.save_path.get_base_dir().path_join("native-session-test.json")
	var session := {"profile_id":profile_id, "save_path":state.save_path,
		"supervisor_pid":OS.get_process_id(), "nonce":"test-nonce", "nickname":"测试角色"}
	var session_file := FileAccess.open(session_path, FileAccess.WRITE)
	session_file.store_string(JSON.stringify(session))
	session_file.close()
	var args := PackedStringArray(["--shared-profile-path=" + state.save_path,
		"--shared-profile-id=" + profile_id, "--shared-profile-session=" + session_path,
		"--shared-profile-nonce=test-nonce"])
	var previous_nonce := OS.get_environment("ALPHABET_SHARED_NONCE")
	var previous_supervisor := OS.get_environment("ALPHABET_SHARED_SUPERVISOR")
	OS.set_environment("ALPHABET_SHARED_NONCE", "test-nonce")
	OS.set_environment("ALPHABET_SHARED_SUPERVISOR", str(OS.get_process_id()))
	var result := Profile.native_configuration(args)
	_check(result.ok and result.save_path == state.save_path, "Accept complete live supervisor session")
	args[3] = "--shared-profile-nonce=wrong"
	_check(not Profile.native_configuration(args).ok, "Reject mismatched supervisor nonce")
	args[3] = "--shared-profile-nonce=test-nonce"
	args[0] = "--shared-profile-path=" + absolute_root.path_join("wrong.json")
	_check(not Profile.native_configuration(args).ok, "Reject a path outside role directory")
	_check(not Profile.native_configuration(PackedStringArray(["--shared-profile-id=" + profile_id])).ok, "Reject partial launch arguments")
	_check(Profile.native_configuration(PackedStringArray()).ok, "Editor/raw project keeps its own save behavior")
	args[0] = "--shared-profile-path=" + state.save_path
	var broken: Dictionary = state.snapshot()
	broken.journey = []
	var broken_text := JSON.stringify(broken)
	_write(state.save_path, broken_text)
	_write(state.save_path + ".bak", broken_text)
	_check(not Profile.prepare(state, {}, args, false).ok, "Reject deep-invalid canonical and backup before default state can load")
	_check(FileAccess.get_file_as_string(state.save_path) == broken_text and FileAccess.get_file_as_string(state.save_path + ".bak") == broken_text, "Rejected deep-invalid files remain byte-identical")
	_write(state.save_path + ".bak", before)
	var recover := Profile.prepare(state, {}, args, false)
	_check(recover.ok and not recover.fresh, "Permit a fully valid backup without treating role as fresh")
	state.load_state()
	_check(state.data.coins == 30 and state.data.outfit == "yellow", "Original state loader recovers valid full-schema backup")
	OS.set_environment("ALPHABET_SHARED_NONCE", previous_nonce)
	OS.set_environment("ALPHABET_SHARED_SUPERVISOR", previous_supervisor)
	Profile.prepare(state, {}, args, true)
	_check(state.save_path.begins_with("user://validation-") and not state.shared_web_save, "Test mode takes precedence over shared parameters")
	state.free()
	_cleanup(absolute_root)
	for failure: String in failures:
		push_error(failure)
	print("SHARED_PROFILE_TESTS checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _cleanup(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	for name: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name: String in directory.get_directories():
		_cleanup(path.path_join(name))
	DirAccess.remove_absolute(path)
