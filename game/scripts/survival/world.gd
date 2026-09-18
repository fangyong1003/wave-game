class_name SurvivalWorld
extends Node3D
const P = preload("res://scripts/props.gd")
const District=preload("res://scripts/survival/district.gd")
const REGION_ASSETS={"apartment":"res://assets/survival/south_block.glb","district":"res://assets/survival/south_district.glb"}
var region: String="apartment"
var game: Node3D
var architecture: Node3D
var environment: Environment
var boxes: Array = []
var map_bounds:=Rect2()
var doors := {}
var targets := {}
var key_visual: Node3D

func _ready() -> void:
	build_region("apartment")
func build_region(id: String,model: PackedScene=null) -> void:
	# Called only while simulation is suspended, never from a physics callback.
	for child in get_children(): child.free()
	boxes.clear();doors.clear();targets.clear();key_visual=null
	region=id if REGION_ASSETS.has(id) else "apartment"
	architecture=(model if model!=null else load(REGION_ASSETS[region])).instantiate()
	add_child(architecture)
	game.age_materials(architecture)
	for obj in architecture.find_children("*","MeshInstance3D",true,false):
		if "window" in obj.name.to_lower() or "diffuser" in obj.name.to_lower(): obj.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var layout_path: String="res://assets/survival/district_collision.json" if region=="district" else "res://assets/survival/collision_layout.json"
	var layout: Array=JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	for entry in layout:
		var pos:=Vector3(entry.pos[0],entry.pos[1],entry.pos[2])
		var size:=Vector3(entry.size[0],entry.size[1],entry.size[2])
		boxes.append({"pos":pos,"size":size})
		var body:=box_body(self,pos,size)
		body.set_meta("surface","wood" if size.y<1.2 and pos.y>.15 else "stone")
	map_bounds=SurvivalNavigation.floor_bounds(boxes)
	environment=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("798d97")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("a5b8c1")
	environment.ambient_light_energy=.33
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.0
	environment.adjustment_enabled=true
	environment.adjustment_brightness=clampf(game.safe_number(game.settings.get("brightness"),1.05),.8,1.6)
	environment.adjustment_contrast=1.08
	environment.adjustment_saturation=.78
	environment.fog_enabled=true
	environment.fog_density=.007
	environment.fog_light_color=Color("6c8385")
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":
		environment.ssao_enabled=true
		environment.ssao_intensity=1.3
		environment.ssil_enabled=true
		environment.ssil_intensity=.55
	var env:=WorldEnvironment.new();env.environment=environment;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-75,0);sun.light_color=Color("b3c7d6");sun.light_energy=.22;sun.shadow_enabled=true;add_child(sun)
	if region=="district":
		sun.light_energy=.40;sun.rotation_degrees=Vector3(-53,-24,0)
		District.furnish(self)
		return
	build_stair_entry()
	omni(Vector3(-2.5,2.2,-2.6),Color("b5c8d2"),1.10,5.7)
	omni(Vector3(-2.3,2.0,-4),Color("d0dcd6"),.33,2.3,false)
	omni(Vector3(2.4,2.2,-3.1),Color("ffd09d"),.54,2.8)
	omni(Vector3(5.0,2.8,-2.5),Color("a9bec5"),.85,4.1)
	omni(Vector3(4.8,2.9,4.7),Color("bfbea4"),.75,3.6)
	for x in [-1.8,1.6,5.3]: omni(Vector3(x,2.9,2),Color("aec4bf"),.44,3.3,false)
	omni(Vector3(-2.5,2.2,2.0),Color("cde4ba"),.38,2.0,false)
	create_door("cabinet","Dynamic_KitchenCabinet",Vector3(.03,.375,.34),Vector3(.04,.75,.67),"厨房储物柜",false)
	create_door("living","Dynamic_LivingDoor",Vector3(.69,1.2,0),Vector3(1.38,2.4,.065),"客厅木门",false)
	create_door("locker","Dynamic_GlassLocker",Vector3(.47,.89,-.01),Vector3(.90,1.76,.03),"上锁储物柜",true)
	create_door("unit304","Dynamic_Unit304",Vector3(.75,1.2,0),Vector3(1.5,2.4,.065),"304 住户门",false)
	create_door("utility","Dynamic_Utility",Vector3(.75,1.2,0),Vector3(1.5,2.4,.065),"物业库房门",false)
	var safe:=target("safe",Vector3(-2.83,1.15,2.1),.46,"安全屋 · 撤回入库")
	safe.set_meta("surface","metal")
	var safe_body:=box_body(self,Vector3(-2.977,1.18,2.15),Vector3(.065,2.36,1.23))
	safe_body.set_meta("surface","metal")
	var warning:=P.label(self,"303 / 储物间",Vector3(4.14,2.55,2.97),24,.003)
	warning.rotation.y=PI
	key_visual=Node3D.new();key_visual.position=Vector3(4.52,.742,-3.22);add_child(key_visual)
	var key_mat:=P.material(Color("bc9e5a"),.4,.7)
	P.torus(key_visual,Vector3.ZERO,.025,.006,key_mat)
	P.line(key_visual,Vector3(0,0,.02),Vector3(0,0,.095),.006,key_mat)
	P.box(key_visual,Vector3(.012,0,.081),Vector3(.025,.01,.014),key_mat)
	target("key",key_visual.position+Vector3.UP*.045,.14,"储物柜钥匙")
	# Normal domestic details replace the old anomaly actors.
	var lamp_mat:=P.material(Color("b8b5a0"),.9)
	P.cylinder(self,Vector3(4.5,.75,-3.4),.15,.05,key_mat)
	P.cylinder(self,Vector3(4.5,.97,-3.4),.015,.40,key_mat)
	P.cylinder(self,Vector3(4.5,1.18,-3.4),.20,.22,lamp_mat,.11)
	P.cylinder(self,Vector3(-2.35,1.01,-3.7),.055,.14,lamp_mat)
	# Supplies now live inside searchable containers, never as unsolicited floor drops.
	var carton:=P.material(Color("796f4f"),.96)
	P.box(self,Vector3(-2.24,1.075,-4.28),Vector3(.46,.27,.52),carton)
	P.box(self,Vector3(-2.24,1.214,-4.28),Vector3(.10,.01,.54),P.material(Color("beb795"),.94))
	var box_mat:=P.material(Color("3c5149"),.86)
	P.box(self,Vector3(1.85,.18,.43),Vector3(.58,.34,.44),box_mat)
	P.box(self,Vector3(1.85,.355,.43),Vector3(.6,.035,.46),box_mat)
	for x in [1.65,2.05]: P.box(self,Vector3(x,.22,.191),Vector3(.025,.10,.015),key_mat)
	for x in [8.4,11.6,14.0,16.5]: omni(Vector3(x,2.85,2.05),Color("b7c6bf"),.52,3.0,false)
	omni(Vector3(9.6,2.50,-3.0),Color("abbfc9"),.90,4.3)
	omni(Vector3(15.0,2.55,-2.5),Color("becfc8"),1.05,4.2)
	omni(Vector3(9.6,2.65,5.1),Color("b5c9c5"),.87,3.8)
	omni(Vector3(15.1,2.62,4.8),Color("dfbe94"),.90,3.7)
	for entry in [[Vector3(8.05,1.85,1.18),"304 / 住户",0.0],[Vector3(14.05,1.85,1.18),"305 / 临时医务室",0.0],[Vector3(11.7,1.85,2.98),"公共洗衣房",PI],[Vector3(16.6,1.85,2.98),"物业库房",PI]]:
		var sign_text:=P.label(self,entry[1],entry[0]+Vector3(0,0,.018 if entry[2]==0 else -.018),22,.0027)
		sign_text.rotation.y=entry[2]
	P.box(self,Vector3(9.42,.94,5.812),Vector3(.36,.20,.012),P.material(Color("bfc0a7"),.96))
	var notice:=P.label(self,"停水\n禁止启动",Vector3(9.42,.94,5.800),18,.0017);notice.rotation.y=PI;notice.modulate=Color("34443d")


func build_stair_entry() -> void:
	# The third floor and street have separate local origins, joined by the stairwell.
	var paint:=P.material(Color("334e47"),.8)
	P.box(self,Vector3(17.035,1.22,2.08),Vector3(.065,2.44,1.55),paint)
	P.box(self,Vector3(16.99,1.30,2.08),Vector3(.035,1.9,1.28),P.material(Color("233731"),.9))
	P.line(self,Vector3(16.93,1.02,1.63),Vector3(16.93,1.27,1.63),.025,P.material(Color("a9aca2"),.5,.6))
	target("travel:district",Vector3(16.86,1.25,2.08),.48,"楼梯间 · 下楼探索南街")

func omni(pos: Vector3,color: Color,energy: float,reach: float,shadows: bool=true) -> void:
	var light:=OmniLight3D.new();light.position=pos;light.light_color=color;light.light_energy=energy;light.omni_range=reach;light.omni_attenuation=1.5;light.shadow_enabled=shadows;light.light_size=.13;light.shadow_bias=.035;add_child(light)
func create_loot_bag(parent: Node3D) -> void:
	var mat:=P.material(Color("6d7156"),.97)
	P.box(parent,Vector3.ZERO,Vector3(.31,.20,.26),mat)
	P.line(parent,Vector3(-.10,.11,0),Vector3(.10,.11,0),.012,P.material(Color("262c27"),.95))
func box_body(parent: Node3D,pos: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();body.position=pos;body.collision_layer=1
	var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;col.shape=shape;body.add_child(col);parent.add_child(body)
	return body
func target(id: String,pos: Vector3,radius: float,caption: String) -> Area3D:
	var area:=Area3D.new();area.position=pos;area.collision_layer=2;area.collision_mask=0
	var col:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=radius;col.shape=sphere;area.add_child(col);add_child(area)
	area.set_meta("interaction",id);area.set_meta("caption",caption)
	targets[id]=area
	return area
func create_door(id: String,node_name: String,center: Vector3,size: Vector3,caption: String,locked: bool) -> void:
	var pivot: Node3D=architecture.find_child(node_name,true,false)
	assert(pivot!=null,"Missing authored pivot "+node_name)
	var body:=box_body(pivot,center,size)
	body.set_meta("interaction",id);body.set_meta("caption",caption);body.set_meta("surface","glass" if locked else "wood")
	var area:=Area3D.new();area.position=center;area.collision_layer=2;area.collision_mask=0
	var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size+Vector3(.06,.04,.06);col.shape=shape;area.add_child(col);pivot.add_child(area)
	area.set_meta("interaction",id);area.set_meta("caption",caption)
	doors[id]={"node":pivot,"body":body,"area":area,"center":center,"size":size,"open":false,"hp":65.0 if locked else 100.0,"busy":false,"locked":locked,"open_angle":-PI*.48 if id=="utility" else PI*.48}
	targets[id]=area
func reset(saved: Dictionary={}) -> void:
	for id in doors:
		var d: Dictionary=doors[id]
		var data: Dictionary=saved.get(id,{}) if saved.get(id,{}) is Dictionary else {}
		d.open=bool(data.get("open",false));d.hp=game.safe_number(data.get("hp"),65.0 if id=="locker" else 100.0);d.busy=false
		d.node.rotation.y=d.open_angle if d.open and id!="locker" else 0.0
		d.node.visible=not (id=="locker" and d.open)
		d.body.collision_layer=0 if id=="locker" and d.open else 1
		d.area.collision_layer=0 if id=="locker" and d.open else 2
	if is_instance_valid(key_visual): key_visual.visible=not game.state.has_key
	if targets.has("key"): targets.key.collision_layer=0 if game.state.has_key else 2
func interact(id: String) -> String:
	if id=="key":
		game.state.has_key=true;key_visual.hide();targets.key.collision_layer=0
		game.save_game()
		return "获得储物柜钥匙。"
	if not doors.has(id): return ""
	var d: Dictionary=doors[id]
	if d.busy: return "门正在移动。"
	if id=="locker":
		if d.open: return "储物柜已打开。"
		if not game.state.has_key: return "柜门已锁。"
		open_locker()
		return "储物柜已解锁。"
	if d.open and id in ["living","unit304","utility"]:
		for actor in [game.player]+game.enemies:
			if not is_instance_valid(actor) or (actor is SurvivalEnemy and actor.health<=0): continue
			var pos: Vector3=actor.global_position-d.node.global_position
			if pos.x>-.30 and pos.x<d.size.x+.30 and absf(pos.z)<.38: return "门被挡住了。"
	d.open=not d.open;d.busy=true
	game.play_sound("door",d.node.global_position,-12)
	game.emit_noise(d.node.global_position,3.0)
	var tween:=create_tween()
	tween.tween_property(d.node,"rotation:y",d.open_angle if d.open else 0.0,.38).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(func():
		d.busy=false
		game.refresh_world()
		game.save_game())
	return "已打开。" if d.open else "已关上。"
func strike(id: String,damage: float) -> bool:
	if id!="locker" or doors.locker.open: return false
	doors.locker.hp-=damage
	if doors.locker.hp<=0:
		open_locker(true)
		game.emit_noise(doors.locker.node.global_position,13)
		game.ui.toast("玻璃已破碎。")
	else: game.ui.toast("玻璃出现裂痕。",2)
	return true
func open_locker(broken: bool=false) -> void:
	var d: Dictionary=doors.locker
	d.open=true;d.node.hide();d.body.collision_layer=0;d.area.collision_layer=0
	game.play_sound("hit_glass" if broken else "door",d.node.global_position,-8 if broken else -18)
	game.refresh_world()
	game.save_game()
func is_open(id: String) -> bool: return id.is_empty() or (doors.has(id) and doors[id].open)
func obstacles() -> Array:
	var result: Array=boxes.duplicate()
	for id in doors:
		var d: Dictionary=doors[id]
		if d.body.collision_layer==0: continue
		var basis: Basis=d.body.global_basis
		var size: Vector3=d.size
		var extents:=basis.x.abs()*size.x+basis.y.abs()*size.y+basis.z.abs()*size.z
		result.append({"pos":d.body.global_position,"size":extents})
	return result
func serialize() -> Dictionary:
	var out: Dictionary={}
	for id in doors: out[id]={"open":doors[id].open,"hp":doors[id].hp}
	return out
