extends RefCounted
## Shared visual language. Individual screens only choose semantic variants.

const INK := Color("4b493b")
const MUTED := Color("6d6b5c")
const PAPER := Color("fffaf0")
const SAGE := Color("54775e")
const SOFT := Color("edf0df")
const CORAL := Color("b8654c")
const GOLD := Color("b8873e")
const LINE := Color("e9dfc8")
static var _body_font: FontFile
static var _heading_font: FontFile
static var _icons: Dictionary = {}
static var _illustrations: Dictionary = {}
const ILLUSTRATED_ICONS := ["apple", "cake", "bag", "journal", "flower_box", "home", "map", "picnic", "science", "art", "music", "outfit", "sun", "leaf", "lamp", "football"]

static func box(color: Color = PAPER, radius: int = 20, padding: int = 20) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(padding)
	result.border_color = LINE
	result.set_border_width_all(1)
	result.shadow_color = Color(0.30, 0.25, 0.16, 0.12)
	result.shadow_size = 3
	result.shadow_offset = Vector2(0, 2)
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
	result.default_font_size = 22
	result.set_color("font_color", "Label", INK)
	for variant: String in ["Button", "PrimaryButton", "QuietButton", "TileButton"]:
		if variant != "Button":
			result.set_type_variation(variant, "Button")
		var primary := variant == "PrimaryButton"
		var color := SAGE if primary else PAPER
		if variant == "QuietButton":
			color = SOFT
		var normal := box(color, 12, 15)
		normal.border_color = color.darkened(0.09) if primary else LINE
		result.set_stylebox("normal", variant, normal)
		var hover := box(color.lightened(0.04) if primary else Color("f5edda"), 12, 15)
		hover.border_color = GOLD if not primary else color.lightened(0.18)
		result.set_stylebox("hover", variant, hover)
		var pressed := box(color.darkened(0.04), 12, 15)
		pressed.shadow_size = 2
		pressed.shadow_offset = Vector2(0, 1)
		result.set_stylebox("pressed", variant, pressed)
		result.set_stylebox("disabled", variant, box(Color("eeecdf"), 12, 15))
		var focus := box(Color.TRANSPARENT, 12, 0)
		focus.border_color = GOLD
		focus.set_border_width_all(3)
		focus.shadow_size = 0
		result.set_stylebox("focus", variant, focus)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, variant, PAPER if primary else INK)
		result.set_color("font_disabled_color", variant, Color("797a6d"))
		result.set_constant("h_separation", variant, 10)
		result.set_constant("icon_max_width", variant, 32)
	result.set_stylebox("panel", "PanelContainer", box())
	result.set_stylebox("normal", "LineEdit", box(Color("f2f4e9"), 14, 14))
	result.set_stylebox("read_only", "LineEdit", box(SOFT, 14, 14))
	var input_focus := box(Color.TRANSPARENT, 14, 0)
	input_focus.border_color = GOLD
	input_focus.set_border_width_all(2)
	input_focus.shadow_size = 0
	result.set_stylebox("focus", "LineEdit", input_focus)
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", SAGE)
	result.set_color("selection_color", "LineEdit", Color("cee0c4"))
	result.set_color("font_selected_color", "LineEdit", INK)
	return result

static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := icon_asset_path(id)
		if ResourceLoader.exists(path):
			if path.ends_with(".png"):
				_icons[id] = _illustration_thumbnail(id, path)
			else:
				_icons[id] = load(path)
		else:
			return null
	return _icons[id]

static func icon_asset_path(id: String) -> String:
	if ILLUSTRATED_ICONS.has(id):
		var painted := "res://assets/ui/illustrations/%s.png" % id
		if ResourceLoader.exists(painted, "Texture2D"):
			return painted
	# Navigation, close, check, settings and speech remain crisp vector symbols.
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
	var bounds: Array = _illustrations.get(id, {}).get("region", [0.0,0.0,1.0,1.0])
	var region := Rect2i(roundi(float(bounds[0])*raster.get_width()),roundi(float(bounds[1])*raster.get_height()),roundi(float(bounds[2])*raster.get_width()),roundi(float(bounds[3])*raster.get_height()))
	var crop := raster.get_region(region)
	var scale_value := 86.0/float(maxi(crop.get_width(),crop.get_height()))
	crop.resize(maxi(1,roundi(crop.get_width()*scale_value)),maxi(1,roundi(crop.get_height()*scale_value)),Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(96,96,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((96-crop.get_width())/2,(96-crop.get_height())/2))
	var thumbnail := ImageTexture.create_from_image(canvas)
	thumbnail.set_meta("source_art_path",path)
	return thumbnail

static func text(value: String, font_size: int = 19, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", maxi(18, font_size + (2 if font_size >= 19 else 0)))
	result.add_theme_font_override("font", heading_font() if font_size >= 26 else body_font())
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
