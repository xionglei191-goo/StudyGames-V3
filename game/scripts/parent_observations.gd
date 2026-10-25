extends RefCounted
## Read-only projections. Living, written choices, self reports and story trials stay distinct.
const Reviews = preload("res://scripts/review_progress.gd")
const P2 = preload("res://scripts/p2_progress.gd")
const U1_RECEIPT := "event/xiangshao-g3-1/unit-1/chapter"
const HELP_NAMES := ["未用额外提示","位置与意义提示","起步提示","缺口提示","逐步帮助","完整示范"]
static var _entry_titles: Dictionary = {}
static var _legacy_titles: Dictionary = {}
const RESULTS := {"":"尚未作答","independent_correct":"首次独立正确","supported_correct":"在支持或再次接触后完成","not_correct":"已尝试，尚未正确","demonstrated":"观看示范","skipped":"本次未尝试","self_report_unassessed":"口头自述，未自动评估","life_activity":"生活体验"}
const DIMENSIONS := {"letter_case_association":"大小写配对","letter_landmark_association":"固定形象与字母","letter_name_self_report":"字母名自述","written_situation_choice":"书面情境选择","orthography":"拼写","meaning":"词义","listening":"听辨","spoken_expression":"表达","written_recognition":"书面辨认","ordered_images":"形象顺序","letter_recognition":"字母辨认","all":"故事综合支持","":"故事接触"}

static func interval_text(seconds: float) -> String:
	if seconds<0: return "间隔未知"
	if seconds<60: return "不足 1 分钟"
	if seconds<3600: return "%d 分钟" % int(seconds/60.0)
	if seconds<86400: return "%.1f 小时" % (seconds/3600.0)
	return "%.1f 天" % (seconds/86400.0)

static func timestamp(value: float) -> String:
	if value<=0: return "时间未记录"
	var local := value+float(Time.get_time_zone_from_system().bias)*60.0
	return Time.get_datetime_string_from_unix_time(int(local),true).left(16)

static func rows(data: Dictionary, filter: String = "all") -> Array:
	var result: Array = []
	var modes := {"independent_action":"自行操作","hinted_action":"提示后操作","companion_action":"陪同操作","demonstration_viewed":"观看示范","":"方式未记录"}
	for letter: String in data.journey.letters:
		var experience: Dictionary = data.journey.letters[letter]
		if not experience.experienced: continue
		var detail := "完成方式："+str(modes.get(experience.completion_mode,"方式未记录"))+"。体验完成不等于独立认出字母。"
		var observed: Array = []
		for opportunity: Dictionary in data.reviews.opportunities.values():
			if opportunity.target.begins_with("letter/"+letter+"/") and not opportunity.answers.is_empty():
				var dimension: String = DIMENSIONS.get(Reviews.catalog()[opportunity.target].dimension,"")
				if not observed.has(dimension): observed.append(dimension)
		detail += "\n回访作答维度："+("尚未尝试" if observed.is_empty() else "、".join(observed))
		result.append({"id":"experience/"+letter,"title":letter+letter.to_lower()+" · 字母生活体验","group":"letters","dimension":"","result":"life_activity","at":0.0,"detail":detail,"source":"字母发现页"})
	for unit: int in [1,2,3]:
		var completed: bool = data.journey.u1.completed if unit==1 else data.journey.p2.chapters[str(unit)].completed
		if not completed: continue
		var at: float = float(data.journey.reward_receipts.get(U1_RECEIPT,{}).get("created_at_utc",0)) if unit==1 else float(data.journey.p2.receipts.get("unit-%d/chapter"%unit,{}).get("at",0))
		result.append({"id":"life/unit-"+str(unit),"title":["欢迎新朋友","给朋友送邀请","欢迎会座位数"][unit-1],"group":"units","dimension":"","result":"life_activity","at":at,"detail":"U%d 生活事件已完成。具体英语作答、帮助和示范见各自记录；没有自动授予英语掌握。"%unit,"source":"主线生活事件"})
	for opportunity: Dictionary in data.reviews.opportunities.values():
		var spec: Dictionary = Reviews.catalog()[opportunity.target]
		var first: String = "未作答"
		if not opportunity.answers.is_empty():
			var answer: Dictionary = opportunity.answers[0]
			first = ("未用提示" if answer.unassisted else "有支持或近期接触")+" · "+("正确" if answer.correct else "未正确")
		var detail := "首次作答："+first+"；帮助方式：%s；作答 %d 次" % [HELP_NAMES[int(opportunity.help)],opportunity.answers.size()]
		detail += "\n距最近记录接触："+interval_text(float(opportunity.elapsed_real_seconds))+"（本机时钟）"
		if opportunity.prior_contact: detail += "；近期接触或时间未知"
		if opportunity.paused and opportunity.result.is_empty(): detail += "；已暂存，重开沿用原尝试"
		var outcome: String = opportunity.result if not opportunity.result.is_empty() else "not_correct" if not opportunity.answers.is_empty() else ""
		result.append({"id":opportunity.id,"title":spec.title,"group":"letters" if spec.group=="letters" else "units","dimension":spec.dimension,"result":outcome,"at":float(opportunity.finished_at) if opportunity.finished_at>0 else float(opportunity.started_at),"detail":detail,"source":"朋友回访"})
	for trial: Dictionary in data.journey.p2.trials.values():
		var trials: Array = trial.get("history",[]).duplicate(true)
		trials.append(trial)
		for entry: Dictionary in trials:
			var letter_trial: bool = str(entry.context).begins_with("recall/")
			var first := "未作答"
			if not entry.attempts.is_empty(): first = "正确" if entry.attempts[0].correct else "未正确"
			result.append({"id":entry.id,"title":trial_title(entry.context),"group":"letters" if letter_trial else "units","dimension":entry.dimension,"result":entry.result if entry.completed else "not_correct" if not entry.attempts.is_empty() else "","at":float(entry.finished_at) if entry.finished_at>0 else float(entry.started_at),"detail":"首次作答：%s；帮助方式：%s；作答 %d 次\n时间间隔：未由原活动记录；不推断延迟表现" % [first,["未用额外提示","小提示","较多支持","完整示范"][int(entry.help)],entry.attempts.size()],"source":"原字母 / 章节活动"})
	for session: Dictionary in data.journey.memory.sessions.values():
		var outcome := ""
		if not session.responses.is_empty(): outcome = str(session.responses.back().result)
		elif session.exposure_completed: outcome = "demonstrated"
		var first := "未作答" if session.first_response==null else ("正确" if session.first_response.correct else "未正确")
		result.append({"id":session.invocation_id,"title":entry_title(session.entry_id),"group":"stories","dimension":session.target_dimension,"result":outcome,"at":float(session.updated_at_utc),"detail":"首次作答：%s；帮助方式：%s；线索 %d 次；作答 %d 次\n看完故事与独立作答分别记录；未推断长期掌握" % [first,HELP_NAMES[int(session.max_help_level)],session.cue_events.size(),session.responses.size()],"source":"词故事 · "+str(session.source_unit.unit_id).replace("unit-","Unit ")})
	for id: String in data.learning:
		var record: Dictionary = data.learning[id]
		result.append({"id":"legacy/"+id,"title":legacy_title(id),"group":"legacy","dimension":"written_situation_choice","result":"legacy_aggregate","at":float(record.last_seen),"detail":"原计数：接触 %d 次、辅助正确 %d 次、独立正确 %d 次、作答 %d 次\n旧记录缺少逐次条件，保留原值；不补造首次结果或真实间隔" % [record.exposed,record.assisted,record.independent,record.attempts],"source":"早期情境课汇总"})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.at>b.at if a.at!=b.at else a.id<b.id)
	return result.filter(func(row: Dictionary): return filter=="all" or row.group==filter)

static func trial_title(context: String) -> String:
	if context.begins_with("recall/"):
		var letter := context.split("/")[1]
		return letter+letter.to_lower()+" · "+str(DIMENSIONS.get(P2.trial_spec(context).get("dimension",""),"字母回想"))
	if context=="U1-07": return "U1 · 和校园朋友打招呼"
	if context=="U1-10": return "U1 · 到花园再次问候"
	for chapter: Dictionary in P2.content().chapters.values():
		for step: Dictionary in chapter.steps:
			if step.id==context: return step.title
	return "原生活情境"

static func entry_title(id: String) -> String:
	if _entry_titles.is_empty():
		var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/learning/catalog.json"))
		for entry: Dictionary in content.entries: _entry_titles[entry.entry_id] = str(entry.spelling_display)+" · "+str(entry.meaning_zh)
	return str(_entry_titles.get(id,"旧词故事（词条已变更）"))

static func legacy_title(id: String) -> String:
	if _legacy_titles.is_empty():
		var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/curriculum.json"))
		for question: Dictionary in content.questions: _legacy_titles[question.id] = "原情境课 · "+str(question.prompt)
	return str(_legacy_titles.get(id,"原情境课"))

static func overview(data: Dictionary) -> Dictionary:
	var experienced := 0
	for letter: Dictionary in data.journey.letters.values():
		if letter.experienced: experienced += 1
	var chapters := int(data.journey.u1.completed)+int(data.journey.p2.chapters["2"].completed)+int(data.journey.p2.chapters["3"].completed)
	var attempted: Dictionary = {}
	for opportunity: Dictionary in data.reviews.opportunities.values():
		if not opportunity.answers.is_empty(): attempted[opportunity.target] = true
	return {"experienced":experienced,"chapters":chapters,"available":data.reviews.targets.size(),"attempted_targets":attempted.size(),"all_targets":Reviews.catalog().size(),"observations":rows(data).size()}
