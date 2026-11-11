class_name HUD
extends CanvasLayer
## Driving and on-foot HUD: gauges, minimap, location and time, notifications,
## interaction prompt, full map and controls help.

var game: Node
var gauges: GaugeCluster
var minimap: MapView
var big_map: MapView
var info_label: Label
var notif_box: VBoxContainer
var prompt_label: Label
var help_panel: PanelContainer
var help_label: Label
var _fps_t := 0.0


func setup(g: Node) -> void:
	game = g
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	gauges = GaugeCluster.new()
	gauges.truck = game.get("truck")
	gauges.anchor_left = 1.0
	gauges.anchor_right = 1.0
	gauges.anchor_top = 1.0
	gauges.anchor_bottom = 1.0
	gauges.offset_left = -540
	gauges.offset_top = -230
	gauges.offset_right = -20
	gauges.offset_bottom = -20
	root.add_child(gauges)

	minimap = MapView.new()
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = 20
	minimap.offset_top = -240
	minimap.offset_right = 240
	minimap.offset_bottom = -20
	root.add_child(minimap)
	minimap.setup(game.get("world"), game, false)

	info_label = _label(18)
	info_label.position = Vector2(20, 16)
	root.add_child(info_label)

	notif_box = VBoxContainer.new()
	notif_box.anchor_left = 0.5
	notif_box.anchor_right = 0.5
	notif_box.offset_left = -330
	notif_box.offset_right = 330
	notif_box.offset_top = 16
	notif_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	notif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notif_box)

	prompt_label = _label(22)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.0
	prompt_label.anchor_bottom = 0.0
	prompt_label.offset_left = -300
	prompt_label.offset_right = 300
	prompt_label.offset_top = 150
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	root.add_child(prompt_label)

	big_map = MapView.new()
	big_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_map.visible = false
	root.add_child(big_map)
	big_map.setup(game.get("world"), game, true)

	help_panel = PanelContainer.new()
	help_panel.theme = GameConfig.ui_theme()
	help_panel.anchor_left = 0.5
	help_panel.anchor_right = 0.5
	help_panel.anchor_top = 0.5
	help_panel.anchor_bottom = 0.5
	help_panel.offset_left = -300
	help_panel.offset_right = 300
	help_panel.offset_top = -330
	help_panel.offset_bottom = 330
	help_panel.visible = false
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + side, 18)
	help_panel.add_child(hm)
	help_label = Label.new()
	help_label.add_theme_font_size_override("font_size", 15)
	hm.add_child(help_label)
	root.add_child(help_panel)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	if game == null:
		return
	_fps_t += delta
	var driving: bool = game.call("is_driving")
	gauges.visible = driving
	var pos: Vector3 = game.call("active_position")
	var world: CoimbatoreWorld = game.get("world")
	var minutes: float = game.get("game_minutes")
	var hh := int(minutes / 60.0) % 24
	var mm := int(minutes) % 60
	var preset_label: String = String(GameConfig.settings.get("graphics_preset", "low")).capitalize()
	info_label.text = "%s\n%02d:%02d   |   FPS %d   |   Graphics: %s" % [world.location_name(pos), hh, mm, Engine.get_frames_per_second(), preset_label]
	prompt_label.text = game.call("prompt_text")


func notify(text: String, seconds := 4.0) -> void:
	if notif_box == null:
		return
	while notif_box.get_child_count() >= 4:
		var old := notif_box.get_child(0)
		notif_box.remove_child(old)
		old.queue_free()
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	sb.border_color = Color(1.0, 0.62, 0.15, 0.9)
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(l)
	notif_box.add_child(panel)
	var tw := panel.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


func toggle_map() -> void:
	big_map.visible = not big_map.visible


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	if help_panel.visible:
		help_label.text = "CONTROLS  (change them in Pause > Settings)\n\n" + GameConfig.controls_text()
