extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func advance(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		game.combat._process(1.0/60)
	await process_frame
func capture(label: String) -> void:
	game.ui.update_hud(game.state,"302",false)
	await RenderingServer.frame_post_draw
	print("HANDS_CAPTURE ",label," = ",root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/survival/hands-"+label+".png")))
func equip(id: String) -> void:
	game.state.phase="safe";game.state.inventory.clear()
	var item: Dictionary=game.state.make_item(id)
	if id in ["pistol","crossbow"]: item.loaded=1
	game.state.pickup(item);game.state.equip(item.uid)
	if id in ["wrench","bat"]: game.state.upgrade_melee(item.uid)
	game.state.phase="run";game.state.stamina=100;game.combat.reset();game.ui.show_game()
	await advance(.2)
func run() -> void:
	root.position=Vector2i(100,100)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/survival"))
	game=load("res://scenes/survival.tscn").instantiate()
	game.save_path="user://hands-preview.json";game.settings_path="user://hands-preview-settings.json"
	DirAccess.remove_absolute(game.save_path);DirAccess.remove_absolute(game.settings_path)
	root.add_child(game);game.new_profile();game.depart();game.reset_actors()
	assert(not game.combat.hand.left and game.combat.support_hand.left and game.combat.torch_grip.left,"Left and right meshes must use the matching skeleton")
	game.set_process(false);game.combat.set_process(false);game.player.active=false;game.player.set_physics_process(false)
	game.player.position=Vector3(-.7,.04,-2.2);game.player.face(Vector3(-2.5,1.4,-4.1))
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await create_timer(.4).timeout
	for id in ["wrench","bat","pistol","crossbow"]:
		await equip(id);await capture(id)
		if id in ["pistol","crossbow"]:
			game.combat.ranged.aiming=true;await advance(.35);await capture(id+"-aim")
			game.state.pickup(game.state.make_item("pistol_ammo" if id=="pistol" else "bolts"));game.state.equipment.primary.loaded=0
			game.combat.ranged.reload();print("RELOAD ",id);await advance(.55);await capture(id+"-reload")
			await advance(1.5)
	await equip("wrench");game.state.pickup(game.state.make_item("bottle"));game.combat.throw_gesture()
	await advance(.10);await capture("bottle-grip");await advance(.19);await capture("bottle-release")
	game.suspended=true;game.effects.stop_audio();await create_timer(.3).timeout;game.queue_free();await process_frame
	DirAccess.remove_absolute("user://hands-preview.json");DirAccess.remove_absolute("user://hands-preview-settings.json")
	quit()
