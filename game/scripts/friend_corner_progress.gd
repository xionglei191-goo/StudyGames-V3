extends RefCounted
## U2 keepsakes share the chapter transaction. Preview drafts never replace the displayed layout.

const RECIPIENTS: Array[String] = ["textbook_lingling", "textbook_tim"]
const STYLES: Array[String] = ["plain", "flowers", "star"]
const SLOTS: Array[String] = ["", "left", "right", "lower"]
const REWARD_ID := "event/xiangshao-g3-1/unit-2/friend-corner-v1"
const REWARD_ITEMS: Array[String] = ["reply_lingling", "reply_tim", "letter_clips"]
const FRIEND_ROOMS := {"textbook_lingling":"school", "textbook_tim":"landmark_M"}

static func empty_layout() -> Dictionary:
	return {"style":"flowers", "positions":{"textbook_lingling":"", "textbook_tim":""}}

static func fresh() -> Dictionary:
	return {"schema_version":1, "invitation_styles":{"textbook_lingling":"plain", "textbook_tim":"plain"},
		"reward_receipt":{}, "layout":empty_layout(), "draft":{}, "revision":0,
		"displayed_at":0.0, "conversations":{}}

static func grant(state: Dictionary) -> void:
	if not state.chapters["2"].completed: return
	var corner: Dictionary = state.friend_corner
	if not corner.reward_receipt.is_empty(): return
	corner.reward_receipt = {"id":REWARD_ID, "source":"unit-2/chapter", "at":float(state.receipts["unit-2/chapter"].at)}

static func owns_replies(corner: Dictionary) -> bool:
	return not corner.reward_receipt.is_empty()

static func placed_count(layout: Dictionary) -> int:
	var count := 0
	for id: String in RECIPIENTS:
		if not str(layout.positions[id]).is_empty(): count += 1
	return count

static func apply(journey: Dictionary, event: Dictionary, now: float) -> Dictionary:
	if not _time(now): return _fail("还没记好这次时间，请再试一下。")
	var state: Dictionary = journey.p2
	var corner: Dictionary = state.friend_corner
	var kind := str(event.get("kind", ""))
	if kind == "corner_cover":
		var recipient: Variant = event.get("recipient")
		var style: Variant = event.get("style")
		if recipient not in RECIPIENTS or style not in STYLES: return _fail("请选择这张邀请的信纸。")
		if not journey.u1.completed or journey.selected_book_id != "xiangshao-g3-1" or event.get("room") != "landmark_Z":
			return _fail("先到邮局，和熊叔一起准备邀请。")
		if state.mail.has(recipient): return _fail("这张邀请已经寄出，朋友会记得当时的样子。")
		if corner.invitation_styles[recipient] == style: return _ok(false)
		corner.invitation_styles[recipient] = style
		return _ok()
	if not owns_replies(corner): return _fail("先把两封邀请送好，再收下朋友的回信。")
	if kind == "corner_friend_seen":
		var recipient: Variant = event.get("recipient")
		if recipient not in RECIPIENTS or event.get("room") != FRIEND_ROOMS[recipient]: return _fail("到朋友身边，再聊聊那封邀请吧。")
		if corner.conversations.has(recipient): return _ok(false)
		corner.conversations[recipient] = now
		return _ok()
	if event.get("room") != "home": return _fail("回到自己的小屋，再摆放这些回忆吧。")
	match kind:
		"corner_begin":
			if not corner.draft.is_empty(): return _ok(false)
			corner.draft = corner.layout.duplicate(true)
		"corner_style":
			if corner.draft.is_empty() or event.get("style") not in ["flowers", "star"]: return _fail("先打开试摆，再选一个喜欢的样子。")
			if corner.draft.style == event.style: return _ok(false)
			corner.draft.style = event.style
		"corner_place":
			var recipient: Variant = event.get("recipient")
			var slot: Variant = event.get("slot")
			if corner.draft.is_empty() or recipient not in RECIPIENTS or slot not in SLOTS: return _fail("先选一封回信，再选展示位置。")
			var previous := str(corner.draft.positions[recipient])
			if previous == slot: return _ok(false)
			for other: String in RECIPIENTS:
				if other != recipient and not str(slot).is_empty() and corner.draft.positions[other] == slot:
					corner.draft.positions[other] = previous
			corner.draft.positions[recipient] = slot
		"corner_cancel":
			if corner.draft.is_empty(): return _ok(false)
			corner.draft = {}
		"corner_confirm":
			if corner.draft.is_empty(): return _ok(false)
			if corner.draft != corner.layout:
				if int(corner.revision) >= 1_000_000: return _fail("这次摆放暂时无法保存。")
				corner.layout = corner.draft.duplicate(true)
				corner.revision += 1
			corner.draft = {}
			if placed_count(corner.layout) == 2 and float(corner.displayed_at) == 0.0: corner.displayed_at = now
		_:
			return _fail("这个朋友角动作还没有准备好。")
	return _ok()

static func normalize(value: Variant, state: Dictionary, u1_completed: bool) -> Dictionary:
	var result := fresh()
	if value == null:
		# Old chapters own their original keepsakes; no new money, attempts or dates are inferred.
		var migrated := state.duplicate(true)
		migrated.friend_corner = result
		grant(migrated)
		return {"ok":true, "value":migrated.friend_corner}
	if not value is Dictionary or value.size() != result.size() or value.get("schema_version") != 1: return {"ok":false}
	var styles: Variant = value.get("invitation_styles")
	if not styles is Dictionary or styles.size() != 2: return {"ok":false}
	for id: String in RECIPIENTS:
		if styles.get(id) not in STYLES or (styles[id] != "plain" and not u1_completed): return {"ok":false}
		result.invitation_styles[id] = styles[id]
	var receipt: Variant = value.get("reward_receipt")
	if not receipt is Dictionary: return {"ok":false}
	if state.chapters["2"].completed:
		if receipt.size() != 3 or receipt.get("id") != REWARD_ID or receipt.get("source") != "unit-2/chapter" or not _time(receipt.get("at")): return {"ok":false}
		if float(receipt.at) != float(state.receipts["unit-2/chapter"].at): return {"ok":false}
		result.reward_receipt = {"id":REWARD_ID, "source":"unit-2/chapter", "at":float(receipt.at)}
	elif not receipt.is_empty(): return {"ok":false}
	if not _valid_layout(value.get("layout")) or not value.get("draft") is Dictionary: return {"ok":false}
	if not value.draft.is_empty() and not _valid_layout(value.draft): return {"ok":false}
	if not _integer(value.get("revision")) or not _time(value.get("displayed_at")): return {"ok":false}
	if not owns_replies(result) and (placed_count(value.layout) > 0 or not value.draft.is_empty() or int(value.revision) > 0 or float(value.displayed_at) > 0): return {"ok":false}
	if float(value.displayed_at) > 0 and int(value.revision) == 0: return {"ok":false}
	if placed_count(value.layout) == 2 and float(value.displayed_at) == 0: return {"ok":false}
	result.layout = value.layout.duplicate(true)
	result.draft = value.draft.duplicate(true)
	result.revision = int(value.revision)
	result.displayed_at = float(value.displayed_at)
	var conversations: Variant = value.get("conversations")
	if not conversations is Dictionary or conversations.size() > 2: return {"ok":false}
	for id: Variant in conversations:
		if id not in RECIPIENTS or not owns_replies(result) or not _time(conversations[id]): return {"ok":false}
		result.conversations[id] = float(conversations[id])
	return {"ok":true, "value":result}

static func _valid_layout(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or value.get("style") not in ["flowers", "star"]: return false
	if not value.get("positions") is Dictionary or value.positions.size() != 2: return false
	var used: Array = []
	for id: String in RECIPIENTS:
		if value.positions.get(id) not in SLOTS: return false
		var slot: String = value.positions[id]
		if not slot.is_empty():
			if used.has(slot): return false
			used.append(slot)
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= 1_000_000

static func _time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

static func _ok(changed: bool = true) -> Dictionary:
	return {"ok":true, "changed":changed}

static func _fail(message: String) -> Dictionary:
	return {"ok":false, "message":message}
