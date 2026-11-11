class_name SettingsMenu
extends PanelContainer
## Settings: graphics preset, display, audio volumes, controls and key rebinding.
## Every change is applied immediately and saved to user://settings.cfg.

signal closed

const PRESET_KEYS := ["low", "medium", "high"]
const FPS_VALUES := [-1, 30, 60, 0]

const FUEL_RATES := [0.25, 0.5, 1.0]

var _file_dialog: FileDialog
var _waiting_action := ""
var _key_buttons := {}
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = GameConfig.ui_theme()
	custom_minimum_size = Vector2(700, 600)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	_section(list, "Graphics")
	var preset_opt := OptionButton.new()
	for k in PRESET_KEYS:
		preset_opt.add_item(GameConfig.PRESETS[k]["label"])
	preset_opt.select(maxi(0, PRESET_KEYS.find(GameConfig.settings["graphics_preset"])))
	preset_opt.item_selected.connect(func(i: int): GameConfig.set_setting("graphics_preset", PRESET_KEYS[i]); _say("Graphics preset changed. Tree density and view range fully update after reloading the game."))
	_row(list, "Quality preset", preset_opt)
	var fps_opt := OptionButton.new()
	for t in ["Preset default", "30 FPS", "60 FPS", "Unlimited"]:
		fps_opt.add_item(t)
	fps_opt.select(maxi(0, FPS_VALUES.find(int(GameConfig.settings["max_fps_override"]))))
	fps_opt.item_selected.connect(func(i: int): GameConfig.set_setting("max_fps_override", FPS_VALUES[i]))
	_row(list, "Frame rate limit", fps_opt)
	var full := CheckBox.new()
	full.button_pressed = bool(GameConfig.settings["fullscreen"])
	full.toggled.connect(func(on: bool): GameConfig.set_setting("fullscreen", on))
	_row(list, "Fullscreen", full)

	_section(list, "Audio")
	_slider(list, "Master volume", "master_volume", 0.0, 1.0)
	_slider(list, "Engine volume", "engine_volume", 0.0, 1.0)
	_slider(list, "Horn volume", "horn_volume", 0.0, 1.0)

	_section(list, "Driving")
	_slider(list, "Mouse sensitivity", "mouse_sensitivity", 0.05, 1.0)
	var auto := CheckBox.new()
	auto.button_pressed = bool(GameConfig.settings["auto_transmission"])
	auto.toggled.connect(func(on: bool): GameConfig.set_setting("auto_transmission", on))
	_row(list, "Automatic gearbox", auto)
	var comb := CheckBox.new()
	comb.button_pressed = bool(GameConfig.settings["combined_horn"])
	comb.toggled.connect(func(on: bool): GameConfig.set_setting("combined_horn", on))
	_row(list, "Combined horn (Horn 1 plays all three)", comb)

	var fuel_opt := OptionButton.new()
	for t in ["Very low (25%)", "Low (50%, default)", "Realistic (100%)"]:
		fuel_opt.add_item(t)
	fuel_opt.select(maxi(0, FUEL_RATES.find(float(GameConfig.settings["fuel_rate"]))))
	fuel_opt.item_selected.connect(func(i: int): GameConfig.set_setting("fuel_rate", FUEL_RATES[i]))
	_row(list, "Diesel use", fuel_opt)

	_section(list, "Cabin - Lord Murugan photo")
	var choose := Button.new()
	choose.text = "Choose my own photo..."
	choose.pressed.connect(_choose_photo)
	_row(list, "Photo on the dashboard", choose)
	var reset_photo := Button.new()
	reset_photo.text = "Use the built-in photo"
	reset_photo.pressed.connect(func(): DashboardPhoto.clear_photo(); _bump_photo(); _say("Using the built-in photo."))
	_row(list, "", reset_photo)
	var slot_opt := OptionButton.new()
	var slot_keys: Array = DashboardPhoto.SLOTS.keys()
	for k in slot_keys:
		slot_opt.add_item(DashboardPhoto.SLOT_LABELS[k])
	slot_opt.select(maxi(0, slot_keys.find(GameConfig.settings["cabin_photo_slot"])))
	slot_opt.item_selected.connect(func(i: int): GameConfig.set_setting("cabin_photo_slot", slot_keys[i]))
	_row(list, "Position", slot_opt)
	var frame_opt := OptionButton.new()
	var frame_keys: Array = DashboardPhoto.FRAMES.keys()
	for k in frame_keys:
		frame_opt.add_item(String(k).capitalize())
	frame_opt.select(maxi(0, frame_keys.find(GameConfig.settings["cabin_photo_frame"])))
	frame_opt.item_selected.connect(func(i: int): GameConfig.set_setting("cabin_photo_frame", frame_keys[i]))
	_row(list, "Frame", frame_opt)
	var extras := CheckBox.new()
	extras.button_pressed = bool(GameConfig.settings["cabin_photo_extras"])
	extras.toggled.connect(func(on: bool): GameConfig.set_setting("cabin_photo_extras", on))
	_row(list, "Vel and flowers beside the photo", extras)
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	_file_dialog.title = "Choose a Lord Murugan photo"
	_file_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_file_dialog.file_selected.connect(_on_photo_selected)
	add_child(_file_dialog)

	_section(list, "Key bindings  (click a key, then press the new key; Esc cancels)")
	for action in GameConfig.ACTION_ORDER:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 0)
		btn.pressed.connect(_start_rebind.bind(action))
		_key_buttons[action] = btn
		_row(list, GameConfig.ACTION_LABELS[action], btn)
	var reset := Button.new()
	reset.text = "Reset keys to default"
	reset.pressed.connect(func(): GameConfig.reset_keys(); _refresh_keys(); _say("Keys reset to default."))
	list.add_child(reset)
	_refresh_keys()

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	vb.add_child(_status)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): _waiting_action = ""; closed.emit())
	vb.add_child(back)


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	parent.add_child(l)


func _row(parent: Control, text: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	hb.add_child(control)
	parent.add_child(hb)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float) -> void:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.custom_minimum_size = Vector2(220, 24)
	s.value = float(GameConfig.settings[key])
	s.value_changed.connect(func(v: float): GameConfig.set_setting(key, v))
	_row(parent, text, s)


func _choose_photo() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_photo_selected(path: String) -> void:
	var err := DashboardPhoto.import_photo(path)
	if err != "":
		_say(err)
		return
	_bump_photo()
	_say("Photo added to the dashboard. It stays saved even if you move the original file.")


func _bump_photo() -> void:
	GameConfig.set_setting("cabin_photo_version", int(GameConfig.settings.get("cabin_photo_version", 0)) + 1)


func _refresh_keys() -> void:
	for action in _key_buttons.keys():
		(_key_buttons[action] as Button).text = GameConfig.key_name(action)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	(_key_buttons[action] as Button).text = "Press a key..."


func _say(text: String) -> void:
	if _status:
		_status.text = text


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		get_viewport().set_input_as_handled()
		if code == KEY_ESCAPE and _waiting_action != "pause":
			_waiting_action = ""
			_refresh_keys()
			return
		var action := _waiting_action
		_waiting_action = ""
		var clashes := GameConfig.rebind(action, code)
		_refresh_keys()
		if clashes.is_empty():
			_say("%s is now %s." % [GameConfig.ACTION_LABELS[action], OS.get_keycode_string(code)])
		else:
			_say("%s is now %s. Note: this key is also used for %s." % [GameConfig.ACTION_LABELS[action], OS.get_keycode_string(code), ", ".join(clashes)])
