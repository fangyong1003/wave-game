class_name SurvivalItems
extends RefCounted

const DATA := {
	"water":{"name":"瓶装水","category":"可食用","note":"水分 +45。带回 2 瓶，完成饮水需求。","hydration":45.0,"nutrition":0.0},
	"can":{"name":"午餐肉罐头","category":"可食用","note":"饱食 +40。饱食与水分充足时，脱战可缓慢回血。","hydration":0.0,"nutrition":40.0},
	"bar":{"name":"能量棒","category":"可食用","note":"饱食 +22，体力 +20；45 秒内体力恢复加快。","hydration":0.0,"nutrition":22.0},
	"wrench":{"name":"旧扳手","category":"武器","slot":"primary","note":"单手交替敲击，出手快。蓄力 0.36 秒后向下重砸。","damage":34.0,"heavy":62.0,"reach":1.65,"cost":14.0,"heavy_cost":28.0,"recovery":0.55,"impact":1.0},
	"bat":{"name":"棒球棍","category":"武器","slot":"primary","note":"双手横扫，距离更长、失衡更强。蓄力 0.55 秒后斜劈；收招慢。","damage":45.0,"heavy":78.0,"reach":2.0,"cost":19.0,"heavy_cost":35.0,"recovery":0.76,"impact":1.35},
	"bottle":{"name":"空玻璃瓶","category":"武器","note":"投掷后碎裂，响声可以吸引感染者。"},
	"crossbow":{"name":"猎用弩","category":"武器","slot":"primary","ranged":true,"ammo":"bolts","magazine":1,"damage":76.0,"headshot":1.5,"range":40.0,"reload":1.85,"interval":.65,"noise":5.0,"note":"安静的单发弩。弩箭有飞行时间和下坠，逐发上弦；命中感染者的弩箭可搜尸回收。"},
	"pistol":{"name":"9mm 手枪","category":"武器","slot":"primary","ranged":true,"ammo":"pistol_ammo","magazine":8,"damage":38.0,"headshot":2.5,"range":55.0,"reload":1.45,"interval":.28,"noise":24.0,"note":"半自动射击，8 发弹匣。单次发射一发；枪声会吸引附近感染者。"},
	"bolts":{"name":"弩箭包","category":"武器","ammunition":true,"quantity":6,"max_quantity":24,"note":"仅供猎用弩使用。每包占一格；余量随物品保存。"},
	"pistol_ammo":{"name":"9mm 弹药盒","category":"武器","ammunition":true,"quantity":12,"max_quantity":60,"note":"仅供 9mm 手枪使用。每盒占一格；余量随物品保存。"},
	"coat":{"name":"加厚防护外套","category":"穿戴","slot":"body","note":"减伤 18%；冲刺体力消耗 +15%。","armor":0.18},
	"shoes":{"name":"轻便运动鞋","category":"穿戴","slot":"feet","note":"移动速度 +5%，脚步声范围 -20%。","speed":0.05},
	"pack":{"name":"登山背包","category":"穿戴","slot":"pack","note":"携带容量由 6 格扩充到 8 格。","capacity":8}
}
const SLOTS := {"primary":"主武器","secondary":"备用武器","body":"上身","feet":"鞋","pack":"背包"}
const ATTRIBUTES := {"strength":"力量","constitution":"体质","endurance":"耐力","agility":"敏捷"}

static func definition(id: String) -> Dictionary:
	return DATA.get(id,{})

static func stats(item: Dictionary) -> Dictionary:
	var data: Dictionary=definition(str(item.get("id",""))).duplicate(true)
	if item.get("melee_upgrade",false) and item.get("id","") in ["wrench","bat"]:
		data.melee_upgrade=true
		data.name += " · 破势" if item.id=="wrench" else " · 破阵"
		data.note = "三段连击：斜击、上挑、下砸追击。连续点击衔接，命中后可提前接下一段。" if item.id=="wrench" else "重击击飞目标，撞倒路径中的敌人；撞墙造成二次重创。轻击横扫多个目标。"
		if item.id=="bat": data.heavy=108.0
	return data

static func caption(item: Dictionary) -> String:
	var data: Dictionary=stats(item)
	var text: String=str(data.get("name","空"))
	if data.get("ammunition",false): text+=" ×%d" % int(item.get("quantity",data.quantity))
	if data.get("ranged",false): text+=" [%d/%d]" % [int(item.get("loaded",0)),int(data.magazine)]
	return text

static func valid_item(item: Variant) -> bool:
	if not (item is Dictionary and DATA.has(item.get("id","")) and item.get("uid") is String and not item.uid.is_empty()): return false
	var data: Dictionary=DATA[item.id]
	if item.has("melee_upgrade") and (not item.melee_upgrade is bool or item.id not in ["wrench","bat"]): return false
	if data.get("ranged",false) and not valid_count(item.get("loaded",0),0,int(data.magazine)): return false
	if data.get("ammunition",false) and not valid_count(item.get("quantity",data.quantity),1,int(data.max_quantity)): return false
	return true

static func valid_count(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
