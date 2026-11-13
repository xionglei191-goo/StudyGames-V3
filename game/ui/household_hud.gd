extends Control
## Leaves the working surface unobscured. There is no button that advances a chore.
signal leave_requested
signal retry_requested
const Style = preload("res://ui/island_theme.gd")
var heading: Label
var instruction: Label
var detail: Label
var progress: ProgressBar
var exit_button: Button
var retry_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	var top := HBoxContainer.new()
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_top = 24
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Style.PAPER, 14, 16))
	top.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	heading = Style.text("", 23)
	column.add_child(heading)
	instruction = Style.text("", 18, Style.MUTED)
	column.add_child(instruction)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	exit_button = Button.new()
	exit_button.text = "先放下  Esc"
	exit_button.custom_minimum_size = Vector2(136, 48)
	exit_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	exit_button.pressed.connect(func(): leave_requested.emit())
	top.add_child(exit_button)
	var bottom := PanelContainer.new()
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -260
	bottom.offset_right = 260
	bottom.offset_top = -112
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", Style.box(Style.PAPER, 14, 14))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(box)
	detail = Style.text("", 18)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 7
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.add_theme_stylebox_override("background", Style.box(Style.SOFT, 3, 0))
	progress.add_theme_stylebox_override("fill", Style.box(Style.SAGE, 3, 0))
	box.add_child(progress)
	retry_button = Button.new()
	retry_button.text = "重试保存"
	retry_button.hide()
	retry_button.pressed.connect(func(): retry_requested.emit())
	box.add_child(retry_button)

func update_status(title: String, hint: String, feedback: String, fraction: float) -> void:
	heading.text = title
	instruction.text = hint
	detail.text = feedback
	progress.value = clampf(fraction, 0, 1)
