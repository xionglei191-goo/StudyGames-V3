extends "res://tests/test_building_residents.gd"
## Continuous native preview: human, robe, robot, quadruped, bird and fish.

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.get_node("State").save_path = "user://validation-expansion-motion-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(output)
	_make_stage()
	root.size = Vector2i(1440, 810)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 8.0
	var frame_number := 0
	var groups := [
		{"label": "人物、长袍与机器人 · Amy / Confucius / Robbie", "ids": ["textbook_amy", "textbook_confucius", "textbook_robbie"]},
		{"label": "四足、鸟类与鱼类 · Bunny / Kelly / Baker / Fendi", "ids": ["textbook_bunny", "textbook_kelly", "textbook_baker_bird", "textbook_fendi"]}
	]
	for group: Dictionary in groups:
		var actors: Array[Node3D] = []
		for i: int in range(group.ids.size()):
			var actor: Node3D = Actor.new()
			if not actor.configure(str(group.ids[i])):
				quit(1)
				return
			stage.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.position.x = (float(i) - float(group.ids.size()-1)*.5) * 2.0
			actor.name_label.visible = false
			actor.face(actor.global_position + Vector3(0, 0, 3), true)
			actors.append(actor)
		var center_y := 1.1 if group.ids.size() == 3 else .75
		camera.size = 8.0 if group.ids.size() == 3 else 8.6
		for phase: Dictionary in [{"id":"idle", "label":"待机", "seconds":1.0}, {"id":"walk", "label":"行走 / 游泳", "seconds":3.0}, {"id":"greet_wave", "label":"招呼", "seconds":2.2}, {"id":"pose_photo", "label":"拍照姿势", "seconds":2.4}]:
			caption.text = "%s\n%s · Godot 原生动作" % [group.label, phase.label]
			for actor: Node3D in actors:
				actor.animation_player.play("normal/"+str(phase.id), 0.0)
				actor.animation_player.advance(0.0)
			for frame: int in range(ceili(float(phase.seconds)*24.0)):
				var at := float(frame)/24.0
				for actor: Node3D in actors:
					var clip: Animation = actor.animation_player.get_animation("normal/"+str(phase.id))
					actor.animation_player.seek(fmod(at,clip.length) if phase.id == "walk" else minf(at,clip.length), true, true)
					actor.skeleton.force_update_all_bone_transforms()
				# A shallow orbit makes the depth of knees, sleeves and tails readable.
				var angle := sin(float(frame_number)/24.0*.35)*.25
				camera.position = Vector3(sin(angle)*9, center_y+.65, cos(angle)*9)
				camera.look_at(Vector3(0, center_y, 0))
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("frame-%04d.png" % frame_number))
				frame_number += 1
		for actor: Node3D in actors: actor.free()
	print("EXPANSION_MOTION_CAPTURE_DONE ", frame_number)
	quit(0)
