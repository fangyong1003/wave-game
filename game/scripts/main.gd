extends Node3D

const State = preload("res://scripts/repair_state.gd")
const Player = preload("res://scripts/player.gd")
const UI = preload("res://scripts/game_ui.gd")
const P = preload("res://scripts/props.gd")
var save_path := "user://apartment302-save.json"
var settings_path := "user://apartment302-settings.json"
var state: RepairState
var player: RepairPlayer
var ui: RepairUI
var environment: Environment
var menu_camera: Camera3D
var started := false
var paused := true
var time := 0.0
var save_clock := 0.0
var target: Area3D
var targets: Dictionary = {}
var target_data: Dictionary = {}
var hold_target := ""
var hold_time := 0.0
var measured_target := ""
var measure_time := 0.0
var cup: Node3D
var lamp: Node3D
var valve: Node3D
var collar: Node3D
var bypass: Node3D
var cover: Node3D
var hose_on_hook: Node3D
var hose_attached: Node3D
var drops: Array[MeshInstance3D] = []
var gauge: Node3D
var gauge_needle: Node3D
var gauge_text: Label3D
var wrench: Node3D
var tools_root: Node3D
var panel_needle: Node3D
var sound_fx: AudioStreamPlayer
var rain_audio: AudioStreamPlayer
var room_audio: AudioStreamPlayer
var water_audio: AudioStreamPlayer3D
var drain_audio: AudioStreamPlayer3D
var settings := {"sensitivity":0.085,"fov":74.0,"brightness":1.05,"volume":0.65,"head_bob":false}
var screenshot_path := ""
var screenshot_clock := 0.0
var inspection_mode := ""
var last_kitchen := 1.0
var exiting := false
var steel: StandardMaterial3D
var brass: StandardMaterial3D
var black: StandardMaterial3D
var white: StandardMaterial3D
var red: StandardMaterial3D

func _ready() -> void:
	get_tree().auto_accept_quit = false
	setup_inputs()
	state = State.new()
	setup_world()
	setup_props()
	player = Player.new()
	add_child(player)
	player.position = Vector3(0,0.08,2.1)
	player.stepped.connect(func(): play_fx("step",-12))
	setup_tools()
	setup_audio()
	ui = UI.new()
	add_child(ui)
	ui.start_requested.connect(start_game)
	ui.resume_requested.connect(resume_game)
	ui.submit_requested.connect(submit)
	ui.quit_requested.connect(request_quit)
	ui.setting_changed.connect(apply_setting)
	load_settings()
	ui.show_menu(false, FileAccess.file_exists(save_path))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_camera.current = true
	# Integration/visual checks use the real scene and production puzzle actions.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			screenshot_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--view="):
			inspection_mode = arg.trim_prefix("--view=")
	if not inspection_mode.is_empty():
		start_game(false)
		match inspection_mode:
			"kitchen":
				player.position = Vector3(.8,.08,.25)
				player.face(Vector3(-1.0,1.5,-3.2))
			"panel":
				player.position = Vector3(1.5,.08,-3.1)
				player.face(Vector3(2.6,1.55,-3.15))
			"living":
				player.position = Vector3(4.2,.08,-.5)
				player.face(Vector3(4.5,1.1,-3.4))
		paused = true
		player.active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func setup_inputs() -> void:
	var keys := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"interact":KEY_E,"walk_slow":KEY_SHIFT,"ticket":KEY_TAB,"hint":KEY_H,"pause_game":KEY_ESCAPE}
	for action in keys:
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	for data in [["measure",MOUSE_BUTTON_RIGHT],["operate",MOUSE_BUTTON_LEFT]]:
		InputMap.add_action(data[0])
		var event := InputEventMouseButton.new()
		event.button_index = data[1]
		InputMap.action_add_event(data[0],event)

func setup_world() -> void:
	var scene = load("res://assets/models/apartment_302.glb")
	assert(scene is PackedScene,"Missing apartment asset. Run tools/build_apartment.py with Blender.")
	var apartment: Node3D = scene.instantiate()
	add_child(apartment)
	apply_surface_materials(apartment)
	for obj in apartment.get_children():
		if obj is MeshInstance3D:
			if "window" in obj.name or "light_diffuser" in obj.name:
				obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/collision_layout.json"))
	for item in data:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(item.size[0],item.size[1],item.size[2])
		shape.shape = box
		body.position = Vector3(item.pos[0],item.pos[1],item.pos[2])
		body.add_child(shape)
		add_child(body)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("72818c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("90a4b2")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.fog_enabled = true
	environment.fog_light_color = Color("6f8590")
	environment.fog_density = 0.008
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.76
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		environment.ssao_enabled = true
		environment.ssao_radius = 1.1
		environment.ssao_intensity = 1.8
		environment.ssil_enabled = true
		environment.ssil_intensity = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-75,0)
	sun.light_color = Color("b3c7d6")
	sun.light_energy = 0.22
	sun.shadow_enabled = true
	add_child(sun)
	omni(Vector3(-2.5,2.15,-2.6),Color("b3c6d3"),0.90,5.7,true)
	omni(Vector3(-2.25,1.95,-4),Color("ccdddf"),0.32,2.0,false)
	omni(Vector3(2.43,2.25,-3.18),Color("ffc98a"),0.62,2.8,true)
	omni(Vector3(5.1,2.7,-2.4),Color("a0b4c1"),0.36,4.0,true)
	for x in [-1.8,1.6,5.3]:
		omni(Vector3(x,2.88,2),Color("a8bcbd"),0.36,3.0,false)
	menu_camera = Camera3D.new()
	menu_camera.position = Vector3(.8,1.70,.28)
	menu_camera.fov = 73
	add_child(menu_camera)
	menu_camera.look_at(Vector3(-.6,1.43,-3.3))

func apply_surface_materials(apartment: Node) -> void:
	for node in apartment.find_children("*","MeshInstance3D",true,false):
		var m := node as MeshInstance3D
		for index in range(m.mesh.get_surface_count()):
			var original = m.mesh.surface_get_material(index)
			if not original is StandardMaterial3D:
				continue
			var n: String = original.resource_name
			if n == "stone_floor":
				var floor_mat: StandardMaterial3D = original.duplicate()
				floor_mat.albedo_color = Color(.65,.69,.68)
				floor_mat.roughness = .72
				m.set_surface_override_material(index,floor_mat)
			elif n in ["aged_plaster","cabinet_paint","old_wood"]:
				var aged := ShaderMaterial.new()
				aged.shader = load("res://shaders/aged_surface.gdshader")
				aged.set_shader_parameter("tint",Color(.64,.65,.59) if n == "aged_plaster" else original.albedo_color)
				aged.set_shader_parameter("wear",.42 if n == "aged_plaster" else .46)
				aged.set_shader_parameter("roughness_base",.92 if n == "aged_plaster" else .65)
				if original.albedo_texture:
					aged.set_shader_parameter("textured",true)
					aged.set_shader_parameter("color_map",original.albedo_texture)
					aged.set_shader_parameter("normal_map",original.normal_texture)
					aged.set_shader_parameter("rough_map",original.roughness_texture)
				m.set_surface_override_material(index,aged)

func omni(pos: Vector3, color: Color, energy: float, radius: float, shadows: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.light_size = .13
	light.omni_range = radius
	light.omni_attenuation = 1.5
	light.shadow_enabled = shadows
	light.shadow_bias = 0.035
	add_child(light)
	return light

func setup_props() -> void:
	steel = P.material(Color("687278"),0.28,0.8)
	brass = P.material(Color("87704b"),0.43,0.75)
	black = P.material(Color("171c1c"),0.88)
	white = P.material(Color("c6c9b8"),0.3)
	red = P.material(Color("833b2d"),0.58,0.25)
	cup = Node3D.new()
	add_child(cup)
	cup.position = Vector3(-2.35,1.28,-3.7)
	P.cylinder(cup,Vector3(0,.065,0),.058,.13,white)
	P.torus(cup,Vector3(0,.132,0),.058,.004,P.material(Color("283d4b"),.3))
	P.cylinder(cup,Vector3(0,.134,0),.051,.003,black)
	var handle := P.torus(cup,Vector3(.067,.073,0),.036,.007,white)
	handle.rotation_degrees.x = 90
	lamp = Node3D.new()
	add_child(lamp)
	lamp.position = Vector3(4.5,.735,-3.4)
	P.cylinder(lamp,Vector3.ZERO,.15,.04,steel)
	P.cylinder(lamp,Vector3(0,.20,0),.015,.39,brass)
	P.cylinder(lamp,Vector3(0,.42,0),.21,.22,P.material(Color("b3b3a0"),.95),.11)
	P.cylinder(lamp,Vector3(0,.308,0),.195,.005,black)
	# Controls lie in the YZ plane with faces pointing toward -X.
	valve = valve_wheel(Vector3(2.50,1.85,-3.46),.17,red)
	P.label(valve,"↑",Vector3(0,.0,.055),36,.003).modulate = Color("ded5ba")
	collar = valve_wheel(Vector3(2.49,1.48,-3.46),.10,brass)
	bypass = valve_wheel(Vector3(2.49,1.13,-2.90),.11,red)
	var can_mat := P.material(Color(0.32,.42,.43,.40),.12,.25)
	can_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	P.cylinder(self,Vector3(2.62,.82,-2.9),.12,.35,can_mat)
	for y in [.64,.99]:
		P.cylinder(self,Vector3(2.62,y,-2.9),.135,.05,brass)
	hoses()
	cover = P.box(self,Vector3(2.48,1.52,-3.15),Vector3(.065,1.82,1.15),P.material(Color("34423e"),.75,.3))
	cover.visible = false
	# Engraved utility labels with room for readable controls.
	wall_label("方向",Vector3(2.46,2.12,-3.45),23)
	wall_label("锁环",Vector3(2.46,1.51,-3.67),16)
	wall_label("旁路",Vector3(2.46,1.33,-2.88),18)
	wall_label("回收罐",Vector3(2.45,.55,-2.89),17)
	wall_label("302  /  校准管网\n带载调向将影响相邻支路\n校准前接入回收旁路",Vector3(2.88,1.72,-4.24),22)
	var gauge_box := Node3D.new()
	gauge_box.position = Vector3(2.53,2.1,-2.88)
	gauge_box.rotation.y = -PI/2
	add_child(gauge_box)
	panel_needle = make_gauge(gauge_box,.105)
	add_target("manifold","总负载表","按住右键  测量负载",Vector3(2.39,2.1,-2.88),.13,"","manifold")
	add_target("direction","方向接头","按住左键转动  /  E 替代操作",Vector3(2.37,1.85,-3.46),.18,"calibrate","manifold",1.1)
	add_target("collar","接头锁环","按住左键操作  /  E 替代操作",Vector3(2.37,1.48,-3.46),.115,"collar","manifold",.75)
	add_target("bypass","红色旁路阀","按住左键开关  /  E 替代操作",Vector3(2.37,1.13,-2.90),.13,"bypass","manifold",.7)
	add_target("connect","旁路软管接口","E  连接引流软管",Vector3(2.42,1.23,-3.13),.12,"connect","manifold")
	var socket := P.cylinder(self,Vector3(2.54,1.23,-3.13),.044,.14,brass)
	socket.rotation.z = PI/2
	wall_label("接口",Vector3(2.43,1.06,-3.26),16)
	add_target("hose","引流软管","E  取下",Vector3(2.78,1.15,-2.09),.24,"hose","")
	add_target("cover","检修盖搭扣","E  封闭 / 打开检修盖",Vector3(2.39,1.60,-2.48),.12,"panel","")
	P.box(self,Vector3(2.58,1.60,-2.49),Vector3(.21,.13,.055),brass)
	wall_label("搭扣",Vector3(2.43,1.78,-2.48),16)
	add_target("tap","厨房水龙头","E  开关水龙头",Vector3(-2.7,1.06,-2.67),.17,"tap","kitchen")
	add_test_point("kitchen","厨房支路测试点",Vector3(-2.05,1.27,-2.28),0)
	add_test_point("living","客厅支路测试点",Vector3(4.85,1.03,-3.12),0)
	add_target("printer","值班打印机","E  查看工单",Vector3(-2.2,1.0,2.10),.30,"printer","")
	P.label(self,"检修站\n登记楼层  1 / 2 / 3",Vector3(-.72,1.72,2.86),28,.003)
	# Upward water is animated from the same pressure that the instrument reads.
	var water_mat := P.material(Color(0.64,.80,.90,.8),.13,.25)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.emission_enabled = true
	water_mat.emission = Color(.10,.15,.18)
	for i in range(70):
		var d := P.sphere(self,Vector3.ZERO,.008 + (i%3)*.002,water_mat,2.5)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drops.append(d)
	P.cylinder(self,Vector3(-2.53,3.135,-2.85),.055,.01,black)

func valve_wheel(pos: Vector3, radius: float, mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = -PI/2
	add_child(root)
	var rim := P.torus(root,Vector3.ZERO,radius,.014,mat)
	rim.rotation.x = PI/2
	var hub := P.cylinder(root,Vector3.ZERO,.038,.07,brass)
	hub.rotation.x = PI/2
	for i in range(4):
		var a := i*PI/2
		P.line(root,Vector3.ZERO,Vector3(cos(a)*radius,sin(a)*radius,0),.010,mat)
	return root

func hoses() -> void:
	hose_on_hook = Node3D.new()
	add_child(hose_on_hook)
	for i in range(28):
		var a := i*TAU/28
		var b := (i+1)*TAU/28
		P.line(hose_on_hook,Vector3(2.82,1.15+cos(a)*.23,-2.1+sin(a)*.17),Vector3(2.82,1.15+cos(b)*.23,-2.1+sin(b)*.17),.024,black)
	P.box(self,Vector3(2.88,1.44,-2.1),Vector3(.2,.03,.10),brass)
	hose_attached = Node3D.new()
	add_child(hose_attached)
	var points := [Vector3(2.53,1.23,-3.13),Vector3(2.22,1.10,-3.13),Vector3(2.24,.54,-3.10),Vector3(2.40,.47,-2.95),Vector3(2.58,.58,-2.9)]
	for i in range(points.size()-1):
		P.line(hose_attached,points[i],points[i+1],.023,black)
	for p in [points[0],points[-1]]:
		P.sphere(hose_attached,p,.034,brass)
	hose_attached.hide()

func wall_label(text: String, pos: Vector3, size: int) -> Label3D:
	var l := P.label(self,text,pos,size,.0024)
	l.rotation.y = -PI/2
	return l

func add_target(id: String, name_text: String, detail: String, pos: Vector3, radius: float, action: String, zone: String, duration: float = 0.0) -> void:
	var area := Area3D.new()
	area.name = "Target_" + id
	area.position = pos
	area.collision_layer = 2
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	area.add_child(collision)
	area.set_meta("target_id",id)
	add_child(area)
	targets[id] = area
	target_data[id] = {"name":name_text,"detail":detail,"action":action,"zone":zone,"duration":duration}

func add_test_point(id: String, title: String, pos: Vector3, rot: float) -> void:
	var stand := Node3D.new()
	stand.position = pos
	stand.rotation.y = rot
	add_child(stand)
	P.box(stand,Vector3.ZERO,Vector3(.15,.14,.035),brass)
	P.line(stand,Vector3(0,-.06,-.015),Vector3(-.08,-.28,-.03),.009,steel)
	P.box(stand,Vector3(-.08,-.28,-.03),Vector3(.12,.02,.11),black)
	var circle := P.cylinder(stand,Vector3(0,0,.025),.045,.025,black)
	circle.rotation.x = PI/2
	P.label(stand,"⊕",Vector3(0,0,.046),24,.002)
	P.label(stand,"厨房" if id == "kitchen" else "客厅",Vector3(0,.13,.02),22,.002)
	add_target(id,title,"按住右键  测量并记录",pos+Vector3(0,0,.07),.14,"",id)

func make_gauge(parent: Node3D, radius: float) -> Node3D:
	var casing := P.cylinder(parent,Vector3.ZERO,radius,.035,steel)
	casing.rotation.x = PI/2
	var face := P.cylinder(parent,Vector3(0,0,.023),radius*.89,.008,P.material(Color("c6c5ac"),.9))
	face.rotation.x = PI/2
	for i in range(13):
		var a := -PI*.75 + i*(PI*1.5/12)
		var a1 := Vector3(sin(a)*radius*.69,cos(a)*radius*.69,.030)
		var b := Vector3(sin(a)*radius*.83,cos(a)*radius*.83,.030)
		P.line(parent,a1,b,.0013,black)
	P.label(parent,"0      50     100",Vector3(0,-radius*.45,.034),16,radius*.009).modulate = Color("343c38")
	var pivot := Node3D.new()
	pivot.position.z = .035
	parent.add_child(pivot)
	P.line(pivot,Vector3.ZERO,Vector3(0,radius*.68,0),.0025,red)
	P.sphere(parent,Vector3(0,0,.038),.006,brass)
	return pivot

func setup_tools() -> void:
	tools_root = Node3D.new()
	player.camera.add_child(tools_root)
	gauge = Node3D.new()
	gauge.position = Vector3(-.29,-.28,-.49)
	gauge.rotation_degrees = Vector3(-8,10,5)
	gauge.scale = Vector3.ONE*.78
	tools_root.add_child(gauge)
	gauge_needle = make_gauge(gauge,.083)
	P.cylinder(gauge,Vector3(0,-.13,-.013),.026,.19,black)
	P.sphere(gauge,Vector3(0,-.105,.028),.05,black,.76)
	for i in range(4):
		P.sphere(gauge,Vector3(-.026+i*.017,-.102,.059),.012,black,1.7)
	P.cylinder(gauge,Vector3(0,-.23,-.03),.053,.17,P.material(Color("293940"),.95),.042)
	gauge_text = P.label(gauge,"302",Vector3(0,.012,.04),17,.0006)
	gauge_text.modulate = Color("3b4945")
	wrench = Node3D.new()
	wrench.position = Vector3(.34,-.31,-.54)
	wrench.rotation_degrees = Vector3(-8,-15,-27)
	wrench.scale = Vector3.ONE*.72
	tools_root.add_child(wrench)
	wrench.add_child(load("res://assets/models/wrench.glb").instantiate())
	P.sphere(wrench,Vector3(0,-.053,.028),.05,black,.9)
	for i in range(4):
		P.sphere(wrench,Vector3(-.028+i*.017,-.045,.057),.012,black,1.8)
	P.cylinder(wrench,Vector3(.004,-.18,.015),.051,.19,P.material(Color("293940"),.95),.043)
	var tool_light := OmniLight3D.new()
	tool_light.position = Vector3(0,.05,-.12)
	tool_light.light_energy = .23
	tool_light.omni_range = .8
	tool_light.light_color = Color("b0c0c6")
	tools_root.add_child(tool_light)
	tools_root.hide()

func setup_audio() -> void:
	sound_fx = AudioStreamPlayer.new()
	add_child(sound_fx)
	rain_audio = loop_audio("rain",-13)
	room_audio = loop_audio("room_tone",-15)
	water_audio = spatial_loop("water",Vector3(-2.53,2.0,-2.85),-7)
	drain_audio = spatial_loop("drain",Vector3(2.58,.82,-2.9),-80)

func loop_stream(name: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load("res://assets/audio/"+name+".wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	return stream

func loop_audio(name: String, db: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = loop_stream(name)
	a.volume_db = db
	add_child(a)
	a.play()
	return a

func spatial_loop(name: String, pos: Vector3, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = loop_stream(name)
	a.position = pos
	a.volume_db = db
	a.max_distance = 12
	add_child(a)
	a.play()
	return a

func play_fx(name: String, db: float = -8) -> void:
	sound_fx.stream = load("res://assets/audio/"+name+".wav")
	sound_fx.volume_db = db
	sound_fx.play()

func start_game(continue_save: bool) -> void:
	state = State.new()
	player.position = Vector3(0,.08,2.1)
	player.rotation = Vector3.ZERO
	player.pitch = 0
	player.camera.rotation = Vector3.ZERO
	if continue_save and FileAccess.file_exists(save_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary and data.get("repair") is Dictionary and state.restore(data.repair):
			var saved_position = data.get("position",[0,0.08,2.1])
			if saved_position is Array and saved_position.size() == 3 and numeric(saved_position[0]) and numeric(saved_position[2]):
				player.position = Vector3(clampf(float(saved_position[0]),-2.7,6.7),0.08,clampf(float(saved_position[2]),-4.7,2.7))
			player.rotation.y = float(data.get("yaw",0)) if numeric(data.get("yaw",0)) else 0.0
			player.pitch = clampf(float(data.get("pitch",0)),-78,78) if numeric(data.get("pitch",0)) else 0.0
			player.camera.rotation_degrees.x = player.pitch
	started = true
	player.camera.current = true
	resume_game()
	ui.toast("302 室 · 水不往下流。按 Tab 查看工单。右键抬起检修仪。",8)
	play_fx("printer")
	save_game()

func resume_game() -> void:
	paused = false
	player.active = true
	player.operating = false
	ui.show_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause_game() -> void:
	paused = true
	player.active = false
	hold_time = 0
	hold_target = ""
	player.operating = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_menu(true,true)
	save_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		capture("user://screenshot.png")
	if event.is_action_pressed("pause_game") and started:
		if paused: resume_game()
		else: pause_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ticket") and started:
		if ui.ticket.visible:
			resume_game()
		elif not paused:
			paused = true
			player.active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			ui.show_ticket(state)
		get_viewport().set_input_as_handled()
	if paused:
		return
	if event.is_action_pressed("hint"):
		ui.toast(state.next_hint(),9)
	if event.is_action_pressed("interact") and target:
		execute(target.get_meta("target_id"))
	if event is InputEventMouseMotion and not hold_target.is_empty():
		hold_time += minf(absf(event.relative.x)*.0012,.05)

func execute(id: String) -> void:
	var data: Dictionary = target_data[id]
	if data.action == "printer":
		if state.completed:
			paused = true
			player.active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			ui.show_ending()
			play_fx("printer")
		else:
			paused = true
			player.active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			ui.show_ticket(state)
		return
	if data.action.is_empty():
		ui.toast("按住右键，用检修仪测量此接点。")
		return
	var message := state.act(data.action)
	ui.toast(message)
	play_fx("ratchet" if data.duration > 0 else "click")
	save_game()

func submit() -> void:
	var message := state.act("submit")
	resume_game()
	ui.toast(message,10)
	play_fx("printer")
	save_game()

func _process(delta: float) -> void:
	time += delta
	if started and not paused:
		state.tick(delta)
		update_target(delta)
		save_clock += delta
		if save_clock > 3:
			save_clock = 0
			save_game()
	update_visuals(delta)
	if not screenshot_path.is_empty():
		screenshot_clock += delta
		if screenshot_clock > 3:
			var path := screenshot_path
			screenshot_path = ""
			await capture(path)
			request_quit()

func stop_audio() -> void:
	for audio in [sound_fx,rain_audio,room_audio,water_audio,drain_audio]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null

func request_quit() -> void:
	if exiting: return
	exiting = true
	save_game()
	set_process(false)
	stop_audio()
	# Allow the audio mixing thread to release its playback references before exit.
	await get_tree().create_timer(.10).timeout
	get_tree().quit()

func _exit_tree() -> void:
	stop_audio()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		request_quit()

func update_target(delta: float) -> void:
	var cam := player.camera
	var from := cam.global_position
	var end := from - cam.global_basis.z*2.3
	var query := PhysicsRayQueryParameters3D.create(from,end,3)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	target = hit.collider if not hit.is_empty() and hit.collider is Area3D else null
	var id := str(target.get_meta("target_id")) if target else ""
	if state.panel_closed and id in ["manifold","direction","collar","bypass","connect"]:
		id = "cover"
		target = targets.cover
	if id == "hose" and state.hose_taken:
		id = ""
		target = null
	ui.interaction.text = target_data[id].name if target else ""
	var interact_key := OS.get_keycode_string(InputMap.action_get_events("interact")[0].physical_keycode)
	ui.interaction_detail.text = (target_data[id].detail if target else "右键  检修仪     E  交互").replace("E",interact_key)
	ui.reticle.modulate = Color("c99a53") if target else Color("d4d8d0")
	var measuring := Input.is_action_pressed("measure")
	var zone := str(target_data[id].zone) if target else ""
	if measuring:
		if measured_target != id:
			measured_target = id
			measure_time = 0
		measure_time += delta
		if measure_time > .65 and not zone.is_empty():
			ui.diagnostic.text = state.measure(zone)
		else:
			ui.diagnostic.text = "接点读数稳定中…" if not zone.is_empty() else "未连接测试点 · 靠近并对准圆形接点"
	else:
		measured_target = ""
		measure_time = 0
		ui.diagnostic.text = ""
	if Input.is_action_pressed("operate") and target and float(target_data[id].duration) > 0 and not measuring:
		if hold_target != id:
			hold_target = id
			hold_time = 0
		hold_time += delta
		player.operating = true
		ui.progress.show()
		ui.progress.value = minf(1,hold_time/float(target_data[id].duration))
		if hold_time >= float(target_data[id].duration):
			execute(id)
			hold_time = -1000 # One action per press; releasing rearms it.
	else:
		hold_target = ""
		hold_time = 0
		player.operating = false
		ui.progress.hide()

func update_visuals(delta: float) -> void:
	ui.location_label.text = "南楼 / 03 层\n" + ("302 · 已验收" if state.completed else ("客厅 · 相邻支路" if player.position.x > 3 and player.position.z < 1 else ("公共走廊 · 值班区" if player.position.z > 1 else "302 · 厨房")))
	var k := state.kitchen_strength()
	var l := state.living_strength()
	cup.position.y = lerpf(cup.position.y,.944 + .37*k + sin(time*1.4)*.018*k,1-exp(-5*delta))
	cup.rotation.z = sin(time*.9)*.045*k
	lamp.position.y = lerpf(lamp.position.y,.735+.50*l+sin(time*1.1)*.012*l,1-exp(-5*delta))
	lamp.rotation.z = sin(time*.7)*.035*l
	if last_kitchen > .01 and k <= .01:
		play_fx("cup",-12)
	last_kitchen = k
	valve.rotation.z = lerp_angle(valve.rotation.z,PI if state.calibrated else 0.0,delta*5)
	collar.rotation.z = lerp_angle(collar.rotation.z,0.0 if state.collar_locked else PI*.4,delta*6)
	bypass.rotation.z = lerp_angle(bypass.rotation.z,PI*.5 if state.bypass_open else 0.0,delta*5)
	cover.visible = state.panel_closed
	hose_on_hook.visible = not state.hose_taken
	hose_attached.visible = state.hose_connected
	panel_needle.rotation.z = deg_to_rad(125-250*state.pressure)
	var measuring := not paused and Input.is_action_pressed("measure")
	gauge.position = gauge.position.lerp(Vector3(-.23,-.10,-.42) if measuring else Vector3(-.29,-.30,-.49),1-exp(-8*delta))
	gauge_needle.rotation.z = lerp_angle(gauge_needle.rotation.z,deg_to_rad(125-250*state.pressure),delta*6)
	gauge_text.text = "%02d%%" % roundi(state.pressure*100) if measuring and target_data.has(measured_target) and not target_data[measured_target].zone.is_empty() else "302"
	wrench.rotation.z = deg_to_rad(-27)+sin(time*25)*.06 if player.operating else deg_to_rad(-27)
	tools_root.visible = started and not ui.menu.visible and not ui.ticket.visible and not ui.settings_panel.visible
	for i in range(drops.size()):
		var drop := drops[i]
		drop.visible = state.faucet_on
		var phase := fposmod(float(i)/drops.size()+time*(.6 if k > .02 else -1.8),1.0)
		if k > .02:
			drop.position = Vector3(-2.53+sin(phase*PI)*.035, .73+phase*2.37,-2.85+sin(phase*9)*.012)
		else:
			drop.position = Vector3(-2.57,.72+phase*.47,-2.83)
	water_audio.volume_db = -9 if state.faucet_on else -80
	water_audio.position.y = 2.2 if k > .02 else .95
	drain_audio.volume_db = -9 if state.bypass_open and state.pressure > 0 else -80

func save_game() -> void:
	if not started or not inspection_mode.is_empty():
		return
	var data := {"repair":state.serialize(),"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"pitch":player.pitch}
	# Write temp first to keep a previous valid save if interrupted during serialization.
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		DirAccess.rename_absolute(save_path+".tmp",save_path)

func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if data is Dictionary:
			for key in data:
				if (settings.has(key) or str(key).begins_with("binding:")) and (numeric(data[key]) or data[key] is bool):
					settings[key] = data[key]
	for key in settings.keys():
		apply_setting(key,settings[key],false)
	ui.sync_settings(settings)

func apply_setting(key: String, value: Variant, persist: bool = true) -> void:
	settings[key] = value
	match key:
		"sensitivity": player.sensitivity = clampf(float(value),.025,.2)
		"fov": player.camera.fov = clampf(float(value),60,95)
		"head_bob": player.head_bob = bool(value)
		"brightness": environment.adjustment_brightness = clampf(float(value),.8,1.6)
		"volume": AudioServer.set_bus_volume_db(0,linear_to_db(clampf(float(value),0,1)))
	if key.begins_with("binding:"):
		var action := key.trim_prefix("binding:")
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			var event := InputEventKey.new()
			event.physical_keycode = int(value)
			InputMap.action_add_event(action,event)
	if persist:
		var file := FileAccess.open(settings_path,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(settings))

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",path," ",error," FPS ",Engine.get_frames_per_second())
