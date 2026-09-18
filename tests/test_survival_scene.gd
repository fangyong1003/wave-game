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
	for e in game.enemies: e.set_physics_process(false)
func place(pos: Vector3,at: Vector3) -> void:
	game.player.active=false;game.player.velocity=Vector3.ZERO;game.player.impulse=Vector3.ZERO
	game.player.position=pos;game.player.face(at)
	await frames()
const SOURCE_MAP={"water-kitchen":"kitchen-box","energy-counter":"kitchen-box","water-cabinet":"cabinet","food-cabinet":"cabinet","water-storage":"storage-rack","pack-storage":"storage-rack","coat-locker":"locker","drop-living-infected":"corpse-living-infected"}
const ITEM_MAP={"water-kitchen":"water","energy-counter":"bar","water-cabinet":"water","food-cabinet":"can","water-storage":"water","pack-storage":"pack","coat-locker":"coat","drop-living-infected":"bat"}
func aim_source(id: String,pos: Vector3) -> void:
	await place(pos,game.sources[id].global_position)
	game.update_target()
	check(game.target==game.sources[id],"Real selection ray reaches source "+id+"; got "+str(game.target))
	check(game.source_reachable(game.sources[id]),"Reachable source "+id)
func pickup(id: String,pos: Vector3) -> void:
	game.combat.reset();game.close_search_results();game.update_sources()
	var source_id: String=SOURCE_MAP.get(id,id)
	await aim_source(source_id,pos)
	var source=game.sources[source_id]
	var uid: String=""
	for item in source.contents:
		if item.id==ITEM_MAP.get(id,"bottle"): uid=item.uid;break
	check(not uid.is_empty(),"Source still holds item "+id)
	Input.action_press("interact");game.interact_target()
	if not source.searched:
		check(game.search_id==source_id and game.ui.view=="game","Search must begin before contents are revealed")
		game.update_search(source.duration+.01)
	Input.action_release("interact")
	check(source.searched and game.ui.view=="search","Search reveals a result list: "+id)
	check(not game.suspended and not game.player.active,"Results keep the world live and release the cursor")
	game.take_from_source(uid);await frames()
	check(game.state.owns_uid(uid) and source.contents.all(func(i): return i.uid!=uid),"Claim transfers exactly once: "+id)
	game.close_search_results()
func aim_target(id: String,pos: Vector3) -> void:
	await place(pos,game.world.targets[id].global_position)
	game.update_target()
	check(is_instance_valid(game.target) and game.target.get_meta("interaction","")==id,"Interaction ray selects "+id+"; got "+str(game.target))
func walk_to(destination: Vector3) -> void:
	game.player.active=true
	Input.action_press("move_forward")
	for i in range(260):
		game.player.face(Vector3(destination.x,game.player.camera.global_position.y,destination.z))
		await physics_frame
		if Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<.15: break
	Input.action_release("move_forward");game.player.active=false
	check(Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<.22,"Walkable route to "+str(destination)+", reached "+str(game.player.position))
func strike(heavy: bool=false) -> void:
	game.combat.reset();game.state.stamina=game.state.maximum_stamina()
	check(game.combat.start_swing(heavy),"Production swing starts")
	game.combat._process(float(game.combat.profile.contact)+.01)
	await frames()
func key_action(name: String) -> void:
	var event:=InputEventAction.new();event.action=name;event.pressed=true
	Input.parse_input_event(event);await frames()
	event=InputEventAction.new();event.action=name;Input.parse_input_event(event);await frames()
func run() -> void:
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://survival-integration-test.json";game.settings_path="user://survival-integration-settings.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.set_process(false);game.combat.set_process(false)
	await frames()
	check(game.ui.view=="menu" and game.suspended,"Boot is paused menu")
	game.ui.action.emit("new",null)
	check(game.ui.view=="base" and game.state.phase=="safe","New profile opens safehouse")
	game.ui.action.emit("depart",null);freeze_enemies();await frames()
	check(game.enemies.size()==7 and game.loot.is_empty() and game.sources.size()==11 and game.ui.view=="game","Departure spawns the playable encounter")
	check(game.world.doors.cabinet.node.global_position.distance_to(Vector3(-2.16,.08,-1.89))<.01,"Authored cabinet pivot matches collision")
	# Skinned meshes have tiny bind-space AABBs; inspect the evaluated skeleton instead.
	var actor=game.enemies[0]
	var head_point: Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.head_bone).origin
	check(head_point.y>1.45 and head_point.y<1.9,"Animated head has human-scale height "+str(head_point))
	check(actor.animator.has_animation("Walk") and actor.animator.has_animation("Attack") and actor.animator.has_animation("Death"),"External model includes three skeletal animations")
	for clip in ["Walk","Attack","Death"]:
		actor.play_clip(clip,0)
		for fraction in [0.0,.25,.5,.75,1.0]:
			actor.animator.seek(actor.animator.get_animation(clip).length*fraction,true)
			var hip: Vector3=actor.corpse_point()-actor.global_position
			check(Vector2(hip.x,hip.z).length()<1.5 and hip.y>-.1 and hip.y<1.3,"Animation remains attached to actor: "+clip)
	actor.play_clip("Walk",0)
	var body: MeshInstance3D=actor.rig.find_children("*","MeshInstance3D",true,false)[0]
	check(body.get_active_material(0).albedo_texture!=null and body.get_active_material(0).normal_texture!=null,"Zombie uses imported diffuse and normal maps")
	await walk_to(Vector3(0,0,2.05));await walk_to(Vector3(0,0,-.4));await walk_to(Vector3(-1.1,0,-3.1))
	await pickup("water-kitchen",Vector3(-1.22,.04,-4.02))
	await pickup("energy-counter",Vector3(-1.22,.04,-3.3))
	check(not game.sources.cabinet.active,"Closed cabinet conceals its contents")
	await aim_target("cabinet",Vector3(-1.1,.04,-1.45))
	game.interact_target();await frames(30)
	check(game.world.doors.cabinet.open and game.sources.cabinet.active,"Opening cabinet exposes real pickups")
	await pickup("water-cabinet",Vector3(-1.1,.04,-1.55))
	await pickup("food-cabinet",Vector3(-1.1,.04,-1.42))
	# Consumption is delayed and damage cancels without consuming the item.
	var can_uid: String=game.state.inventory[game.state.item_index_by_id("can")].uid
	game.use_item(can_uid);game.update_use(.7)
	check(game.state.owns_uid(can_uid) and not game.using_uid.is_empty(),"Eating leaves food in bag until finished")
	game.player_hit(1,game.player.position+Vector3.RIGHT)
	check(game.using_uid.is_empty() and game.state.owns_uid(can_uid),"Damage cancels eating without losing food")
	game.use_item(can_uid);game.update_use(1.36)
	check(not game.state.owns_uid(can_uid) and game.state.nutrition>90,"Completed eating applies nutrition")
	# Tab releases movement while AI/world remain active; Esc really suspends.
	await key_action("inventory")
	check(game.ui.view=="inventory" and not game.suspended and not game.player.active,"Inventory is not a world pause")
	await key_action("pause_game")
	check(game.ui.view=="pause" and game.suspended,"Escape pauses the live inventory scene")
	await key_action("pause_game");await key_action("inventory")
	check(game.ui.view=="game" and game.player.active,"Return from inventory resumes captured controls")
	# Door, key and locked cache use the same line-of-sight interaction as loot.
	await aim_target("living",Vector3(4.95,.04,.05))
	game.interact_target();await frames(30)
	check(game.world.doors.living.open,"Living door opens")
	await place(Vector3(4.92,.04,.05),Vector3(4.92,1.3,2.1))
	await walk_to(Vector3(4.92,0,2.1));await walk_to(Vector3(4.17,0,2.25));await walk_to(Vector3(4.17,0,3.7))
	check(not game.navigation.path(Vector3(4.1,0,2),Vector3(5.4,0,5.2)).is_empty(),"Navigation reaches 303 through its doorway")
	await pickup("water-storage",Vector3(4.15,.04,5.45))
	await pickup("pack-storage",Vector3(4.15,.04,5.45))
	var pack_uid: String=game.state.inventory[game.state.item_index_by_id("pack")].uid
	game.use_item(pack_uid)
	check(game.state.capacity()==8 and game.state.equipment.pack.uid==pack_uid,"Equipment action expands carry capacity")
	await aim_target("locker",Vector3(6.16,.04,5.08))
	game.interact_target()
	check(not game.world.doors.locker.open and not game.sources.locker.active,"Locked cache rejects bare interaction")
	await aim_target("key",Vector3(4.56,.04,-2.35));game.interact_target();await frames()
	check(game.state.has_key and not game.world.key_visual.visible,"Key is taken through scene interaction")
	await aim_target("locker",Vector3(6.16,.04,5.08));game.interact_target();await frames()
	check(game.world.doors.locker.open,"Key opens cache")
	await pickup("coat-locker",Vector3(6.16,.04,5.12))
	# A sweep hits flesh once, with material effects, then awards a death only once.
	var first=game.enemies[0];first.position=Vector3(4.7,.02,-2.15)
	await place(Vector3(4.7,.04,-.85),first.position+Vector3.UP*1.25)
	check(game.combat.sweep(1.65).get("collider")==first,"Real melee sweep selects the enemy")
	await strike()
	check(first.health==61 and game.effects.fragments.size()>0 and game.combat.freeze>0,"Light hit applies damage and impact feedback")
	game.combat.resolve_hit()
	check(first.health==61,"One swing cannot deal damage twice")
	await strike(true)
	check(first.health==0 and game.state.xp==40 and game.sources.has("corpse-living-infected") and game.loot.is_empty(),"Kill awards XP and searchable corpse without loose drops")
	game.enemy_killed(first)
	check(game.state.xp==40,"Duplicate death callback cannot grant XP")
	first.animate(3.0);game.update_sources();await frames()
	await pickup("drop-living-infected",Vector3(4.4,.04,-1.45))
	var bat_uid: String=game.state.inventory[game.state.item_index_by_id("bat")].uid
	game.combat.reset();game.on_ui_action("secondary",bat_uid);game.swap_weapon();game.combat.reset()
	check(game.state.weapon().reach==2.0 and game.combat.shown_weapon=="bat","Collected weapon equips and switches model")
	var second=game.enemies[1];second.position=Vector3(3.5,.04,-2.0);second.behavior="chase"
	await place(Vector3(2.5,.04,-2.0),second.position+Vector3.UP*1.3)
	check(not second.can_see_player(),"Solid partition blocks enemy vision")
	await strike(true)
	check(second.health==95,"Melee cannot damage through partition")
	var hp_before: float=game.state.hp
	second.behavior="windup";second.timer=0;second.attack_fired=false;second._physics_process(.02)
	check(game.state.hp==hp_before,"Enemy cannot finish attack through partition")
	# The sound points toward the landing site, not the player behind the wall.
	second.position=Vector3(5.5,.04,-1.8);second.behavior="idle"
	await place(Vector3(1,.04,-3),Vector3(1,1,-4))
	second.hear(Vector3(4,.04,-.8),6)
	check(second.behavior=="investigate" and second.target_point.distance_to(Vector3(4,.04,-.8))<.01,"Noise investigation stores the actual source")
	second.behavior="recover";second.hear(Vector3(4,.04,-.8),6)
	check(second.behavior=="recover","Noise cannot bypass the enemy's recovery window")
	second.behavior="investigate"
	var start: Vector3=second.position
	second.set_physics_process(true);await frames(90);second.set_physics_process(false)
	check(second.position.distance_to(start)>.4 and second.position.y>-.1,"AI follows navigation with collision and floor support")
	# A visible close target has a telegraphed strike and recovery window.
	second.position=Vector3(4.7,.04,-2.15);second.behavior="chase";second.target_point=Vector3(4.7,.04,-1.0)
	await place(Vector3(4.7,.04,-1.0),second.position+Vector3.UP*1.3)
	second._physics_process(.01)
	check(second.behavior=="windup" and second.timer>.5,"Close attack has a visible windup")
	second.timer=0;second._physics_process(.01)
	check(game.state.hp<hp_before and second.behavior=="recover","Enemy deals damage and enters recovery")
	game.combat.reset();game.state.stamina=100
	check(game.combat.push() and second.behavior=="stagger","Push interrupts the enemy")
	second.health=1;game.combat.reset();await strike()
	var third=game.enemies[2];third.position=Vector3(4.7,.04,-2.15);third.health=1
	await frames();await strike()
	check(game.state.level==2 and game.state.points==1 and game.state.run_kills==3,"First three kills award the first level")
	game.on_ui_action("attribute","endurance")
	check(game.state.maximum_stamina()==110 and game.state.points==0,"UI attribute action changes player functions")
	# Breakable glass works through collision hits too (separate route from key).
	game.world.reset();game.refresh_world();await frames()
	await place(Vector3(6.18,.04,4.9),Vector3(6.18,1.1,6.0));await strike(true)
	check(game.world.doors.locker.open,"Heavy bat hit breaks locked glass")
	# A dropped item can be recovered, while a thrown bottle becomes one noise event.
	game.combat.reset()
	await place(Vector3(.2,.04,-2),Vector3(.2,.8,-3.4))
	var bottle: Dictionary=game.state.make_item("bottle")
	check(game.state.pickup(bottle),"There is space for a throwable")
	game.drop_item(bottle.uid);await frames()
	check(not game.state.owns_uid(bottle.uid) and game.sources.has("dropped-"+bottle.uid),"Drop creates one searchable supply bag")
	await pickup("dropped-"+bottle.uid,Vector3(.2,.04,-1.5))
	game.throw_bottle()
	check(game.projectiles.is_empty() and game.state.owns_uid(bottle.uid),"Throw windup retains the bottle until release")
	game.combat._process(.25)
	check(game.projectiles.size()==1 and not game.state.owns_uid(bottle.uid),"Throw consumes item and launches real projectile")
	for i in range(190): game.update_projectiles(1.0/60)
	check(game.projectiles.is_empty() and game.state.consumed.has(bottle.uid),"Projectile breaks and is not restored as loot")
	# Sprint/crouch change the production movement and stamina controller.
	game.player.active=true;game.state.stamina=100
	Input.action_press("move_forward");Input.action_press("sprint");await frames(16)
	check(game.player.sprinting and game.state.stamina<100,"Sprinting consumes stamina")
	Input.action_release("sprint");Input.action_release("move_forward")
	Input.action_press("crouch");await frames(16)
	check(game.player.crouched and game.player.camera.position.y<1.2,"Crouching lowers camera and capsule")
	Input.action_release("crouch");game.player.active=false;await frames(15)
	# Snapshot restores the exact loot/enemy/door state without duplicating kills.
	game.save_game()
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(game.valid_snapshot(snapshot),"Atomic save is valid JSON")
	var stash_before: int=game.state.stash.size()
	check(game.state.restore(snapshot.profile),"Saved live profile restores")
	game.restore_run(snapshot);freeze_enemies();await frames()
	check(game.state.run_kills==3 and game.enemies[0].health==0 and game.sources["kitchen-box"].contents.is_empty() and game.sources["kitchen-box"].searched,"Reload preserves dead enemies and collected loot")
	check(game.world.doors.locker.open and game.state.equipment.pack.id=="pack","Reload preserves opened cache and equipment")
	# Extract with two collected waters through the actual door and timed interaction.
	await aim_target("safe",Vector3(-1.35,.04,1.76));game.interact_target();game.update_use(1.16)
	check(game.state.phase=="safe" and game.state.mission_done and game.state.stash.size()>stash_before,"Door extraction banks real collected loot")
	check(game.ui.view=="base" and game.suspended,"Extraction returns to playable safehouse management")
	var equipment_before: Dictionary=game.state.equipment.duplicate(true)
	game.depart();freeze_enemies();await frames()
	game.state.pickup(game.state.make_item("coat"));game.state.equip(game.state.inventory[0].uid)
	game.player_hit(1000,game.player.position+Vector3.RIGHT)
	check(game.ui.view=="dead" and game.state.phase=="dead" and game.state.equipment==equipment_before,"Lethal hit restores departure gear and presents recovery")
	game.on_ui_action("recover",null)
	check(game.state.phase=="safe" and game.state.level==2,"Recovery retains progression and allows another run")
	game.apply_setting("fov",81);game.apply_setting("shake",0);game.load_settings()
	check(game.player.camera.fov==81 and game.player.shake_strength==0,"Settings persist and apply to real camera")
	# Exit audio cleanly before freeing the renderer/scene.
	game.effects.stop_audio();await frames(15)
	game.queue_free();await frames()
	# A structurally valid envelope with a bad profile must not expose Continue.
	var file:=FileAccess.open("user://survival-integration-test.json",FileAccess.WRITE)
	file.store_string('{"schema":2,"profile":{"version":2,"phase":"run"},"world":{},"loot":[],"enemies":[]}');file.close()
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://survival-integration-test.json";game.settings_path="user://survival-integration-settings.json"
	root.add_child(game);game.set_process(false);await frames()
	check(game.saved_snapshot.is_empty() and game.ui.view=="menu","Corrupt profile falls back to usable new-game menu")
	game.effects.stop_audio();await frames(15);game.queue_free();await frames()
	DirAccess.remove_absolute("user://survival-integration-test.json");DirAccess.remove_absolute("user://survival-integration-settings.json")
	print("SURVIVAL_SCENE_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
