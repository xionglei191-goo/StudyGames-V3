extends RefCounted
## Pure transactions. The caller commits the complete candidate through State's atomic save.
const C = preload("res://gameplay/creation_catalog.gd")
const OWNED := ["inventory", "placed", "stall", "community"]
const MAX_DESIGNS := 96
const MAX_ITEMS := 512
const MAX_MEMORIES := 4096
const LEGACY_USES := {"reading_sofa":["stool","云朵双人沙发"],"tea_table":["table","下午茶圆桌"],"walnut_bookshelf":["shelf","童话绘本架"],"star_floor_lamp":["lantern","摘星落地灯"],"potted_monstera":["vase","阳光龟背竹"],"trophy_chapter_easel":["frame","章节纪念画架"]}

static func fresh() -> Dictionary:
	return {"schema":1, "revision":0, "next_id":1, "started":false, "wish":"reading", "materials":{"wood":0,"fiber":0,"clay":0,"flower":0,"stone":0},
		"gathered":{}, "recipes":["stool","table","sign","frame"], "stamps":["dots","stripes","star"], "designs":{}, "draft":{}, "items":{},
		"orders":{}, "order_next":0, "stall":{"slots":1,"open":false,"session":0,"served":0,"income":0,"total":0}, "memories":[], "visit":{}, "community_done":false}

static func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

static func ok(message: String = "已保存。", id: String = "") -> Dictionary:
	return {"ok":true,"message":message,"id":id}

static func number(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func canonical(value: Variant) -> Variant:
	# JSON parses numbers as floats. Restore integer counters just like the original
	# State schema, keeping fractional coordinates intact and snapshots comparable.
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(canonical(entry))
		return result
	return value

static func valid_design(d: Variant) -> bool:
	if not d is Dictionary or not C.RECIPES.has(d.get("recipe", "")): return false
	for key: String in ["name", "text", "series"]:
		if not d.get(key) is String or str(d[key]).length() > 64: return false
	if not d.get("keepsake") is String or str(d.keepsake).length()>256: return false
	if not number(d.get("version"),1,1000000) or not number(d.get("color"),0,15) or not number(d.get("shape"),0,1) or not number(d.get("trim"),0,2): return false
	if not d.get("repeat") is bool or not d.get("pattern") is String or d.pattern.length() != 4096: return false
	for ch: String in d.pattern:
		if not "0123456789abcdef".contains(ch): return false
	return true

static func validate(value: Variant, total_cakes: int) -> bool:
	if not value is Dictionary: return false
	var s: Dictionary = value
	for key: String in fresh():
		if not s.has(key) or typeof(s[key]) != typeof(fresh()[key]) and not (s[key] is float and fresh()[key] is int): return false
	if s.schema != 1 or not number(s.revision,0,1000000000) or not number(s.next_id,1,1000000000) or s.wish not in ["reading","collection","stall"]: return false
	if s.designs.size() > MAX_DESIGNS or s.items.size() > MAX_ITEMS or s.orders.size() > 3 or s.memories.size() > MAX_MEMORIES: return false
	for key: String in ["wood","fiber","clay","flower","stone"]:
		if not number(s.materials.get(key),0,1000000): return false
	for key: Variant in s.gathered:
		if not C.MATERIALS.has(key) or not s.gathered[key] is Dictionary: return false
		if not number(s.gathered[key].get("day"),1,1000000) or not number(s.gathered[key].get("count"),0,int(C.MATERIALS[key].daily)): return false
	for id: Variant in s.recipes:
		if not C.RECIPES.has(id): return false
	for id: Variant in s.stamps:
		if not C.STAMPS.has(id): return false
	if not s.draft.is_empty() and not valid_design(s.draft): return false
	for id: Variant in s.designs:
		if not id is String or not valid_design(s.designs[id]): return false
	var cakes := 0
	var community := 0
	var stock := 0
	var occupied_supports: Dictionary = {}
	for id: Variant in s.items:
		var i: Variant = s.items[id]
		if not id is String or not i is Dictionary or not valid_design(i.get("design")): return false
		if i.get("where") not in OWNED + ["gifted","sold","consumed","recycled","delivered"]: return false
		if not i.get("source") is String or not i.get("recipient") is String or not i.get("room") is String or not i.get("lit") is bool: return false
		if not i.get("position") is Array or i.position.size() != 3 or not number(i.get("rotation"),0,359): return false
		for axis: Variant in i.position:
			if not (axis is int or axis is float) or not is_finite(float(axis)) or absf(float(axis)) > 200: return false
		if i.where == "placed" and i.room not in ["home","home_estate"]: return false
		var support: String = str(i.get("support", ""))
		if not support.is_empty():
			if not s.items.has(support) or i.where != "placed": return false
			var base: Variant = s.items[support]
			if not base is Dictionary or not valid_design(base.get("design")) or not base.get("position") is Array or base.position.size()!=3: return false
			if base.get("where") != "placed" or base.get("room") != i.room or base.design.recipe not in ["table","stand"] or occupied_supports.has(support): return false
			occupied_supports[support]=true
		if i.where == "community": community += 1
		if i.where == "stall": stock += 1
		if i.design.recipe == "cake" and i.where in OWNED: cakes += 1
	if cakes > total_cakes or community > 1: return false
	var t: Dictionary = s.stall
	if not t.get("open") is bool or not number(t.get("slots"),1,3) or stock > int(t.slots): return false
	for key: String in ["served","income","total","session"]:
		if not number(t.get(key),0,1000000000): return false
	if t.served > 3 or not number(s.order_next,0,1000000000): return false
	for id: Variant in s.orders:
		if not s.orders[id] is Dictionary or not number(s.orders[id].get("kind"),0,C.ORDERS.size()-1) or not s.orders[id].get("accepted") is bool: return false
	for m: Variant in s.memories:
		if not m is Dictionary or not m.get("text") is String or str(m.text).length() > 300: return false
	if not s.visit.is_empty():
		if not C.FRIENDS.has(s.visit.get("friend", "")) or s.visit.get("room") not in ["home","home_estate","landmark_F"] or s.visit.get("status") not in ["arriving","using","done"]: return false
	return true

static func uid(s: Dictionary, prefix: String) -> String:
	var id := prefix + str(int(s.next_id))
	s.next_id += 1
	return id

static func unlock(s: Dictionary, recipes: Array = [], stamps: Array = []) -> void:
	for id: String in recipes:
		if not s.recipes.has(id): s.recipes.append(id)
	for id: String in stamps:
		if not s.stamps.has(id): s.stamps.append(id)

static func remember(s: Dictionary, message: String, item_id: String = "", actor: String = "") -> void:
	for entry: Dictionary in s.memories:
		if entry.text==message and str(entry.get("item",""))==item_id and str(entry.get("friend",""))==actor: return
	s.memories.append({"text":message.left(300), "item":item_id, "friend":actor})

static func amount(data: Dictionary, id: String) -> int:
	return int(data.apples) if id == "apple" else int(data.creation.materials.get(id,0))

static func add_material(data: Dictionary, id: String, delta: int) -> void:
	if id == "apple": data.apples += delta
	else: data.creation.materials[id] += delta

static func owned_cakes(data: Dictionary) -> int:
	var count := 0
	for i: Dictionary in data.get("creation", {}).get("items", {}).values():
		if i.design.recipe == "cake" and i.where in OWNED: count += 1
	return count

static func visit_work(data: Dictionary, id: String) -> Dictionary:
	if not id.begins_with("legacy:"): return data.creation.items.get(id,{})
	var parts := id.split(":")
	if parts.size()!=3 or not parts[2].is_valid_int(): return {}
	var room: String=parts[1]
	var index: int=int(parts[2])
	var placed: Array = data.get("v4",{}).get("free_decor_placed",{}).get(room,[])
	if index<0 or index>=placed.size() or not LEGACY_USES.has(str(placed[index].id)): return {}
	var item: Dictionary=placed[index]
	var spec: Array=LEGACY_USES[str(item.id)]
	var d:=C.blank_design(spec[0])
	d.name=spec[1]
	return {"where":"placed","room":room,"position":[item.x,item.y,item.z],"rotation":int(item.rot),"design":d,"source":"original_furniture"}

static func legacy_sell(data: Dictionary) -> bool:
	if int(data.cakes) > owned_cakes(data): return true
	for i: Dictionary in data.get("creation", {}).get("items", {}).values():
		if i.design.recipe == "cake" and i.where == "inventory":
			i.where = "recycled"
			data.creation.revision += 1
			return true
	return false

static func make(data: Dictionary, design: Dictionary, source: String) -> Dictionary:
	var s: Dictionary = data.creation
	if s.items.size() >= MAX_ITEMS: return fail("作品记录已满，请先导出存档保留作品；没有扣除材料。")
	var recipe: String = design.recipe
	if not s.recipes.has(recipe): return fail("先跟居民学会这份配方。")
	for material: String in C.RECIPES[recipe].cost:
		if amount(data, material) < int(C.RECIPES[recipe].cost[material]): return fail("材料还不够，可以先保存设计，再去采集或补料。")
	for material: String in C.RECIPES[recipe].cost:
		add_material(data, material, -int(C.RECIPES[recipe].cost[material]))
	var id := uid(s,"work-")
	s.items[id] = {"design":design.duplicate(true), "source":source, "where":"inventory", "recipient":"", "room":"", "position":[0,0,0], "rotation":0, "lit":true}
	if recipe == "cake": data.cakes += 1
	unlock(s,["rug","basket"])
	return ok("做成了「%s」，已收入仓库。" % design.name,id)

static func order_fill(s: Dictionary) -> void:
	while s.orders.size() < 3:
		var id := uid(s,"order-")
		s.orders[id] = {"kind":int(s.order_next) % C.ORDERS.size(), "accepted":false}
		s.order_next += 1

static func transfer(data: Dictionary, id: String, where: String, recipient: String = "") -> void:
	var i: Dictionary = data.creation.items[id]
	if i.design.recipe == "cake" and i.where in OWNED and where not in OWNED: data.cakes -= 1
	i.where = where
	i.recipient = recipient

static func apply(data: Dictionary, action: String, args: Dictionary, expected_revision: int) -> Dictionary:
	if not data.has("creation"): data.creation = fresh()
	var s: Dictionary = data.creation
	if int(s.revision) != expected_revision: return fail("刚才的内容已有变化，请重新查看后确认。")
	if not C.available(data): return fail("先和熊叔完成家园的四步介绍，再来开始自己的生活项目。")
	if action != "start" and not s.started: return fail("先领取工坊材料，选择一个生活心愿。")
	if s.memories.size()>=MAX_MEMORIES and action in ["visit_used","photo","gift","sell","order_deliver","community","eat"]:
		return fail("生活回忆册已满。旧照片和记录全部保留，这次还没有交付或扣除物品。")
	var result := _apply(data,action,args)
	if result.ok:
		s.revision += 1
	return result

static func _apply(data: Dictionary, action: String, a: Dictionary) -> Dictionary:
	var s: Dictionary = data.creation
	var id := str(a.get("id", ""))
	var room := str(a.get("room", ""))
	match action:
		"start":
			if s.started: return fail("开场材料已经领取。")
			s.started = true
			for m: String in {"wood":6,"fiber":4,"clay":2,"flower":2}: s.materials[m] += {"wood":6,"fiber":4,"clay":2,"flower":2}[m]
			if bool(data.quests.delivery_done): unlock(s,["cake"])
			order_fill(s)
			return ok("工坊已开放：木料 6、纤维 4、黏土 2、花材 2 已收入仓库。")
		"wish":
			if id not in ["reading","collection","stall"]: return fail("请选择一个生活心愿。")
			s.wish = id
		"gather", "buy", "sell_material":
			if not C.MATERIALS.has(id): return fail("这里没有这份材料。")
			var m: Dictionary = C.MATERIALS[id]
			if action == "gather":
				if room != m.room: return fail("这份材料在%s。" % C.ROOMS[m.room])
				var g: Dictionary = s.gathered.get(id,{"day":data.day,"count":0})
				if int(g.day) != int(data.day): g = {"day":data.day,"count":0}
				var used: int = int(data.harvested) if id == "apple" else int(g.count)
				if used >= int(m.daily): return fail("今天这一批已取完，回家休息后会恢复。")
				if id == "apple":
					data.harvested += 1
					unlock(s,[],["apple"])
				g.count = used + 1
				s.gathered[id] = g
			elif action == "buy":
				if int(data.coins) < int(m.buy): return fail("叶币不足，可以先去免费采集。")
				data.coins -= int(m.buy)
			else:
				if amount(data,id) < 1: return fail("仓库里没有这份材料。")
				data.coins += int(m.sell)
			add_material(data,id,-1 if action == "sell_material" else 1)
			return ok("%s %s 1 份。" % ["已回收" if action == "sell_material" else "获得",m.name])
		"learn":
			if room == "landmark_C":
				unlock(s,["cake","plate"],["check"])
				return ok("米洛演示了苹果点心的做法。蛋糕、果盘配方和格纹已收入作品册。")
			if room == "landmark_F":
				unlock(s,["vase"],["flower"])
				return ok("花婆婆演示了插花。小花瓶配方和花朵印章已收入作品册。")
			return fail("去 C 烘焙坊找米洛，或去 F 花园找花婆婆一起学手艺。")
		"draft", "design":
			var d: Variant = a.get("design")
			if not valid_design(d): return fail("这份设计暂时无法保存，原作品仍保留。")
			if not s.recipes.has(d.recipe): return fail("先学习这份配方。")
			if action == "draft":
				s.draft = d.duplicate(true)
				return ok("草稿已保存。")
			d.erase("source_design")
			if id.is_empty():
				if s.designs.size() >= MAX_DESIGNS: return fail("作品册已满，请先整理设计；草稿仍保留。")
				id = uid(s,"design-")
				d.version = 1
			elif not s.designs.has(id) or s.designs[id].recipe != d.recipe: return fail("请另存为一份新设计。")
			else: d.version = int(s.designs[id].version) + 1
			s.designs[id] = d.duplicate(true)
			s.draft = d.duplicate(true)
			return ok("设计已保存，可以随时再制作。",id)
		"delete_design":
			if not s.designs.has(id): return fail("这份设计已不在作品册。")
			s.designs.erase(id)
		"craft":
			if not s.designs.has(id): return fail("先保存一份设计。")
			return make(data,s.designs[id],id)
		"order_accept", "order_cancel", "order_replace":
			if not s.orders.has(id): return fail("这张订单已更新。")
			if action=="order_replace":
				s.orders.erase(id)
				order_fill(s)
			else: s.orders[id].accepted = action == "order_accept"
		"order_deliver":
			var order_id := str(a.get("order", ""))
			if not s.orders.has(order_id) or not s.orders[order_id].accepted: return fail("先接下这张订单。")
			var order: Dictionary = C.ORDERS[int(s.orders[order_id].kind)]
			if room != order.room: return fail("把作品送到%s。" % C.ROOMS[order.room])
			if not s.items.has(id) or s.items[id].where != "inventory" or not order.recipes.has(s.items[id].design.recipe): return fail("请选择仓库里符合需求的作品。")
			var item: Dictionary = s.items[id]
			if item.design.recipe == "sign" and str(item.design.text).strip_edges().is_empty(): return fail("这张订单需要名字，请用文字工具写在招牌上。")
			var price: int = int(C.RECIPES[item.design.recipe].sale)
			transfer(data,id,"delivered",str(order.friend))
			data.coins += price
			remember(s,"%s 收到「%s」，付了 %d 叶币。" % [order.friend,item.design.name,price],id,str(order.friend))
			s.orders.erase(order_id)
			order_fill(s)
			return ok("送到了！获得 %d 叶币。" % price)
		"stall_open":
			if room != "home_estate": return fail("到小院的小摊开张。")
			if not s.visit.is_empty() and s.visit.status != "done" and s.visit.room==room: return fail("先结束朋友来访，再开始营业。")
			if s.stall.open: return fail("这次营业还在继续。")
			if items_at(s,"stall").is_empty(): return fail("先陈列一件自己的作品。")
			s.stall.open = true
			s.stall.session += 1
			s.stall.served = 0
			s.stall.income = 0
		"stall_close":
			s.stall.open = false
			for i: Dictionary in s.items.values():
				if i.where == "stall": i.where = "inventory"
		"stall_expand":
			var slots: int = int(s.stall.slots)
			if slots >= 3: return fail("已经有三个陈列位。")
			var price := 24 if slots == 1 else 36
			if data.coins < price: return fail("叶币还不够。")
			data.coins -= price
			s.stall.slots += 1
		"visit_start":
			if room not in ["home","home_estate","landmark_F"] or not C.known_friend(data,id): return fail("先在旅程中认识这位朋友。")
			if not s.visit.is_empty() and s.visit.status != "done": return fail("先接着完成这次来访。")
			if s.stall.open and room == "home_estate": return fail("先收摊，再请朋友来坐坐。")
			s.visit = {"id":uid(s,"visit-"),"friend":id,"room":room,"status":"arriving"}
		"visit_used":
			if s.visit.is_empty() or s.visit.status != "arriving": return fail("先邀请一位朋友来坐坐。")
			var work := visit_work(data,id)
			if work.is_empty() or work.where not in ["placed","community"]: return fail("先摆好一件作品，再邀请朋友使用。")
			if (work.where == "placed" and work.room != s.visit.room) or (work.where == "community" and s.visit.room != "landmark_F"): return fail("朋友还没有来到这件作品旁。")
			s.visit.status = "using"
			var friend: String = s.visit.friend
			remember(s,"%s 在%s%s了「%s」。" % [C.FRIENDS[friend],C.ROOMS[s.visit.room],"坐着试用" if work.design.recipe == "stool" else "观看",work.design.name],id,friend)
			unlock(s,["lantern","shelf","stand"],["owl"] if friend == "textbook_lingling" else ["music"] if friend == "textbook_anne" else [])
		"visit_end":
			if not s.visit.is_empty(): s.visit.status = "done"
		"photo":
			if s.visit.is_empty() or s.visit.status != "using" or s.visit.room != room: return fail("先和来访朋友一起使用作品，再拍照留念。")
			if s.visit.has("photo_path"): return fail("这次来访已经留下照片，可以到生活回忆里查看。")
			var path := str(a.get("path",""))
			if not path.begins_with("user://creation-photos/") or path.length()>256: return fail("照片还没有准备好。")
			s.visit.photo_path=path
			s.memories.append({"text":"和%s在%s的合照。" % [C.FRIENDS[s.visit.friend],C.ROOMS[room]],"image_path":path,"item":"","friend":s.visit.friend})
		"place", "place_on", "store", "apply_design", "gift", "community", "stock", "sell", "recycle", "eat", "light":
			if not s.items.has(id): return fail("找不到这件作品。")
			var item: Dictionary = s.items[id]
			if item.where not in OWNED: return fail("这件作品已经送出或使用了。")
			if action == "store":
				item.where = "inventory"
				item["support"] = ""
				for child: Dictionary in s.items.values():
					if str(child.get("support",""))==id:
						child.where="inventory"
						child.support=""
			elif action == "light":
				if item.design.recipe != "lantern": return fail("这件作品没有灯光开关。")
				item.lit = not item.lit
			elif action == "place":
				if room not in ["home","home_estate"] or item.where not in ["inventory","placed"]: return fail("请先把作品收回仓库，再放在客厅或小院。")
				var pos: Variant = a.get("position")
				if not pos is Array or pos.size() != 3: return fail("请先选定摆放位置。")
				item.where = "placed"
				item.room = room
				item.position = pos.duplicate()
				item.rotation = posmod(int(a.get("rotation",0)),360)
				item["support"] = ""
				for child: Dictionary in s.items.values():
					if str(child.get("support",""))==id:
						child.position=[pos[0],float(pos[1])+0.98,pos[2]]
						child.rotation=item.rotation
						child.room=room
			elif action == "place_on":
				var support := str(a.get("support",""))
				if item.where != "inventory" or item.design.recipe not in ["vase","cake","plate"] or not s.items.has(support): return fail("从仓库选择花瓶或点心，再选一张已经摆好的桌子。")
				var base: Dictionary = s.items[support]
				if base.where != "placed" or base.design.recipe not in ["table","stand"]: return fail("先在家里摆好桌子或陈列台。")
				for child: Dictionary in s.items.values():
					if str(child.get("support",""))==support: return fail("这个桌面已有作品，请先收好它。")
				item.where="placed"
				item.room=base.room
				item.position=[base.position[0],float(base.position[1])+0.98,base.position[2]]
				item.rotation=base.rotation
				item["support"]=support
			elif action == "apply_design":
				var design_id := str(a.get("design", ""))
				if not s.designs.has(design_id) or s.designs[design_id].recipe != item.design.recipe: return fail("只能换成同一种物件的设计。")
				if item.where not in ["inventory","placed"]: return fail("先收回作品，再换外观。")
				item.design = s.designs[design_id].duplicate(true)
			elif action == "community":
				if room != "landmark_F" or item.where != "inventory" or item.design.recipe not in ["frame","vase","stool"]: return fail("带一件画框、花瓶或小凳，到 F 花园的邻里作品角借展。")
				for old: Dictionary in s.items.values():
					if old.where == "community": old.where = "inventory"
				item.where = "community"
				if not s.community_done:
					s.community_done = true
					remember(s,"邻里作品角开放了，第一件借展是「%s」。" % item.design.name,id)
				unlock(s,["lantern","shelf","stand"])
			elif action == "stock":
				if item.where != "inventory" or items_at(s,"stall").size() >= int(s.stall.slots): return fail("请先腾出一个陈列位。")
				item.where = "stall"
			elif action == "sell":
				if room != "home_estate" or not s.stall.open or int(s.stall.served) >= 3 or item.where != "stall": return fail("先开摊并陈列作品；每次最多接待三位顾客。")
				var price: int = int(C.RECIPES[item.design.recipe].sale)
				var customer: String = ["熊叔","阿梨","米洛"][int(s.stall.served)]
				transfer(data,id,"sold",customer)
				data.coins += price
				s.stall.served += 1
				s.stall.income += price
				s.stall.total += price
				remember(s,"%s 买下「%s」，支付 %d 叶币。" % [customer,item.design.name,price],id,customer)
				return ok("%s 带走了作品，%d 叶币已到账。" % [customer,price])
			else:
				if item.where != "inventory": return fail("先把作品收回仓库。")
				if action == "gift":
					var friend := str(a.get("friend", ""))
					if not C.known_friend(data,friend): return fail("先在旅程中认识这位朋友。")
					transfer(data,id,"gifted",friend)
					remember(s,"%s 收到了你的「%s」。" % [C.FRIENDS[friend],item.design.name],id,friend)
				elif action == "recycle":
					transfer(data,id,"recycled")
					data.coins += int(C.RECIPES[item.design.recipe].recycle)
				elif action == "eat":
					if C.RECIPES[item.design.recipe].use != "food": return fail("请选择一份点心。")
					var friend := "自己"
					if not s.visit.is_empty() and s.visit.status == "using" and s.visit.room == room: friend = str(C.FRIENDS[s.visit.friend])
					transfer(data,id,"consumed",friend)
					remember(s,"%s 品尝了「%s」。" % [friend,item.design.name],id)
		_:
			return fail("这个操作暂时不可用。")
	return ok()

static func items_at(s: Dictionary, where: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in s.items:
		if s.items[id].where == where: result.append(id)
	return result
