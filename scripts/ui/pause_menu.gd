class_name PauseMenu
extends CanvasLayer
## Pause menu: resume, save, load, settings, controls, main menu, quit.

var game: Node
var _root: Control
var _main: PanelContainer
var _settings: SettingsMenu
var _controls: PanelContainer
var _status: Label


func setup(g: Node) -> void:
	game = g
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameConfig.ui_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_main = PanelContainer.new()
	_main.custom_minimum_size = Vector2(380, 0)
	center.add_child(_main)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22)
	_main.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	m.add_child(vb)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	vb.add_child(title)
	_button(vb, "Resume", close)
	_button(vb, "Save game", func(): game.call("save_game"); _say("Game saved."))
	_button(vb, "Load last save", func(): close(); game.call("reload_from_save"))
	_button(vb, "Settings", _show_settings)
	_button(vb, "Controls", _show_controls)
	_button(vb, "Save and exit to main menu", func(): game.call("save_game", SaveSystem.SAVE_PATH, true); get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_button(vb, "Save and quit game", func(): game.call("save_game", SaveSystem.SAVE_PATH, true); get_tree().quit())
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	vb.add_child(_status)

	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func(): _settings.visible = false; _main.visible = true)
	center.add_child(_settings)

	_controls = PanelContainer.new()
	_controls.visible = false
	center.add_child(_controls)
	var cm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		cm.add_theme_constant_override("margin_" + side, 20)
	_controls.add_child(cm)
	var cvb := VBoxContainer.new()
	cm.add_child(cvb)
	var cl := Label.new()
	cl.name = "Text"
	cl.add_theme_font_size_override("font_size", 15)
	cvb.add_child(cl)
	_button(cvb, "Back", func(): _controls.visible = false; _main.visible = true)


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 44)
	b.pressed.connect(cb)
	parent.add_child(b)


func _say(text: String) -> void:
	_status.text = text


func _show_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _show_controls() -> void:
	_main.visible = false
	_controls.visible = true
	(_controls.find_child("Text", true, false) as Label).text = GameConfig.controls_text()


func open() -> void:
	visible = true
	_main.visible = true
	_settings.visible = false
	_controls.visible = false
	_status.text = ""
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings.visible:
			_settings.visible = false
			_main.visible = true
		elif _controls.visible:
			_controls.visible = false
			_main.visible = true
		else:
			close()
