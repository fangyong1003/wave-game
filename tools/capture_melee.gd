extends SceneTree
var game: Node3D
var front: SurvivalEnemy
var rear: SurvivalEnemy
var origin:=Vector3(0,.04,0)
func _initialize() -> void: call_deferred("run")
func frames(n: int=3) -> void:
	for i in range(n): await physics_frame
func capture(label: String) -> void:
	game.ui.update_hud(game.state,game.room_name(game.player.position),game.world.region=="district")
	await RenderingServer.frame_post_draw
	var path: String=ProjectSettings.globalize_path("res://../artifacts/survival/melee-"+label+".png")
	print("CAPTURE ",label," = ",root.get_texture().get_image().save_png(path))
func advance(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		game.combat._process(1.0/60)
		for enemy in game.enemies:
			if enemy.launch_remaining>0 or enemy.behavior=="down" or enemy.health<=0: enemy._physics_process(1.0/60)
		game.update_sources()
		await physics_frame
func setup(id: String) -> void:
	game.reset_actors();game.state.phase="safe";game.state.inventory.clear()
	var item: Dictionary=game.state.make_item(id);game.state.pickup(item);game.state.equip(item.uid);game.state.upgrade_melee(item.uid)
	game.state.phase="run";game.state.stamina=100;game.suspended=false;game.combat.reset();game.ui.show_game()
	game.player.position=origin;game.player.velocity=Vector3.ZERO;game.player.kick=0;game.player.roll=0
	game.player.active=false;game.player.set_physics_process(false);game.player.face(origin+Vector3(0,1.30,3))
	front=game.spawn_enemy("street-preview-front",origin+Vector3(0,0,1.12),PI);front.set_physics_process(false)
	rear=game.spawn_enemy("street-preview-rear",origin+Vector3(.06,0,2.8),PI);rear.set_physics_process(false)
	await frames()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/survival"))
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://melee-preview.json";game.settings_path="user://melee-preview-settings.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.new_profile();game.set_process(false);game.combat.set_process(false)
	game.state.pickup(game.state.make_item("bat"));game.show_base()
	await create_timer(.3).timeout;await capture("base")
	game.on_ui_action("workshop",null)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await create_timer(1).timeout
	await capture("workshop")
	game.depart();game.change_region_now("district");await frames()
	await setup("bat");await advance(.02);await capture("bat-ready")
	game.combat.start_swing(true);await advance(.56);await capture("bat-flight")
	await advance(.25);await capture("bat-collision")
	await advance(.85);await capture("bat-landed")
	print("BAT hp=",front.health," rear=",rear.health," pos=",front.position)
	await setup("wrench");await advance(.02);await capture("wrench-ready")
	game.combat.press();game.combat.release();await advance(.13)
	game.combat.press();game.combat.release();await advance(.32);await capture("wrench-uppercut")
	game.combat.press();game.combat.release();await advance(.35);await capture("wrench-finisher")
	await advance(.8);await capture("wrench-landed")
	print("WRENCH hp=",front.health," kind=",game.combat.strike_kind)
	game.suspended=true;game.effects.stop_audio();await create_timer(.3).timeout;game.queue_free();await frames()
	DirAccess.remove_absolute("user://melee-preview.json");DirAccess.remove_absolute("user://melee-preview-settings.json")
	quit()
