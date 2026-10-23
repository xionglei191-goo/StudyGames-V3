extends RefCounted
## A quiet, open-book directory. Actions still belong to JourneyController.
const Style = preload("res://ui/island_theme.gd")

const SOCIAL_ORDER := ["journey:friend_corner", "journey:party", "journey:friends", "journey:orchard_play", "journey:p2:transfer"]
const MEMORY_ORDER := ["journey:discoveries", "journey:letters", "journey:photo", "journey:p2:keepsakes", "journey:home", "journey:p2:home", "journey:old_journal", "journey:old_quest"]
const STORY_ORDER := ["journey:library", "journey:books"]
const ICONS := {
	"friend_corner":"home", "party":"picnic", "friends":"flower_box",
	"orchard_play":"apple", "transfer":"flower_box", "discoveries":"map",
	"letters":"map", "photo":"picnic", "keepsakes":"journal", "home":"home",
	"old_journal":"journal", "old_quest":"leaf", "library":"journal", "books":"science"
}

static func build(ui: Node, book_title: String, next_wish: String, visited: int, discoveries: int, entries: Array) -> void:
	ui._begin("journey", "journal")
	ui._heading("我的小岛旅行册", "今天的故事，从这一页接着讲")
	var pages := HBoxContainer.new()
	pages.name = "TravelBookPages"
	pages.add_theme_constant_override("separation", 24)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(pages)
	var continue_button := _current_page(ui, pages, book_title, next_wish, visited, discoveries)
	var fold := ColorRect.new()
	fold.name = "BookFold"
	fold.color = Style.LINE
	fold.custom_minimum_size.x = 1
	fold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.add_child(fold)
	var right_page := VBoxContainer.new()
	right_page.name = "TravelBookDirectory"
	right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_page.add_theme_constant_override("separation", 12)
	pages.add_child(right_page)
	var intro := ui.label("翻一翻，今天还想做什么？", 23) as Label
	right_page.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.name = "TravelBookScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	right_page.add_child(scroll)
	var directory := VBoxContainer.new()
	directory.name = "TravelBookSections"
	directory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directory.add_theme_constant_override("separation", 22)
	scroll.add_child(directory)
	var social: Array[Dictionary] = []
	var memories: Array[Dictionary] = []
	var stories: Array[Dictionary] = []
	var other: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var id := str(entry.get("id", ""))
		if id == "journey:continue":
			continue
		if SOCIAL_ORDER.has(id):
			social.append(entry)
		elif MEMORY_ORDER.has(id):
			memories.append(entry)
		elif STORY_ORDER.has(id):
			stories.append(entry)
		else:
			other.append(entry)
	_order_entries(social, SOCIAL_ORDER)
	_order_entries(memories, MEMORY_ORDER)
	_order_entries(stories, STORY_ORDER)
	_add_section(ui, directory, "和朋友过一天", social)
	_add_section(ui, directory, "我的发现与回忆", memories)
	_add_section(ui, directory, "书里的故事", stories)
	_add_section(ui, directory, "还有这些小事", other)
	var note := ui.label("发现页会记住一起经历的事，也会记下用过的小提示。", 16, Style.MUTED) as Label
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.panel_box.add_child(note)
	ui._focus_if_current.call_deferred(continue_button.get_instance_id())
	ui._layout.call_deferred()

static func _current_page(ui: Node, pages: HBoxContainer, book_title: String, next_wish: String, visited: int, discoveries: int) -> Button:
	var paper := PanelContainer.new()
	paper.name = "CurrentJourneyPage"
	paper.custom_minimum_size.x = 292
	var surface := Style.box(Color("f2f1e3"), 12, 22)
	surface.shadow_size = 0
	surface.set_border_width_all(0)
	paper.add_theme_stylebox_override("panel", surface)
	pages.add_child(paper)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 17)
	paper.add_child(content)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	content.add_child(heading)
	heading.add_child(ui.icon_view("journal", 40))
	var title := ui.label("我的小旅程", 22) as Label
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(title)
	content.add_child(ui.label("接着上次的故事", 16, Style.MUTED))
	var wish := ui.label(next_wish.replace(" · ", "\n"), 22) as Label
	wish.name = "CurrentJourneyWish"
	wish.custom_minimum_size = Vector2(248, 112)
	wish.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wish.add_theme_constant_override("line_spacing", 5)
	content.add_child(wish)
	var continue_button := ui.button("继续我的旅程", "journey:continue", true, Vector2(0, 56)) as Button
	continue_button.name = "ContinueJourney"
	continue_button.add_theme_font_size_override("font_size", 21)
	content.add_child(continue_button)
	var space := Control.new()
	space.custom_minimum_size.y = 16
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(space)
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Style.LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(line)
	var discoveries_label := ui.label("走进了 %d 处字母地标\n收下了 %d 张发现页" % [visited, discoveries], 18, Style.MUTED) as Label
	discoveries_label.add_theme_constant_override("line_spacing", 7)
	content.add_child(discoveries_label)
	var book := ui.label(book_title, 16, Style.MUTED) as Label
	book.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(book)
	return continue_button

static func _order_entries(entries: Array[Dictionary], order: Array) -> void:
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return order.find(str(first.id)) < order.find(str(second.id))
	)

static func _add_section(ui: Node, directory: VBoxContainer, title: String, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 7)
	directory.add_child(section)
	var heading := ui.label(title, 19, Style.SAGE) as Label
	section.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	section.add_child(grid)
	for entry: Dictionary in entries:
		var id := str(entry.id)
		var item := ui.button(str(entry.label), id, false, Vector2(0, 58)) as Button
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.icon = Style.icon(str(ICONS.get(id.get_slice(":", id.get_slice_count(":") - 1), "leaf")))
		item.add_theme_constant_override("icon_max_width", 34)
		item.add_theme_constant_override("h_separation", 10)
		item.add_theme_font_size_override("font_size", 20)
		item.tooltip_text = str(entry.label)
		item.disabled = bool(entry.get("disabled", false))
		_style_entry(item)
		grid.add_child(item)

static func _style_entry(item: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color.TRANSPARENT
		if state == "hover":
			fill = Color("efefe1")
		elif state == "pressed":
			fill = Color("e5ead9")
		var surface := Style.box(fill, 7, 10)
		surface.shadow_size = 0
		surface.set_border_width_all(0)
		surface.border_width_bottom = 1 if state in ["normal", "disabled"] else 0
		surface.border_color = Color("e5ddc9")
		item.add_theme_stylebox_override(state, surface)
	var focus := Style.box(Color.TRANSPARENT, 7, 10)
	focus.shadow_size = 0
	focus.set_border_width_all(2)
	focus.border_color = Style.GOLD
	item.add_theme_stylebox_override("focus", focus)
