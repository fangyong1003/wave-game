class_name SurvivalLoot
extends Area3D
const P = preload("res://scripts/props.gd")
const Items = preload("res://scripts/survival/items.gd")
var item: Dictionary = {}
var loot_id := ""
var container_id := ""
var visual: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	set_meta("loot",true)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .15 if item.id in ["water","can","bar","bottle"] else .22
	collision.shape = shape
	collision.position.y = .07
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	build_visual(visual,str(item.id))
	if item.get("melee_upgrade",false): decorate_upgrade(visual.get_child(0),item)

func set_available(value: bool) -> void:
	visible = value
	collision_layer = 2 if value else 0

static func build_visual(parent: Node3D, id: String) -> void:
	var dark := P.material(Color("25342f"),.8)
	var paper := P.material(Color("c5c4ad"),.9)
	var metal := P.material(Color("8b9290"),.35,.7)
	match id:
		"water","bottle":
			var bottle_mat := P.material(Color("526a65") if id=="water" else Color("66755a"),.25,.12)
			P.cylinder(parent,Vector3(0,.09,0),.036,.18,bottle_mat)
			P.cylinder(parent,Vector3(0,.19,0),.023,.035,bottle_mat,.014)
			P.cylinder(parent,Vector3(0,.218,0),.016,.022,dark)
			if id=="water":
				P.cylinder(parent,Vector3(0,.098,0),.037,.065,paper)
				P.label(parent,"水",Vector3(0,.10,.039),23,.0012).modulate = Color("283e43")
		"can":
			P.cylinder(parent,Vector3(0,.065,0),.052,.13,metal)
			P.cylinder(parent,Vector3(0,.062,0),.053,.09,P.material(Color("885342"),.7))
			P.torus(parent,Vector3(0,.133,0),.047,.003,metal)
			P.label(parent,"午餐肉",Vector3(0,.067,.055),19,.0009)
		"bar":
			P.box(parent,Vector3(0,.025,0),Vector3(.12,.04,.055),P.material(Color("ada05c"),.6))
			P.box(parent,Vector3(0,.047,0),Vector3(.075,.004,.040),paper)
		"wrench","bat","crossbow","pistol":
			var model: Node3D = load("res://assets/models/wrench.glb" if id=="wrench" else "res://assets/survival/"+id+".glb").instantiate()
			parent.add_child(model)
			model.rotation_degrees.x = 90
			model.position.y = .035
			model.position.z = -.10
		"bolts","pistol_ammo":
			P.box(parent,Vector3(0,.07,0),Vector3(.24,.14,.14),dark)
			P.box(parent,Vector3(0,.145,0),Vector3(.20,.01,.10),paper)
			P.label(parent,"弩箭" if id=="bolts" else "9 mm",Vector3(0,.08,.075),20,.0014)
		"coat":
			var cloth := P.material(Color("495a4b"),.95)
			P.box(parent,Vector3(0,.055,0),Vector3(.33,.11,.27),cloth)
			P.box(parent,Vector3(0,.115,0),Vector3(.012,.005,.24),metal)
			for x in [-.10,.10]: P.box(parent,Vector3(x,.12,.055),Vector3(.07,.008,.08),dark)
		"shoes":
			for x in [-.065,.065]:
				P.sphere(parent,Vector3(x,.06,0),.065,dark,.75).scale.z = 1.7
				P.box(parent,Vector3(x,.018,0),Vector3(.10,.025,.23),paper)
				for z in [-.04,-.01,.02]: P.line(parent,Vector3(x-.03,.105,z),Vector3(x+.03,.105,z),.003,paper)
		"pack":
			var cloth := P.material(Color("726b46"),.92)
			P.box(parent,Vector3(0,.17,0),Vector3(.30,.34,.18),cloth)
			P.box(parent,Vector3(0,.13,.11),Vector3(.22,.16,.06),dark)
			for x in [-.10,.10]: P.line(parent,Vector3(x,.04,-.11),Vector3(x,.30,-.11),.018,dark)

static func decorate_upgrade(parent: Node3D,item: Dictionary) -> void:
	if not item.get("melee_upgrade",false): return
	var wrap:=P.material(Color("71664b"),.90)
	var metal:=P.material(Color("6d7470"),.40,.7)
	if item.id=="bat":
		for y in [.39,.46,.57]: P.cylinder(parent,Vector3(0,y,0),.044,.030,metal)
		for i in range(6): P.cylinder(parent,Vector3(0,-.07+i*.023,0),.019,.018,wrap)
	elif item.id=="wrench":
		for i in range(7): P.box(parent,Vector3(0,-.085+i*.023,0),Vector3(.044,.018,.031),wrap)

func serialize() -> Dictionary:
	return {"id":loot_id,"item":item.duplicate(true),"container":container_id,"position":[position.x,position.y,position.z]}
