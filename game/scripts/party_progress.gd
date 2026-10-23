extends RefCounted
## A small, replayable U3 keepsake. No currency, chapter or learning fields are touched.
const GUESTS: Array[String] = ["textbook_mingming","textbook_dongdong","textbook_tim","textbook_anne"]
const SEATS: Array[String] = ["seat_1","seat_2","seat_3","seat_4"]
const THEMES: Array[String] = ["flowers","star"]
const BEATS: Array[String] = ["welcome","names","together","goodbye"]
const DURATIONS: Array[float] = [4.0,5.0,5.0,4.0]

static func empty_layout() -> Dictionary:
	return {"theme":"flowers","seats":{"textbook_mingming":"","textbook_dongdong":"","textbook_tim":"","textbook_anne":""}}

static func fresh() -> Dictionary:
	return {"schema_version":1,"layout":empty_layout(),"draft":{},"revision":0,"confirmed_at":0.0,"sequence":0,"playback":{},"memory":{}}

static func unlocked(p2: Dictionary) -> bool:
	return p2.get("chapters",{}).get("3",{}).get("completed",false) == true

static func watched(party: Dictionary) -> bool:
	return not party.get("memory",{}).is_empty()

static func theme_name(id: String) -> String:
	return "花朵桌布" if id == "flowers" else "星星桌布"

static func is_arranged(layout: Dictionary) -> bool:
	if not _layout(layout): return false
	for guest: String in GUESTS:
		if str(layout.seats[guest]).is_empty(): return false
	return true

static func apply(journey: Dictionary, event: Dictionary, now: float) -> Dictionary:
	if not _time(now) or now <= 0.0: return _fail("这次时间还没有记好。")
	var p2: Dictionary = journey.p2
	if not unlocked(p2): return _fail("先和四位朋友准备好欢迎桌，再来布置。")
	if event.get("room") != "home": return _fail("回到小屋，再看看我们的欢迎桌。")
	var party: Dictionary = p2.party
	var kind := str(event.get("kind",""))
	match kind:
		"party_begin":
			if not party.playback.is_empty() and not party.playback.finished: return _fail("聚会还没看完，可以接着看，或先结束这次放映。")
			if not party.draft.is_empty(): return _ok(false)
			party.draft = party.layout.duplicate(true)
			# First-time seating is a preview until the child explicitly confirms it.
			if int(party.revision) == 0:
				for index: int in GUESTS.size(): party.draft.seats[GUESTS[index]] = SEATS[index]
		"party_theme":
			if party.draft.is_empty() or event.get("theme") not in THEMES: return _fail("先打开试摆，再选桌布。")
			if party.draft.theme == event.theme: return _ok(false)
			party.draft.theme = event.theme
		"party_seat":
			var guest: Variant = event.get("guest")
			var seat: Variant = event.get("seat")
			if party.draft.is_empty() or guest not in GUESTS or seat not in SEATS: return _fail("先选一位朋友，再点一把椅子。")
			var previous: String = party.draft.seats[guest]
			if previous == seat: return _ok(false)
			for other: String in GUESTS:
				if other != guest and party.draft.seats[other] == seat: party.draft.seats[other] = previous
			party.draft.seats[guest] = seat
		"party_cancel":
			if party.draft.is_empty(): return _ok(false)
			party.draft = {}
		"party_confirm":
			if party.draft.is_empty(): return _ok(false)
			if not is_arranged(party.draft): return _fail("给四位朋友各留一个座位，再确认。")
			if party.draft != party.layout or int(party.revision) == 0:
				if int(party.revision) >= 1000000: return _fail("这次布置暂时无法保存。")
				party.layout = party.draft.duplicate(true)
				party.revision += 1
				if float(party.confirmed_at) == 0.0: party.confirmed_at = now
			party.draft = {}
		"party_play":
			if not party.draft.is_empty() or not is_arranged(party.layout): return _fail("先确认桌布和四个座位，再请朋友入座。")
			if not party.playback.is_empty() and not party.playback.finished: return _ok(false)
			if int(party.sequence) >= 1000000: return _fail("这次聚会暂时无法保存。")
			party.sequence += 1
			party.playback = {"id":"party-%d" % int(party.sequence),"step":0,"started_at":now,"last_at":now,"finished":false,"layout":party.layout.duplicate(true)}
		"party_beat":
			if party.playback.is_empty() or event.get("id") != party.playback.id: return _fail("先打开这次聚会。")
			var playback: Dictionary = party.playback
			var step: Variant = event.get("step")
			if not _integer(step,0,BEATS.size()-1) or event.get("beat") != BEATS[int(step)]: return _fail("聚会的这一幕还没有准备好。")
			if int(step) < int(playback.step): return _ok(false)
			if playback.finished or int(step) != int(playback.step) or now < float(playback.last_at) + DURATIONS[int(step)] - 0.05: return _fail("让朋友把这一幕慢慢说完吧。")
			playback.step += 1
			playback.last_at = now
		"party_finish":
			if party.playback.is_empty() or event.get("id") != party.playback.id: return _fail("先打开这次聚会。")
			if party.playback.finished: return _ok(false)
			if int(party.playback.step) != BEATS.size() or now < float(party.playback.last_at): return _fail("四幕都看完，才会留下一起相聚的回忆。")
			var first_at := now if party.memory.is_empty() else float(party.memory.first_at)
			var views := 1 if party.memory.is_empty() else int(party.memory.views) + 1
			party.memory = {"id":"party-memory-v1","first_at":first_at,"last_at":now,"views":views,"layout":party.playback.layout.duplicate(true)}
			party.playback.finished = true
		"party_abandon":
			if party.playback.is_empty() or party.playback.finished: return _ok(false)
			party.playback = {}
		_:
			return _fail("这个欢迎桌动作还没有准备好。")
	return _ok()

static func normalize(value: Variant, p2: Dictionary) -> Dictionary:
	var result := fresh()
	# Existing U3 completion unlocks arranging; it never proves watching this new scene.
	if value == null: return {"ok":true,"value":result}
	if not value is Dictionary or value.size() != result.size() or value.get("schema_version") != 1: return {"ok":false}
	if not _layout(value.get("layout")) or not value.get("draft") is Dictionary: return {"ok":false}
	if not value.draft.is_empty() and not _layout(value.draft): return {"ok":false}
	if not _integer(value.get("revision"),0,1000000) or not _integer(value.get("sequence"),0,1000000) or not _time(value.get("confirmed_at")): return {"ok":false}
	if not value.get("playback") is Dictionary or not value.get("memory") is Dictionary: return {"ok":false}
	# JSON decodes numbers as floats: validate neutral fields rather than comparing
	# a parsed Dictionary against the integer-typed fresh object.
	if not unlocked(p2) and (int(value.revision) != 0 or int(value.sequence) != 0 or float(value.confirmed_at) != 0.0 or value.layout != empty_layout() or not value.draft.is_empty() or not value.playback.is_empty() or not value.memory.is_empty()): return {"ok":false}
	if int(value.revision) == 0:
		if value.layout != empty_layout() or float(value.confirmed_at) != 0.0 or int(value.sequence) != 0: return {"ok":false}
	elif not is_arranged(value.layout) or float(value.confirmed_at) <= 0.0: return {"ok":false}
	if not value.playback.is_empty():
		var playback: Dictionary = value.playback
		if playback.size() != 6 or int(value.sequence) == 0 or playback.get("id") != "party-%d" % int(value.sequence): return {"ok":false}
		if not _integer(playback.get("step"),0,BEATS.size()) or not playback.get("finished") is bool or not _time(playback.get("started_at")) or not _time(playback.get("last_at")): return {"ok":false}
		if not playback.get("layout") is Dictionary or not is_arranged(playback.layout) or float(playback.started_at) < float(value.confirmed_at): return {"ok":false}
		var elapsed_required := 0.0
		for index: int in int(playback.step): elapsed_required += DURATIONS[index] - 0.05
		if float(playback.last_at) < float(playback.started_at) + elapsed_required: return {"ok":false}
		if playback.finished and (int(playback.step) != BEATS.size() or value.memory.is_empty()): return {"ok":false}
		if not playback.finished and not value.draft.is_empty(): return {"ok":false}
	if not value.memory.is_empty():
		var memory: Dictionary = value.memory
		if memory.size() != 5 or memory.get("id") != "party-memory-v1" or not _time(memory.get("first_at")) or not _time(memory.get("last_at")) or not _integer(memory.get("views"),1,int(value.sequence)): return {"ok":false}
		if not memory.get("layout") is Dictionary or not is_arranged(memory.layout) or float(memory.first_at) < float(value.confirmed_at) or float(memory.last_at) < float(memory.first_at): return {"ok":false}
		if not value.playback.is_empty() and value.playback.finished and (memory.layout != value.playback.layout or float(memory.last_at) < float(value.playback.last_at)): return {"ok":false}
	result = value.duplicate(true)
	result.schema_version = 1
	for key: String in ["revision","sequence"]: result[key] = int(result[key])
	result.confirmed_at = float(result.confirmed_at)
	if not result.playback.is_empty():
		result.playback.step = int(result.playback.step)
		result.playback.started_at = float(result.playback.started_at)
		result.playback.last_at = float(result.playback.last_at)
	if not result.memory.is_empty():
		result.memory.views = int(result.memory.views)
		result.memory.first_at = float(result.memory.first_at)
		result.memory.last_at = float(result.memory.last_at)
	return {"ok":true,"value":result}

static func _layout(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or value.get("theme") not in THEMES or not value.get("seats") is Dictionary or value.seats.size() != GUESTS.size(): return false
	var used: Array[String] = []
	for guest: String in GUESTS:
		var seat: Variant = value.seats.get(guest)
		if seat != "" and seat not in SEATS: return false
		if seat != "":
			if used.has(seat): return false
			used.append(seat)
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

static func _ok(changed: bool = true) -> Dictionary:
	return {"ok":true,"changed":changed}

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
