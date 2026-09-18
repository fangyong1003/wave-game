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
func freeze() -> void:
	for enemy in game.enemies: enemy.set_physics_process(false);enemy.collision_layer=0
	game.player.active=false
func aim(at: Vector3) -> void:
	game.player.active=false;game.player.velocity=Vector3.ZERO;game.player.impulse=Vector3.ZERO;game.player.kick=0;game.player.roll=0
	game.player.face(at);await frames();game.update_target()
func walk(to: Vector3) -> void:
	game.player.active=true;Input.action_press("move_forward")
	for i in range(1800):
		game.player.face(Vector3(to.x,game.player.camera.global_position.y,to.z))
		await physics_frame
		if Vector2(game.player.position.x-to.x,game.player.position.z-to.z).length()<.15: break
	Input.action_release("move_forward");game.player.active=false
	check(Vector2(game.player.position.x-to.x,game.player.position.z-to.z).length()<.24,"Walkable district route: "+str(to)+" reached "+str(game.player.position))
	check(game.player.position.y>-.1,"Street route has supporting collision")
func search(id: String,take: bool=false) -> void:
	var source: SurvivalSearchable=game.sources[id]
	await aim(source.position)
	check(game.target==source and game.source_reachable(source),"Actual selection ray reaches "+id)
	Input.action_press("interact");game.interact_target();game.update_search(1.65);Input.action_release("interact")
	check(source.searched and game.ui.view=="search","Production hold-to-search reveals "+id)
	if take:
		var uid: String=source.contents[0].uid
		game.take_from_source(uid)
		check(game.state.owns_uid(uid) and not source.contents.any(func(item): return item.uid==uid),"Transfer exactly once from "+id)
	game.close_search_results()
func portal(id: String) -> void:
	await aim(game.world.targets["travel:"+id].position)
	check(is_instance_valid(game.target) and game.target.get_meta("interaction","")=="travel:"+id,"Real ray selects region entry")
	game.interact_target();game.update_use(.5)
	check(game.travel_id==id and not game.loading_region,"Stair entry has interruptible approach time")
	game.update_use(1.2)
	check(game.loading_region and game.suspended and not game.player.active,"Region load suspends simulation and controls")
	var deadline:=Time.get_ticks_msec()+20000
	while game.loading_region and Time.get_ticks_msec()<deadline: await process_frame
	check(game.world.region==id and not game.loading_region and not game.suspended,"Threaded resource load completes into "+id)
	freeze();await frames()
func run() -> void:
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://district-test.json";game.settings_path="user://district-test-settings.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.set_process(false);game.combat.set_process(false);await frames()
	game.new_profile();game.depart();freeze();await frames()
	var old: Dictionary=game.snapshot();old.erase("regions");old.erase("region")
	game.state.restore(old.profile);game.restore_run(old);game.resume_game();freeze()
	check(game.world.region=="apartment" and game.sources.size()==11,"Old save without region metadata remains in the original apartment")
	game.world.reset({"unit304":{"open":true}});game.refresh_world()
	game.sources["kitchen-box"].reveal();game.sources["kitchen-box"].contents.clear()
	game.enemies[0].receive_hit(100,Vector3.ZERO,0)
	var apartment_xp: int=game.state.xp
	await walk(Vector3(15.7,0,2.08))
	await aim(game.world.targets["travel:district"].position);game.interact_target();game.update_use(.6)
	game.player_hit(1,game.player.position+Vector3.RIGHT)
	check(game.travel_id.is_empty() and game.world.region=="apartment","Damage interrupts stair entry before loading")
	await portal("district")
	check(game.enemies.size()==8 and game.sources.size()==8 and game.loot.is_empty(),"Street contains eight enemies and eight finite search sources, with no floor drops")
	check(game.world.map_bounds.size==Vector2(52,44) and game.navigation.bounds==game.world.map_bounds,"Collision, save bounds and navigation use the street's own bounds")
	check(game.world.doors.is_empty() and not game.world.targets.has("safe"),"Apartment doors and extraction target are unloaded")
	check(game.region_states.has("apartment") and not game.region_states.has("district"),"Only inactive region retains serialized data")
	check(game.player.position.distance_to(game.District.ARRIVAL)<.12,"Street entry is on the paved courtyard")
	await walk(Vector3(-18,0,-10.4));await search("street-courtyard-box",true)
	await walk(Vector3(-12,0,-10));await walk(Vector3(-12,0,-5.5));await walk(Vector3(-11.6,0,-5.5));await search("street-market-stock",true)
	await walk(Vector3(-12,0,2));await walk(Vector3(-18,0,2));await walk(Vector3(-20.4,0,-3));await search("street-market-shelf")
	check(game.room_name(game.player.position)=="南街便利店","Grocery HUD location")
	await walk(Vector3(-18,0,-1));await walk(Vector3(-17,0,1));await walk(Vector3(-17,0,4.5));await walk(Vector3(0,0,4.5))
	await walk(Vector3(13,0,0));await walk(Vector3(13,0,-5.4));await walk(Vector3(9,0,-5.4));await search("street-clinic-bag")
	await walk(Vector3(15,0,-5.5));await walk(Vector3(17.9,0,-10.9));await search("street-clinic-kit")
	check(game.room_name(game.player.position)=="临时诊所","Clinic HUD location")
	await walk(Vector3(17,0,-12.8));await walk(Vector3(17,0,-16));await walk(Vector3(23,0,-16));await walk(Vector3(24,0,-2));await walk(Vector3(24,0,19))
	await walk(Vector3(19,0,19));await walk(Vector3(19,0,15));await walk(Vector3(20,0,13));await search("street-garage-tools")
	await walk(Vector3(19,0,15));await walk(Vector3(12.7,0,15.7));await search("street-garage-locker")
	check(game.room_name(game.player.position)=="南街修车库","Garage HUD location")
	await walk(Vector3(19,0,15.5));await walk(Vector3(19,0,18.6));await walk(Vector3(13,0,18.6));await walk(Vector3(0,0,18.6));await walk(Vector3(-4,0,19));await search("street-alley-cache")
	check(game.sources.values().all(func(source): return source.searched),"Every new source is reachable and searchable through real geometry")
	# A killed outdoor enemy produces one searchable corpse; its XP and finite contents survive unloading.
	var enemy=game.enemies.filter(func(e): return e.enemy_id=="street-alley")[0]
	enemy.receive_hit(100,Vector3.ZERO,0);enemy.animate(3);game.update_sources()
	check(game.state.xp==apartment_xp+40 and game.sources.has("corpse-street-alley"),"Street death rewards once and exposes a corpse")
	var corpse_items: Array=game.sources["corpse-street-alley"].contents.duplicate(true)
	var street_inventory: Array=game.state.inventory.duplicate(true)
	var street_sources: int=game.sources.size()
	var checkpoint: Dictionary=game.snapshot();game.save_game()
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(disk.region=="district" and disk.regions.has("apartment"),"Disk save stores both active and unloaded regions")
	game.state.restore(disk.profile);game.restore_run(disk);game.resume_game();freeze();await frames()
	check(game.player.position.z>18 and game.player.position.x<0,"Outdoor position survives save loading without indoor clamping")
	check(game.state.inventory==street_inventory and game.sources.size()==street_sources,"Reload neither loses inventory nor duplicates sources")
	# Walk around the closed building and go back through the same physical stair portal.
	await walk(Vector3(-7.8,0,19));await walk(Vector3(-7.8,0,5));await walk(Vector3(-7.8,0,-10));await walk(Vector3(-12,0,-13.5))
	await portal("apartment")
	check(game.enemies.size()==7 and game.sources.size()==12,"Only apartment actors return, including its original corpse")
	check(game.sources["kitchen-box"].searched and game.sources["kitchen-box"].contents.is_empty(),"Looted apartment cache stays empty across street travel")
	check(game.world.doors.unit304.open and game.enemies[0].health==0,"Apartment door and enemy death survive unloading")
	await portal("district")
	check(game.sources["street-market-stock"].searched and game.sources["street-market-stock"].contents.size()==3,"Partially looted outdoor source retains remaining items")
	check(game.sources["corpse-street-alley"].contents==corpse_items and game.state.inventory==street_inventory,"Corpse and carried item identities survive a second visit")
	check(game.state.xp==apartment_xp+40 and game.enemies.filter(func(e): return e.enemy_id=="street-alley")[0].health==0,"A revisited corpse cannot grant duplicate XP")
	# Nearby outdoor AI must follow a real route and damage the player; distant actors stay dormant.
	game.player.position=Vector3(0,.04,5);game.player.active=false
	var hunter=game.enemies.filter(func(e): return e.enemy_id=="street-crossing")[0]
	hunter.position=Vector3(0,.04,2);hunter.home=hunter.position;hunter.target_point=game.player.position;hunter.rotation.y=0;hunter.sense_clock=0;hunter.collision_layer=8;hunter.set_physics_process(true)
	var hp: float=game.state.hp
	for i in range(300):
		await physics_frame
		if game.state.hp<hp: break
	hunter.set_physics_process(false)
	check(game.state.hp<hp,"Outdoor enemy acquires, approaches and attacks through the production AI")
	var distant=game.enemies.filter(func(e): return e.enemy_id=="street-market-rear")[0]
	game.player.position=Vector3(23,.04,19);var old_age: float=distant.age
	distant._physics_process(.25)
	check(distant.age==old_age,"Distant outdoor actors suspend simulation")
	game.player.position=game.District.ARRIVAL;await frames();await portal("apartment")
	await walk(Vector3(0,0,2.05));await walk(Vector3(-1.35,0,1.76));await aim(game.world.targets.safe.position)
	game.interact_target();game.update_use(1.2)
	check(game.state.phase=="safe" and game.state.mission_done,"Two waters from the street reach the original safehouse and complete the objective")
	check(game.state.stash.size()==street_inventory.size(),"Extraction deposits outdoor inventory without duplication")
	game.depart();freeze();await frames()
	check(game.world.region=="apartment" and game.region_states.is_empty(),"A new expedition starts a fresh district ledger as designed")
	game.effects.stop_audio();await frames(12);game.queue_free();await frames()
	DirAccess.remove_absolute("user://district-test.json");DirAccess.remove_absolute("user://district-test-settings.json")
	print("DISTRICT_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
