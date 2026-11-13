extends RefCounted
## V5 Tactile Storybook & Toy-Biscuit Visual Design System.
## Shared palette, 3D beveled biscuit/wood keycaps, custom slim scrollbars,
## and crisp painted + vector iconography with zero raw OS emoji reliance.

const INK := Color("3e3b2f")
const MUTED := Color("6d6756")
const PAPER := Color("fffaf0")
const CARD := Color("f7f1e3")
const SAGE := Color("527e5c")
const SAGE_DEEP := Color("3a5d42")
const SOFT := Color("edf1e1")
const CORAL := Color("c86d51")
const GOLD := Color("c48e37")
const HONEY := Color("f4df9e")
const LINE := Color("e4d7be")
const WOOD_LIP := Color("cbb998")

static var _body_font: FontFile
static var _heading_font: FontFile
static var _icons: Dictionary = {}
static var _illustrations: Dictionary = {}

const ILLUSTRATED_ICONS := [
	"apple", "cake", "bag", "journal", "flower_box", "home", "map", "picnic",
	"science", "art", "music", "outfit", "sun", "leaf", "lamp", "football"
]

static func box(color: Color = PAPER, radius: int = 20, padding: int = 20) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(padding)
	result.border_color = LINE
	result.set_border_width_all(2)
	result.border_width_bottom = 4
	result.shadow_color = Color(0.24, 0.19, 0.11, 0.11)
	result.shadow_size = 6
	result.shadow_offset = Vector2(0, 3)
	return result

static func modal_box(color: Color = Color("fcf7eb"), radius: int = 28, padding: int = 26) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(padding)
	result.border_color = Color("dfd0b4")
	result.set_border_width_all(2)
	result.border_width_bottom = 6
	result.shadow_color = Color(0.18, 0.14, 0.08, 0.22)
	result.shadow_size = 24
	result.shadow_offset = Vector2(0, 10)
	return result

static func pill(bg: Color = PAPER, border: Color = LINE, lip: Color = WOOD_LIP, radius: int = 20, pad_h: int = 16, pad_v: int = 10) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = bg
	result.set_corner_radius_all(radius)
	result.content_margin_left = pad_h
	result.content_margin_right = pad_h
	result.content_margin_top = pad_v
	result.content_margin_bottom = pad_v
	result.border_color = border
	result.set_border_width_all(2)
	result.border_width_bottom = 4
	if lip != border:
		result.border_color = border.lerp(lip, 0.55)
	result.shadow_color = Color(0.22, 0.17, 0.09, 0.12)
	result.shadow_size = 6
	result.shadow_offset = Vector2(0, 3)
	return result

static func keycap(bg: Color, border: Color, bottom_lip: int = 4, radius: int = 16, pad_h: int = 16, pad_v: int = 11) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = bg
	result.set_corner_radius_all(radius)
	result.content_margin_left = pad_h
	result.content_margin_right = pad_h
	result.content_margin_top = pad_v
	result.content_margin_bottom = pad_v + maxi(0, bottom_lip - 2)
	result.border_color = border
	result.set_border_width_all(2)
	result.border_width_bottom = bottom_lip
	result.shadow_color = Color(0.22, 0.17, 0.10, 0.10 if bottom_lip >= 3 else 0.04)
	result.shadow_size = 5 if bottom_lip >= 3 else 2
	result.shadow_offset = Vector2(0, 2 if bottom_lip >= 3 else 1)
	return result

static func body_font() -> FontFile:
	if _body_font == null:
		_body_font = load("res://assets/fonts/rounded/ResourceHanRoundedCN-Medium.ttf")
		_body_font.fallbacks = [load("res://assets/fonts/IslandSans.otf")]
	return _body_font

static func heading_font() -> FontFile:
	if _heading_font == null:
		_heading_font = load("res://assets/fonts/rounded/ResourceHanRoundedCN-Bold.ttf")
		_heading_font.fallbacks = [load("res://assets/fonts/IslandSans.otf")]
	return _heading_font

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = body_font()
	result.default_font_size = 21
	result.set_color("font_color", "Label", INK)

	for variant: String in ["Button", "PrimaryButton", "QuietButton", "TileButton"]:
		if variant != "Button":
			result.set_type_variation(variant, "Button")
		var primary := variant == "PrimaryButton"
		var quiet := variant == "QuietButton"
		var rad := 18 if primary else (14 if quiet else 16)
		var pad_h := 16 if not quiet else 12
		var pad_v := 10 if not quiet else 7

		var bg_norm := SAGE if primary else (SOFT if quiet else Color("fffdf7"))
		var bd_norm := SAGE_DEEP if primary else (Color("d5d9c6") if quiet else Color("d8c8ab"))
		var normal := keycap(bg_norm, bd_norm, 4 if not quiet else 3, rad, pad_h, pad_v)
		result.set_stylebox("normal", variant, normal)

		var bg_hov := SAGE.lightened(0.07) if primary else Color("fdf3dc")
		var bd_hov := Color("36593e") if primary else GOLD
		var hover := keycap(bg_hov, bd_hov, 4 if not quiet else 3, rad, pad_h, pad_v)
		result.set_stylebox("hover", variant, hover)

		var bg_prs := SAGE.darkened(0.06) if primary else Color("f3ead4")
		var pressed := keycap(bg_prs, bd_norm.darkened(0.08), 2, rad, pad_h, pad_v + 1)
		result.set_stylebox("pressed", variant, pressed)

		var disabled := keycap(Color("efede2"), Color("ddd7c6"), 2, rad, pad_h, pad_v)
		disabled.shadow_size = 0
		result.set_stylebox("disabled", variant, disabled)

		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.set_corner_radius_all(rad)
		focus.border_color = GOLD
		focus.set_border_width_all(3)
		result.set_stylebox("focus", variant, focus)

		var txt_col := Color("fffdf8") if primary else INK
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			result.set_color(state, variant, txt_col)
		result.set_color("font_disabled_color", variant, Color("858173"))
		result.set_constant("h_separation", variant, 10)
		result.set_constant("icon_max_width", variant, 30)

	result.set_stylebox("panel", "PanelContainer", box())

	# Warm Biscuit LineEdit
	var le_norm := keycap(Color("f7f5ea"), Color("d8ccb2"), 2, 14, 14, 10)
	le_norm.shadow_size = 0
	result.set_stylebox("normal", "LineEdit", le_norm)
	result.set_stylebox("read_only", "LineEdit", keycap(SOFT, LINE, 2, 14, 14, 10))
	var input_focus := StyleBoxFlat.new()
	input_focus.bg_color = Color.TRANSPARENT
	input_focus.set_corner_radius_all(14)
	input_focus.border_color = GOLD
	input_focus.set_border_width_all(2)
	result.set_stylebox("focus", "LineEdit", input_focus)
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", SAGE)
	result.set_color("selection_color", "LineEdit", Color("cee0c4"))
	result.set_color("font_selected_color", "LineEdit", INK)

	# OptionButton & PopupMenu
	for st: String in ["normal", "hover", "pressed", "focus"]:
		result.set_stylebox(st, "OptionButton", result.get_stylebox(st, "Button"))
	for col_st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(col_st, "OptionButton", INK)
	var popup_panel := modal_box(PAPER, 16, 10)
	popup_panel.shadow_size = 12
	result.set_stylebox("panel", "PopupMenu", popup_panel)
	var popup_hov := StyleBoxFlat.new()
	popup_hov.bg_color = Color("f6ecd2")
	popup_hov.set_corner_radius_all(10)
	result.set_stylebox("hover", "PopupMenu", popup_hov)
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", INK)

	# Slim Warm Honey ScrollBars (eliminates default gray OS bars)
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.45, 0.38, 0.25, 0.06)
	sb_track.set_corner_radius_all(6)
	sb_track.content_margin_left = 4
	sb_track.content_margin_right = 4
	sb_track.content_margin_top = 4
	sb_track.content_margin_bottom = 4
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color("d5c4a6")
	sb_grab.set_corner_radius_all(6)
	var sb_grab_hov := StyleBoxFlat.new()
	sb_grab_hov.bg_color = Color("bda67f")
	sb_grab_hov.set_corner_radius_all(6)
	var sb_grab_prs := StyleBoxFlat.new()
	sb_grab_prs.bg_color = Color("a68e67")
	sb_grab_prs.set_corner_radius_all(6)
	for bar_type: String in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", bar_type, sb_track)
		result.set_stylebox("scroll_focus", bar_type, sb_track)
		result.set_stylebox("grabber", bar_type, sb_grab)
		result.set_stylebox("grabber_highlight", bar_type, sb_grab_hov)
		result.set_stylebox("grabber_pressed", bar_type, sb_grab_prs)

	# Warm Toy HSlider
	var sl_track := StyleBoxFlat.new()
	sl_track.bg_color = Color("e6decb")
	sl_track.set_corner_radius_all(6)
	sl_track.content_margin_top = 6
	sl_track.content_margin_bottom = 6
	var sl_fill := StyleBoxFlat.new()
	sl_fill.bg_color = SAGE
	sl_fill.set_corner_radius_all(6)
	sl_fill.content_margin_top = 6
	sl_fill.content_margin_bottom = 6
	result.set_stylebox("slider", "HSlider", sl_track)
	result.set_stylebox("grabber_area", "HSlider", sl_fill)
	result.set_stylebox("grabber_area_highlight", "HSlider", sl_fill)

	return result

static func icon(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if not _icons.has(id):
		var path := icon_asset_path(id)
		if ResourceLoader.exists(path):
			if path.ends_with(".png"):
				_icons[id] = _illustration_thumbnail(id, path)
			else:
				_icons[id] = load(path)
		elif FileAccess.file_exists(path) and path.ends_with(".svg"):
			var img := Image.new()
			if img.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0) == OK:
				_icons[id] = ImageTexture.create_from_image(img)
			else:
				return null
		else:
			return null
	return _icons[id]

static func icon_asset_path(id: String) -> String:
	if ILLUSTRATED_ICONS.has(id):
		var painted := "res://assets/ui/illustrations/%s.png" % id
		if ResourceLoader.exists(painted, "Texture2D"):
			return painted
	return "res://assets/ui/%s.svg" % id

static func _illustration_thumbnail(id: String, path: String) -> Texture2D:
	if _illustrations.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/illustrations/manifest.json"))
		if parsed is Dictionary:
			_illustrations = parsed.get("icons", {})
	var source := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if source == null:
		return null
	var raster := source.get_image()
	if raster.is_compressed() and raster.decompress() != OK:
		return null
	var bounds: Array = _illustrations.get(id, {}).get("region", [0.0, 0.0, 1.0, 1.0])
	var region := Rect2i(
		roundi(float(bounds[0]) * raster.get_width()),
		roundi(float(bounds[1]) * raster.get_height()),
		roundi(float(bounds[2]) * raster.get_width()),
		roundi(float(bounds[3]) * raster.get_height())
	)
	var crop := raster.get_region(region)
	var scale_value := 88.0 / float(maxi(crop.get_width(), crop.get_height()))
	crop.resize(
		maxi(1, roundi(crop.get_width() * scale_value)),
		maxi(1, roundi(crop.get_height() * scale_value)),
		Image.INTERPOLATE_LANCZOS
	)
	var canvas := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((96 - crop.get_width()) / 2, (96 - crop.get_height()) / 2))
	var thumbnail := ImageTexture.create_from_image(canvas)
	thumbnail.set_meta("source_art_path", path)
	return thumbnail

static func text(value: String, font_size: int = 19, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", maxi(16, font_size + (1 if font_size >= 20 else 0)))
	result.add_theme_font_override("font", heading_font() if font_size >= 24 else body_font())
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
