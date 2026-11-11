extends RefCounted
## V4 8-Book 81-Unit Curriculum Quest & Cozy Life Commission Director.
## Dynamically bridges all 8 primary school books (G3–G6, 81 units, 1,314 words)
## into natural island commissions, diegetic conversations, and Pop-up Book shelves!

const Content = preload("res://ui/memory_story_content.gd")

const NPC_TEMPLATES := {
	"npc_bear_uncle": {
		"speaker": "熊叔 · 暖香面包房",
		"greeting_en": "Good morning, little friend! Today we are sharing \"%s\"!",
		"greeting_zh": "早安呀小朋友！今天面包房正在分享「%s」（%s）的小心愿！"
	},
	"npc_rabbit_gardener": {
		"speaker": "兔兔园丁 · A 苹果果园",
		"greeting_en": "Hello! Could you help me find \"%s\" in the sunny garden?",
		"greeting_zh": "你好呀！能在暖洋洋的果园里帮我想一想「%s」（%s）吗？"
	},
	"textbook_miss_li": {
		"speaker": "李老师 · 阳光游园角",
		"greeting_en": "Welcome! Let's play with \"%s\" in our storybook today!",
		"greeting_zh": "欢迎你！今天我们用立体书和游园会来认识「%s」（%s）吧！"
	}
}

static func active_book_and_unit(state: Node) -> Dictionary:
	var j_snap: Dictionary = state.journey_snapshot()
	var book_id := str(j_snap.get("selected_book_id", "xiangshao-g3-1"))
	var v4_data: Dictionary = state.data.get("v4", {}) if state.data.get("v4") is Dictionary else {}
	var unit_id := str(v4_data.get("active_unit_id", "unit-1"))
	var books: Array = Content.load_catalog().get("books", [])
	var book_title := "湘少版三年级上册"
	var unit_count := 10
	for b: Dictionary in books:
		if str(b.get("book_id", "")) == book_id:
			book_title = str(b.get("title_zh", b.get("title", book_id)))
			unit_count = int(b.get("unit_count", 10))
			break
	var u_num := clampi(int(unit_id.trim_prefix("unit-")), 1, maxi(1, unit_count))
	unit_id = "unit-" + str(u_num)
	return {
		"book_id": book_id,
		"book_title": book_title,
		"unit_id": unit_id,
		"unit_number": u_num,
		"unit_count": unit_count
	}

static func unit_entries(book_id: String, unit_id: String) -> Array:
	var entries := Content.list_entries(book_id, unit_id, "")
	if entries.is_empty():
		entries = Content.list_entries(book_id, "", "").slice(0, 12)
	return entries

static func build_daily_commission(state: Node, npc_id: String = "npc_bear_uncle") -> Dictionary:
	var info := active_book_and_unit(state)
	var entries := unit_entries(str(info.book_id), str(info.unit_id))
	if entries.is_empty():
		return {}

	var v4_data: Dictionary = state.data.get("v4", {}) if state.data.get("v4") is Dictionary else {}
	var done_list: Array = v4_data.get("completed_commissions", [])

	# Pick the first uncompleted word in this unit, or cycle gracefully by day
	var target: Dictionary = entries[int(state.data.get("day", 1)) % entries.size()]
	for item: Dictionary in entries:
		var cid := "%s/%s/%s" % [str(info.book_id), str(info.unit_id), str(item.entry_id)]
		if not done_list.has(cid):
			target = item
			break

	var distractors: Array[Dictionary] = []
	var all_book := Content.list_entries(str(info.book_id), "", "")
	for cand: Dictionary in all_book:
		if str(cand.entry_id) != str(target.entry_id) and str(cand.meaning_zh) != str(target.meaning_zh):
			distractors.append(cand)
			if distractors.size() >= 2:
				break

	var tpl: Dictionary = NPC_TEMPLATES.get(npc_id, NPC_TEMPLATES["npc_bear_uncle"])
	var word_en := str(target.spelling_display)
	var word_zh := str(target.meaning_zh)
	var commission_id := "%s/%s/%s" % [str(info.book_id), str(info.unit_id), str(target.entry_id)]

	# Deterministic shuffle based on entry_id hash so choices don't jump on redraw
	var options: Array[Dictionary] = [
		{"label": "🌟 %s" % word_en, "word": word_en, "correct": true, "entry_id": str(target.entry_id)}
	]
	for d: Dictionary in distractors:
		options.append({
			"label": "🌿 %s" % str(d.spelling_display),
			"word": str(d.spelling_display),
			"correct": false,
			"entry_id": str(d.entry_id)
		})
	var shift := absi(commission_id.hash()) % maxi(1, options.size())
	if shift > 0 and options.size() > 1:
		var rotated: Array[Dictionary] = []
		for i in range(options.size()):
			rotated.append(options[(i + shift) % options.size()])
		options = rotated

	return {
		"commission_id": commission_id,
		"book_id": str(info.book_id),
		"book_title": str(info.book_title),
		"unit_id": str(info.unit_id),
		"speaker": str(tpl.speaker),
		"target_entry_id": str(target.entry_id),
		"target_word": word_en,
		"target_meaning_zh": word_zh,
		"prompt_en": "I am making a cozy card for \"%s\"! Which sticker matches it?" % word_zh,
		"prompt_zh": "我正在为「%s」准备小岛手账贴纸（%s · Unit %d），帮我递一下对应的英文贴纸吧！" % [word_zh, str(info.book_title), int(info.unit_number)],
		"options": options
	}
