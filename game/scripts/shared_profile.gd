extends RefCounted
## Select and bootstrap a shared save before game_state.load_state ever runs.

static func prepare(state: Node, config: Dictionary, args: PackedStringArray, validation: bool) -> Dictionary:
	state.shared_web_save = false
	if validation:
		state.save_path = "user://validation-%s.json" % OS.get_process_id()
		return {"ok":true}
	if OS.has_feature("web") and bool(config.get("shared_save", false)):
		return _prepare_web(state, config)
	if not OS.has_feature("web"):
		var native := native_configuration(args)
		if not native.get("ok", false):
			return native
		if native.has("save_path"):
			state.save_path = native.save_path
			var primary_exists := FileAccess.file_exists(state.save_path)
			var backup_exists := FileAccess.file_exists(state.save_path + ".bak")
			native["fresh"] = not primary_exists and not backup_exists
			if primary_exists or backup_exists:
				var primary_valid: bool = state._read_valid_file(state.save_path).get("ok", false)
				var backup_valid: bool = state._read_valid_file(state.save_path + ".bak").get("ok", false)
				if not primary_valid and not backup_valid:
					return _failure("共享存档和备份均未通过游戏完整校验，已有进度未被修改，请先恢复有效副本。")
			return native
	# Existing native network-validation fixtures continue using isolated profile files.
	if not config.is_empty():
		var profile_root := "/userfs/online-profiles/" if OS.has_feature("web") else "user://online-profiles/"
		state.save_path = profile_root + str(config.profile_id) + "/progress.json"
	return {"ok":true}

static func native_configuration(args: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	for arg: String in args:
		for key: String in ["path", "id", "session", "nonce"]:
			var prefix := "--shared-profile-" + key + "="
			if arg.begins_with(prefix):
				values[key] = arg.trim_prefix(prefix)
	if values.is_empty():
		return {"ok":true}
	for key: String in ["path", "id", "session", "nonce"]:
		if str(values.get(key, "")).is_empty():
			return _failure("共享角色启动信息不完整，请使用游戏入口重新进入。")
	var pattern := RegEx.new()
	pattern.compile("^[a-f0-9]{24}$")
	var path := str(values.path).replace("\\", "/")
	var session_path := str(values.session).replace("\\", "/")
	if pattern.search(str(values.id)) == null or not path.is_absolute_path() or path != path.simplify_path():
		return _failure("共享角色存档路径无效，请使用游戏入口重新进入。")
	if path.get_file() != "progress.json" or path.get_base_dir().get_file() != values.id:
		return _failure("共享角色与存档目录不一致，已有进度未被修改。")
	if not session_path.is_absolute_path() or session_path.get_base_dir() != path.get_base_dir():
		return _failure("共享角色锁定信息无效，请使用游戏入口重新进入。")
	if not FileAccess.file_exists(session_path):
		return _failure("角色尚未锁定，请使用游戏入口重新进入。")
	var session: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
	if not session is Dictionary:
		return _failure("角色启动记录无法读取，已有进度未被修改。")
	var matching := str(session.get("profile_id", "")) == str(values.id)
	matching = matching and str(session.get("save_path", "")).replace("\\", "/") == path
	matching = matching and str(session.get("nonce", "")) == str(values.nonce)
	# Godot's process registry does not reliably identify external Python parents.
	# The runner passes this nonce only into its job-owned child environment.
	matching = matching and OS.get_environment("ALPHABET_SHARED_NONCE") == str(values.nonce)
	matching = matching and int(session.get("supervisor_pid", 0)) > 0
	matching = matching and OS.get_environment("ALPHABET_SHARED_SUPERVISOR").to_int() == int(session.get("supervisor_pid", 0))
	if not matching:
		return _failure("角色锁定已失效，请关闭游戏后从入口重新进入。")
	return {"ok":true, "save_path":path, "profile_id":values.id,
		"nickname":str(session.get("nickname", "我的角色")), "outfit":str(session.get("outfit", "yellow"))}

static func _prepare_web(state: Node, config: Dictionary) -> Dictionary:
	state.save_path = "/userfs/online-profiles/" + str(config.profile_id) + "/progress.json"
	var raw: Variant = JavaScriptBridge.eval("window.AlphabetIslandOnline.initialSave()", true)
	if not raw is String:
		return _failure("共享进度尚未准备好，请返回入口重试。")
	if str(raw).is_empty() and bool(config.get("pending_browser_import", false)) and not FileAccess.file_exists(state.save_path):
		return _failure("旧角色的进度仍在原浏览器中。请回到原浏览器、原来的游戏网址完成导入并保存返回，再从这里继续。")
	if not str(raw).is_empty():
		var result := install_initial_save(state, str(raw))
		if not result.ok:
			return result
	elif FileAccess.file_exists(state.save_path):
		if not state._read_valid_file(state.save_path).get("ok", false) and not state._read_valid_file(state.save_path + ".bak").get("ok", false):
			return _failure("原网页进度无法完整读取，导入已暂停；原文件仍保留在浏览器中。")
		# A legacy browser role is imported once; retain its exact source alongside it.
		var legacy_copy: String = state.save_path + ".legacy-import-copy"
		if not FileAccess.file_exists(legacy_copy):
			if DirAccess.copy_absolute(state.save_path, legacy_copy) != OK:
				return _failure("无法保留原网页进度，导入已暂停，请检查浏览器存储空间。")
	state.shared_web_save = true
	return {"ok":true, "nickname":str(config.get("profile_nickname", "我的角色"))}

static func install_initial_save(state: Node, raw: String) -> Dictionary:
	var incoming := JSON.new()
	if incoming.parse(raw) != OK or not state._normalize_state(incoming.data).get("ok", false):
		return _failure("共享存档未通过完整校验，原进度已保留，请在入口选择恢复副本。")
	var path: String = state.save_path
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return _failure("无法准备浏览器存档目录，请检查存储空间。")
	# Server canonical data is authoritative only after the shell resolved local drafts.
	# A pre-existing local copy is retained for diagnosis/recovery, never rotated away here.
	if FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".before-shared-copy"):
		if DirAccess.copy_absolute(path, path + ".before-shared-copy") != OK:
			return _failure("无法保留本页原进度，加载已暂停。")
	var pending := path + ".shared-incoming"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return _failure("无法写入浏览器存档，请检查存储空间。")
	file.store_string(raw)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(pending, path) != OK:
		return _failure("共享进度尚未完整保存到本页，请返回入口重试。")
	return {"ok":true}

static func _failure(message: String) -> Dictionary:
	return {"ok":false, "message":message}
