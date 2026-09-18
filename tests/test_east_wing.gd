extends SceneTree
var game: Node3D
var assertions:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: ",message)
func frames(count: int=3) -> void:
	for i in range(count): await physics_frame
func freeze_enemies() -> void:
	for enemy in game.enemies: enemy.set_physics_process(false);enemy.collision_layer=0
func aim(at: Vector3) -> void:
	game.player.active=false;game.player.velocity=Vector3.ZERO;game.player.impulse=Vector3.ZERO;game.player.kick=0;game.player.roll=0
	game.player.face(at);await frames();game.update_target()
func walk(to: Vector3) -> void:
	game.player.active=true;Input.action_press("move_forward")
	for i in range(700):
		game.player.face(Vector3(to.x,game.player.camera.global_position.y,to.z))
		await physics_frame
		if Vector2(game.player.position.x-to.x,game.player.position.z-to.z).length()<.14: break
	Input.action_release("move_forward");game.player.active=false
	check(Vector2(game.player.position.x-to.x,game.player.position.z-to.z).length()<.23,"Walk through real collision to "+str(to)+"; reached "+str(game.player.position))
	check(game.player.position.y>-.1,"The route has continuous supporting floor")
func door(id: String) -> void:
	await aim(game.world.targets[id].global_position)
	check(is_instance_valid(game.target) and game.target.get_meta("interaction","")==id,"Ray selects "+id)
	game.interact_target();await frames(30)
	check(game.world.doors[id].open,"Door opens: "+id)
func collect(id: String) -> void:
	var source: SurvivalSearchable=game.sources[id]
	await aim(source.position)
	check(game.target==source and game.source_reachable(source),"Reach and select east source "+id)
	Input.action_press("interact");game.interact_target();game.update_search(.6)
	check(game.ui.search_spinner.visible and not game.ui.progress.visible,"Search uses the ring instead of the horizontal bar")
	var before: float=game.ui.search_spinner.angle;game.ui.search_spinner._process(.12)
	check(not is_equal_approx(before,game.ui.search_spinner.angle) and game.ui.search_spinner.value>.4,"Ring rotates and reports elapsed completion")
	game.update_search(1);Input.action_release("interact")
	check(game.ui.view=="search" and source.searched and not game.ui.search_spinner.visible,"Completion hides the ring and opens results")
	var item: Dictionary=source.contents[0].duplicate(true)
	game.take_from_source(item.uid)
	check(game.state.owns_uid(item.uid),"East source transfers its item: "+id)
	game.close_search_results()
func run() -> void:
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://east-wing-test.json";game.settings_path="user://east-wing-settings.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.set_process(false);game.combat.set_process(false);await frames()
	game.new_profile();game.depart();freeze_enemies();await frames()
	check(game.sources.size()==11 and game.enemies.size()==7,"Expanded encounter has 11 initial sources and 7 enemies")
	check(game.world.map_bounds.end.x>17 and game.navigation.bounds.end.x>17,"Collision and navigation include the east wing")
	check(game.navigation.has_floor(Vector2(7.12,2.05)) and game.navigation.has_floor(Vector2(7.16,5.55)),"Both connecting floor seams support a full character footprint")
	check(not game.navigation.has_floor(Vector2(0,5)) and not game.navigation.has_floor(Vector2(18,2)),"Navigation excludes the original floor cutout and outside perimeter")
	var locked_path: PackedVector3Array=game.navigation.path(Vector3(15.5,0,2),Vector3(14.5,0,5))
	check(locked_path.is_empty(),"Closed utility door blocks the room's only entry")
	var long_path: PackedVector3Array=game.navigation.path(Vector3(9.7,0,2),Vector3(9.7,0,0))
	check(long_path.size()>30,"304 can be reached via the medical-room bypass while its front door is closed")
	await walk(Vector3(6.8,0,2.05));await walk(Vector3(9.7,0,2.05));await door("unit304")
	var short_path: PackedVector3Array=game.navigation.path(Vector3(9.7,0,2),Vector3(9.7,0,0))
	check(short_path.size()>0 and short_path.size()<long_path.size(),"Opening 304 creates the short route in navigation")
	await walk(Vector3(9.7,0,-.85));await walk(Vector3(11.05,0,-2.0));await walk(Vector3(11.05,0,-3.35));await collect("east-pantry")
	check(game.room_name(game.player.position)=="304 住户","HUD labels the resident room")
	await walk(Vector3(9.1,0,-1.2));await collect("east-luggage")
	await walk(Vector3(11.0,0,-2.0));await walk(Vector3(13.05,0,-2.0));await walk(Vector3(15.30,0,-1.55));await collect("aid-chest")
	check(game.room_name(game.player.position)=="305 临时医务室","HUD labels the medical room")
	await walk(Vector3(15.5,0,2.05));await door("utility");await walk(Vector3(15.5,0,4.8));await collect("utility-box")
	await walk(Vector3(14.1,0,5.1));await collect("utility-reserves")
	check(game.room_name(game.player.position)=="物业库房","HUD labels the property store")
	# Save inside the enlarged bounds: neither the player nor supplies may clamp to the old edge.
	var checkpoint: Dictionary=game.snapshot();var inventory_count: int=game.state.inventory.size()
	game.state.restore(checkpoint.profile);game.restore_run(checkpoint);freeze_enemies();game.resume_game();await frames()
	check(game.player.position.x>14 and game.player.position.z>5,"Save/restore preserves the real east-wing position")
	check(game.sources["utility-reserves"].searched and game.sources["utility-reserves"].contents.size()==2,"East container keeps its partial inventory on reload")
	check(game.world.doors.unit304.open and game.world.doors.utility.open,"Reload preserves both new doors")
	check(game.state.inventory.size()==inventory_count and game.enemies.size()==7,"Reload duplicates neither actors nor acquired items")
	await walk(Vector3(15.5,0,4.3));await walk(Vector3(15.5,0,2.05));await walk(Vector3(9.7,0,2.05));await walk(Vector3(9.7,0,4.95));await walk(Vector3(10.64,0,4.95));await collect("laundry-basket")
	check(game.room_name(game.player.position)=="公共洗衣房","HUD labels the laundry")
	await walk(Vector3(9.2,0,5.45));await walk(Vector3(7.3,0,5.55));await walk(Vector3(6.1,0,5.55));await walk(Vector3(4.17,0,3.7));await walk(Vector3(4.17,0,2.05))
	check(game.room_name(Vector3(6.1,0,5.55))=="303 储物间","Laundry bypass rejoins the original 303")
	await walk(Vector3(0,0,2.05));await walk(Vector3(-1.35,0,1.76))
	await aim(game.world.targets.safe.position);game.interact_target();game.update_use(1.16)
	check(game.state.phase=="safe" and game.state.mission_done,"Supplies from the enlarged route can be brought back to the original safehouse")
	# A new enemy must really traverse the service opening and attack in the original wing.
	game.depart();freeze_enemies();await frames()
	game.player.position=Vector3(5.7,.04,5.4);game.player.active=false
	var enemy=game.enemies.filter(func(e): return e.enemy_id=="laundry-infected")[0]
	enemy.position=Vector3(8.3,.04,5.4);enemy.home=enemy.position;enemy.target_point=enemy.position;enemy.sense_clock=0
	enemy.rotation.y=-PI/2;enemy.collision_layer=8;enemy.set_physics_process(true)
	var hp: float=game.state.hp
	for i in range(420):
		await physics_frame
		if game.state.hp<hp: break
	enemy.set_physics_process(false)
	check(enemy.position.x<7.16 and game.state.hp<hp,"East enemy crosses into 303 and attacks; position="+str(enemy.position)+" hp="+str(game.state.hp)+" behavior="+enemy.behavior)
	# Retrofit old map saves once, retaining all west-wing collection and kill records.
	game.new_profile();game.depart();freeze_enemies();await frames()
	game.sources["kitchen-box"].reveal();game.sources["kitchen-box"].contents.clear()
	game.enemies[0].receive_hit(100,Vector3.ZERO,0)
	var old: Dictionary=game.snapshot();old.erase("map_revision")
	old.enemies=old.enemies.filter(func(e): return e.id in ["living-infected","hall-infected","storage-infected"])
	old.sources=old.sources.filter(func(s): return not s.id in ["east-pantry","east-luggage","aid-chest","laundry-basket","utility-box","utility-reserves"])
	game.state.restore(old.profile);game.restore_run(old);freeze_enemies();await frames()
	check(game.enemies.size()==7 and game.sources.size()==12,"Old live save gains the east wing once, including its original corpse")
	check(game.sources["kitchen-box"].contents.is_empty() and game.state.xp==40 and game.enemies[0].health==0,"Map upgrade preserves old empty containers, XP and deaths")
	var once: Dictionary=game.snapshot()
	check(once.map_revision==2,"Upgraded save records the map revision")
	var east_uids: Array=[]
	for entry in game.EAST_CONTAINERS:
		for item in game.sources[entry[0]].contents: east_uids.append(item.uid)
	game.state.restore(once.profile);game.restore_run(once);freeze_enemies();await frames()
	var after_uids: Array=[]
	for entry in game.EAST_CONTAINERS:
		for item in game.sources[entry[0]].contents: after_uids.append(item.uid)
	check(east_uids==after_uids and game.enemies.size()==7,"A second load does not respawn or reroll east-wing contents")
	game.effects.stop_audio();await frames(15);game.queue_free();await frames()
	DirAccess.remove_absolute("user://east-wing-test.json");DirAccess.remove_absolute("user://east-wing-settings.json")
	print("EAST_WING_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
