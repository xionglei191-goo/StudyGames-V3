extends Node
## Invitation-room presence. Personal progression remains entirely in game_state.gd.

const Friend = preload("res://scripts/online_friend.gd")
const PROTOCOL := 1
var game: Node3D
var config: Dictionary = {}
var socket: WebSocketPeer
var peers: Dictionary = {}
var members: Array = []
var group: Node3D
var status := "connecting"
var message := "正在进入朋友的小岛…"
var my_id := ""
var room_code := ""
var host_id := ""
var greeted := false
var connected := false
var stopped := false
var seq := 0
var send_clock := 0.0
var bridge_clock := 0.0
var retry_clock := 0.0
var retry_count := 0
var disconnected_for := 0.0
var connect_clock := 0.0
var command_busy := false
var last_position := Vector3.ZERO
var last_scene := ""
var received_snapshots := 0
var solo := false

static func configuration() -> Dictionary:
	var parsed: Variant = null
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("window.AlphabetIslandOnline ? window.AlphabetIslandOnline.readConfig() : '{}'", true)
		if raw is String:
			parsed = JSON.parse_string(raw)
	else:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--online-config="):
				var path := arg.trim_prefix("--online-config=")
				if FileAccess.file_exists(path):
					parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var pattern := RegEx.new()
	pattern.compile("^[a-f0-9]{16,32}$")
	if pattern.search(str(parsed.get("profile_id", ""))) == null:
		return {}
	if bool(parsed.get("shared_save", false)) and str(parsed.get("token", "")).is_empty():
		return parsed
	for key: String in ["token", "id", "ws_url"]:
		if not parsed.get(key) is String or str(parsed[key]).is_empty():
			return {}
	if not str(parsed.ws_url).begins_with("ws://") and not str(parsed.ws_url).begins_with("wss://"):
		return {}
	return parsed

func setup(owner_game: Node3D, session: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = owner_game
	config = session.duplicate(true)
	solo = bool(config.get("shared_save", false)) and str(config.get("token", "")).is_empty()
	my_id = str(config.get("id", config.profile_id))
	room_code = str(config.get("code", ""))
	group = Node3D.new()
	group.name = "OnlineFriends"
	game.add_child(group)
	last_position = game.player.position
	last_scene = game.room
	if solo:
		status = "solo"
		message = "我的小岛 · 网页单人"
		host_id = my_id
	else:
		_connect_socket()

func _connect_socket() -> void:
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 65536
	socket.outbound_buffer_size = 65536
	socket.max_queued_packets = 64
	greeted = false
	connect_clock = 0.0
	var result := socket.connect_to_url(str(config.ws_url))
	if result != OK:
		_disconnected()

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	bridge_clock += delta
	if bridge_clock >= 0.2:
		bridge_clock = 0.0
		_browser_commands()
		_publish()
	if solo or socket == null:
		return
	for peer: Node3D in peers.values():
		peer.visible = connected and not game.loading_room and peer.online and peer.scene_id == game.room
	if stopped:
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not greeted:
			greeted = true
			_send({"type":"hello", "protocol":PROTOCOL, "token":config.token})
		var packets := 0
		while socket.get_available_packet_count() > 0 and packets < 64:
			packets += 1
			var raw := socket.get_packet()
			if raw.size() > 65536:
				continue
			var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
			if value is Dictionary:
				_receive(value)
		if connected:
			send_clock += delta
			if send_clock >= 0.10 and game.scene_ready and not game.loading_room:
				send_clock = 0.0
				_send_pose()
	elif state == WebSocketPeer.STATE_CONNECTING:
		connect_clock += delta
		if connect_clock > 10.0:
			socket.close()
			_disconnected()
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected or status == "connecting":
			_disconnected()
		disconnected_for += delta
		retry_clock -= delta
		if disconnected_for >= 85.0:
			_finish("连接暂时没有恢复，请返回入口重新加入。")
		elif retry_clock <= 0:
			retry_count += 1
			retry_clock = minf(pow(2, mini(retry_count, 4)), 10.0)
			_connect_socket()

func _send(value: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(value))

func _send_pose() -> void:
	var point: Vector3 = game.player.position
	seq += 1
	_send({"type":"pose", "seq":seq, "scene":game.room,
		"p":[point.x, point.y, point.z], "r":game.player.visual.rotation.y,
		"moving":game.room == last_scene and point.distance_to(last_position) > 0.012,
		"outfit":str(State.data.outfit)})
	last_position = point
	last_scene = game.room

func _receive(value: Dictionary) -> void:
	match str(value.get("type", "")):
		"welcome":
			if str(value.get("id", "")) != my_id:
				_finish("角色信息不一致，请返回入口重新加入。")
				return
			connected = true
			status = "online"
			message = "已和朋友连上小岛"
			disconnected_for = 0.0
			retry_count = 0
			_apply_room(value.get("room", {}))
			_send_pose()
		"snapshot":
			_apply_room(value.get("room", {}))
		"wave":
			var id := str(value.get("id", ""))
			if id == my_id:
				game.player.gesture("wave")
			elif peers.has(id):
				peers[id].wave()
		"error":
			_finish(str(value.get("error", "这次邀请已结束，请重新加入。")))

func _apply_room(value: Variant) -> void:
	if not value is Dictionary or not value.get("members") is Array:
		return
	room_code = str(value.get("code", room_code))
	host_id = str(value.get("host", ""))
	members = value.members.duplicate(true)
	received_snapshots += 1
	var seen: Array[String] = []
	for member: Variant in members:
		if not member is Dictionary:
			continue
		var id := str(member.get("id", ""))
		if id.is_empty() or id == my_id:
			continue
		seen.append(id)
		if not peers.has(id):
			var friend := Friend.new()
			friend.name = "Friend_" + id
			group.add_child(friend)
			friend.setup(str(member.get("nickname", "朋友")))
			friend.reduced_motion = game.ui.reduced_motion
			peers[id] = friend
		peers[id].apply_member(member, game.room)
	for id: String in peers.keys():
		if id not in seen:
			peers[id].queue_free()
			peers.erase(id)

func _disconnected() -> void:
	connected = false
	status = "reconnecting"
	message = "连接断开了，正在重新找朋友…"
	retry_clock = minf(pow(2, mini(retry_count, 4)), 10.0)
	_publish()

func _finish(text: String) -> void:
	connected = false
	stopped = true
	status = "ended"
	message = text
	if socket != null:
		socket.close()
	_publish()

func _browser_commands() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval("window.AlphabetIslandOnline ? window.AlphabetIslandOnline.takeCommands() : '[]'", true)
	if not raw is String:
		return
	var commands: Variant = JSON.parse_string(raw)
	if commands is Array:
		for command: Variant in commands:
			if command is Dictionary:
				act(command)

func act(command: Dictionary) -> void:
	var kind := str(command.get("type", ""))
	if kind == "exit_cancel":
		game.get_tree().paused = false
		return
	if kind == "leave":
		game._request_quit()
		return
	if game.get_tree().paused:
		return
	if (not connected and not solo) or command_busy or game.loading_room:
		return
	match str(command.get("type", "")):
		"wave":
			if solo:
				game.player.gesture("wave")
			else:
				_send({"type":"wave"})
		"outfit":
			var outfit := str(command.get("outfit", ""))
			if outfit in ["yellow", "pink", "blue"]:
				State.set_outfit(outfit)
		"follow":
			var id := str(command.get("id", ""))
			if not peers.has(id) or not peers[id].online or not peers[id].initialized:
				return
			if game.ui.modal.visible:
				game.ui.notify("先收好当前这一页，再去找朋友吧。")
				return
			command_busy = true
			var scene: String = peers[id].scene_id
			if scene != game.room:
				await game.change_room(scene)
			if peers.has(id) and game.room == peers[id].scene_id:
				game.navigate_to(peers[id].target)
			command_busy = false

func snapshot() -> Dictionary:
	if solo:
		members = [{"id":my_id, "nickname":str(config.get("profile_nickname", "我的角色")),
			"outfit":str(State.data.outfit), "online":true,
			"pose":{"scene":game.room, "p":[game.player.position.x, game.player.position.y, game.player.position.z]}}]
	var visible_peers: Array = []
	for id: String in peers:
		var friend: Node3D = peers[id]
		if friend.visible:
			visible_peers.append({"id":id, "p":[friend.position.x, friend.position.y, friend.position.z], "outfit":friend.outfit})
	return {"status":status, "message":message, "id":my_id, "code":room_code,
		"host":host_id, "scene":game.room, "members":members,
		"visible_peers":visible_peers, "received_snapshots":received_snapshots,
		"position":[game.player.position.x, game.player.position.y, game.player.position.z]}

func _publish() -> void:
	if not OS.has_feature("web") or not is_instance_valid(game):
		return
	var data := JSON.stringify(snapshot())
	JavaScriptBridge.eval("if (window.AlphabetIslandOnline) window.AlphabetIslandOnline.report(" + JSON.stringify(data) + ");", true)

func _exit_tree() -> void:
	if socket != null:
		socket.close()
