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
	await _test_drive_flyover_brakes()
	await _test_open_ground()
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
	var world: CoimbatoreWorld = game.get("world")
	check(world.streamer.loaded_count() > 0, "world: chunks streamed in near spawn", "%d chunks" % world.streamer.loaded_count())
	check(world.chunk_specs.size() > 20, "world: chunk plan built", "%d chunks planned" % world.chunk_specs.size())
	check(world.location_name(t.global_position).length() > 3, "world: location name", world.location_name(t.global_position))


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
	await _frames(120)
	check(t.speed_kmh < 0.5, "parking brake: holds truck", "%.2f km/h" % t.speed_kmh)
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
	check(GameConfig.key_name("horn_1") == "H" and GameConfig.key_name("horn_2") == "J" and GameConfig.key_name("horn_3") == "K", "settings: default horn keys H J K")
	for p in ["low", "medium", "high", "low"]:
		GameConfig.settings["graphics_preset"] = p
		game.call("_apply_settings")
		var rig: CameraRig = game.get("rig")
		check(is_equal_approx(rig.camera.far, float(GameConfig.PRESETS[p]["view_distance"])), "graphics: preset %s applies" % p)
