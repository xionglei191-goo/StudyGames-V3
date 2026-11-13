extends SceneTree
## Phase 15 Comprehensive Automated Verification Suite (`test_phase15_complete.gd`).
## Verifies Module 1A (`PopupBookTheater` ZH narration, follow-along, 5 3D scenery themes),
## Module 1B (`MemoryPalaceLoci3D` 3D room shrines & H3 gap-recall tour),
## Module 2 (`SituationalRoleplay` 3-turn dialogues & `MorningWakeMailbox` spaced wake-up),
## Module 3 (Bilingual Campus & Household immersion without polluting formal mastery),
## and Module 4 (`IslandSans.otf` full V5 glyph coverage + immutable baseline locks).

const PalaceLoci = preload("res://gameplay/memory_palace_loci_3d.gd")
const Roleplay = preload("res://gameplay/situational_roleplay.gd")
const WakeMailbox = preload("res://gameplay/morning_wake_mailbox.gd")
const StoryContent = preload("res://ui/memory_story_content.gd")

var game: Node3D
var state: Node
var checks := 0
var failures: Array[String] = []
var prod_before := ""
var spoken_log: Array[Dictionary] = []

const PROD_SAVE := "user://island-save-v1.json"
const EXPECTED_CATALOG_SHA := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const EXPECTED_PROLOGUE_SHA := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

func _initialize() -> void:
	_run.call_deferred()

func _check(id: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures.append(id)
		push_error("PHASE15_FAIL: " + id)

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	prod_before = FileAccess.get_sha256(PROD_SAVE) if FileAccess.file_exists(PROD_SAVE) else "missing"

	# Baseline immutability checks
	_check("catalog_sha256_locked", FileAccess.get_sha256("res://data/learning/catalog.json") == EXPECTED_CATALOG_SHA)
	_check("prologue_sha256_locked", FileAccess.get_sha256("res://data/learning/prologue.json") == EXPECTED_PROLOGUE_SHA)

	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.tts_speak_requested.connect(func(txt: String, lang: String, hint: String):
			spoken_log.append({"text": txt, "lang": lang, "hint": hint})
		)

	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for _f in range(600):
		await process_frame
		if game.scene_ready:
			break
	_check("scene_ready", game.scene_ready)
	if not game.scene_ready:
		_finish()
		return

	state = root.get_node("State")
	_check("isolated_test_save", str(state.save_path).begins_with("user://validation-"))
	state.data = state._default_state()
	game.muted = true
	game.ui.reduced_motion = true

	# Module 4: Bundled IslandSans.otf coverage check
	var font: Font = load("res://assets/fonts/IslandSans.otf")
	_check("island_sans_loaded", font != null)
	if font != null:
		for ch: String in "◈★☆▼▶♪木琴鲸歌磁铁遮罩温故信":
			_check("font_glyph_" + ch, font.has_char(ch.unicode_at(0)))

	# Module 1B: 3D Room Memory Palace Shrine & Tour
	await game.change_room("classroom")
	await _frames(6)
	_check("palace_loci_node_exists", is_instance_valid(game.palace_loci))
	_check("classroom_has_palace_shrine", game.palace_loci.has_shrine)
	_check("shrine_zero_colliders", game.palace_loci.find_children("*", "CollisionObject3D", true, false).is_empty())
	var spawn_pt: Vector3 = game.metadata.get("spawn", Vector3.ZERO)
	var shrine_pt: Vector3 = game.palace_loci.shrine_pos
	var dist_spawn := Vector2(shrine_pt.x - spawn_pt.x, shrine_pt.z - spawn_pt.z).length()
	_check("shrine_clear_of_spawn", dist_spawn >= 1.2)

	var tour_ok: bool = game.palace_loci.open_room_palace_tour(0)
	await _frames(3)
	_check("room_palace_tour_opens", tour_ok and game.ui.current_panel == "v5_palace_tour")
	var classroom_stories := PalaceLoci.stories_for_room("classroom")
	_check("classroom_has_stories", not classroom_stories.is_empty())
	var sample_eid := PalaceLoci.best_entry_id_for_state(classroom_stories[0] as Dictionary, state)
	await game._on_action("open_palace_gap:" + sample_eid)
	await _frames(5)
	var popup: Node = game.journey.current_memory
	_check("gap_recall_opens_popup_theater", is_instance_valid(popup) and popup.name == "PopupBookTheater")
	if is_instance_valid(popup):
		_check("gap_recall_in_h3_practice_mode", str(popup.view_mode) == "practice" and int(popup.support_level) == 3 and popup._revealed_gaps.size() >= 1)

		# Module 1A: Chinese story narration + follow-along + 5 scenery themes
		popup._on_toggle_puzzle() # switch back to story view
		await _frames(2)
		spoken_log.clear()
		popup._on_speak_story_zh()
		var zh_emitted := false
		for item: Dictionary in spoken_log:
			if str(item.get("lang", "")) == "zh" and not str(item.get("text", "")).contains("【"):
				zh_emitted = true
		_check("popup_story_zh_tts_clean_and_emitted", zh_emitted)

		var cheers_before := int(state.data.v4.get("voice_cheers", 0))
		popup._on_follow_along_word()
		_check("popup_follow_along_increments_cheers", int(state.data.v4.get("voice_cheers", 0)) == cheers_before + 1)

		var themes_seen: Dictionary = {}
		for rid_test: String in ["landmark_W", "landmark_X", "home", "landmark_C", "landmark_F"]:
			themes_seen[str(popup._scenery_kind_for_room(rid_test))] = true
		_check("popup_5_scenery_themes_distinct", themes_seen.size() == 5)
	game._close()

	# Module 3: Bilingual Campus & Household Immersion (must never mutate state.data.learning!)
	state.data.learning.clear()
	await game.change_room("science_room")
	await _frames(3)
	spoken_log.clear()
	game.start_activity("science")
	await _frames(3)
	var sboard: Node = game.ui.activity_board
	sboard.choose_pigment(1) # yellow
	sboard.choose_pigment(2) # blue
	sboard.mix()
	var green_spoken := false
	for item: Dictionary in spoken_log:
		if str(item.get("text", "")).contains("Yellow and blue make green"):
			green_spoken = true
	_check("science_mix_speaks_bilingual_formula", green_spoken and sboard.result_label.text.contains("Yellow + Blue = Green"))
	_check("bilingual_campus_never_touches_formal_learning", state.data.learning.is_empty())
	game._close()

	# Module 2A: Multi-Turn Situational Roleplay (3 turns + distractor recast + coin reward)
	for sc_id: String in ["bakery", "post_office", "weather_station", "canteen", "classroom", "playground", "home", "library", "dynamic_landmark_B"]:
		var sc := Roleplay.get_scenario(sc_id, game)
		_check("roleplay_3_turns_" + sc_id, (sc.get("turns", []) as Array).size() == 3)

	var coins_before_rp := int(state.data.coins)
	await game._on_action("v5_roleplay_start:bakery")
	await _frames(2)
	# Pick distractor on turn 0 (choice 2) -> stays on turn 0 with recast!
	await game._on_action("v5_roleplay_pick:bakery:0:2")
	await _frames(2)
	_check("roleplay_distractor_recasts_safely", game.ui.current_panel == "v5_roleplay")
	# Complete turns 0, 1, 2 cleanly
	await game._on_action("v5_roleplay_pick:bakery:0:0")
	await game._on_action("v5_roleplay_pick:bakery:1:0")
	await game._on_action("v5_roleplay_pick:bakery:2:0")
	await _frames(2)
	_check("roleplay_3_turns_complete_and_reward", game.ui.current_panel == "v5_roleplay_done" and int(state.data.coins) == coins_before_rp + 4)
	game._close()

	# Module 2B: Morning Wake-Up Mailbox (prioritizes fragile words without spoiling spelling)
	state.record_stealth_evidence({"word": "umbrella", "support_level": 3, "correct": false, "context": "test_fragile"})
	var wake_cards := WakeMailbox.select_daily_wake_cards(state, 3)
	_check("wake_mailbox_selects_3_cards", wake_cards.size() == 3)
	_check("wake_mailbox_prioritizes_fragile_umbrella", not wake_cards.is_empty() and str(wake_cards[0].get("word", "")).to_lower() == "umbrella")
	await game._on_action("v5_wake_mailbox")
	await _frames(3)
	_check("wake_mailbox_panel_opens", game.ui.current_panel == "v5_wake_mailbox")
	game._close()

	# Clean up isolated validation save files
	for suffix: String in ["", ".bak", ".tmp"]:
		var p: String = str(state.save_path) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	var prod_after := FileAccess.get_sha256(PROD_SAVE) if FileAccess.file_exists(PROD_SAVE) else "missing"
	_check("production_save_unchanged", prod_before == prod_after)
	_finish()

func _finish() -> void:
	print("PHASE15_COMPLETE checks=%d failures=%d %s" % [checks, failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
