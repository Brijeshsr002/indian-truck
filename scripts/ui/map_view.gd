class_name MapView
extends Control
## Road map drawn from the world's road data. Two uses:
##  - minimap: round, heading-up, follows the player
##  - full map: north-up overview of the region with landmarks (press M)

var world: CoimbatoreWorld
var game: Node
var full := false
var meters_radius := 260.0
var _pieces: Array = []


func setup(w: CoimbatoreWorld, g: Node, is_full: bool) -> void:
	world = w
	game = g
	full = is_full
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in world.map_roads:
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		var n := maxi(1, int(a.distance_to(b) / 30.0))
		for i in range(n):
			_pieces.append([a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), float(r["w"])])


var _redraw_t := 0.0


func _process(delta: float) -> void:
	_redraw_t -= delta
	if full and _redraw_t > 0.0:  # the heading-up minimap redraws every frame
		return
	_redraw_t = 1.0 / 15.0  # 15 redraws per second is plenty for gauges and maps
	if visible:
		queue_redraw()


func _draw() -> void:
	if world == null or game == null:
		return
	if full:
		_draw_full()
	else:
		_draw_mini()


func _draw_mini() -> void:
	var c := size * 0.5
	var R := minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(c, R + 3.0, Color(1, 1, 1, 0.2))
	draw_circle(c, R, Color(0.06, 0.08, 0.1, 0.88))
	var pos3: Vector3 = game.call("active_position")
	var fwd3: Vector3 = game.call("active_forward")
	var p := Vector2(pos3.x, pos3.z)
	var f := Vector2(fwd3.x, fwd3.z).normalized()
	var right := Vector2(-f.y, f.x)
	var k := R / meters_radius
	for piece in _pieces:
		var a: Vector2 = piece[0] - p
		var b: Vector2 = piece[1] - p
		var sa := Vector2(a.dot(right), -a.dot(f)) * k
		var sb := Vector2(b.dot(right), -b.dot(f)) * k
		if sa.length() > R - 2.0 or sb.length() > R - 2.0:
			continue
		draw_line(c + sa, c + sb, Color(0.75, 0.75, 0.72), maxf(2.0, float(piece[2]) * k), false)
	for lm in world.landmarks:
		var d: Vector2 = (lm["pos"] as Vector2) - p
		var s := Vector2(d.dot(right), -d.dot(f)) * k
		if s.length() < R - 6.0:
			draw_circle(c + s, 4.0, Color(1.0, 0.62, 0.15))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 7), c + Vector2(-6, 7)]), Color(0.3, 0.8, 1.0))
	var north := Vector2(0, -1)
	var ns := Vector2(north.dot(right), -north.dot(f)).normalized() * (R - 10.0)
	draw_string(ThemeDB.fallback_font, c + ns + Vector2(-6, 6), "N", HORIZONTAL_ALIGNMENT_CENTER, 12, 14, Color(1, 0.4, 0.3))


func _draw_full() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.07, 0.94))
	var font := ThemeDB.fallback_font
	var area := Rect2(-750, -950, 2450, 2400)
	var margin := 60.0
	var k := minf((size.x - margin * 2) / area.size.x, (size.y - margin * 2 - 30) / area.size.y)
	var origin := Vector2((size.x - area.size.x * k) * 0.5, margin + 30) - area.position * k
	draw_string(font, Vector2(margin, 42), "Coimbatore region  -  starter map  (press M to close)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.75, 0.3))
	for r in world.map_roads:
		var a: Vector2 = origin + (r["a"] as Vector2) * k
		var b: Vector2 = origin + (r["b"] as Vector2) * k
		draw_line(a, b, Color(0.8, 0.8, 0.76), maxf(3.0, float(r["w"]) * k), true)
	var seen := {}
	for r in world.map_roads:
		var nm: String = r["name"]
		if seen.has(nm):
			continue
		seen[nm] = true
		var mid: Vector2 = origin + ((r["a"] as Vector2) + (r["b"] as Vector2)) * 0.5 * k
		draw_string(font, mid + Vector2(6, -6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.85, 1.0))
	for lm in world.landmarks:
		var lp: Vector2 = origin + (lm["pos"] as Vector2) * k
		draw_circle(lp, 5.0, Color(1.0, 0.62, 0.15))
		draw_string(font, lp + Vector2(8, 4), lm["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.6))
	for ar in world.areas:
		var ap: Vector2 = origin + (ar["pos"] as Vector2) * k
		draw_string(font, ap + Vector2(-40, 22), ar["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 1, 1, 0.45))
	var pos3: Vector3 = game.call("active_position")
	var fwd3: Vector3 = game.call("active_forward")
	var pp := origin + Vector2(pos3.x, pos3.z) * k
	var f := Vector2(fwd3.x, fwd3.z).normalized()
	var rt := Vector2(-f.y, f.x)
	draw_colored_polygon(PackedVector2Array([pp + f * 12.0, pp - f * 7.0 + rt * 7.0, pp - f * 7.0 - rt * 7.0]), Color(0.3, 0.8, 1.0))
	draw_string(font, Vector2(margin, size.y - 24), "North is up. Other states unlock in later updates.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))
