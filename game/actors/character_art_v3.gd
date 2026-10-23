extends RefCounted
## Versioned character skins. Gameplay identity and action semantics stay stable.

const REVISION := "storybook-character-v3"
const MANIFEST_PATH := "res://assets/characters/storybook_v3/manifest.json"
const ACTIVE_SET_PATH := "res://assets/characters/active-set.json"
const GROUNDING_PATH := "res://assets/characters/tripo_v1/grounding.json"
const GESTURE_PATH := "res://assets/characters/tripo_v1/gesture-overrides.json"
static var _manifest: Dictionary = {}
static var _manifest_override := ""
static var _grounding: Dictionary = {}
static var _gestures: Dictionary = {}
static var _skip_grounding := false

static func use_manifest(path: String) -> void:
	_manifest_override = path
	_manifest.clear()
	_grounding.clear()
	_gestures.clear()

static func manifest() -> Dictionary:
	var path := _manifest_override
	if path.is_empty() and FileAccess.file_exists(ACTIVE_SET_PATH):
		var active: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTIVE_SET_PATH))
		if active is Dictionary: path = str(active.get("manifest",MANIFEST_PATH))
	if path.is_empty(): path = MANIFEST_PATH
	if _manifest.is_empty() and FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

static func revision() -> String:
	return str(manifest().get("art_revision",REVISION))

static func character_entry(character_id: String) -> Dictionary:
	return manifest().get("characters",{}).get(character_id,{})

static func hand_socket(character_id: String, side: String) -> Vector3:
	var values: Array = character_entry(character_id).get("hand_sockets",{}).get(side,[])
	return Vector3(float(values[0]),float(values[1]),float(values[2])) if values.size()==3 else Vector3(0,-0.30,0.18)

static func adapt_library(character_id: String, library: AnimationLibrary, source_hips_height: float, reduced: bool = false) -> AnimationLibrary:
	var entry := character_entry(character_id)
	if str(entry.get("revision","")) != "tripo-character-v1": return library
	var target_hips := Vector3.ZERO
	for bone: Dictionary in entry.bones:
		if str(bone.name)=="Hips": target_hips=Vector3(float(bone.origin[0]),float(bone.origin[1]),float(bone.origin[2]))
	var offset := target_hips-Vector3(0,source_hips_height,0)
	var adapted := AnimationLibrary.new()
	for name: StringName in library.get_animation_list():
		var clip := library.get_animation(name).duplicate(true) as Animation
		for track: int in range(clip.get_track_count()):
			if clip.track_get_type(track)==Animation.TYPE_POSITION_3D and str(clip.track_get_path(track)).ends_with(":Hips"):
				for key: int in range(clip.track_get_key_count(track)):
					var value: Vector3 = clip.track_get_key_value(track,key)
					clip.track_set_key_value(track,key,value+offset)
			# The rabbit's fitted arm is shorter than the old proxy. Preserve the
			# basket contact envelope with a small shoulder reach at contact time.
			if character_id == "npc_rabbit_gardener" and str(name) == "place_item" and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and str(clip.track_get_path(track)).ends_with(":UpperArm_R"):
				for key: int in range(clip.track_get_key_count(track)):
					var time := clip.track_get_key_time(track,key)
					var amount := clampf(minf(time/1.1,(clip.length-time)/1.1),0.0,1.0)
					var rotation: Quaternion = clip.track_get_key_value(track,key)
					clip.track_set_key_value(track,key,Quaternion(Vector3.UP,deg_to_rad(-10.0)*amount)*Quaternion(Vector3.RIGHT,deg_to_rad(-10.0)*amount)*rotation)
		_apply_gesture(character_id,clip,str(name),reduced)
		if not _skip_grounding:
			_apply_grounding(character_id,clip,str(name),reduced)
		adapted.add_animation(name,clip)
	return adapted

static func _apply_gesture(character_id: String, clip: Animation, name: String, reduced: bool) -> void:
	if _gestures.is_empty() and FileAccess.file_exists(GESTURE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GESTURE_PATH))
		if parsed is Dictionary: _gestures = parsed
	var tracks: Array = _gestures.get("characters",{}).get(character_id,{}).get("reduced" if reduced else "normal",{}).get(name,[])
	var skeleton_path := ""
	for index: int in range(clip.get_track_count()):
		var path := str(clip.track_get_path(index))
		if path.ends_with(":UpperArm_R"): skeleton_path = path.get_slice(":",0)
	if skeleton_path.is_empty(): return
	# Every clip owns its wrist pose so interrupting a greeting cannot leave the
	# palm turned when an actor starts carrying, talking, or returning to idle.
	if tracks.is_empty():
		tracks = [{"bone":"Hand_R","keys":[{"time":0.0,"value":[0,0,0,1]},{"time":clip.length,"value":[0,0,0,1]}]}]
	for row: Dictionary in tracks:
		var path := NodePath(skeleton_path+":"+str(row.bone))
		var index := clip.find_track(path,Animation.TYPE_ROTATION_3D)
		if index < 0:
			index = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(index,path)
		for key: int in range(clip.track_get_key_count(index)-1,-1,-1): clip.track_remove_key(index,key)
		clip.track_set_interpolation_type(index,Animation.INTERPOLATION_LINEAR)
		for frame: Dictionary in row.get("keys",[]):
			var value: Array = frame.value
			clip.rotation_track_insert_key(index,float(frame.time),Quaternion(float(value[0]),float(value[1]),float(value[2]),float(value[3])).normalized())

static func _apply_grounding(character_id: String, clip: Animation, name: String, reduced: bool) -> void:
	if name not in ["walk","carry_walk"]: return
	if _grounding.is_empty() and FileAccess.file_exists(GROUNDING_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROUNDING_PATH))
		if parsed is Dictionary: _grounding=parsed
	var frames: Array = _grounding.get("characters",{}).get(character_id,{}).get("reduced" if reduced else "normal",{}).get(name,[])
	if frames.is_empty(): return
	for track: int in range(clip.get_track_count()):
		if clip.track_get_type(track)!=Animation.TYPE_POSITION_3D or not str(clip.track_get_path(track)).ends_with(":Hips"): continue
		var values: Array[Vector3] = []
		for frame: Dictionary in frames:
			var value := clip.position_track_interpolate(track,float(frame.time))
			value.y+=float(frame.offset)
			values.append(value)
		for key: int in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
		clip.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
		for index: int in range(frames.size()): clip.position_track_insert_key(track,float(frames[index].time),values[index])

static func attach(character_id: String, skeleton: Skeleton3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var characters: Dictionary = manifest().get("characters",{})
	if not characters.has(character_id):
		push_error("Missing authored character: " + character_id)
		return result
	var entry: Dictionary = characters[character_id]
	var skin := Skin.new()
	for bone: Dictionary in entry.bones:
		var index := skeleton.find_bone(str(bone.name))
		if index < 0:
			push_error("Character bind bone missing: " + str(bone.name))
			return []
		skin.add_bind(index,skeleton.get_bone_global_rest(index).affine_inverse())
	for group: Dictionary in entry.groups:
		var mesh := load(str(group.path)) as ArrayMesh
		if mesh == null:
			push_error("Missing authored mesh: " + str(group.path))
			continue
		var instance := MeshInstance3D.new()
		instance.name = str(group.name)
		instance.mesh = mesh
		instance.skin = skin
		instance.skeleton = NodePath("..")
		instance.custom_aabb = AABB(Vector3(-1.7,-0.3,-1.7),Vector3(3.4,3.6,3.4))
		instance.set_meta("art_revision",revision())
		instance.set_meta("source_asset",character_id)
		skeleton.add_child(instance)
		result.append(instance)
	return result

static func create_skeleton(character_id: String) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "StorybookSkeleton"
	var entry: Dictionary = manifest().get("characters",{}).get(character_id,{})
	for bone: Dictionary in entry.get("bones",[]):
		var index := skeleton.add_bone(str(bone.name))
		if bone.parent != null:
			skeleton.set_bone_parent(index,skeleton.find_bone(str(bone.parent)))
		var origin: Array = bone.origin
		var rotation: Array = bone.rotation
		var basis := Basis.from_euler(Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2])))
		skeleton.set_bone_rest(index,Transform3D(basis,Vector3(float(origin[0]),float(origin[1]),float(origin[2]))))
		skeleton.reset_bone_pose(index)
	return skeleton

static func statistics(root: Node) -> Dictionary:
	var result := {"skinned_meshes":0,"skin_bind_count":0,"weighted_vertices":0,"blend_shape_count":0,"blend_shape_names":[],"art_revision":revision()}
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or instance.skin == null or instance.skin.get_bind_count() == 0:
			continue
		result.skinned_meshes += 1
		result.skin_bind_count += instance.skin.get_bind_count()
		for shape: int in range(instance.mesh.get_blend_shape_count()):
			result.blend_shape_count += 1
			var shape_name := str(instance.mesh.get_blend_shape_name(shape))
			if not result.blend_shape_names.has(shape_name):
				result.blend_shape_names.append(shape_name)
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var influences: int = weights.size() / maxi(vertices.size(),1)
			for vertex: int in range(vertices.size()):
				var sum_weights := 0.0
				for influence: int in range(influences):
					sum_weights += weights[vertex * influences + influence]
				if sum_weights > 0.0:
					result.weighted_vertices += 1
	return result

static func set_outfit(root: Node, id: String) -> void:
	var colors := {"yellow":Color("e6b946"),"pink":Color("d87e93"),"blue":Color("79aeca")}
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		if str(instance.get_meta("source_asset","")) != "player":
			continue
		var source_material := instance.mesh.surface_get_material(0)
		if source_material is ShaderMaterial:
			var shader_material := instance.material_override as ShaderMaterial
			if shader_material == null: shader_material=source_material.duplicate(true) as ShaderMaterial
			shader_material.set_shader_parameter("recolor",id!="yellow")
			shader_material.set_shader_parameter("outfit_color",colors.get(id,colors.yellow))
			instance.material_override=shader_material
		elif str(node.name)=="Outfit":
			var material := source_material.duplicate() as StandardMaterial3D
			material.albedo_color = colors.get(id,colors.yellow)
			instance.material_override = material

static func blink(meshes: Array[MeshInstance3D], elapsed: float, reduce_motion: bool = false) -> void:
	expression(meshes,elapsed,"idle",reduce_motion)

static func expression(meshes: Array[MeshInstance3D], elapsed: float, action: String, reduce_motion: bool = false) -> void:
	var cycle := fposmod(elapsed,4.7)
	var amount := 0.0 if reduce_motion or cycle < 4.49 else sin((cycle-4.49)/0.21*PI)
	var smile := 0.8 if action in ["greet_wave","pose_photo","wave","photo"] else 0.0
	var talk := (0.28+0.68*absf(sin(elapsed*9.0))) if not reduce_motion and action in ["talk_gesture","talk"] else 0.0
	for mesh: MeshInstance3D in meshes:
		for index: int in range(mesh.mesh.get_blend_shape_count()):
			var shape_name := str(mesh.mesh.get_blend_shape_name(index))
			var value := amount if shape_name == "Blink" else smile if shape_name == "Smile" else talk if shape_name == "Talk" else 0.0
			mesh.set_blend_shape_value(index,clampf(value,0,1))
