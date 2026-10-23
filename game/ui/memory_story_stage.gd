extends Control
## Semantic paper-theatre. At most four letter actors; no hidden answer resources.
signal step_presented(event: Dictionary)
signal playback_changed(snapshot: Dictionary)

const Content = preload("res://ui/memory_story_content.gd")
const Style = preload("res://ui/island_theme.gd")
const STAGE_REVISION := "memory-stage-v1"
const BOOK_READING_CENTER := Vector2(450,172)
const SEMANTIC_ART_REGISTRY := "res://data/learning/story_prop_art.json"
const MAX_SEMANTIC_TEXTURES := 12
const SEMANTIC_TEXTURE_EDGE := 256
static var _semantic_art: Dictionary = {}
const PROP_ROOT := "res://assets/learning/storybook_v2/props/"
const PROP_IDS := ["book_open_base", "book_cover", "book_page_leaf", "football", "greeting_door", "greeting_window", "reading_table", "football_goal_frame", "owl_wing", "drumstick"]
# Source PNGs stay intact. These normalized bounds crop transparent padding only.
const PROP_REGIONS := {
	"book_cover": [0.06862745098039216,0.1397459165154265,0.8641456582633054,0.720508166969147],
	"book_open_base": [0.05477980665950591,0.08284023668639054,0.8904403866809882,0.8236686390532545],
	"book_page_leaf": [0.05458515283842795,0.1423580786026201,0.8930131004366813,0.714410480349345],
	"drumstick": [0.08568207440811725,0.33934611048478014,0.8286358511837655,0.3382187147688839],
	"football": [0.11323763955342903,0.11881977671451356,0.7719298245614035,0.766347687400319],
	"football_goal_frame": [0.04066985645933014,0.14513556618819776,0.9186602870813397,0.7129186602870813],
	"greeting_door": [0.1435546875,0.08138020833333333,0.7138671875,0.8274739583333334],
	"greeting_window": [0.04704944178628389,0.16267942583732056,0.9059011164274322,0.6682615629984051],
	"owl_wing": [0.044657097288676235,0.2894736842105263,0.916267942583732,0.4625199362041467],
	"reading_table": [0.034385569334836524,0.4081172491544532,0.9317925591882751,0.31905298759864714]
}
var entry: Dictionary = {}
var frame_positions: Array = []
var allowed_positions: Array = []
var events: Array = []
var support_level := 5
var reduced_motion := false
var playback_status := "paused"
var phase := 0.0
var event_index := 0
var beat_id := ""
var _textures: Dictionary = {}
var _tween: Tween
var _caption: Label
var _pending_exposure := false
var _generation := 0
var _exposure_generation := -1
var _scale_factor := Vector2.ONE
var _prop_textures: Dictionary = {}
var _prop_source_regions: Dictionary = {}
var _visible_prop_ids: Array[String] = []
var _fallback_prop_ids: Array[String] = []
var _drawn_props: Dictionary = {}
var _drawn_runtime_parts: Dictionary = {}
var _semantic_texture_order: Array[String] = []
var _semantic_source_paths: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 280)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = Style.text("点“播放故事”，看看画面怎样接起来。", 18)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_left = 14
	_caption.offset_right = -14
	_caption.offset_top = -53
	_caption.offset_bottom = -7
	add_child(_caption)
	resized.connect(queue_redraw)
	_update_caption()

func setup(value: Dictionary, positions: Array, visible_positions: Array, level: int, reduced: bool, resume: Dictionary = {}) -> void:
	_stop_tween()
	entry = value
	# JSON stores indices as floats; normalize before strict Array.find/has calls.
	frame_positions = positions.map(func(value: Variant): return int(value))
	allowed_positions = visible_positions.map(func(value: Variant): return int(value))
	support_level = level
	reduced_motion = reduced
	events = Content.animation_events(entry,frame_positions,allowed_positions,support_level)
	beat_id = str(resume.get("beat_id", ""))
	_textures.clear()
	_prop_textures.clear()
	_prop_source_regions.clear()
	_visible_prop_ids.clear()
	_fallback_prop_ids.clear()
	_drawn_props.clear()
	_drawn_runtime_parts.clear()
	_semantic_texture_order.clear()
	_semantic_source_paths.clear()
	for p: Variant in allowed_positions:
		_textures[int(p)] = Content.icon(str(entry.letter_slots[int(p)-1].letter),2.0)
	event_index = 0
	phase = 0.0
	playback_status = "paused"
	if not events.is_empty() and resume.get("stage_revision", STAGE_REVISION) == STAGE_REVISION:
		for index: int in range(events.size()):
			if int(events[index].actor_position) == int(resume.get("step_position", -1)):
				event_index = index
				phase = clampf(float(resume.get("phase", 0.0)),0.0,1.0)
				break
	_pending_exposure = false
	_generation += 1
	_update_caption()
	queue_redraw()

func set_beat_id(value: String) -> void:
	beat_id = value

func set_reduced_motion(value: bool) -> void:
	pause()
	reduced_motion = value
	_update_caption()
	playback_changed.emit(snapshot())

func play() -> void:
	if events.is_empty() or playback_status == "playing":
		return
	if playback_status == "completed":
		event_index = 0
		phase = 0.0
	playback_status = "playing"
	_start_current()

func pause() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	if playback_status == "playing":
		playback_status = "paused"
		playback_changed.emit(snapshot())
	_update_caption()

func replay() -> void:
	_stop_tween()
	event_index = 0
	phase = 0.0
	playback_status = "paused"
	play()

func step() -> void:
	if events.is_empty():
		return
	pause()
	if phase >= 0.999:
		if event_index < events.size()-1:
			event_index += 1
			phase = 0.0
		else:
			playback_status = "completed"
			playback_changed.emit(snapshot())
			return
	phase = 0.55 if phase < 0.54 else 1.0
	_request_exposure()
	_update_caption()
	queue_redraw()
	playback_changed.emit(snapshot())

func seek_pose(position: int, value: float) -> void:
	# Also used by frame-sequence verification; obeys the allowed event list.
	pause()
	for index: int in range(events.size()):
		if int(events[index].actor_position) == position:
			event_index = index
			phase = clampf(value,0.0,1.0)
			_request_exposure()
			_update_caption()
			queue_redraw()
			playback_changed.emit(snapshot())
			return

func snapshot() -> Dictionary:
	if events.is_empty():
		return {}
	return {"schema_version":1,"stage_revision":STAGE_REVISION,"beat_id":beat_id,
		"step_position":int(events[event_index].actor_position),"phase":phase,
		"playback_status":playback_status,"reduced_motion":reduced_motion}

func visible_letter_positions() -> Array:
	return allowed_positions.duplicate()

func visible_prop_ids() -> Array[String]:
	return _visible_prop_ids.duplicate()

func prop_diagnostics() -> Dictionary:
	var loaded: Array[String] = []
	for prop_id: String in _prop_textures:
		if _prop_textures[prop_id] != null:
			loaded.append(prop_id)
	var resolution := semantic_art_resolution()
	return {"visible_prop_ids": visible_prop_ids(), "loaded_prop_ids": loaded,
		"fallback_prop_ids": _fallback_prop_ids.duplicate(),
		"source_regions": _prop_source_regions.duplicate(true),
		"drawn_props": _drawn_props.duplicate(true), "runtime_parts": _drawn_runtime_parts.duplicate(true), "support_level": support_level,
		"resolved_semantic_prop_id": str(resolution.get("prop_id", "")),
		"semantic_art_status": str(resolution.get("status", "")),
		"semantic_art_resolution": resolution.duplicate(true),
		"semantic_source_paths": _semantic_source_paths.duplicate(),
		"semantic_texture_cache_count": _semantic_texture_order.size()}

static func semantic_art_registry() -> Dictionary:
	if _semantic_art.is_empty() and FileAccess.file_exists(SEMANTIC_ART_REGISTRY):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEMANTIC_ART_REGISTRY))
		if parsed is Dictionary:
			_semantic_art = parsed
	return _semantic_art

func semantic_art_resolution() -> Dictionary:
	# Do not even resolve answer art for the hidden help level.
	if support_level == 3:
		return {"prop_id":"", "status":"hidden"}
	var registry := semantic_art_registry()
	var story: Dictionary = registry.get("stories", {}).get(str(entry.get("story_id", "")), {})
	var position := int(_current_event().get("actor_position", 0))
	var steps: Array = story.get("steps", [])
	if position < 1 or position > steps.size():
		return {"prop_id":"", "status":"unregistered_story"}
	return steps[position-1]

func _prop_bounds(prop_id: String) -> Array:
	# v2 keeps its accepted source UVs. New props are optically cropped at load.
	if PROP_IDS.has(prop_id):
		return PROP_REGIONS.get(prop_id, [0.0, 0.0, 1.0, 1.0])
	return [0.0, 0.0, 1.0, 1.0]

func visual_state() -> Dictionary:
	var actors: Dictionary = {}
	for p: Variant in allowed_positions:
		actors[str(int(p))] = _actor_pose(int(p))
	return {"actors":actors,"prop":_prop_state(),"phase":phase,"event":_current_event(),"snapshot":snapshot()}

func _start_current() -> void:
	_stop_tween()
	_request_exposure()
	_update_caption()
	queue_redraw()
	playback_changed.emit(snapshot())
	var duration := float(_current_event().get("duration",2.0))
	_tween = create_tween()
	if reduced_motion:
		if phase < 0.54:
			_tween.tween_interval(0.65)
			_tween.tween_callback(_set_phase.bind(0.55))
		if phase < 0.999:
			_tween.tween_interval(0.65)
			_tween.tween_callback(_set_phase.bind(1.0))
	else:
		_tween.tween_method(_set_phase, phase, 1.0, maxf(0.1,duration*(1.0-phase))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(0.35)
	_tween.tween_callback(_finish_current)

func _set_phase(value: float) -> void:
	phase = value
	queue_redraw()

func _finish_current() -> void:
	if playback_status != "playing":
		return
	if event_index >= events.size()-1:
		playback_status = "completed"
		phase = 1.0
		_update_caption()
		playback_changed.emit(snapshot())
	else:
		event_index += 1
		phase = 0.0
		_start_current()

func _stop_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()

func _request_exposure() -> void:
	_generation += 1
	_pending_exposure = true

func _current_event() -> Dictionary:
	return events[event_index] if not events.is_empty() else {}

func _update_caption() -> void:
	if not is_instance_valid(_caption):
		return
	if events.is_empty():
		_caption.text = "先补出一个图卡伙伴，再一起播放。"
		return
	var prefix := ""
	if reduced_motion:
		prefix = "关键画面 · "
	_caption.text = prefix+str(_current_event().get("caption", ""))
	if playback_status == "completed":
		_caption.text += "  这一页演完啦，可以再看或翻页。"

func _actually_visible() -> bool:
	if not is_visible_in_tree() or not is_inside_tree():
		return false
	var region := get_viewport().get_visible_rect()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			region = region.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return region.has_point(get_global_rect().get_center())

func _emit_visible_step(generation: int) -> void:
	if generation != _generation or not _actually_visible() or events.is_empty():
		return
	_exposure_generation = generation
	var event := _current_event().duplicate(true)
	event["revealed_letter_positions"] = visible_letter_positions()
	event["phase"] = phase
	step_presented.emit(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		pause()

func _exit_tree() -> void:
	_stop_tween()

func _base_point(position: int) -> Vector2:
	var index := frame_positions.find(position)
	var x := 500.0 if frame_positions.size() == 1 else 105.0+790.0*float(index)/float(maxi(1,frame_positions.size()-1))
	return Vector2(x,65.0 if semantic_art_resolution().has("count") else 111.0)

func _target_point(position: int) -> Vector2:
	if allowed_positions.has(position):
		return _base_point(position)
	return Vector2(940,146)

func _actor_pose(position: int) -> Dictionary:
	var center := _base_point(position)
	var rotation := 0.0
	var scale_value := 1.0
	var event := _current_event()
	var actor := int(event.get("actor_position",0))
	var kind := str(event.get("action_kind",""))
	var pulse := sin(phase*PI)
	if position == actor:
		match kind:
			"hat_greet": center.y -= pulse*54.0; rotation = -0.28*pulse
			"egg_greet": center.y += 34.0*(1.0-phase)
			"owl_greet","greet": rotation = 0.15*sin(phase*TAU)
			"nest_release": rotation = 0.17*sin(phase*TAU*2.0)
			"nose_lift": center.x += 30.0*pulse
			"boat_book","boat_ball","train_ball","transport": center.x += 72.0*phase
			"book_open": rotation = 0.28*pulse; center.y += 18.0*pulse; center.x += 25.0*pulse
			"book_page": rotation = 0.28*pulse; center.y += 18.0*pulse; center.x -= 120.0*pulse
			"tap": rotation = 0.28*pulse; center.y += 18.0*pulse
			"kite_book","lift": center.y -= 43.0*phase
			"ball_kick","apple_kick": rotation = -0.35*pulse; center.x += 24.0*pulse
			"ball_chest","catch": center.x -= 22.0*sin(phase*PI*2.0)
			"roll": center.x += 65.0*phase; rotation = phase*TAU
			"fly": center.x += 65.0*phase; center.y -= 48.0*pulse
			"travel": center.x += 80.0*phase
			"known_position": center.y += 25.0*(1.0-phase)
	if kind == "nest_release" and position == 2 and allowed_positions.has(1):
		center = _base_point(1).lerp(_base_point(2),phase)+Vector2(0,-45.0*pulse)
	elif kind == "nose_lift" and position == 3:
		center.y -= 65.0*clampf((phase-0.22)/0.78,0.0,1.0)
	elif kind == "sneeze_star" and position == 3 and allowed_positions.has(4):
		center = (_base_point(3)+Vector2(0,-65)).lerp(_base_point(4)+Vector2(0,15),phase)+Vector2(0,-25*pulse)
	elif kind == "shell_catch" and position == 3 and allowed_positions.has(4):
		center = _base_point(4)+Vector2(0,7)
		scale_value = 0.45
	if semantic_art_resolution().has("count"):
		center.y = clampf(center.y,45.0,65.0)
		scale_value *= 0.62
	return {"center":center,"rotation":rotation,"scale":scale_value}

func _prop_state() -> Dictionary:
	var event := _current_event()
	var position := int(event.get("actor_position",1))
	var kind := str(event.get("action_kind",""))
	var actor := _base_point(position) if frame_positions.has(position) else Vector2(500,110)
	var target := _target_point(int(event.get("target_position",0)))
	var p := Vector2(actor.x,191)
	var openness := 0.0
	if kind == "boat_book": p = Vector2(90,186).lerp(BOOK_READING_CENTER,phase)
	elif kind == "book_open": p = BOOK_READING_CENTER; openness = phase
	elif kind == "book_page": p = BOOK_READING_CENTER; openness = 1.0
	elif kind == "kite_book": p = BOOK_READING_CENTER.lerp(Vector2(actor.x,116),phase); openness = 1.0
	elif kind in ["ball_kick","ball_pass","apple_kick","boat_ball"]:
		p = Vector2(actor.x,177).lerp(Vector2(target.x,177),phase)+Vector2(0,-46.0*sin(phase*PI))
	elif kind == "ball_chest":
		p = Vector2(actor.x,177).lerp(Vector2(target.x,177),clampf((phase-0.35)/0.65,0,1))+Vector2(0,-38.0*sin(minf(1,phase/0.35)*PI))
	elif kind == "train_ball": p = Vector2(actor.x,176)+Vector2(72*phase,0)
	elif kind == "goal_near": p = Vector2(actor.x,182).lerp(Vector2(835,182),phase)
	elif kind == "goal_far": p = Vector2(835,182).lerp(Vector2(962,177),phase)
	elif kind in ["transport","roll","fly","travel"]:
		p = Vector2(actor.x,190).lerp(Vector2(target.x,190),phase)
		if kind == "fly": p.y -= 55*sin(phase*PI)
	elif kind == "catch": p = Vector2(target.x,188).lerp(Vector2(actor.x,158),phase)
	elif kind == "lift": p.y -= 65*phase
	elif kind == "place": p.y = 145+47*phase
	elif kind == "open": openness = phase
	return {"position":p,"openness":openness,"rotation":phase*TAU if kind == "roll" or kind.begins_with("ball") else 0.0}

func _draw() -> void:
	_visible_prop_ids.clear()
	_fallback_prop_ids.clear()
	_drawn_props.clear()
	_drawn_runtime_parts.clear()
	if entry.is_empty() or frame_positions.is_empty():
		return
	_scale_factor = Vector2(size.x/1000.0,(size.y-52.0)/238.0)
	draw_style_box(Style.box(Color("e8eddf"),18,0),Rect2(Vector2.ZERO,size))
	_reset_transform()
	draw_line(Vector2(26,211),Vector2(974,211),Color("bacab4"),3.0,true)
	_draw_environment()
	_draw_semantic_effects(false)
	for p: Variant in frame_positions:
		var position := int(p)
		var base := _base_point(position)
		if not allowed_positions.has(position):
			draw_circle(base,43,Color("d7dece"))
			draw_arc(base,43,0,TAU,40,Style.MUTED,2,true)
			_text("?",base+Vector2(-8,10),26,Style.MUTED)
			_text("第%d格" % position,Vector2(base.x-26,231),16,Style.MUTED)
			continue
		var pose := _actor_pose(position)
		var center: Vector2 = pose.center
		var icon_size := Vector2(112,112)*float(pose.scale)
		if int(_current_event().get("actor_position",0)) == position:
			if semantic_art_resolution().has("count"):
				draw_ellipse_under(base+Vector2(0,41),Vector2(44,8),Color("c4d7b5"))
			else:
				draw_ellipse_under(base+Vector2(0,61),Vector2(68,12),Color("c4d7b5"))
		draw_set_transform(center*_scale_factor,float(pose.rotation),_scale_factor)
		draw_texture_rect(_textures[position],Rect2(-icon_size/2,icon_size),false)
		_reset_transform()
		var slot: Dictionary = entry.letter_slots[position-1]
		var label := "%d  %s · %s" % [position,str(slot.raw_character),str(slot.anchor_zh)]
		if int(slot.occurrence)>1: label += "(%d)" % int(slot.occurrence)
		_text(label,Vector2(base.x-70,231),16,Style.INK)
	_draw_semantic_effects(true)
	_reset_transform()
	if _pending_exposure and _actually_visible() and _exposure_generation != _generation:
		_pending_exposure = false
		_emit_visible_step.call_deferred(_generation)

func _reset_transform() -> void:
	draw_set_transform(Vector2.ZERO,0.0,_scale_factor)

func draw_ellipse_under(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(32):
		var angle := TAU*float(i)/32.0
		points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	draw_colored_polygon(points,color)

func _text(value: String, point: Vector2, pixels: int, color: Color) -> void:
	draw_string(get_theme_default_font(),point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _prop_texture(prop_id: String) -> Texture2D:
	# Hidden help levels must not load a prop just to check whether it exists.
	if support_level == 3:
		return null
	if not PROP_IDS.has(prop_id):
		return _semantic_prop_texture(prop_id)
	if _prop_textures.has(prop_id):
		var cached: Texture2D = _prop_textures[prop_id]
		if cached == null and not _fallback_prop_ids.has(prop_id):
			_fallback_prop_ids.append(prop_id)
		return cached
	var texture: Texture2D
	var path := PROP_ROOT+prop_id+".png"
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_prop_textures[prop_id] = texture
	if texture == null:
		if not _fallback_prop_ids.has(prop_id):
			_fallback_prop_ids.append(prop_id)
		return null
	var bounds: Array = PROP_REGIONS.get(prop_id, [0.0, 0.0, 1.0, 1.0])
	_prop_source_regions[prop_id] = [float(bounds[0])*texture.get_width(), float(bounds[1])*texture.get_height(), float(bounds[2])*texture.get_width(), float(bounds[3])*texture.get_height()]
	return texture

func _semantic_prop_texture(prop_id: String) -> Texture2D:
	if support_level == 3 or prop_id.is_empty():
		return null
	if _prop_textures.has(prop_id):
		_semantic_texture_order.erase(prop_id)
		_semantic_texture_order.append(prop_id)
		return _prop_textures[prop_id] as Texture2D
	var spec: Dictionary = semantic_art_registry().get("assets", {}).get(prop_id, {})
	var path := str(spec.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		if not _fallback_prop_ids.has(prop_id): _fallback_prop_ids.append(prop_id)
		return null
	# Keep at most 12 small thumbnails, never the entire original PNG library.
	var source := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if source == null:
		return null
	var raster := source.get_image()
	if raster == null or raster.is_empty():
		return null
	if raster.is_compressed() and raster.decompress() != OK:
		return null
	var bounds: Array = spec.get("region", [0.0,0.0,1.0,1.0])
	var rectangle := Rect2i(roundi(float(bounds[0])*raster.get_width()),roundi(float(bounds[1])*raster.get_height()),roundi(float(bounds[2])*raster.get_width()),roundi(float(bounds[3])*raster.get_height()))
	var cropped := raster.get_region(rectangle)
	var scale_value := minf(1.0,float(SEMANTIC_TEXTURE_EDGE)/float(maxi(cropped.get_width(),cropped.get_height())))
	if scale_value < 1.0:
		cropped.resize(maxi(1,roundi(cropped.get_width()*scale_value)),maxi(1,roundi(cropped.get_height()*scale_value)),Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(cropped)
	texture.set_meta("source_art_path",path)
	while _semantic_texture_order.size() >= MAX_SEMANTIC_TEXTURES:
		var oldest: String = _semantic_texture_order.pop_front()
		_prop_textures.erase(oldest)
		_prop_source_regions.erase(oldest)
		_semantic_source_paths.erase(oldest)
	_prop_textures[prop_id] = texture
	_prop_source_regions[prop_id] = [0.0,0.0,float(texture.get_width()),float(texture.get_height())]
	_semantic_texture_order.append(prop_id)
	_semantic_source_paths[prop_id] = path
	return texture

func _draw_prop_quad(prop_id: String, points: PackedVector2Array, fraction: Rect2 = Rect2(0,0,1,1)) -> bool:
	var texture := _prop_texture(prop_id)
	if texture == null:
		return false
	var bounds: Array = _prop_bounds(prop_id)
	var source := Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
	var uv_rect := Rect2(source.position+source.size*fraction.position,source.size*fraction.size)
	var uvs := PackedVector2Array([uv_rect.position,Vector2(uv_rect.end.x,uv_rect.position.y),uv_rect.end,Vector2(uv_rect.position.x,uv_rect.end.y)])
	draw_polygon(points,PackedColorArray([Color.WHITE]),uvs,texture)
	if not _visible_prop_ids.has(prop_id):
		_visible_prop_ids.append(prop_id)
	if not _drawn_props.has(prop_id):
		_drawn_props[prop_id] = []
	var quad: Array = []
	for point: Vector2 in points:
		quad.append([point.x,point.y])
	_drawn_props[prop_id].append({"quad":quad,"source_uv":[uv_rect.position.x,uv_rect.position.y,uv_rect.size.x,uv_rect.size.y]})
	return true

func _draw_prop_rect(prop_id: String, target: Rect2, rotation: float = 0.0, stretch: bool = false, fraction: Rect2 = Rect2(0,0,1,1)) -> bool:
	var texture := _prop_texture(prop_id)
	if texture == null:
		return false
	var region: Array = _prop_source_regions[prop_id]
	var source_size := Vector2(float(region[2]),float(region[3]))*fraction.size
	var draw_size := target.size
	if not stretch and source_size.x > 0.0 and source_size.y > 0.0:
		draw_size = source_size*minf(target.size.x/source_size.x,target.size.y/source_size.y)
	var center := target.get_center()
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
		points.append(center+(corner*draw_size).rotated(rotation))
	return _draw_prop_quad(prop_id,points,fraction)

func _draw_environment() -> void:
	if support_level != 5:
		return
	var word := str(entry.get("spelling_display",""))
	if word == "hello":
		if not _draw_prop_rect("greeting_door",Rect2(925,38,62,160)):
			draw_rect(Rect2(939,38,43,160),Color("cbd7c0"),true)
			draw_rect(Rect2(943,42,35,153),Style.SAGE,false,3)
			draw_circle(Vector2(950,127),3,Style.GOLD)
	elif word == "book":
		# Keep the complete table above the letter-label row, with the book on top.
		if not _draw_prop_rect("reading_table",Rect2(351,187,220,27),0.0,true):
			draw_rect(Rect2(351,191,220,9),Color("bca582"))
			draw_line(Vector2(367,199),Vector2(367,214),Style.MUTED,4)
			draw_line(Vector2(554,199),Vector2(554,214),Style.MUTED,4)
	elif word == "football":
		draw_line(Vector2(25,204),Vector2(975,204),Color("92af86"),5)
		if frame_positions.has(8):
			if not _draw_prop_rect("football_goal_frame",Rect2(925,140,60,62),0.0,true):
				for x: int in range(935,985,12): draw_line(Vector2(x,142),Vector2(x,201),Color("bac8b3"),1)
				for y: int in range(151,202,12): draw_line(Vector2(927,y),Vector2(984,y),Color("bac8b3"),1)
				draw_rect(Rect2(925,140,60,62),Color("f8f5e8"),false,3)

func _draw_semantic_effects(foreground: bool) -> void:
	var event := _current_event()
	if event.is_empty() or support_level == 3:
		return
	var kind := str(event.action_kind)
	var actor := _base_point(int(event.actor_position))
	var prop := _prop_state()
	var point: Vector2 = prop.position
	var pulse := sin(phase*PI)
	if not foreground:
		if kind in ["lantern_welcome","lantern_pass","goal_near","goal_far","light"]:
			var end := Vector2(958,185) if kind != "light" else Vector2(point.x+85,195)
			draw_colored_polygon(PackedVector2Array([actor+Vector2(0,20),end+Vector2(0,-58),end+Vector2(0,14)]),Color(0.98,0.82,0.35,0.15+0.36*phase))
		if kind == "egg_greet":
			if not _draw_prop_rect("greeting_window",Rect2(actor.x-70,44,140,107),0.0,true):
				draw_rect(Rect2(actor.x-70,44,140,107),Color("f8edd4"))
				draw_rect(Rect2(actor.x-70,44,140,107),Style.GOLD,false,4)
		return
	match kind:
		"hat_greet":
			if phase>0.3: _speech(actor+Vector2(55,-35),"你好",phase)
		"egg_greet":
			if phase>0.22: _speech(actor+Vector2(54,-34),"你好",phase)
			# The lower painted sill stays in front of the emerging egg.
			if not _draw_prop_rect("greeting_window",Rect2(actor.x-70,131.74,140,19.26),0.0,true,Rect2(0,0.82,1,0.18)):
				draw_line(Vector2(actor.x-77,150),Vector2(actor.x+77,150),Style.GOLD,7)
		"lantern_welcome","lantern_pass":
			var start := actor+Vector2(20,32)
			var end := Vector2(960,160)
			draw_circle(start.lerp(end,phase),10,Color("edc868"))
		"owl_greet":
			if not _draw_owl_wings(int(event.actor_position),pulse):
				var spread := 22+32*pulse
				draw_line(actor+Vector2(-36,13),actor+Vector2(-spread-32,-24*pulse),Color("9f8466"),12,true)
				draw_line(actor+Vector2(36,13),actor+Vector2(spread+32,-24*pulse),Color("9f8466"),12,true)
			if phase>0.3: _speech(actor+Vector2(60,-42),"你好",phase)
		"nose_lift":
			var owl_pose := _actor_pose(int(event.actor_position))
			var owl: Vector2 = owl_pose.center
			var star: Vector2 = _actor_pose(3).center
			var upper := owl+Vector2(26,13)
			var lower := owl+Vector2(29,29)
			var initial_tip := owl+Vector2(48,10)
			var owl_texture: Texture2D = _textures.get(int(event.actor_position))
			if owl_texture != null and str(owl_texture.get_meta("source_art_path", "")) == "res://assets/learning/storybook_v1/O.png":
				# The painted owl's beak is central and above the sprite origin.
				# Keep legacy SVG anchors when the PNG loader falls back.
				upper = owl+(Vector2(2,-8)*float(owl_pose.scale)).rotated(float(owl_pose.rotation))
				lower = owl+(Vector2(3,-1)*float(owl_pose.scale)).rotated(float(owl_pose.rotation))
				initial_tip = owl+(Vector2(19,-3)*float(owl_pose.scale)).rotated(float(owl_pose.rotation))
			var nose_end := initial_tip.lerp(star+Vector2(0,40),clampf(phase/0.22,0.0,1.0))
			draw_colored_polygon(PackedVector2Array([upper,nose_end,lower]),Color("d9ac82"))
		"sneeze_star":
			for i: int in range(3):
				var from := Vector2(405,110+i*13)
				draw_line(from,from+Vector2(155*phase,-18),Color(0.53,0.68,0.68,0.9),3,true)
			_text("阿嚏！",Vector2(345,45),20,Style.CORAL)
		"shell_catch":
			if phase>0.25:
				draw_arc(actor+Vector2(9,23),13,0.6,2.6,16,Style.CORAL,3,true)
				draw_circle(actor+Vector2(16,28),3,Style.CORAL)
		"boat_book","book_open","book_page","kite_book":
			_draw_book(point,float(prop.openness),sin(phase*PI) if kind=="book_page" else 0.0,phase if kind=="book_page" else -1.0)
			if kind == "kite_book":
				draw_line(actor+Vector2(-24,-25),point+Vector2(-35,-18),Style.MUTED,2,true)
				draw_line(actor+Vector2(24,-25),point+Vector2(35,-18),Style.MUTED,2,true)
		"ball_kick","ball_chest","ball_pass","train_ball","boat_ball","apple_kick","goal_near","goal_far":
			_draw_ball(point,float(prop.rotation))
			if kind=="goal_far" and phase>0.8: _text("进门啦",Vector2(884,122),18,Style.SAGE)
		_:
			_draw_generic_effect(kind,actor,prop)

func _draw_owl_wings(position: int, pulse: float) -> bool:
	if _prop_texture("owl_wing") == null:
		return false
	var pose := _actor_pose(position)
	var center: Vector2 = pose.center
	for side: float in [-1.0,1.0]:
		var joint := Vector2(side*31.0,13.0)
		var points := PackedVector2Array()
		for corner: Vector2 in [Vector2(0,-9),Vector2(58,-9),Vector2(58,15),Vector2(0,15)]:
			var local := corner.rotated(0.15-0.70*pulse)
			local.x *= side
			points.append(center+((joint+local)*float(pose.scale)).rotated(float(pose.rotation)))
		_draw_prop_quad("owl_wing",points)
	return true

func _draw_book(center: Vector2, openness: float, turning: float, page_phase: float = -1.0) -> void:
	var half := 23+24*openness
	# A real cover and page each use their own changing quad, not a flat book card.
	var base_texture := _prop_texture("book_open_base")
	var cover_texture := _prop_texture("book_cover")
	var page_texture := _prop_texture("book_page_leaf")
	if base_texture != null and cover_texture != null and page_texture != null:
		_draw_prop_rect("book_open_base",Rect2(center-Vector2(half+3,24),Vector2(half*2+6,48)),0.0,true)
		if openness < 0.999:
			_draw_prop_quad("book_cover",PackedVector2Array([center+Vector2(-half,-21),center+Vector2(half*(1.0-openness*2),-21-15*openness),center+Vector2(half*(1.0-openness*2),22-15*openness),center+Vector2(-half,22)]))
		if page_phase >= 0.0:
			var page_x := half*cos(page_phase*PI)
			if absf(page_x) < 0.6:
				page_x = -0.6 if page_phase >= 0.5 else 0.6
			var arch := sin(page_phase*PI)
			_draw_prop_quad("book_page_leaf",PackedVector2Array([center+Vector2(0,-14),center+Vector2(page_x,-18-22*arch),center+Vector2(page_x,19-6*arch),center+Vector2(0,21)]))
		return
	draw_rect(Rect2(center-Vector2(half+3,24),Vector2(half*2+6,48)),Color("b27b67"),true)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-half,-19),center+Vector2(0,-14),center+Vector2(0,21),center+Vector2(-half,16)]),Color("faf0d4"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-14),center+Vector2(half,-19),center+Vector2(half,16),center+Vector2(0,21)]),Color("fff8e8"))
	draw_line(center+Vector2(0,-14),center+Vector2(0,21),Style.GOLD,2)
	for i: int in range(3):
		draw_line(center+Vector2(6,-8+i*8),center+Vector2(half-6,-11+i*8),Color("a1b8a1"),2)
	if openness < 0.97:
		draw_colored_polygon(PackedVector2Array([center+Vector2(-half,-21),center+Vector2(half*(1.0-openness*2),-21-15*openness),center+Vector2(half*(1.0-openness*2),22-15*openness),center+Vector2(-half,22)]),Color("c99b78"))
	if turning>0.05:
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-14),center+Vector2(half*(1.0-turning*2),-36*turning-14),center+Vector2(half*(1.0-turning*2),-36*turning+19),center+Vector2(0,21)]),Color("e7dfbe"))

func _draw_ball(center: Vector2, rotation: float) -> void:
	if _draw_prop_rect("football",Rect2(center-Vector2(18,18),Vector2(36,36)),rotation):
		return
	draw_circle(center,18,Color("fff9e9"))
	draw_arc(center,18,0,TAU,28,Style.MUTED,2,true)
	var points := PackedVector2Array()
	for i: int in range(5):
		var angle := rotation+TAU*float(i)/5.0
		points.append(center+Vector2(cos(angle),sin(angle))*7)
	draw_colored_polygon(points,Style.SAGE)

func _speech(point: Vector2, text: String, amount: float) -> void:
	var alpha := clampf(amount*2,0,1)
	draw_style_box(Style.box(Color(1,0.98,0.90,alpha),12,0),Rect2(point,Vector2(63,34)))
	_text(text,point+Vector2(12,24),18,Style.INK)

func _draw_generic_effect(kind: String, actor: Vector2, prop: Dictionary) -> void:
	var point: Vector2 = prop.position
	if kind == "known_position":
		return
	if kind == "greet":
		# Generic speech keeps the actual meaning label; only hello says 你好.
		draw_arc(actor+Vector2(53,-27),18,-0.6,0.6,16,Style.GOLD,2,true)
	if kind == "open":
		var source := str(_current_event().get("source_action", ""))
		if source.contains("书"):
			_draw_book(point,float(prop.openness),0)
			return
	var illustrated := _draw_semantic_prop(point, float(prop.rotation))
	if not illustrated:
		# Abstract meanings and a missing art file remain explicit runtime text.
		# Diagnostics distinguish these states; a fallback is never counted as art.
		draw_style_box(Style.box(Color("faf1d5"),8,0),Rect2(point-Vector2(52,19),Vector2(104,38)))
		var meaning := str(entry.get("meaning_zh",""))
		if meaning.length()>8: meaning = meaning.left(8)+"…"
		_text(meaning,point+Vector2(-42,7),16,Style.INK)
	if kind == "open" and not illustrated:
		var cover_width := 104.0*(1.0-float(prop.openness))
		draw_rect(Rect2(point-Vector2(52,19),Vector2(cover_width,38)),Color("c8d6b6"),true)
	if kind == "tap":
		for i: int in range(3):
			draw_arc(point,23+10*i,PI,TAU,20,Color(0.75,0.52,0.29,sin(phase*PI)),2,true)
	elif kind == "mark":
		draw_line(point+Vector2(-35,11),point+Vector2(-35+70*phase,11),Style.CORAL,3,true)
	elif kind == "present" and not semantic_art_resolution().has("count"):
		draw_arc(point,58,-PI*0.15,-PI*0.15+TAU*phase,48,Style.GOLD,3,true)
	_draw_drumstick(kind,actor,point)

func _draw_semantic_prop(point: Vector2, rotation_value: float) -> bool:
	var resolution := semantic_art_resolution()
	var prop_id := str(resolution.get("prop_id", ""))
	if prop_id.is_empty():
		return false
	if resolution.has("count"):
		return _draw_counted_props(prop_id, point, resolution)
	var is_text_surface := str(resolution.get("status", "")) == "text_surface"
	var target := Rect2(point-Vector2(48,72),Vector2(96,72))
	if prop_id == "violin":
		target = Rect2(point-Vector2(48,96),Vector2(96,96))
	if is_text_surface:
		target = Rect2(point-Vector2(65,49),Vector2(130,51))
	if not _draw_prop_rect(prop_id,target,rotation_value if not is_text_surface else 0.0):
		return false
	if prop_id == "violin":
		_draw_violin_strings(target,rotation_value)
	if is_text_surface:
		var label := str(resolution.get("label", entry.get("meaning_zh", "")))
		if label.length()>7: label=label.left(7)+"…"
		_text(label,point+Vector2(-48,-19),14,Style.INK)
	return true

func _draw_violin_strings(target: Rect2, rotation_value: float) -> void:
	# The generated body deliberately has no strings. These four functional
	# lines preserve the exact anatomy while source PNG pixels remain unchanged.
	var source: Array = _prop_source_regions.get("violin", [])
	if source.size() != 4:
		return
	var source_size := Vector2(float(source[2]),float(source[3]))
	var draw_size := source_size*minf(target.size.x/source_size.x,target.size.y/source_size.y)
	var center := target.get_center()
	var parts: Array = []
	for index: int in range(4):
		var x := 0.44+float(index)*0.04
		var top := center+((Vector2(x,0.195)-Vector2(0.5,0.5))*draw_size).rotated(rotation_value)
		var bottom := center+((Vector2(x,0.765)-Vector2(0.5,0.5))*draw_size).rotated(rotation_value)
		draw_line(top,bottom,Color("554635"),1.05,true)
		draw_line(top,bottom,Color("f8e9c8"),0.55,true)
		parts.append({"start":[top.x,top.y],"end":[bottom.x,bottom.y]})
	_drawn_runtime_parts["violin_strings"] = parts

func _draw_counted_props(prop_id: String, point: Vector2, resolution: Dictionary) -> bool:
	# Counts describe visible instances, never baked numerals or guessed image counts.
	var count := maxi(0, int(resolution.get("count", 1)))
	var group_size := int(resolution.get("group_size", 0))
	var center := Vector2(clampf(point.x, 160.0, 850.0), 200.0)
	if count == 0:
		var slots := int(resolution.get("empty_slots", 0))
		for index: int in range(slots):
			draw_style_box(Style.box(Color("faf1d5"), 5, 1), Rect2(center+Vector2((index-(slots-1)*0.5)*24.0-10.0, -44), Vector2(20, 24)))
		return true
	if _prop_texture(prop_id) == null:
		return false
	if group_size > 0:
		var groups := ceili(float(count)/float(group_size))
		for index: int in range(count):
			var group := index / group_size
			var inside := index % group_size
			var x := center.x+(float(group)-(groups-1)*0.5)*48.0+(inside-4.5)*3.8
			_draw_prop_rect(prop_id, Rect2(Vector2(x-1.7,center.y-57.0),Vector2(3.4,43.0)))
		for group: int in range(groups):
			var x := center.x+(group-(groups-1)*0.5)*48.0
			draw_line(Vector2(x-19,center.y-31),Vector2(x+19,center.y-31),Style.CORAL,2.0,true)
		_text("%d × %d = %d" % [groups,group_size,count],center+Vector2(-43,3),14,Style.INK)
		return true
	var columns := int(resolution.get("columns", 0))
	if columns <= 0: columns = mini(count, 5)
	var rows := ceili(float(count)/float(columns))
	var cell := Vector2(40,36) if rows == 1 else Vector2(32,25 if rows <= 3 else 20)
	var origin := center-Vector2(columns*cell.x*0.5,rows*cell.y+14)
	for index: int in range(count):
		var grid := Vector2(index % columns, index / columns)
		_draw_prop_rect(prop_id, Rect2(origin+grid*cell+Vector2(2,2),cell-Vector2(4,4)))
	_text(str(count),center+Vector2(-6,3),14,Style.INK)
	return true

func _draw_drumstick(kind: String, actor: Vector2, point: Vector2) -> void:
	var source := str(_current_event().get("source_action", ""))
	var word := str(entry.get("spelling_display", ""))
	if word == "dog" and source.contains("鼓槌"):
		var center := (actor+Vector2(35,10)).lerp(point+Vector2(0,-20),phase)+Vector2(0,-45*sin(phase*PI))
		_draw_prop_rect("drumstick",Rect2(center-Vector2(30,6),Vector2(60,12)),phase*PI)
	elif word == "wood" and source.contains("鼓棒") and kind == "tap":
		var swing := -0.8+0.8*sin(phase*PI)
		var contact := point+Vector2(0,-21)
		var center := contact-Vector2(30,0).rotated(swing)
		_draw_prop_rect("drumstick",Rect2(center-Vector2(30,6),Vector2(60,12)),swing)
