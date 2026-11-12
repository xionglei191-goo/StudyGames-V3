extends MarginContainer
## V4 3D Interactive Pop-up Book Mnemonic Stage (`PopupBookTheater`).
## Renders a real Forward+ 3D miniature wooden desk & folding cardstock Pop-up Book
## where 26-letter illustrated standee puppets spring upright from the page crease,
## act out mnemonic beats, and fold down for hands-on wooden letter-tile assembly!
## Fully compatible with `JourneyController` / `MemorySink` durable cue & response schema.

signal help_shown(event: Dictionary)
signal response_submitted(response: Dictionary)
signal progress_changed(snapshot: Dictionary)
signal close_requested(result: Dictionary)

const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const CHOREO_PATH := "res://data/learning/popup_choreography_v4.json"

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
var view_mode := "story" # "story" or "practice"
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
var _story_banner: Label
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
var _audio: AudioStreamPlayer
var _built_tokens: Array[String] = []
var _current_choreo: Dictionary = {}

static var _letter_tex_cache: Dictionary = {}
static var _choreo_cache: Dictionary = {}

static func _load_choreo_map() -> Dictionary:
	if _choreo_cache.is_empty() and FileAccess.file_exists(CHOREO_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHOREO_PATH))
		if parsed is Dictionary:
			var entries_val: Variant = (parsed as Dictionary).get("entries", {})
			if entries_val is Dictionary:
				_choreo_cache = entries_val as Dictionary
	return _choreo_cache

func dance_style() -> String:
	return str(_current_choreo.get("dance_style", "bounce_wave"))

func example_en() -> String:
	return str(_current_choreo.get("example_en", ""))

func example_zh() -> String:
	return str(_current_choreo.get("example_zh", ""))

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
	_built_tokens.clear()
	_playing_beat = false
	_book_open_progress = 0.0
	if _ready_done:
		_present_initial.call_deferred(_setup_revision)

func _present_initial(rev: int) -> void:
	if rev != _setup_revision or _content_unavailable:
		return
	_rebuild_3d_puppets()
	_refresh_ui()
	if cue_events.is_empty():
		_record_visible_cue("initial_open", "system")
		_emit_progress()
	# Auto-play gentle pop-up demonstration on open!
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
		if is_instance_valid(_audio):
			_audio.stop()

func _build_layout() -> void:
	var root_col := VBoxContainer.new()
	root_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_theme_constant_override("separation", 10)
	add_child(root_col)

	# 1. Warm Top Ribbon
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_col.add_child(top_bar)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top_bar.add_child(title_box)

	_title_label = Style.text("3D 立体翻翻书剧场", 23, Style.INK)
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_title_label)
	_subtitle_label = Style.text("", 14, Style.MUTED)
	_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_subtitle_label)

	top_bar.add_child(_pill_btn("🔊 听读音", _on_speak_word, false))
	top_bar.add_child(_pill_btn("🎤 跟读", _on_follow_along_word, false))
	top_bar.add_child(_pill_btn("✨ 演立体剧", _on_play_theater, false))
	top_bar.add_child(_pill_btn("💡 小提示", _on_gentle_hint, false))
	top_bar.add_child(_pill_btn("🧩 拼立体卡", _on_toggle_puzzle, true))
	top_bar.add_child(_pill_btn("✕ 收好", func(): request_close("completed" if (first_response != null and bool(first_response.get("correct", false))) or (later_response != null and bool(later_response.get("correct", false))) else "paused"), false))

	# 2. 3D Pop-up Book Viewport Stage
	var stage_frame := PanelContainer.new()
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.custom_minimum_size = Vector2(0, 340)
	var frame_sb := Style.box(Color("e9dfc9"), 18, 6)
	frame_sb.border_color = Color("cbb997")
	frame_sb.set_border_width_all(2)
	stage_frame.add_theme_stylebox_override("panel", frame_sb)
	root_col.add_child(stage_frame)

	_vp_container = SubViewportContainer.new()
	_vp_container.stretch = true
	_vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(_vp_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 340)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp_container.add_child(_viewport)

	_build_3d_book_environment()

	# 3. Story Caption & Beat Flipper Bar
	var caption_card := PanelContainer.new()
	var cap_sb := Style.box(Color("f7f3e6"), 14, 12)
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

	_beat_nav_box = HBoxContainer.new()
	_beat_nav_box.add_theme_constant_override("separation", 8)
	beat_row.add_child(_beat_nav_box)

	_prev_beat_btn = _pill_btn("◀ 上一折", func(): navigate_beat(-1), false)
	_beat_counter_lbl = Style.text("1 / 1", 16, Style.MUTED)
	_next_beat_btn = _pill_btn("下一折 ▶", func(): navigate_beat(1), false)
	_beat_nav_box.add_child(_prev_beat_btn)
	_beat_nav_box.add_child(_beat_counter_lbl)
	_beat_nav_box.add_child(_next_beat_btn)

	_usage_btn = _pill_btn("💬 生活例句", _on_speak_example, false)
	_usage_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_usage_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_usage_btn.custom_minimum_size = Vector2(0, 38)
	_usage_btn.add_theme_font_size_override("font_size", 15)
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
	_type_input.placeholder_text = "点上方木块拼装，也可以直接在这里输入英文……"
	_type_input.custom_minimum_size = Vector2(360, 40)
	_type_input.text_submitted.connect(submit_response)
	manual_row.add_child(_type_input)

	manual_row.add_child(_pill_btn("✨ 拼好啦！立起纸偶", func(): submit_response(_type_input.text), true))
	manual_row.add_child(_pill_btn("↺ 清空重摆", _reset_tokens, false))

	_feedback_label = Style.text("", 17, Color("4d7c43"))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_col.add_child(_feedback_label)

func _pill_btn(caption: String, cb: Callable, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(0, 42)
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
	sky_mat.sky_top_color = Color("ffdca8")
	sky_mat.sky_horizon_color = Color("fff3dc")
	sky_mat.ground_horizon_color = Color("ebd9be")
	sky_mat.ground_bottom_color = Color("b8926a")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color("fff4df")
	env.ambient_light_energy = 0.88
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.06
	if DisplayServer.get_name() != "headless":
		env.ssao_enabled = true
		env.ssao_radius = 0.45
		env.ssao_intensity = 1.35
		env.glow_enabled = true
		env.glow_intensity = 0.18
	env_node.environment = env
	_viewport.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -26, 0)
	key.light_color = Color("fff3db")
	key.light_energy = 0.85
	key.shadow_enabled = true
	key.shadow_opacity = 0.42
	key.shadow_blur = 1.5
	_viewport.add_child(key)

	_spotlight = SpotLight3D.new()
	_spotlight.position = Vector3(0.0, 4.4, 1.4)
	_spotlight.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	_spotlight.light_color = Color("ffe6ad")
	_spotlight.light_energy = 1.15
	_spotlight.spot_range = 9.0
	_spotlight.spot_angle = 30.0
	_viewport.add_child(_spotlight)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 34.0
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 3.65, 5.85), Vector3(0.0, 0.58, -0.15), Vector3.UP)

	# Warm Walnut Study Desk
	var desk := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(14.0, 0.40, 8.0)
	desk.mesh = dbox
	desk.position = Vector3(0.0, -0.32, 0.0)
	desk.material_override = _toy_mat(Color("8f5f3d"), 0.48, 0.30)
	_viewport.add_child(desk)

	# Soft Sage Desk Blotter Mat
	var mat_mesh := MeshInstance3D.new()
	var mbox := BoxMesh.new()
	mbox.size = Vector3(8.6, 0.04, 4.7)
	mat_mesh.mesh = mbox
	mat_mesh.position = Vector3(0.0, -0.10, 0.0)
	mat_mesh.material_override = _toy_mat(Color("cadbc0"), 0.80, 0.05)
	_viewport.add_child(mat_mesh)

	# Open 3D Hardcover Pop-up Book
	_book_root = Node3D.new()
	_book_root.name = "PopupHardcoverBook"
	_viewport.add_child(_book_root)

	var cover_mat := _toy_mat(Color("c96a5b"), 0.54, 0.22)
	var page_mat := _toy_mat(Color("fbf6e8"), 0.72, 0.08)
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

	# Center Spine & Gold Bookmark Ribbon
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

	# Back Pop-up Paper Scenery Arch (Paper Hills, Paper Clouds & Sun)
	var hill_back := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(6.2, 1.05, 0.05)
	hill_back.mesh = hbox
	hill_back.position = Vector3(0.0, 0.62, -1.45)
	hill_back.material_override = _toy_mat(Color("9ed18b"), 0.68, 0.10)
	_book_root.add_child(hill_back)

	var hill_mid := MeshInstance3D.new()
	var hmbox := BoxMesh.new()
	hmbox.size = Vector3(5.4, 0.62, 0.05)
	hill_mid.mesh = hmbox
	hill_mid.position = Vector3(0.0, 0.42, -1.08)
	hill_mid.material_override = _toy_mat(Color("b9df9b"), 0.68, 0.10)
	_book_root.add_child(hill_mid)

	var sun_disc := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.42
	sc.bottom_radius = 0.42
	sc.height = 0.04
	sun_disc.mesh = sc
	sun_disc.rotation_degrees.x = 90.0
	sun_disc.position = Vector3(2.15, 1.35, -1.52)
	sun_disc.material_override = _toy_mat(Color("ffd96b"), 0.38, 0.25)
	_book_root.add_child(sun_disc)

	_puppet_root = Node3D.new()
	_puppet_root.name = "StandeePuppets"
	_book_root.add_child(_puppet_root)

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

		# Wooden Slider Pedestal
		var ped := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.84 * card_scale, 0.08, 0.32 * card_scale)
		ped.mesh = pbox
		ped.position = Vector3(0.0, 0.04, 0.0)
		ped.material_override = _toy_mat(Color("d6a76c"), 0.48, 0.25)
		hinge.add_child(ped)

		# Die-cut Cream Cardstock Backing Standee
		var card_back := MeshInstance3D.new()
		var cb_box := BoxMesh.new()
		cb_box.size = Vector3(0.98 * card_scale, 1.18 * card_scale, 0.045)
		card_back.mesh = cb_box
		card_back.position = Vector3(0.0, 0.64 * card_scale, 0.0)
		card_back.material_override = _toy_mat(Color("fffdf7"), 0.58, 0.18)
		hinge.add_child(card_back)

		# High-res Storybook Illustration Quad on Front of Standee
		var art_plane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.88 * card_scale, 0.88 * card_scale)
		art_plane.mesh = quad
		art_plane.position = Vector3(0.0, 0.72 * card_scale, 0.028)
		var amat := StandardMaterial3D.new()
		amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		amat.albedo_texture = _letter_texture(letter)
		amat.roughness = 0.55
		art_plane.material_override = amat
		hinge.add_child(art_plane)

		# Crisp 3D Letter Badge at Foot of Standee
		var badge := Label3D.new()
		badge.text = str(slot.get("raw", letter))
		badge.font = load("res://assets/fonts/IslandSans.otf")
		badge.font_size = int(46 * card_scale)
		badge.pixel_size = 0.0055
		badge.modulate = Color("4f3e2b")
		badge.outline_modulate = Color("fffaf0")
		badge.outline_size = 6
		badge.position = Vector3(0.0, 0.20 * card_scale, 0.035)
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
		# In hands-on puzzle mode, puppets pop upright as the child places each letter!
		if _revealed_gaps.has(pos_idx):
			return true
		return pos_idx <= _built_tokens.size()

func _process(delta: float) -> void:
	if _content_unavailable or _puppets.is_empty():
		return
	_stage_time += delta
	_book_open_progress = minf(1.0, _book_open_progress + delta * 2.4)

	var active_positions := _beat_positions()
	if _playing_beat:
		_play_timer += delta
		if _play_timer > 3.6:
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
		var badge := p.badge as Label3D
		var art := p.art as MeshInstance3D
		if is_instance_valid(badge):
			badge.visible = shown
		if is_instance_valid(art):
			art.visible = shown

		# Pop-up fold angle: 0° upright when shown, -78° folded flat when hidden!
		var target_pitch := 0.0 if shown else -78.0
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
					_: # "bounce_wave"
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

	if view_mode == "story":
		var show_word := (support_level == 5 or _show_sequence)
		_title_label.text = ("📖 %s  ·  %s" % [spelling, meaning]) if show_word else ("📖 %s  ·  翻翻立体书猜一猜" % meaning)
		_subtitle_label.text = "26 字母纸偶立体剧场（🎭 %s） · 看着纸偶弹起来演故事，顺便记住字母顺序" % d_badge
		var beat_narration := str(beat.get("narration_zh", "")).strip_edges()
		if beat_narration.is_empty():
			var steps_arr: Array = entry.get("steps", [])
			var pieces: PackedStringArray = []
			for p_val: Variant in beat.get("letter_positions", []):
				var idx := int(p_val) - 1
				if idx >= 0 and idx < steps_arr.size():
					var act := str(steps_arr[idx].get("action", steps_arr[idx].get("text", ""))).strip_edges()
					if not act.is_empty():
						pieces.append(act)
			beat_narration = "  →  ".join(pieces) if not pieces.is_empty() else "纸偶伙伴正在书页上排排坐！"
		_story_banner.text = ("✨ " + beat_narration) if support_level >= 4 else "💡 小折角收起了一半纸偶，想一想藏着哪位字母伙伴？"
		if is_instance_valid(_usage_btn):
			if show_word and not ex_en.is_empty():
				_usage_btn.text = "🔊 生活例句：%s   |   %s" % [ex_en, ex_zh]
				_usage_btn.show()
			else:
				_usage_btn.hide()
		_beat_nav_box.visible = beats.size() > 1
		_prev_beat_btn.disabled = current_beat <= 1
		_next_beat_btn.disabled = current_beat >= beats.size()
		_beat_counter_lbl.text = "第 %d / %d 折" % [current_beat, maxi(1, beats.size())]
		_puzzle_box.hide()
	else:
		_title_label.text = "🧩 亲手拼立体书  ·  「%s」" % meaning
		_subtitle_label.text = "点击木块把纸偶一个个立起来！完全靠自己立起全部纸偶会有小惊喜 ✨"
		_story_banner.text = "目标词义：「%s」 —— 试试按顺序摆好木块，让立体纸偶弹起来吧！" % meaning
		var solved := false
		var latest_r: Variant = later_response if later_response != null else first_response
		if latest_r is Dictionary and bool((latest_r as Dictionary).get("correct", false)):
			solved = true
		if is_instance_valid(_usage_btn):
			if solved and not ex_en.is_empty():
				_usage_btn.text = "🔊 生活例句：%s   |   %s" % [ex_en, ex_zh]
				_usage_btn.show()
			else:
				_usage_btn.hide()
		_beat_nav_box.hide()
		_puzzle_box.show()
		_rebuild_puzzle_tray()

	_feedback_label.text = _feedback_text()

func _feedback_text() -> String:
	if view_mode == "practice":
		var latest: Variant = later_response if later_response != null else first_response
		if latest is Dictionary:
			if bool(latest.get("correct", false)):
				return "🎉 哇！全部纸偶都弹起来啦！「%s」拼得真准！" % str(entry.get("spelling_display", ""))
			return "🌱 差一点点！再核对一下字母顺序或大小写，也可以点「折角小提示」偷看一眼～"
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
		slot_lbl.text = _built_tokens[i] if filled else "  ?  "
		slot_lbl.custom_minimum_size = Vector2(46, 46)
		slot_lbl.disabled = not filled
		if filled:
			var remove_idx := i
			slot_lbl.pressed.connect(func():
				_built_tokens.resize(remove_idx)
				_sync_tokens_to_input()
				_rebuild_puzzle_tray()
			)
		_slots_row.add_child(slot_lbl)

	# Build deterministic shuffled wooden token bank (plus 2 gentle decoys for short words)
	var bank: Array[String] = []
	for tok: Dictionary in tokens:
		bank.append(str(tok.get("raw", "")))
	if bank.size() <= 6:
		for decoy: String in ["a", "e", "o", "s", "t"]:
			if not bank.has(decoy) and bank.size() < 8:
				bank.append(decoy)
	# Deterministic shuffle
	var seed_h := absi(str(entry.get("entry_id", "word")).hash())
	for i in range(bank.size()):
		var swap_i := (seed_h + i * 7) % bank.size()
		var tmp := bank[i]
		bank[i] = bank[swap_i]
		bank[swap_i] = tmp

	for piece: String in bank:
		var tile := Button.new()
		tile.text = " " + piece + " "
		tile.custom_minimum_size = Vector2(50, 48)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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

func _on_follow_along_word() -> void:
	var word := str(entry.get("spelling_display", "")).strip_edges()
	if word.is_empty():
		return
	_on_speak_word()
	_story_banner.text = "🎙️ 跟着读一读：「%s」…… 声音真好听！🌟 已收下一颗自信开口星！" % word
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
		# Reveal odd slots in puzzle mode as a gentle pop-up corner peek
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
		# Stand all puppets upright and play celebration bounce!
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
