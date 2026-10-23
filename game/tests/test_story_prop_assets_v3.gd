extends SceneTree
## Every registered source/runtime asset, bounded lazy cache and UI resolver.
const Stage = preload("res://ui/memory_story_stage.gd")
const Content = preload("res://ui/memory_story_content.gd")
const Style = preload("res://ui/island_theme.gd")
const PROTECTED := ["user://island-save-v1.json", "user://island-save-v1.json.bak", "res://data/learning/catalog.json", "res://data/learning/prologue.json"]
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var draw_samples: Array[Dictionary] = []
var gallery_paths: Array[String] = []
var capture := false
var candidate_map: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	var state: Node = root.get_node("State")
	state.save_path = "user://validation-story-prop-assets-v3-%d.json" % OS.get_process_id()
	capture = OS.get_cmdline_user_args().has("--capture")
	root.size = Vector2i(1440,900)
	create_timer(240).timeout.connect(func(): printerr("STORY_PROP_ASSETS_TIMEOUT"); quit(2))
	var before: Dictionary = {}
	for path: String in PROTECTED: before[path] = _hash(path)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../assets/art/story_props_v3/manifest.json"))
	var registry: Dictionary = Stage.semantic_art_registry()
	_check(registry.get("assets", {}).size() == manifest.get("assets", []).size(), "Registry and manifest asset totals agree")
	_check(registry.get("stories", {}).size() == 1096, "Every canonical story is audited")
	_check(str(registry.get("catalog_sha256", "")) == _hash("res://data/learning/catalog.json"), "Registry belongs to the unchanged curriculum")
	var stage := Stage.new()
	stage.support_level = 5
	stage.position = Vector2(70,250)
	stage.size = Vector2(1300,420)
	root.add_child(stage)
	_build_candidates(registry)
	await process_frame
	var new_count := 0
	for asset: Dictionary in manifest.get("assets", []):
		var id := str(asset.get("id", ""))
		var path := str(asset.get("path", ""))
		_check(str(asset.get("status", "")) == "available", "Asset is available: " + id)
		_check(ResourceLoader.exists(path, "Texture2D"), "Imported texture exists: " + id)
		_check(_hash(path) == str(asset.get("sha256", "")), "Runtime bytes match audited SHA: " + id)
		if str(asset.get("origin", "")) == "built-in image_gen":
			new_count += 1
			var source := "res://../" + str(asset.get("source", ""))
			_check(_hash(source) == _hash(path), "Original source and runtime copy are identical: " + id)
			var alpha: Array = asset.get("corner_alpha", [])
			_check(alpha.size() == 4 and alpha.max() <= 5, "Transparent source corners: " + id)
		var texture: Texture2D = stage._prop_texture(id)
		_check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "Actual stage texture resolves: " + id)
		if texture != null and not Stage.PROP_IDS.has(id):
			_check(maxi(texture.get_width(), texture.get_height()) <= Stage.SEMANTIC_TEXTURE_EDGE, "Runtime raster edge is bounded: " + id)
		_check(stage._semantic_texture_order.size() <= Stage.MAX_SEMANTIC_TEXTURES, "Semantic texture cache stays bounded after: " + id)
		if str(asset.get("origin", "")) == "built-in image_gen":
			if candidate_map.has(id):
				await _draw_asset(stage,id,path)
			else:
				var ui_ids: Array = []
				for icon_id: String in registry.get("ui_art", {}):
					if str(registry.ui_art[icon_id]) == id: ui_ids.append(icon_id)
				_check(not ui_ids.is_empty(),"No story witness is explicitly classified as UI illustration: "+id)
				draw_samples.append({"id":id,"classification":"ui_illustration_only","ui_icon_ids":ui_ids})
		await process_frame
	_check(new_count == 182, "All 182 new generated props are present")
	var ui_rows: Array[Dictionary] = []
	for icon_id: String in registry.get("ui_art", {}):
		var path: String = Style.icon_asset_path(icon_id)
		var texture: Texture2D = Style.icon(icon_id)
		var passed := path.ends_with(".png") and texture != null
		if texture != null: passed = passed and texture.get_width() == 96 and str(texture.get_meta("source_art_path", "")) == path
		_check(passed, "UI icon uses the real painted runtime PNG: " + icon_id)
		ui_rows.append({"id":icon_id,"path":path,"passed":passed})
	for icon_id: String in ["close", "check", "arrow", "settings", "speaker"]:
		_check(Style.icon_asset_path(icon_id).ends_with(".svg") and Style.icon(icon_id) != null, "Functional symbol remains vector: " + icon_id)
	if capture:
		stage.hide()
		await _capture_gallery(stage,manifest.get("assets", []))
	stage.queue_free()
	await process_frame
	var hidden := Stage.new()
	hidden.support_level = 3
	for id: String in registry.get("assets", {}):
		_check(hidden._prop_texture(id) == null, "H3 loads no answer texture: " + id)
	_check(hidden._prop_textures.is_empty() and hidden._semantic_source_paths.is_empty(), "H3 leaves both texture caches empty")
	hidden.free()
	for path: String in PROTECTED: _check(before[path] == _hash(path), "Protected content unchanged: " + path)
	var output := ProjectSettings.globalize_path("res://../docs/verification/art-finish-v3/story-prop-assets-v3.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"registered_assets":registry.get("assets", {}).size(),"new_generated_assets":new_count,"ui_icons":ui_rows,"story_draw_samples":draw_samples,"native_gallery_paths":gallery_paths,"scope":"All 218 registered resource paths, original/runtime hashes, lazy texture resolution, cache bounds, each new story prop drawn on an actual authored page, explicitly classified UI-only illustration, UI resolver and H3 resource hiding. Independent semantic quantity/layout is covered by test_story_semantics_v3.gd."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("STORY_PROP_ASSETS_V3 ", JSON.stringify({"passed":failures.is_empty(),"checks":checks.size(),"failures":failures,"report":output}))
	quit(0 if failures.is_empty() else 1)

func _build_candidates(registry: Dictionary) -> void:
	var story_entries: Dictionary = {}
	for entry: Dictionary in Content.load_catalog().get("entries",[]):
		var sid := str(entry.get("story_id",""))
		if not story_entries.has(sid): story_entries[sid] = str(entry.get("entry_id",""))
	for id: String in registry.get("fixtures", {}):
		candidate_map[id] = [registry.fixtures[id].duplicate(true)]
	for sid: String in registry.get("stories", {}):
		var story: Dictionary = registry.stories[sid]
		for step: Dictionary in story.get("steps",[]):
			var id := str(step.get("prop_id",""))
			if id.is_empty() or not story_entries.has(sid): continue
			if not candidate_map.has(id): candidate_map[id] = []
			candidate_map[id].append({"entry_id":story_entries[sid],"position":step.position,"source_action":step.source_action,"word":story.word})

func _draw_asset(stage: Control, id: String, path: String) -> void:
	var attempts: Array = []
	var success := false
	for witness: Dictionary in candidate_map.get(id,[]):
		var entry: Dictionary = Content.get_entry(str(witness.entry_id))
		var position := int(witness.position)
		if entry.is_empty() or position < 1: continue
		var positions: Array = []
		for beat: Dictionary in entry.story_beats:
			for value: Variant in beat.letter_positions:
				if int(value) == position: positions = beat.letter_positions
		if positions.is_empty(): continue
		stage.setup(entry,positions,positions,5,false)
		stage.seek_pose(position,0.55)
		for _frame: int in range(3): await process_frame
		var diagnostic: Dictionary = stage.prop_diagnostics()
		var drawn: Array = diagnostic.drawn_props.get(id,[])
		attempts.append({"entry_id":entry.entry_id,"position":position,"draw_count":drawn.size()})
		if not drawn.is_empty():
			success = true
			_check(diagnostic.visible_prop_ids.has(id),"Actual stage visibility records generated prop: "+id)
			_check(str(diagnostic.semantic_source_paths.get(id,"")) == path,"Actual stage consumes registered PNG: "+id)
			_check(str(entry.steps[position-1].action) == str(witness.source_action),"Actual stage witness matches curriculum: "+id)
			if id == "violin":
				_check(diagnostic.runtime_parts.get("violin_strings",[]).size() == 4,"Violin has exactly four runtime strings")
			draw_samples.append({"id":id,"witness":witness,"authored_positions":positions,"diagnostic":diagnostic,"attempts":attempts})
			break
		if attempts.size() >= 24: break
	_check(success,"Generated prop really draws on an authored story page: "+id)
	if not success: draw_samples.append({"id":id,"passed":false,"attempts":attempts})

func _capture_gallery(stage: Control, assets: Array) -> void:
	var generated: Array = []
	for asset: Dictionary in assets:
		if str(asset.get("origin","")) == "built-in image_gen": generated.append(asset)
	var output := ProjectSettings.globalize_path("res://../docs/screenshots/art-finish-v3/story-prop-gallery")
	DirAccess.make_dir_recursive_absolute(output)
	for page: int in range(ceili(float(generated.size())/36.0)):
		var host := Control.new()
		host.size = Vector2(1440,900)
		host.theme = Style.make_theme()
		root.add_child(host)
		var background := ColorRect.new()
		background.color = Style.PAPER
		background.size = host.size
		host.add_child(background)
		var title := Style.text("故事道具原生资源总览 · %d / %d" % [page+1,ceili(float(generated.size())/36.0)],26)
		title.position = Vector2(28,16)
		host.add_child(title)
		for index: int in range(36):
			var offset := page*36+index
			if offset >= generated.size(): break
			var asset: Dictionary = generated[offset]
			var id := str(asset.id)
			var cell := Panel.new()
			cell.position = Vector2(28+(index%6)*232,65+(index/6)*136)
			cell.size = Vector2(220,128)
			cell.add_theme_stylebox_override("panel",Style.box(Color("fffaf0"),10,1))
			host.add_child(cell)
			var texture := TextureRect.new()
			texture.position = Vector2(12,6)
			texture.size = Vector2(196,94)
			texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture.texture = stage._prop_texture(id)
			cell.add_child(texture)
			var label := Style.text(id+(" · 运行时4弦" if id=="violin" else ""),14)
			label.position = Vector2(8,103)
			label.size = Vector2(204,20)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(label)
		for _frame: int in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var file := output.path_join("%02d.png" % [page+1])
		var result := root.get_texture().get_image().save_png(file)
		_check(result == OK,"Native gallery page saved: "+str(page+1))
		gallery_paths.append(file)
		host.queue_free()
		await process_frame

func _check(passed: bool, description: String) -> void:
	checks.append({"passed":passed,"description":description})
	if not passed: failures.append(description)

func _hash(path: String) -> String:
	if not FileAccess.file_exists(path): return "missing"
	return FileAccess.get_sha256(path)
