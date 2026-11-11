class_name CoimbatoreWorld
extends Node3D
## Coimbatore starter region (inspired by the real layout, not an exact map).
## North is -Z, east is +X. Roads, ground, flyover, hills and signals are always
## loaded. Buildings, trees, street lights and landmarks are planned as light data
## "specs" per 250 m chunk and built or freed by the WorldStreamer.

const CHUNK := 250.0
const BOUNDS := Rect2(-1000, -1200, 2800, 2900)
const ASPHALT := Color(0.24, 0.24, 0.25)
const SHOULDER := Color(0.52, 0.4, 0.3)
const WHITE := Color(0.92, 0.92, 0.9)
const YELLOW := Color(0.95, 0.76, 0.1)
const GROUND := Color(0.44, 0.46, 0.29)
const CONCRETE := Color(0.62, 0.61, 0.58)
const ROAD_Y := 0.03
const FLY_X := [-430.0, -310.0, -190.0, -70.0]
const FLY_H := 6.5
const FLY_W := 13.0

const BRIGHT := [Color(0.95, 0.85, 0.55), Color(0.55, 0.75, 0.9), Color(0.95, 0.62, 0.5),
	Color(0.75, 0.9, 0.7), Color(0.97, 0.95, 0.9), Color(0.9, 0.7, 0.85), Color(0.98, 0.8, 0.35),
	Color(0.6, 0.85, 0.85), Color(0.92, 0.9, 0.82)]
const SIGN_COLORS := [Color(0.75, 0.1, 0.1), Color(0.1, 0.3, 0.7), Color(0.1, 0.5, 0.25),
	Color(0.95, 0.75, 0.1), Color(0.5, 0.1, 0.5), Color(0.95, 0.95, 0.95)]
const SHOP_NAMES := ["MURUGAN STORES", "VELAN HARDWARE", "KUMARAN MEDICALS", "ARUL MOBILES",
	"KAVITHA FANCY STORE", "SIVA TYRES", "THANGAM JEWELLERY", "GANESH HOTEL", "SELVI BAKERY",
	"KOVAI TEXTILES", "ANBU ELECTRICALS", "RAJA AUTO SPARES", "MEENA SILKS", "VIJAY PHOTO STUDIO",
	"BALAJI SWEETS", "SAKTHI PAINTS", "LAKSHMI RICE MANDI", "SUN OPTICALS", "AMMAN TRADERS",
	"KRISHNA MOTORS", "PRIYA BOOK CENTRE", "SRI VARI CLINIC", "ROYAL TAILORS", "NILGIRI TEA DEPOT"]
const MILL_NAMES := ["SRI LAKSHMI TEXTILES", "NOYYAL WEAVING MILLS", "KONGU GARMENTS",
	"SIRUVANI COTTON MILLS", "PALANI PUMPS", "KOVAI FOUNDRY WORKS"]

var roads: Array = []
var map_roads: Array = []
var junctions: Array = []
var areas: Array = []
var landmarks: Array = []
var chunk_specs := {}
var exclusions: Array[Rect2] = []
var spawn_transform := Transform3D.IDENTITY
var streamer: WorldStreamer
var lamp_material: StandardMaterial3D
var signal_mats := {}

var _signal_t := 0.0
var _occupied := {}
var _rng := RandomNumberGenerator.new()
var _tree_density := 0.45
var _tree_meshes := {}
var label_range := 70.0


func _ready() -> void:
	_rng.seed = 2026
	var p := GameConfig.preset()
	_tree_density = float(p["tree_density"])
	label_range = float(p["label_range"])
	lamp_material = MeshKit.emissive(Color(1.0, 0.85, 0.55), 0.0)
	_define_layout()
	_find_junctions()
	_build_ground()
	_build_roads()
	_build_flyover()
	_build_hills()
	_build_boundaries()
	_build_signals()
	_plan_landmarks()
	_plan_buildings()
	_plan_trees()
	_plan_streetlights()
	_plan_fields()
	streamer = WorldStreamer.new()
	streamer.name = "Streamer"
	streamer.world = self
	streamer.radius = float(p["stream_radius"])
	add_child(streamer)


func _process(delta: float) -> void:
	_signal_t = fmod(_signal_t + delta, 30.0)
	var a_green := _signal_t < 12.0
	var a_amber := _signal_t >= 12.0 and _signal_t < 15.0
	var b_green := _signal_t >= 15.0 and _signal_t < 27.0
	var b_amber := _signal_t >= 27.0
	_set_sig("A_green", a_green)
	_set_sig("A_amber", a_amber)
	_set_sig("A_red", not (a_green or a_amber))
	_set_sig("B_green", b_green)
	_set_sig("B_amber", b_amber)
	_set_sig("B_red", not (b_green or b_amber))


func _set_sig(key: String, on: bool) -> void:
	if signal_mats.has(key):
		(signal_mats[key] as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.05


func set_night(on: bool) -> void:
	lamp_material.emission_energy_multiplier = 3.0 if on else 0.0


# ================================================================ layout

func _road(road_name: String, a: Vector2, b: Vector2, w: float) -> void:
	roads.append({"name": road_name, "a": a, "b": b, "w": w})


func _define_layout() -> void:
	_road("Avinashi Road", Vector2(-600, 0), Vector2(-430, 0), 16.0)
	_road("Avinashi Road", Vector2(-70, 0), Vector2(1500, 0), 16.0)
	_road("Mettupalayam Road", Vector2(-500, 0), Vector2(-500, -900), 12.0)
	_road("Ukkadam Road", Vector2(-600, 0), Vector2(-600, 700), 12.0)
	_road("Pollachi Road", Vector2(-600, 700), Vector2(-600, 1400), 12.0)
	_road("Trichy Road", Vector2(-600, 700), Vector2(1100, 700), 14.0)
	_road("Sulur Road", Vector2(1100, 700), Vector2(1600, 700), 14.0)
	_road("Coimbatore Bypass", Vector2(1100, 0), Vector2(1100, 700), 14.0)
	_road("Peelamedu - Singanallur Road", Vector2(300, 0), Vector2(300, 700), 12.0)
	_road("Gandhipuram Cross Road", Vector2(-250, -350), Vector2(-250, 700), 12.0)
	map_roads = roads.duplicate()
	map_roads.append({"name": "Avinashi Road Flyover", "a": Vector2(-430, 0), "b": Vector2(-70, 0), "w": FLY_W})
	areas = [
		{"name": "Gandhipuram", "pos": Vector2(-520, -60)},
		{"name": "Mettupalayam Road", "pos": Vector2(-500, -550)},
		{"name": "Ukkadam", "pos": Vector2(-640, 380)},
		{"name": "Pollachi Road", "pos": Vector2(-600, 1150)},
		{"name": "Peelamedu", "pos": Vector2(120, 180)},
		{"name": "Hope College", "pos": Vector2(560, 120)},
		{"name": "Ramanathapuram", "pos": Vector2(-250, 560)},
		{"name": "Singanallur", "pos": Vector2(320, 650)},
		{"name": "Neelambur", "pos": Vector2(1300, 20)},
		{"name": "Coimbatore Bypass", "pos": Vector2(1100, 360)},
		{"name": "Sulur", "pos": Vector2(1500, 700)},
	]


func _find_junctions() -> void:
	for i in range(roads.size()):
		for j in range(i + 1, roads.size()):
			var r1: Dictionary = roads[i]
			var r2: Dictionary = roads[j]
			var hit = Geometry2D.segment_intersects_segment(r1["a"], r1["b"], r2["a"], r2["b"])
			if hit == null:
				continue
			var pt: Vector2 = hit
			var pad: float = maxf(float(r1["w"]), float(r2["w"])) + 8.0
			var merged := false
			for jn in junctions:
				if (jn[0] as Vector2).distance_to(pt) < 2.0:
					jn[1] = maxf(float(jn[1]), pad)
					merged = true
			if not merged:
				junctions.append([pt, pad])


func zone_at(p: Vector2) -> String:
	if p.y > 1000.0 or p.y < -450.0 or p.x > 1450.0 or p.x < -700.0:
		return "rural"
	if p.x > 1050.0 and p.y < 450.0:
		return "industrial"
	if p.x < -380.0 and p.y < 450.0:
		return "commercial"
	if absf(p.y) < 70.0 or absf(p.y - 700.0) < 60.0:
		return "commercial"
	return "residential"


static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)


func location_name(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	var road_name := ""
	var best_road := INF
	for r in map_roads:
		var d := dist_to_segment(q, r["a"], r["b"])
		if d < float(r["w"]) * 0.5 + 12.0 and d < best_road:
			best_road = d
			road_name = r["name"]
	var area_name := ""
	var best_area := INF
	for a in areas:
		var d2: float = (a["pos"] as Vector2).distance_to(q)
		if d2 < best_area:
			best_area = d2
			area_name = a["name"]
	if road_name == "":
		return area_name + ", Coimbatore"
	if road_name == area_name:
		return road_name
	return "%s, %s" % [road_name, area_name]


func chunk_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CHUNK), floori(z / CHUNK))


func _add_spec(s: Dictionary) -> void:
	var p: Vector3 = s["pos"]
	var k := chunk_key(p.x, p.z)
	if not chunk_specs.has(k):
		chunk_specs[k] = []
	chunk_specs[k].append(s)


# ================================================================ static world

func _build_ground() -> void:
	var b := MeshBatcher.new()
	b.add_flat(Vector3(400, 0, 250), 7000.0, 7000.0, GROUND)
	var mi := MeshKit.mesh_instance(self, b.commit())
	mi.name = "Ground"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	add_child(body)
	MeshKit.col_box(body, Transform3D(Basis(), Vector3(400, -0.5, 250)), Vector3(7000, 1, 7000))


func _strip(b: MeshBatcher, a: Vector2, e: Vector2, width: float, y: float, c: Color) -> void:
	var dir := (e - a).normalized()
	var n := Vector2(-dir.y, dir.x) * width * 0.5
	b.add_quad(Vector3(a.x + n.x, y, a.y + n.y), Vector3(e.x + n.x, y, e.y + n.y),
		Vector3(e.x - n.x, y, e.y - n.y), Vector3(a.x - n.x, y, a.y - n.y), Vector3.UP, c)


func _gaps_for(r: Dictionary) -> Array:
	var a: Vector2 = r["a"]
	var e: Vector2 = r["b"]
	var dir := (e - a).normalized()
	var gaps := []
	for jn in junctions:
		var jp: Vector2 = jn[0]
		if dist_to_segment(jp, a, e) < 1.0:
			var t := (jp - a).dot(dir)
			var half: float = float(jn[1]) * 0.5 + 1.0
			gaps.append([t - half, t + half])
	return gaps


static func _in_gap(t0: float, t1: float, gaps: Array) -> bool:
	for g in gaps:
		if t1 > float(g[0]) and t0 < float(g[1]):
			return true
	return false


func _line(b: MeshBatcher, r: Dictionary, offset: float, dash: float, step: float, width: float, c: Color, gaps: Array) -> void:
	var a: Vector2 = r["a"]
	var e: Vector2 = r["b"]
	var length := a.distance_to(e)
	var dir := (e - a) / length
	var n := Vector2(-dir.y, dir.x)
	var t := 0.0
	while t < length:
		var t1 := minf(t + dash, length)
		if not _in_gap(t, t1, gaps):
			var p0 := a + dir * t + n * offset
			var p1 := a + dir * t1 + n * offset
			_strip(b, p0, p1, width, ROAD_Y + 0.012, c)
		t += step


## Painted black-and-yellow median kerb (visual). Street lights stand on it.
func _median(b: MeshBatcher, r: Dictionary, gaps: Array) -> void:
	var a: Vector2 = r["a"]
	var e: Vector2 = r["b"]
	var length := a.distance_to(e)
	var dir := (e - a) / length
	var bas := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	var t := 0.0
	var i := 0
	while t < length:
		var t1 := minf(t + 2.0, length)
		if not _in_gap(t, t1, gaps):
			var c := a + dir * (t + t1) * 0.5
			b.add_box(Transform3D(bas, Vector3(c.x, 0.15, c.y)), Vector3(t1 - t, 0.3, 0.8), YELLOW if i % 2 == 0 else Color(0.1, 0.1, 0.1))
		t += 2.0
		i += 1


func _build_roads() -> void:
	var b := MeshBatcher.new()
	for r in roads:
		var w: float = r["w"]
		_strip(b, r["a"], r["b"], w + 5.0, 0.015, SHOULDER)
		_strip(b, r["a"], r["b"], w, ROAD_Y, ASPHALT)
	for jn in junctions:
		var jp: Vector2 = jn[0]
		var pad: float = jn[1]
		b.add_flat(Vector3(jp.x, ROAD_Y, jp.y), pad, pad, ASPHALT)
		b.add_flat(Vector3(jp.x, 0.015, jp.y), pad + 5.0, pad + 5.0, SHOULDER)
	for r in roads:
		var w2: float = r["w"]
		var gaps := _gaps_for(r)
		_line(b, r, w2 * 0.5 - 0.35, 10.0, 10.0, 0.15, WHITE, gaps)
		_line(b, r, -(w2 * 0.5 - 0.35), 10.0, 10.0, 0.15, WHITE, gaps)
		if w2 >= 15.0:
			_median(b, r, gaps)
			_line(b, r, w2 * 0.25, 3.0, 9.0, 0.13, WHITE, gaps)
			_line(b, r, -w2 * 0.25, 3.0, 9.0, 0.13, WHITE, gaps)
		else:
			_line(b, r, 0.0, 3.0, 9.0, 0.13, WHITE, gaps)
	# zebra crossings near the big junctions
	for jn in junctions:
		var jp2: Vector2 = jn[0]
		var off: float = float(jn[1]) * 0.5 + 3.0
		for k in range(8):
			var x := jp2.x - off - 1.0
			b.add_flat(Vector3(x, ROAD_Y + 0.012, jp2.y - 6.0 + k * 1.6), 3.0, 0.7, WHITE)
	var mi := MeshKit.mesh_instance(self, b.commit())
	mi.name = "Roads"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func flyover_height(x: float) -> float:
	var x0: float = FLY_X[0]
	var x1: float = FLY_X[1]
	var x2: float = FLY_X[2]
	var x3: float = FLY_X[3]
	if x <= x0 or x >= x3:
		return 0.0
	if x < x1:
		return (x - x0) / (x1 - x0) * FLY_H
	if x <= x2:
		return FLY_H
	return FLY_H * (1.0 - (x - x2) / (x3 - x2))


func _build_flyover() -> void:
	var b := MeshBatcher.new()
	var body := StaticBody3D.new()
	body.name = "Flyover"
	body.collision_layer = 1
	add_child(body)
	var pts := [Vector2(FLY_X[0], 0), Vector2(FLY_X[1], FLY_H), Vector2(FLY_X[2], FLY_H), Vector2(FLY_X[3], 0)]
	for i in range(3):
		_fly_piece(b, body, pts[i], pts[i + 1])
	for px: float in [-360.0, -290.0, -210.0, -140.0]:
		var h := flyover_height(px) - 1.0
		if h > 1.0:
			b.add_cylinder(Transform3D(Basis(), Vector3(px, h * 0.5, 0)), 0.9, 0.9, h, 10, CONCRETE)
			b.add_box(Transform3D(Basis(), Vector3(px, h - 0.3, 0)), Vector3(2.0, 0.6, FLY_W - 1.0), CONCRETE)
			MeshKit.col_cylinder(body, Vector3(px, h * 0.5, 0), 0.9, h)
	# lane markings that follow the slope
	var x := float(FLY_X[0]) + 2.0
	while x < float(FLY_X[3]) - 4.0:
		var y0 := flyover_height(x) + 0.03
		var y1 := flyover_height(x + 3.0) + 0.03
		b.add_quad(Vector3(x, y0, -0.07), Vector3(x + 3.0, y1, -0.07), Vector3(x + 3.0, y1, 0.07), Vector3(x, y0, 0.07), Vector3.UP, YELLOW)
		x += 9.0
	var mi := MeshKit.mesh_instance(self, b.commit())
	mi.name = "FlyoverMesh"
	MeshKit.label3d(self, "AVINASHI ROAD FLYOVER", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-310, FLY_H + 2.2, -6.6)), 48, Color(0.95, 0.95, 0.9), 0.012, 0.0)


func _fly_piece(b: MeshBatcher, body: StaticBody3D, p0: Vector2, p1: Vector2) -> void:
	var d := p1 - p0
	var length := d.length()
	var ang := atan2(d.y, d.x)
	var n := Vector2(-sin(ang), cos(ang))
	var mid := (p0 + p1) * 0.5
	var basis := Basis(Vector3(0, 0, 1), ang)
	var deck_xf := Transform3D(basis, Vector3(mid.x - n.x * 0.5, mid.y - n.y * 0.5, 0))
	var deck_size := Vector3(length + 0.3, 1.0, FLY_W)
	b.add_box(deck_xf, deck_size, CONCRETE, true)
	MeshKit.col_box(body, deck_xf, deck_size)
	var hw := FLY_W * 0.5 - 0.5
	var lift := Vector3(-sin(ang), cos(ang), 0) * 0.015
	b.add_quad(Vector3(p0.x, p0.y, -hw) + lift, Vector3(p1.x, p1.y, -hw) + lift,
		Vector3(p1.x, p1.y, hw) + lift, Vector3(p0.x, p0.y, hw) + lift, Vector3(-sin(ang), cos(ang), 0), ASPHALT)
	for sz: float in [-1.0, 1.0]:
		var wall_xf := Transform3D(basis, Vector3(mid.x + n.x * 0.5, mid.y + n.y * 0.5, sz * (FLY_W * 0.5 - 0.2)))
		var wall_size := Vector3(length + 0.3, 1.0, 0.4)
		b.add_box(wall_xf, wall_size, Color(0.85, 0.84, 0.8))
		MeshKit.col_box(body, wall_xf, wall_size)


func _build_hills() -> void:
	var b := MeshBatcher.new()
	var hills := [
		[Vector2(-1900, -600), 700.0, 420.0], [Vector2(-2100, 200), 800.0, 560.0],
		[Vector2(-1800, 900), 600.0, 380.0], [Vector2(-2300, -1300), 900.0, 700.0],
		[Vector2(-900, -2300), 1000.0, 820.0], [Vector2(200, -2500), 900.0, 650.0],
		[Vector2(-1500, 1900), 700.0, 450.0], [Vector2(-2600, 1100), 900.0, 600.0],
	]
	for h in hills:
		var hp: Vector2 = h[0]
		var c := Color(0.3, 0.4, 0.3).lerp(Color(0.42, 0.5, 0.55), clampf(hp.length() / 3000.0, 0.0, 1.0))
		b.add_cylinder(Transform3D(Basis(), Vector3(hp.x, float(h[2]) * 0.5 - 5.0, hp.y)), float(h[1]), float(h[1]) * 0.15, float(h[2]), 11, c)
	var mi := MeshKit.mesh_instance(self, b.commit())
	mi.name = "Hills"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_boundaries() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	add_child(body)
	var r := BOUNDS
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + r.size.y * 0.5
	MeshKit.col_box(body, Transform3D(Basis(), Vector3(r.position.x, 10, cz)), Vector3(2, 20, r.size.y))
	MeshKit.col_box(body, Transform3D(Basis(), Vector3(r.end.x, 10, cz)), Vector3(2, 20, r.size.y))
	MeshKit.col_box(body, Transform3D(Basis(), Vector3(cx, 10, r.position.y)), Vector3(r.size.x, 20, 2))
	MeshKit.col_box(body, Transform3D(Basis(), Vector3(cx, 10, r.end.y)), Vector3(r.size.x, 20, 2))


func _build_signals() -> void:
	for key in ["A_red", "A_amber", "A_green", "B_red", "B_amber", "B_green"]:
		var col := Color(1.0, 0.1, 0.05)
		if key.ends_with("amber"):
			col = Color(1.0, 0.6, 0.0)
		elif key.ends_with("green"):
			col = Color(0.1, 1.0, 0.3)
		signal_mats[key] = MeshKit.emissive(col, 0.05)
	var poles := MeshBatcher.new()
	var lamp_batches := {}
	for key in signal_mats.keys():
		lamp_batches[key] = MeshBatcher.new()
	var body := StaticBody3D.new()
	body.name = "Signals"
	body.collision_layer = 1
	add_child(body)
	for sp in [Vector2(-500, 0), Vector2(300, 0), Vector2(300, 700), Vector2(1100, 0), Vector2(-250, 700)]:
		var pad := 20.0
		for jn in junctions:
			if (jn[0] as Vector2).distance_to(sp) < 2.0:
				pad = jn[1]
		var pole := Vector3(sp.x + pad * 0.5 + 1.5, 0, sp.y + pad * 0.5 + 1.5)
		poles.add_cylinder(Transform3D(Basis(), pole + Vector3(0, 2.9, 0)), 0.12, 0.1, 5.8, 8, Color(0.2, 0.2, 0.2))
		MeshKit.col_cylinder(body, pole + Vector3(0, 2.9, 0), 0.15, 5.8)
		for head in [["A", PI / 2], ["B", 0.0]]:
			var group: String = head[0]
			var yaw: float = head[1]
			var hb := Basis(Vector3.UP, yaw)
			var hp := pole + Vector3(0, 5.2, 0) + hb.z * 0.2
			poles.add_box(Transform3D(hb, hp), Vector3(0.42, 1.15, 0.3), Color(0.08, 0.08, 0.08))
			var lamps := [["red", 0.36], ["amber", 0.0], ["green", -0.36]]
			for l in lamps:
				var lb: MeshBatcher = lamp_batches["%s_%s" % [group, l[0]]]
				lb.add_box(Transform3D(hb, hp + hb.z * 0.16 + Vector3(0, float(l[1]), 0)), Vector3(0.24, 0.24, 0.03), Color.WHITE)
	MeshKit.mesh_instance(self, poles.commit()).name = "SignalPoles"
	for key in lamp_batches.keys():
		var mi := MeshKit.mesh_instance(self, (lamp_batches[key] as MeshBatcher).commit(signal_mats[key]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================ planning

func _lm(kind: String, pos: Vector3, yaw: float, rect: Rect2, title: String, extra := {}) -> void:
	var s := {"t": "lm", "kind": kind, "pos": pos, "yaw": yaw}
	s.merge(extra)
	_add_spec(s)
	if rect.size.x > 0.0:
		exclusions.append(rect)
	if title != "":
		landmarks.append({"name": title, "pos": Vector2(pos.x, pos.z)})


func _plan_landmarks() -> void:
	_lm("yard", Vector3(340, 0, 365), -PI / 2, Rect2(306, 318, 76, 94), "Sri Murugan Transport yard")
	_lm("petrol", Vector3(150, 0, 32), PI, Rect2(115, 10, 70, 46), "Kovai Fuels")
	_lm("bus_stand", Vector3(-551, 0, -52), 0.0, Rect2(-594, -96, 88, 86), "Gandhipuram Bus Stand")
	_lm("temple", Vector3(-690, 0, 380), PI / 2, Rect2(-745, 325, 143, 110), "Murugan Temple")
	_lm("mill", Vector3(1260, 0, -62), 0.0, Rect2(1200, -125, 120, 115), "Kovai Spinning Mills")
	_lm("logistics", Vector3(1300, 0, 66), PI, Rect2(1230, 12, 140, 110), "Kovai Logistics Park")
	_lm("railway", Vector3(-600, 0, 1000), 0.0, Rect2(-905, 990, 610, 20), "Railway level crossing")
	_lm("arch", Vector3(650, 0, 0), PI / 2, Rect2(638, -16, 24, 32), "")
	_lm("tea_stall", Vector3(500, 0, 728), PI, Rect2(478, 708, 44, 30), "Kumar Tea Stall")
	_lm("board", Vector3(-420, 0, -12), PI / 2, Rect2(-424, -16, 8, 8), "", {"text": "GANDHIPURAM  1 km\nMETTUPALAYAM ROAD  |  OOTY", "w": 7.0})
	_lm("board", Vector3(600, 0, 12), -PI / 2, Rect2(596, 8, 8, 8), "", {"text": "NEELAMBUR  2 km\nTIRUPPUR  48 km  |  AVINASHI  30 km", "w": 7.5})
	_lm("board", Vector3(-588, 0, 760), PI, Rect2(-592, 756, 8, 8), "", {"text": "POLLACHI  38 km\nUDUMALPET  |  MUNNAR", "w": 6.5})
	_lm("board", Vector3(1112, 0, 640), PI, Rect2(1108, 636, 8, 8), "", {"text": "SULUR  12 km\nTRICHY ROAD  |  KARUR", "w": 6.5})
	_lm("milestone", Vector3(850, 0, 10), -PI / 2, Rect2(848, 8, 4, 4), "", {"text": "TIRUPPUR\n50"})
	_lm("milestone", Vector3(-490, 0, -700), PI / 2, Rect2(-492, -702, 4, 4), "", {"text": "METTUPALAYAM\n33"})
	_lm("milestone", Vector3(-591, 0, 1250), PI / 2, Rect2(-593, 1248, 4, 4), "", {"text": "POLLACHI\n36"})
	_lm("milestone", Vector3(1500, 0, 709), -PI / 2, Rect2(1498, 707, 4, 4), "", {"text": "SULUR\n12"})
	spawn_transform = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(342, 1.1, 365))


func _site_ok(center: Vector2, sx: float, sz: float, yaw: float) -> bool:
	var b := Basis(Vector3.UP, yaw)
	var ax := Vector2(b.x.x, b.x.z) * sx * 0.5
	var az := Vector2(b.z.x, b.z.z) * sz * 0.5
	var pts := [center, center + ax + az, center + ax - az, center - ax + az, center - ax - az]
	var rect := Rect2(center, Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	if not BOUNDS.grow(-20.0).encloses(rect):
		return false
	for ex in exclusions:
		if ex.intersects(rect):
			return false
	for p in pts:
		for r in map_roads:
			if dist_to_segment(p, r["a"], r["b"]) < float(r["w"]) * 0.5 + 3.0:
				return false
	var k := chunk_key(center.x, center.y)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var kk := Vector2i(k.x + dx, k.y + dz)
			if _occupied.has(kk):
				for o in _occupied[kk]:
					if (o as Rect2).intersects(rect.grow(0.5)):
						return false
	if not _occupied.has(k):
		_occupied[k] = []
	_occupied[k].append(rect)
	return true


func _plan_buildings() -> void:
	var shop_i := 0
	var mill_i := 0
	for r in roads:
		var a: Vector2 = r["a"]
		var e: Vector2 = r["b"]
		var w: float = r["w"]
		var length := a.distance_to(e)
		var dir := (e - a) / length
		var nrm := Vector2(-dir.y, dir.x)
		for side: float in [-1.0, 1.0]:
			var t := 8.0 + _rng.randf_range(0.0, 8.0)
			while t < length - 8.0:
				var p := a + dir * t
				var zone := zone_at(p + nrm * side * 25.0)
				var width := 10.0
				var depth := 10.0
				var height := 3.2
				var gap := 1.0
				var extra := 0.0
				var t_kind := "bld"
				match zone:
					"commercial":
						width = _rng.randf_range(7.0, 14.0)
						depth = _rng.randf_range(10.0, 15.0)
						height = 3.2 * _rng.randi_range(2, 5)
						gap = _rng.randf_range(0.0, 1.5)
					"residential":
						width = _rng.randf_range(8.0, 12.0)
						depth = _rng.randf_range(8.0, 12.0)
						height = 3.2 * _rng.randi_range(1, 3)
						gap = _rng.randf_range(4.0, 9.0)
						extra = 4.0
					"industrial":
						width = _rng.randf_range(35.0, 65.0)
						depth = _rng.randf_range(25.0, 42.0)
						height = _rng.randf_range(8.0, 11.0)
						gap = _rng.randf_range(12.0, 25.0)
						extra = 9.0
						t_kind = "fac" if _rng.randf() < 0.6 else "ware"
					"rural":
						width = _rng.randf_range(6.0, 9.0)
						depth = _rng.randf_range(6.0, 8.0)
						height = 3.0
						gap = _rng.randf_range(25.0, 70.0)
						extra = _rng.randf_range(4.0, 14.0)
						t_kind = "house"
				var setback := w * 0.5 + 4.0 + extra + depth * 0.5
				var center := a + dir * (t + width * 0.5) + nrm * side * setback
				var face := -nrm * side
				var yaw := atan2(face.x, face.y)
				var skip := zone == "rural" and _rng.randf() < 0.45
				if not skip and _site_ok(center, width, depth, yaw):
					var spec := {"t": t_kind, "pos": Vector3(center.x, 0, center.y), "yaw": yaw,
						"size": Vector3(width, height, depth), "zone": zone,
						"color": BRIGHT[_rng.randi() % BRIGHT.size()], "tank": _rng.randf() < 0.5}
					if zone == "commercial":
						spec["sign"] = SHOP_NAMES[shop_i % SHOP_NAMES.size()]
						spec["sign_color"] = SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()]
						spec["awning"] = SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()]
						shop_i += 1
					elif t_kind == "fac" or t_kind == "ware":
						spec["sign"] = MILL_NAMES[mill_i % MILL_NAMES.size()] if t_kind == "fac" else "KOVAI WAREHOUSING %d" % (mill_i + 1)
						spec["chimney"] = _rng.randf() < 0.5
						spec["color"] = [Color(0.78, 0.76, 0.7), Color(0.65, 0.7, 0.75), Color(0.85, 0.82, 0.74)][mill_i % 3]
						mill_i += 1
					_add_spec(spec)
				t += width + gap


func _tree_ok(p: Vector2) -> bool:
	if not BOUNDS.grow(-10.0).has_point(p):
		return false
	for ex in exclusions:
		if ex.grow(2.0).has_point(p):
			return false
	for r in map_roads:
		if dist_to_segment(p, r["a"], r["b"]) < float(r["w"]) * 0.5 + 2.0:
			return false
	var k := chunk_key(p.x, p.y)
	if _occupied.has(k):
		for o in _occupied[k]:
			if (o as Rect2).grow(1.0).has_point(p):
				return false
	return true


func _plan_trees() -> void:
	for r in roads:
		var a: Vector2 = r["a"]
		var e: Vector2 = r["b"]
		var w: float = r["w"]
		var length := a.distance_to(e)
		var dir := (e - a) / length
		var nrm := Vector2(-dir.y, dir.x)
		for side: float in [-1.0, 1.0]:
			var t := _rng.randf_range(0.0, 20.0)
			while t < length:
				var p := a + dir * t + nrm * side * (w * 0.5 + 3.2)
				var zone := zone_at(p)
				var base_chance: float = {"commercial": 0.25, "residential": 0.7, "industrial": 0.35, "rural": 0.85}[zone]
				var chance := base_chance * _tree_density
				if _rng.randf() < chance and _tree_ok(p):
					var kind := "palm" if (zone == "rural" and _rng.randf() < 0.6) else "neem"
					_add_spec({"t": "tree", "kind": kind, "pos": Vector3(p.x, 0, p.y), "rot": _rng.randf() * TAU, "s": _rng.randf_range(0.8, 1.25)})
				t += _rng.randf_range(14.0, 26.0)
	# coconut groves and scattered trees in the countryside
	var groves := int(140 * _tree_density)
	for i in range(groves):
		var c := Vector2(_rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), _rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
		var zone := zone_at(c)
		if zone != "rural" and _rng.randf() < 0.75:
			continue
		var count := _rng.randi_range(4, 12) if zone == "rural" else _rng.randi_range(1, 3)
		for j in range(count):
			var p := c + Vector2(_rng.randf_range(-25.0, 25.0), _rng.randf_range(-25.0, 25.0))
			if _tree_ok(p):
				var kind := "palm" if zone == "rural" and _rng.randf() < 0.75 else "neem"
				_add_spec({"t": "tree", "kind": kind, "pos": Vector3(p.x, 0, p.y), "rot": _rng.randf() * TAU, "s": _rng.randf_range(0.8, 1.3)})


func _plan_streetlights() -> void:
	for r in roads:
		var road_name: String = r["name"]
		if road_name != "Avinashi Road" and road_name != "Trichy Road":
			continue
		var a: Vector2 = r["a"]
		var e: Vector2 = r["b"]
		var length := a.distance_to(e)
		var dir := (e - a) / length
		var nrm := Vector2(-dir.y, dir.x)
		var gaps := _gaps_for(r)
		var t := 20.0
		while t < length - 10.0:
			if not _in_gap(t - 4.0, t + 4.0, gaps):
				var p := a + dir * t
				if road_name == "Avinashi Road":
					_add_spec({"t": "lamp", "pos": Vector3(p.x, 0, p.y), "n": nrm, "arms": [1.0, -1.0]})
				else:
					var q := p + nrm * (float(r["w"]) * 0.5 + 1.2)
					_add_spec({"t": "lamp", "pos": Vector3(q.x, 0, q.y), "n": nrm, "arms": [-1.0]})
			t += 42.0


func _plan_fields() -> void:
	var cols := [Color(0.42, 0.55, 0.22), Color(0.6, 0.6, 0.3), Color(0.35, 0.48, 0.2), Color(0.55, 0.45, 0.3)]
	for i in range(90):
		var c := Vector2(_rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), _rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
		if zone_at(c) != "rural":
			continue
		var sx := _rng.randf_range(30.0, 80.0)
		var sz := _rng.randf_range(30.0, 80.0)
		var rect := Rect2(c - Vector2(sx, sz) * 0.5, Vector2(sx, sz))
		var ok := true
		for r in map_roads:
			if dist_to_segment(c, r["a"], r["b"]) < float(r["w"]) * 0.5 + maxf(sx, sz) * 0.75:
				ok = false
				break
		for ex in exclusions:
			if ex.intersects(rect):
				ok = false
		if ok:
			_add_spec({"t": "field", "pos": Vector3(c.x, 0, c.y), "sx": sx, "sz": sz, "color": cols[i % cols.size()]})


# ================================================================ chunk building

func build_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	var b := MeshBatcher.new()
	var lamps := MeshBatcher.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var trees := {"neem": [], "palm": []}
	for s in chunk_specs.get(key, []):
		match String(s["t"]):
			"bld":
				_emit_building(s, b, body, root)
			"fac":
				_emit_factory(s, b, body, root)
			"ware":
				_emit_warehouse(s, b, body, root)
			"house":
				_emit_house(s, b, body)
			"tree":
				trees[s["kind"]].append(s)
			"lamp":
				_emit_streetlight(s, b, lamps, body)
			"field":
				b.add_flat(s["pos"] + Vector3(0, 0.02, 0), float(s["sx"]), float(s["sz"]), s["color"])
			"lm":
				Landmarks.build(s, b, lamps, body, root, self)
	if not b.is_empty():
		var mi := MeshKit.mesh_instance(root, b.commit())
		mi.name = "Static"
	if not lamps.is_empty():
		var lm := MeshKit.mesh_instance(root, lamps.commit(lamp_material))
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for kind in trees.keys():
		var list: Array = trees[kind]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _tree_mesh(kind)
		mm.instance_count = list.size()
		for i in range(list.size()):
			var ts: Dictionary = list[i]
			var sc: float = ts["s"]
			var pos: Vector3 = ts["pos"]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(ts["rot"])).scaled(Vector3(sc, sc, sc)), pos))
			MeshKit.col_cylinder(body, pos + Vector3(0, 2.0, 0), 0.3 * sc, 4.0)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
	return root


func _emit_building(s: Dictionary, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	var size: Vector3 = s["size"]
	var col: Color = s["color"]
	var zone: String = s["zone"]
	var L := Transform3D(Basis(Vector3.UP, float(s["yaw"])), s["pos"])
	var main_xf := L * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0))
	b.add_box(main_xf, size, col)
	MeshKit.col_box(body, main_xf, size)
	b.add_box(L * Transform3D(Basis(), Vector3(0, size.y + 0.15, 0)), Vector3(size.x + 0.2, 0.3, size.z + 0.2), col.darkened(0.2))
	var front := size.z * 0.5
	var floors := maxi(1, int(size.y / 3.2))
	var glass := Color(0.17, 0.22, 0.28)
	var first := 1 if zone == "commercial" else 0
	for f in range(first, floors):
		var y := f * 3.2 + 1.8
		var nwin := maxi(1, int((size.x - 1.0) / 2.6))
		var spacing := (size.x - 1.0) / nwin
		for i in range(nwin):
			var x := -size.x * 0.5 + 0.5 + spacing * (i + 0.5)
			b.add_box(L * Transform3D(Basis(), Vector3(x, y, front + 0.04)), Vector3(1.1, 1.3, 0.1), glass)
			b.add_box(L * Transform3D(Basis(), Vector3(x, y + 0.82, front + 0.25)), Vector3(1.4, 0.08, 0.5), col.darkened(0.15))
	if zone == "commercial":
		b.add_box(L * Transform3D(Basis(), Vector3(0, 1.3, front + 0.04)), Vector3(size.x - 0.8, 2.6, 0.08), Color(0.32, 0.33, 0.35))
		b.add_box(L * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 2.95, front + 0.7)), Vector3(size.x, 0.08, 1.4), s.get("awning", Color.RED))
		var sign_y := 3.75
		b.add_box(L * Transform3D(Basis(), Vector3(0, sign_y, front + 0.1)), Vector3(size.x * 0.9, 0.95, 0.12), s.get("sign_color", Color.RED))
		var text: String = s.get("sign", "")
		if text != "":
			var sc: Color = s.get("sign_color", Color.RED)
			var txt_col := Color(0.1, 0.1, 0.1) if sc.get_luminance() > 0.6 else Color(1, 1, 0.92)
			var px := clampf((size.x * 0.85) / (text.length() * 0.6 * 56.0), 0.004, 0.011)
			MeshKit.label3d(root, text, L * Transform3D(Basis(), Vector3(0, sign_y, front + 0.17)), 56, txt_col, px, label_range)
	elif zone == "residential":
		b.add_box(L * Transform3D(Basis(), Vector3(size.x * 0.25, 1.05, front + 0.04)), Vector3(1.0, 2.1, 0.08), Color(0.4, 0.25, 0.15))
		var wall_len := size.x * 0.4
		for sx: float in [-1.0, 1.0]:
			var wxf := L * Transform3D(Basis(), Vector3(sx * (size.x * 0.5 - wall_len * 0.5), 0.6, front + 3.0))
			b.add_box(wxf, Vector3(wall_len, 1.2, 0.2), Color(0.85, 0.82, 0.75))
			MeshKit.col_box(body, wxf, Vector3(wall_len, 1.2, 0.2))
	if bool(s.get("tank", false)):
		var tp := L * Vector3(size.x * 0.28, size.y + 0.9, -size.z * 0.2)
		b.add_cylinder(Transform3D(Basis(), tp), 0.6, 0.6, 1.1, 8, Color(0.08, 0.08, 0.08))


func _emit_factory(s: Dictionary, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	var size: Vector3 = s["size"]
	var col: Color = s["color"]
	var L := Transform3D(Basis(Vector3.UP, float(s["yaw"])), s["pos"])
	var main_xf := L * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0))
	b.add_box(main_xf, size, col)
	MeshKit.col_box(body, main_xf, size)
	var teeth := maxi(1, int(size.z / 6.0))
	var tooth := size.z / teeth
	for i in range(teeth):
		var z := -size.z * 0.5 + tooth * (i + 0.5)
		b.add_wedge(L * Transform3D(Basis(), Vector3(0, size.y + 1.2, z)), Vector3(size.x, 2.4, tooth), Color(0.45, 0.5, 0.55))
	var front := size.z * 0.5
	for i in range(int(size.x / 8.0)):
		var x := -size.x * 0.5 + 4.0 + i * 8.0
		b.add_box(L * Transform3D(Basis(), Vector3(x, size.y * 0.55, front + 0.05)), Vector3(4.5, 1.6, 0.1), Color(0.2, 0.26, 0.3))
	b.add_box(L * Transform3D(Basis(), Vector3(-size.x * 0.25, 2.5, front + 0.05)), Vector3(5.0, 5.0, 0.1), Color(0.3, 0.35, 0.4))
	if bool(s.get("chimney", false)):
		var cp := L * Vector3(size.x * 0.4, 14.0, -size.z * 0.3)
		b.add_cylinder(Transform3D(Basis(), cp), 1.3, 0.9, 28.0, 10, Color(0.6, 0.3, 0.25))
		b.add_cylinder(Transform3D(Basis(), cp + Vector3(0, 12.5, 0)), 0.98, 0.95, 1.5, 10, Color(0.95, 0.95, 0.95), false)
		MeshKit.col_cylinder(body, cp, 1.3, 28.0)
	# compound wall with a gate opening
	var wall_z := front + 7.0
	var seg := (size.x - 14.0) * 0.5
	for sx: float in [-1.0, 1.0]:
		var wxf := L * Transform3D(Basis(), Vector3(sx * (7.0 + seg * 0.5), 1.1, wall_z))
		b.add_box(wxf, Vector3(seg, 2.2, 0.3), Color(0.82, 0.8, 0.72))
		MeshKit.col_box(body, wxf, Vector3(seg, 2.2, 0.3))
	var text: String = s.get("sign", "")
	if text != "":
		b.add_box(L * Transform3D(Basis(), Vector3(0, size.y - 1.4, front + 0.12)), Vector3(minf(size.x * 0.7, 30.0), 1.8, 0.15), Color(0.1, 0.25, 0.55))
		MeshKit.label3d(root, text, L * Transform3D(Basis(), Vector3(0, size.y - 1.4, front + 0.22)), 64, Color.WHITE, 0.016, label_range * 2.0)


func _emit_warehouse(s: Dictionary, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	var size: Vector3 = s["size"]
	var L := Transform3D(Basis(Vector3.UP, float(s["yaw"])), s["pos"])
	var main_xf := L * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0))
	b.add_box(main_xf, size, Color(0.6, 0.66, 0.72))
	MeshKit.col_box(body, main_xf, size)
	b.add_prism(L * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, size.y + 1.6, 0)), Vector3(size.z + 0.6, 3.2, size.x + 0.6), Color(0.4, 0.45, 0.5))
	var front := size.z * 0.5
	var doors := maxi(2, int(size.x / 12.0))
	for i in range(doors):
		var x := -size.x * 0.5 + size.x / doors * (i + 0.5)
		b.add_box(L * Transform3D(Basis(), Vector3(x, 2.4, front + 0.05)), Vector3(4.0, 4.8, 0.1), Color(0.25, 0.27, 0.3))
		b.add_box(L * Transform3D(Basis(), Vector3(x, 0.6, front + 1.0)), Vector3(4.8, 1.2, 2.0), CONCRETE)
	var text: String = s.get("sign", "")
	if text != "":
		MeshKit.label3d(root, text, L * Transform3D(Basis(), Vector3(0, size.y - 1.0, front + 0.1)), 56, Color(0.1, 0.15, 0.3), 0.014, label_range * 2.0)


func _emit_house(s: Dictionary, b: MeshBatcher, body: StaticBody3D) -> void:
	var size: Vector3 = s["size"]
	var col: Color = s["color"]
	var L := Transform3D(Basis(Vector3.UP, float(s["yaw"])), s["pos"])
	var main_xf := L * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0))
	b.add_box(main_xf, size, col)
	MeshKit.col_box(body, main_xf, size)
	b.add_prism(L * Transform3D(Basis(), Vector3(0, size.y + 0.8, 0)), Vector3(size.x + 0.8, 1.6, size.z + 0.8), Color(0.66, 0.3, 0.2))
	b.add_box(L * Transform3D(Basis(), Vector3(0, 1.0, size.z * 0.5 + 0.04)), Vector3(1.0, 2.0, 0.08), Color(0.35, 0.22, 0.12))
	b.add_box(L * Transform3D(Basis(), Vector3(0, 0.15, size.z * 0.5 + 1.2)), Vector3(size.x, 0.3, 2.2), Color(0.7, 0.66, 0.6))


func _emit_streetlight(s: Dictionary, b: MeshBatcher, lamps: MeshBatcher, body: StaticBody3D) -> void:
	var p: Vector3 = s["pos"]
	var n: Vector2 = s["n"]
	b.add_cylinder(Transform3D(Basis(), p + Vector3(0, 4.5, 0)), 0.13, 0.09, 9.0, 6, Color(0.55, 0.56, 0.58))
	MeshKit.col_cylinder(body, p + Vector3(0, 4.5, 0), 0.15, 9.0)
	for side in s["arms"]:
		var dir := Vector3(n.x, 0, n.y) * float(side)
		var yaw := atan2(dir.x, dir.z)
		var bas := Basis(Vector3.UP, yaw)
		b.add_box(Transform3D(bas, p + Vector3(0, 8.9, 0) + dir * 1.1), Vector3(0.08, 0.08, 2.2), Color(0.55, 0.56, 0.58))
		lamps.add_box(Transform3D(bas, p + Vector3(0, 8.8, 0) + dir * 2.2), Vector3(0.35, 0.14, 0.7), Color.WHITE)


func _tree_mesh(kind: String) -> ArrayMesh:
	if _tree_meshes.has(kind):
		return _tree_meshes[kind]
	var b := MeshBatcher.new()
	if kind == "palm":
		b.add_cylinder(Transform3D(Basis(), Vector3(0, 4.5, 0)), 0.22, 0.16, 9.0, 6, Color(0.45, 0.38, 0.3))
		for i in range(9):
			var a := TAU * float(i) / 9.0
			var bas := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5)
			b.add_box(Transform3D(bas, Vector3(0, 9.0, 0) + bas * Vector3(0, 0, 1.6)), Vector3(0.55, 0.05, 3.3), Color(0.2, 0.45, 0.15))
		for i in range(4):
			var a2 := TAU * float(i) / 4.0
			b.add_ellipsoid(Transform3D(Basis(), Vector3(cos(a2) * 0.25, 8.7, sin(a2) * 0.25)), Vector3(0.16, 0.18, 0.16), Color(0.35, 0.4, 0.15), 3, 5)
	else:
		b.add_cylinder(Transform3D(Basis(), Vector3(0, 1.6, 0)), 0.28, 0.2, 3.2, 6, Color(0.35, 0.25, 0.18))
		b.add_ellipsoid(Transform3D(Basis(), Vector3(0, 4.3, 0)), Vector3(2.6, 1.7, 2.6), Color(0.2, 0.37, 0.15), 4, 8)
		b.add_ellipsoid(Transform3D(Basis(), Vector3(0.7, 5.3, 0.4)), Vector3(1.8, 1.3, 1.8), Color(0.25, 0.44, 0.18), 4, 7)
	var mesh := b.commit()
	_tree_meshes[kind] = mesh
	return mesh
