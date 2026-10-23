extends SceneTree
## Independent source fixtures, exercised through the actual paper-theatre stage.
const Content = preload("res://ui/memory_story_content.gd")
const Stage = preload("res://ui/memory_story_stage.gd")
const Story = preload("res://ui/memory_story.gd")
const Style = preload("res://ui/island_theme.gd")
const FIXTURES := "res://../docs/verification/art-finish-v3/story-semantic-fixtures.json"
const REGISTRY := "res://data/learning/story_prop_art.json"
var requested := Vector2i(1440,900)
var capture := false
var only_available := false
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var reader_samples: Array[Dictionary] = []
var protected: Dictionary = {}
var registry_sha := ""
var stage_sha := ""
var fixtures_sha := ""
var host: Control
var caption: Label
var stage: Control
var image_dir := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg == "--only-available": only_available = true
		if arg.begins_with("--art-width="): requested.x = arg.trim_prefix("--art-width=").to_int()
		if arg.begins_with("--art-height="): requested.y = arg.trim_prefix("--art-height=").to_int()
	_run.call_deferred()

func _run() -> void:
	create_timer(120).timeout.connect(func(): printerr("STORY_SEMANTICS_TIMEOUT"); quit(2))
	for path: String in ["user://island-save-v1.json","user://island-save-v1.json.bak"]: protected[path] = _hash(path)
	registry_sha = _hash(REGISTRY)
	stage_sha = _hash("res://ui/memory_story_stage.gd")
	fixtures_sha = _hash(FIXTURES)
	root.size = requested
	image_dir = ProjectSettings.globalize_path("res://../docs/screenshots/art-finish-v3/%dx%d/story-semantics" % [requested.x,requested.y])
	if capture: DirAccess.make_dir_recursive_absolute(image_dir)
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
	host = Control.new()
	host.size = Vector2(1440,900)
	host.theme = Style.make_theme()
	root.add_child(host)
	var background := ColorRect.new()
	background.color = Style.PAPER
	background.size = host.size
	host.add_child(background)
	caption = Style.text("",24)
	caption.position = Vector2(75,65)
	caption.size = Vector2(1290,150)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(caption)
	stage = Stage.new()
	stage.position = Vector2(70,250)
	stage.size = Vector2(1300,420)
	host.add_child(stage)
	await _frames(3)
	for group: String in ["counting_fixtures","quantity_exclusions","actor_priority_fixtures"]:
		for fixture: Dictionary in fixtures[group]:
			await _sample(fixture,group)
	for path: String in protected: _check(_hash(path) == protected[path],"formal save unchanged: "+path)
	_finish()

func _entry(story_id: String) -> Dictionary:
	for record: Dictionary in Content.load_catalog().get("entries",[]):
		if str(record.story_id) == story_id: return Content.get_entry(str(record.entry_id))
	return {}

func _sample(fixture: Dictionary, group: String) -> void:
	var id := "%s-%02d" % [fixture.word,int(fixture.position)]
	var entry := _entry(str(fixture.story_id))
	_check(not entry.is_empty(),id+" source entry exists")
	if entry.is_empty(): return
	var position := int(fixture.position)
	_check(str(entry.steps[position-1].action) == str(fixture.source_action),id+" fixture matches exact curriculum action")
	var positions: Array = []
	for beat: Dictionary in entry.story_beats:
		for value: Variant in beat.letter_positions:
			if int(value) == position: positions = beat.letter_positions
	_check(not positions.is_empty(),id+" uses authored four-actor page")
	stage.setup(entry,positions,positions,5,false)
	stage.seek_pose(position,0.55)
	await _frames(4)
	var diagnostic: Dictionary = stage.prop_diagnostics()
	var resolution: Dictionary = diagnostic.semantic_art_resolution
	var prop := str(resolution.get("prop_id",""))
	if only_available and str(resolution.get("status","")) == "pending_asset":
		samples.append({"fixture":fixture,"group":group,"skipped":"pending_asset","resolution":resolution})
		return
	var expected_prop := str(fixture.get("expected_entity",fixture.get("expected_prop","")))
	if expected_prop == "counting bead": expected_prop = "bead"
	if expected_prop == "counting stick": expected_prop = "counting_stick"
	if group == "quantity_exclusions":
		expected_prop = {"afternoon":"travel_journal","table":"reading_table","violin":"violin","monster":"monster"}[str(fixture.word)]
	var expected_count := int(fixture.get("expected_count",fixture.get("expected_total",1)))
	if not expected_prop.is_empty():
		_check(prop == expected_prop,id+" resolves handled object: "+expected_prop)
		_check(str(resolution.get("status","")) in ["concrete_asset","text_surface","specialized_v2"],id+" resource is actually available")
		_check(int(resolution.get("count",1)) == expected_count,id+" quantity describes the prop, not its actor or body parts")
		var draws: Array = diagnostic.drawn_props.get(expected_prop,[])
		_check(draws.size() == expected_count,id+" actual PNG draw count equals "+str(expected_count))
		_check(diagnostic.fallback_prop_ids.is_empty(),id+" no silent fallback for concrete art")
		_check_quads(draws,id,fixture)
		if expected_prop == "violin":
			var strings: Array = diagnostic.get("runtime_parts",{}).get("violin_strings",[])
			var starts: Dictionary = {}
			var valid_lines := strings.size() == 4
			for line: Dictionary in strings:
				var start := Vector2(float(line.start[0]),float(line.start[1]))
				var end := Vector2(float(line.end[0]),float(line.end[1]))
				starts[str(start)] = true
				valid_lines = valid_lines and start.distance_to(end) > 1.0
			_check(valid_lines and starts.size() == 4,id+" four distinct nondegenerate violin strings are actually drawn")
	if fixture.has("expected_extra_flower_count"):
		_check(prop != "flower" and not diagnostic.visible_prop_ids.has("flower"),id+" actor flower is not duplicated as a prop")
	if fixture.has("expected_extra_owl_count"):
		_check(prop != "owl" and not diagnostic.visible_prop_ids.has("owl"),id+" ordinal actor owl is not duplicated as a prop")
	if fixture.has("expected_groups"):
		_check(int(resolution.get("group_size",0)) == int(fixture.expected_count_per_group),id+" groups contain the source quantity")
	caption.text = "%s · 第 %d 步\n%s\n真实故事舞台 / 原课程动作 / 道具实例数 %d" % [fixture.word,position,fixture.source_action,int(resolution.get("count",1))]
	await _capture(id+".png")
	samples.append({"fixture":fixture,"group":group,"entry_id":entry.entry_id,"frame_positions":positions,"diagnostic":diagnostic})
	if id in ["two-01","nine-02","eight-02","twenty-06","thirty-06","fruit-03"]:
		await _capture_reader(entry,position,id,int(resolution.get("count",1)),prop)
	# Hidden H3 must resolve/load/draw no answer prop, including a fresh setup.
	stage.setup(entry,positions,[],3,false)
	stage.seek_pose(position,0.55)
	await _frames(3)
	var hidden: Dictionary = stage.prop_diagnostics()
	_check(hidden.resolved_semantic_prop_id.is_empty() and hidden.semantic_art_status == "hidden",id+" H3 does not resolve an answer prop")
	_check(hidden.semantic_texture_cache_count == 0 and hidden.semantic_source_paths.is_empty() and hidden.visible_prop_ids.is_empty() and hidden.drawn_props.is_empty() and hidden.get("runtime_parts",{}).is_empty(),id+" H3 makes no prop texture request or draw")

func _capture_reader(entry: Dictionary, position: int, id: String, expected_count: int, prop: String) -> void:
	# The isolated stage above exposes geometry; this samples the unchanged
	# production reader layout to check actual scrolling and physical readability.
	caption.hide()
	stage.hide()
	var reader_host := Control.new()
	reader_host.position = Vector2(70,40)
	reader_host.size = Vector2(1300,820)
	host.add_child(reader_host)
	var reader: Control = Story.new()
	reader_host.add_child(reader)
	var beat_index := 1
	for index: int in range(entry.story_beats.size()):
		for value: Variant in entry.story_beats[index].letter_positions:
			if int(value) == position: beat_index = index+1
	reader.setup(entry,{"current_beat":beat_index,"support_level":5})
	await _frames(8)
	var actual: Control = reader._story_player
	_check(is_instance_valid(actual),id+" actual story reader creates its stage")
	if is_instance_valid(actual):
		actual.seek_pose(position,0.55)
		reader._scroll.ensure_control_visible(actual)
		await _frames(5)
		var real_draws: Dictionary = actual.prop_diagnostics()
		_check(real_draws.drawn_props.get(prop,[]).size() == expected_count,id+" actual reader preserves concrete PNG instance count")
		var rect := actual.get_global_rect()
		var visible := rect.intersection(reader._scroll.get_global_rect()).intersection(root.get_visible_rect())
		_check(visible.size.is_equal_approx(rect.size),id+" actual reader stage fits the visible scroll area")
		reader_samples.append({"id":id,"entry_id":entry.entry_id,"stage_size":[actual.size.x,actual.size.y],"stage_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"diagnostic":real_draws})
		await _capture("reader-"+id+".png")
	reader_host.queue_free()
	await process_frame
	caption.show()
	stage.show()

func _check_quads(draws: Array, id: String, fixture: Dictionary) -> void:
	var row_centers: Dictionary = {}
	var column_centers: Dictionary = {}
	var inside := true
	for draw: Dictionary in draws:
		var center := Vector2.ZERO
		for point: Array in draw.quad:
			var p := Vector2(float(point[0]),float(point[1]))
			center += p/4.0
			inside = inside and p.x >= 0 and p.x <= 1000 and p.y >= 0 and p.y <= 238
		row_centers[roundi(center.y*100)] = true
		column_centers[roundi(center.x*100)] = true
	_check(inside,id+" drawn props remain inside the stage")
	if fixture.has("expected_rows"):
		_check(row_centers.size() == int(fixture.expected_rows) and column_centers.size() == int(fixture.expected_columns),id+" actual PNG centers form source rows and columns")

func _frames(count: int) -> void:
	for index: int in range(count): await process_frame

func _capture(filename: String) -> void:
	if not capture: return
	await _frames(2)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := image_dir.path_join(filename)
	_check(picture.save_png(path) == OK,"native screenshot saved: "+filename)
	captures.append({"path":path,"sha256":_hash(path),"size":[picture.get_width(),picture.get_height()]})

func _check(ok: bool, label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failures.append(label)

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _finish() -> void:
	_check(registry_sha == _hash(REGISTRY),"semantic registry remains unchanged during the run")
	_check(stage_sha == _hash("res://ui/memory_story_stage.gd") and fixtures_sha == _hash(FIXTURES),"stage source and independent fixtures remain unchanged during the run")
	var status := "PASS" if failures.is_empty() else "FAIL"
	if only_available and status == "PASS": status = "PARTIAL_AVAILABLE_ONLY"
	var output := ProjectSettings.globalize_path("res://../docs/verification/art-finish-v3/story-semantics-%dx%d.json" % [requested.x,requested.y])
	var report := {"status":status,"checks":checks.size(),"failures":failures,"check_details":checks,"samples":samples,"captures":captures,"requested_size":[requested.x,requested.y],"actual_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"registry_sha256":registry_sha,"registry_end_sha256":_hash(REGISTRY),"source_fixtures_sha256":_hash(FIXTURES),"stage_sha256":_hash("res://ui/memory_story_stage.gd"),"scope":"Independent source-grounded quantity, part/actor exclusion and handled-object fixtures through actual Stage PNG draws, H3 hidden-resource checks, and native screenshots. Covers listed fixtures only, not all 1096 stories. Static draw counts require visual review for readability."}
	report["reader_samples"] = reader_samples
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("STORY_SEMANTICS_V3 ",JSON.stringify({"status":status,"checks":checks.size(),"failures":failures,"captures":captures.size()}))
	quit(0 if failures.is_empty() else 1)
