class_name SurvivalCombat
extends Node3D
const P = preload("res://scripts/props.gd")
const HandModel=preload("res://scripts/survival/hand_model.gd")
const Sleeve=preload("res://assets/survival/hands/sleeve.glb")
const Ranged=preload("res://scripts/survival/ranged.gd")
var ranged: SurvivalRanged
var game: Node3D
var weapon_root: Node3D
var hand: Node3D
var support_hand: Node3D
var torch_hand: Node3D
var forearms: Array[Node3D]=[]
var torch_grip: SurvivalHandModel
var charge_ready := false
var weapon_model: Node3D
var held_bottle: Node3D
var throw_released := false
var flashlight: SpotLight3D
var phase := "idle"
var elapsed := 0.0
var heavy := false
var hit_done := false
var freeze := 0.0
var shown_weapon := ""
var strike_data: Dictionary={}
var profile: Dictionary={}
var launch_pose: Array=[]
var cooldown := 0.0
var side := 1.0
var next_side := 1.0
var shown_signature: String=""
var strike_kind: String="normal"
var combo_next: int=0
var combo_window: float=0.0
var queued_press: bool=false
var queued_light: bool=false

# Contact timings and poses are coupled: the hit lands as the model crosses the reticle.
static func attack_profile(id: String, charged: bool) -> Dictionary:
	if id=="bat":
		return {"contact":.38 if charged else .25,"follow":.54 if charged else .39,"duration":1.12 if charged else .85,"charge":.55,"radius":.26,"stop":.092 if charged else .060,"recoil":3.2 if charged else 1.9,"force":4.5 if charged else 2.5,"audio":"bat"}
	return {"contact":.22 if charged else .12,"follow":.34 if charged else .22,"duration":.78 if charged else .52,"charge":.36,"radius":.13,"stop":.056 if charged else .028,"recoil":2.1 if charged else .95,"force":3.8 if charged else 1.6,"audio":"wrench"}

func make_hand(parent: Node3D,left: bool=false) -> SurvivalHandModel:
	var grip:=HandModel.new();grip.left=left;parent.add_child(grip)
	return grip
func sleeve_material() -> ShaderMaterial:
	var material:=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
void fragment() {
 vec2 thread=UV*vec2(190.0,680.0);
 float fade=1.0-clamp(max(fwidth(thread.x),fwidth(thread.y)),0.0,1.0);
 float weave=sin(thread.x*6.283)*sin(thread.y*6.283)*.035*fade;
 float grain=sin(UV.y*193.0+sin(UV.x*53.0))*.018;
 ALBEDO=vec3(.115,.145,.135)+vec3(weave+grain);
 ROUGHNESS=.92; SPECULAR=.22;
}"""
	material.shader=shader;return material
func _ready() -> void:
	weapon_root=Node3D.new();add_child(weapon_root)
	var glove:=P.material(Color("222a29"),.95)
	hand=make_hand(weapon_root)
	support_hand=make_hand(weapon_root,true)
	support_hand.position=Vector3(0,.105,.006);support_hand.rotation.z=0
	var cloth:=sleeve_material()
	for i in range(2):
		var sleeve: Node3D=Sleeve.instantiate();add_child(sleeve)
		var mesh: MeshInstance3D=sleeve.find_child("Sleeve",true,false)
		if sleeve is MeshInstance3D: mesh=sleeve
		if mesh!=null: mesh.material_override=cloth;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		forearms.append(sleeve)
	torch_hand=Node3D.new();add_child(torch_hand);torch_hand.position=Vector3(.03,.07,-.14)
	var torch:=Node3D.new();torch.position=Vector3(-.27,-.28,-.45);torch.rotation.x=PI/2;torch_hand.add_child(torch)
	P.cylinder(torch,Vector3.ZERO,.038,.18,glove)
	P.cylinder(torch,Vector3(0,-.105,0),.048,.04,P.material(Color("8a908b"),.33,.8))
	torch_grip=make_hand(torch_hand,true)
	torch_grip.position=Vector3(-.258,-.30,-.38);torch_grip.rotation.x=PI/2;torch_grip.set_pose("Grip Shaft",1)
	flashlight=SpotLight3D.new();flashlight.position=Vector3(-.14,-.12,-.23);flashlight.light_color=Color("d8dfca");flashlight.light_energy=2.3;flashlight.spot_range=9;flashlight.spot_angle=32;flashlight.spot_attenuation=1.3;flashlight.shadow_enabled=true;flashlight.shadow_bias=.05;add_child(flashlight)
	var fill:=OmniLight3D.new();fill.position=Vector3(0,0,-.15);fill.light_energy=.24;fill.omni_range=.9;fill.light_color=Color("a5b9b4");add_child(fill)
	ranged=Ranged.new();ranged.game=game;ranged.combat=self;add_child(ranged)
	held_bottle=Node3D.new();held_bottle.position.y=-.16;weapon_root.add_child(held_bottle)
	SurvivalLoot.build_visual(held_bottle,"bottle");held_bottle.hide()
	update_weapon()
func update_weapon() -> void:
	var id: String=game.state.equipment.primary.get("id","wrench")
	var item: Dictionary=game.state.equipment.primary
	var signature: String=str(item.get("uid",""))+":"+id+":"+str(item.get("melee_upgrade",false))
	if shown_signature==signature: return
	ranged.cancel();clear_combo()
	shown_signature=signature;shown_weapon=id
	if is_instance_valid(weapon_model): weapon_root.remove_child(weapon_model);weapon_model.queue_free()
	var model_path: String="res://assets/models/wrench.glb" if id=="wrench" else "res://assets/survival/"+id+".glb"
	weapon_model=load(model_path).instantiate()
	weapon_model.scale=Vector3.ONE*(1.0 if ranged.equipped() else (.90 if id=="wrench" else .88))
	weapon_root.add_child(weapon_model);game.age_materials(weapon_model)
	SurvivalLoot.decorate_upgrade(weapon_model,item)
	support_hand.position=Vector3(0,.105,.006);support_hand.rotation=Vector3.ZERO
	support_hand.visible=id=="bat" or ranged.equipped()
	# The lamp clips to the chest while both hands hold the bat.
	torch_hand.visible=id=="wrench"
	flashlight.position=Vector3(-.24,-.21,-.70) if id=="wrench" else Vector3(0,-.30,-.15)
	next_side=1
func busy() -> bool: return phase!="idle" or cooldown>0
func clear_combo() -> void:
	combo_next=0;combo_window=0;queued_press=false;queued_light=false
	strike_kind="normal"
func press() -> void:
	if ranged.equipped(): ranged.fire();return
	if game.state.phase!="run": return
	if phase=="swing" and game.state.weapon().get("melee_upgrade",false):
		queued_press=true
		return
	if busy(): return
	game.cancel_use();strike_kind="normal";phase="charge";elapsed=0;charge_ready=false
func release() -> void:
	if phase=="swing" and queued_press:
		queued_press=false;queued_light=true
		return
	if phase!="charge": return
	start_swing(elapsed>=float(attack_profile(shown_weapon,false).charge))
func start_swing(is_heavy: bool) -> bool:
	if ranged.equipped(): return false
	if phase not in ["idle","charge"] or cooldown>0 or game.state.phase!="run": return false
	update_weapon();heavy=is_heavy;strike_data=game.state.weapon().duplicate();profile=attack_profile(shown_weapon,heavy)
	strike_kind="normal"
	if strike_data.get("melee_upgrade",false):
		if shown_weapon=="bat" and heavy:
			strike_kind="launch";profile.stop=.105;profile.recoil=3.8
		elif shown_weapon=="wrench" and not heavy:
			strike_kind=["slash","uppercut","finisher"][combo_next if combo_window>0 else 0]
			match strike_kind:
				"slash": profile.contact=.10;profile.follow=.18;profile.duration=.34
				"uppercut": profile.contact=.13;profile.follow=.23;profile.duration=.40;profile.force=3.0;profile.stop=.07;profile.recoil=1.8
				"finisher": profile.contact=.18;profile.follow=.29;profile.duration=.56;profile.force=6.0;profile.stop=.09;profile.recoil=2.7;profile.radius=.24;strike_data.damage=84.0;strike_data.reach=2.15
	var cost: float=strike_data.heavy_cost if heavy else strike_data.cost
	if not game.state.spend_stamina(cost): phase="idle";clear_combo();game.ui.toast("体力不足。",2);return false
	game.cancel_use();side=next_side
	if not heavy: next_side=-next_side
	launch_pose=[weapon_root.position,weapon_root.rotation_degrees]
	phase="swing";elapsed=0;hit_done=false;queued_light=false;queued_press=false
	game.play_sound(profile.audio+"_swing",game.player.global_position,-6 if heavy else -11)
	game.state.hurt_cooldown=maxf(game.state.hurt_cooldown,2)
	return true
func push() -> bool:
	if busy() or not game.state.spend_stamina(25): return false
	game.cancel_use();clear_combo();ranged.stop_aim();cooldown=.55;phase="push";elapsed=0;game.player.recoil(-1.2)
	var hit:=sweep(1.3,.32)
	if not hit.is_empty() and hit.collider is SurvivalEnemy:
		hit.collider.receive_hit(0,-game.player.camera.global_basis.z,3.3)
		game.play_sound("hit_flesh",hit.position,-12);game.ui.hit()
	return true
func sweep(reach: float,radius: float=.22) -> Dictionary:
	var space:=game.get_world_3d().direct_space_state
	var from: Vector3=game.player.camera.global_position-Vector3.UP*.12
	var direction: Vector3=-game.player.camera.global_basis.z
	var query:=PhysicsShapeQueryParameters3D.new()
	var sphere:=SphereShape3D.new();sphere.radius=radius
	query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,from);query.motion=direction*reach
	query.collision_mask=1|8;query.exclude=[game.player.get_rid()]
	var travel: PackedFloat32Array=space.cast_motion(query)
	if travel.size()==2 and travel[0]<1:
		query.transform.origin+=query.motion*minf(1,travel[1]+.005);query.motion=Vector3.ZERO
		var info:=space.get_rest_info(query)
		if not info.is_empty(): return {"collider":instance_from_id(info.collider_id),"position":info.point,"normal":info.normal}
	var ray:=PhysicsRayQueryParameters3D.create(from,from+direction*reach,1|8)
	ray.exclude=[game.player.get_rid()]
	return space.intersect_ray(ray)
func bat_hits() -> Array[Dictionary]:
	var hits: Array[Dictionary]=[]
	var primary:=sweep(float(strike_data.reach),float(profile.radius))
	if not primary.is_empty(): hits.append(primary)
	# The heavy blow commits to one body; the travelling body supplies its collateral hits.
	if heavy: return hits
	var camera: Camera3D=game.player.camera
	var from: Vector3=camera.global_position-Vector3.UP*.12
	var forward: Vector3=-camera.global_basis.z
	forward.y=0;forward=forward.normalized()
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0: continue
		if hits.any(func(h): return h.collider==enemy): continue
		var at: Vector3=enemy.global_position+Vector3.UP*1.1
		var offset: Vector3=at-from
		var flat:=Vector3(offset.x,0,offset.z)
		if flat.length()>float(strike_data.reach)+.18 or absf(offset.y)>1.1: continue
		if forward.dot(flat.normalized())<cos(deg_to_rad(52)): continue
		var ray:=PhysicsRayQueryParameters3D.create(from,at,1|8);ray.exclude=[game.player.get_rid()]
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider==enemy: hits.append(hit)
	return hits
func resolve_hit() -> void:
	if hit_done or profile.is_empty(): return
	hit_done=true
	var hits: Array[Dictionary]=[]
	if shown_weapon=="bat": hits=bat_hits()
	else:
		var hit:=sweep(float(strike_data.reach),float(profile.radius))
		if not hit.is_empty(): hits.append(hit)
	var connected:=false
	var force: float=float(profile.force)*float(strike_data.impact)*(1+game.state.attributes.strength*.05)
	var direction: Vector3=-game.player.camera.global_basis.z
	direction.y=0;direction=direction.normalized()
	for index in range(hits.size()):
		var hit: Dictionary=hits[index]
		var body: Object=hit.collider
		if not is_instance_valid(body): continue
		var surface: String=str(body.get_meta("surface","stone"))
		var impulse:=direction
		if shown_weapon=="bat" and not heavy: impulse=(impulse+game.player.camera.global_basis.x*side*.45).normalized()
		if body is SurvivalEnemy and body.health>0:
			connected=true
			var damage: float=(strike_data.heavy if heavy else strike_data.damage)*game.state.damage_multiplier()
			body.receive_hit(damage,impulse,force)
			if strike_kind=="launch": body.launch_body(direction,9.0,3.3,true)
			elif strike_kind=="uppercut": body.launch_body(direction,1.1,3.2,false)
			elif strike_kind=="finisher": body.slam_body(direction)
			game.ui.hit(body.health<=0)
			if body.health<=0 and strike_data.get("melee_upgrade",false): game.state.stamina=minf(game.state.maximum_stamina(),game.state.stamina+8)
		elif body.has_meta("interaction"):
			game.world.strike(str(body.get_meta("interaction")),float(strike_data.heavy if heavy else strike_data.damage))
		game.effects.burst(hit.position,hit.normal,surface,heavy or strike_kind=="finisher")
		if index<3: game.play_sound("hit_"+surface,hit.position,-7 if heavy else -11)
		if index==0:
			game.play_sound(profile.audio+"_contact",hit.position,-7 if heavy else -12)
			if strike_kind in ["launch","finisher"]: game.play_sound("heavy_body",hit.position,-8)
		game.emit_noise(hit.position,11 if surface in ["glass","metal"] else 7)
	if connected and strike_kind in ["slash","uppercut"]:
		combo_next=1 if strike_kind=="slash" else 2;combo_window=1.05
	else: combo_next=0;combo_window=0
	if not hits.is_empty():
		game.player.recoil(float(profile.recoil),-side if shown_weapon=="bat" else side*.35)
		freeze=float(profile.stop)
	game.save_game()
func idle_pose() -> Array[Vector3]:
	if is_instance_valid(ranged) and ranged.equipped(): return ranged.rest_pose()
	return [Vector3(.23,-.25,-.77),Vector3(-14,-12,-28)] if shown_weapon=="bat" else [Vector3(.28,-.24,-.67),Vector3(-9,-15,-26)]
func attack_poses() -> Array:
	if strike_kind=="uppercut":
		return [[Vector3(.26,-.53,-.42),Vector3(-40,-18,-38)],[Vector3(.02,-.12,-.83),Vector3(18,6,-15)],[Vector3(-.12,.12,-.62),Vector3(70,22,12)]]
	if strike_kind=="finisher":
		return [[Vector3(.20,.13,-.40),Vector3(74,-12,-18)],[Vector3(.02,-.31,-.84),Vector3(-70,9,7)],[Vector3(-.12,-.53,-.69),Vector3(-102,20,26)]]
	if shown_weapon=="bat":
		if heavy: return [[Vector3(.31,-.24,-.48),Vector3(42,-28,-78)],[Vector3(-.05,-.26,-.80),Vector3(-55,14,22)],[Vector3(-.33,-.52,-.57),Vector3(-76,48,79)]]
		return [[Vector3(.46*side,-.34,-.40),Vector3(6,-42*side,-78*side)],[Vector3(0,-.30,-.86),Vector3(-63,0,0)],[Vector3(-.44*side,-.41,-.52),Vector3(-24,50*side,78*side)]]
	if heavy: return [[Vector3(.18,.01,-.44),Vector3(47,-8,-9)],[Vector3(.05,-.18,-.79),Vector3(-58,8,10)],[Vector3(.04,-.44,-.66),Vector3(-85,12,24)]]
	return [[Vector3(.32*side,-.23,-.48),Vector3(12,-23*side,-48*side)],[Vector3(.04,-.22,-.74),Vector3(-54,8*side,8*side)],[Vector3(-.11*side,-.33,-.63),Vector3(-59,19*side,39*side)]]
func mix_pose(a: Array,b: Array,t: float) -> Array:
	t=smoothstep(0,1,clampf(t,0,1))
	return [a[0].lerp(b[0],t),a[1].lerp(b[1],t)]
func swing_pose(at: float) -> Array:
	var poses:=attack_poses()
	var windup: float=float(profile.contact)*.32
	if at<windup and not launch_pose.is_empty(): return mix_pose(launch_pose,poses[0],at/windup)
	if at<float(profile.contact): return mix_pose(poses[0],poses[1],(at-windup)/(float(profile.contact)-windup))
	if at<float(profile.follow): return mix_pose(poses[1],poses[2],(at-float(profile.contact))/(float(profile.follow)-float(profile.contact)))
	return mix_pose(poses[2],idle_pose(),(at-float(profile.follow))/(float(profile.duration)-float(profile.follow)))
func throw_gesture() -> void:
	clear_combo();ranged.stop_aim()
	phase="throw";elapsed=0;cooldown=.66;throw_released=false
func cancel_action() -> void:
	clear_combo()
	phase="idle";elapsed=0;freeze=0
	ranged.cancel()
func reset() -> void:
	clear_combo();ranged.cancel()
	phase="idle";elapsed=0;cooldown=0;freeze=0;hit_done=false
	update_weapon();weapon_root.position=idle_pose()[0];weapon_root.rotation_degrees=idle_pose()[1];update_arms()
func update_arms() -> void:
	if forearms.size()!=2: return
	var right_pose: String="Pistol" if ranged.equipped() else "Grip"
	if phase=="throw": right_pose="Straight" if throw_released else "Cup"
	elif phase=="push": right_pose="Straight"
	hand.set_pose(right_pose,.6)
	support_hand.set_pose("Grip Shaft" if shown_weapon=="crossbow" else "Grip",.6)
	for i in range(2):
		var sleeve: Node3D=forearms[i]
		var grip: SurvivalHandModel=hand if i==0 else (support_hand if support_hand.visible else torch_grip)
		sleeve.visible=i==0 or support_hand.visible or torch_hand.visible
		var start:=Vector3(.38 if i==0 else -.38,-.69,.05)
		var end: Vector3=to_local(grip.wrist_global())
		var direction:=end-start
		sleeve.position=start;sleeve.scale=Vector3(1,1,maxf(.05,direction.length()+.012))
		sleeve.quaternion=Quaternion(Vector3.FORWARD,direction.normalized())
func _process(delta: float) -> void:
	if game==null: return
	visible=game.state.phase=="run" and game.ui.view=="game"
	if game.suspended or game.state.phase!="run": return
	update_weapon();cooldown=maxf(0,cooldown-delta)
	combo_window=maxf(0,combo_window-delta)
	if combo_window<=0: combo_next=0
	if freeze>0: freeze=maxf(0,freeze-delta);return
	elapsed+=delta
	if ranged.equipped() and phase not in ["throw","push"]:
		ranged.update_pose(delta);return
	var pose: Array=idle_pose()
	if phase=="charge":
		heavy=true;side=next_side
		if not charge_ready and elapsed>=float(attack_profile(shown_weapon,false).charge):
			charge_ready=true;game.play_sound("click",game.player.global_position,-19)
		pose=mix_pose(idle_pose(),attack_poses()[0],elapsed/float(attack_profile(shown_weapon,false).charge))
	elif phase=="swing":
		pose=swing_pose(elapsed)
		if elapsed>=float(profile.contact) and not hit_done: resolve_hit()
		var ready: bool=elapsed>=float(profile.duration) or (strike_kind in ["slash","uppercut"] and combo_window>0 and elapsed>=float(profile.follow)+.025)
		if queued_light and hit_done and ready:
			phase="idle";start_swing(false)
			return
		if elapsed>=float(profile.duration): phase="idle"
	elif phase=="throw":
		var start: Array=[Vector3(.34,-.12,-.36),Vector3(45,-10,-20)]
		var release_pose: Array=[Vector3(.03,-.19,-.76),Vector3(-67,6,15)]
		pose=mix_pose(start,release_pose,elapsed/.24) if elapsed<.24 else mix_pose(release_pose,idle_pose(),(elapsed-.24)/.42)
		if elapsed>=.24 and not throw_released:
			throw_released=true;game.launch_bottle();game.play_sound("wrench_swing",game.player.global_position,-18)
		if elapsed>=.66: phase="idle"
	elif phase=="push":
		var t:=sin(clampf(elapsed/.5,0,1)*PI)
		pose[0]+=Vector3(-.18,.05,-.25)*t;pose[1]+=Vector3(-70,0,20)*t
		if elapsed>=.5: phase="idle"
	else:
		pose[0].y+=sin(game.time*1.6)*.003
		if game.player.moving and game.player.head_bob: pose[0].x+=sin(game.time*5)*.009
	# Exact swing poses keep animation contact synchronized with collision and hit stop.
	if phase=="swing": weapon_root.position=pose[0];weapon_root.rotation_degrees=pose[1]
	else:
		weapon_root.position=weapon_root.position.lerp(pose[0],1-exp(-24*delta))
		weapon_root.rotation_degrees=weapon_root.rotation_degrees.lerp(pose[1],1-exp(-24*delta))

	weapon_model.visible=phase!="throw"
	held_bottle.visible=phase=="throw" and not throw_released
	support_hand.visible=shown_weapon=="bat" and phase!="throw"
	torch_hand.visible=shown_weapon=="wrench" and phase!="throw"
	update_arms()
