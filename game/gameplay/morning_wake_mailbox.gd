extends RefCounted
## V5 Morning Memory Wake-Up Mailbox (`MorningWakeMailbox`).
## Delivers 3 daily Spaced-Repetition "猫头鹰晨间温故信" cards anchored to real
## Memory Palace rooms & concrete furniture corners — prompting gentle spatial
## gap-recall (`open_palace_gap:<entry_id>`) without spoiling the spelling upfront.
## Zero raw OS emojis.

const PalaceLoci = preload("res://gameplay/memory_palace_loci_3d.gd")

static func select_daily_wake_cards(state_node: Node, count: int = 3) -> Array[Dictionary]:
	var all_items := PalaceLoci.all_palace_items()
	if all_items.is_empty():
		return []

	var word_map: Dictionary = {}
	for it: Dictionary in all_items:
		var w := str(it.get("word", "")).to_lower()
		if not w.is_empty() and not word_map.has(w):
			word_map[w] = it

	var picked: Array[Dictionary] = []
	var seen_sids: Dictionary = {}
	var sel_book := "xiangshao-g3-1"
	var sel_unit := "unit-1"
	var day_seed := 1

	if state_node != null and state_node.get("data") is Dictionary:
		var d: Dictionary = state_node.data
		day_seed = maxi(1, int(d.get("day", 1)))
		var j: Dictionary = d.get("journey", {}) if d.get("journey") is Dictionary else {}
		sel_book = str(j.get("selected_book_id", sel_book))
		var v4: Dictionary = d.get("v4", {}) if d.get("v4") is Dictionary else {}
		sel_unit = str(v4.get("active_unit_id", sel_unit))

		# 1. Prioritize fragile / assisted stealth observations first (higher support_level or incorrect)
		var fragile_words: Array[String] = []
		var solid_words: Array[String] = []
		var events: Array = v4.get("stealth_events", []) if v4.get("stealth_events") is Array else []
		for i in range(events.size() - 1, -1, -1):
			var ev_v: Variant = events[i]
			if not (ev_v is Dictionary):
				continue
			var ev: Dictionary = ev_v as Dictionary
			var w := str(ev.get("word", "")).strip_edges().to_lower()
			if not word_map.has(w):
				continue
			var sup := int(ev.get("support_level", 0))
			var ok := bool(ev.get("correct", true))
			if (not ok or sup >= 2) and not fragile_words.has(w):
				fragile_words.append(w)
			elif not solid_words.has(w):
				solid_words.append(w)

		for fw: String in fragile_words:
			if picked.size() >= count:
				break
			var item: Dictionary = word_map[fw]
			var sid := str(item.get("story_id", ""))
			if not seen_sids.has(sid):
				seen_sids[sid] = true
				var copy := item.duplicate(true)
				copy["wake_reason"] = "上次用了小提示，今天回角落想一想"
				picked.append(copy)

		for sw: String in solid_words:
			if picked.size() >= count:
				break
			var item: Dictionary = word_map[sw]
			var sid := str(item.get("story_id", ""))
			if not seen_sids.has(sid):
				seen_sids[sid] = true
				var copy := item.duplicate(true)
				copy["wake_reason"] = "之前在岛上遇见过，顺路温故点亮"
				picked.append(copy)

	# 2. Fill remaining slots from active textbook unit (deterministic daily rotation)
	if picked.size() < count:
		var unit_pool: Array[Dictionary] = []
		var book_pool: Array[Dictionary] = []
		for it: Dictionary in all_items:
			var by_b: Dictionary = it.get("entry_by_book", {}) if it.get("entry_by_book") is Dictionary else {}
			var u_by_b: Dictionary = it.get("unit_by_book", {}) if it.get("unit_by_book") is Dictionary else {}
			if by_b.has(sel_book):
				if (u_by_b.get(sel_book, []) as Array).has(sel_unit):
					unit_pool.append(it)
				else:
					book_pool.append(it)
		for pool: Array in [unit_pool, book_pool, all_items]:
			if picked.size() >= count or pool.is_empty():
				continue
			var start_i := posmod((day_seed - 1) * 3, pool.size())
			for step in range(pool.size()):
				if picked.size() >= count:
					break
				var cand: Dictionary = pool[(start_i + step) % pool.size()]
				var sid := str(cand.get("story_id", ""))
				if not seen_sids.has(sid):
					seen_sids[sid] = true
					var copy := cand.duplicate(true)
					copy["wake_reason"] = "本单元重点记忆桩，去角落唤醒奇象"
					picked.append(copy)

	return picked

static func open_mailbox(game: Node3D) -> void:
	if not is_instance_valid(game):
		return
	var state_node := game.get_node_or_null("/root/State")
	var cards := select_daily_wake_cards(state_node, 3)
	if cards.is_empty():
		game.ui.notify("信箱里干干净净，先去岛上逛逛吧。")
		return

	var day_num := int(state_node.data.get("day", 1)) if state_node != null else 1
	var lines: Array[String] = [
		"第 %d 天清晨，猫头鹰馆长把 3 封【记忆宫殿温故信】投进了门前信箱！" % day_num,
		"先在脑海里回想那个房间角落发生的童话奇象，再点开遮罩拼一拼（不直接剧透拼写哦）：",
		""
	]
	var actions: Array = []
	for idx in range(cards.size()):
		var c: Dictionary = cards[idx]
		var eid := PalaceLoci.best_entry_id_for_state(c, state_node)
		var m_zh := str(c.get("meaning_zh", ""))
		var r_zh := str(c.get("palace_room_zh", "记忆房间"))
		var r_id := str(c.get("palace_room_id", "home"))
		var locus := str(c.get("palace_locus_zh", "角落"))
		var title := str(c.get("title_zh", ""))
		var word_len := str(c.get("word", "")).length()
		var reason := str(c.get("wake_reason", "晨间角落温故"))
		lines.append("第 %d 封 · 词义「%s」（%d 个字母）" % [idx + 1, m_zh, word_len])
		lines.append("   宫殿位置：%s › %s  |  奇象线索：《%s》（%s）" % [r_zh, locus, title, reason])
		actions.append({
			"label": "★ 第 %d 封遮罩回想 ·「%s」（%s）" % [idx + 1, m_zh, r_zh],
			"id": "open_palace_gap:" + eid,
			"primary": idx == 0
		})
		if idx == 0 and not r_id.is_empty():
			actions.append({
				"label": "◈ 直接前往「%s」实地回想" % r_zh,
				"id": "v5_palace_goto:" + r_id
			})

	actions.append({"label": "收好温故信，继续生活", "id": "close"})
	if is_instance_valid(game.audio_director):
		game.audio_director.play_foley("bubble_pop")
	if is_instance_valid(game.ai_bridge):
		game.ai_bridge.speak_text("Good morning! Three memory palace letters are waiting in your mailbox!", "en", "storyteller")

	if not game._prepare_screen():
		return
	game.ui.show_panel(
		"v5_wake_mailbox",
		"猫头鹰晨间温故信",
		"间隔记忆唤醒 · 第 %d 天（共 3 封角落线索卡）" % day_num,
		"\n".join(lines),
		actions,
		"温故信按遗忘规律挑选需要唤醒的词，先用房间角落与奇象线索主动回想，记忆最牢固。"
	)
