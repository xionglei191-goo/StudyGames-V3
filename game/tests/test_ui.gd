extends SceneTree
## Actual GUI mouse dispatch, layout and learning integration with an isolated save.
## Godot --headless --fixed-fps 60 --path game --script res://tests/test_ui.gd -- --test-harness

var _game: Node
var _state: Node
var _failures: Array[String] = []
var _checks: int = 0
var _save_path: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-harness"):
		push_error("UI tests require -- --test-harness to isolate gameplay state.")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	_game = scene.instantiate()
	root.add_child(_game)
	for frame: int in range(300):
		await process_frame
		if _game.scene_ready:
			break
	_check(_game.scene_ready, "Main scene becomes ready")
	if not _game.scene_ready:
		_finish()
		return
	_state = root.get_node("State")
	_check(str(_state.save_path).begins_with("user://validation-"), "Harness avoided the player's save")
	_save_path = "user://ui-tests-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_state.save_path = _save_path
	_state.data = _state._default_state()
	_game.muted = true
	_game._refresh()
	_game.show_welcome()
	await _layout()
	_check_panel("welcome 1440x900")
	_check_font_and_colors()
	await _click_text("开始今天的生活")
	_check(not _game.ui.modal.visible, "Clicking welcome start closes the modal")

	_game.show_bag()
	await _layout()
	_check_panel("wardrobe 1440x900")
	await _click_text("草莓粉")
	_check(_state.data.outfit == "pink", "Mouse click changes outfit to pink")
	_game.show_shop()
	await _layout()
	await _click_text("25 叶币 · 看看")
	for frame: int in range(300):
		await process_frame
		if _game.ui.current_panel == "purchase":
			break
	await _layout()
	_check(not _state.data.decorations_owned.flower_box, "Preview does not purchase the flower box")
	await _click_text("买下并摆好")
	_check(bool(_state.data.decorations_owned.flower_box), "Mouse click buys the flower box")
	_check(int(_state.data.coins) == 5, "Purchase deducted the listed 25 leaf coins")
	await _game.show_decorate()
	await _layout()
	_check(bool(_state.data.decorations_placed.flower_box), "Mouse click places the flower box")
	await _click_text("窗边花箱", true)
	await _click_text("确认收起")
	_check(not _state.data.decorations_placed.flower_box, "Confirm removes the decoration")
	await _click_text("窗边花箱", true)
	await _click_text("确认摆放")
	_check(bool(_state.data.decorations_placed.flower_box), "Preview confirmation restores the flower box")
	await _game.change_room("home")
	await _layout()
	var flowers: Node = _game.world.find_child("SG_DECOR_MODEL_FLOWER_BOX", true, false)
	if flowers == null:
		flowers = _game.world.get_node_or_null("DecorationWindowFlowers")
	_check(flowers != null and flowers.visible, "Placed flower-box geometry is visible after entering home")

	_game.start_unit(1)
	await _layout()
	_check_panel("unhinted lesson 1440x900")
	var transcript: String = str(_game.quiz_current.prompt)
	_check(not _panel_prose().contains(transcript), "Unhinted heading/body do not reveal the answer transcript")
	_check(_game.ui.panel_box.get_child(1).text == "听听朋友的话", "Unhinted lesson uses a neutral heading")
	await _click_text("显示中文提示")
	_check(_game.quiz_hinted, "Mouse click reveals a Chinese hint")
	_check(_state._active_assisted, "Hint click marks the current attempt as assisted")
	_check(_panel_prose().contains(transcript), "Hinted lesson shows the transcript explicitly")
	var correct_text: String = ""
	for choice: Dictionary in _game.quiz_current.choices:
		if str(choice.id) == str(_game.quiz_current.answer):
			correct_text = str(choice.text) + "  /  " + str(choice.zh)
	await _click_text(correct_text)
	var question_id: String = str(_game.quiz_current.id)
	var record: Dictionary = _state.data.learning.get(question_id, {})
	_check(int(record.get("assisted", 0)) == 1, "Correct mouse choice after hint records one assisted success")
	_check(int(record.get("independent", 0)) == 0, "Hinted mouse answer is not recorded as independent")
	_check(_game.ui.current_panel == "correct", "Correct answer advances to feedback panel")

	root.size = Vector2i(960, 640)
	await _layout()
	_game.show_welcome()
	await _layout()
	_check_panel("welcome 960x640")
	_game.show_map()
	await _layout()
	_check_panel("home map 960x640")
	_game.show_bag()
	await _layout()
	_check_panel("wardrobe 960x640")
	_game.start_unit(1)
	await _layout()
	_check_panel("lesson 960x640")
	_check_font_and_colors()
	print("UI_TEST_VIEWPORT logical=%s physical=%s" % [str(root.get_visible_rect()), str(root.size)])
	_game._close()
	_finish()


func _layout() -> void:
	await process_frame
	await process_frame


func _button(text: String, prefix: bool = false) -> Button:
	for node: Node in _game.ui.panel_box.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if (button.text.begins_with(text) if prefix else button.text == text):
			return button
	return null


func _click_text(text: String, prefix: bool = false) -> void:
	var button: Button = _button(text, prefix)
	_check(button != null, "Visible button exists: " + text)
	if button == null:
		return
	_check(not button.disabled and button.is_visible_in_tree(), "Button is enabled: " + text)
	if button.disabled or not button.is_visible_in_tree():
		return
	var center: Vector2 = button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(center), "Button center is inside the viewport: " + text)
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = center
	press.global_position = center
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	Input.parse_input_event(release)
	await _layout()


func _panel_prose() -> String:
	var text := ""
	# Only direct Label children are heading/body/footnote; choices are legitimate answers.
	for child: Node in _game.ui.panel_box.get_children():
		if child is Label:
			text += (child as Label).text + "\n"
	return text


func _check_panel(context: String) -> void:
	var visible: Rect2 = root.get_visible_rect().grow(1.0)
	var rectangle: Rect2 = _game.ui.panel.get_global_rect()
	_check(visible.encloses(rectangle), "Panel fits viewport: %s (%s within %s)" % [context, rectangle, visible])
	_check(_game.ui.modal.visible, "Panel is open: " + context)
	# Scroll containers may intentionally clip later actions; that is not a layout failure.
	for child: Node in _game.ui.panel_box.get_children():
		if child is Label:
			_check(rectangle.grow(1.0).encloses((child as Label).get_global_rect()), "Panel prose fits: " + context)


func _check_font_and_colors() -> void:
	var heading: Label = _game.ui.panel_box.get_child(1) as Label
	_check(heading.get_theme_font("font").resource_path == "res://assets/fonts/IslandSans.otf", "Heading uses the bundled font")
	_check(heading.get_theme_color("font_color").is_equal_approx(_game.ui.ink), "Heading uses the intended ink color")
	for node: Node in _game.ui.panel_box.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.disabled:
			_check(button.get_theme_color("font_focus_color").is_equal_approx(button.get_theme_color("font_color")), "Focus preserves button text color: " + button.text)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if not _save_path.is_empty():
		for suffix: String in ["", ".bak", ".tmp"]:
			var path: String = _save_path + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure: String in _failures:
		push_error(failure)
	print("UI_TEST_RESULT checks=%d failures=%d actual_mouse_dispatch=true" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
