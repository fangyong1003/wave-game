class_name RepairPlayer
extends CharacterBody3D
## Movement / look adapted from Colormatic's MIT Quality First Person Controller.
## See res://licenses/Colormatic-MIT.txt. Apartment-specific capsule, input and camera behavior.
signal stepped
var camera: Camera3D
var active := false
var sensitivity := 0.085
var head_bob := false
var pitch := 0.0
var walking_time := 0.0
var step_clock := 0.0
var operating := false

func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.78
	collision.shape = capsule
	collision.position.y = 0.89
	add_child(collision)
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.18
	camera = Camera3D.new()
	camera.position.y = 1.64
	camera.near = 0.045
	camera.far = 55.0
	camera.fov = 74
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if not active or operating or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -78, 78)
		camera.rotation_degrees.x = pitch

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input_dir := Vector2.ZERO if operating else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction2d := input_dir.rotated(-rotation.y)
	var speed := 1.1 if Input.is_action_pressed("walk_slow") else 2.4
	var smoothing := 1.0 - exp(-12.0 * delta)
	velocity.x = lerpf(velocity.x, direction2d.x * speed, smoothing)
	velocity.z = lerpf(velocity.z, direction2d.y * speed, smoothing)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if moving and is_on_floor():
		walking_time += delta * speed * 3.8
		step_clock += delta * speed
		if step_clock > 1.25:
			step_clock = 0
			stepped.emit()
	camera.position.y = 1.64 + (sin(walking_time) * 0.009 if head_bob and moving else 0.0)

func face(point: Vector3) -> void:
	var direction := (point - camera.global_position).normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	pitch = rad_to_deg(asin(direction.y))
	camera.rotation_degrees.x = pitch
