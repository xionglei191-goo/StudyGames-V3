extends RefCounted
## V5 Open-Book Travel Directory (`TravelBookView`).
## Tactile two-page storybook journal with painted & vector icons and zero raw OS emojis.
## Actions and node names remain 100% compatible with `JourneyController` & layout tests.

const Style = preload("res://ui/island_theme.gd")

const SOCIAL_ORDER := ["journey:revisits", "journey:friend_corner", "journey:party", "journey:friends", "journey:orchard_play", "journey:p2:transfer"]
const MEMORY_ORDER := ["journey:discoveries", "journey:letters", "journey:photo", "journey:p2:keepsakes", "journey:home", "journey:p2:home", "journey:old_journal", "journey:old_quest"]
const STORY_ORDER := ["v4_chapter_atlas", "journey:library", "journey:books"]
const ICONS := {
	"friend_corner": "home", "party": "picnic", "friends": "flower_box",
	"orchard_play": "apple", "transfer": "flower_box", "discoveries": "map",
	"letters": "map", "photo": "picnic", "keepsakes": "journal", "home": "home",
	"old_journal": "journal", "old_quest": "leaf", "library": "book", "books": "science",
	"revisits": "flower_box", "parent": "journal", "v4_chapter_atlas": "compass"
}

static func build(ui: Node, book_title: String, next_wish: String, visited: int, discoveries: int, entries: Array) -> void:
	ui._begin("journey", "journal")
	ui._heading("我的小岛旅行册", "今天的故事，从这一页接着讲")
	var pages := HBoxContainer.new()
	pages.name = "TravelBookPages"
	pages.add_theme_constant_override("separation", 22)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel_box.add_child(pages)
	var continue_button := _current_page(ui, pages, book_title, next_wish, visited, discoveries)
	var fold := ColorRect.new()
	fold.name = "BookFold"
	fold.color = Color("dfd2b8")
	fold.custom_minimum_size.x = 2
	fold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.add_child(fold)
	var right_page := VBoxContainer.new()
	right_page.name = "TravelBookDirectory"
	right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_page.add_theme_constant_override("separation", 12)
	pages.add_child(right_page)
	var intro := ui.label("翻一翻，今天还想做什么？", 22) as Label
	intro.add_theme_font_override("font", Style.heading_font())
	right_page.add_child(intro)
	var v4_bar := HBoxContainer.new()
	v4_bar.name = "V4CozyQuickBar"
	v4_bar.add_theme_constant_override("separation", 10)
	right_page.add_child(v4_bar)
	for quick: Array in [["换装镜台", "bag", "outfit"], ["八册 81 章", "v4_chapter_atlas", "compass"], ["立体翻翻书", "journey:library", "book"], ["AI 观察室", "v4_parent_ai", "leaf"]]:
		var qbtn := ui.button(str(quick[0]), str(quick[1]), str(quick[1]) == "v4_chapter_atlas", Vector2(0, 44)) as Button
		qbtn.icon = Style.icon(str(quick[2]))
		qbtn.add_theme_constant_override("icon_max_width", 22)
		qbtn.add_theme_constant_override("h_separation", 6)
		qbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qbtn.add_theme_font_size_override("font_size", 15)
		v4_bar.add_child(qbtn)
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
	directory.add_theme_constant_override("separation", 20)
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
	var note := ui.label("发现页会记住一起经历的事，也会记下用过的小提示。", 15, Style.MUTED) as Label
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.panel_box.add_child(note)
	ui._focus_if_current.call_deferred(continue_button.get_instance_id())
	ui._layout.call_deferred()

static func _current_page(ui: Node, pages: HBoxContainer, book_title: String, next_wish: String, visited: int, discoveries: int) -> Button:
	var paper := PanelContainer.new()
	paper.name = "CurrentJourneyPage"
	paper.custom_minimum_size.x = 296
	var surface := Style.keycap(Color("f5efe0"), Color("dfd1b5"), 4, 20, 22, 20)
	paper.add_theme_stylebox_override("panel", surface)
	pages.add_child(paper)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	paper.add_child(content)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	content.add_child(heading)
	heading.add_child(ui.icon_view("journal", 38))
	var title := ui.label("我的小旅程", 22) as Label
	title.add_theme_font_override("font", Style.heading_font())
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(title)
	content.add_child(ui.label("接着上次的故事", 15, Style.MUTED))
	var wish := ui.label(next_wish.replace(" · ", "\n"), 20) as Label
	wish.name = "CurrentJourneyWish"
	wish.custom_minimum_size = Vector2(248, 108)
	wish.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wish.add_theme_constant_override("line_spacing", 5)
	content.add_child(wish)
	var continue_button := ui.button("继续我的旅程", "journey:continue", true, Vector2(0, 54)) as Button
	continue_button.name = "ContinueJourney"
	continue_button.icon = Style.icon("compass")
	continue_button.add_theme_constant_override("icon_max_width", 22)
	continue_button.add_theme_font_size_override("font_size", 20)
	content.add_child(continue_button)
	var space := Control.new()
	space.custom_minimum_size.y = 14
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(space)
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Style.LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(line)
	var discoveries_label := ui.label("走进了 %d 处字母地标\n收下了 %d 张发现页" % [visited, discoveries], 17, Style.MUTED) as Label
	discoveries_label.add_theme_constant_override("line_spacing", 6)
	content.add_child(discoveries_label)
	var book := ui.label(book_title, 15, Style.MUTED) as Label
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
	section.add_theme_constant_override("separation", 8)
	directory.add_child(section)
	var heading := ui.label(title, 18, Style.SAGE) as Label
	heading.add_theme_font_override("font", Style.heading_font())
	section.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)
	for entry: Dictionary in entries:
		var id := str(entry.id)
		var clean_lbl := str(entry.label).replace("◈", "").replace("◈", "").replace("◇", "").strip_edges()
		var item := ui.button(clean_lbl, id, false, Vector2(0, 56)) as Button
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.icon = Style.icon(str(ICONS.get(id.get_slice(":", id.get_slice_count(":") - 1), "leaf")))
		item.add_theme_constant_override("icon_max_width", 30)
		item.add_theme_constant_override("h_separation", 10)
		item.add_theme_font_size_override("font_size", 18)
		item.tooltip_text = clean_lbl
		item.disabled = bool(entry.get("disabled", false))
		_style_entry(item)
		grid.add_child(item)

static func _style_entry(item: Button) -> void:
	var norm := Style.keycap(Color("fbf8ef"), Color("e2d6be"), 3, 14, 12, 9)
	norm.shadow_size = 0
	var hov := Style.keycap(Color("fdf2d6"), Style.GOLD, 3, 14, 12, 9)
	hov.shadow_size = 0
	var prs := Style.keycap(Color("efe6cf"), Color("cbb998"), 1, 14, 12, 10)
	prs.shadow_size = 0
	var dis := Style.keycap(Color("f1eee4"), Color("e2dccd"), 1, 14, 12, 9)
	dis.shadow_size = 0
	item.add_theme_stylebox_override("normal", norm)
	item.add_theme_stylebox_override("hover", hov)
	item.add_theme_stylebox_override("pressed", prs)
	item.add_theme_stylebox_override("disabled", dis)
	var focus := Style.box(Color.TRANSPARENT, 14, 10)
	focus.shadow_size = 0
	focus.set_border_width_all(2)
	focus.border_color = Style.GOLD
	item.add_theme_stylebox_override("focus", focus)
