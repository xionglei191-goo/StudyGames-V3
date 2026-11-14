extends RefCounted
## Multi-Character Voice Registry for StudyGames V5 (`CharacterVoices`).
## Maps every island NPC, textbook classmate/teacher, 34 landmark & campus residents,
## and storybook narrator to its dedicated voice archetype for Cloud + Offline Neural TTS
## as well as standalone local WAV fallback pitch shaping.

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
	"teacher_gentle": {
		"label_zh": "温柔女老师音",
		"pitch_scale": 1.00,
	},
	"storyteller": {
		"label_zh": "绘本讲故事音",
		"pitch_scale": 1.01,
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
		"label_zh": "俏皮萌宠音",
		"pitch_scale": 1.17,
	},
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
	"textbook_role_lingling_mother": "teacher_gentle",
	"textbook_role_lingling_father": "uncle_warm",
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
	"textbook_bunny": "girl_bright",
	"textbook_kitty": "girl_bright",
	"textbook_baker_bird": "mascot_dino",
	"textbook_doggie": "mascot_dino",
	"textbook_spot": "mascot_dino",
	"textbook_elephant_ella": "grandma_warm",
	"textbook_fendi": "mascot_dino",
	"textbook_nian": "uncle_warm",
	"textbook_qinmou": "artisan_male",
	"textbook_role_xiaoxiao_parrot": "mascot_dino",
}

static func normalize_hint(npc_or_hint: String) -> String:
	var key := npc_or_hint.strip_edges().to_lower()
	return key if not key.is_empty() else "warm"

static func archetype_for(npc_or_hint: String) -> String:
	var key := normalize_hint(npc_or_hint)
	if ARCHETYPES.has(key):
		return key
	if CHARACTER_ARCHETYPE.has(key):
		return str(CHARACTER_ARCHETYPE[key])
	if key.find("bear") >= 0 or key.find("uncle") >= 0 or key.find("father") >= 0:
		return "uncle_warm"
	if key.find("peter") >= 0 or key.find("boy") >= 0:
		return "boy_sunny"
	if key.find("rabbit") >= 0 or key.find("girl") >= 0:
		return "girl_bright"
	if key.find("dino") >= 0 or key.find("bird") >= 0:
		return "mascot_dino"
	return "teacher_gentle"

static func label_zh_for(npc_or_hint: String) -> String:
	var arch := archetype_for(npc_or_hint)
	var info: Dictionary = ARCHETYPES.get(arch, ARCHETYPES["teacher_gentle"])
	return str(info.get("label_zh", "温柔女老师音"))

static func fallback_pitch_scale(npc_or_hint: String) -> float:
	var arch := archetype_for(npc_or_hint)
	var info: Dictionary = ARCHETYPES.get(arch, ARCHETYPES["teacher_gentle"])
	return float(info.get("pitch_scale", 1.0))

static func npc_for_room(room_id: String) -> String:
	if room_id.begins_with("landmark_"):
		var letter := room_id.trim_prefix("landmark_").to_lower()
		return "resident_" + letter
	var campus_map := {
		"school": "resident_school",
		"classroom": "textbook_miss_li",
		"music_room": "resident_music_room",
		"art_room": "resident_art_room",
		"science_room": "resident_science_room",
		"canteen": "resident_canteen",
		"playground": "textbook_peter",
		"football_field": "resident_football_field",
		"village": "npc_bear_uncle",
	}
	if campus_map.has(room_id):
		return str(campus_map[room_id])
	if room_id.begins_with("home"):
		return "teacher_gentle"
	return "warm"
