extends RefCounted
## Additive, validated P2 state. Mutations are committed by the existing State transaction.
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const MODES := ["independent_action","hinted_action","companion_action","demonstration_viewed"]
const FriendCorner = preload("res://scripts/friend_corner_progress.gd")
const Party = preload("res://scripts/party_progress.gd")
const Discovery = preload("res://scripts/discovery_progress.gd")
static var _content: Dictionary = {}

static func content() -> Dictionary:
	if _content.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/p2_journey.json"))
		if parsed is Dictionary: _content = parsed
	return _content

static func fresh() -> Dictionary:
	var letters: Dictionary = {}
	for letter: String in LETTERS:
		letters[letter] = {"step":0,"choice":0,"placement":[0.5,0.5],"help":0,"glyph_seen":false,"letter_audio":false,"word_audio":false,"receipts":[]}
	return {"schema_version":1,"home_choice":"","trip":[],"letters":letters,"trials":{},"trial_sequence":0,"chapters":{"2":{"steps":[],"details":{},"completed":false},"3":{"steps":[],"details":{},"completed":false}},"mail":[],"seats":0,"receipts":{},"photo_revision":0,"friend_corner":FriendCorner.fresh(),"party":Party.fresh(),"discovery":Discovery.fresh()}

static func next_chapter(state: Dictionary) -> int:
	return 2 if not state.chapters["2"].completed else 3 if not state.chapters["3"].completed else 0

static func next_step(state: Dictionary, number: int) -> Dictionary:
	var items: Array = content().chapters[str(number)].steps
	var count: int = state.chapters[str(number)].steps.size()
	return items[count] if count<items.size() else {}

static func _ok(changed: bool = true) -> Dictionary:
	return {"ok":true,"changed":changed}

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and int(value)>=low and int(value)<=high

static func _text(value: Variant, limit: int = 300) -> bool:
	return value is String and value.length()<=limit

static func apply(journey: Dictionary, event: Dictionary, now: float) -> Dictionary:
	var state: Dictionary = journey.p2
	var kind := str(event.get("kind",""))
	if kind.begins_with("corner_"): return FriendCorner.apply(journey,event,now)
	if kind.begins_with("party_"): return Party.apply(journey,event,now)
	if kind.begins_with("discovery_"): return Discovery.apply(journey,event,now)
	match kind:
		"home_choice":
			var choice := str(event.get("choice",""))
			if choice not in ["flowers","star","later"]: return _fail("请选择一种门口装饰，或先留到以后。")
			if journey.home_steps.size()<1: return _fail("先认识家门旁的向导。")
			state.home_choice = choice
			if journey.home_steps.size()==1: journey.home_steps.append("H02")
			return _ok()
		"trip":
			var route: Variant = event.get("letters",[])
			if not route is Array or route.size()>3: return _fail("一次选一到三个字母伙伴就好。")
			var unique: Array = []
			for letter: Variant in route:
				if not letter is String or letter.length()!=1 or not LETTERS.contains(letter) or unique.has(letter): return _fail("旅行顺序里有不认识或重复的地点。")
				unique.append(letter)
			state.trip = unique
			return _ok()
		"letter_help","letter_glyph","letter_audio","letter_action":
			var letter := str(event.get("letter",""))
			if not state.letters.has(letter) or event.get("room")!="landmark_"+letter or not journey.letters[letter].visited: return _fail("请先到这个字母的真实地标再继续。")
			var record: Dictionary = state.letters[letter]
			if kind=="letter_help":
				if not _integer(event.get("level"),0,3): return _fail("提示级别无法保存。")
				record.help = maxi(int(record.help),int(event.level))
			elif kind=="letter_glyph":
				record.glyph_seen = true
			elif kind=="letter_audio":
				if event.get("role") not in ["letter","word"] or event.get("played")!=true: return _fail("只记录实际开始播放的音轨。")
				record[str(event.role)+"_audio"] = true
			else:
				var operations: Array = content().letters[letter].operations
				var operation := str(event.get("operation",""))
				var expected: Variant = event.get("expected_step")
				if not _integer(expected,0,operations.size()-1): return _fail("动作恢复位置无效。")
				if int(expected)<int(record.step):
					return _ok(false) if record.receipts[int(expected)]==operation else _fail("旧动作不能覆盖已确认的步骤。")
				if int(expected)!=int(record.step) or operation!=operations[int(record.step)].id: return _fail("接着完成当前这一步就好。")
				if not _integer(event.get("choice",0),0,1) or not _point(event.get("placement",[0.5,0.5])): return _fail("摆放位置无法保存。")
				if (letter=="O" or letter=="W") and int(event.get("choice",0))!=0: return _fail("再看看我们今天拜访的伙伴。")
				if letter=="U" and int(event.get("choice",0))!=1: return _fail("选雨天图，看看雨伞怎样撑开。")
				record.choice = int(event.get("choice",0))
				record.placement = event.get("placement",[0.5,0.5]).duplicate()
				record.step += 1
				record.receipts.append(operation)
			return _ok()
		"trial_begin":
			var context := str(event.get("context",""))
			var spec := trial_spec(context)
			if spec.is_empty() or not _trial_available(journey,context,event.get("room","")): return _fail("请在对应的生活情境里开始这次回应。")
			if state.trials.has(context) and not bool(event.get("again",false)): return _ok(false)
			if state.trials.has(context) and not state.trials[context].completed: return _ok(false)
			state.trial_sequence += 1
			var previous: Array = state.trials.get(context,{}).get("history",[]).duplicate(true)
			if state.trials.has(context):
				var old: Dictionary = state.trials[context].duplicate(true)
				old.erase("history")
				previous.append(old)
				if previous.size()>12: previous.pop_front()
			state.trials[context] = {"id":"p2-trial-%d"%int(state.trial_sequence),"context":context,"room":str(event.get("room","")),"dimension":str(spec.dimension),"help":0,"attempts":[],"completed":false,"result":"","started_at":now,"finished_at":0.0,"history":previous,"mastery_awarded":false}
			state.trials[context]["prior_exposure"] = not previous.is_empty()
			return _ok()
		"trial_help","trial_answer","trial_skip":
			var context := str(event.get("context",""))
			if not state.trials.has(context): return _fail("先打开这一次回想。")
			var trial: Dictionary = state.trials[context]
			if event.get("trial_id")!=trial.id: return _fail("这次回应已变化，不能写入另一轮。")
			if trial.completed: return _ok(false)
			if event.get("room")!=trial.room: return _fail("先回到这次回应的场所。")
			var spec := trial_spec(context)
			if kind=="trial_help":
				if not _integer(event.get("level"),0,3): return _fail("提示无法保存。")
				trial.help = maxi(int(trial.help),int(event.level))
			elif kind=="trial_skip":
				trial.completed = true
				trial.result = "skipped"
				trial.finished_at = now
			else:
				var answer := str(event.get("answer",""))
				var demonstration := answer=="__demonstrated__" and int(trial.help)==3
				var self_report := answer=="__spoken__" and str(spec.dimension)=="letter_name_self_report"
				var correct: bool = answer==str(spec.correct)
				if not demonstration and not self_report and not (spec.options as Array).any(func(option: Dictionary): return str(option.id)==answer): return _fail("请选择当前画面里的回应。")
				if trial.attempts.size()>=32 and not demonstration: return _fail("先看看完整示范，或稍后再来。")
				var independent: bool = correct and trial.attempts.is_empty() and int(trial.help)==0 and not trial.get("prior_exposure",false) and str(spec.dimension)!="letter_name_self_report"
				var result := "demonstrated" if demonstration else "self_report_unassessed" if self_report else "independent_correct" if independent else "supported_correct" if correct else "not_correct"
				trial.attempts.append({"answer":answer,"correct":correct,"result":result,"help":trial.help,"at":now,"independent":independent})
				if correct or demonstration or self_report:
					trial.completed = true
					trial.result = result
					trial.finished_at = now
			return _ok()
		"mail":
			if event.get("room")!="landmark_Z" or next_step(state,2).get("id")!="U2-04": return _fail("先问清两位收件人的名字。")
			var recipient := str(event.get("recipient",""))
			if recipient not in ["textbook_lingling","textbook_tim"] or event.get("mailbox")!=recipient: return _fail("邀请上的名字要和信格相同，可以再看一眼。")
			if state.mail.has(recipient): return _ok(false)
			state.mail.append(recipient)
			return _ok()
		"seats":
			var step := next_step(state,3)
			if event.get("room")!="classroom" or step.get("kind")!="seats" or not _integer(event.get("count"),0,10): return _fail("请在欢迎桌旁调整座位卡。")
			state.seats = int(event.count)
			return _ok()
		"chapter_step":
			if journey.selected_book_id!="xiangshao-g3-1" or not journey.u1.completed: return _fail("先把欢迎合照带回家。")
			var number: Variant = event.get("chapter")
			if not _integer(number,2,3): return _fail("这个生活章节尚未接入。")
			var chapter: Dictionary = state.chapters[str(int(number))]
			var step_id := str(event.get("step",""))
			if chapter.steps.has(step_id): return _ok(false)
			if int(number)!=next_chapter(state): return _fail("先完成当前生活章节。")
			var step := next_step(state,int(number))
			if step.get("id")!=step_id or step.get("room")!=event.get("room"): return _fail("先到当前故事地点完成这一步。")
			if step.kind=="question":
				var trial: Dictionary = state.trials.get(step_id,{})
				if not trial.get("completed",false) or trial.get("result") not in ["independent_correct","supported_correct","demonstrated"]: return _fail("可以先回应，也可以请朋友完整示范。")
			if step.kind=="mail" and state.mail.size()!=2: return _fail("还有一封邀请等着投递。")
			if step.kind=="seats" and state.seats!=step.seat_count: return _fail("再数一数，每位来客一张座位卡。")
			chapter.steps.append(step_id)
			chapter.details[step_id] = {"room":str(event.room),"at":now,"result":state.trials.get(step_id,{}).get("result","life_activity")}
			if step.kind=="complete":
				chapter.completed = true
				state.receipts["unit-%d/chapter"%int(number)] = {"at":now,"step":step_id}
				if int(number)==2: FriendCorner.grant(state)
			return _ok()
		"u1_transfer":
			var trial: Dictionary = state.trials.get("U1-10",{})
			if not journey.u1.completed or event.get("room")!="landmark_F" or not trial.get("completed",false): return _fail("在花园见到兔兔后再留下这次记录。")
			if journey.u1.steps.has("U1-10"): return _ok(false)
			journey.u1.steps.append("U1-10")
			var chapter_time: float = float(journey.reward_receipts.get("event/xiangshao-g3-1/unit-1/chapter",{}).get("created_at_utc",now))
			journey.u1.step_details["U1-10"] = {"room":"landmark_F","actor":"npc_rabbit_gardener","trial_id":str(trial.id),"result":str(trial.result),"elapsed_real_seconds":int(maxf(0.0,now-chapter_time)),"delayed_recall_claimed":false,"mastery_awarded":false}
			return _ok()
		"photo_retake":
			if not journey.u1.photo.created or not _text(event.get("path"),1000) or not str(event.path).begins_with("user://welcome-photo-") or not FileAccess.file_exists(event.path) or event.get("frame") not in ["yellow","blue"]: return _fail("照片尚未保存成功。")
			state.photo_revision += 1
			journey.u1.photo.details["image_path"] = event.path
			journey.u1.photo.details["frame"] = event.frame
			journey.u1.step_details["U1-08"] = journey.u1.photo.details.duplicate(true)
			return _ok()
	return _fail("未知的生活记录。")

static func trial_spec(context: String) -> Dictionary:
	if context=="U1-10": return content().u1_transfer.question
	if context=="U1-07":
		return {"correct":"hello","options":[{"id":"hello","text":"Hello!"},{"id":"thanks","text":"Thank you."}],"dimension":"written_situation_choice"}
	for chapter: Dictionary in content().chapters.values():
		for step: Dictionary in chapter.steps:
			if step.id==context and step.has("question"): return step.question
	var pieces := context.split("/")
	if pieces.size()!=3 or pieces[0]!="recall" or pieces[1].length()!=1 or not LETTERS.contains(pieces[1]): return {}
	var letter := pieces[1]
	var dimension := pieces[2]
	if dimension not in ["case_pair","landmark","letter_name"]: return {}
	var index := LETTERS.find(letter)
	var options: Array = []
	for offset: int in [0,7,15]:
		var value := LETTERS[(index+offset)%26]
		options.append({"id":value,"text":value.to_lower() if dimension=="case_pair" else value})
	return {"correct":letter,"options":options,"dimension":"letter_name_self_report" if dimension=="letter_name" else "letter_case_association" if dimension=="case_pair" else "letter_landmark_association"}

static func _trial_available(journey: Dictionary, context: String, room: String) -> bool:
	if context.begins_with("recall/"):
		var parts := context.split("/")
		return parts.size()==3 and journey.letters.get(parts[1],{}).get("experienced",false) and (room=="home" or room=="landmark_"+parts[1])
	if context=="U1-10": return journey.u1.completed and room=="landmark_F"
	if context=="U1-07": return journey.u1.steps.size()==6 and room=="school" and journey.selected_book_id=="xiangshao-g3-1"
	if journey.selected_book_id!="xiangshao-g3-1" or not journey.u1.completed: return false
	var number := next_chapter(journey.p2)
	if number==0: return false
	var step := next_step(journey.p2,number)
	return step.get("id")==context and step.get("room")==room

static func _point(value: Variant) -> bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and is_finite(float(value[0])) and is_finite(float(value[1])) and float(value[0])>=0.0 and float(value[0])<=1.0 and float(value[1])>=0.0 and float(value[1])<=1.0

static func normalize(value: Variant, journey: Dictionary) -> Dictionary:
	if not value is Dictionary or value.get("schema_version")!=1: return {"ok":false}
	var result := fresh()
	if value.get("home_choice") not in ["","flowers","star","later"] or not value.get("trip") is Array or value.trip.size()>3: return {"ok":false}
	result.home_choice = value.home_choice
	for letter: Variant in value.trip:
		if not letter is String or letter.length()!=1 or not LETTERS.contains(letter) or result.trip.has(letter): return {"ok":false}
		result.trip.append(letter)
	if not value.get("letters") is Dictionary or value.letters.size()!=26: return {"ok":false}
	for letter: String in LETTERS:
		var raw: Variant = value.letters.get(letter)
		var ops: Array = content().letters[letter].operations
		if not raw is Dictionary or not _integer(raw.get("step"),0,ops.size()) or not _integer(raw.get("choice"),0,1) or not _integer(raw.get("help"),0,3) or not _point(raw.get("placement")) or not raw.get("receipts") is Array or raw.receipts.size()!=int(raw.step): return {"ok":false}
		for flag: String in ["glyph_seen","letter_audio","word_audio"]:
			if not raw.get(flag) is bool: return {"ok":false}
		for index: int in raw.receipts.size():
			if raw.receipts[index]!=ops[index].id: return {"ok":false}
		if (int(raw.step)>0 or raw.glyph_seen or raw.letter_audio or raw.word_audio) and not journey.letters[letter].visited: return {"ok":false}
		result.letters[letter] = raw.duplicate(true)
		for key: String in ["step","choice","help"]: result.letters[letter][key]=int(raw[key])
		result.letters[letter].placement=[float(raw.placement[0]),float(raw.placement[1])]
	if not value.get("mail") is Array or value.mail.size()>2 or not _integer(value.get("seats"),0,10) or not _integer(value.get("photo_revision"),0,100000) or not _integer(value.get("trial_sequence"),0,1000000): return {"ok":false}
	for recipient: Variant in value.mail:
		if recipient not in ["textbook_lingling","textbook_tim"] or result.mail.has(recipient): return {"ok":false}
		result.mail.append(recipient)
	result.seats = int(value.seats)
	result.photo_revision = int(value.photo_revision)
	result.trial_sequence = int(value.trial_sequence)
	if not value.get("trials") is Dictionary or value.trials.size()>100: return {"ok":false}
	var ids: Dictionary = {}
	for context: Variant in value.trials:
		var spec := trial_spec(str(context))
		var trial: Variant = value.trials[context]
		if spec.is_empty() or not _valid_trial(trial,str(context),spec) or ids.has(trial.id) or not trial.get("history") is Array or trial.history.size()>12: return {"ok":false}
		if not _trial_id_valid(trial.id,result.trial_sequence): return {"ok":false}
		ids[trial.id] = true
		for old: Variant in trial.history:
			if not _valid_trial(old,str(context),spec) or not old.completed or ids.has(old.id): return {"ok":false}
			if not _trial_id_valid(old.id,result.trial_sequence): return {"ok":false}
			ids[old.id] = true
		result.trials[context] = _canonical_trial(trial)
	if not value.get("chapters") is Dictionary or not value.get("receipts") is Dictionary: return {"ok":false}
	var receipts := {}
	for number: String in ["2","3"]:
		var chapter: Variant = value.chapters.get(number)
		var specs: Array = content().chapters[number].steps
		if not chapter is Dictionary or not chapter.get("steps") is Array or chapter.steps.size()>specs.size() or not chapter.get("details") is Dictionary or chapter.details.size()!=chapter.steps.size() or not chapter.get("completed") is bool or chapter.completed!=(chapter.steps.size()==specs.size()): return {"ok":false}
		if not chapter.steps.is_empty() and (not journey.u1.completed or (number=="3" and not result.chapters["2"].completed)): return {"ok":false}
		for index: int in chapter.steps.size():
			var spec: Dictionary = specs[index]
			var detail: Variant = chapter.details.get(str(spec.id))
			if chapter.steps[index]!=spec.id or not detail is Dictionary or detail.get("room")!=spec.room or not _time(detail.get("at")) or not _text(detail.get("result")): return {"ok":false}
			if spec.kind=="question" and (not result.trials.has(spec.id) or not result.trials[spec.id].completed or result.trials[spec.id].result not in ["independent_correct","supported_correct","demonstrated"]): return {"ok":false}
		if chapter.completed:
			var key := "unit-"+number+"/chapter"
			var receipt: Variant = value.receipts.get(key)
			if not receipt is Dictionary or receipt.get("step")!=specs[-1].id or not _time(receipt.get("at")): return {"ok":false}
			receipts[key] = receipt.duplicate(true)
		result.chapters[number] = chapter.duplicate(true)
	if result.chapters["2"].steps.has("U2-04") and result.mail.size()!=2: return {"ok":false}
	if not result.mail.is_empty() and result.chapters["2"].steps.size()<3: return {"ok":false}
	if receipts.size()!=value.receipts.size(): return {"ok":false}
	result.receipts = receipts
	var corner_result := FriendCorner.normalize(value.get("friend_corner"),result,journey.u1.completed)
	if not corner_result.ok: return {"ok":false}
	result.friend_corner = corner_result.value
	var party_result := Party.normalize(value.get("party"),result)
	if not party_result.ok: return {"ok":false}
	result.party = party_result.value
	var discovery_result := Discovery.normalize(value.get("discovery"),journey)
	if not discovery_result.ok: return {"ok":false}
	result.discovery = discovery_result.value
	return {"ok":true,"value":result}

static func _time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0.0

static func _trial_id_valid(id: String, sequence: int) -> bool:
	var suffix := id.trim_prefix("p2-trial-")
	return suffix.is_valid_int() and int(suffix)>0 and int(suffix)<=sequence

static func _trial_room_valid(context: String, room: String) -> bool:
	if context=="U1-07": return room=="school"
	if context=="U1-10": return room=="landmark_F"
	if context.begins_with("recall/"): return room in ["home","landmark_"+context.split("/")[1]]
	for chapter: Dictionary in content().chapters.values():
		for step: Dictionary in chapter.steps:
			if step.id==context: return room==step.room
	return false

static func _canonical_trial(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.help=int(result.help)
	result.started_at=float(result.started_at)
	result.finished_at=float(result.finished_at)
	for attempt: Dictionary in result.attempts:
		attempt.help=int(attempt.help)
		attempt.at=float(attempt.at)
	if result.has("history"):
		for index: int in result.history.size(): result.history[index]=_canonical_trial(result.history[index])
	return result

static func _valid_trial(value: Variant, context: String, spec: Dictionary) -> bool:
	if not value is Dictionary: return false
	if not _text(value.get("id"),100) or not str(value.id).begins_with("p2-trial-") or value.get("context")!=context or value.get("dimension")!=spec.dimension or not _text(value.get("room")) or not _integer(value.get("help"),0,3) or not value.get("attempts") is Array or value.attempts.size()>33 or not value.get("completed") is bool or value.get("mastery_awarded")!=false or not _time(value.get("started_at")) or not _time(value.get("finished_at")) or not value.get("prior_exposure",false) is bool: return false
	if value.has("history") and not value.history.is_empty() and not value.get("prior_exposure",false): return false
	if not _trial_room_valid(context,str(value.room)): return false
	var finished := false
	var last_result := ""
	var help := 0
	for index: int in value.attempts.size():
		var attempt: Variant = value.attempts[index]
		if finished or not attempt is Dictionary or not _text(attempt.get("answer")) or not _integer(attempt.get("help"),help,int(value.help)) or not _time(attempt.get("at")): return false
		help = int(attempt.help)
		var correct: bool = attempt.answer==str(spec.correct)
		var demo: bool = attempt.answer=="__demonstrated__" and help==3
		var spoken: bool = attempt.answer=="__spoken__" and spec.dimension=="letter_name_self_report"
		if not demo and not spoken and not (spec.options as Array).any(func(option: Dictionary): return str(option.id)==attempt.answer): return false
		if index==32 and not demo: return false
		var independent: bool = correct and index==0 and help==0 and not value.get("prior_exposure",false) and spec.dimension!="letter_name_self_report"
		last_result = "demonstrated" if demo else "self_report_unassessed" if spoken else "independent_correct" if independent else "supported_correct" if correct else "not_correct"
		if attempt.get("correct")!=correct or attempt.get("independent")!=independent or attempt.get("result")!=last_result: return false
		finished = correct or demo or spoken
	if value.result=="skipped": return value.completed and not finished
	return value.completed==finished and value.result==(last_result if finished else "")

