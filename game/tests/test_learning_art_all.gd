extends SceneTree
## Focused v2 learning-art integration. Historical v1 tests/reports remain unchanged.
const Content = preload("res://ui/memory_story_content.gd")
const Story = preload("res://ui/memory_story.gd")
const Prologue = preload("res://ui/prologue_activity.gd")
const Sink = preload("res://scripts/memory_event_sink.gd")
const Style = preload("res://ui/island_theme.gd")
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const MANIFEST := "res://../assets/art/storybook_v2/manifest.json"
const BASE_CONTENT_REVISION := "vocabulary-75cc8eb5b90ed004"
const BASE_CODEBOOK_REVISION := "codebook-7976c505db8c0ea5"
const BASE_CATALOG_SHA256 := "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
const BASE_PROLOGUE_SHA256 := "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"
const PROP_IDS := ["book_open_base","book_cover","book_page_leaf","football","greeting_door","greeting_window","reading_table","football_goal_frame","owl_wing","drumstick"]
const GENERIC_KINDS := ["light","open","roll","fly","tap","catch","lift","transport","mark","greet","place","travel","present"]
# Six real source words, 52 positions: A-Z and all 13 generic categories.
const GENERIC_ENTRIES := ["occ-47f1d225c68d","occ-76c657a2a492","occ-69213f605c59","occ-b5fc541d39f7","occ-f728e192d2e7","occ-2558defff075"]
var checks: Array = []
var failures: Array[String] = []
var assets: Array = []
var captures: Array = []
var generic_samples: Array = []
var prop_samples: Array = []
var ui_clicks: Array = []
var covered_letters: Dictionary = {}
var covered_kinds: Dictionary = {}
var drawn_props: Dictionary = {}
var incremental_props: Dictionary = {}
var expected_icons: Dictionary = {}
var prop_pixel_hashes: Dictionary = {}
var letter_items: Dictionary = {}
var prop_items: Dictionary = {}
var restoration: Dictionary = {}
var manifest: Dictionary = {}
var capture_enabled := false
var requested_size := Vector2i(1440,900)
var output := ""
var image_output := ""
var production_hash := ""
var backup_hash := ""
var host: Control
var view: Control
var state: Node
var sink: RefCounted
var invocation := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	capture_enabled = OS.get_cmdline_user_args().has("--capture")
	output=ProjectSettings.globalize_path("res://../docs/verification/art-refresh-all")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--art-width="): requested_size.x=argument.trim_prefix("--art-width=").to_int()
		if argument.begins_with("--art-height="): requested_size.y=argument.trim_prefix("--art-height=").to_int()
		if argument.begins_with("--report-dir="): output=argument.trim_prefix("--report-dir=")
	image_output=ProjectSettings.globalize_path("res://../docs/screenshots/art-refresh-all/%dx%d" % [requested_size.x,requested_size.y])
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): image_output=argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	if capture_enabled: DirAccess.make_dir_recursive_absolute(image_output)
	production_hash=_hash("user://island-save-v1.json")
	backup_hash=_hash("user://island-save-v1.json.bak")
	state=root.get_node("State")
	state.save_path="user://validation-learning-art-all-%d.json" % OS.get_process_id()
	var isolated: bool=str(state.save_path)=="user://validation-learning-art-all-%d.json" % OS.get_process_id()
	_check(isolated,"State is isolated before its first mutable call")
	if not isolated:
		await _finish()
		return
	state.data=state._default_state()
	root.size=requested_size
	await _ticks(3)
	if capture_enabled:
		_check(root.size==requested_size and DisplayServer.window_get_size()==requested_size,"Native window has the requested physical size")
	_check(_hash("res://data/learning/catalog.json")==BASE_CATALOG_SHA256,"Curriculum catalog retains its pre-art bytes")
	_check(_hash("res://data/learning/prologue.json")==BASE_PROLOGUE_SHA256,"Prologue content retains its pre-art bytes")
	var catalog: Dictionary=Content.load_catalog()
	_check(catalog.content_revision==BASE_CONTENT_REVISION and catalog.codebook_revision==BASE_CODEBOOK_REVISION,"Learning and codebook revisions are unchanged")
	_check(Content.STORY_ART_REVISION=="storybook-v2","Artwork revision is independent storybook-v2")
	if not _read_manifest():
		await _finish()
		return
	await _check_assets()
	if not failures.is_empty():
		await _finish()
		return
	_check_letter_fallbacks()
	host=Control.new()
	host.position=Vector2(70,40)
	host.size=Vector2(1300,820)
	host.theme=Style.make_theme()
	root.add_child(host)
	if capture_enabled and requested_size.x==1440: await _capture_alphabet_gallery()
	await _check_generic_stories()
	await _check_prop_stories()
	await _check_hints_and_state()
	await _check_shared_prologue()
	_check(_hash("res://data/learning/catalog.json")==BASE_CATALOG_SHA256 and _hash("res://data/learning/prologue.json")==BASE_PROLOGUE_SHA256,"Validation did not rewrite learning data")
	await _finish()

func _read_manifest() -> bool:
	_check(FileAccess.file_exists(MANIFEST),"v2 manifest exists")
	if not FileAccess.file_exists(MANIFEST): return false
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check(parsed is Dictionary,"Manifest decodes as a dictionary")
	if not parsed is Dictionary: return false
	manifest=parsed
	_check(str(manifest.get("art_revision",""))=="storybook-v2","Manifest identifies v2")
	for item: Dictionary in manifest.get("assets",[]):
		if str(item.get("kind",""))=="letter":
			var letter: String=str(item.get("letter",item.get("id","")))
			_check(not letter_items.has(letter),"Manifest has one letter item: "+letter)
			letter_items[letter]=item
		elif str(item.get("kind",""))=="prop":
			var prop_id: String=str(item.get("id",""))
			_check(not prop_items.has(prop_id),"Manifest has one prop item: "+prop_id)
			prop_items[prop_id]=item
	_check(_sorted_strings(letter_items.keys())==_sorted_strings(ALPHABET.split("")),"Manifest contains exactly A-Z")
	_check(_sorted_strings(prop_items.keys())==_sorted_strings(PROP_IDS),"Manifest contains the ten agreed story props")
	_check(_sorted_strings(manifest.get("letters",[]))==_sorted_strings(letter_items.keys()),"Manifest letter index agrees with its assets")
	_check(_sorted_strings(manifest.get("props",[]))==_sorted_strings(prop_items.keys()),"Manifest prop index agrees with its assets")
	return failures.is_empty()

func _check_assets() -> void:
	for item: Dictionary in manifest.assets:
		var id: String=str(item.id)
		var resource_path: String=_resource_path(str(item.runtime_path))
		var original_path: String=ProjectSettings.globalize_path(MANIFEST).get_base_dir().path_join(str(item.original_copy)).simplify_path()
		_check(not resource_path.is_empty() and FileAccess.file_exists(resource_path) and ResourceLoader.exists(resource_path,"Texture2D"),"Imported runtime PNG exists: "+id)
		_check(FileAccess.file_exists(original_path),"Preserved original source exists: "+id)
		if resource_path.is_empty() or not FileAccess.file_exists(original_path) or not ResourceLoader.exists(resource_path,"Texture2D"): continue
		_check(_hash(resource_path)==str(item.sha256) and _hash(original_path)==str(item.sha256),"Original, runtime copy and manifest SHA agree: "+id)
		var original: Image=Image.load_from_file(original_path)
		_check(original!=null and not original.is_empty(),"Independent source decoder reads: "+id)
		if original==null or original.is_empty(): continue
		original.convert(Image.FORMAT_RGBA8)
		_check(original.get_width()==int(item.size[0]) and original.get_height()==int(item.size[1]),"Manifest records actual PNG dimensions: "+id)
		if str(item.kind)=="letter":
			_check(original.get_width()==original.get_height() and original.get_width()>=512,"Square letter master is at least 512 pixels: "+id)
		var bounds: Array=item.get("alpha_bbox_128",[])
		_check(bounds.size()==4 and float(bounds[2])>float(bounds[0]) and float(bounds[3])>float(bounds[1]),"Manifest has a nonempty visible silhouette: "+id)
		_check(original.get_pixel(0,0).a<0.02 and original.get_pixel(original.get_width()-1,0).a<0.02 and original.get_pixel(0,original.get_height()-1).a<0.02 and original.get_pixel(original.get_width()-1,original.get_height()-1).a<0.02,"Source corners are transparent: "+id)
		var actual: Image
		if str(item.kind)=="letter":
			var letter: String=str(item.letter)
			_check(Content.icon_asset_path(letter)==resource_path,"Letter mapping selects its manifest PNG: "+letter)
			var expected_path: String="res://assets/learning/storybook_v1/"+letter+".png" if letter in ["B","O","K"] else "res://assets/learning/storybook_v2/"+letter+".png"
			_check(resource_path==expected_path,"Accepted B/O/K are reused; new letters use v2: "+letter)
			Content._icon_cache.clear()
			var texture: Texture2D=Content.icon(letter,float(original.get_width())/160.0)
			actual=_texture_image(texture)
			_check(texture!=null and str(texture.get_meta("source_art_path",""))==resource_path,"Loaded letter records its actual artwork source: "+letter)
			expected_icons[letter]={}
			for scale: int in [1,2,3]:
				var expected: Image=original.duplicate()
				expected.resize(160*scale,160*scale,Image.INTERPOLATE_LANCZOS)
				expected_icons[letter][str(scale)]=expected
				var scaled: Texture2D=Content.icon(letter,float(scale))
				_check(scaled!=null and scaled.get_size()==Vector2(160*scale,160*scale) and _same_pixels(_texture_image(scaled),expected),"Actual scaled letter pixels match independent PNG resize: %s/%d" % [letter,scale])
			Content._icon_cache.clear()
		else:
			var texture: Texture2D=load(resource_path) as Texture2D
			actual=_texture_image(texture)
			prop_pixel_hashes[id]=_image_hash(original)
		_check(_same_pixels(actual,original),"Every original RGBA byte survives native-size runtime loading: "+id)
		assets.append({"id":id,"kind":str(item.kind),"runtime_path":resource_path,"file_sha256":_hash(resource_path),"source_pixel_sha256":_image_hash(original),"actual_pixel_sha256":_image_hash(actual),"size":[original.get_width(),original.get_height()]})
		await process_frame

func _check_letter_fallbacks() -> void:
	for letter: String in ALPHABET:
		var configured: String=str(Content._icon_overrides[letter])
		var warm: Texture2D=Content.icon(letter,1.0)
		Content._icon_overrides[letter]="res://assets/learning/storybook_v2/missing-validation-"+letter+".png"
		var fallback: Texture2D=Content.icon(letter,1.0)
		_check(fallback!=null and _same_pixels(_texture_image(fallback),_svg_image(letter)),"Missing configured PNG falls back to that letter's source SVG: "+letter)
		_check(fallback!=warm and not _same_pixels(_texture_image(fallback),_texture_image(warm)),"Warm PNG cache cannot mask a missing path: "+letter)
		Content._icon_overrides[letter]=configured
		_check(_same_pixels(_texture_image(Content.icon(letter,1.0)),expected_icons[letter]["1"]),"Restored path recovers the original PNG: "+letter)
	Content._icon_cache.clear()

func _check_generic_stories() -> void:
	for entry_id: String in GENERIC_ENTRIES:
		var entry: Dictionary=Content.get_entry(entry_id)
		await _open_component(entry)
		for page: int in range(entry.story_beats.size()):
			var player: Control=view._story_player
			_check(is_instance_valid(player),"Generic source page constructs its actual stage: %s/%d" % [entry.spelling_display,page+1])
			if not is_instance_valid(player): break
			for position: Variant in player.allowed_positions:
				var letter: String=str(entry.letter_slots[int(position)-1].letter)
				covered_letters[letter]=true
				_check(player._textures.has(int(position)) and _same_pixels(_texture_image(player._textures[int(position)]),expected_icons[letter]["2"]),"Real generic-stage actor uses its source PNG: %s/%d" % [entry.spelling_display,position])
			for event: Dictionary in player.events.duplicate(true):
				var kind: String=str(event.action_kind)
				if not covered_kinds.has(kind):
					covered_kinds[kind]=true
					await _play_generic_sample(player,event,entry)
			await _capture("generic-%s-page%d.png" % [entry_id,page+1])
			if page+1<entry.story_beats.size(): await _click(view,"下一页")
		await _destroy_view()
	_check(_sorted_strings(covered_letters.keys())==_sorted_strings(ALPHABET.split("")),"Six real words cover all 26 actual letter actors")
	_check(_sorted_strings(covered_kinds.keys())==_sorted_strings(GENERIC_KINDS),"Six real words cover all 13 generic action categories")

func _play_generic_sample(player: Control, event: Dictionary, entry: Dictionary) -> void:
	var position: int=int(event.actor_position)
	player.seek_pose(position,0.10)
	await _ticks(3)
	var before: Dictionary=player.visual_state()
	await _click_button(view._play_button,"Play generic "+str(event.action_kind))
	for tick: int in range(120):
		await process_frame
		if player.phase>=0.58 or player.playback_status!="playing": break
	await _click_button(view._pause_button,"Pause generic "+str(event.action_kind))
	var after: Dictionary=player.visual_state()
	_check(player.playback_status=="paused" and player.phase>0.35 and int(player._current_event().actor_position)==position,"Real Tween advances and pauses within its generic action: "+str(event.action_kind))
	generic_samples.append({"entry_id":entry.entry_id,"word":entry.spelling_display,"position":position,"kind":event.action_kind,"before":_visual_summary(before),"after":_visual_summary(after)})
	await _capture("generic-action-"+str(event.action_kind)+".png")

func _check_prop_stories() -> void:
	for word: String in ["hello","nose","book","football","dog","wood"]:
		var entry: Dictionary=_entry_by_spelling(word)
		_check(not entry.is_empty(),"Real prop-story entry exists: "+word)
		if entry.is_empty(): continue
		await _open_component(entry)
		for page: int in range(entry.story_beats.size()):
			var player: Control=view._story_player
			if not is_instance_valid(player):
				_check(false,"Prop story creates a stage: "+word)
				break
			view._scroll.ensure_control_visible(player)
			await _ticks(3)
			for event: Dictionary in player.events.duplicate(true):
				player.seek_pose(int(event.actor_position),0.55)
				await _ticks(4)
				var diagnostic: Dictionary=player.prop_diagnostics()
				_check(diagnostic.fallback_prop_ids.is_empty(),"Available prop PNGs do not silently fall back: %s/%d" % [word,event.actor_position])
				for prop_id: String in diagnostic.visible_prop_ids:
					# v3 can add a semantic object while the accepted ten v2 props
					# retain their exact original pixels and specialized animation.
					if not prop_items.has(prop_id):
						var source_path := str(diagnostic.get("semantic_source_paths",{}).get(prop_id,""))
						var source_spec: Dictionary = player.semantic_art_registry().get("assets",{}).get(prop_id,{})
						_check(str(source_spec.get("path","")) == source_path and str(source_spec.get("status","")) == "available","Additional semantic prop matches its available registry entry: "+prop_id)
						_check(not source_path.is_empty() and ResourceLoader.exists(source_path,"Texture2D"),"Additional semantic prop has a real texture source: "+prop_id)
						_check(player._prop_textures.get(prop_id) != null and not diagnostic.drawn_props.get(prop_id,[]).is_empty(),"Additional semantic prop is actually drawn: "+prop_id)
						incremental_props[prop_id] = source_path
						_check_drawn_quads(player,prop_id,diagnostic)
						continue
					drawn_props[prop_id]=true
					_check(prop_items.has(prop_id) and _image_hash(_texture_image(player._prop_textures[prop_id]))==str(prop_pixel_hashes[prop_id]),"Actually drawn prop uses its preserved PNG pixels: "+prop_id)
					var region: Array=diagnostic.source_regions[prop_id]
					var source_size: Array=prop_items[prop_id].size
					_check(region.size()==4 and float(region[0])>=0 and float(region[1])>=0 and float(region[2])>0 and float(region[3])>0 and float(region[0])+float(region[2])<=float(source_size[0])+0.01 and float(region[1])+float(region[3])<=float(source_size[1])+0.01,"Prop source region remains inside its original PNG: "+prop_id)
					_check_drawn_quads(player,prop_id,diagnostic)
				prop_samples.append({"word":word,"position":int(event.actor_position),"phase":player.phase,"diagnostic":diagnostic})
				await _capture("props-%s-position%d.png" % [word,event.actor_position])
				if word=="book" and int(event.actor_position) in [2,3]:
					await _check_book_shape_change(player,int(event.actor_position))
				if word=="book" and int(event.actor_position)==3:
					await _check_atomic_book_fallback(player)
				if word=="nose":
					for sample_phase: float in [0.1,0.9]:
						player.seek_pose(int(event.actor_position),sample_phase)
						await _ticks(3)
						await _capture("nose-position%d-phase%d.png" % [event.actor_position,roundi(sample_phase*100)])
			if page+1<entry.story_beats.size(): await _click(view,"下一页")
		await _destroy_view()
	_check(_sorted_strings(drawn_props.keys())==_sorted_strings(PROP_IDS),"The ten props were actually drawn in their source stories")

func _check_drawn_quads(player: Control, prop_id: String, diagnostic: Dictionary) -> void:
	var draws: Array=diagnostic.drawn_props.get(prop_id,[])
	_check(not draws.is_empty(),"Visible prop has an actual draw call: "+prop_id)
	for draw: Dictionary in draws:
		var quad: Array=draw.get("quad",[])
		var uv: Array=draw.get("source_uv",[])
		if quad.size()!=4 or uv.size()!=4:
			_check(false,"Prop draw has four corners and a UV rectangle: "+prop_id)
			continue
		var points: Array[Vector2]=[]
		for value: Array in quad: points.append(Vector2(float(value[0]),float(value[1])))
		var area: float=0.0
		var bounds:=Rect2(points[0],Vector2.ZERO)
		for index: int in range(4):
			area+=points[index].cross(points[(index+1)%4])
			bounds=bounds.expand(points[index])
		_check(absf(area)>0.5 and bounds.intersects(Rect2(0,0,1000,238)),"Actually drawn prop has nondegenerate geometry inside the stage: "+prop_id)
		if prop_id=="reading_table":
			_check(bounds.end.y<215.0,"Actual reading-table quad stays above the source-position labels")
		_check(float(uv[0])>=0.0 and float(uv[1])>=0.0 and float(uv[2])>0.0 and float(uv[3])>0.0 and float(uv[0])+float(uv[2])<=1.00001 and float(uv[1])+float(uv[3])<=1.00001,"Actual draw UV is inside the preserved source PNG: "+prop_id)
		var stage_rect: Rect2=player.get_global_rect()
		var scale: Vector2=Vector2(stage_rect.size.x/1000.0,(stage_rect.size.y-52.0)/238.0)
		var screen_bounds:=Rect2(stage_rect.position+bounds.position*scale,bounds.size*scale)
		var visible: Rect2=root.get_visible_rect()
		var ancestor: Node=player.get_parent()
		while ancestor!=null:
			if ancestor is ScrollContainer: visible=visible.intersection(ancestor.get_global_rect())
			ancestor=ancestor.get_parent()
		_check(screen_bounds.intersects(visible),"Actual prop quad intersects the visible scroll viewport: "+prop_id)

func _check_book_shape_change(player: Control, position: int) -> void:
	var prop_id: String="book_cover" if position==2 else "book_page_leaf"
	var shapes: Array=[]
	for sample_phase: float in [0.2,0.8]:
		player.seek_pose(position,sample_phase)
		await _ticks(3)
		var diagnostic: Dictionary=player.prop_diagnostics()
		_check_drawn_quads(player,prop_id,diagnostic)
		var draws: Array=diagnostic.drawn_props.get(prop_id,[])
		if not draws.is_empty(): shapes.append(draws[0].quad.duplicate(true))
		await _capture("book-position%d-phase%d.png" % [position,roundi(sample_phase*100)])
	_check(shapes.size()==2 and shapes[0]!=shapes[1],"Actual PNG book quad changes across its action: "+prop_id)
	if position==3 and shapes.size()==2:
		_check(float(shapes[0][1][0])>float(shapes[0][0][0]) and float(shapes[1][1][0])<float(shapes[1][0][0]),"Actual PNG page crosses from the right of the spine to its left")
	player.seek_pose(position,0.55)
	await _ticks(3)

func _check_atomic_book_fallback(player: Control) -> void:
	var original: Texture2D=player._prop_textures.get("book_cover")
	player._prop_textures["book_cover"]=null
	player.queue_redraw()
	await _ticks(3)
	var diagnostic: Dictionary=player.prop_diagnostics()
	_check(diagnostic.fallback_prop_ids.has("book_cover") and not diagnostic.visible_prop_ids.has("book_open_base") and not diagnostic.visible_prop_ids.has("book_cover") and not diagnostic.visible_prop_ids.has("book_page_leaf"),"Injected failed book-cover cache takes the complete old-geometry branch")
	player._prop_textures["book_cover"]=original
	player.queue_redraw()
	await _ticks(3)
	_check(player.visible_prop_ids().has("book_open_base") and player.visible_prop_ids().has("book_page_leaf"),"Restoring only the in-memory cover recovers the PNG book")

func _check_hints_and_state() -> void:
	var entry: Dictionary=Content.get_entry(GENERIC_ENTRIES[0])
	var old: Dictionary={"entry_id":entry.entry_id,"content_revision":BASE_CONTENT_REVISION,"codebook_revision":BASE_CODEBOOK_REVISION,"invocation_id":"pre-v2-art-fixture","attempt_id":"pre-v2-art-fixture/attempt-1","current_beat":1,"support_level":3,"max_help_level":5,"revealed_gaps":[2],"first_response":{"correct":false,"response_text":"unfinished"},"later_response":{"correct":true,"response_text":entry.spelling_display},"draft_response":entry.spelling_display,"animation_state":{"schema_version":1,"stage_revision":"memory-stage-v1","beat_id":str(entry.story_beats[0].beat_id),"step_position":2,"phase":0.42,"playback_status":"playing","reduced_motion":false}}
	await _open_component(entry,old)
	_check(not view._content_unavailable and not view.first_response.correct and view.later_response.correct and view.draft_response==entry.spelling_display,"Fixed pre-v2 session keeps response history and draft")
	_check(view._revealed_gaps==[2] and is_instance_valid(view._story_player) and view._story_player.snapshot().step_position==2 and is_equal_approx(view._story_player.phase,0.42) and view._story_player.playback_status=="paused","Fixed pre-v2 session keeps revealed gap, position and phase without autoplay")
	await _destroy_view()
	var context: Dictionary={"book_id":str(entry.source_unit.book_id),"unit_id":str(entry.source_unit.unit_ids[0]),"story_step_id":"all-art-v2/state","task_mode":"meaning_to_spelling","target_dimension":"orthography","declared_stimulus":"written_meaning: "+str(entry.meaning_zh),"answer_visible_at_start":true}
	if not await _open_saved(entry,context): return
	await _click_button(view._play_button,"Play before real disk save")
	await _ticks(24)
	await _click_button(view._pause_button,"Pause before real disk save")
	var saved: Dictionary=view.get_resume()
	_check(sink.close("paused"),"Real event sink writes the isolated art session")
	await _destroy_view()
	sink=null
	state.load_state()
	if not await _open_saved(entry,context): return
	var restored: Dictionary=view.get_resume()
	_check(restored.invocation_id==saved.invocation_id and restored.animation_state.step_position==saved.animation_state.step_position and is_equal_approx(float(restored.animation_state.phase),float(saved.animation_state.phase)) and restored.animation_state.playback_status=="paused","Actual disk reload restores the same session position and phase paused")
	_check(restored.content_revision==BASE_CONTENT_REVISION and restored.codebook_revision==BASE_CODEBOOK_REVISION,"Actual disk reload retains the old learning revisions")
	restoration={"saved":saved.animation_state,"restored":restored.animation_state,"same_invocation":restored.invocation_id==saved.invocation_id}
	await _capture("state-restored-paused.png")
	Content._icon_cache.clear()
	await _click(view,"一起补空格")
	var player: Control=view._story_player
	_check(is_instance_valid(player) and player._textures.keys()==[1,3],"H3 constructs only explicitly visible letter positions")
	if not is_instance_valid(player):
		sink.close("paused")
		await _destroy_view()
		sink=null
		return
	var hidden_second: String=str(entry.letter_slots[1].letter)
	var hidden_fourth: String=str(entry.letter_slots[3].letter)
	_check(not _cache_has_letter(hidden_second) and not _cache_has_letter(hidden_fourth),"Cold H3 cache does not request its unrevealed new letter PNGs")
	_check(player.prop_diagnostics().visible_prop_ids.is_empty() and player.prop_diagnostics().loaded_prop_ids.is_empty(),"H3 loads and displays no answer-bearing prop PNGs")
	_check(not _all_text(view).contains(str(entry.spelling_display)),"H3 does not expose the full target spelling")
	await _capture("h3-hidden-new-letters.png")
	var gap_button: Button
	for card: Node in view._body.find_children("*","PanelContainer",true,false):
		if int(card.get_meta("letter_position",-1))==2:
			gap_button=_find_button(card,"?\n请朋友揭示")
			break
	await _click_button(gap_button,"Reveal exactly source position 2")
	_check(view._story_player._textures.keys()==[1,2,3] and not _cache_has_letter(hidden_fourth),"One actual gap button adds exactly its requested letter")
	for caption: String in ["自己想一想","想想它住哪里"]:
		Content._icon_cache.clear()
		await _click(view,caption)
		_check(not is_instance_valid(view._story_player) and Content._icon_cache.is_empty(),"No stage or letter PNG request at "+caption)
		var session: Dictionary=state.journey_snapshot().memory.sessions[invocation]
		_check(session.cue_events[-1].revealed_letter_positions.is_empty(),"No invented letter cue at "+caption)
	await _click(view,"一步一步接")
	var next_letter: String=str(entry.letter_slots[1].letter)
	var choice: Button=_find_button(view,str(Content.codebook_item(next_letter).representative_label_zh))
	_check(choice!=null and _same_pixels(_texture_image(choice.icon),expected_icons[next_letter]["1"]),"Specific H4 candidate Button uses its new PNG")
	await _click_button(choice,"Choose the actual H4 next-letter candidate")
	_check(view._bridge_position==2,"Actual H4 candidate input advances exactly one source position")
	_check(sink.close("paused"),"Hint sequence is preserved by the real event sink")
	await _destroy_view()
	sink=null

func _check_shared_prologue() -> void:
	var prologue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/prologue.json"))
	for record: Dictionary in prologue.letters:
		var letter: String=str(record.letter.uppercase)
		var activity: Control=Prologue.new()
		activity.size=host.size
		host.add_child(activity)
		activity.setup(record,false)
		await _ticks(4)
		_check(_same_pixels(_texture_image(activity.stage._texture(letter)),expected_icons[letter]["2"]),"P2 object stage retains the canonical letter PNG source: "+letter)
		_check(activity.picture is TextureRect and activity.picture.texture.resource_path==str(activity.spec.world_view),"P2 glyph pane uses the captured authored model: "+letter)
		if letter in ["A","E","M","W","Z"]: await _capture("prologue-"+letter+".png")
		activity.queue_free()
		await process_frame

func _capture_alphabet_gallery() -> void:
	var layout:=VBoxContainer.new()
	layout.size=host.size
	layout.add_theme_constant_override("separation",12)
	host.add_child(layout)
	layout.add_child(Style.text("字母伙伴 · A–Z",30))
	var grid:=GridContainer.new()
	grid.columns=7
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	layout.add_child(grid)
	for letter: String in ALPHABET:
		var card:=PanelContainer.new()
		card.custom_minimum_size=Vector2(175,176)
		card.add_theme_stylebox_override("panel",Style.box(Color("f8f6ec"),14,8))
		grid.add_child(card)
		var box:=VBoxContainer.new()
		box.add_theme_constant_override("separation",3)
		card.add_child(box)
		var picture:=TextureRect.new()
		picture.custom_minimum_size=Vector2(145,128)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture=Content.icon(letter,2.0)
		box.add_child(picture)
		var caption: Label=Style.text(letter+" · "+str(Content.codebook_item(letter).representative_label_zh),17)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		box.add_child(caption)
	await _ticks(6)
	await _capture("00-alphabet-gallery.png")
	layout.queue_free()
	await process_frame

func _open_component(entry: Dictionary, resume: Dictionary = {}) -> void:
	await _destroy_view()
	view=Story.new()
	host.add_child(view)
	view.setup(entry,resume)
	await _ticks(6)

func _open_saved(entry: Dictionary, context: Dictionary) -> bool:
	var opened: Dictionary=state.journey_begin_memory(entry,context)
	_check(bool(opened.get("ok",false)),"State accepts the unchanged source session")
	if not opened.get("ok",false): return false
	invocation=str(opened.invocation_id)
	sink=Sink.new()
	var ready: bool=sink.setup(state,invocation)
	_check(ready,"Real event sink owns the isolated session")
	if not ready: return false
	view=Story.new()
	host.add_child(view)
	view.help_shown.connect(func(event: Dictionary): _check(sink.enqueue("cue",event),"Displayed source cue persists"))
	view.progress_changed.connect(func(progress: Dictionary): _check(sink.enqueue("progress",progress),"Actual progress persists"))
	view.response_submitted.connect(func(response: Dictionary): _check(sink.enqueue("response",response),"Actual response persists"))
	view.setup(entry,opened.resume_state)
	await _ticks(6)
	return true

func _destroy_view() -> void:
	if is_instance_valid(view):
		view.queue_free()
		await process_frame
	view=null

func _entry_by_spelling(word: String) -> Dictionary:
	for entry: Dictionary in Content.list_entries("","",word):
		if str(entry.spelling_display)==word: return Content.get_entry(str(entry.entry_id))
	return {}

func _click(node: Node, caption: String) -> void:
	await _click_button(_find_button(node,caption),caption)

func _click_button(button: Button, label: String) -> void:
	_check(is_instance_valid(button) and not button.disabled,"Actual enabled UI button: "+label)
	if not is_instance_valid(button) or button.disabled: return
	var ancestor: Node=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await _ticks(3)
	var point: Vector2=button.get_global_rect().get_center()
	var reachable: bool=button.is_visible_in_tree() and Rect2(Vector2.ZERO,root.get_visible_rect().size).has_point(point)
	ancestor=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer and not ancestor.get_global_rect().has_point(point): reachable=false
		ancestor=ancestor.get_parent()
	_check(reachable,"Actual UI input lies inside viewport and scroll clips: "+label)
	ui_clicks.append({"label":label,"position":[point.x,point.y],"reachable":reachable})
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
	await _ticks(5)
	if is_instance_valid(view) and is_instance_valid(view._story_player):
		view._scroll.ensure_control_visible(view._story_player)
		await _ticks(3)

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and str(node.text)==caption: return node
	for child: Node in node.get_children():
		var found: Button=_find_button(child,caption)
		if found!=null: return found
	return null

func _cache_has_letter(letter: String) -> bool:
	return Content._icon_cache.keys().any(func(key: Variant): return str(key).begins_with(letter+"@"))

func _all_text(node: Node) -> String:
	var result: String=str(node.text)+"\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+=_all_text(child)
	return result

func _resource_path(repo_relative: String) -> String:
	return "res://"+repo_relative.trim_prefix("game/") if repo_relative.begins_with("game/") else ""

func _sorted_strings(values: Variant) -> Array[String]:
	var result: Array[String]=[]
	for value: Variant in values: result.append(str(value))
	result.sort()
	return result

func _texture_image(texture: Texture2D) -> Image:
	if texture==null: return null
	var result: Image=texture.get_image()
	if result==null or result.is_empty(): return null
	if result.is_compressed(): result.decompress()
	result.clear_mipmaps()
	result.convert(Image.FORMAT_RGBA8)
	return result

func _svg_image(letter: String) -> Image:
	var picture:=Image.new()
	picture.load_svg_from_string(str(Content.codebook_item(letter).svg_source),1.0)
	picture.convert(Image.FORMAT_RGBA8)
	return picture

func _same_pixels(first: Image, second: Image) -> bool:
	return first!=null and second!=null and first.get_size()==second.get_size() and first.get_data()==second.get_data()

func _image_hash(picture: Image) -> String:
	if picture==null: return "unavailable"
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(picture.get_data())
	return context.finish().hex_encode()

func _visual_summary(value: Dictionary) -> Dictionary:
	var actor: String=str(value.event.actor_position)
	var center: Vector2=value.actors[actor].center
	var prop: Vector2=value.prop.position
	return {"phase":value.phase,"status":value.snapshot.playback_status,"actor_center":[center.x,center.y],"prop_position":[prop.x,prop.y],"prop_openness":value.prop.openness}

func _ticks(count: int) -> void:
	for index: int in range(count): await process_frame

func _capture(filename: String) -> void:
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	var picture: Image=root.get_texture().get_image()
	var path: String=image_output.path_join(filename)
	_check(picture.save_png(path)==OK,"Native artifact saved: "+filename)
	captures.append({"file":filename,"sha256":_hash(path),"image_size":[picture.get_width(),picture.get_height()]})

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _check(condition: bool, label: String) -> void:
	checks.append({"check":label,"passed":condition})
	if not condition:
		failures.append(label)
		push_error("LEARNING_ART_ALL_FAIL: "+label)

func _finish() -> void:
	var unchanged: bool=_hash("user://island-save-v1.json")==production_hash and _hash("user://island-save-v1.json.bak")==backup_hash
	_check(unchanged,"Production save and backup remain byte-identical")
	var report: Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"check_details":checks,"manifest_sha256":_hash(MANIFEST),"assets":assets,"generic_word_count":GENERIC_ENTRIES.size(),"covered_letters":_sorted_strings(covered_letters.keys()),"covered_generic_kinds":_sorted_strings(covered_kinds.keys()),"generic_tween_samples":generic_samples,"actually_drawn_props":_sorted_strings(drawn_props.keys()),"prop_samples":prop_samples,"state_restoration":restoration,"ui_clicks":ui_clicks,"captures":captures,"capture_enabled":capture_enabled,"requested_window":[requested_size.x,requested_size.y],"actual_root_window":[root.size.x,root.size.y],"actual_display_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"logical_viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"production_save_and_backup_unchanged":unchanged,"scope":"26 PNG source pixels and cached SVG fallback; six real words cover A-Z and 13 generic categories; ten actually drawn props and atomic book fallback; H0/H1/H3/H4 exposure; fixed old learning revisions and real isolated disk restore; 26 shared prologue images. Discrete native frames and actual UI/Tween samples, not performance, exhaustive curriculum or learning-outcome evidence."}
	report["additional_semantic_props"] = incremental_props
	var name: String="%s-%dx%d-report.json" % ["native" if capture_enabled else "headless",requested_size.x,requested_size.y]
	var file: FileAccess=FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify({"status":report.status,"checks":checks.size(),"failures":failures,"captures":captures.size(),"generic_tween_samples":generic_samples.size(),"drawn_props":drawn_props.size()}))
	if is_instance_valid(host): host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
