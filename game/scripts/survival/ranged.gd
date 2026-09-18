class_name SurvivalRanged
extends Node3D
const P=preload("res://scripts/props.gd")
const Items=preload("res://scripts/survival/items.gd")
var game: Node3D
var combat: Node3D
var aiming:=false
var reload_uid: String=""
var flash: Node3D
var flash_time:=0.0
var bolts: Array[Dictionary]=[]
var sight_amount:=0.0
var bow_lines: Array[MeshInstance3D]=[]

func _ready() -> void:
	flash=Node3D.new();combat.weapon_root.add_child(flash)
	var mat:=P.material(Color("eac985"),.4)
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.emission_enabled=true;mat.emission=Color("ffca79")
	var flare:=P.cylinder(flash,Vector3(0,0,-.055),.027,.11,mat,0);flare.rotation.x=PI/2
	var glow:=OmniLight3D.new();glow.light_color=Color("ffc37e");glow.light_energy=1.4;glow.omni_range=2.3;flash.add_child(glow);flash.hide()
func equipped() -> bool: return game.state.weapon().get("ranged",false)
func muzzle_local() -> Vector3: return Vector3(0,.132,-.51) if combat.shown_weapon=="crossbow" else Vector3(0,.10,-.22)
func rest_pose() -> Array[Vector3]:
	var hip:=Vector3(.23,-.24,-.56) if combat.shown_weapon=="crossbow" else Vector3(.22,-.22,-.50)
	var sight:=Vector3(0,-.174,-.46) if combat.shown_weapon=="crossbow" else Vector3(0,-.145,-.50)
	return [hip.lerp(sight,sight_amount),Vector3.ZERO]
func stop_aim() -> void:
	aiming=false;sight_amount=0
	if is_instance_valid(game.player): game.player.camera.fov=clampf(game.safe_number(game.settings.get("fov"),74),60,95)
func cancel() -> void:
	reload_uid="";flash_time=0
	if is_instance_valid(flash): flash.hide()
	stop_aim()
func reload() -> bool:
	if not equipped() or combat.busy() or game.state.phase!="run" or game.ui.view!="game" or game.suspended: return false
	var data: Dictionary=game.state.weapon();var gun: Dictionary=game.state.equipment.primary
	if int(gun.get("loaded",0))>=int(data.magazine): game.ui.toast("已装满。",2);return false
	if game.state.ammo_count(data.ammo)<=0: game.ui.toast("背包里没有对应弹药。",2);game.play_sound("dry_fire",game.player.position,-17);return false
	game.cancel_use();stop_aim();reload_uid=gun.uid;combat.phase="reload";combat.elapsed=0
	game.play_sound("crossbow_load" if gun.id=="crossbow" else "pistol_reload",game.player.position,-13)
	return true
func fire() -> bool:
	if not equipped() or combat.busy() or game.state.phase!="run" or game.ui.view!="game" or game.suspended: return false
	var data: Dictionary=game.state.weapon().duplicate();var gun: Dictionary=game.state.equipment.primary
	game.cancel_use()
	if not game.state.fire_round(gun.uid):
		combat.cooldown=.22;game.play_sound("dry_fire",game.player.position,-16)
		game.ui.toast("空仓" if game.state.ammo_count(data.ammo)>0 else "弹药耗尽。",2)
		return false
	combat.phase="shoot";combat.elapsed=0;combat.cooldown=float(data.interval)
	var camera: Camera3D=game.player.camera
	var origin: Vector3=camera.global_position
	var direction: Vector3=-camera.global_basis.z
	if gun.id=="pistol":
		var spread:=.003 if aiming else .014
		direction=(direction+camera.global_basis.x*randf_range(-spread,spread)+camera.global_basis.y*randf_range(-spread,spread)).normalized()
	var aim_hit:=ray(origin,origin+direction*float(data.range))
	var destination: Vector3=aim_hit.get("position",origin+direction*float(data.range))
	var muzzle: Vector3=combat.weapon_root.to_global(muzzle_local())
	var obstruction:=ray(origin,muzzle,1)
	if not obstruction.is_empty():
		impact(obstruction,data,gun.id=="crossbow")
	elif gun.id=="pistol":
		var hit:=ray(muzzle,destination+direction*.02)
		if not hit.is_empty(): impact(hit,data,false)
		trace(muzzle,hit.get("position",destination))
	else:
		spawn_bolt(muzzle,(destination-muzzle).normalized()*34.0,float(data.damage),float(data.headshot),0.0)
	game.play_sound("crossbow_fire" if gun.id=="crossbow" else "pistol_fire",muzzle,-11 if gun.id=="crossbow" else -4)
	game.emit_noise(game.player.position,float(data.noise))
	game.player.recoil(-.75 if gun.id=="crossbow" else -2.8,randf_range(-.3,.3))
	game.state.hurt_cooldown=maxf(2,game.state.hurt_cooldown)
	flash_time=.055 if gun.id=="pistol" else 0
	flash.position=muzzle_local();flash.visible=flash_time>0
	game.save_game()
	return true
func ray(from: Vector3,to: Vector3,mask: int=1|8) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,mask);query.exclude=[game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_ray(query)
func impact(hit: Dictionary,data: Dictionary,arrow: bool) -> void:
	var body: Object=hit.get("collider")
	if not is_instance_valid(body): return
	var surface: String=str(body.get_meta("surface","stone"))
	if body is SurvivalEnemy and body.health>0:
		var headshot: bool=hit.position.y-body.global_position.y>=1.47
		# Add the recoverable arrow before damage: a lethal hit immediately creates its corpse inventory.
		if arrow: body.embedded_bolts+=1
		body.receive_hit(float(data.damage)*(float(data.headshot) if headshot else 1.0),-game.player.camera.global_basis.z,2.1 if arrow else .8)
		game.ui.hit(body.health<=0)
		if headshot: game.ui.toast("要害命中",1)
	elif body.has_meta("interaction"):
		game.world.strike(str(body.get_meta("interaction")),float(data.damage))
	game.effects.burst(hit.position,hit.normal,surface,false)
	game.play_sound("hit_"+surface,hit.position,-12 if arrow else -9)
	# Embedded scenery bolts are a short visual mark, not an automatically granted item.
	if arrow and not body is SurvivalEnemy: game.effects.add_mark(hit.position,hit.normal,surface)
func trace(from: Vector3,to: Vector3) -> void:
	var mat:=P.material(Color("ddc296"),.7);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var node:=P.line(game.effects,from,to,.0018,mat)
	game.effects.fragments.append({"node":node,"velocity":Vector3.ZERO,"life":.055,"spin":Vector3.ZERO})
func spawn_bolt(at: Vector3,velocity: Vector3,damage: float,headshot: float,age: float) -> void:
	var node:=Node3D.new();game.actors.add_child(node);node.position=at
	var mat:=P.material(Color("909d99"),.4,.65)
	P.line(node,Vector3.ZERO,Vector3(0,0,.38),.004,mat)
	for x in [-.013,.013]: P.box(node,Vector3(x,0,.32),Vector3(.024,.003,.05),mat)
	if velocity.length_squared()>.01: node.look_at(at+velocity)
	bolts.append({"node":node,"velocity":velocity,"damage":damage,"headshot":headshot,"age":age})
func update_projectiles(delta: float) -> void:
	# Segment sweeps prevent arrows tunnelling through thin walls even on a slow frame.
	var remaining:=minf(delta,.25)
	while remaining>0:
		var step:=minf(remaining,.025);remaining-=step
		for i in range(bolts.size()-1,-1,-1):
			var bolt: Dictionary=bolts[i]
			var from: Vector3=bolt.node.position
			var to: Vector3=from+bolt.velocity*step+Vector3.DOWN*2.4*step*step
			bolt.velocity.y-=4.8*step;bolt.age+=step
			var hit:=ray(from,to)
			if not hit.is_empty() or bolt.age>2.0:
				# Remove first so a kill-triggered save cannot serialize an already spent projectile.
				bolts.remove_at(i);bolt.node.queue_free()
				if not hit.is_empty(): impact(hit,bolt,true)
				game.save_game()
			else:
				bolt.node.position=to;bolt.node.look_at(to+bolt.velocity)
func clear_projectiles() -> void:
	for bolt in bolts:
		if is_instance_valid(bolt.node): bolt.node.queue_free()
	bolts.clear()
func serialize_bolts() -> Array:
	var out: Array=[]
	for bolt in bolts:
		var p: Vector3=bolt.node.position;var v: Vector3=bolt.velocity
		out.append({"position":[p.x,p.y,p.z],"velocity":[v.x,v.y,v.z],"damage":bolt.damage,"headshot":bolt.headshot,"age":bolt.age})
	return out
func restore_bolts(entries: Variant) -> void:
	if not entries is Array: return
	for entry in entries.slice(0,8):
		if not entry is Dictionary or not vector_ok(entry.get("position")) or not vector_ok(entry.get("velocity")): continue
		var p: Array=entry.position;var v: Array=entry.velocity
		spawn_bolt(Vector3(p[0],p[1],p[2]),Vector3(v[0],v[1],v[2]),clampf(game.safe_number(entry.get("damage"),76),0,100),clampf(game.safe_number(entry.get("headshot"),1.5),1,3),clampf(game.safe_number(entry.get("age"),0),0,2))
func vector_ok(value: Variant) -> bool:
	if not value is Array or value.size()!=3: return false
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n))>200: return false
	return true
func update_pose(delta: float) -> void:
	flash_time=maxf(0,flash_time-delta);flash.visible=flash_time>0
	var aim_allowed: bool=aiming and combat.phase in ["idle","shoot"] and game.ui.view=="game" and not game.player.sprinting
	sight_amount=lerpf(sight_amount,1.0 if aim_allowed else 0.0,1-exp(-16*delta))
	var base_fov: float=clampf(game.safe_number(game.settings.get("fov"),74),60,95)
	game.player.camera.fov=lerpf(base_fov,base_fov*.74,sight_amount)
	var pose:=rest_pose();var recoil:=0.0
	var slide: Node3D=combat.weapon_model.find_child("Slide",true,false)
	var mag: Node3D=combat.weapon_model.find_child("Magazine",true,false)
	var arrow: Node3D=combat.weapon_model.find_child("LoadedBolt",true,false)
	var string_node: Node3D=combat.weapon_model.find_child("BowString",true,false)
	combat.support_hand.position=Vector3(-.045,-.025,.02) if combat.shown_weapon=="pistol" else Vector3(0,-.025,-.175)
	combat.support_hand.rotation_degrees=Vector3.ZERO if combat.shown_weapon=="pistol" else Vector3(90,0,0)
	if combat.phase=="shoot":
		recoil=exp(-combat.elapsed*18)
		pose[0].z+=recoil*.052;pose[1].x+=recoil*(7 if combat.shown_weapon=="pistol" else 2.3)
		if combat.elapsed>=float(game.state.weapon().interval): combat.phase="idle"
	elif combat.phase=="reload":
		var duration: float=game.state.weapon().reload
		var t:=clampf(combat.elapsed/duration,0,1);var dip:=sin(t*PI)
		pose[0]+=Vector3(.04,-.12,.05)*dip
		pose[1]+=Vector3(12,-14,25 if combat.shown_weapon=="pistol" else -10)*dip
		if combat.shown_weapon=="crossbow": combat.support_hand.position=Vector3(0,.035,lerpf(-.23,.03,smoothstep(0,.7,t)))
		else: combat.support_hand.position.y-=dip*.23
		if mag!=null: mag.position.y=-.20*sin(clampf(t/.85,0,1)*PI)
		if combat.elapsed>=duration:
			game.state.reload_weapon(reload_uid);reload_uid="";combat.phase="idle";game.play_sound("click",game.player.position,-17);game.save_game()
	if slide!=null: slide.position.z=recoil*.035
	if mag!=null and combat.phase!="reload": mag.position=Vector3.ZERO
	if arrow!=null: arrow.visible=int(game.state.equipment.primary.get("loaded",0))>0
	if string_node!=null:
		string_node.hide()
		if bow_lines.is_empty() or not is_instance_valid(bow_lines[0]) or bow_lines[0].get_parent()!=combat.weapon_model:
			bow_lines.clear()
			for i in range(2): bow_lines.append(P.cylinder(combat.weapon_model,Vector3.ZERO,.0025,1,P.material(Color("8c9691"),.8)))
		var draw_amount:=1.0 if int(game.state.equipment.primary.get("loaded",0))>0 else 0.0
		if combat.phase=="reload": draw_amount=smoothstep(.20,.85,combat.elapsed/float(game.state.weapon().reload))
		for i in range(2):
			var start:=Vector3(-.34 if i==0 else .34,.107,-.325)
			var end:=Vector3(0,.117,lerpf(-.31,-.04,draw_amount))
			bow_lines[i].position=(start+end)*.5;bow_lines[i].scale.y=start.distance_to(end)
			bow_lines[i].quaternion=Quaternion(Vector3.UP,(end-start).normalized())
	combat.weapon_root.position=combat.weapon_root.position.lerp(pose[0],1-exp(-24*delta))
	combat.weapon_root.rotation_degrees=combat.weapon_root.rotation_degrees.lerp(pose[1],1-exp(-24*delta))
	combat.weapon_model.show();combat.held_bottle.hide();combat.torch_hand.hide();combat.support_hand.show();combat.update_arms()
