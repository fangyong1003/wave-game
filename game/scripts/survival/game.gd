extends Node3D
const State = preload("res://scripts/survival/state.gd")
const Items = preload("res://scripts/survival/items.gd")
const Player = preload("res://scripts/survival/player.gd")
const World = preload("res://scripts/survival/world.gd")
const Enemy = preload("res://scripts/survival/enemy.gd")
const Loot = preload("res://scripts/survival/loot.gd")
const Combat = preload("res://scripts/survival/combat.gd")
const Effects = preload("res://scripts/survival/effects.gd")
const UI = preload("res://scripts/survival/ui.gd")
const Navigation = preload("res://scripts/survival/navigation.gd")
const Searchable = preload("res://scripts/survival/searchable.gd")
const District=preload("res://scripts/survival/district.gd")
const MAP_REVISION=2
const RANGED_REVISION=1
var region_states: Dictionary={}
var travel_id: String=""
var travel_clock: float=0.0
var loading_region: bool=false
const EAST_ENEMIES=[
	["resident-infected",Vector3(10.75,.04,-1.5),0.0],
	["aid-infected",Vector3(15.4,.04,-.75),PI],
	["laundry-infected",Vector3(9.0,.04,4.8),PI],
	["utility-infected",Vector3(14.5,.04,5.1),0.0]
]
const EAST_CONTAINERS=[
	["east-pantry","304 食品箱",Vector3(11.05,1.10,-4.5),Vector3(.62,.36,.54),["water","can","bar"]],
	["east-luggage","304 遗留行李箱",Vector3(7.92,.29,-.45),Vector3(.70,.54,.51),["shoes","coat"]],
	["aid-chest","医务室补给箱",Vector3(16.45,1.06,-1.55),Vector3(.67,.40,.56),["water","bar","can"]],
	["laundry-basket","洗衣房衣物篮",Vector3(10.64,.88,4.10),Vector3(.65,.40,.47),["coat","bar"]],
	["utility-box","物业工具箱",Vector3(16.49,1.12,4.85),Vector3(.62,.44,.68),["wrench","bottle"]],
	["utility-reserves","物业应急储备",Vector3(14.10,.39,6.08),Vector3(.94,.77,.67),["water","pack","bat"]]
]
var state: SurvivalState
var player: SurvivalPlayer
var world: SurvivalWorld
var combat: SurvivalCombat
var effects: SurvivalEffects
var ui: SurvivalUI
var navigation:=Navigation.new()
var actors: Node3D
var enemies: Array[SurvivalEnemy]=[]
var loot: Dictionary={}
var sources: Dictionary={}
var search_id: String=""
var search_clock: float=0.0
var active_source_id: String=""
var projectiles: Array[Dictionary]=[]
var menu_camera: Camera3D
var suspended:=true
var time:=0.0
var save_clock:=0.0
var ui_dirty:=false
var resume_view:="game"
var target: Object
var target_hit: Dictionary={}
var using_uid:=""
var use_clock:=0.0
var extracting:=false
var saved_snapshot: Dictionary={}
var save_path:="user://south-block-survival-v3.json"
var settings_path:="user://south-block-settings-v2.json"
var settings:={"fov":74.0,"sensitivity":.085,"brightness":1.05,"volume":.72,"shake":.5,"head_bob":false,"blood":true}
var inspection_mode:=""
var capture_path:=""
var capture_time:=0.0
var inspection_strike:=""
var exiting:=false
const KEY_BINDINGS={"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"interact":KEY_E,"sprint":KEY_SHIFT,"crouch":KEY_CTRL,"flashlight":KEY_F,"quick_use":KEY_Q,"throw":KEY_G,"inventory":KEY_TAB,"pause_game":KEY_ESCAPE,"swap_one":KEY_1,"swap_two":KEY_2,"reload":KEY_R,"shove":KEY_V}

func _ready() -> void:
	get_tree().auto_accept_quit=false
	DisplayServer.window_set_title("南楼求生 · 断水之夜")
	setup_inputs()
	state=State.new()
	connect_state()
	world=World.new();world.game=self;add_child(world)
	player=Player.new();player.survival=state;add_child(player)
	player.position=Vector3(0,.04,2.12)
	player.stepped.connect(footstep)
	effects=Effects.new();add_child(effects)
	actors=Node3D.new();add_child(actors)
	combat=Combat.new();combat.game=self;player.camera.add_child(combat)
	ui=UI.new();add_child(ui);ui.action.connect(on_ui_action)
	menu_camera=Camera3D.new();menu_camera.position=Vector3(.8,1.7,.3);menu_camera.fov=72;add_child(menu_camera);menu_camera.look_at(Vector3(-.6,1.35,-3.4));menu_camera.current=true
	load_settings()
	var load_path:=save_path
	if save_path=="user://south-block-survival-v3.json" and not FileAccess.file_exists(load_path): load_path="user://south-block-survival-v2.json"
	if FileAccess.file_exists(load_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(load_path))
		if valid_snapshot(data) and state.restore(data.profile):
			saved_snapshot=data
			restore_run(data)
	ui.show_menu(not saved_snapshot.is_empty())
	set_controls()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): inspection_mode=arg.trim_prefix("--view=")
		if arg.begins_with("--strike="): inspection_strike=arg.trim_prefix("--strike=")
		if arg.begins_with("--capture="): capture_path=arg.trim_prefix("--capture=")
	if not inspection_mode.is_empty():
		new_profile();depart()
		match inspection_mode:
			"kitchen": player.position=Vector3(.8,.04,.2);player.face(Vector3(-1,1.4,-3.3))
			"combat": player.position=Vector3(4.6,.04,-.9);player.face(Vector3(5.4,1.45,-2.5));enemies[0].position=Vector3(5.3,.04,-2.4);enemies[0].rotation.y=-.35
			"storage": player.position=Vector3(4.12,.04,3.8);player.face(Vector3(6.1,1.3,6.1))
			"corpse":
				player.position=Vector3(4.6,.04,-.3);enemies[0].position=Vector3(5.2,.04,-2.1);enemies[0].rotation.y=PI
				enemies[0].receive_hit(100,Vector3.ZERO,0);enemies[0].animate(3);update_sources()
				player.face(sources["corpse-living-infected"].position)
				active_source_id="corpse-living-infected";sources["corpse-living-infected"].reveal();ui.show_search(sources["corpse-living-infected"],state)
			"search":
				player.position=Vector3(-1.0,.04,-3.15);player.face(sources["kitchen-box"].position)
				active_source_id="kitchen-box";sources["kitchen-box"].reveal();ui.show_search(sources["kitchen-box"],state)
			"bat":
				state.pickup(state.make_item("bat"));state.equip(state.inventory[0].uid);combat.reset()
				player.position=Vector3(4.6,.04,-.9);player.face(Vector3(5.4,1.45,-2.5));enemies[0].position=Vector3(5.3,.04,-2.4);enemies[0].rotation.y=-.35
			"inventory":
				for id in ["can","coat","pack","bat"]: state.pickup(state.make_item(id))
				state.reward("demo-a");state.reward("demo-b");state.reward("demo-c")
				ui.show_inventory(state)
			"base": state.extract();ui.show_inventory(state,true)
			"credits": ui.show_credits()
			"east": player.position=Vector3(7.75,.04,2.06);player.face(Vector3(14.9,1.55,2.10))
			"laundry": player.position=Vector3(11.25,.04,4.80);player.face(Vector3(8.9,1.2,6.3))
			"aid": player.position=Vector3(16.0,.04,-1.8);player.face(Vector3(13.5,1.3,-3.9))
			"district","market","clinic","garage":
				change_region_now("district")
				match inspection_mode:
					"district": player.position=Vector3(-5,.04,-10);player.face(Vector3(0,2.1,7))
					"market": player.position=Vector3(-17,.04,1.1);player.face(Vector3(-20,1.3,-3.2))
					"clinic": player.position=Vector3(14,.04,-5.5);player.face(Vector3(10,1.4,-11.5))
					"garage": player.position=Vector3(18.8,.04,15.9);player.face(Vector3(15,1.4,10.6))
			"crossbow","pistol":
				var weapon:=state.make_item(inspection_mode);weapon.loaded=int(Items.DATA[inspection_mode].magazine)
				state.pickup(weapon);state.equip(weapon.uid);state.pickup(state.make_item(Items.DATA[inspection_mode].ammo));combat.reset()
				change_region_now("district");player.position=Vector3(-5,.04,-10);player.face(Vector3(0,1.55,4))
				combat.ranged.update_pose(1)
			"loading":
				player.position=Vector3(-1.22,.04,-4.02);player.face(sources["kitchen-box"].position)
				ui.search_spinner.begin();ui.search_spinner.value=.56
		if not inspection_strike.is_empty():
			if combat.ranged.equipped():
				if inspection_strike=="reload": state.equipment.primary.loaded=0;combat.ranged.reload();combat._process(.65)
				else: combat.ranged.fire();combat._process(.016)
			else: combat.start_swing(inspection_strike=="heavy");combat._process(float(combat.profile.contact))
		suspended=true;set_controls();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func setup_inputs() -> void:
	for action in KEY_BINDINGS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event:=InputEventKey.new();event.physical_keycode=KEY_BINDINGS[action];InputMap.action_add_event(action,event)
	for binding in [["attack",MOUSE_BUTTON_LEFT],["push",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(binding[0]): InputMap.add_action(binding[0])
		InputMap.action_erase_events(binding[0]);var event:=InputEventMouseButton.new();event.button_index=binding[1];InputMap.action_add_event(binding[0],event)
func connect_state() -> void:
	state.changed.connect(func(): ui_dirty=true)
	state.level_gained.connect(func(level: int):
		if is_instance_valid(ui):
			ui.toast("升到 %d 级 · +1 属性点" % level,6)
			play_sound("level",player.global_position,-6))
func new_profile() -> void:
	region_states.clear()
	if world.region!="apartment": world.build_region("apartment")
	state=State.new();connect_state();player.survival=state
	saved_snapshot.clear()
	reset_actors()
	combat.reset();world.reset();effects.set_outdoors(false)
	show_base()
	save_game()
func show_base() -> void:
	suspended=true
	ui.show_inventory(state,true)
	menu_camera.current=true
	set_controls()
func depart() -> void:
	region_states.clear()
	if world.region!="apartment": world.build_region("apartment")
	state.begin_run()
	world.reset();effects.set_outdoors(false)
	spawn_run()
	player.position=Vector3(0,.04,2.12);player.velocity=Vector3.ZERO;player.impulse=Vector3.ZERO;player.rotation=Vector3.ZERO;player.pitch=0
	player.face(Vector3(.0,1.55,-2))
	combat.reset()
	resume_game()
	save_game()
func reset_actors() -> void:
	combat.ranged.clear_projectiles()
	for node in actors.get_children(): actors.remove_child(node);node.queue_free()
	enemies.clear();loot.clear();sources.clear();projectiles.clear()
	search_id="";search_clock=0;active_source_id=""
	using_uid="";extracting=false;use_clock=0
func spawn_run() -> void:
	reset_actors()
	spawn_containers(true)
	for entry in [["living-infected",Vector3(5.5,.04,-2.4),PI],["hall-infected",Vector3(6.1,.04,2.22),-PI/2],["storage-infected",Vector3(5.55,.04,5.2),PI]]:
		spawn_enemy(entry[0],entry[1],entry[2])
	spawn_east_content()
	add_ranged_supplies()
	refresh_world()
func spawn_containers(fill: bool) -> void:
	for entry in [
		["kitchen-box","厨房补给箱",Vector3(-2.24,1.10,-4.28),Vector3(.50,.32,.58),"",["water","bar"]],
		["cabinet","厨房储物柜",Vector3(-2.49,.45,-1.54),Vector3(.64,.65,.61),"cabinet",["water","can"]],
		["entry-box","玄关工具箱",Vector3(1.85,.20,.43),Vector3(.60,.38,.46),"",["bottle","shoes"]],
		["storage-rack","303 储物架",Vector3(3.12,1.05,5.60),Vector3(.53,1.45,1.1),"",["water","pack","can"]],
		["locker","303 玻璃柜",Vector3(6.18,1.16,6.29),Vector3(.78,.66,.49),"locker",["coat"]]
	]:
		var entries: Array[Dictionary]=[]
		if fill:
			for item_id in entry[5]: entries.append(state.make_item(item_id))
		spawn_source(entry[0],entry[1],entry[2],entries,entry[3],"cabinet",entry[4])
func spawn_east_content() -> void:
	for entry in EAST_CONTAINERS:
		if sources.has(entry[0]): continue
		var items: Array[Dictionary]=[]
		for id in entry[4]: items.append(state.make_item(id))
		spawn_source(entry[0],entry[1],entry[2],items,entry[3])
	for entry in EAST_ENEMIES:
		if enemies.any(func(enemy): return enemy.enemy_id==entry[0]) or state.rewarded.has(entry[0]): continue
		spawn_enemy(entry[0],entry[1],entry[2])
func spawn_source(id: String,caption: String,pos: Vector3,items: Array,box: Vector3=Vector3(.7,.6,.7),kind: String="cabinet",gate: String="",owner: String="") -> SurvivalSearchable:
	var node:=Searchable.new()
	node.source_id=id;node.caption=caption;node.position=pos;node.contents.assign(items.duplicate(true));node.bounds=box;node.kind=kind;node.gate=gate;node.owner_enemy=owner
	node.duration=1.6 if kind=="corpse" else 1.25
	actors.add_child(node);sources[id]=node
	node.set_available(world.is_open(gate))
	if kind=="bag": world.create_loot_bag(node)
	return node
func source_reachable(source: SurvivalSearchable) -> bool:
	if not is_instance_valid(source) or not source.active or state.phase!="run": return false
	if player.camera.global_position.distance_to(source.global_position)>2.9: return false
	var q:=PhysicsRayQueryParameters3D.create(player.camera.global_position,source.global_position,1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func update_sources() -> void:
	for enemy in enemies:
		var id: String="corpse-"+enemy.enemy_id
		if enemy.health<=0 and sources.has(id): sources[id].global_position=enemy.corpse_point()
func start_search(source: SurvivalSearchable) -> void:
	if not source_reachable(source) or combat.busy(): return
	cancel_use()
	if source.searched: open_search_results(source);return
	search_id=source.source_id;search_clock=0
	ui.progress.hide();ui.search_spinner.begin()
	player.operating=true
	play_sound("search",source.global_position,-16)
	emit_noise(source.global_position,1.8)
func update_search(delta: float) -> void:
	if ui.view=="search":
		if not sources.has(active_source_id) or not source_reachable(sources[active_source_id]): close_search_results()
		return
	if search_id.is_empty(): return
	if not sources.has(search_id) or not Input.is_action_pressed("interact"):
		cancel_search();return
	var source: SurvivalSearchable=sources[search_id]
	if not source_reachable(source) or target!=source or combat.busy(): cancel_search();return
	search_clock+=delta;player.operating=true
	ui.search_spinner.value=minf(1,search_clock/source.duration)
	if search_clock>=source.duration:
		source.reveal();cancel_search();open_search_results(source);save_game()
func cancel_search() -> void:
	search_id="";search_clock=0
	if is_instance_valid(player): player.operating=false
	if is_instance_valid(ui): ui.progress.hide();ui.search_spinner.hide()
func open_search_results(source: SurvivalSearchable) -> void:
	if not source.searched or not source_reachable(source): return
	active_source_id=source.source_id
	ui.show_search(source,state);set_controls()
func close_search_results() -> void:
	active_source_id="";cancel_search()
	if ui.view=="search": resume_game()
func take_from_source(uid: String="") -> void:
	if ui.view!="search" or not sources.has(active_source_id): return
	var source: SurvivalSearchable=sources[active_source_id]
	if not source_reachable(source): close_search_results();return
	var count:=0
	for item in source.contents.duplicate(true):
		if not uid.is_empty() and item.uid!=uid: continue
		if source.take(item.uid,state): count+=1
	if count>0: play_sound("pickup",source.global_position,-9);ui.toast("已收取 %d 件物资。" % count,2)
	elif not source.contents.is_empty(): ui.toast("背包已满 · 物资未取出",3)
	ui.refresh_search(source,state);save_game()
func spawn_enemy(id: String,pos: Vector3,yaw: float=0) -> SurvivalEnemy:
	var enemy:=Enemy.new();enemy.game=self;enemy.enemy_id=id;enemy.position=pos;enemy.rotation.y=yaw;actors.add_child(enemy);enemies.append(enemy)
	return enemy
func spawn_loot(id: String,item: Dictionary,pos: Vector3,container: String="") -> SurvivalLoot:
	var node:=Loot.new();node.item=item.duplicate(true);node.loot_id=id;node.container_id=container;node.position=pos;actors.add_child(node);loot[id]=node
	node.set_available(world.is_open(container))
	return node
func spawn_district_content() -> void:
	for entry in District.CONTAINERS:
		var items: Array[Dictionary]=[]
		for item_id in entry[4]: items.append(state.make_item(item_id))
		spawn_source(entry[0],entry[1],entry[2],items,entry[3])
	for entry in District.ENEMIES: spawn_enemy(entry[0],entry[1],entry[2])
	add_ranged_supplies()
func add_ranged_supplies() -> void:
	var additions: Dictionary={"east-luggage":["crossbow","bolts"],"utility-box":["pistol","pistol_ammo"]} if world.region=="apartment" else {"street-market-stock":["bolts"],"street-garage-tools":["pistol","pistol_ammo"],"street-alley-cache":["crossbow","bolts"]}
	for source_id in additions:
		if not sources.has(source_id): continue
		for id in additions[source_id]: sources[source_id].contents.append(state.make_item(id))

func begin_travel(id: String) -> void:
	if loading_region or combat.busy() or not world.targets.has("travel:"+id): return
	for door_data in world.doors.values():
		if door_data.busy: ui.toast("门正在移动。",2);return
	cancel_use();travel_id=id;travel_clock=0

func travel_to(id: String) -> void:
	if loading_region or not World.REGION_ASSETS.has(id) or id==world.region: return
	cancel_use();combat.reset();loading_region=true;suspended=true;set_controls()
	ui.show_transition("正在下楼 · 南街" if id=="district" else "正在上楼 · 南楼三层")
	var path: String=World.REGION_ASSETS[id]
	var result:=ResourceLoader.load_threaded_request(path,"PackedScene")
	if result!=OK:
		loading_region=false;resume_game();ui.toast("区域载入失败，仍留在原位置。",4);return
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:
		loading_region=false;resume_game();ui.toast("区域载入失败，仍留在原位置。",4);return
	# Draw the transition before scene instantiation, which still happens on the main thread.
	await get_tree().process_frame
	var model:=ResourceLoader.load_threaded_get(path) as PackedScene
	change_region_now(id,model)
	await get_tree().physics_frame
	loading_region=false;resume_game();save_game()

func change_region_now(id: String,model: PackedScene=null) -> void:
	if not World.REGION_ASSETS.has(id) or id==world.region: return
	region_states[world.region]=region_snapshot()
	reset_actors();target=null;target_hit={};effects.clear_region()
	world.build_region(id,model)
	if region_states.has(id):
		var cached: Dictionary=region_states[id];region_states.erase(id)
		restore_region(cached)
	elif id=="district": spawn_district_content()
	else: spawn_run()
	player.position=District.ARRIVAL if id=="district" else Vector3(15.9,.04,2.08)
	player.velocity=Vector3.ZERO;player.impulse=Vector3.ZERO;player.kick=0;player.roll=0
	player.face(Vector3(-8,1.55,-6) if id=="district" else Vector3(8,1.55,2.08))
	combat.reset();refresh_world()
	world.environment.adjustment_brightness=clampf(safe_number(settings.get("brightness"),1.05),.8,1.6)
	effects.set_outdoors(world.region=="district")

func refresh_world() -> void:
	for node in loot.values():
		if is_instance_valid(node): node.set_available(world.is_open(node.container_id))
	for source in sources.values(): source.set_available(world.is_open(source.gate))
	navigation.rebuild(world.obstacles())
func resume_game() -> void:
	if state.phase=="safe": show_base();return
	if state.phase=="dead": ui.show_dead(state);suspended=true;set_controls();return
	suspended=false;ui.show_game();player.camera.current=true;set_controls()
func set_controls() -> void:
	if not is_instance_valid(ui): return
	var playable: bool=not suspended and state.phase=="run"
	player.active=playable and ui.view=="game"
	player.set_physics_process(playable)
	effects.set_process(not suspended)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if player.active else Input.MOUSE_MODE_VISIBLE
func pause_game() -> void:
	resume_view=ui.view
	suspended=true;combat.cancel_action();cancel_use();ui.show_menu(true,true);set_controls();save_game()

func _input(event: InputEvent) -> void:
	if loading_region: return
	if not is_instance_valid(ui) or not ui.binding_action.is_empty(): return
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("pause_game"):
		if ui.view=="workshop": on_ui_action("workshop_back",null)
		elif ui.view=="settings": on_ui_action("settings_back",ui.settings_origin)
		elif ui.view=="pause":
			if resume_view=="inventory": suspended=false;ui.show_inventory(state);set_controls()
			elif resume_view=="search" and sources.has(active_source_id): suspended=false;open_search_results(sources[active_source_id])
			else: resume_game()
		elif state.phase=="run": pause_game()
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("inventory") and state.phase=="run" and not suspended:
		if ui.view=="inventory": resume_game()
		else:
			active_source_id="";combat.cancel_action();cancel_use();ui.show_inventory(state);set_controls()
		get_viewport().set_input_as_handled();return
	if ui.view=="search" and event.is_action_pressed("interact"):
		close_search_results();get_viewport().set_input_as_handled();return
	if suspended or state.phase!="run" or ui.view!="game": return
	if event.is_action_pressed("attack"): combat.press()
	if event.is_action_released("attack"): combat.release()
	if event.is_action_pressed("push"):
		if combat.ranged.equipped(): combat.ranged.aiming=true
		else: combat.push()
	if event.is_action_released("push"): combat.ranged.aiming=false
	if event.is_action_pressed("shove"): combat.push()
	if event.is_action_pressed("reload"): combat.ranged.reload()
	if event.is_action_pressed("interact"): interact_target()
	if event.is_action_pressed("flashlight"): combat.flashlight.visible=not combat.flashlight.visible
	if event.is_action_pressed("quick_use"): quick_use()
	if event.is_action_pressed("throw"): throw_bottle()
	if event.is_action_pressed("swap_one") or event.is_action_pressed("swap_two"): swap_weapon()
	if event is InputEventKey and event.pressed and event.keycode==KEY_F12: capture("user://survival-screenshot.png")

func on_ui_action(name: String,value: Variant) -> void:
	if loading_region: return
	match name:
		"new": new_profile()
		"continue": resume_game()
		"depart": depart()
		"workshop":
			if state.phase=="safe": ui.show_workshop(state)
		"workshop_back":
			if state.phase=="safe": show_base()
		"upgrade_melee":
			if state.phase=="safe" and ui.view=="workshop" and state.upgrade_melee(str(value)):
				combat.reset();save_game();play_sound("ratchet",player.position,-12);ui.show_workshop(state)
		"resume": resume_game()
		"menu": suspended=true;ui.show_menu(true);menu_camera.current=true;set_controls();save_game()
		"recover": state.return_to_base();show_base();save_game()
		"quit": request_quit()
		"search_take": take_from_source(str(value))
		"search_all": take_from_source()
		"search_close": close_search_results()
		"credits": ui.show_credits();set_controls()
		"attribute":
			if state.add_attribute(str(value)): ui.toast("已提升"+Items.ATTRIBUTES[value]);save_game()
		"respec": state.reset_attributes();save_game()
		"swap": swap_weapon()
		"unequip": ui.toast(state.unequip(str(value)));combat.update_weapon();save_game()
		"withdraw","deposit":
			if not state.transfer(str(value),name=="withdraw"): ui.toast("背包容量不足。")
			save_game()
		"drop": drop_item(str(value))
		"secondary":
			if not combat.busy(): ui.toast(state.equip(str(value),"secondary"));save_game()
		"use": use_item(str(value))
		"settings":
			var origin: String=ui.view
			suspended=true;ui.show_settings(settings,origin);set_controls()
		"settings_back":
			if str(value)=="pause": ui.show_menu(true,true)
			else: ui.show_menu(not saved_snapshot.is_empty() or state.run_id>0)
			set_controls()
		"setting": apply_setting(str(value.key),value.value)
		"binding":
			var key_event:=InputEventKey.new();key_event.physical_keycode=int(value.key)
			InputMap.action_erase_events(value.action);InputMap.action_add_event(value.action,key_event)
			settings["binding:"+str(value.action)]=int(value.key);save_settings()
	if ui.view in ["inventory","base"]: ui.refresh_inventory()

func _process(delta: float) -> void:
	time+=delta
	if not suspended and state.phase=="run":
		state.tick(delta)
		update_sources()
		update_target()
		update_use(delta)
		update_search(delta)
		update_projectiles(delta)
		combat.ranged.update_projectiles(delta)
		save_clock+=delta
		if save_clock>=3: save_clock=0;save_game()
	ui.update_hud(state,room_name(player.position),world.region=="district")
	if ui_dirty:
		ui_dirty=false
		if ui.view in ["inventory","base"]: ui.refresh_inventory()
		if ui.view=="search" and sources.has(active_source_id): ui.refresh_search(sources[active_source_id],state)
	if not capture_path.is_empty():
		capture_time+=delta
		if capture_time>3:
			var path:=capture_path;capture_path=""
			await capture(path)
			request_quit()

func update_target() -> void:
	var cam:=player.camera
	var query:=PhysicsRayQueryParameters3D.create(cam.global_position,cam.global_position-cam.global_basis.z*2.45,1|2|8)
	query.collide_with_areas=true;query.exclude=[player.get_rid()]
	target_hit=get_world_3d().direct_space_state.intersect_ray(query)
	target=target_hit.get("collider")
	ui.enemy_bar.hide();ui.reticle.modulate=UI.INK
	if not is_instance_valid(target): return
	if target is SurvivalSearchable or target is SurvivalLoot:
		ui.reticle.modulate=UI.AMBER
	elif target is SurvivalEnemy and target.health>0:
		ui.enemy_bar.show();ui.enemy_bar.max_value=95;ui.enemy_bar.value=target.health
	elif target.has_meta("interaction"):
		ui.reticle.modulate=UI.AMBER

func interact_target() -> void:
	combat.ranged.stop_aim()
	if combat.busy(): return
	update_target()
	if not is_instance_valid(target): return
	if target is SurvivalSearchable:
		start_search(target)
	elif target is SurvivalLoot:
		var node: SurvivalLoot=target
		if state.pickup(node.item):
			ui.toast("获得 "+Items.caption(node.item),2)
			play_sound("pickup",node.global_position,-7)
			loot.erase(node.loot_id);node.collision_layer=0;node.hide();node.queue_free();target=null;save_game()
		else: ui.toast("背包已满。",3)
	elif target.has_meta("interaction"):
		var id: String=target.get_meta("interaction")
		if id.begins_with("travel:"): begin_travel(id.trim_prefix("travel:"))
		elif id=="safe":
			cancel_use();extracting=true;use_clock=0;ui.toast("正在撤回…",2)
		else: ui.toast(world.interact(id),3)

func use_item(uid: String) -> void:
	var index:=state.index_of(uid)
	if index<0: return
	var item: Dictionary=state.inventory[index]
	var data:=Items.definition(item.id)
	if data.category=="可食用":
		if state.phase=="safe": state.consume(uid);save_game();return
		if combat.busy(): ui.toast("当前动作未结束。",2);return
		resume_game();cancel_use();using_uid=uid;use_clock=0
		ui.toast("正在食用 "+Items.caption(item),2)
		play_sound("eat",player.global_position,-10)
	elif data.get("ammunition",false):
		if state.phase=="run": resume_game();combat.ranged.reload()
		else: ui.toast("当前不在外出状态。",3)
	elif data.has("slot"):
		if combat.busy(): ui.toast("当前动作未结束。",2);return
		ui.toast(state.equip(uid));combat.update_weapon();save_game()
	elif item.id=="bottle" and state.phase=="run": resume_game();throw_bottle()
func quick_use() -> void:
	var preferred: Array=["water","can","bar"] if state.hydration<55 else (["bar","can","water"] if state.stamina<55 else ["can","bar","water"])
	for id in preferred:
		var index:=state.item_index_by_id(id)
		if index>=0: use_item(state.inventory[index].uid);return
	ui.toast("没有可食用物资。",3)
func update_use(delta: float) -> void:
	if not travel_id.is_empty():
		var portal: Area3D=world.targets.get("travel:"+travel_id)
		if not is_instance_valid(portal) or player.camera.global_position.distance_to(portal.global_position)>2.5:
			cancel_use();return
		player.operating=true;travel_clock+=delta;ui.progress.show();ui.progress.value=travel_clock/1.6
		if travel_clock>=1.6:
			var destination:=travel_id;cancel_use();travel_to(destination)
		return
	if not search_id.is_empty(): return
	if using_uid.is_empty() and not extracting:
		player.operating=false
		ui.progress.visible=combat.phase in ["charge","reload"]
		if combat.phase=="reload": ui.progress.value=minf(1,combat.elapsed/float(state.weapon().reload))
		elif combat.phase=="charge": ui.progress.value=minf(1,combat.elapsed/float(combat.attack_profile(combat.shown_weapon,false).charge))
		return
	player.operating=true
	use_clock+=delta
	ui.progress.show();ui.progress.value=use_clock/(1.15 if extracting else 1.35)
	if extracting:
		if player.position.distance_to(Vector3(-2.83,.04,2.1))>2.4: cancel_use();return
		if use_clock>=1.15:
			cancel_use()
			if state.extract(): show_base();save_game()
	elif use_clock>=1.35:
		var uid:=using_uid;cancel_use()
		if state.consume(uid): ui.toast("补给已使用。状态已更新。",2);save_game()
func cancel_use() -> void:
	travel_id="";travel_clock=0
	cancel_search()
	using_uid="";use_clock=0;extracting=false
	if is_instance_valid(player): player.operating=false
	if is_instance_valid(ui): ui.progress.hide();ui.search_spinner.hide()
func swap_weapon() -> void:
	if combat.busy(): return
	if state.swap_weapons():
		combat.update_weapon();combat.cooldown=.35/(1+state.attributes.agility*.05);ui.toast("切换为 "+Items.caption(state.equipment.primary),2);save_game()
	else: ui.toast("未装备备用武器。",2)
func drop_item(uid: String) -> void:
	if state.phase!="run": return
	# Place on the nearest supporting surface, never beyond a wall or inside a cabinet.
	var from: Vector3=player.global_position+Vector3.UP*.65
	var query:=PhysicsRayQueryParameters3D.create(from,from-player.global_basis.z*.55,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	var place: Vector3=hit.position+hit.normal*.18 if not hit.is_empty() else query.to
	query=PhysicsRayQueryParameters3D.create(place,place-Vector3.UP*1.0,1)
	hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): ui.toast("当前位置无法放置物品。",2);return
	var item:=state.drop(uid)
	if item.is_empty(): return
	spawn_source("dropped-"+item.uid,"遗留物资包",hit.position+Vector3.UP*.15,[item],Vector3(.4,.3,.35),"bag")
	save_game()

func throw_bottle() -> void:
	if combat.busy() or state.phase!="run": return
	if state.item_index_by_id("bottle")<0: ui.toast("背包里没有空瓶。",2);return
	cancel_use();combat.throw_gesture()
func launch_bottle() -> void:
	# Consume at release, so interrupting the windup cannot destroy the reserved item.
	if state.phase!="run" or not state.throw_bottle(): return
	var node:=Node3D.new();actors.add_child(node);Loot.build_visual(node,"bottle")
	var from: Vector3=player.camera.global_position
	var release_point: Vector3=from-player.camera.global_basis.z*.35
	var q:=PhysicsRayQueryParameters3D.create(from,release_point,1)
	var obstruction:=get_world_3d().direct_space_state.intersect_ray(q)
	node.position=obstruction.position+obstruction.normal*.05 if not obstruction.is_empty() else release_point
	projectiles.append({"node":node,"velocity":-player.camera.global_basis.z*9+Vector3.UP*1.4,"life":3.0})
	save_game()
func update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary=projectiles[i]
		p.velocity.y-=9.8*delta
		var from: Vector3=p.node.global_position
		var to: Vector3=from+p.velocity*delta
		var query:=PhysicsRayQueryParameters3D.create(from,to,1|8);query.exclude=[player.get_rid()]
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		p.life-=delta
		if not hit.is_empty() or p.life<=0:
			var at: Vector3=hit.get("position",to)
			effects.burst(at,hit.get("normal",Vector3.UP),"glass",true);play_sound("hit_glass",at,-6);emit_noise(at,12)
			p.node.queue_free();projectiles.remove_at(i)
		else: p.node.position=to;p.node.rotation.x+=delta*9
func footstep() -> void:
	if suspended or state.phase!="run": return
	play_sound("step",player.global_position,-22 if player.crouched else -15)
	var loudness:=1.6 if player.crouched else (6.0 if player.sprinting else 3.2)
	if not state.equipment.feet.is_empty(): loudness*=.8
	emit_noise(player.global_position,loudness)
func emit_noise(at: Vector3,radius: float) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.hear(at,radius)
func play_sound(name: String,at: Vector3,db: float=-10) -> void:
	if is_instance_valid(effects): effects.sound(name,at,db)
func player_hit(damage: float,from: Vector3) -> void:
	if state.phase!="run": return
	if state.hurt(damage)<=0: return
	cancel_use();close_search_results();combat.cancel_action()
	player.recoil(-4.0)
	player.impulse=(player.position-from).normalized()*1.5
	ui.damaged();play_sound("hurt",player.global_position,-7)
	if state.hp<=0:
		state.fail_run();suspended=true;ui.show_dead(state);set_controls()
	save_game()
func enemy_killed(enemy: SurvivalEnemy) -> void:
	if state.reward(enemy.enemy_id)<=0: return
	play_sound("snarl",enemy.position,-11)
	var found: Array[Dictionary]=[]
	if enemy.enemy_id=="living-infected": found.append(state.make_item("bat"))
	elif enemy.enemy_id in ["hall-infected","resident-infected","aid-infected"]: found.append(state.make_item("bar"))
	elif enemy.enemy_id=="utility-infected": found.append(state.make_item("water"))
	else: found.append(state.make_item("bottle"))
	if enemy.embedded_bolts>0:
		var recovered:=state.make_item("bolts");recovered.quantity=mini(24,enemy.embedded_bolts);found.append(recovered)
	spawn_source("corpse-"+enemy.enemy_id,"感染者尸体",enemy.corpse_point(),found,Vector3(.90,.5,.95),"corpse","",enemy.enemy_id)
	if state.points<=0: ui.toast("+40 经验",3)
	save_game()
func room_name(pos: Vector3) -> String:
	if world.region=="district": return District.room_name(pos)
	if pos.x>7.16:
		if pos.z>3.1: return "物业库房" if pos.x>12.08 else "公共洗衣房"
		if pos.z>1: return "东翼走廊"
		return "305 临时医务室" if pos.x>12.08 else "304 住户"
	if pos.z>3.1: return "303 储物间"
	if pos.z>1: return "公共走廊"
	return "302 客厅" if pos.x>3 else "302 厨房"

func age_materials(root: Node) -> void:
	for node in root.find_children("*","MeshInstance3D",true,false):
		for index in range(node.mesh.get_surface_count()):
			var original: Material=node.mesh.surface_get_material(index)
			if not original is StandardMaterial3D: continue
			var name0: String=original.resource_name
			if name0=="stone_floor":
				var mat: StandardMaterial3D=original.duplicate();mat.albedo_color=Color(.72,.75,.72);mat.roughness=.8;node.set_surface_override_material(index,mat)
			elif name0 in ["aged_plaster","cabinet_paint","old_wood","infected_coat","infected_trousers","infected_skin","bat_wood"] or (name0.begins_with("district_") and name0 not in ["district_glass","district_water","district_lamp"]):
				var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/aged_surface.gdshader")
				mat.set_shader_parameter("tint",Color(.64,.65,.59) if name0=="aged_plaster" else original.albedo_color)
				if name0=="district_plaster": mat.set_shader_parameter("tint",Color(.48,.51,.47))
				if name0=="district_concrete": mat.set_shader_parameter("tint",Color(.25,.28,.27))
				if name0=="district_tile": mat.set_shader_parameter("tint",Color(.37,.40,.37))
				mat.set_shader_parameter("wear",.50 if "infected" in name0 else .38)
				mat.set_shader_parameter("roughness_base",.70 if name0=="district_asphalt" else .91)
				mat.set_shader_parameter("metallic_base",original.metallic)
				if original.albedo_texture:
					mat.set_shader_parameter("textured",true);mat.set_shader_parameter("color_map",original.albedo_texture);mat.set_shader_parameter("normal_map",original.normal_texture);mat.set_shader_parameter("rough_map",original.roughness_texture)
				node.set_surface_override_material(index,mat)
func safe_number(value: Variant,fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
func read_vector(value: Variant,fallback: Vector3) -> Vector3:
	if not value is Array or value.size()!=3: return fallback
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)): return fallback
	var bounds: Rect2=world.map_bounds.grow(-.25)
	return Vector3(clampf(float(value[0]),bounds.position.x,bounds.end.x),clampf(float(value[1]),-.05,2),clampf(float(value[2]),bounds.position.y,bounds.end.y))
func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or not value.get("profile") is Dictionary or not value.get("world") is Dictionary or not value.get("enemies") is Array: return false
	return (value.get("schema")==3 and value.get("sources") is Array) or (value.get("schema")==2 and value.get("loot") is Array)
func region_snapshot() -> Dictionary:
	var foes: Array=[]
	for enemy in enemies:
		if is_instance_valid(enemy): foes.append(enemy.serialize())
	var containers: Array=[]
	for source in sources.values(): containers.append(source.serialize())
	return {"schema":3,"map_revision":MAP_REVISION,"world":world.serialize(),"sources":containers,"enemies":foes,"ranged_revision":RANGED_REVISION,"bolts":combat.ranged.serialize_bolts()}
func snapshot() -> Dictionary:
	var data:=region_snapshot()
	data.merge({"profile":state.serialize(),"region":world.region,"regions":region_states.duplicate(true),"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"pitch":player.pitch})
	return data
func restore_run(data: Dictionary) -> void:
	reset_actors();region_states.clear()
	var region: String=str(data.get("region","apartment"))
	if not World.REGION_ASSETS.has(region): region="apartment"
	if data.get("regions") is Dictionary:
		for id in data.regions:
			var entry: Variant=data.regions[id]
			if id!=region and World.REGION_ASSETS.has(id) and entry is Dictionary and entry.get("world") is Dictionary and entry.get("sources") is Array and entry.get("enemies") is Array:
				region_states[id]=entry.duplicate(true)
	if world.region!=region: world.build_region(region)
	restore_region(data)
	player.position=read_vector(data.get("position"),District.ARRIVAL if region=="district" else Vector3(-1.3,.04,2.1));player.rotation.y=safe_number(data.get("yaw"),0);player.pitch=clampf(safe_number(data.get("pitch"),0),-78,78);player.camera.rotation_degrees.x=player.pitch
	player.survival=state;combat.reset();refresh_world()
	world.environment.adjustment_brightness=clampf(safe_number(settings.get("brightness"),1.05),.8,1.6)
	effects.set_outdoors(world.region=="district")
func restore_region(data: Dictionary) -> void:
	world.reset(data.world)
	for entry in data.enemies:
		if not entry is Dictionary or not entry.get("id") is String: continue
		var enemy:=spawn_enemy(entry.id,read_vector(entry.get("position"),Vector3(5,.04,-2)))
		enemy.restore(entry)
		if state.rewarded.has(enemy.enemy_id): enemy.health=0;enemy.behavior="dead";enemy.collision_layer=0
	if data.get("schema",3)==2: migrate_loot(data.loot)
	else:
		var seen: Dictionary={}
		for entry in data.sources:
			if not entry is Dictionary or not entry.get("id") is String or not entry.get("contents") is Array or sources.has(entry.id): continue
			var contents: Array[Dictionary]=[]
			for item in entry.contents:
				if not Items.valid_item(item) or seen.has(item.uid) or state.owns_uid(item.uid) or state.consumed.has(item.uid): continue
				seen[item.uid]=true;contents.append(item)
			var box:=Vector3(.7,.6,.7)
			if entry.get("bounds") is Array and entry.bounds.size()==3:
				box=Vector3(clampf(safe_number(entry.bounds[0],.7),.1,2),clampf(safe_number(entry.bounds[1],.6),.1,2),clampf(safe_number(entry.bounds[2],.7),.1,2))
			var source:=spawn_source(entry.id,str(entry.get("caption","储物处")),read_vector(entry.get("position"),Vector3.ZERO),contents,box,str(entry.get("kind","cabinet")),str(entry.get("gate","")),str(entry.get("owner","")))
			source.searched=entry.get("searched",false)==true
	if world.region=="apartment" and int(safe_number(data.get("map_revision"),1))<MAP_REVISION and state.phase=="run": spawn_east_content()
	if int(safe_number(data.get("ranged_revision"),0))<RANGED_REVISION and state.phase=="run": add_ranged_supplies()
	combat.ranged.restore_bolts(data.get("bolts",[]))
func migrate_loot(old_loot: Array) -> void:
	# Version 2 -> 3: preserve every remaining instance; never recreate an already claimed drop.
	spawn_containers(false)
	for enemy in enemies:
		if enemy.health<=0: spawn_source("corpse-"+enemy.enemy_id,"感染者尸体",enemy.corpse_point(),[],Vector3(.90,.5,.95),"corpse","",enemy.enemy_id)
	var mapping: Dictionary={"water-kitchen":"kitchen-box","energy-counter":"kitchen-box","water-cabinet":"cabinet","food-cabinet":"cabinet","bottle-kitchen":"entry-box","shoes-entry":"entry-box","water-storage":"storage-rack","pack-storage":"storage-rack","food-storage":"storage-rack","coat-locker":"locker"}
	var seen: Dictionary={}
	for entry in old_loot:
		if not entry is Dictionary or not Items.valid_item(entry.get("item")): continue
		var item: Dictionary=entry.item
		if seen.has(item.uid) or state.owns_uid(item.uid) or state.consumed.has(item.uid): continue
		seen[item.uid]=true
		var id: String=str(entry.get("id",item.uid))
		var destination: String=mapping.get(id,"")
		if id.begins_with("drop-"): destination="corpse-"+id.trim_prefix("drop-")
		if not sources.has(destination):
			destination="legacy-"+id
			spawn_source(destination,"遗留物资包",read_vector(entry.get("position"),Vector3.ZERO)+Vector3.UP*.15,[],Vector3(.4,.3,.35),"bag")
		sources[destination].contents.append(item.duplicate(true))
func save_game() -> void:
	if not inspection_mode.is_empty() or not is_instance_valid(world) or not is_instance_valid(player): return
	var data:=snapshot()
	var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data));file.close();DirAccess.rename_absolute(save_path+".tmp",save_path)
		saved_snapshot=data
func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if data is Dictionary:
			for key in data:
				if (settings.has(key) or str(key).begins_with("binding:")) and (data[key] is bool or data[key] is int or data[key] is float): settings[key]=data[key]
	for key in settings.keys(): apply_setting(key,settings[key],false)
func apply_setting(key: String,value: Variant,persist: bool=true) -> void:
	settings[key]=value
	match key:
		"fov": player.camera.fov=clampf(safe_number(value,74),60,95)
		"sensitivity": player.sensitivity=clampf(safe_number(value,.085),.025,.2)
		"brightness": world.environment.adjustment_brightness=clampf(safe_number(value,1.05),.8,1.6)
		"volume": AudioServer.set_bus_volume_db(0,linear_to_db(clampf(safe_number(value,.72),0,1)))
		"shake": player.shake_strength=clampf(safe_number(value,.5),0,1)
		"head_bob": player.head_bob=bool(value)
		"blood": effects.blood=bool(value)
	if key.begins_with("binding:"):
		var name0:=key.trim_prefix("binding:")
		if KEY_BINDINGS.has(name0) and int(value)>0:
			var event:=InputEventKey.new();event.physical_keycode=int(value);InputMap.action_erase_events(name0);InputMap.action_add_event(name0,event)
	if persist: save_settings()
func save_settings() -> void:
	var file:=FileAccess.open(settings_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(settings))
func request_quit() -> void:
	if exiting: return
	exiting=true;save_game();suspended=true;effects.stop_audio();set_process(false)
	await get_tree().create_timer(.12).timeout
	get_tree().quit()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui): request_quit()
func _exit_tree() -> void:
	if is_instance_valid(effects): effects.stop_audio()
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error:=get_viewport().get_texture().get_image().save_png(path)
	print("SURVIVAL_CAPTURE ",path," error=",error," fps=",Engine.get_frames_per_second())
