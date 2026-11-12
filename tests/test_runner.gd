extends Node
## Headless gameplay tests. Run:
##   Godot_console.exe --headless --path . res://tests/test_runner.tscn --fixed-fps 60
## Exit code 0 = all passed.

const GameScene := preload("res://scenes/game.tscn")

var game: Node
var passes := 0
var failures := 0


func _ready() -> void:
	GameConfig.test_mode = true
	# Tests must not depend on the player's saved choices (for example the manual gearbox).
	GameConfig.settings["auto_transmission"] = true
	# Never touch the player's real dashboard photo.
	DashboardPhoto.user_image_path = "user://test_cabin_photo.png"
	call_deferred("_run")


func check(cond: bool, test_name: String, detail := "") -> void:
	if cond:
		passes += 1
		print("PASS  %s  %s" % [test_name, detail])
	else:
		failures += 1
		print("FAIL  %s  %s" % [test_name, detail])


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _new_game(spawn: Variant) -> void:
	if game != null:
		game.queue_free()
		await get_tree().process_frame
	game = GameScene.instantiate()
	game.set("external_control", true)
	game.set("spawn_override", spawn)
	add_child(game)
	await _frames(2)


func _upright(t: Truck) -> bool:
	return t.global_transform.basis.y.dot(Vector3.UP) > 0.9


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await _test_spawn_yard()
	await _test_truck_model()
	await _test_drive_flyover_brakes()
	await _test_open_ground()
	await _test_camera_keys()
	await _test_dashboard_photo()
	await _test_phase1_fixes()
	_test_settings()
	print("----")
	print("RESULT: %d passed, %d failed, %.1f s" % [passes, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(1 if failures > 0 else 0)


func _test_spawn_yard() -> void:
	await _new_game(null)
	var t: Truck = game.get("truck")
	await _frames(120)
	check(_upright(t), "spawn: truck upright in yard")
	check(t.global_position.y > 0.4 and t.global_position.y < 1.3, "spawn: truck rests on ground", "y=%.2f" % t.global_position.y)
	check(t.speed_kmh < 1.0, "spawn: truck stationary with parking brake", "%.2f km/h" % t.speed_kmh)
	check(not t.engine_on and t.handbrake_on, "control: new game starts with engine off and parking brake on")
	var world: CoimbatoreWorld = game.get("world")
	check(world.streamer.loaded_count() > 0, "world: chunks streamed in near spawn", "%d chunks" % world.streamer.loaded_count())
	check(world.chunk_specs.size() > 20, "world: chunk plan built", "%d chunks planned" % world.chunk_specs.size())
	check(world.location_name(t.global_position).length() > 3, "world: location name", world.location_name(t.global_position))


## Phase 2: detailed Blender truck model.
func _test_truck_model() -> void:
	var t: Truck = game.get("truck")
	check(t.model_kind == "detailed", "truck model: detailed Blender model loaded", t.model_kind)
	var model := t.get_node_or_null("Model") as Node3D
	check(model != null, "truck model: model attached to the truck")
	if model == null:
		return
	var missing: Array[String] = []
	for p: String in ["Body", "Glass", "Lamp_head", "Lamp_brake", "Lamp_reverse", "Lamp_ind_l", "Lamp_ind_r", "Lamp_marker", "Wiper_L", "Wiper_R"]:
		if model.find_child(p, true, false) == null:
			missing.append(p)
	check(missing.is_empty(), "truck model: all named parts present", str(missing))
	check(model.find_child("WheelSingle", true, false) == null and model.find_child("WheelDual", true, false) == null, "truck model: wheel templates not left on the body")
	var body := model.find_child("Body", true, false) as MeshInstance3D
	var box := body.mesh.get_aabb()
	var height := box.end.y + TruckVisual.RIDE_HEIGHT
	# A real Indian 10-wheeler: about 2.5 m wide (3.3 m with mirrors), 9.8 m long, 3.3-3.6 m high.
	check(box.size.x > 2.45 and box.size.x < 3.5 and box.size.z > 9.4 and box.size.z < 10.3 and height > 3.1 and height < 3.8,
			"truck model: real-world proportions", "width %.2f m, length %.2f m, height %.2f m" % [box.size.x, box.size.z, height])
	var textured := 0
	for i in body.mesh.get_surface_count():
		var m := body.mesh.surface_get_material(i) as StandardMaterial3D
		if m and m.albedo_texture and m.normal_enabled and m.normal_texture:
			textured += 1
	check(body.mesh.get_surface_count() >= 20 and textured >= 4, "truck model: PBR materials with texture and normal maps", "%d materials, %d textured" % [body.mesh.get_surface_count(), textured])
	var bad_wheels := 0
	for w in t.all_wheels:
		var mi := w.get_child(0) as MeshInstance3D
		var r := mi.mesh.get_aabb().size.y * 0.5
		var right_ok := w.position.x > 0.0 or is_equal_approx(mi.rotation.y, PI)
		if absf(r - Truck.WHEEL_RADIUS) > 0.03 or not right_ok:
			bad_wheels += 1
	check(bad_wheels == 0, "truck model: model tyres match the physics wheel size and face outwards", "%d wrong" % bad_wheels)
	var head := model.find_child("Lamp_head", true, false) as MeshInstance3D
	var dim := (head.material_override as StandardMaterial3D).emission_energy_multiplier
	t.set_headlights(true)
	t._update_light_visuals()
	var lit := (head.material_override as StandardMaterial3D).emission_energy_multiplier
	t.set_headlights(false)
	t._update_light_visuals()
	check(lit > dim + 1.0, "truck model: headlamps light up on the new model", "%.1f -> %.1f" % [dim, lit])
	check(t.steering_spinner != null and t.steering_spinner.is_inside_tree(), "truck model: steering wheel present")
	# Steering: the cab steering wheel and the front tyres must visibly turn.
	t.set_handbrake(false)
	t.set_controls(0.0, 0.0, 1.0)
	await _frames(60)
	var front: VehicleWheel3D = t.all_wheels[0]
	# Compare axle directions (basis.x): the wheel also spins about its axle as it rolls.
	var tyre_angle := rad_to_deg(t.global_transform.basis.x.signed_angle_to(front.global_transform.basis.x, Vector3.UP))
	check(absf(t.steering_spinner.rotation.y) > 1.0, "steering: cab steering wheel turns", "%.0f deg" % rad_to_deg(t.steering_spinner.rotation.y))
	check(absf(tyre_angle) > 15.0, "steering: front tyres turn", "%.0f deg" % tyre_angle)
	t.set_controls(0.0, 0.0, 0.0)
	t.set_handbrake(true)
	await _frames(60)
	var holder := Node3D.new()
	add_child(holder)
	var fallback := TruckModel.build(holder)
	check(fallback.has("head") and fallback.has("spinner"), "truck model: simple fallback model still builds")
	holder.queue_free()
	var parked := get_tree().root.find_children("ParkedLorry*", "", true, false)
	check(parked.size() >= 2, "truck model: parked lorries in the yard use the new model", "%d found" % parked.size())


func _test_drive_flyover_brakes() -> void:
	# Eastbound left lane (India drives on the left; facing +X, left is -Z).
	await _new_game(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-560, 1.1, -4.0)))
	var t: Truck = game.get("truck")
	await _frames(60)
	t.toggle_engine()
	await _frames(90)
	check(t.engine_on, "engine: starts after cranking")
	check(t.rpm > 500.0 and t.rpm < 1100.0, "engine: idles", "rpm=%.0f" % t.rpm)
	t.set_handbrake(false)
	t.set_controls(0.0, 0.0, 0.0)
	var idle_pos := t.global_position
	await _frames(180)
	check(t.global_position.distance_to(idle_pos) < 0.3 and t.speed_kmh < 0.5, "control: no movement without accelerator (engine on, brake off)", "moved %.2f m" % t.global_position.distance_to(idle_pos))
	var start := t.global_position
	var fuel0 := t.fuel
	var max_y := 0.0
	var max_gear := 0
	var upright_ok := true
	var frames := 0
	t.set_controls(1.0, 0.0, 0.0)
	while frames < 60 * 90 and t.global_position.x < -40.0:
		await get_tree().physics_frame
		frames += 1
		max_y = maxf(max_y, t.global_position.y)
		max_gear = maxi(max_gear, t.gear)
		if not _upright(t):
			upright_ok = false
		if frames % 240 == 0:
			print("  trace t=%.0fs x=%.1f y=%.2f v=%.1f gear=%d rpm=%.0f hb=%s brake=%.1f ef=%.0f contact=%s" % [frames / 60.0, t.global_position.x, t.global_position.y, t.speed_kmh, t.gear, t.rpm, t.handbrake_on, t.drive_wheels[0].brake, t.drive_wheels[0].engine_force, t.drive_wheels[0].is_in_contact()])
	var moved := t.global_position - start
	check(moved.x > 400.0, "drive: truck moves forward along heading (+Z local)", "moved %.0f m in %.1f s" % [moved.x, frames / 60.0])
	check(max_y > FLYOVER_TOP(), "drive: climbs the Avinashi Road flyover", "max body y=%.2f" % max_y)
	check(upright_ok, "drive: stays upright over the flyover")
	check(absf(t.global_position.z + 4.0) < 1.5, "drive: tracks straight in lane", "z=%.2f" % t.global_position.z)
	check(max_gear >= 4, "gearbox: automatic upshifts", "max gear %d" % max_gear)
	check(t.fuel < fuel0, "fuel: consumed while driving", "%.2f L used" % (fuel0 - t.fuel))
	# accelerate to cruising speed, then emergency brake
	frames = 0
	while t.speed_kmh < 60.0 and frames < 60 * 40:
		await get_tree().physics_frame
		frames += 1
	var v0 := t.speed_kmh
	check(v0 >= 55.0, "drive: reaches highway speed", "%.1f km/h" % v0)
	await _frames(60 * 15)
	check(t.speed_kmh <= Truck.GOVERNOR_KMH + 3.0, "governor: limits top speed", "%.1f km/h" % t.speed_kmh)
	v0 = t.speed_kmh
	var bpos := t.global_position
	t.set_controls(0.0, 1.0, 0.0)
	frames = 0
	while t.speed_kmh > 0.5 and frames < 60 * 20:
		await get_tree().physics_frame
		frames += 1
	var dist := t.global_position.distance_to(bpos)
	check(t.speed_kmh <= 0.5, "brakes: truck stops", "from %.0f km/h in %.1f s" % [v0, frames / 60.0])
	check(dist > 20.0 and dist < 90.0, "brakes: realistic stopping distance", "%.1f m from %.0f km/h" % [dist, v0])
	check(_upright(t), "brakes: stable under hard braking")


func FLYOVER_TOP() -> float:
	return CoimbatoreWorld.FLY_H - 0.5


func _test_open_ground() -> void:
	await _new_game(Transform3D(Basis(), Vector3(0, 1.1, 330)))
	var t: Truck = game.get("truck")
	await _frames(60)
	t.toggle_engine()
	await _frames(80)
	t.set_handbrake(false)
	# steering
	var yaw0 := atan2(t.global_transform.basis.z.x, t.global_transform.basis.z.z)
	t.set_controls(0.5, 0.0, 1.0)
	await _frames(60 * 8)
	var yaw1 := atan2(t.global_transform.basis.z.x, t.global_transform.basis.z.z)
	var turned := absf(wrapf(yaw1 - yaw0, -PI, PI))
	check(turned > deg_to_rad(45.0) or t.speed_kmh > 3.0 and turned > deg_to_rad(30.0), "steering: truck turns", "%.0f deg" % rad_to_deg(turned))
	check(wrapf(yaw1 - yaw0, -PI, PI) > 0.0, "steering: left input turns left")
	check(_upright(t), "steering: upright while turning at low speed")
	# stop and reverse
	t.set_controls(0.0, 1.0, 0.0)
	await _frames(60 * 4)
	t.set_controls(0.0, 0.0, 0.0)
	t.toggle_reverse()
	check(t.gear == -1, "reverse: gear selected when stopped")
	var p0 := t.global_position
	var fwd := t.global_transform.basis.z
	t.set_controls(0.7, 0.0, 0.0)
	await _frames(60 * 5)
	var along := (t.global_position - p0).dot(fwd)
	check(along < -2.0, "reverse: truck moves backwards", "%.1f m" % along)
	check(t.speed_kmh <= Truck.REVERSE_LIMIT_KMH + 1.0, "reverse: speed limited", "%.1f km/h" % t.speed_kmh)
	t.set_controls(0.0, 1.0, 0.0)
	await _frames(60 * 3)
	t.toggle_reverse()
	check(t.gear == 1, "reverse: back to forward gear")
	# parking brake holds
	t.set_controls(0.0, 0.0, 0.0)
	t.set_handbrake(true)
	await _frames(60)
	var hb_pos := t.global_position
	await _frames(120)
	var hb_moved := Vector2(t.global_position.x - hb_pos.x, t.global_position.z - hb_pos.z).length()
	check(hb_moved < 0.1, "parking brake: holds truck", "moved %.3f m in 2 s" % hb_moved)
	# manual gearbox
	t.auto_transmission = false
	t.gear = 1
	t.shift_up()
	await _frames(30)
	check(t.gear == 2, "manual gearbox: shift up")
	t.shift_down()
	t.shift_down()
	await _frames(30)
	check(t.gear == 0, "manual gearbox: shift down to neutral")
	t.auto_transmission = true
	t.gear = 1
	# horns
	for i in range(3):
		t.horn.set_horn(i, true)
		await _frames(3)
		check(t.horn.is_sounding(i), "horn %d: plays (%s)" % [i + 1, HornController.HORN_NAMES[i]])
		t.horn.set_horn(i, false)
		await _frames(3)
		check(not t.horn.is_sounding(i), "horn %d: stops on release" % (i + 1))
	var s1: AudioStreamWAV = t.horn.players[0].stream
	var s2: AudioStreamWAV = t.horn.players[1].stream
	var s3: AudioStreamWAV = t.horn.players[2].stream
	check(s1 != s2 and s2 != s3 and s1.data != s2.data and s1.data.size() != s3.data.size(), "horns: three different sound samples")
	t.horn.combined = true
	t.horn.set_horn(0, true)
	await _frames(3)
	check(t.horn.is_sounding(0) and t.horn.is_sounding(1) and t.horn.is_sounding(2), "horns: combined mode plays all three")
	t.horn.release_all()
	t.horn.combined = false
	# lights
	t.toggle_headlights()
	check(t.headlights_on, "lights: headlights toggle on")
	t.toggle_headlights()
	# exit, walk, enter
	await _frames(30)
	var truck_pos := t.global_position
	check(game.call("exit_truck"), "exit: driver gets down when stopped")
	var driver: Driver = game.get("driver")
	check(not game.call("is_driving") and driver.visible, "exit: on-foot mode with visible driver")
	var door: Vector3 = t.global_transform * Truck.DOOR_RIGHT_LOCAL
	check(Vector2(driver.global_position.x - door.x, driver.global_position.z - door.z).length() < 1.5, "exit: driver placed at the driver door")
	await _frames(120)
	check(t.global_position.distance_to(truck_pos) < 0.3, "exit: truck keeps its position", "moved %.2f m" % t.global_position.distance_to(truck_pos))
	check(driver.is_on_floor(), "walk: driver stands on the ground", "y=%.2f" % driver.global_position.y)
	var d0 := driver.global_position
	var away := (d0 - t.global_position)
	away.y = 0.0
	away = away.normalized()
	driver.move_input = Vector2(0, 1)
	driver.cam_yaw = atan2(-away.x, -away.z)
	await _frames(120)
	driver.move_input = Vector2.ZERO
	var walked := Vector2(driver.global_position.x - d0.x, driver.global_position.z - d0.z).length()
	check(walked > 2.5, "walk: driver walks", "%.1f m in 2 s" % walked)
	driver.running = true
	await _frames(60)
	driver.move_input = Vector2.ZERO
	driver.running = false
	check(t.distance_to_door(driver.global_position) > 3.0 and not game.call("try_enter_truck"), "enter: refused when far from the door")
	driver.global_position = t.global_transform * Truck.DOOR_RIGHT_LOCAL + Vector3(0, 0.2, 0)
	await _frames(10)
	check(game.call("try_enter_truck"), "enter: driver gets in at the door")
	check(game.call("is_driving") and not driver.visible, "enter: back in driving mode")
	# save / load round trip
	var path := "user://test_save.json"
	check(game.call("save_game", path, true), "save: writes save file")
	var saved_pos := t.global_position
	t.global_transform = Transform3D(Basis(), saved_pos + Vector3(30, 0, 30))
	t.fuel = 12.0
	await _frames(5)
	check(game.call("load_game", path), "load: reads save file")
	await _frames(5)
	check(t.global_position.distance_to(saved_pos) < 1.0, "load: truck position restored", "%.2f m off" % t.global_position.distance_to(saved_pos))
	check(t.fuel > 100.0, "load: fuel restored", "%.1f L" % t.fuel)
	var bad := "user://test_bad.json"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var res: Dictionary = SaveSystem.load_data(bad)
	check(not res["ok"] and String(res["error"]).length() > 10, "load: damaged save handled safely")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad + ".corrupt"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# streaming follows the player
	var world: CoimbatoreWorld = game.get("world")
	var before: Array = world.streamer.loaded.keys()
	var far := Node3D.new()
	add_child(far)
	far.global_position = Vector3(1400, 0, 700)
	world.streamer.target = far
	world.streamer.update_now(true)
	await _frames(3)
	var after: Array = world.streamer.loaded.keys()
	var changed := false
	for k in after:
		if not before.has(k):
			changed = true
	check(changed, "streaming: loads new chunks at a far location", "%d -> %d" % [before.size(), after.size()])
	var still_near := false
	for k in after:
		if (k as Vector2i) == world.chunk_key(0, 330):
			still_near = true
	check(not still_near, "streaming: frees distant chunks")
	world.streamer.target = t
	far.queue_free()


## Presses real keys through Godot's input system, exactly like a player.
func _test_camera_keys() -> void:
	var rig: CameraRig = game.get("rig")
	game.set("external_control", false)
	var expected := {KEY_1: CameraRig.Mode.COCKPIT, KEY_2: CameraRig.Mode.CHASE, KEY_3: CameraRig.Mode.BUMPER, KEY_4: CameraRig.Mode.TOP}
	for key in expected.keys():
		await _press(key)
		check(rig.mode == expected[key], "camera key %s: %s" % [OS.get_keycode_string(key), rig.camera_name()])
	var seen := {}
	for i in range(4):
		await _press(KEY_C)
		seen[rig.mode] = true
	check(seen.size() == 4, "camera key C: cycles through all four cameras", "%d distinct" % seen.size())
	await _press(KEY_2)
	await _frames(5)
	var cam_pos := rig.camera.global_position
	var t: Truck = game.get("truck")
	check(cam_pos.distance_to(t.global_position) > 5.0, "camera 2: chase camera sits behind/above the truck", "%.1f m away" % cam_pos.distance_to(t.global_position))
	game.set("external_control", true)


func _press(keycode: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _test_dashboard_photo() -> void:
	var t: Truck = game.get("truck")
	check(t.photo != null and t.photo.get_parent() == t, "cabin photo: framed photo attached to the truck")
	# import a tall test image and check the frame keeps its aspect ratio
	var img := Image.create(300, 600, false, Image.FORMAT_RGB8)
	img.fill(Color(0.8, 0.4, 0.1))
	var src := "user://test_photo_src.png"
	img.save_png(src)
	var err := DashboardPhoto.import_photo(src)
	check(err == "", "cabin photo: player photo imports", err)
	t.photo.rebuild()
	await _frames(2)
	check(t.photo.source == "player photo" and t.photo.image_size == Vector2i(300, 600), "cabin photo: player photo shown at its real size", "%s %s" % [t.photo.source, str(t.photo.image_size)])
	var quad := (t.photo.get_child(0) as MeshInstance3D).mesh as QuadMesh
	check(is_equal_approx(quad.size.x / quad.size.y, 0.5), "cabin photo: aspect ratio preserved", "%.2f" % (quad.size.x / quad.size.y))
	var bad := DashboardPhoto.import_photo("user://does_not_exist.png")
	check(bad != "", "cabin photo: missing file gives a clear error", bad)
	GameConfig.settings["cabin_photo_slot"] = "passenger_side"
	t.photo.rebuild()
	check(t.photo.position.is_equal_approx(DashboardPhoto.SLOTS["passenger_side"]), "cabin photo: position can be changed")
	GameConfig.settings["cabin_photo_slot"] = "centre"
	t.photo.rebuild()
	DashboardPhoto.clear_photo()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(src))
	var default_exists := ResourceLoader.exists(DashboardPhoto.DEFAULT_IMAGE)
	print("INFO  cabin photo: built-in default image present = %s" % default_exists)


func _test_phase1_fixes() -> void:
	var t: Truck = game.get("truck")
	var rig: CameraRig = game.get("rig")
	# B9: the real photo path is untouched by tests
	check(DashboardPhoto.user_image_path != DashboardPhoto.USER_IMAGE, "B9: tests use a scratch photo path")
	# B3: gearbox follows the setting during a drive
	GameConfig.settings["auto_transmission"] = false
	game.call("_apply_settings")
	check(not t.auto_transmission, "B3: unticking Automatic gearbox switches to manual mid-drive")
	GameConfig.settings["auto_transmission"] = true
	game.call("_apply_settings")
	check(t.auto_transmission, "B3: ticking it switches back to automatic")
	# B4: refuel at the pump and emergency diesel elsewhere
	t.engine_on = false
	t.fuel = 0.0
	var added: float = game.call("try_refuel")
	check(added > 30.0 and t.fuel > 30.0, "B4: emergency diesel when the tank is empty", "+%.0f L" % added)
	t.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(154, 1.0, 32))  # pump lane between dispensers
	t.linear_velocity = Vector3.ZERO
	await _frames(60)
	t.fuel = 50.0
	check(game.call("at_fuel_pump"), "B4: truck detected at the Kovai Fuels pumps")
	added = game.call("try_refuel")
	check(is_equal_approx(t.fuel, Truck.FUEL_CAPACITY), "B4: tank filled at the pump", "+%.0f L" % added)
	# B8: on-foot camera faces the way the truck faces after leaving cockpit view
	rig.set_truck_camera(0)
	await _frames(5)
	check(game.call("exit_truck"), "B7: exit finds a clear spot at the pumps")
	var z := t.global_transform.basis.z
	var cam_fwd := rig.forward_flat()
	check(cam_fwd.dot(Vector3(z.x, 0, z.z).normalized()) > 0.7, "B8: on-foot camera faces the truck's direction after cockpit view", "dot=%.2f" % cam_fwd.dot(Vector3(z.x, 0, z.z).normalized()))
	var driver: Driver = game.get("driver")
	driver.global_position = t.global_transform * Truck.DOOR_RIGHT_LOCAL
	await _frames(5)
	game.call("try_enter_truck")
	# B7: a truck parked against a tall building must not put the driver inside it
	var world: CoimbatoreWorld = game.get("world")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	MeshKit.col_box(wall, Transform3D(Basis(), Vector3(0, 6, 0)), Vector3(4, 12, 20))
	world.add_child(wall)
	var tx := t.global_transform
	wall.global_position = tx * Vector3(-3.4, 0, 3.7) - Vector3(0, tx.origin.y, 0)
	await _frames(3)
	var spot: Variant = game.call("_find_exit_spot")
	var right_door: Vector3 = tx * Truck.DOOR_RIGHT_LOCAL
	var blocked_side_used: bool = spot != null and Vector2((spot as Vector3).x - right_door.x, (spot as Vector3).z - right_door.z).length() < 1.0
	check(not blocked_side_used, "B7: exit refuses the door side blocked by a 12 m building")
	wall.queue_free()
	# B5: crash-safe save keeps a backup and recovers it
	var path := "user://test_safe.json"
	SaveSystem.save_data({"truck": {"fuel": 1.0}}, path)
	SaveSystem.save_data({"truck": {"fuel": 2.0}}, path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var rec: Dictionary = SaveSystem.load_data(path)
	check(rec["ok"] and float(rec["data"]["truck"]["fuel"]) == 2.0, "B5: interrupted save recovered from the backup")
	# Review fix: a damaged main save falls back to the good backup
	SaveSystem.save_data({"truck": {"fuel": 3.0}}, path)
	SaveSystem.save_data({"truck": {"fuel": 4.0}}, path)
	var bf := FileAccess.open(path, FileAccess.WRITE)
	bf.store_string("{ damaged")
	bf.close()
	var rec2: Dictionary = SaveSystem.load_data(path)
	check(rec2["ok"] and rec2.has("warning") and float(rec2["data"]["truck"]["fuel"]) == 3.0, "B5: damaged save falls back to the previous good save")
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	# Review fix: refuelling a full tank says so instead of "added 0 litres"
	t.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(154, 1.0, 32))
	t.linear_velocity = Vector3.ZERO
	t.engine_on = false
	await _frames(30)
	t.fuel = Truck.FUEL_CAPACITY
	check(is_zero_approx(float(game.call("try_refuel"))), "B4: full tank is not refilled")
	# Review fix (regression): getting out under the Avinashi Road flyover deck
	t.global_transform = Transform3D(Basis(), Vector3(-250, 1.1, 1.5))
	t.linear_velocity = Vector3.ZERO
	await _frames(90)
	check(t.global_position.y < 1.5, "flyover: truck parked on the cross road under the deck", "y=%.2f" % t.global_position.y)
	check(game.call("exit_truck"), "B7: can get out under the flyover deck")
	var drv: Driver = game.get("driver")
	drv.global_position = t.global_transform * Truck.DOOR_RIGHT_LOCAL
	await _frames(5)
	game.call("try_enter_truck")
	# B10: zebra crossings drawn on every junction arm
	var world2: CoimbatoreWorld = game.get("world")
	check(world2.zebra_count >= world2.junctions.size(), "B10: zebra crossings on junction arms", "%d crossings at %d junctions" % [world2.zebra_count, world2.junctions.size()])
	# Review fix: settings checkbox follows changes made elsewhere (T key path)
	var menu := SettingsMenu.new()
	add_child(menu)
	await _frames(2)
	GameConfig.set_setting("auto_transmission", false)
	var cb: CheckBox = menu.get("_toggles")["auto_transmission"]
	check(not cb.button_pressed, "B3: settings checkbox updates when the gearbox mode changes elsewhere")
	GameConfig.set_setting("auto_transmission", true)
	check(cb.button_pressed, "B3: and back")
	menu.queue_free()


func _test_settings() -> void:
	var clashes: Array = GameConfig.rebind("horn_1", KEY_Y)
	var has_y := false
	for ev in InputMap.action_get_events("horn_1"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_Y:
			has_y = true
	check(has_y, "settings: horn key rebinding works")
	GameConfig.rebind("horn_1", KEY_J)
	check(GameConfig.rebind("horn_1", KEY_J).is_empty() == false, "settings: key clash detected")
	GameConfig.reset_keys()
	var arrows_ok := true
	for pair in [["accelerate", KEY_UP], ["brake", KEY_DOWN], ["steer_left", KEY_LEFT], ["steer_right", KEY_RIGHT]]:
		var found := false
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == pair[1]:
				found = true
		arrows_ok = arrows_ok and found
	check(arrows_ok, "controls: arrow keys drive as well as W A S D")
	check(GameConfig.key_name("horn_1") == "H" and GameConfig.key_name("horn_2") == "J" and GameConfig.key_name("horn_3") == "K", "settings: default horn keys H J K")
	for p in ["low", "medium", "high", "low"]:
		GameConfig.settings["graphics_preset"] = p
		game.call("_apply_settings")
		var rig: CameraRig = game.get("rig")
		check(is_equal_approx(rig.camera.far, float(GameConfig.PRESETS[p]["view_distance"])), "graphics: preset %s applies" % p)
