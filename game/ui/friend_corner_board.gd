extends Control
## The same composition renders the interactive tabletop and the committed board inside the home.
signal placement_requested(recipient: String, slot: String)
signal reply_opened(recipient: String)
signal selection_changed(recipient: String)

const Style = preload("res://ui/island_theme.gd")
const Progress = preload("res://scripts/friend_corner_progress.gd")
const Content = preload("res://ui/memory_story_content.gd")
const LOGICAL_SIZE := Vector2(1000,560)
const SLOT_RECTS := {"left":Rect2(46,128,250,214), "right":Rect2(704,128,250,214), "lower":Rect2(375,330,250,214)}
const TRAY_RECTS := {"textbook_lingling":Rect2(46,390,250,150), "textbook_tim":Rect2(704,390,250,150)}
const SLOT_LABELS := {"left":"左边挂点", "right":"右边挂点", "lower":"下面挂点"}
const NAMES := {"textbook_lingling":"Lingling", "textbook_tim":"Tim"}
var layout_data: Dictionary = Progress.empty_layout()
var reply_data: Dictionary = {}
var owned := false
var editable := false
var goal_preview := false
var world_view := false
var selected := ""
var photo: Texture2D
var has_photo := false
var cards: Dictionary = {}
var slots: Dictionary = {}
var font: Font = Style.body_font()
var _factor := 1.0
var _origin := Vector2.ZERO
var _ready_to_layout := false

class LetterButton extends Button:
	var recipient := ""
	var slot := ""
	var drop_action: Callable
	var draggable := false
	func _get_drag_data(_at: Vector2) -> Variant:
		if not draggable: return null
		var preview := Label.new()
		preview.text = "挂起 " + ("Lingling" if recipient == "textbook_lingling" else "Tim") + " 的回信"
		preview.add_theme_stylebox_override("normal", Style.box(Style.PAPER,12,12))
		set_drag_preview(preview)
		return {"kind":"friend_corner_reply", "recipient":recipient}
	func _can_drop_data(_at: Vector2, value: Variant) -> bool:
		return draggable and not slot.is_empty() and value is Dictionary and value.get("kind") == "friend_corner_reply" and value.get("recipient") in Progress.RECIPIENTS
	func _drop_data(_at: Vector2, value: Variant) -> void:
		drop_action.call(str(value.recipient),slot)

class SlotButton extends Button:
	var slot := ""
	var drop_action: Callable
	func _can_drop_data(_at: Vector2, value: Variant) -> bool:
		return value is Dictionary and value.get("kind") == "friend_corner_reply" and value.get("recipient") in Progress.RECIPIENTS
	func _drop_data(_at: Vector2, value: Variant) -> void:
		drop_action.call(str(value.recipient),slot)

func setup(value: Dictionary, photo_path: String, photo_created: bool, replies: Dictionary, editing: bool = false, preview: bool = false, world: bool = false) -> void:
	owned = Progress.owns_replies(value)
	editable = editing
	goal_preview = preview
	world_view = world
	has_photo = photo_created
	reply_data = replies
	layout_data = (value.draft if editing and not value.draft.is_empty() else value.layout).duplicate(true)
	if not photo_path.is_empty() and FileAccess.file_exists(photo_path):
		var image := Image.load_from_file(photo_path)
		if image: photo = ImageTexture.create_from_image(image)
	custom_minimum_size = Vector2(0,250)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE if world_view else MOUSE_FILTER_STOP
	for slot: String in SLOT_RECTS:
		var target := SlotButton.new()
		target.name = "CornerSlot_" + slot
		target.slot = slot
		target.text = SLOT_LABELS[slot]
		target.add_theme_font_size_override("font_size",23)
		target.drop_action = _drop
		target.pressed.connect(func(): if not selected.is_empty(): _drop(selected,slot))
		target.tooltip_text = "先选一封回信，再点这里；也可以拖过来。"
		add_child(target)
		slots[slot] = target
	for recipient: String in Progress.RECIPIENTS:
		var card := LetterButton.new()
		card.name = "CornerReply_" + recipient
		card.recipient = recipient
		card.drop_action = _drop
		card.draggable = editable
		card.add_theme_font_size_override("font_size",23)
		card.add_theme_constant_override("outline_size",0)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.pressed.connect(func():
			if editable:
				selected = recipient
				selection_changed.emit(recipient)
				_sync()
			else: reply_opened.emit(recipient)
		)
		add_child(card)
		cards[recipient] = card
	_ready_to_layout = true
	resized.connect(_sync)
	_sync()

func update_layout(value: Dictionary) -> void:
	layout_data = value.duplicate(true)
	_sync()

func _drop(recipient: String, slot: String) -> void:
	selected = recipient
	placement_requested.emit(recipient,slot)
	selection_changed.emit(recipient)

func _sync() -> void:
	if not _ready_to_layout: return
	_factor = minf(size.x/LOGICAL_SIZE.x, size.y/LOGICAL_SIZE.y)
	_factor = maxf(_factor,0.01)
	_origin = (size-LOGICAL_SIZE*_factor)*0.5
	for slot: String in slots:
		var target: Button = slots[slot]
		target.visible = editable
		var area: Rect2 = SLOT_RECTS[slot]
		_position_control(target,Rect2(area.position-Vector2(0,40),Vector2(area.size.x,36)))
		target.add_theme_stylebox_override("normal",Style.box(Color("e3eadb"),10,4))
	for recipient: String in cards:
		var card: LetterButton = cards[recipient]
		var slot := str(layout_data.positions[recipient])
		if goal_preview and not owned: slot = "left" if recipient == Progress.RECIPIENTS[0] else "right"
		card.slot = slot
		card.visible = (owned or goal_preview) and (not world_view or not slot.is_empty())
		card.disabled = not owned
		card.focus_mode = FOCUS_NONE if world_view or not owned else FOCUS_ALL
		card.mouse_filter = MOUSE_FILTER_IGNORE if world_view else MOUSE_FILTER_STOP
		var area: Rect2 = TRAY_RECTS[recipient] if slot.is_empty() else SLOT_RECTS[slot]
		_position_control(card,area)
		if not owned:
			card.text = "朋友的回信\n\n以后可以挂在这里"
		elif slot.is_empty():
			card.text = str(NAMES[recipient])+" 的回信\n\n"+("选中 / 拖动来挂起" if editable else "已收好 · 点开读一读")
		else:
			var lines: Array = reply_data.get(recipient,{}).get("lines",[])
			card.text = str(NAMES[recipient])+" 的回信\n\n"+"\n".join(lines)
		card.tooltip_text = "朋友的回信 · 完成邀请后收到" if not owned else str(NAMES[recipient])+" 的回信"+(" · 已选中" if selected == recipient and editable else "")
		var paper := Style.box(Color("fffaf0") if owned else Color("eaeadd"),12,14)
		paper.border_color = Style.GOLD if selected == recipient and editable else Color("d6c49c")
		paper.set_border_width_all(3 if selected == recipient and editable else 1)
		card.add_theme_stylebox_override("normal",paper)
		card.add_theme_stylebox_override("hover",Style.box(Color("fffdf5"),12,14))
		card.add_theme_stylebox_override("disabled",Style.box(Color("eaeadd"),12,14))
		card.add_theme_color_override("font_color",Style.INK)
		card.add_theme_color_override("font_disabled_color",Style.MUTED)
	queue_redraw()

func _position_control(node: Control, rect: Rect2) -> void:
	node.position = _origin+rect.position*_factor
	node.size = rect.size
	node.scale = Vector2.ONE*_factor

func _draw() -> void:
	if not _ready_to_layout: return
	draw_set_transform(_origin,0,Vector2.ONE*_factor)
	var paper := Style.box(Color("e9ecdb") if layout_data.style == "flowers" else Color("eee3c9"),24,0)
	paper.shadow_size = 0
	draw_style_box(paper,Rect2(Vector2.ZERO,LOGICAL_SIZE))
	for column: int in 20:
		for row: int in 11:
			draw_circle(Vector2(25+column*50,25+row*50),1.3,Color(0.3,0.4,0.3,0.12))
	draw_string(font,Vector2(35,42),"一起做过的小事",HORIZONTAL_ALIGNMENT_LEFT,360,28,Style.INK)
	var motif: Texture2D = Content.icon("F" if layout_data.style == "flowers" else "S",1.0)
	if motif: draw_texture_rect(motif,Rect2(902,12,72,72),false)
	var frame := Style.box(Style.PAPER,10,0)
	frame.shadow_size = 3
	draw_style_box(frame,Rect2(345,58,310,224))
	if photo:
		var target := Rect2(357,70,286,164)
		var fit: float = minf(target.size.x/photo.get_width(),target.size.y/photo.get_height())
		var photo_size := Vector2(photo.get_width(),photo.get_height())*fit
		draw_texture_rect(photo,Rect2(target.position+(target.size-photo_size)*0.5,photo_size),false)
	else:
		draw_rect(Rect2(357,70,286,164),Color("d5dfd4"))
		for index: int in 3:
			var center := Vector2(414+index*85,134)
			draw_circle(center,23,Color("e8bb8d"))
			draw_style_box(Style.box([Color("d8a872"),Color("7caa9a"),Color("d49b8b")][index],16,0),Rect2(center+Vector2(-26,23),Vector2(52,56)))
	draw_string(font,Vector2(365,263),"我们的欢迎合照" if has_photo else "欢迎合照的位置",HORIZONTAL_ALIGNMENT_CENTER,270,23,Style.INK)
	for slot: String in SLOT_RECTS:
		var area: Rect2 = SLOT_RECTS[slot]
		var occupied := false
		for recipient: String in Progress.RECIPIENTS:
			if layout_data.positions[recipient] == slot: occupied = true
		if not occupied and not (goal_preview and slot in ["left", "right"]):
			var empty := Style.box(Color(0.99,0.98,0.91,0.45),12,0)
			empty.shadow_size = 0
			empty.border_color = Color("bcc7b1")
			draw_style_box(empty,area)
			if editable: draw_string(font,area.position+Vector2(18,area.size.y*0.55),"回信可以挂在这里",HORIZONTAL_ALIGNMENT_CENTER,area.size.x-36,21,Style.MUTED)
		if occupied or (goal_preview and slot in ["left", "right"]):
			draw_line(area.position+Vector2(area.size.x*0.5,-17),area.position+Vector2(area.size.x*0.5,7),Style.GOLD,8,true)
	if owned and not world_view:
		for recipient: String in Progress.RECIPIENTS:
			if str(layout_data.positions[recipient]).is_empty():
				var area: Rect2 = TRAY_RECTS[recipient]
				draw_string(font,area.position-Vector2(0,12),"回信收在这里",HORIZONTAL_ALIGNMENT_CENTER,area.size.x,21,Style.MUTED)
