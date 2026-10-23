extends SceneTree
## Focused regression for the B/O/K presentation-only PNG override.
const Content = preload("res://ui/memory_story_content.gd")
const Story = preload("res://ui/memory_story.gd")
const Prologue = preload("res://ui/prologue_activity.gd")
const Sink = preload("res://scripts/memory_event_sink.gd")
const LETTERS := ["B", "O", "K"]
const ART_ROOT := "res://assets/learning/storybook_v1/"
const BASE_CONTENT_REVISION := "vocabulary-75cc8eb5b90ed004"
const BASE_CODEBOOK_REVISION := "codebook-7976c505db8c0ea5"
const BASE_CATALOG_SHA256 := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const BASE_PROLOGUE_SHA256 := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"
var checks: Array = []
var failures: Array[String] = []
var asset_evidence: Array = []
var animation_frames: Array = []
var captures: Array = []
var actual_button_clicks: Array = []
var restoration: Dictionary = {}
var capture_enabled := false
var requested_size := Vector2i(1440,900)
var output := ""
var image_output := ""
var host: Control
var view: Control
var state: Node
var sink: RefCounted
var invocation := ""
var book: Dictionary
var context: Dictionary
var production_hash := ""
var backup_hash := ""
var source_png: Dictionary = {}
var book_page_rois: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	capture_enabled = OS.get_cmdline_user_args().has("--capture")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--art-width="): requested_size.x = argument.trim_prefix("--art-width=").to_int()
		if argument.begins_with("--art-height="): requested_size.y = argument.trim_prefix("--art-height=").to_int()
	output = ProjectSettings.globalize_path("res://../docs/verification/art-refresh-v1")
	image_output = ProjectSettings.globalize_path("res://../docs/screenshots/art-refresh-v1/%dx%d" % [requested_size.x,requested_size.y])
	DirAccess.make_dir_recursive_absolute(output)
	if capture_enabled: DirAccess.make_dir_recursive_absolute(image_output)
	production_hash = _hash("user://island-save-v1.json")
	backup_hash = _hash("user://island-save-v1.json.bak")
	root.size = requested_size
	await _ticks(3)
	if capture_enabled:
		_check(root.size==requested_size and DisplayServer.window_get_size()==requested_size,"Native engine window uses the requested physical size")
	state = root.get_node("State")
	# This focused script does not instantiate main.tscn, whose harness normally
	# redirects State. Set an isolated path before any mutable State call.
	state.save_path = "user://validation-art-refresh-%d.json" % OS.get_process_id()
	var isolated := str(state.save_path)=="user://validation-art-refresh-%d.json" % OS.get_process_id()
	_check(isolated,"State writes only an isolated validation save")
	if not isolated:
		await _finish()
		return
	state.data = state._default_state()
	_check(_hash("res://data/learning/catalog.json")==BASE_CATALOG_SHA256,"Entire pre-art curriculum catalog is byte-identical")
	_check(_hash("res://data/learning/prologue.json")==BASE_PROLOGUE_SHA256,"Pre-art prologue content and letter coding are byte-identical")
	var catalog := Content.load_catalog()
	_check(str(catalog.content_revision)==BASE_CONTENT_REVISION and str(catalog.codebook_revision)==BASE_CODEBOOK_REVISION,"Learning content and codebook revisions retain pre-art values")
	_check(Content.STORY_ART_REVISION=="storybook-v1","Artwork has an independent presentation revision")
	await _check_png_assets()
	if not failures.is_empty():
		await _finish()
		return
	_check_missing_override_fallback()
	host = Control.new()
	host.position = Vector2(70,40)
	host.size = Vector2(1300,820)
	root.add_child(host)
	book = Content.get_entry("occ-5605ac34c5f2")
	context = {"book_id":str(book.source_unit.book_id),"unit_id":str(book.source_unit.unit_ids[0]),"story_step_id":"art-refresh/book","task_mode":"meaning_to_spelling","target_dimension":"orthography","declared_stimulus":"written_meaning: 书","answer_visible_at_start":true}
	await _check_old_revision_fixture()
	if not await _open_saved_book():
		await _finish()
		return
	await _check_book_playback()
	if not await _check_live_pause_and_reload():
		await _finish()
		return
	await _check_hidden_resources()
	await _check_shared_views()
	_check(_hash("res://data/learning/catalog.json")==BASE_CATALOG_SHA256 and _hash("res://data/learning/prologue.json")==BASE_PROLOGUE_SHA256,"Validation did not rewrite curriculum data")
	await _finish()

func _check_png_assets() -> void:
	Content._icon_cache.clear()
	for letter: String in LETTERS:
		var path := ART_ROOT+letter+".png"
		_check(Content.icon_asset_path(letter)==path,"Configured generated PNG path: "+letter)
		_check(FileAccess.file_exists(path) and ResourceLoader.exists(path),"PNG exists and is imported as a runtime resource: "+letter)
		if not FileAccess.file_exists(path) or not ResourceLoader.exists(path): continue
		var original := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(original!=null and not original.is_empty(),"Independent decoder reads source PNG: "+letter)
		if original==null or original.is_empty(): continue
		original.convert(Image.FORMAT_RGBA8)
		_check(original.get_width()==original.get_height() and original.get_width()>=512,"Art is a square master of at least 512 pixels: "+letter)
		_check(_visible_pixel_count(original)>1000,"PNG is not entirely transparent: "+letter)
		_check(original.get_pixel(0,0).a<0.02 and original.get_pixel(original.get_width()-1,0).a<0.02 and original.get_pixel(0,original.get_height()-1).a<0.02 and original.get_pixel(original.get_width()-1,original.get_height()-1).a<0.02,"PNG corners have transparent alpha: "+letter)
		source_png[letter] = original
		var native_scale := float(original.get_width())/160.0
		var texture: Texture2D = Content.icon(letter,native_scale)
		var actual := _texture_image(texture)
		_check(actual!=null and _same_visible_pixels(actual,original),"Actual Content.icon texture preserves every source alpha and all nonzero-alpha RGB pixels at native size: "+letter)
		for scale_value: float in [1.0,2.0,3.0]:
			var scaled: Texture2D = Content.icon(letter,scale_value)
			var expected_size := roundi(160.0*scale_value)
			_check(scaled!=null and scaled.get_size()==Vector2(expected_size,expected_size),"Existing icon scale contract preserved: %s/%s" % [letter,scale_value])
			_check(_normalized_difference(_texture_image(scaled),original)<0.04,"Scaled actual texture retains PNG appearance: %s/%s" % [letter,scale_value])
		var old := _svg_image(letter,native_scale)
		_check(actual!=null and not _same_pixels(actual,old),"PNG verification cannot silently pass through legacy SVG: "+letter)
		asset_evidence.append({"letter":letter,"path":path,"file_sha256":_hash(path),"source_size":[original.get_width(),original.get_height()],"actual_pixel_sha256":_image_hash(actual),"source_pixel_sha256":_image_hash(original),"actual_visible_pixel_sha256":_visible_pixel_hash(actual),"source_visible_pixel_sha256":_visible_pixel_hash(original),"pixel_differences":_pixel_difference_summary(actual,original),"transparent_rgb_policy":"Only RGB of fully transparent alpha-zero pixels is normalized; every alpha byte and all RGB at nonzero alpha remain exact.","legacy_svg_pixel_sha256":_image_hash(old)})
		await process_frame

func _check_missing_override_fallback() -> void:
	var configured: String = str(Content._icon_overrides.B)
	var warm: Texture2D = Content.icon("B",1.0)
	Content._icon_overrides.B = "res://assets/learning/storybook_v1/absent-validation-fixture.png"
	var fallback: Texture2D = Content.icon("B",1.0)
	_check(fallback!=null and _same_pixels(_texture_image(fallback),_svg_image("B",1.0)),"A configured but missing B PNG safely decodes its original embedded SVG")
	_check(fallback!=warm and not _same_pixels(_texture_image(fallback),_texture_image(warm)),"Warm PNG cache cannot mask a missing override path")
	Content._icon_overrides.B = configured
	_check(_same_pixels(_texture_image(Content.icon("B",1.0)),_texture_image(warm)),"Restoring only the in-process path restores the generated B icon")
	_check(_same_pixels(_texture_image(Content.icon("A",1.0)),_svg_image("A",1.0)),"Unchanged A continues to use the original SVG")
	Content._icon_cache.clear()

func _check_old_revision_fixture() -> void:
	# Fixed pre-art revision values, not a fresh snapshot from the PNG implementation.
	var old := {"entry_id":"occ-5605ac34c5f2","content_revision":BASE_CONTENT_REVISION,"codebook_revision":BASE_CODEBOOK_REVISION,
		"invocation_id":"pre-art-book-fixture","attempt_id":"pre-art-book-fixture/attempt-1","current_beat":1,"support_level":3,"max_help_level":5,"revealed_gaps":[2],
		"first_response":{"correct":false,"response_text":"bok"},"later_response":{"correct":true,"response_text":"book"},"draft_response":"book",
		"animation_state":{"schema_version":1,"stage_revision":"memory-stage-v1","beat_id":str(book.story_beats[0].beat_id),"step_position":2,"phase":0.42,"playback_status":"playing","reduced_motion":false}}
	view = Story.new()
	host.add_child(view)
	view.setup(book,old)
	await _ticks(8)
	_check(not view._content_unavailable and view.support_level==3 and view.max_help_level==5,"Fixed pre-art revision fixture opens without replacing learning content")
	_check(not bool(view.first_response.correct) and bool(view.later_response.correct) and view.draft_response=="book","Pre-art first error, later correct response and draft survive")
	_check(view._story_player.visible_letter_positions()==[1,2,3] and view._revealed_gaps==[2],"Pre-art revealed gap survives PNG refresh")
	_check(view._story_player.snapshot().step_position==2 and is_equal_approx(view._story_player.phase,0.42) and view._story_player.playback_status=="paused","Pre-art animation restores the same position/phase and opens paused")
	var wrong: Dictionary = old.duplicate(true)
	wrong.content_revision = "unsupported-other-content-version"
	view.setup(book,wrong)
	await _ticks(6)
	_check(view._content_unavailable and not is_instance_valid(view._story_player),"Unrelated content-version mismatch is still rejected")
	view.queue_free()
	await process_frame

func _open_saved_book() -> bool:
	var opened: Dictionary = state.journey_begin_memory(book,context)
	_check(bool(opened.get("ok",false)),"Actual State accepts the unchanged book session")
	if not opened.get("ok",false): return false
	invocation = str(opened.invocation_id)
	sink = Sink.new()
	var sink_ready: bool = sink.setup(state,invocation)
	_check(sink_ready,"Production event sink owns the test session")
	if not sink_ready: return false
	view = Story.new()
	host.add_child(view)
	view.help_shown.connect(func(event: Dictionary): _check(sink.enqueue("cue",event),"Displayed cue persists"))
	view.progress_changed.connect(func(progress: Dictionary): _check(sink.enqueue("progress",progress),"Visible progress persists"))
	view.response_submitted.connect(func(response: Dictionary): _check(sink.enqueue("response",response),"Actual response persists"))
	view.setup(book,opened.resume_state)
	await _ticks(8)
	return true

func _check_book_playback() -> void:
	var player: Control = view._story_player
	_check(player.allowed_positions==[1,2,3,4] and player._textures.keys()==[1,2,3,4],"Book constructs four independently positioned actors")
	_check(str(book.letter_slots[1].letter)=="O" and str(book.letter_slots[2].letter)=="O" and int(book.letter_slots[1].occurrence)==1 and int(book.letter_slots[2].occurrence)==2,"Both O occurrences keep separate source positions")
	for position: int in [1,2,3,4]:
		var letter := str(book.letter_slots[position-1].letter)
		_check(_normalized_difference(_texture_image(player._textures[position]),source_png[letter])<0.04,"Real stage texture uses generated asset at position "+str(position))
	var sampled: Dictionary = {}
	var poses: Dictionary = {}
	await _click(view,"播放故事")
	for tick: int in range(1800):
		await process_frame
		var position := int(player._current_event().actor_position)
		for sample: int in range(3):
			var key := "%d/%d" % [position,sample]
			if player.phase>=[0.08,0.50,0.94][sample] and not sampled.has(key):
				sampled[key] = true
				var visual: Dictionary = player.visual_state()
				poses[key] = visual
				animation_frames.append({"position":position,"sample":sample,"phase":player.phase,"action":player._current_event().action_kind,"owl_2":_v2(visual.actors["2"].center),"owl_3":_v2(visual.actors["3"].center),"book_position":_v2(visual.prop.position),"book_openness":visual.prop.openness})
				await _capture("book-position%d-%d.png" % [position,sample],position==3,sample)
		if player.playback_status!="playing": break
	_check(player.playback_status=="completed" and sampled.size()==12,"All four real actions finish with three samples each")
	if poses.has("2/0") and poses.has("2/2"):
		_check(float(poses["2/2"].prop.openness)-float(poses["2/0"].prop.openness)>0.75,"First O actually opens the book cover")
	if poses.has("3/0") and poses.has("3/1"):
		_check(float(poses["3/0"].actors["3"].center.x)-float(poses["3/1"].actors["3"].center.x)>80,"Second O physically approaches the book to turn its page")
		_check(poses["3/0"].actors["2"].center==poses["3/1"].actors["2"].center,"First O stays independently positioned during second O's action")
	if capture_enabled:
		_check(book_page_rois.has(1) and book_page_rois.has(2) and str(book_page_rois.get(1,""))!=str(book_page_rois.get(2,"")),"Native book-page-only pixels differ between middle and final turning poses")
	var session: Dictionary = state.journey_snapshot().memory.sessions[invocation]
	var cues: Array = session.cue_events.filter(func(event: Dictionary): return str(event.get("display_event",""))=="story_animation_step")
	_check(cues.map(func(event: Dictionary): return int(event.animated_letter_position))==[1,2,3,4],"Authoritative animation cues retain both distinct O positions in sequence")
	_check(cues.size()>=3 and cues[1].animation_action=="book_open" and cues[2].animation_action=="book_page","Recorded O actions remain opening then page turning")

func _check_live_pause_and_reload() -> bool:
	await _click(view,"再看一次")
	await _ticks(30)
	await _click(view,"暂停")
	var saved: Dictionary = view.get_resume()
	_check(sink.close("paused"),"Art-enabled session closes to the real validation save")
	view.queue_free()
	await process_frame
	state.load_state()
	if not await _open_saved_book(): return false
	var restored: Dictionary = view.get_resume()
	_check(restored.content_revision==BASE_CONTENT_REVISION and restored.codebook_revision==BASE_CODEBOOK_REVISION,"Saved session retains pre-art learning revisions after disk reload")
	_check(restored.invocation_id==saved.invocation_id and restored.animation_state.step_position==saved.animation_state.step_position and is_equal_approx(float(restored.animation_state.phase),float(saved.animation_state.phase)),"Actual persisted animation position and phase survive PNG-enabled reload")
	_check(restored.animation_state.playback_status=="paused","Reload never autoplays past saved evidence")
	restoration = {"saved":saved.animation_state,"restored":restored.animation_state,"content_revision":restored.content_revision,"codebook_revision":restored.codebook_revision,"same_invocation":restored.invocation_id==saved.invocation_id}
	await _capture("book-restored-paused.png")
	return true

func _check_hidden_resources() -> void:
	Content._icon_cache.clear()
	await _click(view,"一起补空格")
	var player: Control = view._story_player
	_check(player._textures.keys()==[1,3] and player.visible_letter_positions()==[1,3],"H3 creates only positions 1 and 3, including only the visible O occurrence")
	_check(not _cache_has_letter("K"),"Unrevealed fourth-position K was not loaded into the icon cache")
	_check(not _all_text(view).contains("风筝") and not _all_text(view).contains(str(book.steps[1].action)),"H3 prose does not leak the hidden K or first O action")
	await _click(view,"播放故事")
	await _ticks(25)
	await _click(view,"暂停")
	var session: Dictionary = state.journey_snapshot().memory.sessions[invocation]
	var last: Dictionary = session.cue_events[-1]
	_check(last.revealed_letter_positions==[1,3] and str(last.get("animation_action",""))=="known_position","H3 actual playback records only visible letter positions")
	await _capture("book-h3-hidden-o-k.png")
	view._reveal_gap(2)
	await _ticks(6)
	_check(view._story_player._textures.keys()==[1,2,3] and not _cache_has_letter("K"),"Revealing O adds exactly position 2 without loading hidden K")
	view._reveal_gap(4)
	await _ticks(6)
	_check(view._story_player._textures.keys()==[1,2,3,4] and _cache_has_letter("K"),"Explicit K reveal is the first point that loads its PNG")
	for caption: String in ["自己想一想","想想它住哪里"]:
		Content._icon_cache.clear()
		await _click(view,caption)
		_check(not is_instance_valid(view._story_player) and Content._icon_cache.is_empty(),"No stage or new letter image request at "+caption)
		_check(not _all_text(view).contains("book"),"No target spelling leaked at "+caption)
		_check(state.journey_snapshot().memory.sessions[invocation].cue_events[-1].revealed_letter_positions.is_empty(),"No invented visual cue at "+caption)

func _check_shared_views() -> void:
	await _click(view,"一步一步接")
	await _click(view,str(Content.codebook_item("O").representative_label_zh))
	await _click(view,str(Content.codebook_item("O").representative_label_zh))
	var kite_button := _find_button(view,str(Content.codebook_item("K").representative_label_zh))
	_check(kite_button!=null and _normalized_difference(_texture_image(kite_button.icon),source_png.K)<0.04,"Actual H4 candidate Button shares the generated K image")
	_check(sink.close("paused"),"Shared-view preparation preserves the learning session")
	view.queue_free()
	await process_frame
	var prologue_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/prologue.json"))
	for letter: String in LETTERS:
		var record: Dictionary = {}
		for candidate: Dictionary in prologue_data.letters:
			if str(candidate.letter.uppercase)==letter: record=candidate; break
		var activity: Control = Prologue.new()
		activity.position = Vector2.ZERO
		activity.size = host.size
		host.add_child(activity)
		activity.setup(record,false)
		await _ticks(6)
		_check(_normalized_difference(_texture_image(activity.stage._texture(letter)),source_png[letter])<0.04,"P2 object stage retains the generated source image: "+letter)
		_check(activity.picture is TextureRect and activity.picture.texture.resource_path==str(activity.spec.world_view),"P2 glyph pane uses the captured authored model: "+letter)
		await _capture("prologue-%s.png" % letter)
		activity.queue_free()
		await process_frame

func _cache_has_letter(letter: String) -> bool:
	return Content._icon_cache.keys().any(func(key: Variant): return str(key).begins_with(letter+"@"))

func _texture_image(texture: Texture2D) -> Image:
	if texture==null: return null
	var result := texture.get_image()
	if result==null or result.is_empty(): return null
	if result.is_compressed(): result.decompress()
	result.clear_mipmaps()
	result.convert(Image.FORMAT_RGBA8)
	return result

func _svg_image(letter: String, scale_value: float) -> Image:
	var result := Image.new()
	result.load_svg_from_string(str(Content.codebook_item(letter).svg_source),scale_value)
	result.convert(Image.FORMAT_RGBA8)
	return result

func _same_pixels(first: Image, second: Image) -> bool:
	return first!=null and second!=null and first.get_size()==second.get_size() and first.get_data()==second.get_data()

func _visible_pixel_bytes(picture: Image) -> PackedByteArray:
	var pixels := picture.get_data()
	for index: int in range(0,pixels.size(),4):
		if pixels[index+3]==0:
			pixels[index]=0
			pixels[index+1]=0
			pixels[index+2]=0
	return pixels

func _pixel_difference_summary(first: Image, second: Image) -> Dictionary:
	if first==null or second==null or first.get_size()!=second.get_size():
		return {"size_mismatch":true,"actual_size":str(first.get_size()) if first!=null else "null"}
	var actual := first.get_data()
	var expected := second.get_data()
	var alpha_differences := 0
	var visible_rgb_differences := 0
	var transparent_rgb_differences := 0
	var alpha_range := [255,0]
	var max_rgb_delta := 0
	var examples: Array = []
	for index: int in range(0,actual.size(),4):
		if actual[index+3]!=expected[index+3]: alpha_differences+=1
		var rgb_diff := actual[index]!=expected[index] or actual[index+1]!=expected[index+1] or actual[index+2]!=expected[index+2]
		if not rgb_diff: continue
		if actual[index+3]==0 and expected[index+3]==0:
			transparent_rgb_differences+=1
			continue
		visible_rgb_differences+=1
		alpha_range[0]=mini(alpha_range[0],expected[index+3])
		alpha_range[1]=maxi(alpha_range[1],expected[index+3])
		for channel: int in range(3): max_rgb_delta=maxi(max_rgb_delta,absi(actual[index+channel]-expected[index+channel]))
		if examples.size()<6:
			examples.append({"pixel":index/4,"expected":[expected[index],expected[index+1],expected[index+2],expected[index+3]],"actual":[actual[index],actual[index+1],actual[index+2],actual[index+3]]})
	return {"alpha_different_pixels":alpha_differences,"visible_rgb_different_pixels":visible_rgb_differences,"transparent_rgb_different_pixels":transparent_rgb_differences,"visible_difference_alpha_range":alpha_range,"maximum_visible_rgb_byte_delta":max_rgb_delta,"examples":examples}

func _same_visible_pixels(first: Image, second: Image) -> bool:
	return first!=null and second!=null and first.get_size()==second.get_size() and _visible_pixel_bytes(first)==_visible_pixel_bytes(second)

func _visible_pixel_hash(picture: Image) -> String:
	if picture==null: return "unavailable"
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(_visible_pixel_bytes(picture))
	return hash_context.finish().hex_encode()

func _image_hash(picture: Image) -> String:
	if picture==null: return "unavailable"
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(picture.get_data())
	return hash_context.finish().hex_encode()

func _visible_pixel_count(picture: Image) -> int:
	var total := 0
	for y: int in range(picture.get_height()):
		for x: int in range(picture.get_width()):
			if picture.get_pixel(x,y).a>0.05: total+=1
	return total

func _normalized_difference(first: Image, second: Image) -> float:
	if first==null or second==null: return 1.0
	var left: Image = first.duplicate()
	var right: Image = second.duplicate()
	left.resize(32,32,Image.INTERPOLATE_LANCZOS)
	right.resize(32,32,Image.INTERPOLATE_LANCZOS)
	var error := 0.0
	for y: int in range(32):
		for x: int in range(32):
			var a := left.get_pixel(x,y)
			var b := right.get_pixel(x,y)
			error += absf(a.a-b.a)+absf(a.r*a.a-b.r*b.a)+absf(a.g*a.a-b.g*b.a)+absf(a.b*a.a-b.b*b.a)
	return error/4096.0

func _click(node: Node, caption: String) -> void:
	var button := _find_button(node,caption)
	_check(button!=null and not button.disabled,"Actual enabled UI button: "+caption)
	if button==null or button.disabled: return
	var ancestor: Node = button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await _ticks(4)
	var point := button.get_global_rect().get_center()
	var reachable := button.is_visible_in_tree() and Rect2(Vector2.ZERO,root.get_visible_rect().size).has_point(point)
	ancestor=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer and not ancestor.get_global_rect().has_point(point): reachable=false
		ancestor=ancestor.get_parent()
	_check(reachable,"Actual UI click is inside the visible viewport and scroll clips: "+caption)
	actual_button_clicks.append({"caption":caption,"position":[point.x,point.y],"reachable":reachable})
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
	await _ticks(6)
	if is_instance_valid(view) and is_instance_valid(view._story_player):
		view._scroll.ensure_control_visible(view._story_player)
		await _ticks(3)

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and str(node.text)==caption: return node
	for child: Node in node.get_children():
		var found := _find_button(child,caption)
		if found!=null: return found
	return null

func _all_text(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+=_all_text(child)
	return result

func _v2(value: Vector2) -> Array:
	return [value.x,value.y]

func _ticks(count: int) -> void:
	for index: int in range(count): await process_frame

func _capture(filename: String, page_roi: bool = false, sample: int = -1) -> void:
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := image_output.path_join(filename)
	_check(picture.save_png(path)==OK,"Native generated-art capture: "+filename)
	captures.append({"file":filename,"sha256":_hash(path),"image_size":[picture.get_width(),picture.get_height()]})
	if page_roi and is_instance_valid(view._story_player):
		var player: Control = view._story_player
		var rectangle: Rect2 = player.get_global_rect()
		var viewport_size := root.get_visible_rect().size
		var render_scale := Vector2(picture.get_width(),picture.get_height())/viewport_size
		var point := rectangle.position+Vector2(410.0/1000.0*rectangle.size.x,145.0/238.0*(rectangle.size.y-52.0))
		var dimensions := Vector2(35.0/1000.0*rectangle.size.x,35.0/238.0*(rectangle.size.y-52.0))
		var region := Rect2i(Vector2i(point*render_scale),Vector2i(dimensions*render_scale))
		book_page_rois[sample] = _image_hash(picture.get_region(region))

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(condition: bool, label: String) -> void:
	checks.append({"check":label,"passed":condition})
	if not condition:
		failures.append(label)
		push_error("ART_REFRESH_FAIL: "+label)

func _finish() -> void:
	_check(_hash("user://island-save-v1.json")==production_hash and _hash("user://island-save-v1.json.bak")==backup_hash,"Production save and backup are unchanged")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"check_details":checks,"assets":asset_evidence,"animation_frames":animation_frames,"book_page_roi_sha256":book_page_rois,"restoration":restoration,"captures":captures,"capture_enabled":capture_enabled,"requested_window":[requested_size.x,requested_size.y],"actual_root_window":[root.size.x,root.size.y],"actual_display_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"logical_viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"actual_button_clicks":actual_button_clicks,"production_save_and_backup_unchanged":_hash("user://island-save-v1.json")==production_hash and _hash("user://island-save-v1.json.bak")==backup_hash,
		"scope":"B/O/K actual generated-PNG texture pixels, SVG fallback under a missing configured path, book O instances and action semantics, hint resource boundaries, shared UI texture loading, fixed pre-art revisions and real isolated-save roundtrip. Native page ROI is checked only with --capture; no performance or learning-effect claim."}
	var filename := "%s-%dx%d-report.json" % ["native" if capture_enabled else "headless",requested_size.x,requested_size.y]
	var file := FileAccess.open(output.path_join(filename),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures,"captures":captures.size(),"animation_samples":animation_frames.size()}))
	if is_instance_valid(host): host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
