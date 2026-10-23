extends Node3D
## Additive runtime presentation; this module never edits source meshes/materials,
## collision shapes, marker transforms, learning timestamps, days or task rewards.

signal semantic_event(character_id: String, action_id: String, event_key: String)
signal actors_changed

const ActorScript = preload("res://scripts/textbook_actor.gd")
const WaterShader = preload("res://shaders/living_water.gdshader")
const ACTOR_CATALOG_PATH := "res://assets/living/textbook_actor_catalog.json"
const WEATHER_IDS := ["clear", "cloudy", "light_rain", "mist"]
const DAY_PHASES := ["dawn", "day", "dusk", "night"]
const OUTDOOR_ROOMS := ["village", "school", "playground", "football_field", "landmark_A", "landmark_B", "landmark_F", "home_estate", "home_balcony"]
const CORE_IDS := ["textbook_lingling", "textbook_peter", "textbook_anne", "textbook_mingming", "textbook_dongdong", "textbook_tim", "textbook_dino"]
const RAIN_COUNT := 96
const WEATHER_LABELS := {"clear":"晴", "cloudy":"多云", "light_rain":"小雨", "mist":"薄雾"}
const PHASE_LABELS := {"dawn":"清晨", "day":"白昼", "dusk":"黄昏", "night":"夜晚"}

var room_id := ""
var world_time := 0.0
var performance_time := 0.0
var weather_id := "clear"
var day_phase := "day"
var context: Dictionary = {}
var _world: Node3D
var _world_info: Dictionary = {}
var _player: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _baseline: Dictionary = {}
var _foliage: Array[Dictionary] = []
var _water: Array[Dictionary] = []
var _actors: Dictionary = {}
var _interaction_views: Array[Array] = []
var _world_running := true
var _performance_running := true
var _focus_backgrounded := false
var _day_cycle_seconds := 600.0
var _weather_seconds := 0.0
var _weather_cycle_index := 0
var _rain: MultiMeshInstance3D
var _rain_bases := PackedVector3Array()
var _rain_floors := PackedFloat32Array()
var _rain_roof_cursor := 0
var _rain_anchor := Vector3.ZERO
var _rain_needs_shelter_scan := true
var _configured := false
var _spawn_failures: Array[String] = []
var _actor_catalog: Dictionary = {}
var environment_effects_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_actor_catalog()

func _load_actor_catalog() -> void:
	if not _actor_catalog.is_empty() or not FileAccess.file_exists(ACTOR_CATALOG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTOR_CATALOG_PATH))
	if parsed is Dictionary:
		_actor_catalog = parsed as Dictionary

func get_actor_catalog() -> Dictionary:
	_load_actor_catalog()
	return _actor_catalog.duplicate(true)

func set_environment_effects_enabled(enabled: bool) -> void:
	environment_effects_enabled = enabled
	if not _configured:
		return
	_update_foliage()
	_update_water()
	_update_rain()

func configure(world: Node3D, next_room: String, settings: Dictionary = {}) -> Dictionary:
	_release_targets()
	_clear_actors()
	if is_instance_valid(_rain):
		_rain.queue_free()
		_rain = null
	_world = world
	room_id = next_room
	context.merge(settings, true)
	_world_info = settings.get("world_info", {}) as Dictionary
	_player = settings.get("player", null) as Node3D
	_spawn_failures.clear()
	_capture_lighting()
	_capture_visual_targets()
	_build_rain()
	_configured = true
	_update_clock_flags()
	_apply_lighting(1.0)
	_update_foliage()
	_update_water()
	if bool(settings.get("spawn_core_actors", true)):
		var requested: Array = []
		if settings.has("actor_ids"):
			requested = settings.actor_ids as Array
		elif room_id == "home":
			requested = ["npc_bear_uncle"]
		elif room_id == "school":
			requested = ["textbook_lingling", "textbook_peter", "textbook_anne"]
		elif room_id == "classroom":
			requested = ["textbook_mingming", "textbook_dongdong", "textbook_tim", "textbook_dino"]
		_spawn_from_markers(requested)
	return get_status()

func prepare_room_change() -> void:
	# Call before the host removes the old world children. This closes the two
	# physics-frame window between world.build() and the next configure().
	_configured = false
	_release_targets()
	_clear_actors()
	if is_instance_valid(_rain):
		_rain.visible = false

func set_context(patch: Dictionary) -> void:
	var previous_story_phase := str(context.get("story_day_phase", ""))
	var previous_story_weather := str(context.get("story_weather", ""))
	context.merge(patch, true)
	if patch.has("player"):
		_player = patch.player as Node3D
	_update_clock_flags()
	if _configured and (previous_story_phase != str(context.get("story_day_phase", "")) or previous_story_weather != str(context.get("story_weather", ""))):
		# Semantic story lighting must be visible while dialogue freezes world time.
		# Clearing the override restores the comfort preferences immediately.
		_apply_lighting(1.0)
		_update_rain()
	if _configured and patch.has("reduced_motion"):
		_update_foliage()
		_update_water()
		_update_rain()

func set_weather(value: String, immediate: bool = false) -> bool:
	if not value in WEATHER_IDS:
		return false
	weather_id = value
	_weather_seconds = 0.0
	if immediate and _configured:
		_apply_lighting(1.0)
		_update_rain()
	return true

func set_day_phase(value: String, immediate: bool = false) -> bool:
	if not value in DAY_PHASES:
		return false
	day_phase = value
	_day_cycle_seconds = {"dawn":60.0, "day":600.0, "dusk":1500.0, "night":1900.0}[value]
	if immediate and _configured:
		_apply_lighting(1.0)
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_backgrounded = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_backgrounded = false

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not _configured:
		return
	_update_clock_flags()
	var step := clampf(delta, 0.0, 0.1)  # Never catch up a backgrounded/offline interval.
	if _performance_running:
		performance_time += step
	if not _world_running:
		return
	world_time += step
	if bool(context.get("auto_cycle", true)) and not bool(context.get("guided_prologue", false)):
		if not bool(context.get("fixed_day", false)):
			_day_cycle_seconds = fmod(_day_cycle_seconds + step, 2160.0)
			day_phase = "dawn" if _day_cycle_seconds < 240.0 else "day" if _day_cycle_seconds < 1440.0 else "dusk" if _day_cycle_seconds < 1680.0 else "night"
		if not bool(context.get("fixed_weather", false)):
			_weather_seconds += step
			if _weather_seconds >= 480.0:
				var sequence := ["clear", "cloudy", "light_rain", "cloudy", "clear", "mist"]
				_weather_cycle_index = (_weather_cycle_index + 1) % sequence.size()
				weather_id = str(sequence[_weather_cycle_index])
				_weather_seconds = 0.0
	if environment_effects_enabled:
		_update_foliage()
		_update_water()
		_update_rain()
	_apply_lighting(1.0 - exp(-step / 4.0))

func _update_clock_flags() -> void:
	var hard_pause := bool(context.get("paused", false)) or bool(context.get("backgrounded", false)) or _focus_backgrounded
	if is_inside_tree():
		hard_pause = hard_pause or get_tree().paused
	_performance_running = not hard_pause
	_world_running = not hard_pause and not (bool(context.get("dialogue_open", false)) or bool(context.get("learning_open", false)) or bool(context.get("memory_open", false)))
	var active: Array = context.get("active_actor_ids", []) as Array
	var normalized: Array[String] = []
	for id: Variant in active:
		normalized.append(ActorScript.canonical_id(str(id)))
	for id: String in _actors:
		var actor: Variant = _actors[id]
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			actor.set_clock_state(_world_running, _performance_running, id in normalized, bool(context.get("reduced_motion", false)))

func _effective_weather() -> String:
	var story_weather := str(context.get("story_weather", ""))
	if story_weather in WEATHER_IDS:
		return story_weather
	return "clear" if bool(context.get("fixed_weather", false)) or bool(context.get("guided_prologue", false)) else weather_id

func _effective_phase() -> String:
	var story_phase := str(context.get("story_day_phase", ""))
	if story_phase in DAY_PHASES:
		return story_phase
	return "day" if bool(context.get("fixed_day", false)) or bool(context.get("guided_prologue", false)) else day_phase

func _capture_lighting() -> void:
	_environment = null
	_sun = null
	_fill = null
	_baseline.clear()
	if not is_instance_valid(_world):
		return
	for child: Node in _world.get_children():
		if child is WorldEnvironment:
			_environment = (child as WorldEnvironment).environment
		elif child is DirectionalLight3D:
			if _sun == null:
				_sun = child as DirectionalLight3D
			else:
				_fill = child as DirectionalLight3D
	if _environment:
		_baseline = {"background":_environment.background_color, "ambient_color":_environment.ambient_light_color,
			"ambient_energy":_environment.ambient_light_energy, "fog_enabled":_environment.fog_enabled,
			"fog_density":_environment.fog_density, "fog_light_color":_environment.fog_light_color,
			"fog_sky_affect":_environment.fog_sky_affect}
	if is_instance_valid(_sun):
		_baseline.sun_color = _sun.light_color
		_baseline.sun_energy = _sun.light_energy
		_baseline.sun_rotation = _sun.rotation_degrees
	if is_instance_valid(_fill):
		_baseline.fill_color = _fill.light_color
		_baseline.fill_energy = _fill.light_energy

func _apply_lighting(blend: float) -> void:
	if _environment == null or _baseline.is_empty():
		return
	var weather := _effective_weather()
	var phase := _effective_phase()
	var outdoor := room_id in OUTDOOR_ROOMS
	var phase_colors := {"dawn":Color("e6d8bf"), "day":Color("e8eee6"), "dusk":Color("dbc9c3"), "night":Color("b5c4d2")}
	var sky_colors := {"dawn":Color("e3ddc9"), "day":Color("d5e2d6"), "dusk":Color("d8c7bc"), "night":Color("8c9fb4")}
	var ambient: Color = phase_colors[phase]
	var sky: Color = sky_colors[phase]
	var direct_scale := float({"dawn":0.78, "day":1.0, "dusk":0.72, "night":0.34}[phase])
	var ambient_scale := float({"dawn":0.94, "day":1.0, "dusk":0.92, "night":0.80}[phase])
	if weather in ["cloudy", "light_rain", "mist"]:
		ambient = ambient.lerp(Color("c9d5d4"), 0.30)
		sky = sky.lerp(Color("b4c5c6"), 0.45)
		direct_scale *= 0.65 if weather == "cloudy" else 0.48
	# Interior teaching surfaces keep a neutral, readable fill even at night.
	if not outdoor:
		ambient = (_baseline.ambient_color as Color).lerp(ambient, 0.25)
		sky = (_baseline.background as Color).lerp(sky,0.16)
		ambient_scale = maxf(ambient_scale, 0.92)
	_environment.background_color = _environment.background_color.lerp(sky, blend)
	_environment.ambient_light_color = _environment.ambient_light_color.lerp(ambient, blend)
	_environment.ambient_light_energy = lerpf(_environment.ambient_light_energy, float(_baseline.ambient_energy) * ambient_scale, blend)
	var fog_target := 0.006 if weather == "mist" and outdoor else 0.0015 if weather == "light_rain" and outdoor else 0.0
	_environment.fog_density = lerpf(_environment.fog_density if _environment.fog_enabled else 0.0, fog_target, blend)
	_environment.fog_enabled = _environment.fog_density > 0.00005
	_environment.fog_light_color = _environment.fog_light_color.lerp(sky, blend)
	_environment.fog_sky_affect = 0.18
	if is_instance_valid(_sun):
		var sunlight := Color("fff8e9") if phase == "day" else Color("efc6a1") if phase in ["dawn", "dusk"] else Color("c0cfe1")
		_sun.light_color = _sun.light_color.lerp(sunlight, blend)
		_sun.light_energy = lerpf(_sun.light_energy, float(_baseline.get("sun_energy", 0.25)) * direct_scale, blend)
		var pitch := -27.0 if phase == "dawn" else -52.0 if phase == "day" else -23.0 if phase == "dusk" else -42.0
		_sun.rotation_degrees.x = lerpf(_sun.rotation_degrees.x, pitch, blend)
	if is_instance_valid(_fill):
		_fill.light_color = _fill.light_color.lerp(Color("dbe5e7") if phase != "night" else Color("bdcadb"), blend)
		_fill.light_energy = float(_baseline.get("fill_energy", 0.10))

func _capture_visual_targets() -> void:
	if not is_instance_valid(_world):
		return
	for node: Node in _world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		var label := str(mesh.name)
		var is_tree_crown := "Tree" in label and ("Canopy" in label or "Crown" in label)
		if is_tree_crown and not label.begins_with("SG_"):
			var box := mesh.get_aabb()
			var local_wind := mesh.global_basis.inverse() * Vector3(0.75, 0, 0.66)
			var axis := Vector3(-local_wind.z, 0, local_wind.x).normalized()
			if axis.length_squared() < 0.1:
				axis = Vector3.RIGHT
			_foliage.append({"node":mesh, "transform":mesh.transform,
				"pivot":Vector3(box.get_center().x, box.position.y, box.get_center().z),
				"axis":axis, "phase":float(absi(label.hash()) % 6283) / 1000.0})
		if label in ["ALPHA_River_Water", "ALPHA_V3_Lake_Deep_To_Shallow", "ALPHA_Ocean_Presentation", "Harbour_Water", "A_Wash_Water"] and mesh.material_overlay == null:
			var material := ShaderMaterial.new()
			material.shader = WaterShader
			material.set_shader_parameter("flow_direction", Vector2(0.18, 1.0) if "River" in label else Vector2(0.66, 0.45))
			_water.append({"node":mesh, "overlay":mesh.material_overlay, "material":material})
			mesh.material_overlay = material

func _update_foliage() -> void:
	var reduced := bool(context.get("reduced_motion", false))
	var wind_strength := 0.010 if _effective_weather() == "clear" else 0.014
	for item: Dictionary in _foliage:
		if not is_instance_valid(item.get("node")):
			continue
		var node := item.node as MeshInstance3D
		var pivot: Vector3 = item.pivot
		var phase := float(item.phase)
		var angle := 0.0 if reduced or not environment_effects_enabled else sin(world_time * 0.64 + phase) * wind_strength * (0.78 + sin(world_time * 0.13) * 0.22)
		var rotation := Basis(item.axis as Vector3, angle)
		node.transform = (item.transform as Transform3D) * Transform3D(rotation, pivot - rotation * pivot)

func _update_water() -> void:
	for item: Dictionary in _water:
		if not is_instance_valid(item.get("node")) or not is_instance_valid(item.get("material")):
			continue
		var material := item.material as ShaderMaterial
		var node := item.node as MeshInstance3D
		if not environment_effects_enabled:
			if node.material_overlay == material:
				node.material_overlay = item.overlay as Material
			continue
		if node.material_overlay == item.overlay:
			node.material_overlay = material
		material.set_shader_parameter("world_time", world_time)
		material.set_shader_parameter("ripple_strength", 0.0 if bool(context.get("reduced_motion", false)) else 0.65)

func _build_rain() -> void:
	_rain_bases.clear()
	_rain_floors.clear()
	_rain = MultiMeshInstance3D.new()
	_rain.name = "LocalGentleRain"
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drops := MultiMesh.new()
	drops.transform_format = MultiMesh.TRANSFORM_3D
	var drop := CylinderMesh.new()
	drop.top_radius = 0.008
	drop.bottom_radius = 0.008
	drop.height = 0.24
	drop.radial_segments = 4
	drops.mesh = drop
	drops.instance_count = RAIN_COUNT
	_rain.multimesh = drops
	var rain_material := StandardMaterial3D.new()
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.albedo_color = Color(0.70, 0.81, 0.84, 0.48)
	_rain.material_override = rain_material
	add_child(_rain)
	for index: int in range(RAIN_COUNT):
		var x := float((index * 37) % 101) / 101.0 * 15.0 - 7.5
		var z := float((index * 59 + 11) % 103) / 103.0 * 15.0 - 7.5
		_rain_bases.append(Vector3(x, float((index * 13) % 97) / 97.0, z))
		_rain_floors.append(0.0)
	_rain.visible = false
	_rain_roof_cursor = 0
	_rain_needs_shelter_scan = true

func _update_rain() -> void:
	if not is_instance_valid(_rain):
		return
	_rain.visible = environment_effects_enabled and _effective_weather() == "light_rain" and room_id in OUTDOOR_ROOMS and not bool(context.get("reduced_motion", false))
	if not _rain.visible:
		return
	var focus := _player.global_position if is_instance_valid(_player) else _marker_position("SG_SPAWN")
	if _rain_needs_shelter_scan or focus.distance_squared_to(_rain_anchor) > 2.25:
		_rain_anchor = focus
		_rain_roof_cursor = 0
		_rain_needs_shelter_scan = true
	_rain.global_position = _rain_anchor
	var space := get_world_3d().direct_space_state
	# Scan all columns before first display or after a move, then refresh four per
	# frame. A newly visible shower must never start below an unscanned roof.
	var refresh_count := RAIN_COUNT if _rain_needs_shelter_scan else 4
	for offset: int in range(refresh_count):
		var index := (_rain_roof_cursor + offset) % RAIN_COUNT
		var base: Vector3 = _rain_bases[index]
		var point := _rain_anchor + Vector3(base.x, 0, base.z)
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 14.0, point + Vector3.DOWN * 10.0, 5)
		var hit := space.intersect_ray(ray)
		_rain_floors[index] = float(hit.position.y) - _rain_anchor.y + 0.15 if not hit.is_empty() else 0.0
	_rain_roof_cursor = (_rain_roof_cursor + refresh_count) % RAIN_COUNT
	_rain_needs_shelter_scan = false
	for index: int in range(RAIN_COUNT):
		var base: Vector3 = _rain_bases[index]
		var height := maxf(1.0, 8.0 - _rain_floors[index])
		var y := _rain_floors[index] + (1.0 - fmod(base.y + world_time * 0.38, 1.0)) * height
		_rain.multimesh.set_instance_transform(index, Transform3D(Basis.from_euler(Vector3(0, 0, -0.08)), Vector3(base.x, y, base.z)))

func _spawn_from_markers(requested: Array) -> void:
	var base := _marker_position("SG_NPC_HOST")
	if not _has_marker("SG_NPC_HOST"):
		base = _marker_position("SG_SPAWN")
	for requested_id: Variant in requested:
		var id := ActorScript.canonical_id(str(requested_id))
		var found := false
		for radius: float in [2.6, 3.8, 5.2, 6.6]:
			for index: int in range(16):
				var angle := float(index) * TAU / 16.0 + 0.20
				var point := base + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
				var floor_hit := _find_spawn_floor(point)
				if floor_hit.is_empty():
					continue
				point = floor_hit.position as Vector3
				if not _spawn_clear(point):
					continue
				var actor := spawn_actor(id, point + Vector3.UP * 0.02, {"validate_position":false})
				if actor:
					actor.face(base + Vector3(0, 0, 5))
					found = true
				break
			if found:
				break
		if not found:
			_spawn_failures.append(id)
			push_warning("No safe existing-marker area found for " + id + " in " + room_id)

func _has_marker(marker_name: String) -> bool:
	return (_world_info.get("marker_nodes", {}) as Dictionary).has(marker_name)

func _marker_position(marker_name: String) -> Vector3:
	var markers: Dictionary = _world_info.get("marker_nodes", {})
	var marker: Variant = markers.get(marker_name, null)
	if marker is Node3D and is_instance_valid(marker):
		return (marker as Node3D).global_position
	if marker is Dictionary and (marker as Dictionary).get("position") is Vector3:
		return _world.to_global((marker as Dictionary).position)
	var point: Vector3 = _world_info.get("spawn", Vector3.ZERO)
	return _world.to_global(point) if is_instance_valid(_world) else point

func _find_spawn_floor(point: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 6.0, point + Vector3.DOWN * 5.0, 4)
	var ground := space.intersect_ray(ray)
	if ground.is_empty() or (ground.normal as Vector3).y < 0.82:
		return {}
	var water_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 7.0, point + Vector3.DOWN * 6.0, 8)
	var water := space.intersect_ray(water_ray)
	if not water.is_empty() and float(ground.position.y) < float(water.position.y) - 0.002:
		return {}
	return ground

func _spawn_clear(point: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.0)
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	for entry: Dictionary in _world_info.get("interactions", []):
		var location: Vector3 = entry.get("position", Vector3.ZERO)
		if Vector2(point.x - location.x, point.z - location.z).length() < 1.5:
			return false
	for actor: Variant in _actors.values():
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.global_position.distance_to(point) < 1.55:
			return false
	if is_instance_valid(_player) and _player.global_position.distance_to(point) < 1.5:
		return false
	return true

func spawn_actor(id: String, world_position: Vector3, options: Dictionary = {}) -> Node3D:
	var canonical := ActorScript.canonical_id(id)
	if not ActorScript.supports(canonical):
		push_warning("No reviewed prototype for " + canonical + "; source roster remains pending, no guessed appearance created.")
		return null
	if _actors.has(canonical) and is_instance_valid(_actors[canonical]):
		return _actors[canonical] as Node3D
	if bool(options.get("validate_position", true)) and not _spawn_clear(world_position):
		return null
	var actor: CharacterBody3D = ActorScript.new()
	var actor_options := options.duplicate(true)
	actor_options.reduced_motion = bool(context.get("reduced_motion", false))
	if not actor.configure(canonical, actor_options):
		actor.queue_free()
		return null
	add_child(actor)
	actor.global_position = world_position
	actor.semantic_event.connect(_on_actor_semantic_event)
	_actors[canonical] = actor
	_update_clock_flags()
	actors_changed.emit()
	return actor

func get_actor(id: String) -> Node3D:
	var value: Variant = _actors.get(ActorScript.canonical_id(id), null)
	if not is_instance_valid(value) or value.is_queued_for_deletion():
		return null
	return value as Node3D

func remove_actor(id: String) -> void:
	var canonical := ActorScript.canonical_id(id)
	var value: Variant = _actors.get(canonical,null)
	_actors.erase(canonical)
	for entries: Array in _interaction_views:
		_remove_actor_interactions(entries, canonical)
	if is_instance_valid(value):
		var actor := value as Node3D
		if actor.get_parent() == self:
			remove_child(actor)
		actor.queue_free()
	actors_changed.emit()

func play_actor_action(id: String, action_id: String, event_key: String = "", options: Dictionary = {}) -> bool:
	var actor := get_actor(id)
	if not is_instance_valid(actor):
		return false
	var active: Array = context.get("active_actor_ids", []) as Array
	if not str(actor.character_id) in active:
		active.append(str(actor.character_id))
	context.active_actor_ids = active
	_update_clock_flags()
	return bool(actor.play_action(action_id, event_key,options))

func _on_actor_semantic_event(id: String, action_id: String, event_key: String) -> void:
	semantic_event.emit(id, action_id, event_key)

func get_interactions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor: Variant in _actors.values():
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			result.append(actor.get_interaction())
	return result

func _remove_actor_interactions(entries: Array, canonical: String = "") -> void:
	for index: int in range(entries.size() - 1, -1, -1):
		if not entries[index] is Dictionary:
			continue
		var entry: Dictionary = entries[index]
		if entry.get("type") == "textbook_actor" and (canonical.is_empty() or str(entry.get("character_id", "")) == canonical):
			entries.remove_at(index)

func refresh_interactions(entries: Array) -> void:
	# Retain the caller's array reference so removal clears its interaction rows
	# before queue_free runs at frame end; unrelated original NPC entries stay put.
	var known_view := false
	for view: Array in _interaction_views:
		if is_same(view, entries):
			known_view = true
			break
	if not known_view:
		_interaction_views.append(entries)
	var present: Dictionary = {}
	for index: int in range(entries.size() - 1, -1, -1):
		if not entries[index] is Dictionary:
			continue
		var entry: Dictionary = entries[index]
		if entry.get("type") != "textbook_actor":
			continue
		# A freed Object cannot even be cast to Node3D. Validate the Variant first.
		var value: Variant = entry.get("actor_ref")
		if not is_instance_valid(value):
			entries.remove_at(index)
			continue
		var actor := value as Node3D
		var canonical := str(entry.get("character_id", ""))
		if actor == null or actor.is_queued_for_deletion() or not is_same(_actors.get(canonical, null), actor):
			entries.remove_at(index)
			continue
		entry.position = actor.global_position
		present[str(entry.id)] = true
	for entry: Dictionary in get_interactions():
		if not present.has(str(entry.id)):
			entries.append(entry)

func get_status() -> Dictionary:
	var actor_status: Array[Dictionary] = []
	for actor: Variant in _actors.values():
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			actor_status.append(actor.get_status())
	return {"room_id":room_id, "world_time":world_time, "performance_time":performance_time,
		"world_running":_world_running, "performance_running":_performance_running,
		"weather":_effective_weather(), "weather_requested":weather_id, "weather_label":WEATHER_LABELS[_effective_weather()],
		"day_phase":_effective_phase(), "phase_label":PHASE_LABELS[_effective_phase()],
		"foliage_count":_foliage.size(), "water_count":_water.size(), "rain_visible":is_instance_valid(_rain) and _rain.visible,
		"rain_instances":RAIN_COUNT, "actors":actor_status, "spawn_failures":_spawn_failures.duplicate(),
		"actor_visual_status":"rigid_bone_prototypes_not_skinned", "source_geometry_modified":false,
		"learning_or_day_state_written":false, "all_textbook_roster_produced":false,
		"registered_identity_count":int(_actor_catalog.get("source_identity_count",0)),
		"registered_textbook_identity_count":int(_actor_catalog.get("textbook_identity_count",0)),
		"available_prototype_count":ActorScript.PROFILES.size(),
		"environment_effects_enabled":environment_effects_enabled}

func _clear_actors() -> void:
	for entries: Array in _interaction_views:
		_remove_actor_interactions(entries)
	_interaction_views.clear()
	for actor: Variant in _actors.values():
		if is_instance_valid(actor):
			remove_child(actor)
			actor.queue_free()
	_actors.clear()

func _release_targets() -> void:
	for item: Dictionary in _foliage:
		if is_instance_valid(item.get("node")):
			(item.node as Node3D).transform = item.transform as Transform3D
	for item: Dictionary in _water:
		if is_instance_valid(item.get("node")):
			(item.node as MeshInstance3D).material_overlay = item.overlay as Material
	_foliage.clear()
	_water.clear()
	if _environment and not _baseline.is_empty():
		_environment.background_color = _baseline.background
		_environment.ambient_light_color = _baseline.ambient_color
		_environment.ambient_light_energy = float(_baseline.ambient_energy)
		_environment.fog_enabled = bool(_baseline.fog_enabled)
		_environment.fog_density = float(_baseline.fog_density)
		_environment.fog_light_color = _baseline.fog_light_color
		_environment.fog_sky_affect = float(_baseline.fog_sky_affect)
	if is_instance_valid(_sun) and _baseline.has("sun_color"):
		_sun.light_color = _baseline.sun_color
		_sun.light_energy = float(_baseline.sun_energy)
		_sun.rotation_degrees = _baseline.sun_rotation
	if is_instance_valid(_fill) and _baseline.has("fill_color"):
		_fill.light_color = _baseline.fill_color
		_fill.light_energy = float(_baseline.fill_energy)

func _exit_tree() -> void:
	_release_targets()
