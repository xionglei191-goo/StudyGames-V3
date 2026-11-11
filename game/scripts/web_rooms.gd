extends RefCounted
## Optional web asset packs; native builds continue to use the existing local resources.

static var loaded: Dictionary = {}

static func ensure_room(host: Node, room_id: String) -> bool:
	if not OS.has_feature("web") or loaded.has(room_id):
		return true
	var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.ALPHABET_ROOM_PACKS || {})", true)
	var manifest: Variant = JSON.parse_string(str(raw))
	if not manifest is Dictionary or not manifest.has(room_id):
		# A standard Web Preview export still carries every room in its main pack.
		return ResourceLoader.exists("res://assets/interiors/%s.glb" % room_id)
	var entry: Dictionary = manifest[room_id]
	var cache_path := "/userfs/web-room-cache/%s.pck" % room_id
	_report("正在准备这个地方…", true)
	# The browser fetches into Godot's memory filesystem. HTTPRequest's web
	# download_file path timed out on the inspected single-threaded template.
	JavaScriptBridge.eval("window.AlphabetIslandOnline.downloadRoom(" + JSON.stringify(room_id) + ");", true)
	var result: Dictionary = {}
	var deadline := Time.get_ticks_msec() + 65000
	while not bool(result.get("done", false)) and Time.get_ticks_msec() < deadline:
		await host.get_tree().create_timer(0.05).timeout
		var state: Variant = JavaScriptBridge.eval("window.AlphabetIslandOnline.roomDownloadStatus(" + JSON.stringify(room_id) + ");", true)
		var parsed: Variant = JSON.parse_string(str(state))
		if parsed is Dictionary:
			result = parsed
	var valid := bool(result.get("ok", false))
	if valid:
		valid = FileAccess.get_sha256(cache_path) == str(entry.sha256)
	if valid:
		valid = ProjectSettings.load_resource_pack(cache_path, false)
	if valid:
		valid = ResourceLoader.exists("res://assets/interiors/%s.glb" % room_id)
	if valid:
		loaded[room_id] = true
	_report("", false)
	return valid

static func _report(text: String, visible: bool) -> void:
	JavaScriptBridge.eval("if (window.AlphabetIslandOnline) window.AlphabetIslandOnline.roomLoading(" + JSON.stringify(text) + "," + str(visible).to_lower() + ");", true)
