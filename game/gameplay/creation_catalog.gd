extends RefCounted
## Shared content for the workshop, inventory, world objects and economy.

const MATERIALS := {
	"wood": {"name":"木料", "en":"wood", "room":"home_estate", "daily":4, "buy":4, "sell":1},
	"fiber": {"name":"纤维", "en":"fiber", "room":"home_estate", "daily":3, "buy":3, "sell":1},
	"clay": {"name":"黏土", "en":"clay", "room":"landmark_F", "daily":2, "buy":4, "sell":1},
	"apple": {"name":"苹果", "en":"apple", "room":"landmark_A", "daily":3, "buy":6, "sell":2},
	"flower": {"name":"花材", "en":"flowers", "room":"landmark_F", "daily":3, "buy":3, "sell":1},
	"stone": {"name":"石料", "en":"stone", "room":"landmark_A", "daily":2, "buy":4, "sell":1}
}
const RECIPES := {
	"stool": {"name":"小木凳", "en":"stool", "cost":{"wood":2,"fiber":1}, "sale":13, "recycle":5, "use":"seat"},
	"table": {"name":"小圆桌", "en":"table", "cost":{"wood":3,"clay":1}, "sale":19, "recycle":8, "use":"table"},
	"sign": {"name":"自绘招牌", "en":"sign", "cost":{"wood":1,"fiber":1}, "sale":9, "recycle":3, "use":"display"},
	"frame": {"name":"装饰画框", "en":"picture", "cost":{"wood":1,"fiber":1}, "sale":9, "recycle":3, "use":"display"},
	"rug": {"name":"编织地毯", "en":"rug", "cost":{"fiber":3}, "sale":11, "recycle":4, "use":"display"},
	"vase": {"name":"小花瓶", "en":"vase", "cost":{"clay":2,"flower":1}, "sale":13, "recycle":5, "use":"display"},
	"basket": {"name":"编织收纳篮", "en":"basket", "cost":{"fiber":2}, "sale":8, "recycle":3, "use":"storage"},
	"lantern": {"name":"星星灯笼", "en":"lamp", "cost":{"wood":2,"stone":1,"fiber":1}, "sale":18, "recycle":7, "use":"light"},
	"shelf": {"name":"小绘本架", "en":"bookshelf", "cost":{"wood":4,"fiber":1}, "sale":22, "recycle":9, "use":"books"},
	"stand": {"name":"手作陈列台", "en":"display stand", "cost":{"wood":3,"fiber":2}, "sale":21, "recycle":9, "use":"stall"},
	"cake": {"name":"苹果蛋糕", "en":"apple cake", "cost":{"apple":3}, "sale":20, "recycle":15, "use":"food"},
	"plate": {"name":"苹果果盘", "en":"apple plate", "cost":{"apple":2}, "sale":14, "recycle":8, "use":"food"}
}
const PALETTE := ["fff9eb","f2d49b","b98759","704f3b","ead5ca","e78d8d","bd5969","efb951","9fbb7d","54775e","8acac2","5d91ba","8074b3","c3abd1","586173","292f3a"]
const STAMPS := {"dots":"圆点", "stripes":"条纹", "star":"星星", "apple":"苹果", "check":"格纹", "flower":"花朵", "owl":"猫头鹰", "music":"音符"}
const FRIENDS := {"npc_bear_uncle":"熊叔", "textbook_lingling":"Lingling", "textbook_anne":"Anne"}
const ROOMS := {"home":"客厅", "home_estate":"小院", "landmark_A":"A 果园", "landmark_C":"C 烘焙坊", "landmark_F":"F 花园"}
const ORDERS := [
	{"name":"阅读角需要一个座位", "recipes":["stool"], "room":"home", "friend":"npc_bear_uncle"},
	{"name":"想挂一幅新的装饰画", "recipes":["frame"], "room":"landmark_F", "friend":"花婆婆"},
	{"name":"请帮我准备点心", "recipes":["cake","plate"], "room":"landmark_A", "friend":"阿梨"},
	{"name":"想给生活角挂个名字", "recipes":["sign"], "room":"landmark_C", "friend":"米洛"},
	{"name":"想在桌上摆一束花", "recipes":["vase"], "room":"landmark_F", "friend":"花婆婆"}
]

static func blank_design(recipe: String) -> Dictionary:
	return {"recipe":recipe, "name":str(RECIPES.get(recipe, {}).get("name", "我的作品")), "version":1,
		"color":2, "shape":0, "trim":0, "pattern":"0".repeat(4096), "text":"", "repeat":false, "series":"", "keepsake":""}

static func cost_text(recipe: String, data: Dictionary = {}) -> String:
	var parts: PackedStringArray = []
	for id: String in RECIPES[recipe].cost:
		var amount: int = RECIPES[recipe].cost[id]
		var have: int = int(data.get("apples", 0)) if id == "apple" else int(data.get("creation", {}).get("materials", {}).get(id, 0))
		parts.append("%s %d%s" % [MATERIALS[id].name, amount, "（已有 %d）" % have if not data.is_empty() else ""])
	return "  ·  ".join(parts)

static func known_friend(data: Dictionary, id: String) -> bool:
	var journey: Dictionary = data.get("journey", {})
	var steps: Array = journey.get("u1", {}).get("steps", [])
	return id == "npc_bear_uncle" or (id == "textbook_lingling" and steps.has("U1-03")) or (id == "textbook_anne" and steps.has("U1-07"))

static func available(data: Dictionary) -> bool:
	var j: Dictionary = data.get("journey", {})
	return j.get("home_steps", []).size() == 4 or bool(j.get("legacy_compatible", false))
