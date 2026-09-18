class_name SurvivalPlayer
extends "res://scripts/player.gd"
var survival: SurvivalState
var crouched := false
var sprinting := false
var moving := false
var impulse := Vector3.ZERO
var shake_strength := 0.5
var kick := 0.0
var roll := 0.0
var capsule_shape: CollisionShape3D

func _ready() -> void:
	super._ready()
	capsule_shape = get_child(0)
	collision_mask = 1|8

func _unhandled_input(event: InputEvent) -> void:
	if not active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x*sensitivity
		pitch = clampf(pitch-event.relative.y*sensitivity,-78,78)

func _physics_process(delta: float) -> void:
	if survival == null: return
	var wish_crouch := active and Input.is_action_pressed("crouch")
	if crouched and not wish_crouch:
		var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.1,global_position+Vector3.UP*1.85,1)
		wish_crouch = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	crouched = wish_crouch
	var cap := capsule_shape.shape as CapsuleShape3D
	cap.height = 1.18 if crouched else 1.78
	capsule_shape.position.y = cap.height/2
	var input := Input.get_vector("move_left","move_right","move_forward","move_back") if active else Vector2.ZERO
	sprinting = active and not crouched and input.length()>.1 and Input.is_action_pressed("sprint") and survival.stamina>3
	if sprinting:
		if not survival.spend_stamina(delta*12*(1.15 if survival.armor()>0 else 1.0)): sprinting = false
		else: survival.hydration=maxf(0,survival.hydration-delta*.018)
	var speed: float = (4.05 if sprinting else (1.22 if crouched else 2.50))*survival.speed_multiplier()
	if operating: speed *= .4
	var direction := input.rotated(-rotation.y)
	var smoothing := 1-exp(-13*delta)
	velocity.x = lerpf(velocity.x,direction.x*speed+impulse.x,smoothing)
	velocity.z = lerpf(velocity.z,direction.y*speed+impulse.z,smoothing)
	if not is_on_floor(): velocity += get_gravity()*delta
	move_and_slide()
	impulse = impulse.move_toward(Vector3.ZERO,delta*7)
	moving = Vector2(velocity.x,velocity.z).length()>.2
	if moving and is_on_floor():
		walking_time += delta*speed*3.2
		step_clock += delta*speed
		if step_clock>1.25:
			step_clock = 0
			stepped.emit()
	kick = move_toward(kick,0,delta*12)
	roll = move_toward(roll,0,delta*10)
	camera.position.y = lerpf(camera.position.y,(1.08 if crouched else 1.64)+(sin(walking_time)*.012 if head_bob and moving else 0.0),1-exp(-12*delta))
	camera.rotation_degrees = Vector3(pitch+kick*shake_strength,0,roll*shake_strength)

func recoil(amount: float, side: float = 1.0) -> void:
	kick = amount
	roll = side*amount*.55
