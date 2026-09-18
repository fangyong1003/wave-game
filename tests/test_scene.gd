extends SceneTree
## Integration checks: actual apartment collisions, ray selection, input, UI and disk saves.
var game: Node3D
var assertions := 0
var failures := 0
var stations := {
	"kitchen":Vector3(-1.35,.08,-1.35), "tap":Vector3(-1.4,.08,-2.6),
	"living":Vector3(4.8,.08,-1.9), "printer":Vector3(-2.1,.08,1.2)
}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func frames(count: int = 3) -> void:
	for i in range(count): await physics_frame

func aim(id: String) -> void:
	game.player.active = false
	game.player.position = stations.get(id,Vector3(1.25,.08,game.targets[id].position.z))
	game.player.face(game.targets[id].global_position)
	await frames()
	game.update_target(.016)
	var selected: String = game.target.get_meta("target_id") if game.target else "nothing"
	check(selected == id,"Ray selects %s, got %s" % [id,selected])

func action(id: String, use_wrench: bool = false) -> void:
	await aim(id)
	if use_wrench:
		Input.action_press("operate")
		game.update_target(1.3)
		Input.action_release("operate")
		game.update_target(.016)
	else:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		Input.parse_input_event(event)
		await frames()
		event = InputEventAction.new()
		event.action = "interact"
		Input.parse_input_event(event)
		await frames()

func measure(id: String) -> void:
	await aim(id)
	Input.action_press("measure")
	game.update_target(.8)
	check(not game.ui.diagnostic.text.is_empty(),"Measurement feedback for "+id)
	Input.action_release("measure")
	game.update_target(.016)

func walk_to(destination: Vector3) -> void:
	game.player.active = true
	game.player.face(Vector3(destination.x,game.player.camera.global_position.y,destination.z))
	Input.action_press("move_forward")
	for i in range(300):
		await physics_frame
		game.player.face(Vector3(destination.x,game.player.camera.global_position.y,destination.z))
		if Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length() < .16:
			break
	Input.action_release("move_forward")
	game.player.active = false
	check(Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length() < .20,"Walkable route to "+str(destination)+"; stopped at "+str(game.player.position))

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://integration302-save.json"
	game.settings_path = "user://integration302-settings.json"
	root.add_child(game)
	game.set_process(false)
	await frames()
	check(game.ui.menu.visible,"Menu is the initial screen")
	game.ui.start_requested.emit(false)
	check(game.started and not game.paused and game.ui.hud.visible,"Start signal enters playable scene")
	await walk_to(Vector3(0,0,-.5))
	await walk_to(Vector3(4.2,0,-.5))
	await walk_to(Vector3(4.92,0,.4))
	await walk_to(Vector3(4.92,0,2.1))
	await measure("kitchen")
	await measure("living")
	check(game.state.kitchen_seen and game.state.living_seen,"Both initial observations registered")
	await aim("manifold")
	await action("collar",true)
	check(not game.state.collar_locked,"Hold input unlocks collar")
	await action("direction",true)
	game.update_visuals(1)
	check(game.state.transferred and game.lamp.position.y > 1,"Wrong order transfers anomaly to physical lounge lamp")
	await measure("living")
	check("转移" in game.ui.diagnostic.text or game.state.living_strength() > .5,"Instrument detects transfer")
	await action("hose")
	check(game.state.hose_taken,"Keyboard interaction takes hose")
	await action("connect")
	check(game.state.hose_connected,"Hose connects through input path")
	await action("bypass",true)
	for i in range(480): game.state.tick(1.0/60.0)
	check(is_zero_approx(game.state.pressure) and not game.state.transferred,"Actual drainage clears transferred load")
	await action("collar",true)
	await action("bypass",true)
	check(game.state.stable(),"Recovered repair is stable")
	await action("tap")
	check(not game.state.faucet_on,"Tap can be switched off")
	await action("tap")
	check(game.state.faucet_tested,"Reopening tap records restart test")
	await measure("kitchen")
	await measure("living")
	await action("cover")
	check(game.state.can_complete(),"Real scene sequence satisfies all inspections")
	game.save_game()
	var saved := FileAccess.get_file_as_string(game.save_path)
	check(not saved.is_empty(),"Save is written to disk")
	game.start_game(true)
	check(game.state.can_complete(),"Resume restores inspected repair")
	game.player.active = false
	game.ui.show_ticket(game.state)
	check(not game.ui.submit_button.disabled,"Completed checklist enables signature")
	game.ui.submit_button.pressed.emit()
	check(game.state.completed,"Signing UI completes 302")
	await action("printer")
	check(game.paused and game.ui.menu.visible,"Printer opens ending")
	check("401" in game.ui.headline.text,"Ending delivers impossible next address")
	# Walls must occlude interactables. Looking at a target through the partition is invalid.
	game.start_game(false)
	game.player.active = false
	game.player.position = Vector3(3.7,.08,-3.46)
	game.player.face(game.targets.direction.global_position)
	await frames()
	game.update_target(.016)
	check(game.target == null,"Solid partition blocks target selection")
	# Walk into a wall for one second using the production controller and physics world.
	game.player.position = Vector3(0,.08,-4.5)
	game.player.rotation.y = 0
	game.player.active = true
	Input.action_press("move_forward")
	await frames(75)
	Input.action_release("move_forward")
	check(game.player.position.z > -4.85 and game.player.position.y > -.1,"Capsule remains inside apartment and above floor")
	game.player.active = false
	game.apply_setting("fov",81)
	game.apply_setting("binding:interact",KEY_F)
	game.load_settings()
	check(is_equal_approx(game.player.camera.fov,81),"Saved FOV reapplied")
	check(is_equal_approx(game.ui.setting_sliders.fov.value,81),"Settings UI reflects saved FOV")
	check(game.ui.binding_buttons.interact.text == "F","Settings UI reflects remapped key")
	await aim("hose")
	check("F" in game.ui.interaction_detail.text,"World hint reflects remapped key")
	# Truncated/corrupt outer save must fall back to a usable new job.
	var file := FileAccess.open(game.save_path,FileAccess.WRITE)
	file.store_string('{"repair": "broken", "position": ["x", null, {}]}')
	file.close()
	game.start_game(true)
	check(not game.state.completed and game.player.position.is_finite(),"Invalid outer save falls back safely")
	game.started = false
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(game.settings_path)
	# Match production quit: release playback on the audio thread before freeing the scene.
	game.stop_audio()
	await frames(15)
	game.queue_free()
	await frames()
	print("SCENE_INTEGRATION_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
