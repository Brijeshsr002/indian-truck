extends Node3D
## Gameplay scene. Builds world, truck, driver, camera, HUD and pause menu, and
## routes input. Also supports command-line benchmark / screenshot runs:
##   IndianTruckSimulator.exe -- --bench --frames=900 --out=C:/path/result.txt --shot=C:/path/shot.png
## Options: --cam=chase|cockpit|bumper|top|foot  --hour=18  --autodrive  --spawn=x,z,yaw_degrees
##          --preset=low|medium|high (this run only; the saved setting is kept)
##          --lights (headlights on)  --wipers=1|2 (slow or fast)

enum PlayMode { DRIVING, ON_FOOT }

const AUTOSAVE_SECONDS := 120.0
const DAY_MINUTES_PER_SECOND := 1.0

var mode: int = PlayMode.DRIVING
var world: CoimbatoreWorld
var truck: Truck
var driver: Driver
var rig: CameraRig
var hud: HUD
var pause_menu: PauseMenu
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var game_minutes := 8.0 * 60.0

## Tests set these before adding the scene to the tree.
var external_control := false
var spawn_override: Variant = null

var _autosave_t := 0.0
var _cli := {}
var _bench_frames := 0
var _bench_time := 0.0
var _bench_min_fps := 9999.0
var _night := false
var _daylight_t := 0.0


func _ready() -> void:
	_parse_cli()
	_build_environment()
	world = CoimbatoreWorld.new()
	world.name = "World"
	add_child(world)

	truck = Truck.new()
	truck.name = "Truck"
	truck.transform = _initial_truck_transform()
	truck.auto_transmission = bool(GameConfig.settings.get("auto_transmission", true))
	add_child(truck)
	truck.notify.connect(_on_notify)

	driver = Driver.new()
	driver.name = "Driver"
	add_child(driver)
	driver.global_position = truck.global_transform * Truck.DOOR_RIGHT_LOCAL + Vector3(0, 0.1, 0)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(truck, driver)

	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(self)

	GameConfig.settings_changed.connect(_apply_settings)
	_apply_settings()
	world.streamer.target = truck
	world.streamer.update_now(true)
	_set_mode(PlayMode.DRIVING)

	var loaded := false
	if GameConfig.load_on_start:
		GameConfig.load_on_start = false
		loaded = load_game()
	if _cli.has("hour"):
		game_minutes = float(_cli["hour"]) * 60.0
	if _cli.has("cam"):
		match String(_cli["cam"]):
			"cockpit":
				rig.set_mode(CameraRig.Mode.COCKPIT)
			"bumper":
				rig.set_mode(CameraRig.Mode.BUMPER)
			"top":
				rig.set_mode(CameraRig.Mode.TOP)
			"foot":
				exit_truck()
	if _cli.has("lights"):
		truck.set_headlights(true)
	if _cli.has("wipers"):
		truck.set_wipers(int(_cli["wipers"]))
	if _cli.has("autodrive"):
		truck.engine_on = true
		truck.rpm = Truck.IDLE_RPM
		truck.handbrake_on = false
	_update_daylight()
	# Benchmark and screenshot runs never grab the mouse, so moving it cannot turn the camera.
	if not _is_headless() and not external_control and not (_cli.has("bench") or _cli.has("shot")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not loaded:
		hud.notify("Vanakkam! Welcome to Coimbatore. Press %s for controls." % GameConfig.key_name("help"), 6.0)
		hud.notify("Press %s to start the engine, %s to release the parking brake." % [GameConfig.key_name("engine"), GameConfig.key_name("handbrake")], 7.0)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.substr(2).split("=", true, 1)
		_cli[parts[0]] = parts[1] if parts.size() > 1 else "1"
	# Benchmark a preset for this run only; the saved setting is not changed.
	if (_cli.has("bench") or _cli.has("shot")) and _cli.has("preset") and GameConfig.PRESETS.has(String(_cli["preset"])):
		GameConfig.set_setting("graphics_preset", String(_cli["preset"]), false)


func _initial_truck_transform() -> Transform3D:
	if spawn_override != null:
		return spawn_override
	if _cli.has("spawn"):
		var v := String(_cli["spawn"]).split(",")
		if v.size() == 3:
			return Transform3D(Basis(Vector3.UP, deg_to_rad(float(v[2]))), Vector3(float(v[0]), 1.1, float(v[1])))
	return world.spawn_transform


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A white point of 1.0 clipped sunlit ground to pure white. 6.0 keeps highlights
	# (light concrete, white paint) readable; the sun is raised to match.
	env.tonemap_white = 6.0
	# Part of the ambient light is a warm neutral, so sunlit ground is not tinted
	# cyan by the blue sky.
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.85, 0.82, 0.76)
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.78, 0.8)
	env.fog_sky_affect = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)


func _apply_settings() -> void:
	var p := GameConfig.preset()
	GameConfig.apply_graphics(get_viewport(), env, sun, rig.camera)
	truck.apply_graphics(p)
	truck.horn.combined = bool(GameConfig.settings.get("combined_horn", false))
	# Settings are the single source of truth for the gearbox mode.
	var want_auto := bool(GameConfig.settings.get("auto_transmission", true))
	if truck.auto_transmission != want_auto:
		truck.auto_transmission = want_auto
		if want_auto and truck.gear == 0:
			truck.gear = 1
	world.streamer.radius = float(p["stream_radius"])


# ---------------------------------------------------------------- frame loop

func _physics_process(_delta: float) -> void:
	if external_control:
		return
	if mode == PlayMode.DRIVING:
		if _cli.has("autodrive"):
			truck.set_controls(0.6, 0.0, 0.0)
		else:
			truck.set_controls(Input.get_action_strength("accelerate"), Input.get_action_strength("brake"),
				Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right"))
	else:
		truck.set_controls(0.0, 0.0, 0.0)
		driver.move_input = Vector2(
			Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"),
			Input.get_action_strength("accelerate") - Input.get_action_strength("brake"))
		driver.running = Input.is_action_pressed("run")
	driver.cam_yaw = rig.yaw


func _process(delta: float) -> void:
	game_minutes = fmod(game_minutes + delta * DAY_MINUTES_PER_SECOND, 1440.0)
	_daylight_t -= delta
	if _daylight_t <= 0.0:
		_daylight_t = 0.5  # sky and sun change slowly; no need to update every frame
		_update_daylight()
	if mode == PlayMode.DRIVING and not external_control:
		for i in range(3):
			truck.horn.set_horn(i, Input.is_action_pressed("horn_%d" % (i + 1)))
	if not external_control and not _cli.has("bench"):
		_autosave_t += delta
		if _autosave_t >= AUTOSAVE_SECONDS:
			_autosave_t = 0.0
			save_game(SaveSystem.SAVE_PATH, true)
	if _cli.has("bench") or _cli.has("shot"):
		_bench_step(delta)


func _bench_step(delta: float) -> void:
	_bench_frames += 1
	var warmup := 90
	if _bench_frames > warmup:
		_bench_time += delta
		if delta > 0.0:
			_bench_min_fps = minf(_bench_min_fps, 1.0 / delta)
	var target := int(_cli.get("frames", "600"))
	if _bench_frames >= warmup + target:
		var avg := float(target) / maxf(_bench_time, 0.001)
		var report := "frames=%d avg_fps=%.1f worst_frame_fps=%.1f renderer=%s gpu=%s preset=%s chunks=%d truck_pos=%s speed_kmh=%.1f" % [
			target, avg, _bench_min_fps, RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name(), GameConfig.settings.get("graphics_preset", "low"),
			world.streamer.loaded_count(), str(truck.global_position.snapped(Vector3(0.1, 0.1, 0.1))), truck.speed_kmh]
		print(report)
		if _cli.has("out"):
			var f := FileAccess.open(String(_cli["out"]), FileAccess.WRITE)
			if f:
				f.store_string(report + "\n")
				f.close()
		if _cli.has("shot"):
			var img := get_viewport().get_texture().get_image()
			img.save_png(String(_cli["shot"]))
		get_tree().quit()


func _update_daylight() -> void:
	var hours := game_minutes / 60.0
	var a := (hours - 6.0) / 12.0 * PI
	var elev := sin(a)
	var s := Vector3(cos(a), sin(a), 0.35).normalized()
	var day := clampf(elev * 3.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)
	if elev > -0.05:
		sun.global_transform.basis = Basis.looking_at(-s, Vector3.UP if absf(s.y) < 0.99 else Vector3.FORWARD)
		sun.light_energy = 0.2 + 2.2 * day
		sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.6, 0.35), dusk)
	else:
		var m := Vector3(-cos(a), -sin(a), 0.35).normalized()
		sun.global_transform.basis = Basis.looking_at(-m, Vector3.UP)
		sun.light_energy = 0.3  # moonlight, rebalanced with the day sun
		sun.light_color = Color(0.55, 0.65, 0.9)
	var night_top := Color(0.02, 0.03, 0.08)
	var day_top := Color(0.28, 0.5, 0.82)
	var day_hor := Color(0.72, 0.8, 0.86)
	var dusk_hor := Color(0.95, 0.6, 0.38)
	var hor := day_hor.lerp(dusk_hor, dusk)
	sky_mat.sky_top_color = night_top.lerp(day_top, day)
	sky_mat.sky_horizon_color = Color(0.05, 0.06, 0.1).lerp(hor, clampf(day + dusk * 0.6, 0.0, 1.0))
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.1)
	env.ambient_light_energy = 0.25 + 0.6 * day
	env.fog_light_color = sky_mat.sky_horizon_color
	var night := elev < 0.05
	if night != _night:
		_night = night
		world.set_night(night)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if external_control:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rig.handle_mouse((event as InputEventMouseMotion).relative)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("pause"):
		truck.horn.release_all()
		pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("help"):
		hud.toggle_help()
	elif event.is_action_pressed("map"):
		hud.toggle_map()
	elif event.is_action_pressed("quick_save"):
		save_game()
	elif event.is_action_pressed("quick_load"):
		reload_from_save()
	elif event.is_action_pressed("interact"):
		if mode == PlayMode.DRIVING:
			exit_truck()
		else:
			try_enter_truck()
	if mode != PlayMode.DRIVING:
		return
	if event.is_action_pressed("camera"):
		rig.cycle_truck_camera()
		hud.notify(rig.camera_name(), 1.5)
		return
	for i in range(4):
		if event.is_action_pressed("camera_%d" % (i + 1)):
			rig.set_truck_camera(i)
			hud.notify(rig.camera_name(), 1.5)
			return
	if event.is_action_pressed("refuel"):
		try_refuel()
		return
	if event.is_action_pressed("engine"):
		truck.toggle_engine()
	elif event.is_action_pressed("headlights"):
		truck.toggle_headlights()
	elif event.is_action_pressed("wipers"):
		truck.cycle_wipers()
	elif event.is_action_pressed("handbrake"):
		truck.toggle_handbrake()
	elif event.is_action_pressed("reverse"):
		truck.toggle_reverse()
	elif event.is_action_pressed("transmission_mode"):
		truck.toggle_transmission()
		# Through set_setting so the settings menu checkbox and listeners stay in sync.
		GameConfig.set_setting("auto_transmission", truck.auto_transmission)
	elif event.is_action_pressed("indicator_left"):
		truck.toggle_indicator(-1)
	elif event.is_action_pressed("indicator_right"):
		truck.toggle_indicator(1)
	if event.is_action_pressed("gear_up"):
		truck.shift_up()
	elif event.is_action_pressed("gear_down"):
		truck.shift_down()


# ---------------------------------------------------------------- modes

func _set_mode(m: int) -> void:
	mode = m
	if m == PlayMode.DRIVING:
		driver.visible = false
		driver.process_mode = Node.PROCESS_MODE_DISABLED
		driver.collision_layer = 0
		driver.collision_mask = 0
		rig.set_mode(rig.last_truck_mode)
		world.streamer.target = truck
	else:
		driver.visible = true
		driver.process_mode = Node.PROCESS_MODE_INHERIT
		driver.collision_layer = 4
		driver.collision_mask = 1 | 2
		rig.set_mode(CameraRig.Mode.ON_FOOT)
		world.streamer.target = driver


func is_driving() -> bool:
	return mode == PlayMode.DRIVING


func exit_truck() -> bool:
	if mode != PlayMode.DRIVING:
		return false
	if truck.speed_kmh > 5.0:
		hud.notify("Slow down below 5 km/h before getting out.")
		return false
	var spot: Variant = _find_exit_spot()
	if spot == null:
		hud.notify("There is no space to open the door here.")
		return false
	truck.set_controls(0.0, 0.0, 0.0)
	truck.horn.release_all()
	if not truck.handbrake_on:
		truck.set_handbrake(true)
	driver.global_position = spot
	driver.velocity = Vector3.ZERO
	var z := truck.global_transform.basis.z
	driver.face_yaw(atan2(z.x, z.z))
	_set_mode(PlayMode.ON_FOOT)
	hud.notify("Parking brake applied. You got down from the truck.")
	return true


func _find_exit_spot() -> Variant:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	for local in [Truck.DOOR_RIGHT_LOCAL, Truck.DOOR_LEFT_LOCAL, Vector3(0, 0, -6.5)]:
		var p: Vector3 = truck.global_transform * local
		# Cast down from just above the truck roof. Overhead structures (flyover
		# deck) are above the start point and ignored; a ray starting inside a
		# building passes through it, and the capsule check below rejects that spot.
		var start_y := truck.global_position.y + 3.5
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, start_y, p.z), Vector3(p.x, start_y - 15.0, p.z), 1)
		q.exclude = [truck.get_rid()]
		var hit := space.intersect_ray(q)
		var spot := Vector3(p.x, 0.05, p.z)
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			if hp.y > truck.global_position.y + 0.5:
				continue  # wall top or kerb too high to stand on
			spot = hp + Vector3(0, 0.05, 0)
		# Make sure the driver's body would not be inside anything.
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = capsule
		sq.transform = Transform3D(Basis(), spot + Vector3(0, 0.95, 0))
		sq.collision_mask = 1
		sq.exclude = [truck.get_rid()]
		if space.intersect_shape(sq, 1).is_empty():
			return spot
	return null


func try_enter_truck() -> bool:
	if mode != PlayMode.ON_FOOT:
		return false
	if truck.distance_to_door(driver.global_position) > 3.0:
		hud.notify("Walk to the truck door to get in.")
		return false
	_set_mode(PlayMode.DRIVING)
	hud.notify("You are in the driver's seat.")
	return true


const EMERGENCY_DIESEL_L := 40.0
const PUMP_RADIUS_M := 18.0


func at_fuel_pump() -> bool:
	for lm in world.landmarks:
		if String(lm["name"]) == "Kovai Fuels":
			var p: Vector2 = lm["pos"]
			return Vector2(truck.global_position.x - p.x, truck.global_position.z - p.y).length() < PUMP_RADIUS_M
	return false


## Fills the tank at the pump, or calls roadside assistance when empty elsewhere.
## Returns the litres added.
func try_refuel() -> float:
	if mode != PlayMode.DRIVING:
		return 0.0
	if truck.speed_kmh > 2.0:
		hud.notify("Stop the truck before refuelling.")
		return 0.0
	if at_fuel_pump():
		if truck.engine_on:
			hud.notify("Switch off the engine (%s) before refuelling." % GameConfig.key_name("engine"))
			return 0.0
		if truck.fuel >= Truck.FUEL_CAPACITY - 1.0:
			hud.notify("The tank is already full.")
			return 0.0
		var added := Truck.FUEL_CAPACITY - truck.fuel
		truck.fuel = Truck.FUEL_CAPACITY
		hud.notify("Tank full. Added %.0f litres of diesel." % added)
		return added
	if truck.fuel < 1.0:
		truck.fuel += EMERGENCY_DIESEL_L
		hud.notify("Roadside assistance brought %.0f litres of emergency diesel." % EMERGENCY_DIESEL_L)
		return EMERGENCY_DIESEL_L
	hud.notify("Refuel at the Kovai Fuels pumps on Avinashi Road (Peelamedu).")
	return 0.0


func prompt_text() -> String:
	if mode == PlayMode.DRIVING and truck.speed_kmh < 2.0:
		if at_fuel_pump() and truck.fuel < Truck.FUEL_CAPACITY - 1.0:
			return "Press %s to fill diesel (engine off)" % GameConfig.key_name("refuel")
		if truck.fuel < 1.0:
			return "Out of diesel. Press %s to call roadside assistance" % GameConfig.key_name("refuel")
	if mode == PlayMode.ON_FOOT:
		if truck.distance_to_door(driver.global_position) <= 3.0:
			return "Press %s to get in the truck" % GameConfig.key_name("interact")
		return ""
	if truck.speed_kmh < 1.0 and not truck.engine_on:
		return "Press %s to start the engine   |   %s to get down" % [GameConfig.key_name("engine"), GameConfig.key_name("interact")]
	return ""


func active_position() -> Vector3:
	return truck.global_position if mode == PlayMode.DRIVING else driver.global_position


func active_forward() -> Vector3:
	if mode == PlayMode.DRIVING:
		return truck.global_transform.basis.z
	return rig.forward_flat()


func _on_notify(text: String) -> void:
	hud.notify(text)


# ---------------------------------------------------------------- save / load

func save_game(path: String = SaveSystem.SAVE_PATH, silent := false) -> bool:
	var data := {
		"mode": "driving" if mode == PlayMode.DRIVING else "foot",
		"truck": truck.get_state(),
		"driver": driver.get_state(),
		"game_minutes": game_minutes,
		"camera": rig.last_truck_mode,
	}
	var res: Dictionary = SaveSystem.save_data(data, path)
	if not res["ok"]:
		hud.notify(String(res["error"]))
		return false
	if not silent:
		hud.notify("Game saved.")
	return true


func load_game(path: String = SaveSystem.SAVE_PATH) -> bool:
	var res: Dictionary = SaveSystem.load_data(path)
	if res.get("ok", false) and res.has("warning"):
		hud.notify(String(res["warning"]), 6.0)
	if not res["ok"]:
		hud.notify(String(res["error"]))
		return false
	var d: Dictionary = res["data"]
	truck.apply_state(d.get("truck", {}))
	driver.apply_state(d.get("driver", {}))
	game_minutes = float(d.get("game_minutes", 480.0))
	rig.last_truck_mode = int(d.get("camera", CameraRig.Mode.CHASE))
	_set_mode(PlayMode.ON_FOOT if String(d.get("mode", "driving")) == "foot" else PlayMode.DRIVING)
	if mode == PlayMode.ON_FOOT:
		var dd: Dictionary = d.get("driver", {})
		rig.yaw = float(dd.get("yaw", 0.0)) + PI  # camera behind the driver
	world.streamer.update_now(true)
	hud.notify("Saved game loaded.")
	return true


func reload_from_save() -> void:
	if not SaveSystem.has_save():
		hud.notify("No saved game found. Press %s to save." % GameConfig.key_name("quick_save"))
		return
	GameConfig.load_on_start = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not external_control and truck != null:
		save_game(SaveSystem.SAVE_PATH, true)
