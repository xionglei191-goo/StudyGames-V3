extends RefCounted
## Local optional opportunities. Wall time is an estimate, never a verified learning claim.
const DAY := 86400.0
const INTERVALS := [0.0, DAY, 3.0 * DAY, 7.0 * DAY]
const RESULTS := ["", "independent_correct", "supported_correct", "not_correct", "demonstrated", "skipped"]
const LEGACY_SOURCES := {"hello":["u1_greeting"],"morning":["u1_morning"],"thanks":["u1_goodbye"],"name":["u2_name","u2_intro"],"goodbye":["u2_polite"],"age":["u3_age"],"7":[],"8":["u3_birthday"],"9":["u3_nine","u3_age"],"10":[]}
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/revisits.json"))
		for row: Dictionary in parsed.targets: _catalog[row.id] = row
	return _catalog

static func fresh() -> Dictionary:
	return {"schema_version":1,"clock":{"last_wall":0.0,"epoch":0,"anomalies":0},"activity_serial":0,"sequence":0,"targets":{},"opportunities":{},"batch":{"at":0.0,"ids":[]}}

static func tick(review: Dictionary, now: float, expected_elapsed: float = -1.0) -> bool:
	var last := float(review.clock.last_wall)
	var gap := now-last
	var anomalous := last>0 and (gap < -300.0 or (expected_elapsed>=0 and absf(gap-expected_elapsed)>300.0) or (expected_elapsed<0 and gap>30.0*DAY))
	if anomalous:
		review.clock.epoch += 1
		review.clock.anomalies += 1
		review.batch.at = now
		# Keep optional encounters reachable after a rollback; their intervals remain unknown.
		for target: Dictionary in review.targets.values():
			target.anchor_at = maxf(0.0,now-maxf(DAY,float(INTERVALS[mini(int(target.round),3)])))
		for opportunity: Dictionary in review.opportunities.values():
			if opportunity.result.is_empty():
				opportunity.elapsed_real_seconds = -1.0
				opportunity.prior_contact = true
	review.clock.last_wall = now
	return anomalous

static func source_signature(data: Dictionary, spec: Dictionary) -> String:
	var journey: Dictionary = data.journey
	if spec.group=="letters":
		var letter: String = spec.letter
		if not journey.letters[letter].experienced: return ""
		var recall := "recall/"+letter+("/case_pair" if spec.id.ends_with("/case") else "/landmark")
		return JSON.stringify([journey.letters[letter],journey.p2.letters[letter],journey.p2.trials.get(recall,{})])
	var unit := int(str(spec.group).trim_prefix("u"))
	var unlocked: bool = journey.u1.completed if unit==1 else journey.p2.chapters[str(unit)].completed
	unlocked = unlocked or bool(data.completed_units.get(str(unit),false))
	if not unlocked: return ""
	var trials: Array = []
	for context: String in spec.source_refs: trials.append(journey.p2.trials.get(context,{}))
	var legacy: Array = []
	for id: String in LEGACY_SOURCES.get(str(spec.id).trim_prefix("unit/"),[]): legacy.append(data.learning.get(id,{}))
	return JSON.stringify([unlocked,trials,legacy])

static func _phrase_key(text: String) -> String:
	var letters := ""
	for character: String in text.to_lower().replace("’","'"):
		letters += character if "abcdefghijklmnopqrstuvwxyz0123456789'".contains(character) else " "
	return " ".join(letters.split(" ",false))

static func targets_in_text(texts: Array) -> Array:
	var result: Array = []
	var normalized: Array = texts.map(func(value: Variant): return " "+_phrase_key(str(value))+" ")
	for id: String in catalog():
		var spec: Dictionary = catalog()[id]
		if spec.group=="letters": continue
		var scene: Dictionary = spec.contexts[0]
		var answer: String = scene.options.filter(func(option: Dictionary): return option.id==scene.correct)[0].text
		var key := " "+_phrase_key(answer)+" "
		if normalized.any(func(value: String): return value.contains(key)): result.append(id)
	return result

static func sync(data: Dictionary, before: Dictionary, now: float) -> void:
	var review: Dictionary = data.reviews
	if not before.is_empty():
		# A distinct life outcome can separate the initial optional encounter.
		var changed_activity: bool = data.life != before.life or data.journey.home_steps != before.journey.home_steps or data.journey.u1.steps != before.journey.u1.steps or data.journey.p2.chapters != before.journey.p2.chapters
		for letter: String in data.journey.letters:
			changed_activity = changed_activity or data.journey.letters[letter].experienced != before.journey.letters[letter].experienced
		if changed_activity: review.activity_serial += 1
	for id: String in catalog():
		var spec: Dictionary = catalog()[id]
		var signature := source_signature(data,spec)
		if signature.is_empty(): continue
		var known_change := not before.is_empty() and signature!=source_signature(before,spec)
		if not review.targets.has(id):
			review.targets[id] = {"signature":signature,"round":0,"anchor_at":now,"anchor_activity":review.activity_serial,"last_exposure":now if known_change else -1.0,"exposure_epoch":int(review.clock.epoch),"imported_unknown":not known_change}
		elif signature!=review.targets[id].signature:
			review.targets[id].signature = signature
			if known_change: expose(review,[id],now)

static func expose(review: Dictionary, ids: Array, now: float) -> void:
	for id: String in ids:
		if not review.targets.has(id): continue
		var target: Dictionary = review.targets[id]
		target.last_exposure = now
		target.exposure_epoch = int(review.clock.epoch)
		target.imported_unknown = false
		for opportunity: Dictionary in review.opportunities.values():
			if opportunity.target==id and opportunity.result.is_empty() and opportunity.started_at>0:
				opportunity.prior_contact = true
				opportunity.elapsed_real_seconds = 0.0

static func eligible(review: Dictionary, id: String, now: float) -> bool:
	var target: Dictionary = review.targets[id]
	if int(target.round)==0:
		return (int(review.activity_serial)>int(target.anchor_activity) and now-float(target.anchor_at)>=60.0) or now-float(target.anchor_at)>=DAY
	return now-float(target.anchor_at)>=float(INTERVALS[mini(int(target.round),3)])

static func refresh(review: Dictionary, now: float) -> void:
	# A persisted half-hour outing cannot be reset by reloading, changing panels or sleeping.
	if not review.batch.ids.is_empty() and now-float(review.batch.at)<1800.0: return
	var ids: Array = []
	for id: String in review.opportunities:
		if review.opportunities[id].result.is_empty(): ids.append(id)
		if ids.size()==2: break
	var used: Array = []
	for id: String in ids: used.append(str(catalog()[review.opportunities[id].target].get("letter","")))
	var has_letter := ids.any(func(id: String): return catalog()[review.opportunities[id].target].group=="letters")
	var has_unit := ids.any(func(id: String): return catalog()[review.opportunities[id].target].group!="letters")
	var unit_due: bool = review.targets.keys().any(func(id: String): return catalog()[id].group!="letters" and eligible(review,id,now))
	var candidates: Array = review.targets.keys()
	candidates.sort_custom(func(a: String,b: String):
		var ta: Dictionary = review.targets[a]
		var tb: Dictionary = review.targets[b]
		return float(ta.anchor_at)<float(tb.anchor_at) if ta.anchor_at!=tb.anchor_at else a<b
	)
	for target_id: String in candidates:
		if ids.size()>=2: break
		var spec: Dictionary = catalog()[target_id]
		if spec.group=="letters" and has_letter and not has_unit and unit_due: continue
		if not eligible(review,target_id,now) or (not spec.letter.is_empty() and used.has(spec.letter)): continue
		var existing := false
		for opportunity: Dictionary in review.opportunities.values():
			if opportunity.target==target_id and opportunity.result.is_empty(): existing = true
		if existing: continue
		review.sequence += 1
		var id := "revisit-%d" % int(review.sequence)
		var target: Dictionary = review.targets[target_id]
		review.opportunities[id] = {"id":id,"target":target_id,"round":int(target.round),"context_index":int(target.round)%3,"content_revision":"revisits-v1","created_at":now,"started_at":0.0,"finished_at":0.0,"source_exposure":float(target.last_exposure),"source_epoch":int(target.exposure_epoch),"elapsed_real_seconds":-1.0,"help":0,"help_events":[],"answers":[],"result":"","prior_contact":false,"paused":false,"delayed_recall_claimed":false}
		ids.append(id)
		if spec.group=="letters": has_letter = true
		else: has_unit = true
		if not spec.letter.is_empty(): used.append(spec.letter)
	review.batch = {"at":now,"ids":ids}

static func context(opportunity: Dictionary) -> Dictionary:
	return catalog()[opportunity.target].contexts[int(opportunity.context_index)]

static func apply(review: Dictionary, event: Dictionary, now: float) -> Dictionary:
	var id := str(event.get("id",""))
	if not review.opportunities.has(id): return _fail("这份邀请还没有准备好，请先打开旅行册。")
	var opportunity: Dictionary = review.opportunities[id]
	var kind := str(event.get("kind",""))
	if not opportunity.result.is_empty(): return {"ok":true,"changed":false}
	var target: Dictionary = review.targets[opportunity.target]
	if kind=="defer":
		opportunity.paused = true
		return {"ok":true}
	if kind=="begin":
		if str(event.get("room",""))!=context(opportunity).room: return _fail("先到朋友邀请的地方，再接着聊。")
		if opportunity.started_at==0:
			opportunity.started_at = now
			opportunity.source_exposure = float(target.last_exposure)
			opportunity.source_epoch = int(target.exposure_epoch)
			if target.last_exposure>=0 and target.exposure_epoch==review.clock.epoch and now>=float(target.last_exposure):
				opportunity.elapsed_real_seconds = now-float(target.last_exposure)
			opportunity.prior_contact = opportunity.elapsed_real_seconds<DAY
			# A legal question can still expose material used by a different target.
			var sibling_ids: Array = []
			var spec: Dictionary = catalog()[opportunity.target]
			if spec.group=="letters":
				for sibling: String in review.targets:
					if sibling!=opportunity.target and catalog()[sibling].letter==spec.letter: sibling_ids.append(sibling)
			else:
				var texts: Array = context(opportunity).options.map(func(option: Dictionary): return option.text)
				texts.append(context(opportunity).prompt)
				sibling_ids = targets_in_text(texts)
				sibling_ids.erase(opportunity.target)
			expose(review,sibling_ids,now)
		opportunity.paused = false
		return {"ok":true}
	if opportunity.started_at<=0 or str(event.get("room",""))!=context(opportunity).room: return _fail("请从这份邀请继续，已用过的帮助会保留。")
	if kind=="help":
		var level := int(event.get("level",0))
		if level not in [1,5]: return _fail("帮助方式无法记录。")
		if opportunity.help_events.size()>=31 and level<=int(opportunity.help): return {"ok":true,"changed":false}
		opportunity.help = maxi(int(opportunity.help),level)
		opportunity.help_events.append({"level":level,"at":now,"kind":"full_demonstration" if level==5 else "location_meaning"})
		return {"ok":true}
	var result := ""
	if kind=="answer":
		var answer := str(event.get("answer",""))
		if not (context(opportunity).options as Array).any(func(option: Dictionary): return option.id==answer): return _fail("请选择当前卡片里的回应。")
		if opportunity.answers.size()>=16: return _fail("先收好这次尝试，或看看完整示范。")
		var correct: bool = answer==context(opportunity).correct
		var no_help: bool = int(opportunity.help)==0 and not opportunity.prior_contact
		var first: bool = opportunity.answers.is_empty()
		opportunity.answers.append({"answer":answer,"correct":correct,"at":now,"help":int(opportunity.help),"unassisted":no_help,"first":first})
		if correct: result = "independent_correct" if first and no_help else "supported_correct"
	elif kind=="demonstrated":
		if int(opportunity.help)!=5: return _fail("先看看完整示范。")
		result = "demonstrated"
	elif kind=="skip": result = "skipped" if opportunity.answers.is_empty() else "not_correct"
	else: return _fail("未知的回访操作。")
	if not result.is_empty():
		opportunity.result = result
		opportunity.finished_at = now
		target.round += 1
		target.anchor_at = now
		target.anchor_activity = int(review.activity_serial)
		# A skip with no response did not expose an answer, but is still a completed opportunity.
		if result!="skipped":
			target.last_exposure = now
			target.exposure_epoch = int(review.clock.epoch)
			target.imported_unknown = false
	return {"ok":true}

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

static func _number(value: Variant, minimum: float = 0.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<1.0e13

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value)==floorf(float(value))

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"ok":false}
	var clean: Dictionary = value.duplicate(true)
	for key: String in fresh():
		if not clean.has(key) or typeof(clean[key])!=typeof(fresh()[key]) and not (_number(clean[key]) and _number(fresh()[key])): return {"ok":false}
	if clean.schema_version!=1 or not _number(clean.sequence) or not _number(clean.activity_serial): return {"ok":false}
	clean.schema_version = 1
	for key: String in ["sequence","activity_serial"]:
		if not _integer(clean[key]): return {"ok":false}
		clean[key] = int(clean[key])
	for key: String in ["last_wall","epoch","anomalies"]:
		if not _number(clean.clock.get(key)): return {"ok":false}
	for key: String in ["epoch","anomalies"]:
		if not _integer(clean.clock[key]): return {"ok":false}
		clean.clock[key] = int(clean.clock[key])
	if clean.targets.size()>catalog().size() or clean.opportunities.size()>20000: return {"ok":false}
	for id: Variant in clean.targets:
		if not id is String or not catalog().has(id) or not clean.targets[id] is Dictionary: return {"ok":false}
		var target: Dictionary = clean.targets[id]
		for key: String in ["round","anchor_at","anchor_activity","exposure_epoch"]:
			if not _number(target.get(key)): return {"ok":false}
		for key: String in ["round","anchor_activity","exposure_epoch"]:
			if not _integer(target[key]): return {"ok":false}
			target[key] = int(target[key])
		if not _number(target.get("last_exposure"),-1.0) or not target.get("imported_unknown") is bool or not target.get("signature") is String or target.signature.length()>100000: return {"ok":false}
	for id: Variant in clean.opportunities:
		if not id is String or not clean.opportunities[id] is Dictionary: return {"ok":false}
		var opportunity: Dictionary = clean.opportunities[id]
		var sequence_text: String = id.trim_prefix("revisit-")
		if not sequence_text.is_valid_int() or int(sequence_text)<1 or int(sequence_text)>int(clean.sequence) or id!="revisit-%d"%int(sequence_text): return {"ok":false}
		if opportunity.get("id")!=id or not clean.targets.has(opportunity.get("target")) or opportunity.get("content_revision")!="revisits-v1" or not RESULTS.has(opportunity.get("result")): return {"ok":false}
		for key: String in ["round","context_index","created_at","started_at","finished_at","source_epoch","help"]:
			if not _number(opportunity.get(key)): return {"ok":false}
		for key: String in ["round","context_index","source_epoch","help"]:
			if not _integer(opportunity[key]): return {"ok":false}
			opportunity[key] = int(opportunity[key])
		if opportunity.context_index not in [0,1,2] or opportunity.help not in [0,1,5]: return {"ok":false}
		if int(opportunity.context_index)!=int(opportunity.round)%3: return {"ok":false}
		for key: String in ["source_exposure","elapsed_real_seconds"]:
			if not _number(opportunity.get(key),-1.0): return {"ok":false}
		if opportunity.get("delayed_recall_claimed")!=false or not opportunity.get("prior_contact") is bool or not opportunity.get("paused") is bool: return {"ok":false}
		if not opportunity.get("answers") is Array or opportunity.answers.size()>16 or not opportunity.get("help_events") is Array or opportunity.help_events.size()>32: return {"ok":false}
		var max_help := 0
		for help: Variant in opportunity.help_events:
			if not help is Dictionary or not _integer(help.get("level")) or not _number(help.get("at")): return {"ok":false}
			help.level = int(help.level)
			if help.level not in [1,5]: return {"ok":false}
			max_help = maxi(max_help,int(help.level))
		if max_help!=int(opportunity.help): return {"ok":false}
		var index := 0
		for answer: Variant in opportunity.answers:
			if not answer is Dictionary or not answer.get("answer") is String or not answer.get("correct") is bool or not answer.get("unassisted") is bool or not answer.get("first") is bool or not _number(answer.get("at")) or not _integer(answer.get("help")): return {"ok":false}
			answer.help = int(answer.help)
			if answer.help not in [0,1,5]: return {"ok":false}
			if answer.first!=(index==0) or answer.correct!=(answer.answer==context(opportunity).correct): return {"ok":false}
			if not (context(opportunity).options as Array).any(func(option: Dictionary): return option.id==answer.answer): return {"ok":false}
			if answer.help>opportunity.help or (answer.correct and index!=opportunity.answers.size()-1): return {"ok":false}
			if answer.unassisted and answer.help>0: return {"ok":false}
			index += 1
		if opportunity.result=="independent_correct" and (opportunity.answers.size()!=1 or not opportunity.answers[0].correct or not opportunity.answers[0].unassisted or opportunity.help>0 or opportunity.prior_contact or opportunity.elapsed_real_seconds<DAY): return {"ok":false}
		if opportunity.result=="supported_correct" and (opportunity.answers.is_empty() or not opportunity.answers.back().correct): return {"ok":false}
		if opportunity.result=="demonstrated" and opportunity.help!=5: return {"ok":false}
		if opportunity.result=="not_correct" and opportunity.answers.is_empty(): return {"ok":false}
		if not opportunity.result.is_empty() and opportunity.finished_at<=0: return {"ok":false}
		if opportunity.result.is_empty() and opportunity.finished_at!=0: return {"ok":false}
		if opportunity.result in ["skipped",""] and not opportunity.answers.is_empty() and opportunity.answers.back().correct: return {"ok":false}
		if opportunity.result=="not_correct" and opportunity.answers.back().correct: return {"ok":false}
	for target_id: String in clean.targets:
		var completed := 0
		var rounds: Array = []
		for opportunity: Dictionary in clean.opportunities.values():
			if opportunity.target!=target_id: continue
			if rounds.has(int(opportunity.round)): return {"ok":false}
			rounds.append(int(opportunity.round))
			if opportunity.result.is_empty():
				if opportunity.round!=clean.targets[target_id].round: return {"ok":false}
			else:
				if opportunity.round>=clean.targets[target_id].round: return {"ok":false}
				completed += 1
		if completed!=int(clean.targets[target_id].round): return {"ok":false}
	if not _number(clean.batch.get("at")) or not clean.batch.get("ids") is Array or clean.batch.ids.size()>2: return {"ok":false}
	for id: Variant in clean.batch.ids:
		if not id is String or not clean.opportunities.has(id): return {"ok":false}
	if clean.batch.ids.size()==2 and clean.batch.ids[0]==clean.batch.ids[1]: return {"ok":false}
	return {"ok":true,"value":clean}
