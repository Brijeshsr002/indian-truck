extends Node
## Central configuration: graphics presets, settings, key bindings, audio buses, UI theme.
## Gameplay systems read from here; changing a preset never changes gameplay.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const VERSION := "0.1.0 (Phase 1 + horns)"

## LOW is the target for this development PC (8 GB RAM, integrated graphics).
const PRESETS := {
	"low": {
		"label": "Low - integrated graphics",
		"shadows": true, "shadow_size": 1024, "shadow_distance": 50.0, "shadow_splits": 1,
		"render_scale": 0.8, "msaa": 0, "max_fps": 30,
		"stream_radius": 420.0, "view_distance": 850.0, "fog_density": 0.0016,
		"tree_density": 0.45, "headlight_shadows": false, "label_range": 70.0,
	},
	"medium": {
		"label": "Medium - 16 GB RAM, better graphics",
		"shadows": true, "shadow_size": 2048, "shadow_distance": 110.0, "shadow_splits": 2,
		"render_scale": 1.0, "msaa": 1, "max_fps": 60,
		"stream_radius": 650.0, "view_distance": 1400.0, "fog_density": 0.0009,
		"tree_density": 0.8, "headlight_shadows": false, "label_range": 120.0,
	},
	"high": {
		"label": "High - dedicated gaming GPU",
		"shadows": true, "shadow_size": 4096, "shadow_distance": 180.0, "shadow_splits": 4,
		"render_scale": 1.0, "msaa": 2, "max_fps": 0,
		"stream_radius": 950.0, "view_distance": 2200.0, "fog_density": 0.0006,
		"tree_density": 1.0, "headlight_shadows": true, "label_range": 180.0,
	},
}

const ACTION_ORDER := [
	"accelerate", "brake", "steer_left", "steer_right", "reverse", "engine",
	"horn_1", "horn_2", "horn_3", "headlights", "handbrake", "camera",
	"camera_1", "camera_2", "camera_3", "camera_4", "map",
	"interact", "run", "gear_up", "gear_down", "transmission_mode",
	"indicator_left", "indicator_right", "help", "quick_save", "quick_load", "pause",
]

const ACTION_LABELS := {
	"accelerate": "Accelerate / walk forward",
	"brake": "Brake / walk back",
	"steer_left": "Steer left / walk left",
	"steer_right": "Steer right / walk right",
	"reverse": "Reverse gear (toggle)",
	"engine": "Engine on / off",
	"horn_1": "Horn 1 - standard",
	"horn_2": "Horn 2 - air horn",
	"horn_3": "Horn 3 - special multi-tone",
	"headlights": "Headlights",
	"handbrake": "Parking brake (toggle)",
	"camera": "Next camera",
	"camera_1": "Camera 1 - driver seat",
	"camera_2": "Camera 2 - chase",
	"camera_3": "Camera 3 - bumper",
	"camera_4": "Camera 4 - top view",
	"map": "World map",
	"interact": "Get in / get out of truck",
	"run": "Run (on foot)",
	"gear_up": "Gear up (manual)",
	"gear_down": "Gear down (manual)",
	"transmission_mode": "Automatic / manual gearbox",
	"indicator_left": "Left indicator",
	"indicator_right": "Right indicator",
	"help": "Show controls",
	"quick_save": "Quick save",
	"quick_load": "Quick load",
	"pause": "Pause menu",
}

const DEFAULT_KEYS := {
	"accelerate": KEY_W, "brake": KEY_S, "steer_left": KEY_A, "steer_right": KEY_D,
	"reverse": KEY_R, "engine": KEY_E, "horn_1": KEY_H, "horn_2": KEY_J, "horn_3": KEY_K,
	"headlights": KEY_L, "handbrake": KEY_SPACE, "camera": KEY_C, "map": KEY_M,
	"camera_1": KEY_1, "camera_2": KEY_2, "camera_3": KEY_3, "camera_4": KEY_4,
	"interact": KEY_F, "run": KEY_SHIFT, "gear_up": KEY_SHIFT, "gear_down": KEY_CTRL,
	"transmission_mode": KEY_T, "indicator_left": KEY_BRACKETLEFT,
	"indicator_right": KEY_BRACKETRIGHT, "help": KEY_F1, "quick_save": KEY_F5,
	"quick_load": KEY_F9, "pause": KEY_ESCAPE,
}

## Arrow keys always work as a second set of driving / walking keys.
const SECONDARY_KEYS := {
	"accelerate": KEY_UP, "brake": KEY_DOWN, "steer_left": KEY_LEFT, "steer_right": KEY_RIGHT,
}

## Gamepad defaults (XInput layout). A steering wheel shows up as a joypad: its
## wheel axis usually maps to left stick X and pedals to the triggers.
const DEFAULT_JOY_AXES := {
	"accelerate": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "brake": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"steer_left": [JOY_AXIS_LEFT_X, -1.0], "steer_right": [JOY_AXIS_LEFT_X, 1.0],
}
const DEFAULT_JOY_BUTTONS := {
	"horn_1": JOY_BUTTON_X, "horn_2": JOY_BUTTON_B, "horn_3": JOY_BUTTON_DPAD_UP,
	"handbrake": JOY_BUTTON_A, "interact": JOY_BUTTON_Y, "camera": JOY_BUTTON_RIGHT_STICK,
	"engine": JOY_BUTTON_DPAD_DOWN, "reverse": JOY_BUTTON_DPAD_LEFT,
	"headlights": JOY_BUTTON_DPAD_RIGHT, "gear_up": JOY_BUTTON_RIGHT_SHOULDER,
	"gear_down": JOY_BUTTON_LEFT_SHOULDER, "pause": JOY_BUTTON_START, "map": JOY_BUTTON_BACK,
}

var settings := {
	"graphics_preset": "low",
	"fullscreen": false,
	"max_fps_override": -1,
	"master_volume": 0.8,
	"engine_volume": 0.8,
	"horn_volume": 0.9,
	"mouse_sensitivity": 0.25,
	"auto_transmission": true,
	"combined_horn": false,
	# 1.0 = realistic diesel use; default is half, as requested.
	"fuel_rate": 0.5,
	"cabin_photo_slot": "centre",
	"cabin_photo_frame": "gold",
	"cabin_photo_extras": true,
	"cabin_photo_version": 0,
}
var key_bindings := {}

## Runtime flags set by menus and tests (not saved).
var load_on_start := false
var test_mode := false

var _theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	key_bindings = DEFAULT_KEYS.duplicate()
	_setup_audio_buses()
	load_settings()
	_apply_input_map()
	apply_display()
	apply_audio()


func preset() -> Dictionary:
	var key: String = settings.get("graphics_preset", "low")
	if not PRESETS.has(key):
		key = "low"
	return PRESETS[key]


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	apply_display()
	apply_audio()
	settings_changed.emit()


# ---------------------------------------------------------------- persistence

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		if cfg.has_section_key("settings", k):
			settings[k] = cfg.get_value("settings", k)
	for action in DEFAULT_KEYS.keys():
		if cfg.has_section_key("keys", action):
			var code := int(cfg.get_value("keys", action))
			if code > 0:
				key_bindings[action] = code


func save_settings() -> void:
	if test_mode:
		return
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	for action in key_bindings.keys():
		cfg.set_value("keys", action, key_bindings[action])
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))


# ---------------------------------------------------------------- input

func _apply_input_map() -> void:
	for action in DEFAULT_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		_apply_action_keys(action)
		if DEFAULT_JOY_AXES.has(action):
			var ev := InputEventJoypadMotion.new()
			ev.axis = DEFAULT_JOY_AXES[action][0]
			ev.axis_value = DEFAULT_JOY_AXES[action][1]
			InputMap.action_add_event(action, ev)
		if DEFAULT_JOY_BUTTONS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = DEFAULT_JOY_BUTTONS[action]
			InputMap.action_add_event(action, jb)


func _apply_action_keys(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var key := InputEventKey.new()
	key.physical_keycode = key_bindings[action]
	InputMap.action_add_event(action, key)
	if SECONDARY_KEYS.has(action) and int(SECONDARY_KEYS[action]) != int(key_bindings[action]):
		var alt := InputEventKey.new()
		alt.physical_keycode = SECONDARY_KEYS[action]
		InputMap.action_add_event(action, alt)


## Rebinds an action to a key. Returns the other actions already using that key.
func rebind(action: String, keycode: int) -> Array:
	if not DEFAULT_KEYS.has(action) or keycode <= 0:
		return []
	key_bindings[action] = keycode
	_apply_action_keys(action)
	save_settings()
	settings_changed.emit()
	var clashes := []
	for other in key_bindings.keys():
		if other != action and int(key_bindings[other]) == keycode:
			clashes.append(ACTION_LABELS.get(other, other))
	return clashes


func reset_keys() -> void:
	key_bindings = DEFAULT_KEYS.duplicate()
	for action in DEFAULT_KEYS.keys():
		_apply_action_keys(action)
	save_settings()
	settings_changed.emit()


func key_name(action: String) -> String:
	if not key_bindings.has(action):
		return "?"
	return OS.get_keycode_string(int(key_bindings[action]))


func controls_text() -> String:
	var lines := PackedStringArray()
	for action in ACTION_ORDER:
		lines.append("%-6s  %s" % [key_name(action), ACTION_LABELS[action]])
	lines.append("Arrows  Also accelerate, brake and steer (Up, Down, Left, Right)")
	lines.append("Mouse   Look around (click the game window to capture the mouse)")
	return "\n".join(lines)


# ---------------------------------------------------------------- display / graphics

func apply_display() -> void:
	if test_mode or DisplayServer.get_name() == "headless":
		return
	var p := preset()
	var fps_override := int(settings.get("max_fps_override", -1))
	Engine.max_fps = int(p["max_fps"]) if fps_override < 0 else fps_override
	var want_full := bool(settings.get("fullscreen", false))
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Applies the current preset to the 3D scene. Called by the game scene.
func apply_graphics(viewport: Viewport, env: Environment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	var p := preset()
	if sun:
		sun.shadow_enabled = bool(p["shadows"])
		sun.directional_shadow_max_distance = float(p["shadow_distance"])
		match int(p["shadow_splits"]):
			1:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			2:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_size"]), true)
	if viewport:
		viewport.msaa_3d = int(p["msaa"]) as Viewport.MSAA
		viewport.scaling_3d_scale = float(p["render_scale"])
	if env:
		env.fog_enabled = true
		env.fog_density = float(p["fog_density"])
	if camera:
		camera.far = float(p["view_distance"])


# ---------------------------------------------------------------- audio

func _setup_audio_buses() -> void:
	for bus_name in ["Engine", "Horns", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			# Low-pass used to muffle outside sounds while sitting in the cabin.
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 1500.0 if bus_name == "Engine" else 3200.0
			AudioServer.add_bus_effect(idx, lp)
			AudioServer.set_bus_effect_enabled(idx, 0, false)


func set_cabin_audio(inside: bool) -> void:
	for bus_name in ["Engine", "Horns", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0 and AudioServer.get_bus_effect_count(idx) > 0:
			AudioServer.set_bus_effect_enabled(idx, 0, inside)


func apply_audio() -> void:
	_set_bus_volume("Master", float(settings.get("master_volume", 0.8)))
	_set_bus_volume("Engine", float(settings.get("engine_volume", 0.8)))
	_set_bus_volume("Horns", float(settings.get("horn_volume", 0.9)))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


# ---------------------------------------------------------------- UI theme

func ui_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	var normal := _sb(Color(0.09, 0.11, 0.15, 0.94), Color(0.26, 0.29, 0.36), 1)
	var hover := _sb(Color(0.15, 0.17, 0.23, 0.97), Color(1.0, 0.62, 0.15), 2)
	var pressed := _sb(Color(0.93, 0.53, 0.1), Color(1.0, 0.72, 0.3), 2)
	var disabled := _sb(Color(0.08, 0.09, 0.11, 0.8), Color(0.18, 0.2, 0.24), 1)
	var focus := _sb(Color(0, 0, 0, 0), Color(1.0, 0.62, 0.15, 0.8), 2)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, Color(0.92, 0.93, 0.95))
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color(0.08, 0.08, 0.1))
		t.set_color("font_disabled_color", cls, Color(0.45, 0.47, 0.5))
	var panel := _sb(Color(0.06, 0.07, 0.1, 0.96), Color(0.22, 0.25, 0.32), 1)
	panel.set_corner_radius_all(10)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", Color(0.9, 0.91, 0.93))
	_theme = t
	return t


func _sb(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
