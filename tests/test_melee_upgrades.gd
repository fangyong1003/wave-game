extends SceneTree
const State=preload("res://scripts/survival/state.gd")
const Items=preload("res://scripts/survival/items.gd")
var game: Node3D
var assertions:=0
var failures:=0
const ORIGIN=Vector3(50,.04,0)
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: ",message)
func frames(n: int=3) -> void:
	for i in range(n): await physics_frame
func advance(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		game.combat._process(1.0/60)
		for enemy in game.enemies:
			if enemy.launch_remaining>0 or enemy.behavior=="down" or enemy.health<=0: enemy._physics_process(1.0/60)
		game.update_sources()
		await physics_frame
func enemy(id: String,offset: Vector3) -> SurvivalEnemy:
	var actor: SurvivalEnemy=game.spawn_enemy(id,ORIGIN+offset)
	actor.set_physics_process(false)
	return actor
func equip(id: String,upgraded: bool=true) -> void:
	game.state.phase="safe";game.state.inventory.clear()
	var item: Dictionary=game.state.make_item(id);game.state.pickup(item);game.state.equip(item.uid)
	if upgraded: game.state.upgrade_melee(item.uid)
	game.state.phase="run";game.state.stamina=100;game.combat.reset()
func reset_arena() -> void:
	game.reset_actors();game.combat.reset();game.player.position=ORIGIN
	game.player.velocity=Vector3.ZERO;game.player.impulse=Vector3.ZERO;game.player.kick=0;game.player.roll=0
	game.player.active=false;game.player.set_physics_process(false);game.player.face(ORIGIN+Vector3(0,1.25,-3))
	game.suspended=false;game.state.phase="run";game.ui.show_game()
	await frames()
func click() -> void:
	game.combat.press();game.combat.release()
func state_checks() -> void:
	var state:=State.new()
	check(state.upgrade_melee("starter-wrench"),"Owned starting wrench upgrades in safehouse")
	check(state.weapon().get("melee_upgrade",false) and "破势" in Items.caption(state.equipment.primary),"Effective stats and caption expose the upgraded instance")
	check(not state.upgrade_melee("starter-wrench") and not state.upgrade_melee("missing"),"Repeat and forged upgrades are rejected")
	var bat: Dictionary=state.make_item("bat");state.pickup(bat);state.transfer(bat.uid,false)
	check(state.upgrade_melee(bat.uid) and state.stash[0].melee_upgrade,"Stashed bat can be upgraded without moving or duplicating it")
	var data: Dictionary=JSON.parse_string(JSON.stringify(state.serialize()));var restored:=State.new()
	check(restored.restore(data) and restored.equipment.primary.melee_upgrade and restored.stash[0].melee_upgrade,"JSON save preserves upgrades in equipment and storage")
	for bad in [1,"true",null,[],{}]:
		var invalid: Dictionary=data.duplicate(true);invalid.equipment.primary.melee_upgrade=bad
		check(not restored.restore(invalid) and restored.equipment.primary.melee_upgrade,"Invalid upgrade field rejected before profile mutation")
	var invalid_food: Dictionary=state.make_item("water");invalid_food.melee_upgrade=true
	check(not Items.valid_item(invalid_food),"Food cannot carry a melee upgrade")
	var legacy: Dictionary=data.duplicate(true);legacy.equipment.primary.erase("melee_upgrade");legacy.stash[0].erase("melee_upgrade")
	check(restored.restore(legacy) and not restored.weapon().get("melee_upgrade",false),"Older saves load as unmodified equipment")
	state.begin_run();check(not state.upgrade_melee(bat.uid),"Upgrading during an expedition is blocked")
	state.fail_run();check(state.equipment.primary.melee_upgrade,"Departure weapon upgrades survive death recovery")
func run() -> void:
	state_checks()
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://melee-upgrade-test.json";game.settings_path="user://melee-upgrade-settings-test.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.set_process(false);game.combat.set_process(false)
	game.new_profile();game.on_ui_action("workshop",null)
	check(game.ui.view=="workshop" and game.suspended,"Workshop opens only from safehouse")
	game.on_ui_action("upgrade_melee","starter-wrench")
	check(game.state.equipment.primary.melee_upgrade and game.ui.view=="workshop","Workshop action upgrades and refreshes without starting play")
	game.on_ui_action("workshop_back",null);check(game.ui.view=="base","Workshop returns to safehouse")
	game.depart();game.world.map_bounds=Rect2(40,-9,20,18);game.world.box_body(game.world,Vector3(50,-.15,0),Vector3(18,.3,18))
	await reset_arena();equip("bat",false)
	var left:=enemy("sweep-left",Vector3(-.60,0,-1.25));var right:=enemy("sweep-right",Vector3(.60,0,-1.25))
	await frames();game.combat.start_swing(false);await advance(.32)
	check(left.health<95 and right.health<95,"Basic bat connects with multiple bodies in its visible arc")
	var hp: float=left.health;game.combat.resolve_hit();check(left.health==hp,"One swing never damages the same body twice")
	await reset_arena();equip("bat",false)
	left=enemy("wall-visible",Vector3(-.65,0,-1.30));right=enemy("wall-hidden",Vector3(.65,0,-1.30))
	var occluder: StaticBody3D=game.world.box_body(game.world,ORIGIN+Vector3(.48,.95,-.66),Vector3(.60,2,.16))
	await frames();game.combat.start_swing(false);await advance(.32)
	check(left.health<95 and right.health==95,"Bat sweep does not damage a body behind an intervening wall")
	occluder.queue_free();await frames()
	await reset_arena();equip("bat")
	var front:=enemy("launch-front",Vector3(0,0,-1.25));var rear:=enemy("launch-rear",Vector3(0,0,-2.6))
	await frames();check(game.combat.start_swing(true),"Upgraded bat heavy attack starts")
	await advance(.42)
	check(front.health==0 and front.launch_remaining>0,"Heavy blow kills an ordinary target and launches the actual body")
	check(game.sources.has("corpse-launch-front") and game.loot.is_empty(),"Launch kill creates a searchable corpse, not floor loot")
	await advance(.20)
	check(rear.health==33 and rear.behavior=="down","Flying body deals one collateral hit and knocks the rear enemy down: hp="+str(rear.health)+" behavior="+rear.behavior)
	var saved_velocity: Vector3=front.launch_velocity
	var before_reload: Dictionary=game.snapshot()
	game.state.restore(before_reload.profile);game.restore_run(before_reload)
	for actor in game.enemies: actor.set_physics_process(false)
	front=game.enemies.filter(func(e):return e.enemy_id=="launch-front")[0]
	rear=game.enemies.filter(func(e):return e.enemy_id=="launch-rear")[0]
	check(front.launch_velocity.is_equal_approx(saved_velocity),"Flight velocity restores without world-position clamping")
	check(front.launch_remaining>0 and front.launch_hits.has("launch-rear"),"Mid-flight save restores velocity and struck identities")
	await advance(1.6)
	check(rear.health==33 and front.launch_remaining==0,"Reload does not replay collateral damage; flight lands")
	game.update_sources()
	check(game.sources["corpse-launch-front"].position.distance_to(front.corpse_point())<.02,"Corpse search follows final body position")
	check(front.global_position.y<.15 and game.sources["corpse-launch-front"].position.y<.5,"Launched corpse settles back onto the floor: root="+str(front.global_position)+" pelvis="+str(front.corpse_point())+" death="+str(front.death_time)+" clip="+str(front.animator.get_animation("Death").length))
	var xp: int=game.state.run_xp;game.enemy_killed(front)
	check(game.state.run_xp==xp,"Repeated flight/death updates cannot award XP twice")
	await reset_arena();equip("bat")
	front=enemy("blocked-front",Vector3(0,0,-1.20));rear=enemy("blocked-rear",Vector3(0,0,-3.1))
	occluder=game.world.box_body(game.world,ORIGIN+Vector3(0,1.6,-2.35),Vector3(5,3.2,.2))
	await frames();game.combat.start_swing(true);await advance(1.4)
	check(front.launch_wall_hit and front.position.z>-2.35,"Launched body hits the wall instead of tunnelling through")
	check(rear.health==95,"Collateral damage cannot pass through walls")
	check(game.sources["corpse-blocked-front"].position.z>-2.35,"Search point remains on the reachable side of the wall")
	occluder.queue_free();await frames()
	await reset_arena();equip("wrench")
	front=enemy("combo-front",Vector3(0,0,-1.12))
	await frames();click();await advance(.13)
	check(front.health==61 and game.combat.combo_next==1,"First combo contact primes uppercut without bonus damage")
	click();await advance(.30)
	check(game.combat.strike_kind=="uppercut" and front.health==27 and front.launch_remaining>0,"Buffered second click produces a visible uppercut")
	click();await advance(.35)
	check(game.combat.strike_kind=="finisher" and front.health==0,"Third click follows the raised enemy with a lethal down strike")
	check(game.state.stamina>58,"Confirmed upgraded melee kill restores some stamina")
	await advance(1.2);check(game.combat.combo_next==0,"Completed chain returns to neutral")
	await reset_arena();equip("wrench")
	front=enemy("cancel-front",Vector3(0,0,-1.1));await frames();click();await advance(.13)
	click();game.player_hit(1,ORIGIN+Vector3.RIGHT)
	check(game.combat.phase=="idle" and game.combat.combo_next==0 and not game.combat.queued_light,"Taking damage clears combo and buffered attacks")
	await advance(.4);check(front.health==61,"Cancelled input does not strike later")
	game.combat.reset();game.state.stamina=100;game.player.face(ORIGIN+Vector3(0,1,3));await frames();click();await advance(.4)
	check(game.combat.combo_next==0,"Empty swings do not unlock uppercut")
	await reset_arena();equip("wrench")
	front=enemy("pause-front",Vector3(0,0,-1.1));await frames();click();await advance(.13);click();game.pause_game()
	check(game.combat.combo_next==0 and not game.combat.queued_light,"Pausing cancels the chain")
	game.resume_game();game.combat.reset()
	var upgraded_model: Node3D=game.combat.weapon_model
	game.state.phase="safe";var plain: Dictionary=game.state.make_item("wrench");game.state.pickup(plain);game.state.equip(plain.uid);game.state.phase="run";game.combat.reset()
	check(game.combat.weapon_model!=upgraded_model and not game.state.weapon().get("melee_upgrade",false),"Swapping same-type weapon refreshes appearance and combat capability")
	game.suspended=true;game.effects.stop_audio();await create_timer(.3).timeout;game.queue_free();await frames()
	DirAccess.remove_absolute("user://melee-upgrade-test.json");DirAccess.remove_absolute("user://melee-upgrade-settings-test.json")
	print("MELEE_UPGRADE_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
