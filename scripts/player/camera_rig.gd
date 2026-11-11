class_name CameraRig
extends Node3D
## One camera with three modes: chase (third person), cockpit (first person) and
## on foot. A SpringArm stops the camera going through buildings.

enum Mode { CHASE, COCKPIT, ON_FOOT }

var mode: int = Mode.CHASE
var last_truck_mode: int = Mode.CHASE
var truck: Truck
var driver: Driver
var camera: Camera3D
var arm: SpringArm3D

var pitch := -0.22
var yaw := 0.0
var chase_yaw_offset := 0.0
var cockpit_yaw := 0.0
var cockpit_pitch := -0.1
var _chase_heading := 0.0
var _idle_look := 10.0


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.3
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	arm.shape = sh
	add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 70.0
	arm.add_child(camera)


func setup(t: Truck, d: Driver) -> void:
	truck = t
	driver = d
	arm.add_excluded_object(truck.get_rid())
	arm.add_excluded_object(driver.get_rid())
	_chase_heading = _heading_of(truck)


func set_mode(m: int) -> void:
	mode = m
	if m != Mode.ON_FOOT:
		last_truck_mode = m
	if m == Mode.ON_FOOT:
		yaw = _chase_heading + PI + chase_yaw_offset
		pitch = -0.2
	if m == Mode.CHASE:
		_chase_heading = _heading_of(truck)
	camera.near = 0.04 if m == Mode.COCKPIT else 0.1
	GameConfig.set_cabin_audio(m == Mode.COCKPIT)


func cycle_truck_camera() -> void:
	set_mode(Mode.COCKPIT if mode == Mode.CHASE else Mode.CHASE)


func handle_mouse(rel: Vector2) -> void:
	var s := float(GameConfig.settings.get("mouse_sensitivity", 0.25)) * 0.012
	match mode:
		Mode.CHASE:
			chase_yaw_offset -= rel.x * s
			pitch = clampf(pitch - rel.y * s, -1.2, 0.25)
			_idle_look = 0.0
		Mode.COCKPIT:
			cockpit_yaw = clampf(cockpit_yaw - rel.x * s, -2.3, 2.3)
			cockpit_pitch = clampf(cockpit_pitch - rel.y * s, -1.0, 0.7)
		Mode.ON_FOOT:
			yaw -= rel.x * s
			pitch = clampf(pitch - rel.y * s, -1.2, 0.6)


func _heading_of(n: Node3D) -> float:
	var z := n.global_transform.basis.z
	return atan2(z.x, z.z)


func _process(delta: float) -> void:
	if truck == null:
		return
	match mode:
		Mode.CHASE:
			var t := truck.global_transform
			_chase_heading = lerp_angle(_chase_heading, _heading_of(truck), clampf(3.0 * delta, 0.0, 1.0))
			_idle_look += delta
			if _idle_look > 2.5:
				chase_yaw_offset = lerp_angle(chase_yaw_offset, 0.0, clampf(1.5 * delta, 0.0, 1.0))
			global_transform = Transform3D(Basis.from_euler(Vector3(pitch, _chase_heading + PI + chase_yaw_offset, 0.0)), t.origin + Vector3(0, 3.2, 0))
			arm.spring_length = 13.0
		Mode.COCKPIT:
			var a := truck.cockpit_anchor.global_transform
			global_transform = Transform3D(a.basis * Basis.from_euler(Vector3(cockpit_pitch, cockpit_yaw + PI, 0.0)), a.origin)
			arm.spring_length = 0.0
		Mode.ON_FOOT:
			global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), driver.global_position + Vector3(0, 1.6, 0))
			arm.spring_length = 4.5


func forward_flat() -> Vector3:
	var f := -camera.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD
