class_name SurvivalEnemy
extends CharacterBody3D
const MODEL=preload("res://assets/survival/zombie/pixelhouse_zombie.glb")
static var appearance_materials: Dictionary={}
var game: Node3D
var enemy_id := ""
var health := 95.0
var behavior := "idle"
var timer := 0.0
var sense_clock := 0.0
var memory := 0.0
var target_point := Vector3.ZERO
var home := Vector3.ZERO
var route := PackedVector3Array()
var route_index := 0
var path_clock := 0.0
var knockback := Vector3.ZERO
var rig: Node3D
var age := 0.0
var stagger_pose := 0.0
var attack_fired := false
var hit_pause := 0.0
var animator: AnimationPlayer
var skeleton: Skeleton3D
var pelvis_bone: int=-1
var head_bone: int=-1
var clip_state: String=""
var appearance: int=0
var death_time: float=0.0
var embedded_bolts: int=0
var reaction_pivot: Node3D
var launch_velocity:=Vector3.ZERO
var launch_remaining: float=0.0
var launch_elapsed: float=0.0
var launch_chain: bool=false
var launch_wall_hit: bool=false
var launch_hits: Array[String]=[]
var launch_direction:=Vector3.FORWARD
var down_remaining: float=0.0
var down_elapsed: float=0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1|4|8
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .23
	capsule.height = 1.73
	collision.shape = capsule
	collision.position.y = .865
	add_child(collision)
	reaction_pivot=Node3D.new();reaction_pivot.position.y=.85;add_child(reaction_pivot)
	rig = MODEL.instantiate()
	reaction_pivot.add_child(rig);rig.position.y=-.85
	rig.rotation.y=PI/2
	animator=rig.find_child("AnimationPlayer",true,false)
	skeleton=rig.find_child("Skeleton3D",true,false)
	assert(animator!=null and skeleton!=null,"Imported zombie needs its animation player and skeleton")
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	pelvis_bone=skeleton.find_bone("Bip01 Pelvis")
	head_bone=skeleton.find_bone("Bip01 Head")
	appearance=0 if enemy_id in ["living-infected","resident-infected"] else (1 if enemy_id in ["hall-infected","laundry-infected"] else 2)
	if enemy_id.begins_with("street-"): appearance=posmod(enemy_id.hash(),3)
	apply_appearance()
	for clip in animator.get_animation_list():
		var animation:=animator.get_animation(clip)
		animation.loop_mode=Animation.LOOP_LINEAR if clip=="Walk" else Animation.LOOP_NONE
	animator.play("Walk");animator.advance(0)
	home = position
	target_point = position
	sense_clock = randf()*.25
	age = randf()*8
	set_meta("surface","flesh")
func apply_appearance() -> void:
	var colors: Array[Color]=[Color(1,1,1),Color(.72,.85,.80),Color(.89,.76,.61)]
	for mesh in rig.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var key: String=str(appearance)+":"+str(i)
			if not appearance_materials.has(key):
				var material:=mesh.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
				material.albedo_color=colors[appearance]
				material.roughness=.93;material.metallic_specular=.25;material.normal_scale=.6
				appearance_materials[key]=material
			mesh.set_surface_override_material(i,appearance_materials[key])
	# Reuse the three immutable materials across reloads and enemy instances.
	rig.scale=Vector3(1.04,1.02,1.02) if appearance==1 else (Vector3(.96,.98,.98) if appearance==2 else Vector3.ONE)
func corpse_point() -> Vector3:
	if skeleton!=null and pelvis_bone>=0:
		var at: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(pelvis_bone).origin+Vector3.UP*.05
		if health<=0 and is_inside_tree():
			var ray:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.3,at,1)
			var obstruction:=get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty(): return obstruction.position+obstruction.normal*.22
		return at
	return global_position+Vector3.UP*.3

func can_see_player() -> bool:
	var p: Node3D = game.player
	var offset: Vector3 = p.global_position-global_position
	if offset.length()>4.7 or p.global_position.y < -.5: return false
	var facing := Vector3(sin(rotation.y),0,cos(rotation.y))
	if behavior not in ["chase","windup","recover"] and facing.dot(offset.normalized()) < .0 and offset.length()>1.6: return false
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.5,p.global_position+Vector3.UP*(.85 if p.crouched else 1.35),1|4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == p

func hear(at: Vector3, loudness: float) -> void:
	if behavior in ["dead","windup","recover","stagger","launched","down"]: return
	var q := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,at+Vector3.UP,1)
	var attenuation := .5 if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() else 1.0
	if global_position.distance_to(at)>loudness*attenuation: return
	if behavior != "chase":
		behavior = "investigate"
		target_point = at
		memory = 5
		path_clock = 0

func receive_hit(damage: float, direction: Vector3, force: float) -> void:
	if behavior == "dead": return
	var was_down: bool=behavior=="down"
	health = maxf(0,health-damage)
	knockback = direction.normalized()*force
	stagger_pose = clampf(force*.10,.12,.42)
	hit_pause = .065 if force>3.5 else .042
	attack_fired = true
	if health <= 0:
		behavior = "dead"
		collision_layer = 0
		collision_mask = 1
		death_time=animator.current_animation_position/1.9 if was_down else 0.0
		play_clip("Death",0)
		game.enemy_killed(self)
	else:
		behavior = "launched" if launch_remaining>0 else ("down" if was_down else "stagger")
		timer = .35+force*.035
		memory = 5
		target_point = game.player.global_position

func launch_body(direction: Vector3,speed: float,lift: float,chain: bool) -> void:
	launch_direction=Vector3(direction.x,0,direction.z).normalized()
	if launch_direction.length_squared()<.01: launch_direction=Vector3.FORWARD
	launch_velocity=launch_direction*speed+Vector3.UP*lift
	launch_remaining=1.4;launch_elapsed=0;launch_chain=chain;launch_wall_hit=false
	launch_hits.clear();down_remaining=0;down_elapsed=0;knockback=Vector3.ZERO
	collision_mask=1;attack_fired=true;hit_pause=0
	if health>0: behavior="launched"
	clip_state="";play_clip("Walk",0)
func knock_down(duration: float,direction: Vector3) -> void:
	if health<=0: return
	launch_remaining=0;launch_chain=false;collision_mask=1|4|8
	behavior="down";down_remaining=duration;down_elapsed=0;attack_fired=true
	knockback=direction.normalized()*2.1
	clip_state="";play_clip("Death",0)
func slam_body(direction: Vector3) -> void:
	if launch_remaining>0:
		launch_velocity=Vector3(direction.x*.8,-5.0,direction.z*.8);launch_chain=false
	elif health>0: knock_down(1.4,direction)
func step_launch(delta: float) -> void:
	launch_remaining=maxf(0,launch_remaining-delta);launch_elapsed+=delta
	var before:=global_position
	launch_velocity.y-=9.8*delta
	var speed: float=Vector2(launch_velocity.x,launch_velocity.z).length()
	var collision:=move_and_collide(launch_velocity*delta)
	# Sweep the path actually travelled, after world collision has shortened it.
	if launch_chain and speed>2.0:
		for other in game.enemies:
			if other==self or not is_instance_valid(other) or other.health<=0 or other.launch_remaining>0 or launch_hits.has(other.enemy_id): continue
			var at: Vector3=other.global_position+Vector3.UP*.8
			var nearest:=Geometry3D.get_closest_point_to_segment(at,before+Vector3.UP*.8,global_position+Vector3.UP*.8)
			if nearest.distance_squared_to(at)>.67*.67: continue
			var ray:=PhysicsRayQueryParameters3D.create(nearest,at,1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			launch_hits.append(other.enemy_id)
			other.receive_hit(62.0,launch_direction,4.0)
			other.knock_down(1.5,launch_direction)
			game.effects.burst(at,-launch_direction,"flesh",true);game.play_sound("heavy_body",at,-9)
			game.ui.hit(other.health<=0)
			game.save_game()
	if collision!=null:
		var normal: Vector3=collision.get_normal()
		if normal.y>.55:
			finish_launch()
			return
		if not launch_wall_hit and speed>2.5:
			launch_wall_hit=true
			game.effects.burst(collision.get_position(),normal,"stone",true)
			game.play_sound("body_land",collision.get_position(),-7)
			if health>0: receive_hit(38.0,-normal,0)
			game.emit_noise(global_position,8)
		launch_velocity=launch_velocity.slide(normal);launch_velocity.x*=.12;launch_velocity.z*=.12
	launch_velocity.x=move_toward(launch_velocity.x,0,delta*1.8)
	launch_velocity.z=move_toward(launch_velocity.z,0,delta*1.8)
	if launch_remaining<=0: finish_launch()
func finish_launch() -> void:
	launch_remaining=0;launch_chain=false;launch_velocity=Vector3.ZERO;velocity=Vector3.ZERO
	collision_mask=1 if health<=0 else 1|4|8
	if health<=0:
		death_time=animator.get_animation("Death").length*.72/1.9
		reaction_pivot.quaternion=Quaternion.IDENTITY
		clip_state="";play_clip("Death",0);animator.seek(death_time*1.9,true)
	else: knock_down(1.25,launch_direction)
	game.play_sound("body_land",global_position,-11)
	game.effects.burst(global_position+Vector3.UP*.08,Vector3.UP,"dust",true)
	game.save_game()

func _physics_process(delta: float) -> void:
	if game == null or game.suspended or game.state.phase != "run": return
	# Only nearby outdoor actors simulate; unloaded regions have no actor nodes at all.
	if game.world.region=="district" and global_position.distance_squared_to(game.player.global_position)>26.0*26.0 and (behavior!="dead" or death_time>3): return
	age += delta
	if hit_pause>0: hit_pause=maxf(0,hit_pause-delta)
	else: animate(delta)
	if launch_remaining>0:
		step_launch(delta)
		return
	if behavior == "dead" or behavior=="down":
		velocity.x=knockback.x;velocity.z=knockback.z
		knockback = knockback.move_toward(Vector3.ZERO,delta*8)
		if not is_on_floor(): velocity.y -= 9.8*delta
		else: velocity.y=0
		move_and_slide()
		if behavior=="down":
			down_remaining=maxf(0,down_remaining-delta);down_elapsed+=delta
			if down_remaining<=0: behavior="chase";memory=4;clip_state="";play_clip("Walk",.12)
		return
	timer = maxf(0,timer-delta)
	memory = maxf(0,memory-delta)
	sense_clock -= delta
	if sense_clock<=0:
		sense_clock = .18
		if can_see_player():
			target_point = game.player.global_position
			memory = 4.5
			if behavior in ["idle","investigate"]:
				behavior = "chase"
				game.play_sound("snarl",global_position,-14)
	var to_target := target_point-global_position
	to_target.y = 0
	if behavior == "stagger" and timer<=0: behavior = "chase"
	if behavior == "chase" and memory<=0:
		behavior = "investigate"
		memory = 3
	if behavior == "investigate" and memory<=0:
		behavior = "idle"
		target_point = home
	if behavior == "chase" and to_target.length()<1.30 and can_see_player():
		behavior = "windup"
		clip_state="";play_clip("Attack",.08)
		timer = .65
		attack_fired = false
		game.play_sound("snarl",global_position,-12)
	if behavior == "windup" and timer<=0:
		if not attack_fired:
			attack_fired = true
			if global_position.distance_to(game.player.global_position)<1.55 and can_see_player():
				game.player_hit(23,global_position)
		behavior = "recover"
		timer = 1.15
	if behavior == "recover" and timer<=0: behavior = "chase"
	var desired := Vector3.ZERO
	if behavior in ["chase","investigate","idle"] and to_target.length()>.32:
		path_clock -= delta
		if path_clock<=0 or route.is_empty():
			path_clock = .55
			route = game.navigation.path(global_position,target_point)
			route_index = mini(1,route.size()-1)
		if route_index>=0 and route_index<route.size():
			var direction := route[route_index]-global_position
			direction.y = 0
			if direction.length()<.19:
				route_index += 1
			else: desired = direction.normalized()*(1.72 if behavior == "chase" else .86)
	if desired.length()>.05:
		rotation.y = lerp_angle(rotation.y,atan2(desired.x,desired.z),1-exp(-7*delta))
	elif behavior == "windup" and to_target.length()>.01:
		rotation.y = lerp_angle(rotation.y,atan2(to_target.x,to_target.z),1-exp(-5*delta))
	velocity.x = desired.x+knockback.x
	velocity.z = desired.z+knockback.z
	knockback = knockback.move_toward(Vector3.ZERO,delta*8)
	if not is_on_floor(): velocity.y -= 9.8*delta
	else: velocity.y = 0
	move_and_slide()

func animate(delta: float) -> void:
	if not is_instance_valid(animator): return
	if launch_remaining>0:
		var local_direction: Vector3=global_basis.inverse()*launch_direction
		var axis: Vector3=Vector3.UP.cross(local_direction).normalized()
		reaction_pivot.quaternion=Quaternion(axis,minf(launch_elapsed*4,1.05))
		play_clip("Walk",0);animator.advance(0)
		return
	reaction_pivot.quaternion=reaction_pivot.quaternion.slerp(Quaternion.IDENTITY,1-exp(-12*delta))
	if behavior=="down":
		play_clip("Death",0)
		var amount:=minf(1,down_elapsed/.24)
		if down_remaining<.35: amount=down_remaining/.35
		animator.seek(animator.get_animation("Death").length*amount,true)
		return
	if behavior == "dead":
		play_clip("Death",.08)
		death_time+=delta
		animator.advance(delta*1.9)
		return
	if behavior in ["windup","recover"]:
		play_clip("Attack",.08)
		animator.advance(delta*1.5)
	elif behavior=="stagger":
		# A brief bone-driven recoil is layered over the paused locomotion pose.
		play_clip("Walk",.08)
		animator.advance(0)
	else:
		play_clip("Walk",.12)
		var moving:=Vector2(velocity.x,velocity.z).length()
		animator.advance(delta*(.90 if behavior=="chase" else .50) if moving>.12 else 0)
	stagger_pose = move_toward(stagger_pose,0,delta*1.2)
	rig.rotation.x=-stagger_pose*.5
	rig.rotation.z=sin(age*1.7+appearance)*.018
func play_clip(name: String,blend: float=.1) -> void:
	if clip_state==name: return
	clip_state=name
	animator.play(name,blend)
	animator.advance(0)

func serialize() -> Dictionary:
	return {"id":enemy_id,"hp":health,"position":[position.x,position.y,position.z],"yaw":rotation.y,"behavior":behavior,"timer":timer,"memory":memory,"target":[target_point.x,target_point.y,target_point.z],"death_time":death_time,"embedded_bolts":embedded_bolts,"down_remaining":down_remaining,"down_elapsed":down_elapsed,"launch":{"remaining":launch_remaining,"elapsed":launch_elapsed,"velocity":[launch_velocity.x,launch_velocity.y,launch_velocity.z],"direction":[launch_direction.x,launch_direction.y,launch_direction.z],"chain":launch_chain,"wall":launch_wall_hit,"hits":launch_hits.duplicate()}}
static func read_motion(value: Variant,fallback: Vector3) -> Vector3:
	if not value is Array or value.size()!=3: return fallback
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)): return fallback
	return Vector3(value[0],value[1],value[2])

func restore(data: Dictionary) -> void:
	embedded_bolts=clampi(int(game.safe_number(data.get("embedded_bolts"),0)),0,24)
	health = clampf(game.safe_number(data.get("hp"),95),0,95)
	position = game.read_vector(data.get("position"),home)
	rotation.y = game.safe_number(data.get("yaw"),0)
	behavior = str(data.get("behavior","idle"))
	if behavior not in ["idle","investigate","chase","windup","recover","stagger","dead","launched","down"]: behavior = "idle"
	timer = game.safe_number(data.get("timer"),0)
	memory = game.safe_number(data.get("memory"),0)
	target_point = game.read_vector(data.get("target"),position)
	if health<=0:
		behavior = "dead"
		collision_layer = 0;collision_mask=1
		death_time=maxf(0,game.safe_number(data.get("death_time"),3))
		play_clip("Death",0)
		animator.seek(minf(death_time*1.9,animator.get_animation("Death").length),true)

	# Restore the actual motion and struck IDs, so loading cannot replay collateral damage.
	down_remaining=clampf(game.safe_number(data.get("down_remaining"),0),0,2)
	down_elapsed=clampf(game.safe_number(data.get("down_elapsed"),0),0,2)
	var flight: Variant=data.get("launch",{})
	if flight is Dictionary:
		launch_remaining=clampf(game.safe_number(flight.get("remaining"),0),0,1.4)
		launch_elapsed=clampf(game.safe_number(flight.get("elapsed"),0),0,2)
		launch_velocity=read_motion(flight.get("velocity"),Vector3.ZERO).limit_length(18)
		launch_direction=read_motion(flight.get("direction"),Vector3.FORWARD).normalized()
		if launch_direction.length_squared()<.01: launch_direction=Vector3.FORWARD
		launch_chain=flight.get("chain",false)==true;launch_wall_hit=flight.get("wall",false)==true
		launch_hits.clear()
		if flight.get("hits") is Array:
			for id in flight.hits:
				if id is String and launch_hits.size()<32 and not launch_hits.has(id): launch_hits.append(id)
	if launch_remaining>0:
		collision_mask=1;clip_state="";play_clip("Walk",0);animate(0)
	elif behavior=="launched": behavior="stagger";timer=.3
	elif behavior=="down": animate(0)
