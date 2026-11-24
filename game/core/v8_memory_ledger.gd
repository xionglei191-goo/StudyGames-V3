extends RefCounted
## V8 Dual-Track Ebbinghaus Spatial Memory & Speech Ledger (`V8MemoryLedger`).
## Tracks per-word 5-stage retention (`0..5`), spoken follow-along stars (`0..3`),
## 287 spatial placement discoveries across 16 Home & School rooms, and active recall errands.

const DAY_SEC := 86400
const SHORT_SESSION_SEC := 480
const SHORT_MIN_WORDS := 5
const SHORT_MIN_ROOM_HOPS := 2

const STAGE_LABELS := {
	0: "未探索",
	1: "铜叶初识",
	2: "首轮巩固",
	3: "一日稳固",
	4: "三日稳固",
	5: "金星永固",
}

const SPOKEN_LABELS := {
	0: "未跟读",
	1: "安心默读星",
	2: "勇敢开口星",
	3: "闪耀发音星",
}


static func fresh() -> Dictionary:
	return {
		"schema_version": 1,
		"room_visits": 0,
		"last_room": "",
		"errand_seq": 0,
		"completed_errands": 0,
		"items": {},
		"visited_slots": {},
		"active_errand": {},
	}


static func normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false}
	var src: Dictionary = raw as Dictionary
	var out := fresh()
	out["room_visits"] = clampi(int(src.get("room_visits", 0)), 0, 999999)
	out["last_room"] = str(src.get("last_room", "")).left(40)
	out["errand_seq"] = clampi(int(src.get("errand_seq", 0)), 0, 999999)
	out["completed_errands"] = clampi(int(src.get("completed_errands", 0)), 0, 999999)

	if src.get("visited_slots", {}) is Dictionary:
		var raw_slots: Dictionary = src["visited_slots"]
		var clean_slots: Dictionary = {}
		for sk: Variant in raw_slots.keys():
			if sk is String and not str(sk).is_empty() and clean_slots.size() < 600:
				clean_slots[str(sk).left(64)] = true
		out["visited_slots"] = clean_slots

	if src.get("items", {}) is Dictionary:
		var raw_items: Dictionary = src["items"]
		var clean_items: Dictionary = {}
		for wk: Variant in raw_items.keys():
			if not (wk is String) or str(wk).is_empty() or clean_items.size() >= 400:
				continue
			var rec_v: Variant = raw_items[wk]
			if not (rec_v is Dictionary):
				continue
			var rec: Dictionary = rec_v as Dictionary
			var key := str(wk).strip_edges().to_lower().left(40)
			clean_items[key] = {
				"word": key,
				"zh": str(rec.get("zh", "")).left(32),
				"room_id": str(rec.get("room_id", "home")).left(32),
				"anchor_order": clampi(int(rec.get("anchor_order", 1)), 1, 10),
				"stage": clampi(int(rec.get("stage", 1)), 1, 5),
				"first_seen_sec": maxi(0, int(rec.get("first_seen_sec", 0))),
				"last_review_sec": maxi(0, int(rec.get("last_review_sec", 0))),
				"last_review_day": maxi(1, int(rec.get("last_review_day", 1))),
				"seen_room_serial": maxi(0, int(rec.get("seen_room_serial", 0))),
				"spoken_tier": clampi(int(rec.get("spoken_tier", 0)), 0, 3),
				"spoken_count": clampi(int(rec.get("spoken_count", 0)), 0, 9999),
				"sentence_spoken": bool(rec.get("sentence_spoken", false)),
				"blind_recalls": clampi(int(rec.get("blind_recalls", 0)), 0, 9999),
				"total_recalls": clampi(int(rec.get("total_recalls", 0)), 0, 9999),
			}
		out["items"] = clean_items

	if src.get("active_errand", {}) is Dictionary and not (src["active_errand"] as Dictionary).is_empty():
		var ae: Dictionary = src["active_errand"]
		var clean_targets: Array = []
		if ae.get("targets", []) is Array:
			for tv: Variant in (ae["targets"] as Array).slice(0, 3):
				if tv is Dictionary and not str((tv as Dictionary).get("word", "")).is_empty():
					var td := tv as Dictionary
					clean_targets.append({
						"word": str(td.get("word", "")).to_lower().left(40),
						"zh": str(td.get("zh", "")).left(32),
						"room_id": str(td.get("room_id", "home")).left(32),
						"room_zh": str(td.get("room_zh", "房间")).left(32),
						"anchor_order": clampi(int(td.get("anchor_order", 1)), 1, 10),
						"anchor_zh": str(td.get("anchor_zh", "家具")).left(32),
						"found": bool(td.get("found", false)),
						"hint_tier": clampi(int(td.get("hint_tier", 0)), 0, 2),
					})
		if not clean_targets.is_empty():
			out["active_errand"] = {
				"id": str(ae.get("id", "errand-1")).left(32),
				"domain": str(ae.get("domain", "home")).left(16),
				"giver_npc_id": str(ae.get("giver_npc_id", "textbook_role_lingling_mother")).left(48),
				"giver_name": str(ae.get("giver_name", "妈妈 · Mom")).left(40),
				"created_sec": maxi(0, int(ae.get("created_sec", 0))),
				"targets": clean_targets,
			}

	return {"ok": true, "value": out}


static func ensure(data: Dictionary) -> Dictionary:
	if not data.has("v8_memory") or not (data["v8_memory"] is Dictionary):
		data["v8_memory"] = fresh()
	var mem: Dictionary = data["v8_memory"]
	if not mem.has("items") or not (mem["items"] is Dictionary):
		mem["items"] = {}
	if not mem.has("visited_slots") or not (mem["visited_slots"] is Dictionary):
		mem["visited_slots"] = {}
	if not mem.has("active_errand") or not (mem["active_errand"] is Dictionary):
		mem["active_errand"] = {}
	if not mem.has("room_visits"):
		mem["room_visits"] = 0
	if not mem.has("last_room"):
		mem["last_room"] = ""
	if not mem.has("errand_seq"):
		mem["errand_seq"] = 0
	if not mem.has("completed_errands"):
		mem["completed_errands"] = 0
	return mem


static func record_room_visit(data: Dictionary, room_id: String) -> bool:
	var rid := room_id.strip_edges()
	if rid.is_empty():
		return false
	var mem := ensure(data)
	if str(mem.get("last_room", "")) == rid:
		return false
	mem["last_room"] = rid
	mem["room_visits"] = int(mem.get("room_visits", 0)) + 1
	return true


static func record_word_exposure(
	data: Dictionary,
	word_raw: String,
	zh: String,
	room_id: String,
	anchor_order: int,
	now_sec: int
) -> Dictionary:
	var key := word_raw.strip_edges().to_lower()
	if key.is_empty():
		return {"changed": false, "first_time": false}
	var mem := ensure(data)
	var cur_day := maxi(1, int(data.get("day", 1)))
	var slot_key := "%s:%d:%s" % [room_id, anchor_order, key]
	var slots: Dictionary = mem["visited_slots"]
	var slot_new := not slots.has(slot_key)
	slots[slot_key] = true

	var items: Dictionary = mem["items"]
	if not items.has(key):
		items[key] = {
			"word": key,
			"zh": zh,
			"room_id": room_id,
			"anchor_order": clampi(anchor_order, 1, 10),
			"stage": 1,
			"first_seen_sec": now_sec,
			"last_review_sec": now_sec,
			"last_review_day": cur_day,
			"seen_room_serial": int(mem.get("room_visits", 0)),
			"spoken_tier": 0,
			"spoken_count": 0,
			"sentence_spoken": false,
			"blind_recalls": 0,
			"total_recalls": 0,
		}
		return {"changed": true, "first_time": true, "stage": 1}

	var rec: Dictionary = items[key]
	if not room_id.is_empty():
		rec["room_id"] = room_id
		rec["anchor_order"] = clampi(anchor_order, 1, 10)
	if not zh.is_empty() and str(rec.get("zh", "")).is_empty():
		rec["zh"] = zh
	return {"changed": slot_new, "first_time": false, "stage": int(rec.get("stage", 1))}


static func record_spoken(
	data: Dictionary,
	word_raw: String,
	tier: int,
	is_sentence: bool,
	zh: String = "",
	room_id: String = "home",
	anchor_order: int = 1,
	now_sec: int = 0
) -> Dictionary:
	var key := word_raw.strip_edges().to_lower()
	if key.is_empty():
		return {"changed": false}
	var ts := now_sec if now_sec > 0 else int(Time.get_unix_time_from_system())
	record_word_exposure(data, key, zh, room_id, anchor_order, ts)
	var mem := ensure(data)
	var rec: Dictionary = (mem["items"] as Dictionary)[key]
	var clamped_tier := clampi(tier, 1, 3)
	var prev_tier := int(rec.get("spoken_tier", 0))
	var prev_sent := bool(rec.get("sentence_spoken", false))
	rec["spoken_tier"] = maxi(prev_tier, clamped_tier)
	rec["spoken_count"] = int(rec.get("spoken_count", 0)) + 1
	if is_sentence and clamped_tier >= 2:
		rec["sentence_spoken"] = true
	return {
		"changed": true,
		"upgraded_tier": clamped_tier > prev_tier,
		"first_sentence": is_sentence and clamped_tier >= 2 and not prev_sent,
		"spoken_tier": int(rec["spoken_tier"]),
	}


static func is_word_due(data: Dictionary, word_raw: String, now_sec: int) -> bool:
	var key := word_raw.strip_edges().to_lower()
	var mem := ensure(data)
	var items: Dictionary = mem["items"]
	if not items.has(key):
		return false
	var rec: Dictionary = items[key]
	var stg := int(rec.get("stage", 1))
	if stg >= 5:
		return false

	var cur_day := maxi(1, int(data.get("day", 1)))
	var last_sec := int(rec.get("last_review_sec", 0))
	var last_day := int(rec.get("last_review_day", 1))
	var elapsed_sec := maxi(0, now_sec - last_sec)
	var elapsed_days := maxi(0, cur_day - last_day)

	match stg:
		1:
			var learned_count := items.size()
			var hops := int(mem.get("room_visits", 0)) - int(rec.get("seen_room_serial", 0))
			if learned_count >= SHORT_MIN_WORDS and hops >= SHORT_MIN_ROOM_HOPS:
				return true
			return elapsed_sec >= SHORT_SESSION_SEC or elapsed_days >= 1
		2:
			return elapsed_sec >= DAY_SEC or elapsed_days >= 1
		3:
			return elapsed_sec >= 3 * DAY_SEC or elapsed_days >= 3
		4:
			return elapsed_sec >= 7 * DAY_SEC or elapsed_days >= 7
	return false


static func due_words(data: Dictionary, domain_filter: String = "", now_sec: int = -1) -> Array[Dictionary]:
	var ts := now_sec if now_sec >= 0 else int(Time.get_unix_time_from_system())
	var mem := ensure(data)
	var items: Dictionary = mem["items"]
	var result: Array[Dictionary] = []
	for wk: Variant in items.keys():
		var key := str(wk)
		if not is_word_due(data, key, ts):
			continue
		var rec: Dictionary = items[key]
		var rid := str(rec.get("room_id", "home"))
		var dom := "home" if rid.begins_with("home") else "school"
		if not domain_filter.is_empty() and dom != domain_filter:
			continue
		result.append(rec.duplicate(true))

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("stage", 1))
		var sb := int(b.get("stage", 1))
		if sa != sb:
			return sa < sb
		return int(a.get("last_review_sec", 0)) < int(b.get("last_review_sec", 0))
	)
	return result


static func active_errand_target_for_anchor(data: Dictionary, room_id: String, anchor_order: int) -> Dictionary:
	var mem := ensure(data)
	var ae: Dictionary = mem.get("active_errand", {})
	if ae.is_empty() or not (ae.get("targets", []) is Array):
		return {}
	for tv: Variant in ae["targets"]:
		if not (tv is Dictionary):
			continue
		var td := tv as Dictionary
		if not bool(td.get("found", false)) and str(td.get("room_id", "")) == room_id and int(td.get("anchor_order", 0)) == anchor_order:
			return td
	return {}


static func advance_errand_hint(data: Dictionary, word_raw: String) -> int:
	var key := word_raw.strip_edges().to_lower()
	var mem := ensure(data)
	var ae: Dictionary = mem.get("active_errand", {})
	if ae.is_empty() or not (ae.get("targets", []) is Array):
		return 0
	for tv: Variant in ae["targets"]:
		if tv is Dictionary and str((tv as Dictionary).get("word", "")) == key and not bool((tv as Dictionary).get("found", false)):
			var nxt := mini(2, int((tv as Dictionary).get("hint_tier", 0)) + 1)
			(tv as Dictionary)["hint_tier"] = nxt
			return nxt
	return 0


static func complete_errand_target(data: Dictionary, word_raw: String, now_sec: int) -> Dictionary:
	var key := word_raw.strip_edges().to_lower()
	var mem := ensure(data)
	var ae: Dictionary = mem.get("active_errand", {})
	if ae.is_empty() or not (ae.get("targets", []) is Array):
		return {"ok": false}

	var matched: Dictionary = {}
	var all_done := true
	for tv: Variant in ae["targets"]:
		if not (tv is Dictionary):
			continue
		var td := tv as Dictionary
		if str(td.get("word", "")) == key and not bool(td.get("found", false)):
			td["found"] = true
			matched = td
		if not bool(td.get("found", false)):
			all_done = false

	if matched.is_empty():
		return {"ok": false}

	var hint_tier := clampi(int(matched.get("hint_tier", 0)), 0, 2)
	var cur_day := maxi(1, int(data.get("day", 1)))
	var items: Dictionary = mem["items"]
	var new_stage := 2
	if items.has(key):
		var rec: Dictionary = items[key]
		var prev_stage := int(rec.get("stage", 1))
		new_stage = mini(5, prev_stage + 1) if hint_tier <= 1 else prev_stage
		rec["stage"] = new_stage
		rec["last_review_sec"] = now_sec
		rec["last_review_day"] = cur_day
		rec["seen_room_serial"] = int(mem.get("room_visits", 0))
		rec["total_recalls"] = int(rec.get("total_recalls", 0)) + 1
		if hint_tier == 0:
			rec["blind_recalls"] = int(rec.get("blind_recalls", 0)) + 1

	var exp_reward := 32 if hint_tier == 0 else (24 if hint_tier == 1 else 16)
	var coin_reward := 4 if hint_tier == 0 else (3 if hint_tier == 1 else 2)
	var badge_zh := "过目不忘金星" if hint_tier == 0 else ("线索联想银星" if hint_tier == 1 else "温故重逢暖星")

	if all_done:
		mem["completed_errands"] = int(mem.get("completed_errands", 0)) + 1
		mem["active_errand"] = {}
		coin_reward += 3

	return {
		"ok": true,
		"word": key,
		"zh": str(matched.get("zh", key)),
		"hint_tier": hint_tier,
		"new_stage": new_stage,
		"stage_label": str(STAGE_LABELS.get(new_stage, "巩固中")),
		"exp_reward": exp_reward,
		"coin_reward": coin_reward,
		"badge_zh": badge_zh,
		"errand_completed": all_done,
	}


static func summary(data: Dictionary, now_sec: int = -1) -> Dictionary:
	var ts := now_sec if now_sec >= 0 else int(Time.get_unix_time_from_system())
	var mem := ensure(data)
	var items: Dictionary = mem["items"]
	var slots: Dictionary = mem["visited_slots"]
	var gold_count := 0
	var solid_count := 0
	var due_count := 0
	var spoken_stars := 0
	var exact_spoken := 0
	for wk: Variant in items.keys():
		var key := str(wk)
		var rec: Dictionary = items[key]
		var stg := int(rec.get("stage", 1))
		if stg >= 5:
			gold_count += 1
		elif stg >= 2:
			solid_count += 1
		if is_word_due(data, key, ts):
			due_count += 1
		var sp := int(rec.get("spoken_tier", 0))
		if sp >= 1:
			spoken_stars += 1
		if sp >= 3:
			exact_spoken += 1

	return {
		"discovered_words": items.size(),
		"visited_placements": slots.size(),
		"gold_words": gold_count,
		"solid_words": solid_count,
		"due_words": due_count,
		"spoken_words": spoken_stars,
		"exact_spoken_words": exact_spoken,
		"completed_errands": int(mem.get("completed_errands", 0)),
		"has_active_errand": not (mem.get("active_errand", {}) as Dictionary).is_empty(),
	}
