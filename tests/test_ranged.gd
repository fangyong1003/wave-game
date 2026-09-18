extends SceneTree
const State=preload("res://scripts/survival/state.gd")
const Items=preload("res://scripts/survival/items.gd")
var game: Node3D
var assertions:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: ",message)
func frames(count: int=3) -> void:
	for i in range(count): await physics_frame
func equip(id: String,loaded: int=0) -> void:
	game.state.inventory.clear()
	var gun: Dictionary=game.state.make_item(id);gun.loaded=loaded
	game.state.pickup(gun);game.state.equip(gun.uid);game.combat.reset();game.combat._process(.01)
func pose(pos: Vector3,at: Vector3) -> void:
	game.player.position=pos;game.player.velocity=Vector3.ZERO;game.player.impulse=Vector3.ZERO;game.player.kick=0;game.player.roll=0;game.player.active=false
	game.player.face(at);await frames();game.combat._process(.01)
func fresh_enemy(id: String,at: Vector3) -> SurvivalEnemy:
	var enemy: SurvivalEnemy=game.spawn_enemy(id,at)
	enemy.set_physics_process(false)
	return enemy
func state_checks() -> void:
	var state:=State.new();state.begin_run()
	var gun:=state.make_item("pistol");state.pickup(gun);state.equip(gun.uid)
	check(gun.loaded==0 and state.ammo_count("pistol_ammo")==0,"Found guns are empty and ammo is inventory-backed")
	check(not state.fire_round(gun.uid) and state.reload_weapon(gun.uid)==0,"Empty weapons cannot fire or invent ammunition")
	var pack:=state.make_item("pistol_ammo");state.pickup(pack)
	check(state.reload_weapon(gun.uid)==8 and state.equipment.primary.loaded==8 and state.ammo_count("pistol_ammo")==4,"Reload moves only magazine capacity out of a counted pack")
	check(state.reload_weapon(gun.uid)==0 and not state.fire_round("wrong-uid"),"Full magazine and stale weapon references cannot consume ammo")
	for i in range(3): check(state.fire_round(gun.uid),"Each trigger consumes one loaded round")
	check(state.reload_weapon(gun.uid)==3 and state.ammo_count("pistol_ammo")==1,"Partial reload retains rounds already in the magazine")
	state.fire_round(gun.uid)
	check(state.reload_weapon(gun.uid)==1 and state.ammo_count("pistol_ammo")==0 and state.consumed.has(pack.uid),"Empty ammo pack retires its UID exactly once")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(state.serialize()));var restored:=State.new()
	check(restored.restore(saved) and restored.equipment.primary.loaded==8,"Magazine counts survive a JSON round trip")
	for bad in [-1,9,1.5,"4",INF]:
		var corrupted:=saved.duplicate(true);corrupted.equipment.primary.loaded=bad
		check(not restored.restore(corrupted) and restored.equipment.primary.loaded==8,"Malformed magazine state is rejected atomically: "+str(bad))
	var arrow_pack:=state.make_item("bolts")
	for bad in [0,25,2.5,"6",NAN]:
		var invalid:=arrow_pack.duplicate();invalid.quantity=bad
		check(not Items.valid_item(invalid),"Malformed ammo quantities rejected")
	state.extract();state.begin_run();state.fire_round(gun.uid);state.fail_run()
	check(state.equipment.primary.loaded==7,"Death restores departure gear without refilling spent ammunition")
	state.return_to_base();state.begin_run()
	var crossbow:=state.make_item("crossbow");state.pickup(crossbow);state.equip(crossbow.uid)
	state.pickup(state.make_item("pistol_ammo"))
	check(state.reload_weapon(crossbow.uid)==0,"Pistol rounds cannot load a crossbow")
	state.pickup(arrow_pack)
	check(state.reload_weapon(crossbow.uid)==1 and state.ammo_count("bolts")==5,"Crossbow loads exactly one arrow")
func run() -> void:
	state_checks()
	game=load("res://scenes/survival.tscn").instantiate();game.save_path="user://ranged-test.json";game.settings_path="user://ranged-test-settings.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.set_process(false);game.combat.set_process(false);await frames()
	game.new_profile();game.depart()
	for enemy in game.enemies: enemy.set_physics_process(false);enemy.collision_layer=0
	check(game.sources["east-luggage"].contents.any(func(i):return i.id=="crossbow") and game.sources["utility-box"].contents.any(func(i):return i.id=="pistol"),"Both weapons exist inside actual searchable apartment containers")
	check(game.loot.is_empty(),"Ranged supplies do not bypass the search system")
	# First visit is migrated once, including previously searched caches, without resetting their old items.
	var legacy: Dictionary=game.snapshot();legacy.erase("ranged_revision")
	for source in legacy.sources:
		source.contents=source.contents.filter(func(i): return i.id not in ["crossbow","pistol","bolts","pistol_ammo"])
	game.state.restore(legacy.profile);game.restore_run(legacy)
	var once: Dictionary=game.snapshot();var initial: Array=game.sources["utility-box"].contents.duplicate(true)
	game.state.restore(once.profile);game.restore_run(once)
	check(game.sources["utility-box"].contents==initial and initial.size()==4,"Old region gets ranged items once, preserving finite identities")
	# Acquire the bow and ammunition through the real container, not a debug grant.
	for enemy in game.enemies: enemy.set_physics_process(false);enemy.collision_layer=0
	game.resume_game()
	var luggage: SurvivalSearchable=game.sources["east-luggage"]
	await pose(Vector3(9.1,.04,-1.2),luggage.position);game.update_target()
	check(game.target==luggage,"Selection ray reaches the container holding the bow")
	Input.action_press("interact");game.interact_target();game.update_search(1.3);Input.action_release("interact")
	check(game.ui.view=="search" and luggage.searched,"Bow case uses the production search sequence")
	var acquired: Dictionary=luggage.contents.filter(func(i):return i.id=="crossbow")[0].duplicate()
	var acquired_ammo: Dictionary=luggage.contents.filter(func(i):return i.id=="bolts")[0].duplicate()
	game.take_from_source(acquired.uid);game.take_from_source(acquired_ammo.uid);game.close_search_results();game.use_item(acquired.uid)
	check(game.state.equipment.primary.uid==acquired.uid and game.state.ammo_count("bolts")==6,"Searched weapon equips and uses searched ammunition")
	var reload_event:=InputEventAction.new();reload_event.action="reload";reload_event.pressed=true;game._input(reload_event)
	check(game.combat.phase=="reload","Reload input is connected to the held bow")
	game.combat._process(1.9)
	check(game.state.equipment.primary.loaded==1 and game.state.ammo_count("bolts")==5,"Bow animation completes and consumes one searched arrow")
	game.change_region_now("district");game.resume_game()
	for enemy in game.enemies: enemy.set_physics_process(false);enemy.collision_layer=0
	equip("pistol");var ammo: Dictionary=game.state.make_item("pistol_ammo");game.state.pickup(ammo)
	check(game.combat.ranged.reload(),"Production reload starts")
	game.combat._process(.70)
	check(game.state.equipment.primary.loaded==0 and game.state.ammo_count("pistol_ammo")==12,"Reload windup reserves nothing and consumes nothing")
	game.player_hit(1,game.player.position+Vector3.RIGHT)
	check(game.combat.phase=="idle" and game.state.ammo_count("pistol_ammo")==12,"Damage interrupts reload without losing ammo")
	check(game.combat.ranged.reload(),"Reload can restart after interruption")
	game.combat._process(1.46);game.combat._process(.05)
	check(game.state.equipment.primary.loaded==8 and game.state.ammo_count("pistol_ammo")==4,"Animation completion commits exactly one magazine")
	game.state.fire_round(game.state.equipment.primary.uid);game.combat.ranged.reload();game.combat._process(.3);game.pause_game();game.resume_game()
	check(game.state.equipment.primary.loaded==7 and game.state.ammo_count("pistol_ammo")==4,"Pausing cancels reload without committing ammo")
	# A pistol's trigger hits immediately; holding and releasing cannot add a second shot.
	var target:=fresh_enemy("test-pistol",Vector3(0,.04,4))
	await pose(Vector3(0,.04,-2),Vector3(0,1.06,4));game.combat.ranged.aiming=true
	game.combat.press()
	check(target.health==57 and game.state.equipment.primary.loaded==6,"Pistol body shot is immediate and spends one round")
	game.combat.press();game.combat.release();game.combat._process(.35)
	check(target.health==57 and game.state.equipment.primary.loaded==6,"Semi-auto has no held-trigger repeat or release shot")
	check(game.combat.ranged.flash_time==0,"Muzzle flash ends after its short impulse")
	game.combat.ranged.aiming=true;game.combat._process(.4)
	check(game.player.camera.fov<60 and game.combat.ranged.sight_amount>.9,"Right-button aiming narrows FOV and aligns the model")
	await pose(Vector3(0,.04,-2),Vector3(0,1.62,4));game.combat.ranged.aiming=true
	game.combat.press();game.combat._process(.35)
	check(target.health==0 and game.sources.has("corpse-test-pistol"),"Pistol headshot uses the normal kill/XP/corpse path")
	# Wall between muzzle and target must absorb gunfire.
	var cover: StaticBody3D=game.world.box_body(game.world,Vector3(0,1.3,1),Vector3(2,2.6,.16))
	var shielded:=fresh_enemy("test-covered",Vector3(0,.04,4))
	await pose(Vector3(0,.04,-2),Vector3(0,1.1,4));var loaded: int=game.state.equipment.primary.loaded
	game.combat.press();game.combat._process(.4)
	check(shielded.health==95 and game.state.equipment.primary.loaded==loaded-1,"Walls block shots while the fired round remains spent")
	equip("crossbow",1);game.combat.press();game.combat.ranged.update_projectiles(.2)
	check(shielded.health==95 and game.combat.ranged.bolts.is_empty(),"Physical arrows also stop at cover")
	cover.queue_free();await frames()
	shielded.collision_layer=0
	# Crossbow projectile reaches the target over time and leaves a recoverable corpse arrow.
	equip("crossbow",1)
	var bow_target:=fresh_enemy("test-bow",Vector3(0,.04,8))
	await pose(Vector3(0,.04,2),Vector3(0,1.38,8));game.combat.ranged.aiming=true;game.combat.press()
	check(bow_target.health==95 and game.combat.ranged.bolts.size()==1,"Crossbow launches a travelling projectile rather than an immediate hit")
	var before_y: float=game.combat.ranged.bolts[0].velocity.y;game.combat.ranged.update_projectiles(.06)
	check(game.combat.ranged.bolts.size()==1 and game.combat.ranged.bolts[0].velocity.y<before_y,"Arrow velocity falls under gravity")
	var flight: Dictionary=game.snapshot();var flight_count: int=game.combat.ranged.bolts.size()
	game.state.restore(flight.profile);game.restore_run(flight);game.resume_game()
	for enemy in game.enemies: enemy.set_physics_process(false)
	check(game.state.equipment.primary.loaded==0 and game.combat.ranged.bolts.size()==flight_count,"An in-flight arrow resumes with its already spent ammo on save/restore")
	bow_target=game.enemies.filter(func(e):return e.enemy_id=="test-bow")[0]
	# Restore the intended line after previously disabled test actors were re-instantiated.
	for enemy in game.enemies:
		if enemy!=bow_target: enemy.collision_layer=0
	await frames();game.combat.ranged.update_projectiles(.2)
	check(bow_target.health==19 and bow_target.embedded_bolts==1 and game.combat.ranged.bolts.is_empty(),"Arrow segment sweep lands once and records its embedded ammunition")
	bow_target.receive_hit(100,Vector3.ZERO,0);game.update_sources()
	var corpse: SurvivalSearchable=game.sources["corpse-test-bow"]
	check(not corpse.searched and corpse.contents.any(func(i):return i.id=="bolts" and i.quantity==1),"Arrow recovery requires corpse search; nothing is granted directly")
	var bolt_item: Dictionary=corpse.contents.filter(func(i):return i.id=="bolts")[0]
	check(not corpse.take(bolt_item.uid,game.state),"Unsearched corpse cannot give back its arrow")
	corpse.reveal();check(corpse.take(bolt_item.uid,game.state) and not corpse.take(bolt_item.uid,game.state),"A recovered arrow transfers only once")
	# Sound distinguishes the two weapons, and stale aim cannot survive switching or menus.
	var listener:=fresh_enemy("test-listener",Vector3(0,.04,-9))
	await pose(Vector3(0,.04,1),Vector3(0,1.5,4));equip("crossbow",1);game.combat.press()
	check(listener.behavior=="idle","Quiet bow does not alert a listener ten metres away")
	game.combat.ranged.clear_projectiles();equip("pistol",1);game.combat.press()
	check(listener.behavior=="investigate","Gunshot attracts a listener outside bow hearing range")
	game.combat._process(.3);game.combat.ranged.aiming=true;game.combat._process(.3);game.pause_game()
	check(is_equal_approx(game.player.camera.fov,float(game.settings.fov)) and not game.combat.ranged.aiming,"Pause resets aim and restores the configured FOV")
	game.resume_game();game.combat.reset()
	check(not game.combat.ranged.fire() and game.state.equipment.primary.loaded==0,"Dry fire cannot create a shot")
	# UI descriptions work for both ammo packs and loaded weapons; original melee still equips.
	game.ui.current_state=game.state
	check("弹仓" in game.ui.describe_item(game.state.equipment.primary) and "剩余" in game.ui.describe_item(game.state.make_item("bolts")),"Inventory describes ranged weapons and ammunition without melee-only fields")
	game.ui.update_hud(game.state,"南街",true)
	check(game.ui.weapon_label.visible and "备用" in game.ui.weapon_label.text,"HUD exposes magazine and reserve counts")
	equip("wrench");check(game.combat.start_swing(false),"Melee attacks still work after switching back from a firearm")
	game.combat.reset();game.ui.update_hud(game.state,"南街",true)
	check(not game.ui.weapon_label.visible,"Ammo HUD hides for melee weapons")
	game.effects.stop_audio();await create_timer(.3).timeout;game.queue_free();await frames()
	DirAccess.remove_absolute("user://ranged-test.json");DirAccess.remove_absolute("user://ranged-test-settings.json")
	print("RANGED_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
