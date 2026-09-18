class_name SurvivalDistrict
extends RefCounted
const P=preload("res://scripts/props.gd")
const ARRIVAL=Vector3(-12,.04,-13.5)
const EXIT=Vector3(-12,1.35,-15.45)
const ENEMIES=[
	["street-courtyard",Vector3(-7,.04,-12),PI/2],
	["street-crossing",Vector3(1,.04,1),PI],
	["street-market",Vector3(-18,.04,-2),PI],
	["street-market-rear",Vector3(-14,.04,-9),-PI/2],
	["street-clinic",Vector3(16,.04,-8),PI],
	["street-garage",Vector3(19,.04,13),0.0],
	["street-mechanic",Vector3(8,.04,9),PI/2],
	["street-alley",Vector3(-6,.04,18),PI]
]
const CONTAINERS=[
	["street-market-shelf","便利店货架",Vector3(-21.55,1.10,-3),Vector3(.8,.6,.9),["water","can","bar"]],
	["street-market-stock","便利店后仓",Vector3(-10.5,.40,-5.5),Vector3(.94,.85,.80),["water","can","bottle"]],
	["street-clinic-kit","诊所应急箱",Vector3(18.98,1.02,-11),Vector3(.8,.5,.85),["water","bar","can"]],
	["street-clinic-bag","诊所遗留背包",Vector3(8.5,.28,-6.5),Vector3(.8,.6,.65),["pack","coat"]],
	["street-garage-tools","修车库工具箱",Vector3(21.10,1.07,13),Vector3(.8,.5,.9),["wrench","bat","bottle"]],
	["street-garage-locker","修车库工作柜",Vector3(11.46,1.05,15.7),Vector3(.5,.8,.8),["coat","shoes"]],
	["street-courtyard-box","院落应急储备",Vector3(-18,.40,-11.5),Vector3(1.1,.9,.9),["water","bar"]],
	["street-alley-cache","背巷行李箱",Vector3(-4,.35,18),Vector3(.9,.8,.75),["pack","water"]]
]

static func furnish(world: Node3D) -> void:
	world.target("travel:apartment",EXIT,.50,"南楼楼梯 · 返回三层 / 安全屋")
	for row in [
		["南 楼",Vector3(-12,2.3,-15.54),0.0,29,.008],
		["南街便利店",Vector3(-16,2.96,3.24),0.0,38,.014],
		["临时诊所",Vector3(14,2.98,-3.76),0.0,34,.012],
		["汽车维修",Vector3(16.5,2.98,17.25),0.0,32,.012],
		["修车库 · 后门",Vector3(16,2.82,5.76),PI,26,.008],
		["便利店后仓",Vector3(-12,2.76,-7.25),PI,26,.008],
		["道路封闭",Vector3(0,1.7,21.24),PI,35,.012],
		["隔离区边界",Vector3(0,1.8,-21.24),0.0,30,.013]
	]:
		var sign_text:=P.label(world,row[0],row[1],row[3],row[4]);sign_text.rotation.y=row[2]
	for row in [[Vector3(-12,2.6,-14.7),Color("d5c09a"),1.1,5.0],[Vector3(-17,2.8,2.6),Color("b1c8c1"),1.3,7.0],[Vector3(14,2.8,-9),Color("adceca"),1.4,8.0],[Vector3(17,2.8,12),Color("d0b485"),1.5,8.0]]:
		world.omni(row[0],row[1],row[2],row[3],false)
	for z in [-12,0,15]: world.omni(Vector3(7.2,4.65,z),Color("ddc899"),.8,8,false)
	world.environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("36434c");sky_mat.sky_horizon_color=Color("76868b")
	sky_mat.ground_bottom_color=Color("222d32");sky_mat.ground_horizon_color=Color("818f91")
	sky_mat.sky_curve=.6;sky.sky_material=sky_mat;world.environment.sky=sky
	world.environment.ambient_light_energy=.37
	world.environment.fog_density=.003
	world.environment.fog_light_color=Color("677a80")

static func room_name(pos: Vector3) -> String:
	if pos.x<-9 and pos.z>-7 and pos.z<3: return "南街便利店"
	if pos.x>7 and pos.z>-14 and pos.z<-4: return "临时诊所"
	if pos.x>10 and pos.z>6 and pos.z<17: return "南街修车库"
	if pos.z<-9 and pos.x<-6: return "南楼院落"
	if pos.z>17 or pos.x<-23 or pos.x>23: return "南街背巷"
	return "南街 · 隔离街区"
