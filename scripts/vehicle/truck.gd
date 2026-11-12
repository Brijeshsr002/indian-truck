class_name Truck
extends VehicleBody3D
## Heavy 6x4 rigid truck (original design): engine, gearbox, brakes, steering,
## lights, horns and audio. Controls are plain fields so the player, AI or tests
## can drive it. Faces +Z. Right-hand drive.

signal notify(text: String)

const EMPTY_MASS := 9000.0
const WHEEL_RADIUS := 0.52
const GEARS := [6.5, 4.2, 2.8, 1.9, 1.35, 1.0]
const REVERSE_RATIO := 6.0
const FINAL_DRIVE := 5.0
const DRIVETRAIN_EFF := 0.85
const IDLE_RPM := 650.0
const SHIFT_UP_RPM := 1950.0
const SHIFT_DOWN_RPM := 1000.0
const MAX_RPM := 2500.0
const GOVERNOR_KMH := 80.0
const REVERSE_LIMIT_KMH := 15.0
const FUEL_CAPACITY := 400.0
const BRAKE_PER_WHEEL := 160.0
const HANDBRAKE_PER_WHEEL := 420.0
const ENGINE_BRAKE_PER_WHEEL := 12.0
const HOLD_BRAKE_PER_WHEEL := 60.0
const MAX_STEER_LOW := 0.55
const MAX_STEER_HIGH := 0.12
const STEER_RATE := 0.9
const COCKPIT_EYE := Vector3(-0.55, 2.05, 3.35)
const DOOR_RIGHT_LOCAL := Vector3(-2.4, 0.0, 3.7)
const DOOR_LEFT_LOCAL := Vector3(2.4, 0.0, 3.7)
## Wipers: seconds per full sweep (up and back) for slow and fast, and sweep angle.
const WIPER_PERIODS := [0.0, 1.7, 0.85]
const WIPER_SWEEP_DEG := 95.0
const WIPER_MODE_NAMES := ["off", "slow", "fast"]

# ---- controls
var throttle_input := 0.0
var brake_input := 0.0
var steer_input := 0.0
var handbrake_on := true

# ---- state
var engine_on := false
var rpm := 0.0
var gear := 1
var auto_transmission := true
var fuel := 300.0
var headlights_on := false
var indicator := 0
var wiper_mode := 0  # 0 off, 1 slow, 2 fast
var speed_kmh := 0.0
var forward_speed := 0.0
var cargo_mass := 0.0
var odometer_km := 0.0
var fuel_used_l := 0.0

var drive_wheels: Array[VehicleWheel3D] = []
var rear_wheels: Array[VehicleWheel3D] = []
var all_wheels: Array[VehicleWheel3D] = []
var horn: HornController
var engine_audio: EngineAudio
var cockpit_anchor: Node3D
var steering_spinner: Node3D
var photo: DashboardPhoto
## "detailed" (Blender model, TruckVisual) or "simple" (fallback TruckModel).
var model_kind := ""

var _driven_rpm := 0.0
var _shift_timer := 0.0
var _steer_current := 0.0
var _start_timer := 0.0
var _blink_t := 0.0
var _blink_on := false
var _hb_warn_cooldown := 0.0
var _sfx: AudioStreamPlayer3D
var _cab_sfx: AudioStreamPlayer3D
var _mats := {}
var _headlights: Array[SpotLight3D] = []
var _lamp_key: Array = []
var _wipers: Array[Node3D] = []
var _wiper_rest: Array[Basis] = []
var _wiper_axis := Vector3.FORWARD
var _wiper_phase := 0.0  # 0..TAU per sweep; 0 = parked


func _ready() -> void:
	mass = EMPTY_MASS + cargo_mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.1, 0.4)
	can_sleep = false
	# Air and rolling drag are modelled in _apply_resistance(), so no default damping.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	_build_collision()
	_build_wheels()
	_mats = TruckVisual.build(self)
	model_kind = "detailed"
	if _mats.is_empty():
		_mats = TruckModel.build(self)
		model_kind = "simple"
	steering_spinner = _mats.get("spinner")
	_setup_wipers()
	_build_lights()
	_build_audio()
	cockpit_anchor = Node3D.new()
	cockpit_anchor.name = "CockpitEye"
	cockpit_anchor.position = COCKPIT_EYE
	add_child(cockpit_anchor)
	photo = DashboardPhoto.new()
	add_child(photo)
	GameConfig.cabin_photo_changed.connect(photo.rebuild)
	_update_light_visuals()


func _build_collision() -> void:
	MeshKit.col_box(self, Transform3D(Basis(), Vector3(0, 1.6, 3.72)), Vector3(2.46, 2.25, 2.2))
	MeshKit.col_box(self, Transform3D(Basis(), Vector3(0, 1.45, -1.2)), Vector3(2.5, 1.95, 6.8))
	MeshKit.col_box(self, Transform3D(Basis(), Vector3(0, 0.02, -0.3)), Vector3(1.2, 0.35, 9.6))


func _build_wheels() -> void:
	for sx: float in [1.0, -1.0]:
		_add_wheel(Vector3(1.0 * sx, 0.0, 3.4), true, false, false)
		_add_wheel(Vector3(0.95 * sx, 0.0, -1.8), false, true, true)
		_add_wheel(Vector3(0.95 * sx, 0.0, -3.1), false, true, true)


func _add_wheel(pos: Vector3, steer: bool, drive: bool, dual: bool) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.wheel_radius = WHEEL_RADIUS
	w.wheel_rest_length = 0.32
	w.suspension_travel = 0.2
	w.suspension_stiffness = 22.0
	w.suspension_max_force = 90000.0
	w.damping_compression = 1.6
	w.damping_relaxation = 2.2
	w.wheel_friction_slip = 1.15
	w.wheel_roll_influence = 0.08
	w.use_as_steering = steer
	w.use_as_traction = drive
	var mi := MeshInstance3D.new()
	var detailed := TruckVisual.wheel_mesh(dual)
	if detailed:
		mi.mesh = detailed
		# The model wheel faces +X; turn it round for the right-hand (-X) side.
		if pos.x < 0.0:
			mi.rotation.y = PI
	else:
		mi.mesh = TruckModel.wheel_mesh(dual, pos.x > 0.0)
	w.add_child(mi)
	add_child(w)
	all_wheels.append(w)
	if drive:
		drive_wheels.append(w)
	if not steer:
		rear_wheels.append(w)


func _build_lights() -> void:
	for sx: float in [1.0, -1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(0.86 * sx, 0.7, 5.0)
		l.rotation = Vector3(deg_to_rad(-3), PI, 0)
		l.spot_range = 90.0
		l.spot_angle = 30.0
		# Rebalanced for linear world colours and tonemap white 6 (was 5).
		l.light_energy = 22.0
		l.light_color = Color(1.0, 0.95, 0.85)
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_headlights.append(l)


func _build_audio() -> void:
	engine_audio = EngineAudio.new()
	engine_audio.name = "EngineAudio"
	engine_audio.position = Vector3(0, 0.8, 3.6)
	add_child(engine_audio)
	horn = HornController.new()
	horn.name = "Horns"
	horn.position = Vector3(0, 2.8, 3.8)
	add_child(horn)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = "SFX"
	_sfx.unit_size = 10.0
	_sfx.position = Vector3(0, 0.5, 0)
	add_child(_sfx)
	_cab_sfx = AudioStreamPlayer3D.new()
	_cab_sfx.bus = "SFX"
	_cab_sfx.unit_size = 2.0
	_cab_sfx.max_distance = 30.0
	_cab_sfx.position = COCKPIT_EYE
	_cab_sfx.stream = AudioSynth.tick()
	add_child(_cab_sfx)


func apply_graphics(p: Dictionary) -> void:
	for l in _headlights:
		l.shadow_enabled = bool(p.get("headlight_shadows", false))


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	var fwd := global_transform.basis.z
	forward_speed = linear_velocity.dot(fwd)
	speed_kmh = absf(forward_speed) * 3.6
	odometer_km += absf(forward_speed) * delta / 1000.0
	_hb_warn_cooldown = maxf(0.0, _hb_warn_cooldown - delta)
	_update_engine(delta)
	_update_transmission(delta)
	_apply_drive()
	_update_steering(delta)
	_apply_resistance()
	_update_blinkers(delta)
	_update_light_visuals()
	if engine_audio:
		engine_audio.rpm = rpm
		engine_audio.throttle = throttle_input if engine_on else 0.0
		engine_audio.running = engine_on or _start_timer > 0.0


func current_ratio() -> float:
	if gear > 0:
		return float(GEARS[gear - 1])
	if gear < 0:
		return REVERSE_RATIO
	return 0.0


## Effective torque curve (Nm), tuned so a 9 t truck feels heavy but drivable.
func torque_at(r: float) -> float:
	if r < 800.0:
		return lerpf(380.0, 520.0, clampf((r - 500.0) / 300.0, 0.0, 1.0))
	if r < 1200.0:
		return lerpf(520.0, 650.0, (r - 800.0) / 400.0)
	if r < 1700.0:
		return 650.0
	if r < 2300.0:
		return lerpf(650.0, 520.0, (r - 1700.0) / 600.0)
	return lerpf(520.0, 0.0, clampf((r - 2300.0) / 200.0, 0.0, 1.0))


func _update_engine(delta: float) -> void:
	var wheel_rpm := absf(forward_speed) / (TAU * WHEEL_RADIUS) * 60.0
	_driven_rpm = wheel_rpm * current_ratio() * FINAL_DRIVE
	if _start_timer > 0.0:
		_start_timer -= delta
		rpm = move_toward(rpm, 280.0, 700.0 * delta)
		if _start_timer <= 0.0:
			engine_on = true
			rpm = IDLE_RPM + 200.0
			notify.emit("Engine started. Press %s to release the parking brake." % GameConfig.key_name("handbrake") if handbrake_on else "Engine started.")
		return
	if not engine_on:
		rpm = move_toward(rpm, 0.0, 900.0 * delta)
		return
	if fuel <= 0.0:
		fuel = 0.0
		engine_on = false
		notify.emit("Out of diesel. The engine has stopped.")
		return
	var target: float
	if gear == 0 or _shift_timer > 0.0:
		target = IDLE_RPM + throttle_input * 1500.0
	elif _driven_rpm < 1000.0:
		target = maxf(_driven_rpm, IDLE_RPM + throttle_input * 450.0)
	else:
		target = _driven_rpm
	rpm = lerpf(rpm, clampf(target, IDLE_RPM * 0.95, MAX_RPM), clampf(8.0 * delta, 0.0, 1.0))
	var fuel_rate := float(GameConfig.settings.get("fuel_rate", 0.5))
	var litres_per_hour := (2.2 + 38.0 * throttle_input * (rpm / 2000.0)) * fuel_rate
	var used := litres_per_hour / 3600.0 * delta
	fuel = maxf(0.0, fuel - used)
	fuel_used_l += used


func _update_transmission(delta: float) -> void:
	if _shift_timer > 0.0:
		_shift_timer -= delta
	if not auto_transmission or not engine_on or _shift_timer > 0.0:
		return
	if gear == 0 and throttle_input > 0.05:
		gear = 1
		return
	if gear <= 0:
		return
	if _driven_rpm > SHIFT_UP_RPM and gear < GEARS.size() and throttle_input > 0.05:
		_shift_to(gear + 1)
	elif gear > 1 and (_driven_rpm < SHIFT_DOWN_RPM or (throttle_input > 0.9 and _driven_rpm < 1200.0)):
		_shift_to(gear - 1)


func _shift_to(g: int) -> void:
	gear = g
	_shift_timer = 0.45


func _apply_drive() -> void:
	var force := 0.0
	var can_drive := engine_on and gear != 0 and _shift_timer <= 0.0 and brake_input < 0.05
	if engine_on and gear == 0 and throttle_input > 0.01 and _hb_warn_cooldown <= 0.0:
		notify.emit("Gearbox is in neutral (N). Press %s for 1st gear, or %s for the automatic gearbox." % [GameConfig.key_name("gear_up"), GameConfig.key_name("transmission_mode")])
		_hb_warn_cooldown = 4.0
	if can_drive and throttle_input > 0.01:
		if handbrake_on:
			if _hb_warn_cooldown <= 0.0:
				notify.emit("Parking brake is on. Press %s to release it." % GameConfig.key_name("handbrake"))
				_hb_warn_cooldown = 4.0
		else:
			var torque := torque_at(rpm) * throttle_input
			if rpm >= MAX_RPM - 30.0:
				torque = 0.0
			force = torque * current_ratio() * FINAL_DRIVE * DRIVETRAIN_EFF / WHEEL_RADIUS
			if gear > 0 and speed_kmh > GOVERNOR_KMH:
				force = 0.0
			if gear < 0:
				force = -force
				if speed_kmh > REVERSE_LIMIT_KMH:
					force = 0.0
	var per_wheel := force / float(drive_wheels.size())
	var coasting := engine_on and gear > 0 and throttle_input < 0.01 and speed_kmh > 4.0
	var service := brake_input * BRAKE_PER_WHEEL
	# Hold brake: the truck never creeps unless the driver presses the accelerator.
	var hold := throttle_input < 0.01 and speed_kmh < 2.0
	for w in all_wheels:
		var wb := service
		if hold:
			wb = maxf(wb, HOLD_BRAKE_PER_WHEEL)
		if coasting and w.use_as_traction:
			wb = maxf(wb, ENGINE_BRAKE_PER_WHEEL)
		if handbrake_on and not w.use_as_steering:
			wb = maxf(wb, HANDBRAKE_PER_WHEEL)
		w.brake = wb
		# Godot ignores brakes on a wheel while it has engine force, so only
		# driven wheels without braking receive force.
		w.engine_force = per_wheel if (w.use_as_traction and wb <= 0.0) else 0.0


func _update_steering(delta: float) -> void:
	var t := clampf(speed_kmh / 70.0, 0.0, 1.0)
	var max_steer := lerpf(MAX_STEER_LOW, MAX_STEER_HIGH, t)
	var target := clampf(steer_input, -1.0, 1.0) * max_steer
	var rate := STEER_RATE
	if absf(target) < absf(_steer_current):
		rate *= 1.6
	_steer_current = move_toward(_steer_current, target, rate * delta)
	steering = _steer_current
	if steering_spinner:
		steering_spinner.rotation.y = _steer_current * 7.0


func _apply_resistance() -> void:
	var v := linear_velocity
	var hs := Vector3(v.x, 0.0, v.z)
	var spd := hs.length()
	if spd < 0.3:
		return
	var grounded := false
	for w in all_wheels:
		if w.is_in_contact():
			grounded = true
			break
	if not grounded:
		return
	var f := 0.007 * mass * 9.8 + 3.6 * spd * spd
	apply_central_force(-hs / spd * f)


func _update_blinkers(delta: float) -> void:
	_blink_t += delta
	var on := indicator != 0 and fmod(_blink_t, 0.7) < 0.35
	if on != _blink_on:
		_blink_on = on
		if indicator != 0 and _cab_sfx:
			_cab_sfx.play()


func _update_light_visuals() -> void:
	if _mats.is_empty():
		return
	# Only touch the materials when a lamp actually changes state.
	var key := [brake_input > 0.05, gear < 0, headlights_on, _blink_on, indicator]
	if key == _lamp_key:
		return
	_lamp_key = key
	var tail := 0.5 if headlights_on else 0.0
	(_mats["brake"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if brake_input > 0.05 else tail
	(_mats["reverse"] as StandardMaterial3D).emission_energy_multiplier = 2.5 if gear < 0 else 0.0
	(_mats["head"] as StandardMaterial3D).emission_energy_multiplier = 4.0 if headlights_on else 0.15
	(_mats["ind_l"] as StandardMaterial3D).emission_energy_multiplier = 4.0 if (_blink_on and indicator < 0) else 0.0
	(_mats["ind_r"] as StandardMaterial3D).emission_energy_multiplier = 4.0 if (_blink_on and indicator > 0) else 0.0



# ---------------------------------------------------------------- wipers

func _setup_wipers() -> void:
	for w in _mats.get("wipers", []):
		if w is Node3D:
			_wipers.append(w)
			_wiper_rest.append((w as Node3D).basis)
	# Rotate about the windscreen normal (the glass leans back about 10.7 degrees).
	_wiper_axis = Vector3(0.0, sin(deg_to_rad(10.7)), cos(deg_to_rad(10.7))).normalized()


func has_wipers() -> bool:
	return not _wipers.is_empty()


## Current wiper arm angle in degrees (0 = parked).
func wiper_angle_deg() -> float:
	return WIPER_SWEEP_DEG * (0.5 - 0.5 * cos(_wiper_phase))


func _process(delta: float) -> void:
	_update_wipers(delta)


func _update_wipers(delta: float) -> void:
	if _wipers.is_empty():
		return
	if wiper_mode > 0:
		_wiper_phase = fmod(_wiper_phase + TAU * delta / float(WIPER_PERIODS[wiper_mode]), TAU)
	elif _wiper_phase > 0.0:
		# Switched off: finish the sweep at slow speed and park, like a real wiper motor.
		_wiper_phase += TAU * delta / float(WIPER_PERIODS[1])
		if _wiper_phase >= TAU:
			_wiper_phase = 0.0
	else:
		return
	# Negative rotation about the forward-facing normal lifts the arms upwards.
	var rot := Basis(_wiper_axis, -deg_to_rad(wiper_angle_deg()))
	for i in _wipers.size():
		_wipers[i].basis = rot * _wiper_rest[i]


func cycle_wipers() -> void:
	if not has_wipers():
		notify.emit("This truck model has no wipers.")
		return
	set_wipers((wiper_mode + 1) % 3)
	notify.emit("Wipers %s." % WIPER_MODE_NAMES[wiper_mode])


func set_wipers(mode: int) -> void:
	# A model without wipers keeps them off, so the dashboard lamp never lies.
	wiper_mode = clampi(mode, 0, 2) if has_wipers() else 0

# ---------------------------------------------------------------- driver commands

func set_controls(throttle: float, brake_amount: float, steer: float) -> void:
	throttle_input = clampf(throttle, 0.0, 1.0)
	brake_input = clampf(brake_amount, 0.0, 1.0)
	steer_input = clampf(steer, -1.0, 1.0)


func toggle_engine() -> void:
	if _start_timer > 0.0:
		return
	if engine_on:
		engine_on = false
		notify.emit("Engine off.")
		return
	if fuel <= 0.0:
		notify.emit("The fuel tank is empty.")
		return
	_start_timer = 1.1
	_play_sfx(AudioSynth.engine_start())
	notify.emit("Starting engine...")


func set_handbrake(on: bool) -> void:
	if on == handbrake_on:
		return
	handbrake_on = on
	_play_sfx(AudioSynth.air_brake())


func toggle_handbrake() -> void:
	set_handbrake(not handbrake_on)
	notify.emit("Parking brake applied." if handbrake_on else "Parking brake released.")


func toggle_headlights() -> void:
	headlights_on = not headlights_on
	for l in _headlights:
		l.visible = headlights_on
	notify.emit("Headlights on." if headlights_on else "Headlights off.")


func set_headlights(on: bool) -> void:
	headlights_on = on
	for l in _headlights:
		l.visible = on


func toggle_indicator(direction: int) -> void:
	indicator = 0 if indicator == direction else direction
	_blink_t = 0.0


func toggle_reverse() -> void:
	if speed_kmh > 3.0:
		notify.emit("Stop the truck before changing direction.")
		return
	if gear < 0:
		gear = 1
		notify.emit("Forward gear selected.")
	else:
		gear = -1
		notify.emit("Reverse gear selected.")


func toggle_transmission() -> void:
	auto_transmission = not auto_transmission
	if auto_transmission and gear == 0:
		gear = 1
	notify.emit("Automatic gearbox." if auto_transmission else "Manual gearbox. Shift with %s and %s." % [GameConfig.key_name("gear_up"), GameConfig.key_name("gear_down")])


func shift_up() -> void:
	if auto_transmission:
		notify.emit("Gearbox is automatic. Press %s for manual." % GameConfig.key_name("transmission_mode"))
		return
	if gear < 0:
		gear = 0
	elif gear < GEARS.size():
		gear += 1
		_shift_timer = 0.3


func shift_down() -> void:
	if auto_transmission:
		return
	if gear > 0:
		gear -= 1
		_shift_timer = 0.3


func gear_label() -> String:
	if gear < 0:
		return "R"
	if gear == 0:
		return "N"
	return ("A" if auto_transmission else "M") + str(gear)


func door_positions() -> Array:
	return [global_transform * DOOR_RIGHT_LOCAL, global_transform * DOOR_LEFT_LOCAL]


func distance_to_door(p: Vector3) -> float:
	var best := INF
	for d in door_positions():
		var dv: Vector3 = d
		best = minf(best, Vector2(p.x - dv.x, p.z - dv.z).length() + maxf(0.0, absf(p.y - dv.y) - 2.0))
	return best


func _play_sfx(stream: AudioStream) -> void:
	if _sfx:
		_sfx.stream = stream
		_sfx.play()


# ---------------------------------------------------------------- save / load

func get_state() -> Dictionary:
	return {
		"xform": SaveSystem.xform_to_array(global_transform),
		"engine_on": engine_on, "fuel": fuel, "gear": gear, "auto": auto_transmission,
		"lights": headlights_on, "handbrake": handbrake_on, "odometer": odometer_km,
		"fuel_used": fuel_used_l,
		"wipers": wiper_mode,
	}


func apply_state(d: Dictionary) -> void:
	if d.has("xform"):
		global_transform = SaveSystem.array_to_xform(d["xform"])
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	engine_on = bool(d.get("engine_on", false))
	rpm = IDLE_RPM if engine_on else 0.0
	fuel = clampf(float(d.get("fuel", 300.0)), 0.0, FUEL_CAPACITY)
	gear = clampi(int(d.get("gear", 1)), -1, GEARS.size())
	handbrake_on = bool(d.get("handbrake", true))
	odometer_km = float(d.get("odometer", 0.0))
	fuel_used_l = float(d.get("fuel_used", 0.0))
	set_headlights(bool(d.get("lights", false)))
	set_wipers(int(d.get("wipers", 0)))
