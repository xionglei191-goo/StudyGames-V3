extends RefCounted
## Multi-Character Voice Registry for StudyGames V9 (`CharacterVoices`).
## Maps every island NPC, parent, teacher, classmate, 34 landmark & campus residents,
## talking mascots, pure animals, and storybook narrator to dedicated voice archetypes
## and organic animal vocalization sound keys.

const ARCHETYPES := {
	"uncle_warm": {
		"label_zh": "暖厚大叔音",
		"pitch_scale": 0.86,
	},
	"elder_wise": {
		"label_zh": "慈祥智者音",
		"pitch_scale": 0.84,
	},
	"artisan_male": {
		"label_zh": "阳光男匠人音",
		"pitch_scale": 0.92,
	},
	"mother_affectionate": {
		"label_zh": "温柔妈妈音",
		"pitch_scale": 0.99,
	},
	"father_warm": {
		"label_zh": "暖心爸爸音",
		"pitch_scale": 0.90,
	},
	"teacher_gentle": {
		"label_zh": "亲切女老师音",
		"pitch_scale": 1.00,
	},
	"storyteller": {
		"label_zh": "绘本姐姐音",
		"pitch_scale": 1.02,
	},
	"grandma_warm": {
		"label_zh": "慈爱长辈女音",
		"pitch_scale": 0.95,
	},
	"artisan_female": {
		"label_zh": "明快女达人音",
		"pitch_scale": 1.04,
	},
	"girl_bright": {
		"label_zh": "元气小女孩音",
		"pitch_scale": 1.12,
	},
	"boy_sunny": {
		"label_zh": "阳光小男孩音",
		"pitch_scale": 1.07,
	},
	"mascot_dino": {
		"label_zh": "奇幻小恐龙音",
		"pitch_scale": 1.14,
	},
	"mascot_parrot": {
		"label_zh": "俏皮小鹦鹉音",
		"pitch_scale": 1.16,
	},
}

const PURE_ANIMAL_KEYS := [
	"textbook_kitty",
	"textbook_doggie",
	"textbook_spot",
	"textbook_bunny",
	"textbook_baker_bird",
	"textbook_elephant_ella",
	"textbook_fendi",
]

const TALKING_MASCOT_KEYS := [
	"textbook_dino",
	"textbook_role_xiaoxiao_parrot",
]

const ANIMAL_SOUND_MAP := {
	"textbook_kitty": "kitty_meow",
	"textbook_doggie": "puppy_woof",
	"textbook_spot": "puppy_woof",
	"textbook_fendi": "puppy_woof",
	"textbook_bunny": "bunny_chirp",
	"textbook_baker_bird": "bird_tweet",
	"textbook_elephant_ella": "elephant_toot",
	"textbook_dino": "dino_chirp",
	"textbook_role_xiaoxiao_parrot": "parrot_squawk",
}

const CHARACTER_ARCHETYPE := {
	"warm": "teacher_gentle",
	"storyteller": "storyteller",
	"narrator": "storyteller",
	"player": "girl_bright",
	# Core island & textbook cast
	"npc_bear_uncle": "uncle_warm",
	"npc_rabbit_gardener": "girl_bright",
	"npc_owl_tutor": "elder_wise",
	"textbook_miss_li": "teacher_gentle",
	"textbook_lingling": "girl_bright",
	"textbook_anne": "girl_bright",
	"textbook_peter": "boy_sunny",
	"textbook_mingming": "boy_sunny",
	"textbook_dongdong": "boy_sunny",
	"textbook_tim": "boy_sunny",
	"textbook_jim": "boy_sunny",
	"textbook_dino": "mascot_dino",
	# 26 Alphabet Landmark Residents (A-Z)
	"resident_a": "girl_bright",
	"resident_b": "uncle_warm",
	"resident_c": "artisan_male",
	"resident_d": "mascot_dino",
	"resident_e": "grandma_warm",
	"resident_f": "grandma_warm",
	"resident_g": "artisan_male",
	"resident_h": "artisan_female",
	"resident_i": "mascot_dino",
	"resident_j": "artisan_male",
	"resident_k": "boy_sunny",
	"resident_l": "artisan_female",
	"resident_m": "uncle_warm",
	"resident_n": "artisan_female",
	"resident_o": "elder_wise",
	"resident_p": "boy_sunny",
	"resident_q": "elder_wise",
	"resident_r": "artisan_female",
	"resident_s": "artisan_male",
	"resident_t": "uncle_warm",
	"resident_u": "mascot_dino",
	"resident_v": "artisan_female",
	"resident_w": "girl_bright",
	"resident_x": "artisan_male",
	"resident_y": "grandma_warm",
	"resident_z": "artisan_male",
	# 8 School Campus Residents
	"resident_school": "elder_wise",
	"resident_classroom": "teacher_gentle",
	"resident_music_room": "artisan_male",
	"resident_art_room": "girl_bright",
	"resident_science_room": "teacher_gentle",
	"resident_canteen": "uncle_warm",
	"resident_playground": "boy_sunny",
	"resident_football_field": "artisan_female",
	# Textbook Expansion Cast
	"textbook_amy": "girl_bright",
	"textbook_daisy": "girl_bright",
	"textbook_kathy": "girl_bright",
	"textbook_kelly": "girl_bright",
	"textbook_lily": "girl_bright",
	"textbook_li_jie": "artisan_female",
	"textbook_dan": "boy_sunny",
	"textbook_harry": "boy_sunny",
	"textbook_robbie": "boy_sunny",
	"textbook_miss_lin": "teacher_gentle",
	"textbook_aunt_carol": "grandma_warm",
	"textbook_role_lingling_mother": "mother_affectionate",
	"textbook_role_lingling_father": "father_warm",
	"textbook_uncle_ben": "uncle_warm",
	"textbook_mr_wang": "artisan_male",
	"textbook_mr_chen": "elder_wise",
	"textbook_old_macdonald": "uncle_warm",
	"textbook_santa_claus": "uncle_warm",
	"textbook_confucius": "elder_wise",
	"textbook_socrates": "elder_wise",
	"textbook_yu_gong": "elder_wise",
	"textbook_jade_emperor": "elder_wise",
	"textbook_qu_yuan": "artisan_male",
	"textbook_zhang_heng": "elder_wise",
	"textbook_yuan_longping": "elder_wise",
	"textbook_tu_youyou": "grandma_warm",
	"textbook_wang_yaping": "teacher_gentle",
	"textbook_chang_e": "storyteller",
	"textbook_andy_armstrong": "artisan_male",
	"textbook_bob_weather_photo": "artisan_male",
	"textbook_bunny": "storyteller",
	"textbook_kitty": "storyteller",
	"textbook_baker_bird": "storyteller",
	"textbook_doggie": "storyteller",
	"textbook_spot": "storyteller",
	"textbook_elephant_ella": "storyteller",
	"textbook_fendi": "storyteller",
	"textbook_nian": "uncle_warm",
	"textbook_qinmou": "artisan_male",
	"textbook_role_xiaoxiao_parrot": "mascot_parrot",
}

static func normalize_hint(npc_or_hint: String) -> String:
	var key := npc_or_hint.strip_edges().to_lower()
	if key.begins_with("actor:"):
		key = key.trim_prefix("actor:").strip_edges()
	return key if not key.is_empty() else "warm"

static func archetype_for(npc_or_hint: String) -> String:
	var key := normalize_hint(npc_or_hint)
	if ARCHETYPES.has(key):
		return key
	if CHARACTER_ARCHETYPE.has(key):
		return str(CHARACTER_ARCHETYPE[key])
	if key.find("mother") >= 0 or key.find("mom") >= 0:
		return "mother_affectionate"
	if key.find("father") >= 0 or key.find("dad") >= 0:
		return "father_warm"
	if key.find("bear") >= 0 or key.find("uncle") >= 0:
		return "uncle_warm"
	if key.find("peter") >= 0 or key.find("boy") >= 0:
		return "boy_sunny"
	if key.find("rabbit") >= 0 or key.find("girl") >= 0:
		return "girl_bright"
	if key.find("parrot") >= 0:
		return "mascot_parrot"
	if key.find("dino") >= 0 or key.find("bird") >= 0:
		return "mascot_dino"
	return "teacher_gentle"

static func label_zh_for(npc_or_hint: String) -> String:
	var arch := archetype_for(npc_or_hint)
	var info: Dictionary = ARCHETYPES.get(arch, ARCHETYPES["teacher_gentle"])
	return str(info.get("label_zh", "亲切女老师音"))

static func fallback_pitch_scale(npc_or_hint: String) -> float:
	var arch := archetype_for(npc_or_hint)
	var info: Dictionary = ARCHETYPES.get(arch, ARCHETYPES["teacher_gentle"])
	return float(info.get("pitch_scale", 1.0))

static func is_pure_animal(npc_or_hint: String) -> bool:
	var key := normalize_hint(npc_or_hint)
	return key in PURE_ANIMAL_KEYS

static func is_talking_mascot(npc_or_hint: String) -> bool:
	var key := normalize_hint(npc_or_hint)
	return key in TALKING_MASCOT_KEYS

static func animal_sound_key(npc_or_hint: String) -> String:
	var key := normalize_hint(npc_or_hint)
	return str(ANIMAL_SOUND_MAP.get(key, ""))

static func speaker_badge_label_zh(npc_or_hint: String) -> String:
	if is_pure_animal(npc_or_hint):
		return "萌宠原声 · 绘本姐姐慢读"
	return label_zh_for(npc_or_hint)

static func strip_animal_interjection(text: String, _lang: String = "en") -> String:
	var out := text.strip_edges()
	if out.is_empty():
		return ""
	var re_en := RegEx.new()
	re_en.compile("^(?i)\\s*(?:(?:meow|mew|purr|woof|arf|tweet|chirp|squeak|toot|squawk)\\b[\\s,]*)+(?:[~!?.…—–-]+[\\s,~!?.…—–-]*|$)")
	var re_zh := RegEx.new()
	re_zh.compile("^\\s*(?:(?:呼噜喵|喵呜|喵喵|喵|汪汪|汪|啾啾|啾)[\\s,，、]*)+(?:[~～!！?？.。…—–-]+[\\s,，、~～!！?？.。…—–-]*|$)")
	for _pass in range(2):
		var m_en := re_en.search(out)
		if m_en != null and m_en.get_start() == 0 and m_en.get_end() > 0:
			out = out.substr(m_en.get_end()).strip_edges()
		var m_zh := re_zh.search(out)
		if m_zh != null and m_zh.get_start() == 0 and m_zh.get_end() > 0:
			out = out.substr(m_zh.get_end()).strip_edges()
	return out

static func npc_for_room(room_id: String) -> String:
	if room_id.begins_with("landmark_"):
		var letter := room_id.trim_prefix("landmark_").to_lower()
		return "resident_" + letter
	var campus_map := {
		"school": "textbook_lingling",
		"classroom": "textbook_miss_li",
		"music_room": "textbook_miss_lin",
		"art_room": "textbook_lingling",
		"science_room": "textbook_mr_chen",
		"canteen": "textbook_dongdong",
		"playground": "textbook_peter",
		"football_field": "textbook_mr_wang",
		"village": "npc_bear_uncle",
		"home": "textbook_role_lingling_mother",
		"home_kitchen": "textbook_role_lingling_mother",
		"home_bedroom": "textbook_role_lingling_mother",
		"home_bathroom": "textbook_role_lingling_mother",
		"home_balcony": "textbook_role_lingling_mother",
		"home_study": "textbook_role_lingling_father",
		"home_dining": "textbook_role_lingling_father",
		"home_estate": "textbook_role_lingling_father",
	}
	if campus_map.has(room_id):
		return str(campus_map[room_id])
	if room_id.begins_with("home"):
		return "textbook_role_lingling_mother"
	return "warm"
