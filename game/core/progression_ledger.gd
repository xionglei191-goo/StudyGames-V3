class_name ProgressionLedger
extends RefCounted
## V7 Joint Level + EXP & Leaf Coin Economy Ledger (`ProgressionLedger`).
## Manages:
## 1. Lv.1 ~ Lv.12 growth curve + unlimited Star Prestige scholarships every 400 EXP after Lv.12.
## 2. Anti-grind EXP & Leaf Coin settlement (first-clear bonus, spaced review bonus, daily/cooldown caps).
## 3. Recommended-but-unlocked Stage 1~4 grammar mastery badges.
## 4. Joint Level + Leaf Coin unlock rules for Wardrobe (outfits, hats, bags) & 3D Free-Grid Furniture.

const MAX_BASE_LEVEL: int = 12
const STAR_PRESTIGE_STEP: int = 400
const STAR_PRESTIGE_COINS: int = 30
const MAX_EXP: int = 10_000_000
const MAX_HISTORY_ENTRIES: int = 10_000
const MAX_EVENT_KEY_LENGTH: int = 160

const LEVEL_TABLE: Array[Dictionary] = [
	{"level": 1, "min_exp": 0, "zh": "启蒙小芽", "en": "Island Sprout", "gift_coins": 0, "unlock_zh": "初始穿搭 · 向日葵书包开放兑换 · 第 1 阶对话徽章"},
	{"level": 2, "min_exp": 60, "zh": "好奇认物生", "en": "Word Finder", "gift_coins": 15, "unlock_zh": "草莓粉/水手蓝套装 · 田园草帽 · 甜品台/兔兔绿雕"},
	{"level": 3, "min_exp": 150, "zh": "收纳小帮手", "en": "Tidy Helper", "gift_coins": 18, "unlock_zh": "第 2 阶语法晋级徽章 · 蝴蝶结发箍 · 落地灯/绘本架"},
	{"level": 4, "min_exp": 280, "zh": "家居小达人", "en": "Home Explorer", "gift_coins": 20, "unlock_zh": "薄荷园艺装 · 藤编野餐篮 · 云朵沙发/手作展台"},
	{"level": 5, "min_exp": 450, "zh": "礼貌交际星", "en": "Polite Speaker", "gift_coins": 22, "unlock_zh": "黄铜留声机 · 章节纪念画架"},
	{"level": 6, "min_exp": 670, "zh": "校园活力星", "en": "Campus Star", "gift_coins": 25, "unlock_zh": "第 3 阶语法晋级徽章 · 焦糖烘焙装 · 画家贝雷帽"},
	{"level": 7, "min_exp": 940, "zh": "故事收藏家", "en": "Story Keeper", "gift_coins": 28, "unlock_zh": "阳光小院森系木秋千"},
	{"level": 8, "min_exp": 1260, "zh": "记忆筑梦师", "en": "Palace Builder", "gift_coins": 30, "unlock_zh": "暖绒小兔发箍"},
	{"level": 9, "min_exp": 1640, "zh": "时态小侦探", "en": "Time Detective", "gift_coins": 35, "unlock_zh": "第 4 阶语法晋级徽章 · 星光薰衣草礼服 · 晴空小喷泉"},
	{"level": 10, "min_exp": 2080, "zh": "家校小使者", "en": "Bilingual Host", "gift_coins": 38, "unlock_zh": "星光童话小翅膀背饰"},
	{"level": 11, "min_exp": 2580, "zh": "博学领航员", "en": "Island Navigator", "gift_coins": 42, "unlock_zh": "庭院与书房大师荣誉头衔"},
	{"level": 12, "min_exp": 3160, "zh": "双语小博士", "en": "Island Scholar", "gift_coins": 50, "unlock_zh": "满级金叶徽章 · 每满 400 EXP 循环领星耀奖学金"},
]

const STAGE_RECOMMENDED_LEVEL: Dictionary = {
	1: 1,
	2: 3,
	3: 6,
	4: 9,
}

const STAGE_CLEAR_REWARDS: Dictionary = {
	1: {"exp": 25, "coins": 8},
	2: {"exp": 32, "coins": 10},
	3: {"exp": 40, "coins": 12},
	4: {"exp": 50, "coins": 14},
}

const BADGE_BONUS_EXP: int = 20
const BADGE_BONUS_COINS: int = 8

const WARDROBE_RULES: Dictionary = {
	"outfit:yellow": {"level": 1, "price": 0},
	"outfit:pink": {"level": 2, "price": 18},
	"outfit:blue": {"level": 2, "price": 18},
	"outfit:mint": {"level": 4, "price": 26},
	"outfit:caramel": {"level": 6, "price": 32},
	"outfit:lavender": {"level": 9, "price": 42},
	"hat:none": {"level": 1, "price": 0},
	"hat:straw_hat": {"level": 2, "price": 16},
	"hat:ribbon_bow": {"level": 3, "price": 20},
	"hat:star_beret": {"level": 6, "price": 28},
	"hat:bunny_ears": {"level": 8, "price": 36},
	"bag:none": {"level": 1, "price": 0},
	"bag:school_pack": {"level": 1, "price": 12},
	"bag:picnic_basket": {"level": 4, "price": 24},
	"bag:star_wings": {"level": 10, "price": 48},
}

const FURNITURE_LEVEL_RULES: Dictionary = {
	"sunflower_rug": 1,
	"tea_table": 1,
	"potted_monstera": 1,
	"bunny_topiary": 2,
	"apple_cake_stand": 2,
	"star_floor_lamp": 3,
	"walnut_bookshelf": 3,
	"reading_sofa": 4,
	"trophy_craft_pedestal": 4,
	"music_gramophone": 5,
	"trophy_chapter_easel": 5,
	"courtyard_swing": 7,
	"garden_fountain": 9,
}


static func fresh() -> Dictionary:
	return {
		"exp": 0,
		"level": 1,
		"star_ranks": 0,
		"highest_gifted_level": 1,
		"gifted_star_ranks": 0,
		"wardrobe_owned": {
			"outfit:yellow": true,
			"hat:none": true,
			"bag:none": true,
		},
		"stage_badges": {},
		"claimed_once": {},
		"daily_claims": {},
		"cooldowns": {},
	}


static func level_for_exp(total_exp: int) -> int:
	var xp := maxi(0, total_exp)
	var lv := 1
	for row: Dictionary in LEVEL_TABLE:
		if xp >= int(row["min_exp"]):
			lv = int(row["level"])
	return lv


static func star_ranks_for_exp(total_exp: int) -> int:
	var top_min := int(LEVEL_TABLE[MAX_BASE_LEVEL - 1]["min_exp"])
	if total_exp <= top_min:
		return 0
	return (total_exp - top_min) / STAR_PRESTIGE_STEP


static func level_info(level_num: int) -> Dictionary:
	var idx := clampi(level_num, 1, MAX_BASE_LEVEL) - 1
	return LEVEL_TABLE[idx]


static func progress_summary(prog: Dictionary) -> Dictionary:
	var xp := maxi(0, int(prog.get("exp", 0)))
	var lv := level_for_exp(xp)
	var stars := star_ranks_for_exp(xp)
	var cur_row := level_info(lv)
	var cur_min := int(cur_row["min_exp"])
	var next_min := cur_min + STAR_PRESTIGE_STEP
	var span := STAR_PRESTIGE_STEP
	var into := 0
	if lv < MAX_BASE_LEVEL:
		var next_row := level_info(lv + 1)
		next_min = int(next_row["min_exp"])
		span = maxi(1, next_min - cur_min)
		into = clampi(xp - cur_min, 0, span)
	else:
		var top_min := int(LEVEL_TABLE[MAX_BASE_LEVEL - 1]["min_exp"])
		into = posmod(xp - top_min, STAR_PRESTIGE_STEP)
		next_min = top_min + (stars + 1) * STAR_PRESTIGE_STEP
	var ratio := clampf(float(into) / float(maxi(1, span)), 0.0, 1.0)
	var title_zh := str(cur_row["zh"])
	if stars > 0:
		title_zh += " ★%d" % stars
	return {
		"exp": xp,
		"level": lv,
		"star_ranks": stars,
		"title_zh": title_zh,
		"title_en": str(cur_row["en"]),
		"unlock_zh": str(cur_row["unlock_zh"]),
		"into_level": into,
		"level_span": span,
		"next_min_exp": next_min,
		"to_next": maxi(0, span - into),
		"ratio": ratio,
		"is_max_base": lv >= MAX_BASE_LEVEL,
	}


static func wardrobe_rule(category: String, item_id: String) -> Dictionary:
	var key := "%s:%s" % [category.strip_edges(), item_id.strip_edges()]
	if WARDROBE_RULES.has(key):
		return WARDROBE_RULES[key] as Dictionary
	return {"level": 1, "price": 0}


static func is_wardrobe_owned(data: Dictionary, category: String, item_id: String) -> bool:
	var cat := category.strip_edges()
	var iid := item_id.strip_edges()
	var key := "%s:%s" % [cat, iid]
	var rule := wardrobe_rule(cat, iid)
	if int(rule.get("price", 0)) <= 0 and int(rule.get("level", 1)) <= 1:
		return true
	# Always treat currently equipped item as owned so legacy/prologue outfits never lock out.
	if cat == "outfit" and str(data.get("outfit", "yellow")) == iid:
		return true
	var w_dict: Dictionary = data.get("wardrobe", {}) if data.get("wardrobe") is Dictionary else {}
	if cat == "hat" and str(w_dict.get("hat", "none")) == iid:
		return true
	if cat == "bag" and str(w_dict.get("bag", "none")) == iid:
		return true
	var prog: Dictionary = data.get("progression", {}) if data.get("progression") is Dictionary else {}
	var owned: Dictionary = prog.get("wardrobe_owned", {}) if prog.get("wardrobe_owned") is Dictionary else {}
	return bool(owned.get(key, false))


static func furniture_required_level(item_id: String) -> int:
	return int(FURNITURE_LEVEL_RULES.get(item_id.strip_edges(), 1))


static func stage_recommended_level(stage_num: int) -> int:
	return int(STAGE_RECOMMENDED_LEVEL.get(clampi(stage_num, 1, 4), 1))


static func has_stage_badge(data: Dictionary, scenario_id: String) -> bool:
	var prog: Dictionary = data.get("progression", {}) if data.get("progression") is Dictionary else {}
	var badges: Dictionary = prog.get("stage_badges", {}) if prog.get("stage_badges") is Dictionary else {}
	return bool(badges.get(scenario_id.strip_edges(), false))


static func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false}
	var src: Dictionary = raw
	var clean := fresh()
	if not _integer_between(src.get("exp", 0), 0, MAX_EXP):
		return {"ok": false}
	var xp := int(src.get("exp", 0))
	var lv := level_for_exp(xp)
	var stars := star_ranks_for_exp(xp)
	if not _integer_between(src.get("highest_gifted_level", lv), 1, MAX_BASE_LEVEL):
		return {"ok": false}
	if not _integer_between(src.get("gifted_star_ranks", stars), 0, 100_000):
		return {"ok": false}
	for field: String in ["wardrobe_owned", "stage_badges", "claimed_once", "daily_claims", "cooldowns"]:
		if src.has(field) and not src[field] is Dictionary:
			return {"ok": false}
		if (src.get(field, {}) as Dictionary).size() > MAX_HISTORY_ENTRIES:
			# Reject an oversized/corrupt save instead of forgetting reward receipts.
			return {"ok": false}
	clean["exp"] = xp
	clean["level"] = lv
	clean["star_ranks"] = stars
	clean["highest_gifted_level"] = int(src.get("highest_gifted_level", lv))
	clean["gifted_star_ranks"] = int(src.get("gifted_star_ranks", stars))

	var owned_out: Dictionary = (clean["wardrobe_owned"] as Dictionary).duplicate(true)
	if src.get("wardrobe_owned") is Dictionary:
		var raw_owned: Dictionary = src["wardrobe_owned"]
		for k: Variant in raw_owned.keys():
			if not k is String or not raw_owned[k] is bool:
				return {"ok": false}
			if WARDROBE_RULES.has(k) and raw_owned[k]:
				owned_out[str(k)] = true
	clean["wardrobe_owned"] = owned_out

	var badges_out: Dictionary = {}
	if src.get("stage_badges") is Dictionary:
		var raw_b: Dictionary = src["stage_badges"]
		for bk: Variant in raw_b.keys():
			if not _valid_history_key(bk) or not raw_b[bk] is bool:
				return {"ok": false}
			if raw_b[bk]:
				badges_out[bk] = true
	clean["stage_badges"] = badges_out

	var once_out: Dictionary = {}
	if src.get("claimed_once") is Dictionary:
		var raw_once: Dictionary = src["claimed_once"]
		for ok_v: Variant in raw_once.keys():
			if not _valid_history_key(ok_v) or not raw_once[ok_v] is bool:
				return {"ok": false}
			if raw_once[ok_v]:
				once_out[ok_v] = true
	clean["claimed_once"] = once_out

	var daily_out: Dictionary = {}
	if src.get("daily_claims") is Dictionary:
		var raw_d: Dictionary = src["daily_claims"]
		for dk: Variant in raw_d.keys():
			if not _valid_history_key(dk) or not raw_d[dk] is Dictionary:
				return {"ok": false}
			var drec: Dictionary = raw_d[dk]
			if not _integer_between(drec.get("day", 1), 1, 1_000_000) or not _integer_between(drec.get("count", 1), 0, 100):
				return {"ok": false}
			daily_out[dk] = {"day": int(drec.get("day", 1)), "count": int(drec.get("count", 1))}
	clean["daily_claims"] = daily_out

	var cd_out: Dictionary = {}
	if src.get("cooldowns") is Dictionary:
		var raw_cd: Dictionary = src["cooldowns"]
		for ck: Variant in raw_cd.keys():
			if not _valid_history_key(ck) or not _integer_between(raw_cd[ck], 0, 253_402_300_799):
				return {"ok": false}
			cd_out[ck] = int(raw_cd[ck])
	clean["cooldowns"] = cd_out

	return {"ok": true, "value": clean}


static func _valid_history_key(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= MAX_EVENT_KEY_LENGTH


static func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric == floor(numeric) and numeric >= minimum and numeric <= maximum


static func migrate_from_legacy(state_data: Dictionary) -> Dictionary:
	var prog := fresh()
	var owned: Dictionary = prog["wardrobe_owned"]
	var cur_outfit := str(state_data.get("outfit", "yellow"))
	if WARDROBE_RULES.has("outfit:" + cur_outfit):
		owned["outfit:" + cur_outfit] = true
	var w_dict: Dictionary = state_data.get("wardrobe", {}) if state_data.get("wardrobe") is Dictionary else {}
	var cur_hat := str(w_dict.get("hat", "none"))
	var cur_bag := str(w_dict.get("bag", "none"))
	if WARDROBE_RULES.has("hat:" + cur_hat):
		owned["hat:" + cur_hat] = true
	if WARDROBE_RULES.has("bag:" + cur_bag):
		owned["bag:" + cur_bag] = true

	var xp := 0
	var life: Dictionary = state_data.get("life", {}) if state_data.get("life") is Dictionary else {}
	var disc: Dictionary = life.get("discoveries", {}) if life.get("discoveries") is Dictionary else {}
	xp += disc.size() * 12

	var htasks: Dictionary = life.get("home_tasks", {}) if life.get("home_tasks") is Dictionary else {}
	xp += htasks.size() * 18

	var acts: Dictionary = life.get("activities", {}) if life.get("activities") is Dictionary else {}
	for ak: Variant in acts.keys():
		if bool(acts[ak]):
			xp += 20

	var units: Dictionary = state_data.get("completed_units", {}) if state_data.get("completed_units") is Dictionary else {}
	for uk: Variant in units.keys():
		if bool(units[uk]):
			xp += 35

	var v4: Dictionary = state_data.get("v4", {}) if state_data.get("v4") is Dictionary else {}
	var comms: Array = v4.get("completed_commissions", []) if v4.get("completed_commissions") is Array else []
	xp += comms.size() * 14

	var lv := level_for_exp(xp)
	var stars := star_ranks_for_exp(xp)
	prog["exp"] = xp
	prog["level"] = lv
	prog["star_ranks"] = stars
	prog["highest_gifted_level"] = lv
	prog["gifted_star_ranks"] = stars
	return prog


static func apply_exp_event(state_data: Dictionary, event: Dictionary, now_sec: int) -> Dictionary:
	if not state_data.has("progression") or not state_data["progression"] is Dictionary:
		state_data["progression"] = fresh()
	var prog: Dictionary = state_data["progression"]
	var once_map: Dictionary = prog["claimed_once"]
	var daily_map: Dictionary = prog["daily_claims"]
	var cd_map: Dictionary = prog["cooldowns"]
	var badges_map: Dictionary = prog["stage_badges"]

	var key := str(event.get("key", "")).strip_edges()
	var mode := str(event.get("mode", "once")).strip_edges()
	var day_num := maxi(1, int(state_data.get("day", 1)))
	if not _valid_history_key(key):
		return {"changed": false, "exp_gained": 0, "coins_gained": 0, "leveled_up": false}

	var exp_gain := 0
	var coin_gain := 0
	var badge_earned := false
	var reason_tag := "none"
	var receipt_changed := false

	match mode:
		"once":
			if not bool(once_map.get(key, false)):
				receipt_changed = true
				once_map[key] = true
				exp_gain = maxi(0, int(event.get("base_exp", 8)))
				coin_gain = maxi(0, int(event.get("coin_bonus", 0)))
				reason_tag = "first"

		"word_study":
			var is_due_review := bool(event.get("is_due_review", false))
			var last_ts := int(cd_map.get(key, -999999))
			if not bool(once_map.get(key, false)):
				receipt_changed = true
				once_map[key] = true
				cd_map[key] = now_sec
				exp_gain = maxi(1, int(event.get("base_exp", 10)))
				coin_gain = maxi(0, int(event.get("coin_bonus", 0)))
				reason_tag = "first_word"
			elif is_due_review and (now_sec - last_ts >= 60):
				receipt_changed = true
				cd_map[key] = now_sec
				exp_gain = maxi(1, int(event.get("review_exp", 6)))
				coin_gain = maxi(0, int(event.get("review_coins", 0)))
				reason_tag = "due_review"
			elif now_sec - last_ts >= 300:
				receipt_changed = true
				cd_map[key] = now_sec
				exp_gain = maxi(0, int(event.get("repeat_exp", 1)))
				reason_tag = "cooldown_floor"

		"daily_repeat":
			var d_rec: Dictionary = daily_map.get(key, {}) if daily_map.get(key) is Dictionary else {}
			var prev_day := int(d_rec.get("day", -1))
			if not bool(once_map.get(key, false)):
				receipt_changed = true
				once_map[key] = true
				daily_map[key] = {"day": day_num, "count": 1}
				exp_gain = maxi(0, int(event.get("base_exp", 18)))
				coin_gain = maxi(0, int(event.get("coin_bonus", 0)))
				reason_tag = "first"
			elif prev_day < day_num:
				receipt_changed = true
				daily_map[key] = {"day": day_num, "count": 1}
				exp_gain = maxi(0, int(event.get("repeat_exp", 6)))
				coin_gain = maxi(0, int(event.get("repeat_coins", 0)))
				reason_tag = "daily_review"

		"dialogue_clear":
			var stage_num := clampi(int(event.get("stage", 1)), 1, 4)
			var scenario_id := str(event.get("scenario_id", key)).strip_edges()
			var stage_cfg: Dictionary = STAGE_CLEAR_REWARDS.get(stage_num, {"exp": 25, "coins": 8})
			var d_rec2: Dictionary = daily_map.get(key, {}) if daily_map.get(key) is Dictionary else {}
			var prev_day2 := int(d_rec2.get("day", -1))
			var cur_count := int(d_rec2.get("count", 0)) if prev_day2 == day_num else 0

			if not bool(once_map.get(key, false)):
				receipt_changed = true
				once_map[key] = true
				daily_map[key] = {"day": day_num, "count": 1}
				exp_gain += int(event.get("base_exp", stage_cfg["exp"]))
				coin_gain += int(event.get("coin_bonus", stage_cfg["coins"]))
				reason_tag = "first_dialogue"
			elif cur_count < 3:
				receipt_changed = true
				daily_map[key] = {"day": day_num, "count": cur_count + 1}
				exp_gain += int(event.get("repeat_exp", 4))
				reason_tag = "dialogue_practice"

			# Check Recommended Stage Mastery Badge (either before or right after base EXP applies)
			var projected_lv := level_for_exp(int(prog.get("exp", 0)) + exp_gain)
			var rec_lv := stage_recommended_level(stage_num)
			if projected_lv >= rec_lv and not bool(badges_map.get(scenario_id, false)):
				badges_map[scenario_id] = true
				badge_earned = true
				exp_gain += BADGE_BONUS_EXP
				coin_gain += BADGE_BONUS_COINS

		"daily_cap_10":
			var d_rec3: Dictionary = daily_map.get(key, {}) if daily_map.get(key) is Dictionary else {}
			var prev_day3 := int(d_rec3.get("day", -1))
			var cnt3 := int(d_rec3.get("count", 0)) if prev_day3 == day_num else 0
			if cnt3 < 10:
				receipt_changed = true
				daily_map[key] = {"day": day_num, "count": cnt3 + 1}
				exp_gain = maxi(0, int(event.get("base_exp", 5)))
				coin_gain = maxi(0, int(event.get("coin_bonus", 0)))
				reason_tag = "daily_voice"

	if exp_gain <= 0 and coin_gain <= 0 and not badge_earned:
		return {
			"changed": receipt_changed,
			"exp_gained": 0,
			"coins_gained": 0,
			"gift_coins": 0,
			"leveled_up": false,
			"badge_earned": false,
			"reason": reason_tag,
		}

	# Only expired limits may be discarded. Evicting an active receipt lets the
	# same activity pay again, even though its first-clear record still exists.
	if cd_map.size() > 1000:
		for cd_key: Variant in cd_map.keys():
			if now_sec - int(cd_map[cd_key]) >= 300:
				cd_map.erase(cd_key)
	if daily_map.size() > 500:
		for daily_key: Variant in daily_map.keys():
			if int(daily_map[daily_key].get("day", day_num)) < day_num:
				daily_map.erase(daily_key)

	var old_exp := int(prog.get("exp", 0))
	var old_level := level_for_exp(old_exp)
	var old_stars := star_ranks_for_exp(old_exp)
	var new_exp := mini(MAX_EXP, old_exp + exp_gain)
	var new_level := level_for_exp(new_exp)
	var new_stars := star_ranks_for_exp(new_exp)

	prog["exp"] = new_exp
	prog["level"] = new_level
	prog["star_ranks"] = new_stars

	var gift_coins := 0
	var prev_gifted_lv := clampi(int(prog.get("highest_gifted_level", old_level)), 1, MAX_BASE_LEVEL)
	if new_level > prev_gifted_lv:
		for lv_step: int in range(prev_gifted_lv + 1, new_level + 1):
			gift_coins += int(level_info(lv_step)["gift_coins"])
		prog["highest_gifted_level"] = new_level

	var prev_gifted_stars := maxi(0, int(prog.get("gifted_star_ranks", old_stars)))
	if new_stars > prev_gifted_stars:
		gift_coins += (new_stars - prev_gifted_stars) * STAR_PRESTIGE_COINS
		prog["gifted_star_ranks"] = new_stars

	var total_coins_added := coin_gain + gift_coins
	if total_coins_added > 0:
		state_data["coins"] = mini(1_000_000, int(state_data.get("coins", 0)) + total_coins_added)

	var info := level_info(new_level)
	return {
		"changed": true,
		"exp_gained": exp_gain,
		"coins_gained": coin_gain,
		"gift_coins": gift_coins,
		"total_coins_gained": total_coins_added,
		"old_level": old_level,
		"new_level": new_level,
		"old_stars": old_stars,
		"new_stars": new_stars,
		"leveled_up": (new_level > old_level) or (new_stars > old_stars),
		"badge_earned": badge_earned,
		"title_zh": str(info["zh"]) + ((" ★%d" % new_stars) if new_stars > 0 else ""),
		"title_en": str(info["en"]),
		"unlock_zh": str(info["unlock_zh"]),
		"reason": reason_tag,
	}
