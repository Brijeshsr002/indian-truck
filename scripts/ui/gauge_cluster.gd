class_name GaugeCluster
extends Control
## Speedometer, tachometer, gear, fuel and warning lamps, drawn with 2D primitives.

const ACCENT := Color(1.0, 0.62, 0.15)
const DIM := Color(1, 1, 1, 0.18)

var truck: Truck
var _bg: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(520, 210)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Color(0.03, 0.04, 0.06, 0.78)
	_bg.border_color = Color(1, 1, 1, 0.08)
	_bg.set_border_width_all(1)
	_bg.set_corner_radius_all(14)


var _redraw_t := 0.0


func _process(delta: float) -> void:
	_redraw_t -= delta
	if _redraw_t > 0.0:
		return
	_redraw_t = 1.0 / 15.0  # 15 redraws per second is plenty for gauges and maps
	if visible:
		queue_redraw()


func _draw() -> void:
	if truck == null:
		return
	var font := ThemeDB.fallback_font
	_bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, custom_minimum_size))
	_dial(Vector2(105, 108), 82.0, truck.rpm / 100.0, 30.0, 5.0, 24.0, "RPM x100", Color(0.45, 0.8, 1.0), font)
	_dial(Vector2(300, 108), 92.0, truck.speed_kmh, 120.0, 20.0, 80.0, "km/h", ACCENT, font)
	draw_string(font, Vector2(250, 158), "%d" % roundi(truck.speed_kmh), HORIZONTAL_ALIGNMENT_CENTER, 100, 30, Color.WHITE)
	# gear
	var gear_rect := Rect2(Vector2(80, 128), Vector2(50, 38))
	draw_rect(gear_rect, Color(0, 0, 0, 0.5))
	draw_string(font, gear_rect.position + Vector2(0, 29), truck.gear_label(), HORIZONTAL_ALIGNMENT_CENTER, 50, 26, ACCENT)
	# fuel
	var frac := truck.fuel / Truck.FUEL_CAPACITY
	var fx := 420.0
	draw_string(font, Vector2(fx, 30), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	draw_rect(Rect2(fx, 38, 22, 120), DIM)
	var fc := Color(0.3, 0.85, 0.4) if frac > 0.2 else Color(1.0, 0.3, 0.2)
	draw_rect(Rect2(fx, 38 + 120 * (1.0 - frac), 22, 120 * frac), fc)
	draw_string(font, Vector2(fx - 8, 178), "%d L" % roundi(truck.fuel), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	# warning lamps
	var lx := 460.0
	_lamp(font, Vector2(lx, 14), "ENG", Color(0.3, 0.9, 0.4) if truck.engine_on else Color(0.9, 0.25, 0.2), true)
	_lamp(font, Vector2(lx, 44), "P", Color(1.0, 0.25, 0.2), truck.handbrake_on)
	_lamp(font, Vector2(lx, 74), "LIGHT", Color(0.4, 0.75, 1.0), truck.headlights_on)
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.7) < 0.35
	_lamp(font, Vector2(lx, 104), "<  >", Color(0.3, 0.9, 0.4), truck.indicator != 0 and blink)
	_lamp(font, Vector2(lx, 134), ["WIPE", "WIPE", "WIPE+"][truck.wiper_mode], Color(0.4, 0.75, 1.0), truck.wiper_mode > 0)
	_lamp(font, Vector2(lx, 164), "AUTO" if truck.auto_transmission else "MAN", ACCENT, true)


func _lamp(font: Font, pos: Vector2, text: String, col: Color, on: bool) -> void:
	var r := Rect2(pos, Vector2(52, 24))
	draw_rect(r, col if on else Color(1, 1, 1, 0.08))
	draw_string(font, pos + Vector2(0, 17), text, HORIZONTAL_ALIGNMENT_CENTER, 52, 13, Color(0.05, 0.05, 0.05) if on else Color(1, 1, 1, 0.35))


func _dial(center: Vector2, r: float, value: float, max_v: float, step: float, red_from: float, label: String, col: Color, font: Font) -> void:
	var a0 := deg_to_rad(135.0)
	var a1 := deg_to_rad(405.0)
	draw_arc(center, r, a0, a1, 64, DIM, 6.0, true)
	draw_arc(center, r, lerpf(a0, a1, red_from / max_v), a1, 32, Color(0.9, 0.2, 0.15, 0.7), 6.0, true)
	var frac := clampf(value / max_v, 0.0, 1.0)
	draw_arc(center, r, a0, lerpf(a0, a1, frac), 64, col, 6.0, true)
	var n := int(max_v / step)
	for i in range(n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (r - 14.0), center + dir * (r - 4.0), Color(1, 1, 1, 0.75), 2.0)
		draw_string(font, center + dir * (r - 28.0) + Vector2(-15, 5), str(int(i * step)), HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color(1, 1, 1, 0.75))
	var na := lerpf(a0, a1, frac)
	draw_line(center, center + Vector2(cos(na), sin(na)) * (r - 12.0), Color(1.0, 0.3, 0.2), 3.0, true)
	draw_circle(center, 6.0, Color(0.9, 0.9, 0.9))
	draw_string(font, center + Vector2(-45, -r * 0.3), label, HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color(1, 1, 1, 0.55))
