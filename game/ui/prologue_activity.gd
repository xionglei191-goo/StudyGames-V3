extends VBoxContainer
signal fact(id: String, mode: String)
signal audio_requested(kind: String)
signal finished
signal object_sound(kind: String, index: int)
const Style = preload("res://ui/island_theme.gd")
const Progress = preload("res://scripts/p2_progress.gd")
const Stage = preload("res://ui/landmark_activity_stage.gd")
var entry: Dictionary
var spec: Dictionary
var reduced := false
var stage: Control
var picture: TextureRect
var result_label: Label
var actions: HBoxContainer
var case_box: VBoxContainer
var action_step := 0
var demonstrated := false
var action_done := false
var letter := "A"
var help := 0
var busy := false
var persist: Callable
var glyph_seen := false
var glyph_box: VBoxContainer
var object_box: VBoxContainer
var suspended := false

func _process(_delta: float) -> void:
	if is_instance_valid(stage): stage.suspended = suspended

func _wait_active(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed<seconds and is_inside_tree():
		await get_tree().process_frame
		if not suspended: elapsed+=get_process_delta_time()

func setup(record: Dictionary, reduced_motion: bool = false, resume: Dictionary = {}, commit: Callable = Callable()) -> void:
	entry = record
	letter = str(entry.letter.uppercase)
	spec = Progress.content().letters[letter]
	reduced = reduced_motion
	persist = commit
	action_step = int(resume.get("step",0))
	help = int(resume.get("help",0))
	demonstrated = help==3
	glyph_seen = bool(resume.get("glyph_seen",false))
	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",18)
	add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)
	object_box = VBoxContainer.new()
	object_box.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(object_box)
	stage = Stage.new()
	stage.letter = letter
	stage.step = action_step
	stage.choice = int(resume.get("choice",0))
	var position: Array = resume.get("placement",[0.5,0.5])
	stage.placement = Vector2(position[0],position[1])
	stage.reduced = reduced
	stage.operation_requested.connect(_act)
	object_box.add_child(stage)
	var caption := Style.text(str(entry.anchor.chinese_image_name)+" · "+str(entry.anchor.canonical_word),20)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	object_box.add_child(caption)
	glyph_box = VBoxContainer.new()
	glyph_box.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(glyph_box)
	glyph_box.hide()
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(260,225)
	picture.size_flags_vertical = SIZE_EXPAND_FILL
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = load(spec.world_view)
	glyph_box.add_child(picture)
	var cue := Style.text(spec.glyph_cue,18)
	cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	glyph_box.add_child(cue)
	var views := HBoxContainer.new()
	glyph_box.add_child(views)
	_add_button(views,"正面",func(): picture.texture=load(spec.world_view))
	_add_button(views,"换个角度",func(): picture.texture=load(spec.alternate_view))
	_add_button(left,"看看建筑里的 "+letter,show_glyph)
	_add_button(left,"回到观察小活动",func(): glyph_box.hide(); object_box.show())
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	side.size_flags_horizontal = SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation",10)
	row.add_child(side)
	var instruction := Style.text(spec.instruction,20)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(instruction)
	result_label = Style.text("可以在图上动手，也可以用下面的按钮。",17,Style.MUTED)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(result_label)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	side.add_child(actions)
	var support := HBoxContainer.new()
	side.add_child(support)
	_add_button(support,"小提示",func(): _help(1))
	_add_button(support,"陪我一步",func(): _help(2))
	_add_button(support,"完整示范",_demo)
	case_box = VBoxContainer.new()
	side.add_child(case_box)
	_refresh_actions()
	_emit_initial.call_deferred()

func _emit_initial() -> void:
	if not is_inside_tree(): return
	fact.emit("representative_image_presented","companion_action")
	if action_step>=spec.operations.size(): _feedback()

func _add_button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _save(event: Dictionary) -> bool:
	event.letter = letter
	event.room = "landmark_"+letter
	if persist.is_valid() and not persist.call(event):
		result_label.text = "还没有保存成功。请再按一次当前按钮重试。"
		return false
	return true

func flush() -> bool:
	return not busy

func show_glyph() -> void:
	glyph_box.show()
	object_box.hide()
	await get_tree().process_frame
	if is_inside_tree() and _save({"kind":"letter_glyph"}):
		glyph_seen = true
		if action_done: fact.emit("letter_name_support_offered","demonstration_viewed" if demonstrated else "companion_action")

func _refresh_actions() -> void:
	for child: Node in actions.get_children(): actions.remove_child(child); child.queue_free()
	if action_step>=spec.operations.size(): return
	if letter=="G":
		var slider := HSlider.new()
		slider.min_value=0
		slider.max_value=1
		slider.step=0.01
		slider.custom_minimum_size=Vector2(110,44)
		slider.value_changed.connect(func(value: float): stage.view_angle=value; stage.queue_redraw())
		actions.add_child(slider)
	if not spec.choices.is_empty():
		for index: int in spec.choices.size(): _add_button(actions,str(spec.choices[index]),_act.bind(index,Vector2(0.5,0.5)))
	else: _add_button(actions,str(spec.operations[action_step].label),_act.bind(0,Vector2(0.5,0.5)))

func _help(level: int) -> void:
	if busy or action_done or suspended: return
	if not _save({"kind":"letter_help","level":level}): return
	help = maxi(help,level)
	result_label.text = ("看看图中的伙伴："+str(spec.instruction)) if level==1 else ("我们一起做："+str(spec.operations[action_step].label)+"。点图或下面同名按钮。")

func _act(selected: int = 0, point: Vector2 = Vector2(0.5,0.5)) -> void:
	if busy or action_done or suspended: return
	if (letter in ["O","W"] and selected!=0) or (letter=="U" and selected!=1):
		result_label.text = "再看看今天的伙伴。" if letter!="U" else "雨天要撑开雨伞，再选一次吧。"
		return
	busy = true
	stage.enabled = false
	var event := {"kind":"letter_action","expected_step":action_step,"operation":spec.operations[action_step].id,"choice":selected,"placement":[point.x,point.y]}
	var old_choice: int = stage.choice
	var old_point: Vector2 = stage.placement
	stage.step = action_step+1
	stage.choice = selected
	stage.placement = point
	stage.clock = 0
	stage.queue_redraw()
	if letter=="D": object_sound.emit("kick",0)
	if letter=="X": object_sound.emit("note",0 if action_step==0 else 7)
	await _wait_active(0.12 if reduced else 0.35)
	if not is_inside_tree(): return
	if _save(event): action_step += 1
	else:
		stage.step = action_step
		stage.choice = old_choice
		stage.placement = old_point
	busy = false
	stage.enabled = true
	_refresh_actions()
	if action_step>=spec.operations.size(): _feedback()
	elif action_step==1 and stage.complete_drag:
		stage.complete_drag=false
		_act(selected,point)
	elif help>0: result_label.text = "接下来："+str(spec.operations[action_step].label)

func _demo() -> void:
	if busy or action_done: return
	if not _save({"kind":"letter_help","level":3}): return
	help = 3
	demonstrated = true
	result_label.text = "向导陪你做完每一步，你也可以看着学。"
	while is_inside_tree() and not action_done:
		var previous := action_step
		await _act(1 if letter=="U" else 0)
		if not is_inside_tree() or action_step==previous: return
		await _wait_active(0.15 if reduced else 0.5)

func _feedback() -> void:
	if action_done: return
	action_done = true
	stage.enabled = false
	result_label.text = spec.feedback
	fact.emit("micro_action_feedback_seen","demonstration_viewed" if demonstrated else "hinted_action" if help>0 else "independent_action")
	var pair := Style.text(str(entry.letter.pair),58)
	pair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_box.add_child(pair)
	fact.emit("case_pair_presented","demonstration_viewed" if demonstrated else "companion_action")
	var sounds := HBoxContainer.new()
	case_box.add_child(sounds)
	_add_button(sounds,"听字母名 "+letter,func(): audio_requested.emit("letter"))
	_add_button(sounds,"听地标名",func(): audio_requested.emit("word"))
	if glyph_seen: fact.emit("letter_name_support_offered","demonstration_viewed" if demonstrated else "companion_action")
	_add_button(case_box,"收下这张发现页",func():
		if not glyph_seen:
			show_glyph()
			result_label.text = "先看看建筑里的字母，再收下发现页。"
		else: finished.emit()
	).theme_type_variation = "PrimaryButton"
