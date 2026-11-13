extends MarginContainer
## V5 3D Interactive Pop-up Book Mnemonic Stage (`PopupBookTheater`).
## Renders a sunlit Forward+ 3D miniature wooden desk, nursery window backdrop,
## and folding cardstock Pop-up Book where 26-letter illustrated standee puppets
## spring upright from the page crease, act out mnemonic beats, and fold down
## for hands-on wooden letter-tile assembly. Zero raw OS emojis.
## Fully compatible with `JourneyController` / `MemorySink` durable cue & response schema.

signal help_shown(event: Dictionary)
signal response_submitted(response: Dictionary)
signal progress_changed(snapshot: Dictionary)
signal close_requested(result: Dictionary)
signal visit_palace_requested(room_id: String)

const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const Bridge = preload("res://core/ai_companion_bridge.gd")
const CHOREO_PATH := "res://data/learning/popup_choreography_v4.json"
const PALACE_V5_PATH := "res://data/learning/memory_palace_v5.json"

const DANCE_LABELS := {
	"bounce_wave": "欢跳挥手舞",
	"orbit_dance": "圆舞旋转步",
	"peekaboo_pop": "躲猫猫弹跳",
	"domino_cheer": "多米诺人浪",
	"starlight_float": "星光漂浮舞",
}

const SUPPORT_KINDS := [
	"unassisted_attempt", "location_and_meaning", "first_step",
	"gap_completion", "step_bridge", "full_demonstration"
]

var entry: Dictionary = {}
var invocation_id := ""
var attempt_id := ""
var current_beat := 1
var seen_beats: Array = []
var support_level := 5
var max_help_level := 0
var view_mode := "story"
var cue_events: Array = []
var first_response: Variant = null
var later_response: Variant = null
var draft_response := ""
var _revealed_gaps: Array = []
var _bridge_position := 1
var _show_sequence := false
var _animation_state: Dictionary = {}
var _reduced_motion := false
var _content_unavailable := false
var _ready_done := false
var _setup_revision := 0

# 3D Pop-up Stage Nodes
var _vp_container: SubViewportContainer
var _viewport: SubViewport
var _book_root: Node3D
var _scenery_root: Node3D
var _puppet_root: Node3D
var _spotlight: SpotLight3D
var _puppets: Array[Dictionary] = []
var _stage_time := 0.0
var _playing_beat := false
var _play_timer := 0.0
var _book_open_progress := 0.0

# 2D Cozy Controls
var _title_label: Label
var _subtitle_label: Label
var _palace_btn: Button
var _story_banner: Label
var _story_voice_btn: Button
var _follow_btn: Button
var _beat_nav_box: HBoxContainer
var _prev_beat_btn: Button
var _beat_counter_lbl: Label
var _next_beat_btn: Button
var _puzzle_box: VBoxContainer
var _slots_row: HBoxContainer
var _tiles_row: HBoxContainer
var _type_input: LineEdit
var _feedback_label: Label
var _usage_btn: Button
var _toggle_puzzle_btn: Button
var _audio: AudioStreamPlayer
var _mic_player: AudioStreamPlayer
var _mic_capture: AudioEffectCapture
var _mic_bus := ""
var _mic_frames := PackedVector2Array()
var _mic_recording := false
var _mic_elapsed := 0.0
var _mic_sample_rate := 48000.0
var _asr_request: HTTPRequest
var _built_tokens: Array[String] = []
var _current_choreo: Dictionary = {}
var _current_palace: Dictionary = {}

static var _letter_tex_cache: Dictionary = {}
static var _choreo_cache: Dictionary = {}
static var _palace_cache: Dictionary = {}

static func _load_choreo_map() -> Dictionary:
	if _choreo_cache.is_empty() and FileAccess.file_exists(CHOREO_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHOREO_PATH))
		if parsed is Dictionary:
			var entries_val: Variant = (parsed as Dictionary).get("entries", {})
			if entries_val is Dictionary:
				_choreo_cache = entries_val as Dictionary
	return _choreo_cache

static func _load_palace_map() -> Dictionary:
	if _palace_cache.is_empty() and FileAccess.file_exists(PALACE_V5_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALACE_V5_PATH))
		if parsed is Dictionary:
			var stories_val: Variant = (parsed as Dictionary).get("stories", {})
			if stories_val is Dictionary:
				_palace_cache = stories_val as Dictionary
	return _palace_cache

func dance_style() -> String:
	var p_dance := str(_current_palace.get("dance_style", "")).strip_edges()
	if not p_dance.is_empty():
		return p_dance
	return str(_current_choreo.get("dance_style", "bounce_wave"))

func example_en() -> String:
	var p_en := str(_current_palace.get("example_en", "")).strip_edges()
	if not p_en.is_empty():
		return p_en
	return str(_current_choreo.get("example_en", ""))

func example_zh() -> String:
	var p_zh := str(_current_palace.get("example_zh", "")).strip_edges()
	if not p_zh.is_empty():
		return p_zh
	return str(_current_choreo.get("example_zh", ""))

func palace_room_id() -> String:
	return str(_current_palace.get("palace_room_id", "")).strip_edges()

func palace_room_zh() -> String:
	return str(_current_palace.get("palace_room_zh", "")).strip_edges()

func palace_locus_zh() -> String:
	return str(_current_palace.get("palace_locus_zh", "")).strip_edges()

func story_title_zh() -> String:
	return str(_current_palace.get("title_zh", "")).strip_edges()

func meaning_climax_zh() -> String:
	return str(_current_palace.get("meaning_climax_zh", "")).strip_edges()

func _ready() -> void:
	name = "PopupBookTheater"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	theme = Style.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_build_layout()
	_ready_done = true
	if not entry.is_empty():
		_present_initial.call_deferred(_setup_revision)

func setup(value: Dictionary, resume: Dictionary = {}) -> void:
	entry = value.duplicate(true)
	_setup_revision += 1
	invocation_id = str(resume.get("invocation_id", ""))
	attempt_id = str(resume.get("attempt_id", ""))
	current_beat = clampi(int(resume.get("current_beat", 1)), 1, maxi(1, entry.get("story_beats", []).size()))
	seen_beats = resume.get("seen_beats", []).duplicate(true)
	support_level = clampi(int(resume.get("support_level", 5)), 0, 5)
	_animation_state = {}
	max_help_level = int(resume.get("max_help_level", 0))
	view_mode = str(resume.get("view_mode", "story"))
	cue_events = resume.get("cue_events", []).duplicate(true)
	first_response = resume.get("first_response", null)
	later_response = resume.get("later_response", null)
	draft_response = str(resume.get("draft_response", ""))
	_revealed_gaps = resume.get("revealed_gaps", []).duplicate()
	_bridge_position = int(resume.get("bridge_position", 1))
	_show_sequence = bool(resume.get("show_sequence", false))
	if _show_sequence:
		support_level = 5
	_content_unavailable = entry.is_empty()
	var cmap: Dictionary = _load_choreo_map()
	var eid_key: String = str(entry.get("entry_id", ""))
	_current_choreo = (cmap[eid_key] as Dictionary) if (cmap.has(eid_key) and cmap[eid_key] is Dictionary) else {}
	var pmap: Dictionary = _load_palace_map()
	var sid_key: String = str(entry.get("story_id", ""))
	_current_palace = (pmap[sid_key] as Dictionary) if (pmap.has(sid_key) and pmap[sid_key] is Dictionary) else {}
	_built_tokens.clear()
	_playing_beat = false
	_book_open_progress = 0.0
	if _ready_done:
		_present_initial.call_deferred(_setup_revision)

func _present_initial(rev: int) -> void:
	if rev != _setup_revision or _content_unavailable:
		return
	_rebuild_scenery_backdrop()
	_rebuild_3d_puppets()
	_refresh_ui()
	if cue_events.is_empty():
		_record_visible_cue("initial_open", "system")
		_emit_progress()
	_playing_beat = not _reduced_motion
	_play_timer = 0.0

func get_resume() -> Dictionary:
	return {
		"invocation_id": invocation_id,
		"attempt_id": attempt_id,
		"entry_id": entry.get("entry_id", ""),
		"content_revision": entry.get("content_revision", ""),
		"codebook_revision": entry.get("codebook_revision", ""),
		"current_beat": current_beat,
		"seen_beats": seen_beats.duplicate(),
		"support_level": support_level,
		"max_help_level": max_help_level,
		"cue_events": cue_events.duplicate(true),
		"first_response": first_response,
		"later_response": later_response,
		"view_mode": view_mode,
		"draft_response": draft_response,
		"revealed_gaps": _revealed_gaps.duplicate(),
		"bridge_position": _bridge_position,
		"show_sequence": _show_sequence,
		"animation_state": {}
	}

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_playing_beat = false

func set_paused(value: bool) -> void:
	if value:
		_playing_beat = false
		_cancel_mic_follow()
		if is_instance_valid(_audio):
			_audio.stop()

func _build_layout() -> void:
	var root_col := VBoxContainer.new()
	root_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_theme_constant_override("separation", 10)
	add_child(root_col)

	# 1. Warm Tactile Top Ribbon (Crisp Vector Icons, Zero Truncation)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_col.add_child(top_bar)

	var book_ic := TextureRect.new()
	book_ic.texture = Style.icon("book")
	book_ic.custom_minimum_size = Vector2(34, 34)
	book_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	book_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(book_ic)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top_bar.add_child(title_box)

	_title_label = Style.text("3D 立体翻翻书剧场", 24, Style.INK)
	_title_label.add_theme_font_override("font", Style.heading_font())
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_title_label)
	_subtitle_label = Style.text("", 14, Style.MUTED)
	_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_subtitle_label)

	top_bar.add_child(_pill_btn("听读音", "speaker", _on_speak_word, false))
	_follow_btn = _pill_btn("跟读", "mic", _on_follow_along_word, false)
	top_bar.add_child(_follow_btn)
	top_bar.add_child(_pill_btn("演立体剧", "play", _on_play_theater, false))
	top_bar.add_child(_pill_btn("小提示", "bulb", _on_gentle_hint, false))
	_toggle_puzzle_btn = _pill_btn("拼立体卡", "sparkle", _on_toggle_puzzle, true)
	top_bar.add_child(_toggle_puzzle_btn)
	var close_btn := _pill_btn("", "close", func(): request_close("completed" if (first_response != null and bool(first_response.get("correct", false))) or (later_response != null and bool(later_response.get("correct", false))) else "paused"), false)
	close_btn.custom_minimum_size = Vector2(42, 42)
	close_btn.tooltip_text = "收好立体书 · Esc"
	top_bar.add_child(close_btn)

	# 1.5 Spatial Memory Palace Locus Pill (Real Walkable Island Room + Concrete Corner!)
	_palace_btn = _pill_btn("记忆宫殿桩点", "compass", _on_visit_palace, false)
	_palace_btn.name = "PalaceLocusBadge"
	_palace_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_palace_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_palace_btn.custom_minimum_size = Vector2(0, 34)
	_palace_btn.add_theme_font_size_override("font_size", 14)
	var p_norm := Style.keycap(Color("f5edda"), Color("d8c39b"), 2, 14, 14, 5)
	p_norm.shadow_size = 0
	_palace_btn.add_theme_stylebox_override("normal", p_norm)
	_palace_btn.add_theme_stylebox_override("hover", Style.keycap(Color("fdf3da"), Style.GOLD, 2, 14, 14, 5))
	_palace_btn.tooltip_text = "点击可前往这座记忆宫殿的真实 3D 房间散步观察"
	root_col.add_child(_palace_btn)

	# 2. Sunlit 3D Pop-up Book Viewport Stage
	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.custom_minimum_size = Vector2(0, 290)
	var frame_sb := Style.keycap(Color("efe5cf"), Color("cfb993"), 4, 22, 6, 6)
	stage_frame.add_theme_stylebox_override("panel", frame_sb)
	root_col.add_child(stage_frame)

	_vp_container = SubViewportContainer.new()
	_vp_container.stretch = true
	_vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(_vp_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 420)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp_container.add_child(_viewport)

	_build_3d_book_environment()

	# 3. Story Caption & Beat Flipper Bar
	var caption_card := PanelContainer.new()
	var cap_sb := Style.keycap(Color("faf6ea"), Color("ded1b6"), 3, 18, 16, 12)
	cap_sb.shadow_size = 0
	caption_card.add_theme_stylebox_override("panel", cap_sb)
	root_col.add_child(caption_card)

	var cap_col := VBoxContainer.new()
	cap_col.add_theme_constant_override("separation", 8)
	caption_card.add_child(cap_col)

	var beat_row := HBoxContainer.new()
	beat_row.add_theme_constant_override("separation", 12)
	cap_col.add_child(beat_row)

	_story_banner = Style.text("", 19, Style.INK)
	_story_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beat_row.add_child(_story_banner)

	_story_voice_btn = _pill_btn("讲故事", "chat", _on_speak_story_zh, false)
	_story_voice_btn.name = "StoryVoiceBtn"
	_story_voice_btn.tooltip_text = "用温暖中文语音伴读这一幕奇象故事"
	beat_row.add_child(_story_voice_btn)

	_beat_nav_box = HBoxContainer.new()
	_beat_nav_box.add_theme_constant_override("separation", 8)
	beat_row.add_child(_beat_nav_box)

	_prev_beat_btn = _pill_btn("上一折", "", func(): navigate_beat(-1), false)
	_beat_counter_lbl = Style.text("1 / 1", 15, Style.MUTED)
	_next_beat_btn = _pill_btn("下一折", "", func(): navigate_beat(1), false)
	_beat_nav_box.add_child(_prev_beat_btn)
	_beat_nav_box.add_child(_beat_counter_lbl)
	_beat_nav_box.add_child(_next_beat_btn)

	_usage_btn = _pill_btn("生活例句", "speaker", _on_speak_example, false)
	_usage_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_usage_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_usage_btn.custom_minimum_size = Vector2(0, 38)
	_usage_btn.add_theme_font_size_override("font_size", 15)
	var u_norm := Style.keycap(Color("f3efe1"), Color("dfd3ba"), 2, 14, 14, 7)
	u_norm.shadow_size = 0
	_usage_btn.add_theme_stylebox_override("normal", u_norm)
	_usage_btn.add_theme_stylebox_override("hover", Style.keycap(Color("fdf3dc"), Style.GOLD, 2, 14, 14, 7))
	cap_col.add_child(_usage_btn)

	# 4. Interactive Wooden Token Assembly Tray (shown in Puzzle Mode)
	_puzzle_box = VBoxContainer.new()
	_puzzle_box.add_theme_constant_override("separation", 8)
	_puzzle_box.hide()
	cap_col.add_child(_puzzle_box)

	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 8)
	_puzzle_box.add_child(_slots_row)

	_tiles_row = HBoxContainer.new()
	_tiles_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tiles_row.add_theme_constant_override("separation", 8)
	_puzzle_box.add_child(_tiles_row)

	var manual_row := HBoxContainer.new()
	manual_row.alignment = BoxContainer.ALIGNMENT_CENTER
	manual_row.add_theme_constant_override("separation", 10)
	_puzzle_box.add_child(manual_row)

	_type_input = LineEdit.new()
	_type_input.placeholder_text = "点击上方木块拼装，也可以直接在这里输入英文……"
	_type_input.custom_minimum_size = Vector2(360, 40)
	_type_input.text_submitted.connect(submit_response)
	manual_row.add_child(_type_input)

	manual_row.add_child(_pill_btn("拼好啦 · 立起纸偶", "sparkle", func(): submit_response(_type_input.text), true))
	manual_row.add_child(_pill_btn("清空重摆", "undo", _reset_tokens, false))

	_feedback_label = Style.text("", 17, Color("446e3c"))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_col.add_child(_feedback_label)

func _pill_btn(caption: String, icon_name: String, cb: Callable, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = caption
	if not icon_name.is_empty():
		btn.icon = Style.icon(icon_name)
		btn.add_theme_constant_override("icon_max_width", 19)
		btn.add_theme_constant_override("h_separation", 6)
	if caption.is_empty():
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 15)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.theme_type_variation = "PrimaryButton" if primary else "Button"
	btn.pressed.connect(cb)
	return btn

func _toy_mat(col: Color, rough: float = 0.56, coat: float = 0.20) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if coat > 0.01:
		m.clearcoat_enabled = true
		m.clearcoat = coat
		m.clearcoat_roughness = 0.35
	return m

func _build_3d_book_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("dff1fa")
	sky_mat.sky_horizon_color = Color("fff6e4")
	sky_mat.ground_horizon_color = Color("fff6e4")
	sky_mat.ground_bottom_color = Color("f2e5cb")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.62
	env.ambient_light_color = Color("fff7e6")
	env.ambient_light_energy = 0.92
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.06
	if DisplayServer.get_name() != "headless":
		env.ssao_enabled = true
		env.ssao_radius = 0.45
		env.ssao_intensity = 1.25
		env.glow_enabled = true
		env.glow_intensity = 0.16
	env_node.environment = env
	_viewport.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, -24, 0)
	key.light_color = Color("fff5df")
	key.light_energy = 0.90
	key.shadow_enabled = true
	key.shadow_opacity = 0.36
	key.shadow_blur = 1.6
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 145, 0)
	fill.light_color = Color("e8f3fa")
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	_viewport.add_child(fill)

	_spotlight = SpotLight3D.new()
	_spotlight.position = Vector3(0.0, 4.4, 1.4)
	_spotlight.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	_spotlight.light_color = Color("ffe9b5")
	_spotlight.light_energy = 1.15
	_spotlight.spot_range = 9.0
	_spotlight.spot_angle = 32.0
	_viewport.add_child(_spotlight)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 33.5
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 3.55, 5.75), Vector3(0.0, 0.62, -0.15), Vector3.UP)

	# Sunlit Cozy Nursery Reading Nook Wall & Window Backdrop (Eliminates muddy void!)
	var studio_wall := MeshInstance3D.new()
	var wbox := BoxMesh.new()
	wbox.size = Vector3(18.0, 8.0, 0.25)
	studio_wall.mesh = wbox
	studio_wall.position = Vector3(0.0, 3.2, -3.35)
	studio_wall.material_override = _toy_mat(Color("f7efe0"), 0.85, 0.0)
	_viewport.add_child(studio_wall)

	var wainscot := MeshInstance3D.new()
	var wsbox := BoxMesh.new()
	wsbox.size = Vector3(18.0, 1.65, 0.32)
	wainscot.mesh = wsbox
	wainscot.position = Vector3(0.0, 0.60, -3.30)
	wainscot.material_override = _toy_mat(Color("e6d8be"), 0.78, 0.05)
	_viewport.add_child(wainscot)

	# Sunny Sky Window Pane on Upper Wall
	var win_glass := MeshInstance3D.new()
	var wgbox := BoxMesh.new()
	wgbox.size = Vector3(4.6, 2.2, 0.06)
	win_glass.mesh = wgbox
	win_glass.position = Vector3(-2.6, 2.55, -3.20)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("dff2fc")
	gmat.emission_enabled = true
	gmat.emission = Color("e8f6ff")
	gmat.emission_energy_multiplier = 0.42
	gmat.roughness = 0.25
	win_glass.material_override = gmat
	_viewport.add_child(win_glass)

	# Warm Honey-Oak Study Desk
	var desk := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(16.0, 0.40, 7.2)
	desk.mesh = dbox
	desk.position = Vector3(0.0, -0.32, 0.1)
	desk.material_override = _toy_mat(Color("b68252"), 0.50, 0.25)
	_viewport.add_child(desk)

	# Soft Sage Linen Desk Blotter Mat
	var mat_mesh := MeshInstance3D.new()
	var mbox := BoxMesh.new()
	mbox.size = Vector3(8.8, 0.04, 4.7)
	mat_mesh.mesh = mbox
	mat_mesh.position = Vector3(0.0, -0.10, 0.0)
	mat_mesh.material_override = _toy_mat(Color("d3e2c8"), 0.82, 0.04)
	_viewport.add_child(mat_mesh)

	# Open 3D Hardcover Pop-up Book
	_book_root = Node3D.new()
	_book_root.name = "PopupHardcoverBook"
	_viewport.add_child(_book_root)

	var cover_mat := _toy_mat(Color("cc6e5c"), 0.52, 0.22)
	var page_mat := _toy_mat(Color("fdf9ef"), 0.70, 0.08)
	var gold_mat := _toy_mat(Color("e8be66"), 0.30, 0.45)

	for side: float in [-1.0, 1.0]:
		var cover := MeshInstance3D.new()
		var cbox := BoxMesh.new()
		cbox.size = Vector3(3.65, 0.10, 4.05)
		cover.mesh = cbox
		cover.position = Vector3(side * 1.86, -0.02, 0.0)
		cover.rotation_degrees.z = side * -1.8
		cover.material_override = cover_mat
		_book_root.add_child(cover)

		var page := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(3.46, 0.14, 3.82)
		page.mesh = pbox
		page.position = Vector3(side * 1.75, 0.07, 0.0)
		page.rotation_degrees.z = side * -2.2
		page.material_override = page_mat
		_book_root.add_child(page)

	var spine := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.14
	scyl.bottom_radius = 0.14
	scyl.height = 4.08
	spine.mesh = scyl
	spine.rotation_degrees.x = 90.0
	spine.position = Vector3(0.0, 0.01, 0.0)
	spine.material_override = gold_mat
	_book_root.add_child(spine)

	_scenery_root = Node3D.new()
	_scenery_root.name = "ThemedPaperScenery"
	_book_root.add_child(_scenery_root)
	_rebuild_scenery_backdrop()

	_puppet_root = Node3D.new()
	_puppet_root.name = "StandeePuppets"
	_book_root.add_child(_puppet_root)

func _scenery_kind_for_room(rid: String) -> String:
	if rid in ["landmark_B", "landmark_W", "landmark_I"]:
		return "ocean"
	if rid in ["landmark_X", "landmark_S", "landmark_D", "music_room"]:
		return "stage"
	if rid.begins_with("home") or rid in ["landmark_Q", "landmark_L"]:
		return "home"
	if rid in ["landmark_C", "landmark_J", "canteen"]:
		return "bakery"
	return "nature"

func _rebuild_scenery_backdrop() -> void:
	if not is_instance_valid(_scenery_root):
		return
	for ch: Node in _scenery_root.get_children():
		_scenery_root.remove_child(ch)
		ch.queue_free()

	var kind := _scenery_kind_for_room(palace_room_id())
	var back_col := Color("9ed18b")
	var mid_col := Color("bbe09e")
	var orb_col := Color("ffd96b")
	match kind:
		"ocean":
			back_col = Color("73b9d9")
			mid_col = Color("9fd6ec")
			orb_col = Color("ffe694")
		"stage":
			back_col = Color("75689e")
			mid_col = Color("9c8ec4")
			orb_col = Color("ffe074")
		"home":
			back_col = Color("df9b79")
			mid_col = Color("f2cfa8")
			orb_col = Color("ffd56b")
		"bakery":
			back_col = Color("e59da4")
			mid_col = Color("f6cad0")
			orb_col = Color("ffe17d")

	var hill_back := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(6.2, 1.08, 0.05)
	hill_back.mesh = hbox
	hill_back.position = Vector3(0.0, 0.64, -1.45)
	hill_back.material_override = _toy_mat(back_col, 0.68, 0.10)
	_scenery_root.add_child(hill_back)

	var hill_mid := MeshInstance3D.new()
	var hmbox := BoxMesh.new()
	hmbox.size = Vector3(5.4, 0.64, 0.05)
	hill_mid.mesh = hmbox
	hill_mid.position = Vector3(0.0, 0.42, -1.08)
	hill_mid.material_override = _toy_mat(mid_col, 0.68, 0.10)
	_scenery_root.add_child(hill_mid)

	var sun_disc := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.40
	sc.bottom_radius = 0.40
	sc.height = 0.04
	sun_disc.mesh = sc
	sun_disc.rotation_degrees.x = 90.0
	sun_disc.position = Vector3(2.15, 1.35, -1.52)
	sun_disc.material_override = _toy_mat(orb_col, 0.36, 0.28)
	_scenery_root.add_child(sun_disc)

	# Distinct 3D Paper Toppers per Memory Palace Theme!
	if kind == "stage":
		for sx: float in [-2.1, -0.7, 0.8]:
			var star_card := MeshInstance3D.new()
			var p_prism := PrismMesh.new()
			p_prism.size = Vector3(0.32, 0.30, 0.04)
			star_card.mesh = p_prism
			star_card.position = Vector3(sx, 1.32, -1.40)
			star_card.material_override = _toy_mat(Color("ffdf6e"), 0.34, 0.30)
			_scenery_root.add_child(star_card)
	elif kind == "ocean":
		for wx: float in [-1.8, 0.0, 1.8]:
			var crest := MeshInstance3D.new()
			var c_cyl := CylinderMesh.new()
			c_cyl.top_radius = 0.46
			c_cyl.bottom_radius = 0.46
			c_cyl.height = 0.04
			crest.mesh = c_cyl
			crest.rotation_degrees.x = 90.0
			crest.position = Vector3(wx, 0.72, -1.02)
			crest.material_override = _toy_mat(Color("eef9ff"), 0.50, 0.18)
			_scenery_root.add_child(crest)
	elif kind == "home":
		var roof := MeshInstance3D.new()
		var r_prism := PrismMesh.new()
		r_prism.size = Vector3(2.2, 0.62, 0.06)
		roof.mesh = r_prism
		roof.position = Vector3(-1.55, 1.36, -1.42)
		roof.material_override = _toy_mat(Color("c96f53"), 0.56, 0.15)
		_scenery_root.add_child(roof)
	elif kind == "bakery":
		for stripe_i in range(5):
			var stripe := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.55, 0.24, 0.06)
			stripe.mesh = s_box
			stripe.position = Vector3(-1.8 + float(stripe_i) * 0.9, 1.18, -1.41)
			stripe.material_override = _toy_mat(Color("fff8ee") if stripe_i % 2 == 0 else Color("de7380"), 0.55, 0.16)
			_scenery_root.add_child(stripe)
	else:
		for tx: float in [-2.05, 1.65]:
			var crown := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.44
			tc.bottom_radius = 0.44
			tc.height = 0.05
			crown.mesh = tc
			crown.rotation_degrees.x = 90.0
			crown.position = Vector3(tx, 1.24, -1.40)
			crown.material_override = _toy_mat(Color("7fb86d"), 0.62, 0.12)
			_scenery_root.add_child(crown)

func _letter_texture(letter: String) -> Texture2D:
	var up := letter.to_upper()
	if _letter_tex_cache.has(up):
		return _letter_tex_cache[up] as Texture2D
	var v2_path := "res://assets/learning/storybook_v2/%s.png" % up
	if ResourceLoader.exists(v2_path):
		var tex := load(v2_path) as Texture2D
		if tex != null:
			_letter_tex_cache[up] = tex
			return tex
	var fallback := Content.icon(up, 2.0)
	_letter_tex_cache[up] = fallback
	return fallback

func _rebuild_3d_puppets() -> void:
	_puppets.clear()
	if not is_instance_valid(_puppet_root):
		return
	for child: Node in _puppet_root.get_children():
		_puppet_root.remove_child(child)
		child.queue_free()

	var slots: Array = entry.get("letter_slots", [])
	var count := slots.size()
	if count == 0:
		return

	var total_span := minf(5.8, float(maxi(1, count - 1)) * 0.92)
	var step_x := 0.0 if count <= 1 else total_span / float(count - 1)
	var start_x := -total_span * 0.5
	var card_scale := clampf(5.4 / float(maxi(4, count)), 0.54, 1.0)

	for i in range(count):
		var slot: Dictionary = slots[i]
		var pos_idx := i + 1
		var letter := str(slot.get("letter", "A")).to_upper()
		var anchor_zh := str(Content.codebook_item(letter).get("representative_label_zh", letter))
		var base_x := start_x + float(i) * step_x
		var base_z := 0.18 + (0.28 if i % 2 == 0 else -0.18)

		var hinge := Node3D.new()
		hinge.name = "PuppetHinge_%d" % pos_idx
		hinge.position = Vector3(base_x, 0.14, base_z)
		hinge.rotation_degrees.x = 0.0 if _reduced_motion else -82.0
		_puppet_root.add_child(hinge)

		var ped := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.84 * card_scale, 0.07 * card_scale, 0.26 * card_scale)
		ped.mesh = pbox
		ped.position = Vector3(0.0, 0.035 * card_scale, 0.0)
		ped.material_override = _toy_mat(Color("d6a76c"), 0.48, 0.25)
		hinge.add_child(ped)

		var card_back := MeshInstance3D.new()
		var cb_box := BoxMesh.new()
		cb_box.size = Vector3(0.98 * card_scale, 1.18 * card_scale, 0.045)
		card_back.mesh = cb_box
		card_back.position = Vector3(0.0, 0.64 * card_scale, 0.0)
		card_back.material_override = _toy_mat(Color("fffdf7"), 0.58, 0.18)
		hinge.add_child(card_back)

		var art_plane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.84 * card_scale, 0.84 * card_scale)
		art_plane.mesh = quad
		art_plane.position = Vector3(0.0, 0.75 * card_scale, 0.028)
		var amat := StandardMaterial3D.new()
		amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		amat.albedo_texture = _letter_texture(letter)
		amat.roughness = 0.55
		art_plane.material_override = amat
		hinge.add_child(art_plane)

		var badge := Label3D.new()
		badge.text = str(slot.get("raw", letter))
		badge.font = load("res://assets/fonts/IslandSans.otf")
		badge.font_size = int(46 * card_scale)
		badge.pixel_size = 0.0055
		badge.modulate = Color("4f3e2b")
		badge.outline_modulate = Color("fffaf0")
		badge.outline_size = 6
		badge.position = Vector3(0.0, 0.23 * card_scale, 0.036)
		hinge.add_child(badge)

		_puppets.append({
			"index": pos_idx,
			"letter": letter,
			"raw": str(slot.get("raw", letter.to_lower())),
			"anchor_zh": anchor_zh,
			"hinge": hinge,
			"art": art_plane,
			"badge": badge,
			"base_pos": hinge.position
		})

func _is_slot_revealed(pos_idx: int) -> bool:
	if view_mode == "story":
		if support_level == 5 or _show_sequence:
			return true
		if support_level == 3:
			return (pos_idx % 2 == 1) or _revealed_gaps.has(pos_idx)
		if support_level == 2:
			return pos_idx == 1
		return false
	else:
		if _revealed_gaps.has(pos_idx):
			return true
		return pos_idx <= _built_tokens.size()

func _process(delta: float) -> void:
	if _mic_recording:
		if _mic_capture != null:
			var avail := _mic_capture.get_frames_available()
			if avail > 0:
				_mic_frames.append_array(_mic_capture.get_buffer(avail))
		_mic_elapsed += delta
		if _mic_elapsed >= 4.5:
			_finish_mic_follow()

	if _content_unavailable or _puppets.is_empty():
		return
	_stage_time += delta
	_book_open_progress = minf(1.0, _book_open_progress + delta * 2.4)

	var active_positions := _beat_positions()
	if _playing_beat:
		_play_timer += delta
		if _play_timer > 3.8:
			var beats: Array = entry.get("story_beats", [])
			if current_beat < beats.size():
				current_beat += 1
				_play_timer = 0.0
				_refresh_ui()
			else:
				_playing_beat = false

	for p: Dictionary in _puppets:
		var hinge := p.hinge as Node3D
		if not is_instance_valid(hinge):
			continue
		var idx := int(p.index)
		var shown := _is_slot_revealed(idx)
		var in_beat := active_positions.has(idx)
		var beat_order := active_positions.find(idx)
		# Sequential left-to-right pop-up cascade during active beat playback!
		var stagger_fold := false
		if shown and _playing_beat and in_beat and beat_order > 0 and _play_timer < float(beat_order) * 0.28:
			stagger_fold = true
		var badge := p.badge as Label3D
		var art := p.art as MeshInstance3D
		if is_instance_valid(badge):
			badge.visible = shown and not stagger_fold
		if is_instance_valid(art):
			art.visible = shown and not stagger_fold

		var target_pitch := 0.0 if (shown and not stagger_fold) else -78.0
		if _reduced_motion:
			hinge.rotation_degrees.x = target_pitch
			hinge.position = p.base_pos as Vector3
		else:
			var d_style: String = dance_style()
			var extra_pitch := 0.0
			var base_p: Vector3 = p.base_pos
			var hop := 0.0
			var off_x := 0.0
			var off_z := 0.0
			var sway := 0.0
			var yaw := 0.0
			if shown and _playing_beat and in_beat:
				match d_style:
					"orbit_dance":
						off_x = sin(_stage_time * 3.8 + float(idx)) * 0.08
						off_z = cos(_stage_time * 3.8 + float(idx)) * 0.06
						hop = absf(sin(_stage_time * 4.2 + float(idx))) * 0.11
						yaw = sin(_stage_time * 3.2 + float(idx)) * 16.0
						sway = cos(_stage_time * 3.8 + float(idx)) * 5.0
					"peekaboo_pop":
						var peek_s := sin(_stage_time * 4.5 + float(idx) * 1.25)
						extra_pitch = -28.0 * maxf(0.0, peek_s)
						hop = maxf(0.0, -peek_s) * 0.22
						sway = sin(_stage_time * 6.0 + float(idx)) * 4.0
					"domino_cheer":
						var w_phase := fposmod(_stage_time * 3.5 - float(idx) * 0.45, TAU)
						var crest := maxf(0.0, sin(w_phase))
						hop = crest * crest * 0.24
						sway = cos(w_phase) * 6.5
					"starlight_float":
						hop = 0.10 + sin(_stage_time * 2.4 + float(idx) * 0.8) * 0.09
						sway = sin(_stage_time * 1.9 + float(idx) * 0.6) * 5.0
						yaw = cos(_stage_time * 1.6 + float(idx)) * 9.0
					_:
						hop = absf(sin(_stage_time * 5.4 + float(idx) * 0.8)) * 0.19
						sway = sin(_stage_time * 4.2 + float(idx)) * 8.0
				if is_instance_valid(_spotlight):
					_spotlight.look_at_from_position(_spotlight.position, hinge.global_position + Vector3(0, 0.5, 0), Vector3.UP)
			elif shown:
				hop = sin(_stage_time * 1.8 + float(idx) * 0.9) * 0.02
			hinge.rotation_degrees.x = lerpf(hinge.rotation_degrees.x, target_pitch + extra_pitch, minf(delta * 10.0, 1.0))
			hinge.position = base_p + Vector3(off_x, hop, off_z)
			hinge.rotation_degrees.z = lerpf(hinge.rotation_degrees.z, sway, minf(delta * 8.0, 1.0))
			hinge.rotation_degrees.y = lerpf(hinge.rotation_degrees.y, yaw, minf(delta * 8.0, 1.0))

func _refresh_ui() -> void:
	if not _ready_done or entry.is_empty():
		return
	var meaning := str(entry.get("meaning_zh", ""))
	var spelling := str(entry.get("spelling_display", ""))
	var beats: Array = entry.get("story_beats", [])
	current_beat = clampi(current_beat, 1, maxi(1, beats.size()))
	var beat: Dictionary = beats[current_beat - 1] if not beats.is_empty() else {}

	var d_style: String = dance_style()
	var d_badge: String = str(DANCE_LABELS.get(d_style, "欢跳挥手舞"))
	var ex_en: String = example_en()
	var ex_zh: String = example_zh()
	var p_room := palace_room_zh()
	var p_locus := palace_locus_zh()
	var s_title := story_title_zh()
	var root_loc := str(entry.get("root_location_label", "小岛故事书桌")).strip_edges()

	if is_instance_valid(_toggle_puzzle_btn):
		_toggle_puzzle_btn.text = "拼立体卡" if view_mode == "story" else "看立体剧"

	if is_instance_valid(_palace_btn):
		if not p_room.is_empty():
			if view_mode == "story":
				var t_part := ("   ·   奇象剧目：《%s》" % s_title) if not s_title.is_empty() else ""
				_palace_btn.text = "记忆宫殿桩点：%s · %s%s   （点此去房间看看 ›）" % [p_room, p_locus, t_part]
			else:
				_palace_btn.text = "空间定桩回想：%s · %s —— 想想这个角落里依次出现了哪几位字母精灵？" % [p_room, p_locus]
			_palace_btn.disabled = false
			_palace_btn.show()
		else:
			_palace_btn.text = "记忆桩点：%s" % root_loc
			_palace_btn.disabled = true
			_palace_btn.show()

	if view_mode == "story":
		var show_word := (support_level == 5 or _show_sequence)
		_title_label.text = ("%s  ·  %s" % [spelling, meaning]) if show_word else ("%s  ·  翻翻立体书猜一猜" % meaning)
		_subtitle_label.text = "真·记忆宫殿 26 字母精灵剧场  ·  %s" % d_badge
		var beat_narration := _resolve_beat_narration(current_beat - 1, beat)
		if support_level >= 4 or _show_sequence:
			_story_banner.text = "◈  " + beat_narration
		elif support_level == 3:
			_story_banner.text = "◈  " + _mask_unrevealed_pegs(beat_narration, beat.get("letter_positions", []))
		else:
			_story_banner.text = "◈  小折角收起了一半纸偶，结合上方记忆宫殿角落，想一想藏着哪位字母精灵？"
		if is_instance_valid(_usage_btn):
			if show_word and not ex_en.is_empty():
				_usage_btn.text = "生活例句：%s   ·   %s" % [ex_en, ex_zh]
				_usage_btn.show()
			else:
				_usage_btn.text = ""
				_usage_btn.hide()
		if is_instance_valid(_story_voice_btn):
			_story_voice_btn.show()
		_beat_nav_box.visible = beats.size() > 1
		_prev_beat_btn.disabled = current_beat <= 1
		_next_beat_btn.disabled = current_beat >= beats.size()
		_beat_counter_lbl.text = "第 %d / %d 幕" % [current_beat, maxi(1, beats.size())]
		_puzzle_box.hide()
	else:
		if is_instance_valid(_story_voice_btn):
			_story_voice_btn.hide()
		_title_label.text = "亲手拼立体书  ·  「%s」" % meaning
		_subtitle_label.text = "点按木牌把纸偶依次立起来 · 独立拼完会有惊喜哦"
		var locus_hint := ("回想「%s · %s」里的奇象连锁，" % [p_room, p_locus]) if not p_room.is_empty() else ""
		_story_banner.text = "目标词义：「%s」 —— %s按顺序摆好下方字母木块，让纸偶弹起来吧！" % [meaning, locus_hint]
		var solved := false
		var latest_r: Variant = later_response if later_response != null else first_response
		if latest_r is Dictionary and bool((latest_r as Dictionary).get("correct", false)):
			solved = true
		if is_instance_valid(_usage_btn):
			if solved and not ex_en.is_empty():
				_usage_btn.text = "生活例句：%s   ·   %s" % [ex_en, ex_zh]
				_usage_btn.show()
			else:
				_usage_btn.text = ""
				_usage_btn.hide()
		_beat_nav_box.hide()
		_puzzle_box.show()
		_rebuild_puzzle_tray()

	var fb := _feedback_text()
	_feedback_label.text = fb
	_feedback_label.visible = not fb.is_empty()

func _resolve_beat_narration(beat_idx: int, beat: Dictionary) -> String:
	var p_beats: Variant = _current_palace.get("beats_zh", [])
	if p_beats is Array and beat_idx >= 0 and beat_idx < (p_beats as Array).size():
		var authored := str((p_beats as Array)[beat_idx]).strip_edges()
		if not authored.is_empty():
			return authored
	var beat_narration := str(beat.get("narration_zh", "")).strip_edges()
	if not beat_narration.is_empty():
		return beat_narration
	var steps_arr: Array = entry.get("steps", [])
	var pieces: PackedStringArray = []
	for p_val: Variant in beat.get("letter_positions", []):
		var idx := int(p_val) - 1
		if idx >= 0 and idx < steps_arr.size():
			var anchor_name := str(steps_arr[idx].get("anchor_zh", "")).strip_edges()
			var ltr := str(steps_arr[idx].get("letter", "")).to_upper()
			var act := str(steps_arr[idx].get("action", steps_arr[idx].get("text", ""))).strip_edges()
			if not act.is_empty():
				pieces.append(("【%s%s】%s" % [anchor_name, ltr, act]) if not anchor_name.is_empty() else act)
	return "，接着".join(pieces) if not pieces.is_empty() else "纸偶精灵正在书页上排排坐！"

func _mask_unrevealed_pegs(narration: String, positions: Array) -> String:
	var rx := RegEx.new()
	if rx.compile("【[^【】]+】") != OK:
		return "小折角收起了一半纸偶，想一想藏着哪位字母精灵？"
	var matches := rx.search_all(narration)
	if matches.is_empty():
		return "小折角收起了一半纸偶，想一想藏着哪位字母精灵？"
	var out := ""
	var cursor := 0
	var revealed_anchors: Dictionary = {}
	var hidden_anchors: Array[String] = []
	var steps_arr: Array = entry.get("steps", [])
	for i in range(matches.size()):
		var m := matches[i]
		out += narration.substr(cursor, m.get_start() - cursor)
		var pos_idx := int(positions[i]) if i < positions.size() else (i + 1)
		var a_zh := str(steps_arr[pos_idx - 1].get("anchor_zh", "")).strip_edges() if (pos_idx >= 1 and pos_idx <= steps_arr.size()) else ""
		if _is_slot_revealed(pos_idx):
			out += m.get_string()
			if not a_zh.is_empty():
				revealed_anchors[a_zh] = true
		else:
			out += "【？神秘精灵】"
			if not a_zh.is_empty() and not hidden_anchors.has(a_zh):
				hidden_anchors.append(a_zh)
		cursor = m.get_end()
	out += narration.substr(cursor)
	for h_zh: String in hidden_anchors:
		if not revealed_anchors.has(h_zh):
			out = out.replace(h_zh, "神秘精灵")
	return out

func _on_visit_palace() -> void:
	var target := palace_room_id()
	if not target.is_empty():
		visit_palace_requested.emit(target)

func _feedback_text() -> String:
	if view_mode == "practice":
		var latest: Variant = later_response if later_response != null else first_response
		if latest is Dictionary:
			if bool(latest.get("correct", false)):
				return "★ 哇！全部纸偶都弹起来啦！「%s」拼得真准！" % str(entry.get("spelling_display", ""))
			return "◈ 差一点点！再核对一下字母顺序或大小写，也可以点上方「小提示」偷看一眼～"
	elif view_mode == "story" and (support_level == 5 or _show_sequence):
		var climax := meaning_climax_zh()
		var beats: Array = entry.get("story_beats", [])
		if not climax.is_empty() and current_beat >= maxi(1, beats.size()):
			return "★ 词义高潮定格：" + climax
	return ""

func _rebuild_puzzle_tray() -> void:
	for c: Node in _slots_row.get_children():
		_slots_row.remove_child(c)
		c.queue_free()
	for c: Node in _tiles_row.get_children():
		_tiles_row.remove_child(c)
		c.queue_free()

	var tokens: Array = entry.get("reconstruction_tokens", [])
	for i in range(tokens.size()):
		var filled := i < _built_tokens.size()
		var slot_lbl := Button.new()
		slot_lbl.text = _built_tokens[i] if filled else "·"
		slot_lbl.custom_minimum_size = Vector2(48, 48)
		slot_lbl.add_theme_font_override("font", Style.heading_font())
		slot_lbl.add_theme_font_size_override("font_size", 21)
		slot_lbl.disabled = not filled
		if filled:
			slot_lbl.add_theme_stylebox_override("normal", Style.keycap(Color("fff8e3"), Style.GOLD, 4, 12, 8, 6))
			slot_lbl.add_theme_stylebox_override("hover", Style.keycap(Color("fcebc4"), Style.CORAL, 4, 12, 8, 6))
			var remove_idx := i
			slot_lbl.pressed.connect(func():
				_built_tokens.resize(remove_idx)
				_sync_tokens_to_input()
				_rebuild_puzzle_tray()
			)
		else:
			var empty_sb := Style.keycap(Color("f1ece0"), Color("d7ccb6"), 2, 12, 8, 6)
			empty_sb.shadow_size = 0
			slot_lbl.add_theme_stylebox_override("disabled", empty_sb)
		_slots_row.add_child(slot_lbl)

	var bank: Array[String] = []
	for tok: Dictionary in tokens:
		bank.append(str(tok.get("raw", "")))
	if bank.size() <= 6:
		for decoy: String in ["a", "e", "o", "s", "t"]:
			if not bank.has(decoy) and bank.size() < 8:
				bank.append(decoy)
	var seed_h := absi(str(entry.get("entry_id", "word")).hash())
	for i in range(bank.size()):
		var swap_i := (seed_h + i * 7) % bank.size()
		var tmp := bank[i]
		bank[i] = bank[swap_i]
		bank[swap_i] = tmp

	for piece: String in bank:
		var tile := Button.new()
		tile.text = piece
		tile.custom_minimum_size = Vector2(52, 50)
		tile.add_theme_font_override("font", Style.heading_font())
		tile.add_theme_font_size_override("font_size", 22)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.add_theme_stylebox_override("normal", Style.keycap(Color("fdf5e2"), Color("d1b17e"), 4, 14, 10, 8))
		tile.add_theme_stylebox_override("hover", Style.keycap(Color("fcedc8"), Style.GOLD, 4, 14, 10, 8))
		tile.add_theme_stylebox_override("pressed", Style.keycap(Color("efe2c4"), Color("bfa06d"), 2, 14, 10, 9))
		tile.pressed.connect(func():
			if _built_tokens.size() < tokens.size():
				_built_tokens.append(piece)
				_sync_tokens_to_input()
				_rebuild_puzzle_tray()
				if _built_tokens.size() == tokens.size():
					submit_response(_type_input.text)
		)
		_tiles_row.add_child(tile)

func _sync_tokens_to_input() -> void:
	var joined := ""
	for s: String in _built_tokens:
		joined += s
	_type_input.text = joined
	draft_response = joined

func _reset_tokens() -> void:
	_built_tokens.clear()
	_sync_tokens_to_input()
	_rebuild_puzzle_tray()

func _on_speak_example() -> void:
	var sent := example_en().strip_edges()
	if sent.is_empty():
		return
	if Engine.get_main_loop() is SceneTree:
		var bus := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")
		if bus != null:
			bus.tts_speak_requested.emit(sent, "en", "storyteller")
	_playing_beat = not _reduced_motion
	_play_timer = 0.0

func _on_speak_word() -> void:
	var word := str(entry.get("spelling_display", ""))
	var audio_info: Dictionary = entry.get("audio", {})
	var path := str(audio_info.get("path", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			_audio.stream = stream
			_audio.play()
			var event := _base_cue("whole_word_audio", "child")
			event["support_level"] = maxi(1, support_level)
			event["support_kind"] = "whole_word_audio"
			event["asset_or_content_ref"] = path
			event["revealed_letter_positions"] = []
			event["answer_revealing_dimensions"] = ["spoken_expression"]
			event["audio_role"] = "additional_cue"
			_store_cue(event)
			_emit_progress()
			return
	if Engine.get_main_loop() is SceneTree:
		var bus := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")
		if bus != null:
			bus.tts_speak_requested.emit(word, "en", "storyteller")

func _clean_story_for_zh_tts(raw_zh: String) -> String:
	var s := raw_zh.replace("◈", "").strip_edges()
	var rx := RegEx.new()
	if rx.compile("【([^【】]*?)[A-Z]】") == OK:
		s = rx.sub(s, "$1", true)
	s = s.replace("【？神秘精灵】", "神秘小精灵").replace("【", "").replace("】", "")
	return s.strip_edges()

func _on_speak_story_zh() -> void:
	var spoken_zh := _clean_story_for_zh_tts(_story_banner.text)
	if spoken_zh.is_empty():
		return
	if view_mode == "story" and (support_level == 5 or _show_sequence):
		var beats: Array = entry.get("story_beats", [])
		if current_beat >= beats.size() and not meaning_climax_zh().is_empty():
			spoken_zh += " " + meaning_climax_zh()
	if Engine.get_main_loop() is SceneTree:
		var bus := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")
		if bus != null:
			bus.tts_speak_requested.emit(spoken_zh, "zh", "storyteller")
	_playing_beat = not _reduced_motion
	_play_timer = 0.0

func _on_follow_along_word() -> void:
	var word := str(entry.get("spelling_display", "")).strip_edges()
	if word.is_empty():
		return
	if _mic_recording:
		_finish_mic_follow()
		return
	# In headless CI or when audio input is unavailable, provide immediate warm encouragement
	if DisplayServer.get_name() == "headless" or not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)) or float(AudioServer.get_mix_rate()) < 16000.0:
		_on_speak_word()
		_record_follow_cheer(word, "★ 跟着读一读：「%s」…… 声音真好听！已收下一颗自信开口星！" % word)
		return

	if is_instance_valid(_audio):
		_audio.stop()
	_mic_sample_rate = float(AudioServer.get_mix_rate())
	_mic_bus = "PopupTheaterMic_%d" % get_instance_id()
	AudioServer.add_bus()
	var bus_idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_idx, _mic_bus)
	AudioServer.set_bus_mute(bus_idx, true)
	_mic_capture = AudioEffectCapture.new()
	_mic_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus_idx, _mic_capture)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = _mic_bus
	add_child(_mic_player)
	_mic_frames.clear()
	_mic_elapsed = 0.0
	_mic_recording = true
	if is_instance_valid(_follow_btn):
		_follow_btn.text = "结束跟读"
	_mic_player.play()
	_story_banner.text = "★ 正在听你读「%s」…… 读完再点一下「结束跟读」（最多 4.5 秒）" % word

func _stop_mic_bus() -> void:
	_mic_recording = false
	if is_instance_valid(_mic_player):
		_mic_player.stop()
		_mic_player.queue_free()
	_mic_player = null
	_mic_capture = null
	if not _mic_bus.is_empty():
		var idx := AudioServer.get_bus_index(_mic_bus)
		if idx >= 0:
			AudioServer.remove_bus(idx)
	_mic_bus = ""

func _cancel_mic_follow() -> void:
	_stop_mic_bus()
	_mic_frames.clear()
	if is_instance_valid(_asr_request):
		_asr_request.cancel_request()
		_asr_request.queue_free()
	_asr_request = null
	if is_instance_valid(_follow_btn):
		_follow_btn.text = "跟读"
		_follow_btn.disabled = false

func _finish_mic_follow() -> void:
	var word := str(entry.get("spelling_display", "")).strip_edges()
	if _mic_capture != null:
		var avail := _mic_capture.get_frames_available()
		if avail > 0:
			_mic_frames.append_array(_mic_capture.get_buffer(avail))
	_stop_mic_bus()
	if is_instance_valid(_follow_btn):
		_follow_btn.text = "跟读"
	if _mic_frames.size() < int(_mic_sample_rate * 0.22):
		_mic_frames.clear()
		_on_speak_word()
		_story_banner.text = "★ 没听到麦克风声音哦～先听示范读一遍「%s」，靠近麦克风再试一次吧！" % word
		return
	var step := _mic_sample_rate / 16000.0
	var count := int(float(_mic_frames.size()) / step)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var energy := 0.0
	for i in range(count):
		var fr: Vector2 = _mic_frames[mini(_mic_frames.size() - 1, int(float(i) * step))]
		var s := clampf((fr.x + fr.y) * 0.5, -1.0, 1.0)
		energy += s * s
		pcm.encode_s16(i * 2, clampi(int(round(s * 32767.0)), -32768, 32767))
	_mic_frames.clear()
	var rms := sqrt(energy / float(maxi(1, count)))
	if rms < 0.0012:
		_on_speak_word()
		_story_banner.text = "★ 刚才声音有点轻～先听一遍「%s」，大胆读出来试试！" % word
		return
	var wav := "RIFF".to_ascii_buffer()
	wav.resize(44)
	wav.encode_u32(4, 36 + pcm.size())
	for chunk: Array in [[8, "WAVE"], [12, "fmt "], [36, "data"]]:
		var b: PackedByteArray = str(chunk[1]).to_ascii_buffer()
		for j in range(4):
			wav[int(chunk[0]) + j] = b[j]
	wav.encode_u32(16, 16)
	wav.encode_u16(20, 1)
	wav.encode_u16(22, 1)
	wav.encode_u32(24, 16000)
	wav.encode_u32(28, 32000)
	wav.encode_u16(32, 2)
	wav.encode_u16(34, 16)
	wav.encode_u32(40, pcm.size())
	wav.append_array(pcm)

	_asr_request = HTTPRequest.new()
	_asr_request.timeout = 8.0
	add_child(_asr_request)
	if is_instance_valid(_follow_btn):
		_follow_btn.disabled = true
	_story_banner.text = "★ 正在用离线语音助手听你读「%s」……" % word
	_asr_request.request_completed.connect(func(res: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		if is_instance_valid(_asr_request):
			_asr_request.queue_free()
		_asr_request = null
		if is_instance_valid(_follow_btn):
			_follow_btn.disabled = false
		var msg := "★ 勇敢开口读「%s」，声音真棒！收下一颗自信开口星！" % word
		if res == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and bool((parsed as Dictionary).get("ok", false)):
				var cheer := str((parsed as Dictionary).get("message_zh", "")).strip_edges()
				var trans := str((parsed as Dictionary).get("transcript", "")).strip_edges()
				if not cheer.is_empty():
					msg = "★ " + cheer + (("（识别到：%s）" % trans) if not trans.is_empty() else "")
		_record_follow_cheer(word, msg)
	)
	var payload := {"target_text": word, "mode": "voice", "rms_energy": rms, "duration_ms": int(float(count) / 16.0), "wav_base64": Marshalls.raw_to_base64(wav)}
	var err := _asr_request.request("http://127.0.0.1:4195/api/v4/speech/encourage", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		if is_instance_valid(_asr_request):
			_asr_request.queue_free()
		_asr_request = null
		if is_instance_valid(_follow_btn):
			_follow_btn.disabled = false
		_record_follow_cheer(word, "★ 勇敢开口读「%s」！收下一颗自信开口星！" % word)

func _record_follow_cheer(word: String, banner_msg: String) -> void:
	_story_banner.text = banner_msg
	if Engine.get_main_loop() is SceneTree:
		var root_node := (Engine.get_main_loop() as SceneTree).root
		var st := root_node.get_node_or_null("State")
		if st != null and st.has_method("record_voice_cheer"):
			st.record_voice_cheer()
			st.record_stealth_evidence({
				"word": word,
				"support_level": 1,
				"correct": true,
				"context": "popup_follow_along"
			})

func _exit_tree() -> void:
	_cancel_mic_follow()
	if is_instance_valid(_audio):
		_audio.stop()

func _on_play_theater() -> void:
	if view_mode != "story":
		view_mode = "story"
		support_level = 5
		_show_sequence = true
		_record_visible_cue("full_sequence", "child")
		_emit_progress()
	current_beat = 1
	_playing_beat = true
	_play_timer = 0.0
	_refresh_ui()
	_on_speak_word()

func _on_gentle_hint() -> void:
	if view_mode == "story":
		support_level = 3 if support_level == 5 else 5
		_show_sequence = (support_level == 5)
		_record_visible_cue("support_selected", "child")
	else:
		support_level = 3
		for i in range(1, entry.get("letter_slots", []).size() + 1, 2):
			if not _revealed_gaps.has(i):
				_revealed_gaps.append(i)
		_record_visible_cue("gap_revealed", "child")
	_emit_progress()
	_refresh_ui()

func _on_toggle_puzzle() -> void:
	if view_mode == "story":
		start_practice()
	else:
		view_mode = "story"
		support_level = 5
		_show_sequence = true
		_record_visible_cue("support_selected", "child")
		_emit_progress()
		_refresh_ui()

func navigate_beat(direction: int) -> void:
	var beats: Array = entry.get("story_beats", [])
	current_beat = clampi(current_beat + direction, 1, maxi(1, beats.size()))
	_playing_beat = true
	_play_timer = 0.0
	_refresh_ui()
	_record_visible_cue("story_page", "child")
	_emit_progress()

func start_practice() -> void:
	view_mode = "practice"
	support_level = 0
	_show_sequence = false
	_revealed_gaps.clear()
	_built_tokens.clear()
	if is_instance_valid(_type_input):
		_type_input.clear()
	_record_visible_cue("practice_started", "child")
	_emit_progress()
	_refresh_ui()

func enter_gap_recall_mode() -> void:
	if not _ready_done or _content_unavailable:
		call_deferred("enter_gap_recall_mode")
		return
	view_mode = "practice"
	support_level = 3
	_show_sequence = false
	_revealed_gaps.clear()
	for i in range(1, entry.get("letter_slots", []).size() + 1, 2):
		_revealed_gaps.append(i)
	_built_tokens.clear()
	if is_instance_valid(_type_input):
		_type_input.clear()
	_record_visible_cue("gap_revealed", "child")
	_emit_progress()
	_refresh_ui()

func submit_response(value: String) -> void:
	if _content_unavailable or view_mode != "practice":
		return
	draft_response = value
	var target_word := str(entry.get("spelling_display", ""))
	var correct := (value == target_word)
	var response := {
		"response_id": _event_id("response"),
		"invocation_id": invocation_id,
		"attempt_id": attempt_id,
		"response_text": value,
		"correct": correct,
		"target_dimension": "orthography",
		"task_mode": "meaning_to_spelling",
		"practice_is_extra": not bool(entry.get("task_permissions", {}).get("formal_spelling_eligible", false)),
		"observed_at": Time.get_unix_time_from_system(),
		"support_level": support_level,
		"prior_cue_event_count": cue_events.size(),
		"answer_visible": support_level == 5 or _show_sequence,
		"independent_claimed": false
	}
	if first_response == null:
		first_response = response.duplicate(true)
	else:
		later_response = response.duplicate(true)

	if correct:
		for i in range(1, entry.get("letter_slots", []).size() + 1):
			if not _revealed_gaps.has(i):
				_revealed_gaps.append(i)
		_playing_beat = not _reduced_motion
		_play_timer = 0.0

	response_submitted.emit(response)
	if Engine.get_main_loop() is SceneTree:
		var bus := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")
		if bus != null:
			bus.stealth_evidence_observed.emit({
				"word": target_word,
				"support_level": max_help_level if _revealed_gaps.size() > 0 else support_level,
				"correct": correct,
				"context": "popup_book_theater"
			})
	_emit_progress()
	_refresh_ui()

func request_close(result: String = "paused") -> void:
	set_paused(true)
	_emit_progress()
	close_requested.emit({
		"invocation_id": invocation_id,
		"attempt_id": attempt_id,
		"result": "content_unavailable" if _content_unavailable else result,
		"progress": get_resume()
	})

func _record_visible_cue(kind: String, requested_by: String) -> void:
	var event := _base_cue(kind, requested_by)
	var positions: Array = []
	var dimensions: Array = [] if support_level == 0 else ["meaning"]
	if support_level == 5 or _show_sequence:
		for p: int in range(1, entry.get("letter_slots", []).size() + 1):
			positions.append(p)
	elif support_level == 2:
		positions = [1]
	elif support_level == 3:
		for p: Variant in _beat_positions():
			if (int(p) % 2 != 0 and _beat_positions().size() > 1) or _revealed_gaps.has(int(p)):
				positions.append(int(p))
		for g: Variant in _revealed_gaps:
			if not positions.has(int(g)):
				positions.append(int(g))
	if not positions.is_empty():
		dimensions.append("orthography")
	event["revealed_letter_positions"] = positions
	event["answer_revealing_dimensions"] = dimensions
	event["displayed_stimulus_dimensions"] = ["meaning"]
	if support_level == 5:
		var beats: Array = entry.get("story_beats", [])
		if not beats.is_empty():
			var beat: Dictionary = beats[current_beat - 1]
			if not seen_beats.has(str(beat.beat_id)):
				seen_beats.append(str(beat.beat_id))
	_store_cue(event)

func _base_cue(kind: String, requested_by: String) -> Dictionary:
	return {
		"event_id": _event_id("cue"),
		"invocation_id": invocation_id,
		"attempt_id": attempt_id,
		"support_level": support_level,
		"support_kind": SUPPORT_KINDS[clampi(support_level, 0, 5)],
		"display_event": kind,
		"asset_or_content_ref": "%s/frame-%d" % [str(entry.get("story_id", "")), current_beat],
		"requested_by": requested_by,
		"shown_at": Time.get_unix_time_from_system()
	}

func _store_cue(event: Dictionary) -> void:
	max_help_level = maxi(max_help_level, int(event.support_level))
	cue_events.append(event.duplicate(true))
	help_shown.emit(event)

func _emit_progress() -> void:
	progress_changed.emit(get_resume())

func _event_id(kind: String) -> String:
	return "%s/%s/%s/%d-%d" % [invocation_id, attempt_id, kind, Time.get_ticks_usec(), cue_events.size()]

func _beat_positions() -> Array:
	var beats: Array = entry.get("story_beats", [])
	return beats[current_beat - 1].get("letter_positions", []) if not beats.is_empty() else []
