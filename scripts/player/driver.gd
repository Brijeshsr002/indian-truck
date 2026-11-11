class_name Driver
extends CharacterBody3D
## Playable truck driver on foot. Placeholder low-poly model (shirt, white veshti
## with green border, towel on the shoulder) with a procedural walk cycle.

const WALK_SPEED := 2.0
const RUN_SPEED := 5.0
const ACCEL := 10.0
const GRAVITY := 9.8

const SKIN := Color(0.55, 0.36, 0.24)
const SHIRT := Color(0.55, 0.72, 0.88)
const VESHTI := Color(0.95, 0.94, 0.9)
const BORDER := Color(0.1, 0.5, 0.25)
const HAIR := Color(0.06, 0.05, 0.05)
const TOWEL := Color(0.8, 0.15, 0.12)

## x = right, y = forward, relative to the camera.
var move_input := Vector2.ZERO
var running := false
var cam_yaw := 0.0

var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _anim_t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	_build_model()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	var b := Basis(Vector3.UP, cam_yaw)
	var fwd := -b.z
	var right := b.x
	var dir := fwd * move_input.y + right * move_input.x
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var spd := RUN_SPEED if running else WALK_SPEED
	var target := dir * spd
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	move_and_slide()
	if global_position.y < -20.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)
		velocity = Vector3.ZERO
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 0.2:
		var want := atan2(velocity.x, velocity.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, want, clampf(10.0 * delta, 0.0, 1.0))
	_animate(delta, hspeed)


func _animate(delta: float, hspeed: float) -> void:
	var amp := clampf(hspeed / RUN_SPEED, 0.0, 1.0) * 0.75 + (0.2 if hspeed > 0.2 else 0.0)
	_anim_t += delta * (2.5 + hspeed * 2.2)
	var swing := sin(_anim_t) * amp
	if hspeed < 0.2:
		swing = lerpf(_legs[0].rotation.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8


func face_yaw(yaw: float) -> void:
	if _model:
		_model.rotation.y = yaw


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var b := MeshBatcher.new()
	# veshti (wrap) and green border
	b.add_cylinder(Transform3D(Basis(), Vector3(0, 0.66, 0)), 0.29, 0.21, 0.62, 10, VESHTI)
	b.add_cylinder(Transform3D(Basis(), Vector3(0, 0.38, 0)), 0.295, 0.285, 0.06, 10, BORDER, false)
	# shirt
	b.add_box(Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(0.44, 0.52, 0.25), SHIRT)
	b.add_box(Transform3D(Basis(), Vector3(0, 1.45, 0.02)), Vector3(0.2, 0.05, 0.2), SHIRT.darkened(0.15))
	for i in range(4):
		b.add_box(Transform3D(Basis(), Vector3(0, 1.36 - i * 0.12, 0.128)), Vector3(0.02, 0.02, 0.01), Color.WHITE)
	# towel over the right shoulder
	b.add_box(Transform3D(Basis(Vector3.FORWARD, 0.15), Vector3(-0.17, 1.38, 0.0)), Vector3(0.12, 0.08, 0.3), TOWEL)
	b.add_box(Transform3D(Basis(), Vector3(-0.2, 1.22, 0.14)), Vector3(0.1, 0.32, 0.02), TOWEL)
	# neck and head
	b.add_cylinder(Transform3D(Basis(), Vector3(0, 1.5, 0)), 0.055, 0.055, 0.1, 6, SKIN)
	b.add_ellipsoid(Transform3D(Basis(), Vector3(0, 1.62, 0.0)), Vector3(0.105, 0.13, 0.115), SKIN, 5, 8)
	b.add_ellipsoid(Transform3D(Basis(), Vector3(0, 1.68, -0.015)), Vector3(0.11, 0.09, 0.12), HAIR, 4, 8)
	b.add_box(Transform3D(Basis(), Vector3(0, 1.575, 0.112)), Vector3(0.09, 0.018, 0.015), HAIR)
	for sx: float in [-0.04, 0.04]:
		b.add_box(Transform3D(Basis(), Vector3(sx, 1.635, 0.108)), Vector3(0.022, 0.015, 0.01), HAIR)
	b.add_box(Transform3D(Basis(), Vector3(0, 1.665, 0.112)), Vector3(0.012, 0.03, 0.006), Color(0.8, 0.1, 0.1))
	MeshKit.mesh_instance(_model, b.commit())
	# legs (pivot at hip)
	for sx: float in [-0.1, 0.1]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.9, 0)
		_model.add_child(leg)
		var lb := MeshBatcher.new()
		lb.add_cylinder(Transform3D(Basis(), Vector3(0, -0.25, 0)), 0.075, 0.08, 0.45, 6, VESHTI)
		lb.add_cylinder(Transform3D(Basis(), Vector3(0, -0.66, 0)), 0.05, 0.06, 0.4, 6, SKIN)
		lb.add_box(Transform3D(Basis(), Vector3(0, -0.88, 0.05)), Vector3(0.1, 0.05, 0.24), Color(0.25, 0.15, 0.08))
		MeshKit.mesh_instance(leg, lb.commit())
		_legs.append(leg)
	# arms (pivot at shoulder)
	for sx: float in [-0.27, 0.27]:
		var arm := Node3D.new()
		arm.position = Vector3(sx, 1.4, 0)
		_model.add_child(arm)
		var ab := MeshBatcher.new()
		ab.add_cylinder(Transform3D(Basis(), Vector3(0, -0.13, 0)), 0.06, 0.065, 0.26, 6, SHIRT)
		ab.add_cylinder(Transform3D(Basis(), Vector3(0, -0.4, 0)), 0.045, 0.05, 0.3, 6, SKIN)
		ab.add_ellipsoid(Transform3D(Basis(), Vector3(0, -0.58, 0)), Vector3(0.045, 0.06, 0.035), SKIN, 3, 6)
		MeshKit.mesh_instance(arm, ab.commit())
		_arms.append(arm)


func get_state() -> Dictionary:
	return {"pos": SaveSystem.vec3_to_array(global_position), "yaw": _model.rotation.y if _model else 0.0}


func apply_state(d: Dictionary) -> void:
	if d.has("pos"):
		global_position = SaveSystem.array_to_vec3(d["pos"])
	face_yaw(float(d.get("yaw", 0.0)))
	velocity = Vector3.ZERO
