extends Node
## Opt-in exported-package smoke check; requires an isolated test save.
const Content = preload("res://ui/memory_story_content.gd")
var game: Node
var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		get_tree().quit(2)
		return
	var catalog := Content.load_catalog()
	_check(catalog.get("entries",[]).size()==1314,"packaged_1314_entries")
	_check(catalog.get("books",[]).size()==8,"packaged_eight_books")
	for letter: String in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		_check(Content.icon(letter)!=null,"packaged_icon/"+letter)
		for kind: String in ["letter","word"]:
			var path := "res://assets/audio/prologue/"+kind+"_"+letter+".wav"
			var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
			_check(stream!=null and stream.get_length()>0.1,kind+"_audio/"+letter)
	_check(Content.STORY_ART_REVISION=="storybook-v2","packaged_art_revision")
	for letter: String in ["B","O","K"]:
		var art_path := Content.icon_asset_path(letter)
		var art: Texture2D = load(art_path) if ResourceLoader.exists(art_path,"Texture2D") else null
		_check(art!=null and art.get_size()==Vector2(1254,1254),"packaged_generated_png/"+letter)
		if art!=null:
			var pixels := art.get_image()
			_check(pixels!=null and pixels.get_pixel(0,0).a<0.01,"packaged_transparent_corner/"+letter)
	_check(FileAccess.file_exists("res://assets/living/textbook_actor_catalog.json"),"actor_catalog_packaged")
	var font: Font = load("res://assets/fonts/IslandSans.otf")
	for character: String in "咖啡é帽鲸轮椅拼写故事":
		_check(font.has_char(character.unicode_at(0)),"font/"+character)
	_check(game.scene_ready,"exported_scene_ready")
	if game.scene_ready:
		await game.change_room("home")
		_check(game.living.get_actor("npc_bear_uncle")!=null,"exported_home_guide")
		game.journey.show_home()
		await _capture("01-home")
		game.journey.show_library()
		await get_tree().process_frame
		_check(game.ui.current_panel=="journey_library" and game.journey.library_matches.size()>100,"exported_library")
		await _capture("02-library")
		game.journey.open_hello_story()
		for frame: int in 4: await get_tree().process_frame
		_check(game.ui.current_panel=="word_story","exported_story_component")
		_check(game.journey.current_memory.find_child("MemoryStoryStage",true,false)!=null,"exported_animated_story_stage")
		await _capture("03-memory-story")
		var story: Node=game.journey.current_memory
		story._reveal_sequence()
		story.set_support(3)
		var session: Dictionary=game.journey.snapshot().memory.sessions[game.journey.memory_invocation]
		_check(session.support_level==3 and not session.show_sequence and session.max_help_level==5,"exported_support_change_keeps_history_and_saves")
		game._close()
		_check(not game.ui.modal.visible and game.journey.memory_sink==null,"exported_story_closes_after_sequence_support_change")
		game.journey.open_story("occ-5605ac34c5f2")
		for frame: int in 8: await get_tree().process_frame
		var book: Node=game.journey.current_memory
		_check(is_instance_valid(book),"exported_book_opens")
		if is_instance_valid(book):
			var book_stage: Node=book._story_player
			_check(is_instance_valid(book_stage) and book_stage._textures.size()==4,"exported_book_four_generated_actors")
			if is_instance_valid(book_stage):
				for position: int in [1,2,3,4]:
					var letter: String=str(book.entry.letter_slots[position-1].letter)
					_check(_matches_packaged_art(book_stage._textures.get(position),letter,320),"exported_stage_png/"+str(position))
				book_stage.seek_pose(2,0.78)
				await _capture("06-book-generated-open")
				book_stage.seek_pose(3,0.72)
				await _capture("07-book-generated-page")
			book.set_support(4)
			for frame: int in 3: await get_tree().process_frame
			var owl_choice := _find_named_button(book._body,str(Content.codebook_item("O").representative_label_zh))
			var decoy_choice := _find_named_button(book._body,str(Content.codebook_item("A").representative_label_zh))
			_check(owl_choice!=null and decoy_choice!=null,"exported_bridge_actual_candidates")
			if owl_choice!=null:
				_check(_matches_packaged_art(owl_choice.icon,"O",160),"exported_bridge_owl_png")
				var old_position: int=book._bridge_position
				owl_choice.pressed.emit()
				_check(book._bridge_position==old_position+1,"exported_bridge_owl_choice_advances")
		game._close()
		await game.change_room("classroom")
		_check(game.living.get_actor("textbook_dino")!=null,"exported_dino_rig")
		var dino: Node=game.living.get_actor("textbook_dino")
		_check(dino.animation_player.has_animation("normal/greet_wave") and dino.animation_player.has_animation("reduced/greet_wave"),"exported_saved_animation_libraries")
		await _capture("04-classroom")
	var state := get_tree().root.get_node("State")
	for step: String in ["H01","H02","H03","H04"]:
		if not state.journey_snapshot().home_steps.has(step): state.journey_complete_home_step(step)
	await game.change_room("landmark_A")
	game.start_orchard_activity()
	for frame: int in 8: await get_tree().process_frame
	_check(is_instance_valid(game.orchard_activity),"exported_orchard_scene")
	if is_instance_valid(game.orchard_activity):
		var activity: Node=game.orchard_activity
		activity.start_demonstration()
		for frame: int in 2400:
			await get_tree().physics_frame
			await get_tree().process_frame
			if activity.phase=="deposited": break
		_check(activity.phase=="deposited","exported_real_pick_carry_place")
		_check(state.journey_orchard_snapshot().completion_mode=="demonstration_viewed","exported_orchard_saved_mode")
		for frame: int in 90:
			await get_tree().physics_frame
			await get_tree().process_frame
		_check(is_instance_valid(activity.discovery_panel),"exported_discovery_after_contact")
		await _capture("05-orchard-discovery")
		activity.set_paused(true)
		activity.replay()
		_check(activity.apple.global_transform.is_equal_approx(activity._apple_on_branch),"exported_replay_restores_branch_transform")
		_check(activity.paused and activity.main_button.disabled,"exported_replay_retains_pause")
		game._stop_orchard_activity()
	for suffix: String in ["",".bak",".tmp"]:
		var path: String = state.save_path+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var report := {"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"exported":not OS.has_feature("editor"),"display_server":DisplayServer.get_name(),"art_revision":Content.STORY_ART_REVISION,"generated_letters":["B","O","K"]}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--smoke-report="):
			var file := FileAccess.open(argument.trim_prefix("--smoke-report="),FileAccess.WRITE)
			if file: file.store_string(JSON.stringify(report,"  "))
	print("RELEASE_SMOKE ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--smoke-capture="):
			var folder := argument.trim_prefix("--smoke-capture=")
			DirAccess.make_dir_recursive_absolute(folder)
			for frame: int in 5: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join(name+".png"))

func _check(condition: bool, id: String) -> void:
	checks += 1
	if not condition: failures.append(id)

func _matches_packaged_art(texture: Texture2D, letter: String, pixels: int) -> bool:
	if texture==null: return false
	var path := Content.icon_asset_path(letter)
	if not ResourceLoader.exists(path,"Texture2D"): return false
	var source: Texture2D=load(path)
	if source==null: return false
	var expected := source.get_image()
	if expected==null or expected.is_empty(): return false
	if expected.is_compressed() and expected.decompress()!=OK: return false
	expected.resize(pixels,pixels,Image.INTERPOLATE_LANCZOS)
	var actual := texture.get_image()
	return actual!=null and actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data()

func _find_named_button(node: Node, caption: String) -> Button:
	if node is Button and node.text==caption: return node
	for child: Node in node.get_children():
		var found := _find_named_button(child,caption)
		if found!=null: return found
	return null
