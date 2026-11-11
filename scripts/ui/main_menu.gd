extends Control
## Main menu. Phase 1 items: Continue, New Game, Settings, Controls, Exit.
## Garage, Truck Dealer, Job Market, Company and World Map arrive in later phases
## and are shown as "coming in a later update" rather than as fake screens.

var _menu: VBoxContainer
var _settings: SettingsMenu
var _info: Label


func _ready() -> void:
	# Benchmark / screenshot runs skip the menu (see game.gd for the options).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench") or arg.begins_with("--shot"):
			_new_game.call_deferred()
			return
	theme = GameConfig.ui_theme()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.04, 0.05, 0.09))
	grad.set_color(1, Color(0.35, 0.14, 0.04))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	var left := MarginContainer.new()
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_theme_constant_override("margin_left", 80)
	left.add_theme_constant_override("margin_top", 70)
	add_child(left)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	left.add_child(vb)
	var t1 := Label.new()
	t1.text = "INDIAN TRUCK SIMULATOR"
	t1.add_theme_font_size_override("font_size", 52)
	t1.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	vb.add_child(t1)
	var t2 := Label.new()
	t2.text = "ALL INDIA EDITION   -   Starting in Coimbatore, Tamil Nadu"
	t2.add_theme_font_size_override("font_size", 20)
	t2.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	vb.add_child(t2)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vb.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	vb.add_child(_menu)
	var cont := _button("Continue", _continue)
	cont.disabled = not SaveSystem.has_save()
	_button("New game", _new_game)
	_button("Settings", func(): _menu.visible = false; _settings.visible = true)
	_button("Controls", func(): _info.text = GameConfig.controls_text())
	for later in ["Garage", "Truck dealer", "Job market", "Company", "World map"]:
		var b := _button(later + "   (later update)", func(): _info.text = "%s is planned for a later phase. Phase 1 covers driving, the driver on foot, the Coimbatore area and the three horns." % later)
		b.modulate = Color(1, 1, 1, 0.55)
	_button("Exit", func(): get_tree().quit())

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(620, 0)
	vb.add_child(_info)

	var ver := Label.new()
	ver.text = "Version %s   |   Graphics preset: %s" % [GameConfig.VERSION, GameConfig.preset()["label"]]
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 80
	ver.offset_top = -40
	add_child(ver)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func(): _settings.visible = false; _menu.visible = true)
	center.add_child(_settings)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	_menu.add_child(b)
	return b


func _continue() -> void:
	GameConfig.load_on_start = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _new_game() -> void:
	GameConfig.load_on_start = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")
