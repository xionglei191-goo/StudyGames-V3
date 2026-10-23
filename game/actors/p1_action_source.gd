extends RefCounted
## Editable source for the saved P1 AnimationLibrary resources.
## Values below are bone-local Euler degrees. Runtime actors load the saved
## libraries; this source is only used to rebuild them and to read clip metadata.

const DIRECTORY := "res://actors/p1"
const BASE_BONES := ["Hips","Spine","Head","UpperArm_L","LowerArm_L","UpperArm_R","LowerArm_R","UpperLeg_L","LowerLeg_L","UpperLeg_R","LowerLeg_R"]
const FAMILIES := ["humanoid","animal","dino","wheelchair"]
const ALIASES := {"wave":"greet_wave","greet":"greet_wave","reach":"reach_target","pick":"pick_item","carry":"carry_item","place":"place_item","give":"give_item","take":"take_item","photo":"pose_photo","point":"point_target","talk":"talk_gesture","nod":"listen_nod"}
const SPECS := {
	"idle":{"duration":3.2,"loop":true,"contact_time":-1.0},
	"walk":{"duration":1.12,"loop":true,"contact_time":-1.0},
	"carry_item":{"duration":2.0,"loop":true,"contact_time":-1.0},
	"carry_walk":{"duration":1.12,"loop":true,"contact_time":-1.0},
	"greet_wave":{"duration":2.2,"loop":false,"contact_time":-1.0},
	"reach_target":{"duration":2.2,"loop":false,"contact_time":1.1},
	"pick_item":{"duration":2.2,"loop":false,"contact_time":1.1},
	"place_item":{"duration":2.2,"loop":false,"contact_time":1.1},
	"give_item":{"duration":2.2,"loop":false,"contact_time":1.1},
	"take_item":{"duration":2.2,"loop":false,"contact_time":1.1},
	"pose_photo":{"duration":2.4,"loop":false,"contact_time":-1.0},
	"point_target":{"duration":2.0,"loop":false,"contact_time":-1.0},
	"talk_gesture":{"duration":2.2,"loop":false,"contact_time":-1.0},
	"listen_nod":{"duration":1.8,"loop":false,"contact_time":-1.0},
}

static func canonical_action(value: String) -> String:
	return str(ALIASES.get(value,value))

static func family_for(kind: String) -> String:
	return "wheelchair" if kind == "wheelchair" else "dino" if kind == "dino" else "animal" if kind in ["bear","rabbit"] else "humanoid"

static func allowed(action: String, family: String) -> bool:
	var id := canonical_action(action)
	return SPECS.has(id) and not (family == "wheelchair" and id in ["walk","carry_walk","pick_item"])

static func library_path(family: String, reduced: bool) -> String:
	return DIRECTORY.path_join(family + ("_reduced" if reduced else "") + ".tres")

static func spec(action: String, family: String) -> Dictionary:
	var id := canonical_action(action)
	if not SPECS.has(id):
		return {"id":id,"allowed":false,"duration":0.0,"contact_time":-1.0,"loop":false}
	var result: Dictionary = SPECS[id].duplicate(true)
	result.id = id
	result.allowed = allowed(id,family)
	result.family = family
	result.semantic_data_mutation = false
	result.phases = [{"phase":"anticipation","from":0.0,"to":0.3},{"phase":"reach","from":0.3,"to":1.1},{"phase":"contact","from":1.1,"to":1.4},{"phase":"recover","from":1.4,"to":float(result.duration)}] if float(result.contact_time) >= 0.0 else [{"phase":"loop" if bool(result.loop) else "perform","from":0.0,"to":float(result.duration)}]
	return result

static func bones_for(family: String) -> Array:
	var result := BASE_BONES.duplicate()
	if family == "dino":
		result.append_array(["Tail","Wing_L","Wing_R"])
	return result

static func rest_rotation(family: String, bone: String) -> Quaternion:
	if family == "wheelchair":
		if bone.begins_with("UpperLeg_"):
			return Quaternion.from_euler(Vector3(-PI * 0.5,0,0))
		if bone.begins_with("LowerLeg_"):
			return Quaternion.from_euler(Vector3(PI * 0.5,0,0))
	return Quaternion.IDENTITY

static func hips_height(family: String) -> float:
	return 0.88 if family == "wheelchair" else 0.79

static func _pose(values: Dictionary = {}) -> Dictionary:
	var pose := {"UpperArm_L":Vector3(0,0,7),"UpperArm_R":Vector3(0,0,-7)}
	pose.merge(values,true)
	return pose

static func _frame(time: float, values: Dictionary = {}) -> Dictionary:
	return {"time":time,"pose":_pose(values)}

static func _carry() -> Dictionary:
	return {"UpperArm_R":Vector3(-52,-8,-12),"LowerArm_R":Vector3(-72,0,0),"UpperArm_L":Vector3(-45,10,14),"LowerArm_L":Vector3(-72,0,0),"Head":Vector3(7,0,0)}

static func _contact(action: String) -> Dictionary:
	var pose := {"Spine":Vector3(7,0,0),"UpperArm_R":Vector3(-68,0,-5),"LowerArm_R":Vector3(-6,0,0),"UpperArm_L":Vector3(-20,5,10),"LowerArm_L":Vector3(-25,0,0),"Head":Vector3(8,0,0)}
	if action == "place_item":
		# Low basket reach: pelvis/spine lean forward while both legs counterrotate
		# to keep the feet planted. The socket reaches about z=.79m / y=.62m.
		pose.Hips = Vector3(25,0,0)
		pose.Spine = Vector3(35,0,0)
		pose.UpperLeg_L = Vector3(-25,0,0)
		pose.UpperLeg_R = Vector3(-25,0,0)
		pose.UpperArm_R = Vector3(-108,0,-5)
		pose.LowerArm_R = Vector3(30,0,0)
		pose.UpperArm_L = Vector3(-40,0,12)
		pose.LowerArm_L = Vector3(-30,0,0)
		pose.Head = Vector3(-35,0,0)
	elif action in ["give_item","take_item"]:
		pose.UpperArm_R = Vector3(-78,0,-8)
		pose.LowerArm_R = Vector3(-12,0,0)
		pose.Spine = Vector3(3,0,0)
		pose.Head = Vector3(0,0,0)
	return pose

static func frames_for(action: String, reduced: bool) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	match action:
		"idle":
			for t: float in [0.0,0.8,1.6,2.4,3.2]:
				var breath := 0.0 if reduced else sin(t / 3.2 * TAU) * 1.6
				frames.append(_frame(t,{"Spine":Vector3(breath,0,0),"Head":Vector3(0,-breath * 0.3,0)}))
		"walk", "carry_walk":
			var leg_poses := [
				{"UpperLeg_L":Vector3(-25,0,0),"LowerLeg_L":Vector3(31,0,0),"UpperLeg_R":Vector3(21,0,0),"LowerLeg_R":Vector3(9,0,0),"hips_y":-0.038},
				{"UpperLeg_L":Vector3(0,0,0),"LowerLeg_L":Vector3(0,0,0),"UpperLeg_R":Vector3(-31,0,0),"LowerLeg_R":Vector3(60,0,0),"hips_y":0.0},
				{"UpperLeg_L":Vector3(21,0,0),"LowerLeg_L":Vector3(9,0,0),"UpperLeg_R":Vector3(-25,0,0),"LowerLeg_R":Vector3(31,0,0),"hips_y":-0.038},
				{"UpperLeg_L":Vector3(-31,0,0),"LowerLeg_L":Vector3(60,0,0),"UpperLeg_R":Vector3(0,0,0),"LowerLeg_R":Vector3(0,0,0),"hips_y":0.0},
				{"UpperLeg_L":Vector3(-25,0,0),"LowerLeg_L":Vector3(31,0,0),"UpperLeg_R":Vector3(21,0,0),"LowerLeg_R":Vector3(9,0,0),"hips_y":-0.038},
			]
			for index: int in range(5):
				var pose: Dictionary = leg_poses[index].duplicate(true)
				var arm_swing: float = [25.0,0.0,-25.0,0.0,25.0][index]
				pose.merge({"UpperArm_L":Vector3(arm_swing,0,7),"UpperArm_R":Vector3(-arm_swing,0,-7),"LowerArm_L":Vector3(-15,0,0),"LowerArm_R":Vector3(-15,0,0)},true)
				if action == "carry_walk":
					pose.merge(_carry(),true)
				frames.append(_frame(index * 0.28,pose))
		"carry_item":
			for t: float in [0.0,0.5,1.0,1.5,2.0]:
				var pose := _carry()
				pose.Spine = Vector3(0.0 if reduced else sin(t * PI) * 1.0,0,0)
				frames.append(_frame(t,pose))
		"greet_wave":
			# Lift outward beside the silhouette. A forward-overhead lift hides the
			# hand behind the large prototype head in the actual high game camera.
			frames = [_frame(0.0),_frame(0.25,{"Head":Vector3(-3,0,-3),"UpperArm_R":Vector3(-12,0,30)}),
				_frame(0.65,{"UpperArm_R":Vector3(-15,0,120),"LowerArm_R":Vector3(-12,0,25),"Head":Vector3(-3,0,-5)}),
				_frame(0.92,{"UpperArm_R":Vector3(-15,0,120),"LowerArm_R":Vector3(-12,0,75 if not reduced else 45)}),
				_frame(1.19,{"UpperArm_R":Vector3(-15,0,120),"LowerArm_R":Vector3(-12,0,25 if not reduced else 45)}),
				_frame(1.46,{"UpperArm_R":Vector3(-15,0,120),"LowerArm_R":Vector3(-12,0,75 if not reduced else 45)}),
				_frame(1.72,{"UpperArm_R":Vector3(-12,0,85),"LowerArm_R":Vector3(-12,0,30)}),_frame(2.2)]
		"reach_target","pick_item","place_item","give_item","take_item":
			var start := _carry() if action in ["place_item","give_item"] else {}
			var finish := _carry() if action in ["pick_item","take_item"] else {}
			frames = [_frame(0.0,start),_frame(0.3,start),_frame(0.65,{"UpperArm_R":Vector3(-42,0,-10),"LowerArm_R":Vector3(-26,0,0),"Spine":Vector3(4,0,0),"Head":Vector3(5,0,0)}),
				_frame(1.1,_contact(action)),_frame(1.4,_contact(action)),_frame(1.8,finish),_frame(2.2,finish)]
		"pose_photo":
			var pose := {"UpperArm_R":Vector3(-118,0,-26),"LowerArm_R":Vector3(-38,0,12),"UpperArm_L":Vector3(-55,0,28),"LowerArm_L":Vector3(-46,0,0),"Head":Vector3(0,0,-7)}
			frames = [_frame(0.0),_frame(0.55,pose),_frame(1.9,pose),_frame(2.4)]
		"point_target":
			var pose := {"UpperArm_R":Vector3(-83,-18,-10),"LowerArm_R":Vector3(-6,0,0),"Head":Vector3(0,-15,0)}
			frames = [_frame(0.0),_frame(0.6,pose),_frame(1.5,pose),_frame(2.0)]
		"talk_gesture":
			frames = [_frame(0.0),_frame(0.5,{"UpperArm_R":Vector3(-42,0,-24),"LowerArm_R":Vector3(-45,0,0),"Head":Vector3(4,0,0)}),
				_frame(1.1,{"UpperArm_R":Vector3(-65,0,-14),"LowerArm_R":Vector3(-30,0,0),"Head":Vector3(-3 if not reduced else 4,0,0)}),
				_frame(1.65,{"UpperArm_R":Vector3(-42,0,-24),"LowerArm_R":Vector3(-45,0,0),"Head":Vector3(4,0,0)}),_frame(2.2)]
		"listen_nod":
			frames = [_frame(0.0),_frame(0.4,{"Head":Vector3(13,0,0)}),_frame(0.75,{"Head":Vector3(0 if not reduced else 8,0,0)}),_frame(1.1,{"Head":Vector3(12 if not reduced else 8,0,0)}),_frame(1.8)]
	return frames

static func build_clip(action: String, family: String, reduced: bool) -> Animation:
	var clip := Animation.new()
	clip.resource_name = action
	clip.length = float(SPECS[action].duration)
	clip.loop_mode = Animation.LOOP_LINEAR if bool(SPECS[action].loop) else Animation.LOOP_NONE
	var frames := frames_for(action,reduced)
	for bone: String in bones_for(family):
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath("VisualRoot/PrototypeSkeleton:" + bone))
		clip.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
		for frame: Dictionary in frames:
			var degrees: Vector3 = (frame.pose as Dictionary).get(bone,Vector3.ZERO)
			if family == "wheelchair" and bone.contains("Leg_"):
				degrees = Vector3.ZERO
			if family == "wheelchair" and action == "place_item":
				if bone == "Hips":
					degrees = Vector3.ZERO
				elif bone == "Spine":
					degrees.x = minf(degrees.x,10.0)
				elif bone == "Head":
					degrees = Vector3.ZERO
			if family == "animal" and bone == "Head" and action == "greet_wave":
				degrees.z *= 1.3
			if family == "dino" and not reduced:
				var phase := float(frame.time) / clip.length * TAU
				if bone == "Tail":
					degrees = Vector3(0,sin(phase) * (20.0 if action == "greet_wave" else 10.0),0)
				elif bone in ["Wing_L","Wing_R"]:
					var opening := sin(PI * float(frame.time) / clip.length) * (26.0 if action in ["greet_wave","pose_photo"] else 5.0)
					degrees = Vector3(0,opening * (-1.0 if bone == "Wing_L" else 1.0),0)
			var rotation := rest_rotation(family,bone) * Quaternion.from_euler(degrees * PI / 180.0)
			clip.rotation_track_insert_key(track,float(frame.time),rotation)
	var hips_track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(hips_track,NodePath("VisualRoot/PrototypeSkeleton:Hips"))
	for frame: Dictionary in frames:
		var y := hips_height(family) + (0.0 if family == "wheelchair" else float((frame.pose as Dictionary).get("hips_y",0.0)))
		clip.position_track_insert_key(hips_track,float(frame.time),Vector3(0,y,0))
	if float(SPECS[action].contact_time) >= 0.0:
		var contact_track := clip.add_track(Animation.TYPE_METHOD)
		clip.track_set_path(contact_track,NodePath("."))
		clip.track_insert_key(contact_track,float(SPECS[action].contact_time),{"method":&"_on_animation_contact_marker","args":[]})
	return clip

static func build_library(family: String, reduced: bool) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for action: String in SPECS:
		if allowed(action,family):
			library.add_animation(action,build_clip(action,family,reduced))
	return library
