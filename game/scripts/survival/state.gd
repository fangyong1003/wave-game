class_name SurvivalState
extends RefCounted
## Authoritative run/profile state. World objects store stable instance IDs, never item templates.
signal changed
signal level_gained(level: int)
const Items = preload("res://scripts/survival/items.gd")
var phase := "safe"
var level := 1
var xp := 0
var points := 0
var attributes := {"strength":0,"constitution":0,"endurance":0,"agility":0}
var hp := 100.0
var stamina := 100.0
var nutrition := 58.0
var hydration := 76.0
var energy_buff := 0.0
var hurt_cooldown := 0.0
var exertion := 0.0
var inventory: Array[Dictionary] = []
var stash: Array[Dictionary] = []
var equipment := {"primary":{"id":"wrench","uid":"starter-wrench"},"secondary":{},"body":{},"feet":{},"pack":{}}
var departure_equipment: Dictionary = {}
var rewarded: Array[String] = []
var consumed: Array[String] = []
var run_id := 0
var serial := 0
var run_kills := 0
var run_xp := 0
var mission_done := false
var has_key := false
var result_text := "先检查装备，再进入南楼。带回至少两瓶饮水。"

func maximum_hp() -> float: return 100.0 + attributes.constitution*10.0
func maximum_stamina() -> float:
	return (100.0+attributes.endurance*10.0) * (0.78 if hydration < 25 else 1.0)
func speed_multiplier() -> float:
	return 1.0+attributes.agility*.02+(.05 if not equipment.feet.is_empty() else 0.0)
func damage_multiplier() -> float: return 1.0+attributes.strength*.06
func armor() -> float: return .18 if not equipment.body.is_empty() else 0.0
func capacity() -> int: return 8 if not equipment.pack.is_empty() else 6
func xp_needed() -> int: return 100+(level-1)*60
func weapon() -> Dictionary:
	return Items.stats(equipment.primary)
func upgrade_melee(uid: String) -> bool:
	if phase!="safe": return false
	for item in inventory+stash+equipment.values():
		if item.get("uid","")==uid and item.get("id","") in ["wrench","bat"] and not item.get("melee_upgrade",false):
			item.melee_upgrade=true
			changed.emit()
			return true
	return false

func has_item(id: String) -> bool: return item_index_by_id(id) >= 0
func item_index_by_id(id: String) -> int:
	for i in range(inventory.size()):
		if inventory[i].id == id: return i
	return -1
func index_of(uid: String, source: Variant = null) -> int:
	var entries: Array = inventory if source == null else source
	for i in range(entries.size()):
		if entries[i].uid == uid: return i
	return -1
func count_item(id: String, bank: bool = false) -> int:
	var count := 0
	for item in stash if bank else inventory:
		if item.id == id: count += 1
	return count
func make_item(id: String) -> Dictionary:
	if not Items.DATA.has(id): return {}
	serial += 1
	var item: Dictionary={"id":id,"uid":"%d-%d" % [run_id,serial]}
	if Items.DATA[id].get("ranged",false): item.loaded=0
	if Items.DATA[id].get("ammunition",false): item.quantity=int(Items.DATA[id].quantity)
	return item
func pickup(item: Dictionary) -> bool:
	if not Items.valid_item(item) or owns_uid(item.uid) or inventory.size() >= capacity(): return false
	inventory.append(item.duplicate(true))
	changed.emit()
	return true
func owns_uid(uid: String) -> bool:
	for item in inventory+stash:
		if item.uid == uid: return true
	for item in equipment.values():
		if item.get("uid","") == uid: return true
	return false
func drop(uid: String) -> Dictionary:
	var index := index_of(uid)
	if index < 0: return {}
	var item: Dictionary = inventory.pop_at(index)
	changed.emit()
	return item
func equip(uid: String, requested_slot: String = "") -> String:
	var index := index_of(uid)
	if index < 0: return "物品已不在背包中。"
	var item: Dictionary = inventory[index]
	var data := Items.definition(item.id)
	if not data.has("slot"): return "这件物品不能穿戴。"
	var slot: String = data.slot
	if requested_slot == "secondary" and slot == "primary": slot = requested_slot
	var previous: Dictionary = equipment[slot]
	var next_size := inventory.size()-1+(0 if previous.is_empty() else 1)
	var next_capacity := 8 if slot == "pack" and item.id == "pack" else capacity()
	if next_size > next_capacity: return "背包空间不足，先处理多出的物品。"
	inventory.remove_at(index)
	if not previous.is_empty(): inventory.append(previous)
	equipment[slot] = item
	clamp_vitals()
	changed.emit()
	return "已装备："+Items.caption(item)
func unequip(slot: String) -> String:
	if not equipment.has(slot) or equipment[slot].is_empty(): return "此位置没有装备。"
	if slot == "primary": return "主武器请通过换装替换，保留一把防身武器。"
	var next_capacity := 6 if slot == "pack" else capacity()
	if inventory.size()+1 > next_capacity: return "需要先腾出背包空间。"
	inventory.append(equipment[slot])
	equipment[slot] = {}
	clamp_vitals()
	changed.emit()
	return "装备已收回背包。"
func swap_weapons() -> bool:
	if equipment.secondary.is_empty(): return false
	var old: Dictionary = equipment.primary
	equipment.primary = equipment.secondary
	equipment.secondary = old
	changed.emit()
	return true
func consume(uid: String) -> bool:
	var index := index_of(uid)
	if index < 0: return false
	var item: Dictionary = inventory[index]
	var data := Items.definition(item.id)
	if data.category != "可食用": return false
	nutrition = minf(100,nutrition+float(data.nutrition))
	hydration = minf(100,hydration+float(data.hydration))
	if item.id == "bar":
		energy_buff = 45
		stamina = minf(maximum_stamina(),stamina+20)
	consumed.append(item.uid)
	inventory.remove_at(index)
	changed.emit()
	return true
func throw_bottle() -> bool:
	var index := item_index_by_id("bottle")
	if index < 0: return false
	consumed.append(inventory[index].uid)
	inventory.remove_at(index)
	changed.emit()
	return true
func ammo_count(id: String) -> int:
	var total:=0
	for item in inventory:
		if item.id==id and Items.DATA[id].get("ammunition",false): total+=int(item.get("quantity",Items.DATA[id].quantity))
	return total
func fire_round(uid: String) -> bool:
	var gun: Dictionary=equipment.primary
	if phase!="run" or gun.get("uid","")!=uid or not weapon().get("ranged",false) or int(gun.get("loaded",0))<=0: return false
	gun.loaded=int(gun.loaded)-1;changed.emit()
	return true
func reload_weapon(uid: String) -> int:
	var data:=weapon();var gun: Dictionary=equipment.primary
	if phase!="run" or gun.get("uid","")!=uid or not data.get("ranged",false): return 0
	var wanted: int=int(data.magazine)-int(gun.get("loaded",0))
	var supplied:=0
	for i in range(inventory.size()-1,-1,-1):
		var item: Dictionary=inventory[i]
		if wanted<=0: break
		if item.id!=data.ammo: continue
		var available: int=int(item.get("quantity",Items.DATA[item.id].quantity))
		var take:=mini(wanted,available);wanted-=take;supplied+=take
		if take==available: consumed.append(item.uid);inventory.remove_at(i)
		else: item.quantity=available-take
	if supplied>0: gun.loaded=int(gun.get("loaded",0))+supplied;changed.emit()
	return supplied
func spend_stamina(amount: float) -> bool:
	if stamina+.001 < amount: return false
	stamina = maxf(0,stamina-amount)
	exertion = .8
	return true
func hurt(amount: float) -> float:
	if phase != "run" or hp <= 0: return 0
	var actual := amount*(1.0-armor())
	hp = maxf(0,hp-actual)
	hurt_cooldown = 10
	changed.emit()
	return actual
func tick(delta: float) -> void:
	if phase != "run" or hp <= 0: return
	exertion = maxf(0,exertion-delta)
	hurt_cooldown = maxf(0,hurt_cooldown-delta)
	energy_buff = maxf(0,energy_buff-delta)
	nutrition = maxf(0,nutrition-delta*.035)
	hydration = maxf(0,hydration-delta*.05)
	if exertion <= 0:
		var recovery: float = 23.0*(1.0+attributes.endurance*.03+(.30 if energy_buff>0 else 0.0))
		if nutrition < 25: recovery *= .65
		stamina = minf(maximum_stamina(),stamina+delta*recovery)
	if nutrition > 70 and hydration > 70 and hurt_cooldown <= 0:
		hp = minf(maximum_hp(),hp+delta*.75)
	clamp_vitals()
func statuses() -> PackedStringArray:
	var entries := PackedStringArray()
	if nutrition > 70 and hydration > 70: entries.append("饱足 · 脱战恢复")
	if nutrition < 25: entries.append("饥饿 · 体力恢复降低")
	if hydration < 25: entries.append("缺水 · 体力上限降低")
	if stamina < 5: entries.append("力竭")
	if hp < maximum_hp()*.3: entries.append("负伤")
	if energy_buff > 0: entries.append("能量充沛 %ds" % ceili(energy_buff))
	return entries
func reward(enemy_id: String, amount: int = 40) -> int:
	if phase != "run" or rewarded.has(enemy_id): return 0
	rewarded.append(enemy_id)
	run_kills += 1
	run_xp += amount
	xp += amount
	while level < 5 and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		points += 1
		level_gained.emit(level)
	if level >= 5: xp = 0
	changed.emit()
	return amount
func add_attribute(key: String) -> bool:
	if not attributes.has(key) or points <= 0 or attributes[key] >= 5: return false
	attributes[key] += 1
	points -= 1
	changed.emit()
	return true
func reset_attributes() -> bool:
	if phase != "safe": return false
	for key in attributes:
		points += int(attributes[key])
		attributes[key] = 0
	clamp_vitals()
	changed.emit()
	return true
func begin_run() -> void:
	phase = "run"
	run_id += 1
	run_kills = 0
	run_xp = 0
	rewarded.clear()
	consumed.clear()
	has_key = false
	departure_equipment = equipment.duplicate(true)
	hp = maximum_hp()
	stamina = maximum_stamina()
	hurt_cooldown = 0
	energy_buff = 0
	exertion = 0
	changed.emit()
func extract() -> bool:
	if phase != "run" or hp <= 0: return false
	var items_taken := inventory.size()
	stash.append_array(inventory)
	inventory.clear()
	phase = "safe"
	mission_done = mission_done or count_item("water",true) >= 2
	result_text = "已带回 %d 件物资 · 击败 %d 名感染者 · 获得 %d 经验\n%s" % [items_taken,run_kills,run_xp,"饮水需求已完成。继续外出，补充储备并提升能力。" if mission_done else "饮水储备 %d / 2。可以整理装备后再次外出。" % count_item("water",true)]
	hp = maximum_hp()
	stamina = maximum_stamina()
	changed.emit()
	return true
func fail_run() -> void:
	if phase != "run": return
	# Returning departure gear must not refill ammunition spent during the run.
	var restored:=departure_equipment.duplicate(true)
	for slot in ["primary","secondary"]:
		var original: Dictionary=restored.get(slot,{})
		if not Items.definition(original.get("id","")).get("ranged",false): continue
		var remaining:=0
		for item in inventory+equipment.values():
			if item.get("uid","")==original.uid: remaining=int(item.get("loaded",0));break
		original.loaded=mini(int(original.get("loaded",0)),remaining)
	inventory.clear()
	equipment = restored
	phase = "dead"
	result_text = "本次背包物资遗失。等级和经验已保留，出发前装备已找回。\n击败 %d 名感染者 · 保留 %d 经验" % [run_kills,run_xp]
	changed.emit()
func return_to_base() -> void:
	phase = "safe"
	hp = maximum_hp()
	stamina = maximum_stamina()
	nutrition = maxf(nutrition,55)
	hydration = maxf(hydration,65)
	changed.emit()
func transfer(uid: String, withdraw: bool) -> bool:
	if phase != "safe": return false
	var source: Array = stash if withdraw else inventory
	var index := index_of(uid,source)
	if index < 0 or (withdraw and inventory.size() >= capacity()): return false
	var item: Dictionary = source.pop_at(index)
	if withdraw: inventory.append(item)
	else: stash.append(item)
	changed.emit()
	return true
func clamp_vitals() -> void:
	hp = clampf(hp,0,maximum_hp())
	stamina = clampf(stamina,0,maximum_stamina())
func serialize() -> Dictionary:
	var out := {"version":2}
	for key in ["phase","level","xp","points","attributes","hp","stamina","nutrition","hydration","energy_buff","hurt_cooldown","exertion","inventory","stash","equipment","departure_equipment","rewarded","consumed","run_id","serial","run_kills","run_xp","mission_done","has_key","result_text"]:
		out[key] = get(key)
	return out.duplicate(true)
func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 2: return false
	if data.get("phase","") not in ["safe","run","dead"]: return false
	for key in ["level","xp","points","hp","stamina","nutrition","hydration","energy_buff","hurt_cooldown","exertion","run_id","serial","run_kills","run_xp"]:
		var value = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0: return false
	if data.level < 1 or data.level > 5: return false
	if not data.get("attributes") is Dictionary: return false
	var total := int(data.points)
	for key in attributes:
		var v = data.attributes.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or v < 0 or v > 5: return false
		total += int(v)
	if total != int(data.level)-1: return false
	var seen := {}
	for name in ["inventory","stash"]:
		if not data.get(name) is Array: return false
		for item in data[name]:
			if not Items.valid_item(item) or seen.has(item.uid): return false
			seen[item.uid] = true
	for name in ["equipment","departure_equipment"]:
		if not data.get(name) is Dictionary: return false
		if name == "departure_equipment" and data[name].is_empty() and data.phase == "safe": continue
		for slot in Items.SLOTS:
			var item = data[name].get(slot)
			if not item is Dictionary: return false
			if item.is_empty():
				if slot == "primary": return false
				continue
			if not Items.valid_item(item): return false
			var expected = Items.DATA[item.id].get("slot","")
			if expected != slot and not (slot == "secondary" and expected == "primary"): return false
			if name == "equipment":
				if seen.has(item.uid): return false
				seen[item.uid] = true
	var cap := 6 if data.equipment.pack.is_empty() else 8
	if data.inventory.size() > cap: return false
	for key in ["rewarded","consumed"]:
		if not data.get(key) is Array: return false
		for value in data[key]:
			if not value is String: return false
	for key in ["mission_done","has_key"]:
		if not data.get(key) is bool: return false
	if not data.get("result_text") is String: return false
	# Only mutate after validating the complete snapshot.
	for key in serialize().keys():
		if key == "version": continue
		if key == "inventory": inventory.assign(data[key])
		elif key == "stash": stash.assign(data[key])
		elif key == "rewarded": rewarded.assign(data[key])
		elif key == "consumed": consumed.assign(data[key])
		elif key in ["level","xp","points","run_id","serial","run_kills","run_xp"]: set(key,int(data[key]))
		else: set(key,data[key].duplicate(true) if data[key] is Dictionary else data[key])
	nutrition = clampf(nutrition,0,100)
	hydration = clampf(hydration,0,100)
	clamp_vitals()
	changed.emit()
	return true
