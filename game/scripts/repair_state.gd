class_name RepairState
extends RefCounted
## Scene-independent, reversible puzzle state. Only actual observations can pass inspection.

signal changed
var pressure: float = 1.0
var calibrated: bool = false
var collar_locked: bool = true
var transferred: bool = false
var hose_taken: bool = false
var hose_connected: bool = false
var bypass_open: bool = false
var panel_closed: bool = false
var faucet_on: bool = true
var faucet_was_closed: bool = false
var faucet_tested: bool = false
var kitchen_verified: bool = false
var living_verified: bool = false
var kitchen_seen: bool = false
var living_seen: bool = false
var completed: bool = false
var hint_level: int = 0

func stable() -> bool:
	return pressure <= 0.01 and calibrated and collar_locked and not bypass_open

func kitchen_strength() -> float:
	return pressure if not calibrated else 0.0

func living_strength() -> float:
	return pressure if transferred else 0.0

func invalidate() -> void:
	kitchen_verified = false
	living_verified = false
	faucet_tested = false
	faucet_was_closed = false

func tick(delta: float) -> void:
	if completed:
		return
	var old := pressure
	if bypass_open and hose_connected:
		pressure = maxf(0.0, pressure - delta * 0.14)
		if pressure <= 0.001:
			pressure = 0.0
			transferred = false
	elif not calibrated or pressure > 0.01:
		pressure = minf(1.0, pressure + delta * 0.085)
	if absf(old - pressure) > 0.00001:
		changed.emit()

func act(action: String) -> String:
	if completed:
		return "302 已验收。回到走廊领取下一张工单。"
	if action in ["bypass", "collar", "calibrate", "connect"] and panel_closed:
		return "先打开检修盖。"
	match action:
		"hose":
			if hose_connected:
				return "软管已连接回收罐。"
			hose_taken = true
			changed.emit()
			return "已取下引流软管。两端接口与旁路口匹配。"
		"connect":
			if hose_connected:
				return "旁路已连接。可以操作下方红色阀门。"
			if not hose_taken:
				return "需要引流软管。检修箱旁挂着一根。"
			hose_connected = true
			changed.emit()
			return "软管锁入接口。旁路已连接回收罐。"
		"bypass":
			if not hose_connected:
				return "旁路尚未接通。先用软管连接回收罐。"
			bypass_open = not bypass_open
			invalidate()
			changed.emit()
			return "旁路打开。观察负载表针，等待回到零位。" if bypass_open else "旁路关闭。重新测量以确认负载稳定。"
		"collar":
			collar_locked = not collar_locked
			invalidate()
			changed.emit()
			return "锁环已紧固。" if collar_locked else "锁环松开。方向接头可以转动。"
		"calibrate":
			if collar_locked:
				return "方向接头被锁环固定。先松开下方锁环。"
			calibrated = not calibrated
			if pressure > 0.01:
				transferred = calibrated
			invalidate()
			changed.emit()
			if transferred:
				return "厨房水流恢复了……客厅传来金属摩擦声。"
			return "方向已对齐向下刻度。紧固锁环后完成复测。" if calibrated else "方向接头指向反向刻度。"
		"panel":
			if bypass_open and not panel_closed:
				return "旁路还开着，无法封闭检修盖。"
			if not collar_locked and not panel_closed:
				return "锁环尚未紧固，无法封闭检修盖。"
			panel_closed = not panel_closed
			changed.emit()
			return "检修盖已封闭。" if panel_closed else "检修盖打开。"
		"tap":
			faucet_on = not faucet_on
			if stable():
				if not faucet_on:
					faucet_was_closed = true
				elif faucet_was_closed:
					faucet_tested = true
			else:
				faucet_was_closed = false
				faucet_tested = false
			changed.emit()
			return "水龙头已打开。" if faucet_on else "水龙头已关闭。"
		"submit":
			if not can_complete():
				return "验收尚未完成。按 Tab 查看未通过的检查项。"
			completed = true
			changed.emit()
			return "302 验收通过。回到走廊，打印机有一张新的工单。"
	return ""

func measure(zone: String) -> String:
	match zone:
		"kitchen":
			kitchen_seen = true
			if stable() and faucet_tested:
				kitchen_verified = true
			changed.emit()
			if kitchen_strength() > 0.02:
				return "厨房支路：方向反接 ↑ · 负载 %02d%%" % roundi(pressure * 100)
			return "厨房支路：方向正常 ↓ · 已记录复测" if kitchen_verified else "厨房支路：方向正常 ↓ · 仍需完成水龙头开关测试后复测"
		"living":
			living_seen = true
			if stable() and faucet_tested:
				living_verified = true
			changed.emit()
			if living_strength() > 0.02:
				return "客厅支路：检测到转移负载 ↑ · %02d%%" % roundi(pressure * 100)
			return "客厅支路：方向正常 ↓ · 已记录复测" if living_verified else "客厅支路：方向正常 ↓ · 初始观察已记录"
		"manifold":
			return "总负载 %02d%% · %s" % [roundi(pressure * 100), "可安全校准" if pressure <= 0.01 else "带载调向会影响相邻支路"]
	return "未连接测试点。靠近标有圆形接点的设备。"

func checks() -> Array:
	return [
		["校准完成，锁环紧固，旁路关闭", stable()],
		["水龙头完成关闭 → 打开测试", faucet_tested],
		["厨房接点复测正常", kitchen_verified],
		["客厅接点复测正常", living_verified],
		["检修盖已封闭", panel_closed]
	]

func can_complete() -> bool:
	for check in checks():
		if not check[1]:
			return false
	return true

func next_hint() -> String:
	hint_level += 1
	if completed:
		return "回到走廊，查看打印机的新工单。"
	if not kitchen_seen or not living_seen:
		return "按住右键，对准厨房与客厅的圆形测试接点。比较两处的方向。"
	if not hose_connected:
		return "检修箱旁的软管可以接入旁路。旁路通向下方的回收罐。"
	if pressure > 0.01:
		return "打开红色旁路阀，把这组支路的负载释放到回收罐；表针归零后再校准。"
	if not calibrated:
		return "松开锁环，转动上方方向接头，让箭头朝下。"
	if not collar_locked:
		return "紧固锁环，让方向接头保持在校准位置。"
	if bypass_open:
		return "关闭旁路，然后对水龙头做一次关闭、打开测试。"
	if not faucet_tested:
		return "关闭厨房水龙头，再把它打开，检查水流是否保持正常。"
	if not kitchen_verified or not living_verified:
		return "对准厨房和客厅测试点，分别按住右键，记录修复后的读数。"
	if not panel_closed:
		return "合上检修盖，回到工单完成验收。"
	return "所有验收项已通过。按 Tab 签收工单。"

func serialize() -> Dictionary:
	var data := {"version": 1, "pressure": pressure, "hint_level": hint_level}
	for key in bool_keys():
		data[key] = get(key)
	return data

func restore(data: Dictionary) -> bool:
	if data.get("version", 0) != 1:
		return false
	var saved_pressure = data.get("pressure", 1.0)
	if not (saved_pressure is float or saved_pressure is int):
		return false
	if not is_finite(float(saved_pressure)):
		return false
	for key in bool_keys():
		if not data.get(key, false) is bool:
			return false
	pressure = clampf(float(saved_pressure), 0, 1)
	for key in bool_keys():
		set(key, data.get(key, false))
	var saved_hint = data.get("hint_level", 0)
	hint_level = maxi(0,int(saved_hint)) if saved_hint is int or saved_hint is float else 0
	if bypass_open and not hose_connected:
		bypass_open = false
	if completed and not can_complete():
		completed = false
	changed.emit()
	return true

func bool_keys() -> Array[String]:
	return ["calibrated", "collar_locked", "transferred", "hose_taken", "hose_connected", "bypass_open", "panel_closed", "faucet_on", "faucet_was_closed", "faucet_tested", "kitchen_verified", "living_verified", "kitchen_seen", "living_seen", "completed"]
