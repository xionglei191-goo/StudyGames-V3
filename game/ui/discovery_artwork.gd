extends Control
## One composition is shared by editing, collection and the actual home display.
const Progress = preload("res://scripts/discovery_progress.gd")
const Style = preload("res://ui/island_theme.gd")
const Content = preload("res://ui/memory_story_content.gd")
const LOGICAL_SIZE := Vector2(560,500)
const COLORS := {"sunrise":Color("f4e4bd"),"meadow":Color("dce9d5"),"sea":Color("d6e8ee")}
var item_type := "card"
var item_id := ""
var design: Dictionary = {}
var caption := ""
var font: Font = Style.body_font()
var image_texture: Texture2D
var small_images: Dictionary = {}

func setup(kind: String, id: String, value: Dictionary, title: String = "") -> void:
	item_type = kind
	item_id = id
	caption = title
	custom_minimum_size = Vector2(180,230)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw): resized.connect(queue_redraw)
	update_design(value)

func update_design(value: Dictionary) -> void:
	design = value.duplicate(true)
	image_texture = Content.icon(str(design.get("image_letter","")),2.0)
	small_images.clear()
	if item_type == "page":
		for letter: String in str(Progress.DISTRICTS.get(item_id,"")):
			small_images[letter] = Content.icon(letter,0.5)
	set_meta("item_type",item_type)
	set_meta("item_id",item_id)
	set_meta("image_letter",str(design.get("image_letter","")))
	set_meta("design",design.duplicate(true))
	queue_redraw()

func _draw() -> void:
	var factor := minf(size.x/LOGICAL_SIZE.x,size.y/LOGICAL_SIZE.y)
	if factor <= 0: return
	draw_set_transform((size-LOGICAL_SIZE*factor)*0.5,0,Vector2.ONE*factor)
	var background: Color = COLORS.get(design.get("theme","sunrise"),COLORS.sunrise)
	var paper := Style.box(background,24,0)
	paper.shadow_size = 0
	paper.border_color = background.darkened(0.16)
	paper.set_border_width_all(2)
	draw_style_box(paper,Rect2(Vector2(6,6),LOGICAL_SIZE-Vector2(12,12)))
	for x: int in 10:
		for y: int in 9:
			draw_circle(Vector2(30+x*54,30+y*54),1.4,Color(0.25,0.35,0.25,0.12))
	if item_id.is_empty() or design.is_empty():
		draw_string(font,Vector2(40,245),"发现卡的位置" if item_type == "card" else "旅行页的位置",HORIZONTAL_ALIGNMENT_CENTER,480,30,Style.MUTED)
		draw_string(font,Vector2(40,293),"选好后，就能在家里看见",HORIZONTAL_ALIGNMENT_CENTER,480,23,Style.MUTED)
		return
	var letter := str(design.image_letter)
	var title := "我的字母发现" if item_type == "card" else str(Progress.DISTRICT_NAMES.get(item_id,""))+" · 旅行页"
	draw_string(font,Vector2(30,52),title,HORIZONTAL_ALIGNMENT_CENTER,500,30,Style.INK)
	var image_rect := Rect2(125,77,310,282)
	var text_rect := Rect2(40,370,480,70)
	if item_type == "page":
		image_rect = Rect2(140,73,280,250)
		text_rect = Rect2(40,325,480,70)
	if design.layout == "postcard":
		image_rect = Rect2(35,105,285,285)
		text_rect = Rect2(330,170,200,150)
		if item_type == "card": draw_line(Vector2(325,105),Vector2(325,380),background.darkened(0.22),2,true)
	draw_style_box(Style.box(Color("fffdf4"),18,0),image_rect)
	if image_texture: _draw_texture_fit(image_texture,image_rect.grow(-12))
	draw_string(font,text_rect.position+Vector2(0,40),letter+letter.to_lower(),HORIZONTAL_ALIGNMENT_CENTER,text_rect.size.x,43,Style.INK)
	if not caption.is_empty():
		draw_string(font,text_rect.position+Vector2(0,77 if design.layout == "postcard" else 69),caption,HORIZONTAL_ALIGNMENT_CENTER,text_rect.size.x,24,Style.INK)
	if item_type == "page":
		var district_letters := str(Progress.DISTRICTS[item_id])
		var spacing := 470.0/float(district_letters.length())
		for index: int in district_letters.length():
			var key := district_letters[index]
			var rect := Rect2(45+spacing*index,431,46,46)
			if small_images.get(key) != null: _draw_texture_fit(small_images[key],rect)
			draw_string(font,Vector2(rect.position.x+44,463),key,HORIZONTAL_ALIGNMENT_LEFT,30,18,Style.INK)
	else:
		draw_string(font,Vector2(30,476),"一起看过的发现，带回小屋",HORIZONTAL_ALIGNMENT_CENTER,500,20,Style.MUTED)

func _draw_texture_fit(texture: Texture2D, target: Rect2) -> void:
	var dimensions := Vector2(texture.get_width(),texture.get_height())
	var fit := minf(target.size.x/dimensions.x,target.size.y/dimensions.y)
	var extent := dimensions*fit
	draw_texture_rect(texture,Rect2(target.position+(target.size-extent)*0.5,extent),false)
