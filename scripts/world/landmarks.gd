class_name Landmarks
extends RefCounted
## Builders for named places in the Coimbatore region. All names of businesses are
## fictional. Each landmark is built in its own local frame (front faces local +Z).

const CREAM := Color(0.95, 0.9, 0.78)
const WHITE := Color(0.95, 0.95, 0.93)
const CONCRETE := Color(0.66, 0.65, 0.62)
const GOLD := Color(0.95, 0.72, 0.2)
const TERRACOTTA := Color(0.86, 0.55, 0.38)
const GRANITE := Color(0.58, 0.55, 0.5)
const RED := Color(0.78, 0.12, 0.1)
const GREEN := Color(0.08, 0.45, 0.22)
const DARK := Color(0.12, 0.12, 0.13)
const TAMIL_RED := Color(0.75, 0.1, 0.08)


static func build(s: Dictionary, b: MeshBatcher, lamps: MeshBatcher, body: StaticBody3D, root: Node3D, world: CoimbatoreWorld) -> void:
	var L := Transform3D(Basis(Vector3.UP, float(s["yaw"])), s["pos"])
	match String(s["kind"]):
		"yard":
			_yard(L, b, body, root)
		"petrol":
			_petrol(L, b, lamps, body, root)
		"bus_stand":
			_bus_stand(L, b, body, root)
		"temple":
			_temple(L, b, lamps, body, root)
		"mill":
			_mill(L, b, body, root)
		"logistics":
			_logistics(L, b, body, root)
		"railway":
			_railway(L, b, body, root)
		"arch":
			_arch(L, b, body, root)
		"tea_stall":
			_tea_stall(L, b, lamps, body, root)
		"board":
			_board(L, b, body, root, s.get("text", ""), float(s.get("w", 6.0)))
		"milestone":
			_milestone(L, b, root, s.get("text", ""))


# ---------------------------------------------------------------- helpers

static func _bx(b: MeshBatcher, body: StaticBody3D, L: Transform3D, center: Vector3, size: Vector3, c: Color, collide := true, rot := Vector3.ZERO) -> void:
	var xf := L * Transform3D(Basis.from_euler(rot), center)
	b.add_box(xf, size, c)
	if collide and body != null:
		MeshKit.col_box(body, xf, size)


static func _cyl(b: MeshBatcher, body: StaticBody3D, L: Transform3D, center: Vector3, r_bottom: float, r_top: float, h: float, c: Color, collide := true, sides := 8) -> void:
	var xf := L * Transform3D(Basis(), center)
	b.add_cylinder(xf, r_bottom, r_top, h, sides, c)
	if collide and body != null:
		MeshKit.col_cylinder(body, xf.origin, maxf(r_bottom, r_top), h)


static func _flat(b: MeshBatcher, L: Transform3D, center: Vector3, sx: float, sz: float, c: Color) -> void:
	var p := L * center
	var yaw := atan2(L.basis.x.z, L.basis.x.x) * -1.0
	b.add_flat(p, sx, sz, c, yaw)


static func _label(root: Node3D, L: Transform3D, text: String, center: Vector3, font_size: int, color: Color, pixel: float, back := false, vis := 160.0) -> void:
	var bas := Basis(Vector3.UP, PI) if back else Basis()
	MeshKit.label3d(root, text, L * Transform3D(bas, center), font_size, color, pixel, vis)


static func _vel(b: MeshBatcher, L: Transform3D, base: Vector3, scale: float) -> void:
	b.add_cylinder(L * Transform3D(Basis(), base + Vector3(0, 0.5 * scale, 0)), 0.03 * scale, 0.03 * scale, 1.0 * scale, 6, GOLD)
	b.add_ellipsoid(L * Transform3D(Basis(Vector3.RIGHT, PI / 2), base + Vector3(0, 1.25 * scale, 0)), Vector3(0.14, 0.03, 0.3) * scale, GOLD, 3, 8)
	b.add_cylinder(L * Transform3D(Basis(), base + Vector3(0, 0.98 * scale, 0)), 0.1 * scale, 0.0, 0.08 * scale, 6, GOLD)


static func prop_truck(b: MeshBatcher, body: StaticBody3D, L: Transform3D, pos: Vector3, yaw: float, cab: Color, cargo: Color) -> void:
	var T := L * Transform3D(Basis(Vector3.UP, yaw), pos)
	b.add_box(T * Transform3D(Basis(), Vector3(0, 1.65, 3.7)), Vector3(2.4, 2.3, 2.2), cab)
	b.add_box(T * Transform3D(Basis(), Vector3(0, 2.1, 4.81)), Vector3(2.2, 0.9, 0.05), Color(0.2, 0.3, 0.38))
	b.add_box(T * Transform3D(Basis(), Vector3(0, 1.5, -1.2)), Vector3(2.5, 1.9, 6.8), cargo)
	b.add_box(T * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(1.2, 0.3, 9.6), DARK)
	for z: float in [3.4, -1.8, -3.1]:
		for sx: float in [-1.0, 1.0]:
			b.add_cylinder(T * Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3(1.0 * sx, 0.52, z)), 0.52, 0.52, 0.35, 10, DARK)
	MeshKit.col_box(body, T * Transform3D(Basis(), Vector3(0, 1.5, 0)), Vector3(2.5, 3.0, 10.0))


static func prop_bus(b: MeshBatcher, body: StaticBody3D, L: Transform3D, pos: Vector3, yaw: float, c: Color) -> void:
	var T := L * Transform3D(Basis(Vector3.UP, yaw), pos)
	b.add_box(T * Transform3D(Basis(), Vector3(0, 1.85, 0)), Vector3(2.5, 2.9, 11.5), c)
	b.add_box(T * Transform3D(Basis(), Vector3(0, 2.45, 0)), Vector3(2.54, 0.95, 10.6), Color(0.15, 0.2, 0.25))
	b.add_box(T * Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(2.54, 0.25, 11.5), WHITE)
	for z: float in [3.8, -3.6]:
		for sx: float in [-1.0, 1.0]:
			b.add_cylinder(T * Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3(1.05 * sx, 0.5, z)), 0.5, 0.5, 0.3, 10, DARK)
	MeshKit.col_box(body, T * Transform3D(Basis(), Vector3(0, 1.75, 0)), Vector3(2.5, 3.3, 11.5))


# ---------------------------------------------------------------- landmarks

static func _yard(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.025, 0), 90, 60, Color(0.56, 0.5, 0.42))
	var wall := Color(0.82, 0.8, 0.72)
	_bx(b, body, L, Vector3(0, 1.1, -30), Vector3(90, 2.2, 0.3), wall)
	_bx(b, body, L, Vector3(-45, 1.1, 0), Vector3(0.3, 2.2, 60), wall)
	_bx(b, body, L, Vector3(45, 1.1, 0), Vector3(0.3, 2.2, 60), wall)
	_bx(b, body, L, Vector3(-28.5, 1.1, 30), Vector3(33, 2.2, 0.3), wall)
	_bx(b, body, L, Vector3(28.5, 1.1, 30), Vector3(33, 2.2, 0.3), wall)
	for sx: float in [-1.0, 1.0]:
		_bx(b, body, L, Vector3(12.5 * sx, 3.6, 30), Vector3(0.8, 7.2, 0.8), CREAM)
	_bx(b, body, L, Vector3(0, 6.6, 30), Vector3(26, 1.8, 0.35), Color(0.1, 0.25, 0.55))
	_label(root, L, "ஸ்ரீ முருகன் டிரான்ஸ்போர்ட்", Vector3(0, 6.95, 30.2), 64, Color(1, 0.9, 0.3), 0.011)
	_label(root, L, "SRI MURUGAN TRANSPORT", Vector3(0, 6.2, 30.2), 64, Color.WHITE, 0.011)
	_label(root, L, "ஸ்ரீ முருகன் டிரான்ஸ்போர்ட்", Vector3(0, 6.95, 29.8), 64, Color(1, 0.9, 0.3), 0.011, true)
	_label(root, L, "SRI MURUGAN TRANSPORT  -  COIMBATORE", Vector3(0, 6.2, 29.8), 64, Color.WHITE, 0.009, true)
	# office
	_bx(b, body, L, Vector3(-30, 2.0, -24), Vector3(14, 4.0, 8), WHITE)
	_bx(b, null, L, Vector3(-30, 3.4, -19.95), Vector3(14, 0.5, 0.1), Color(0.15, 0.35, 0.7), false)
	_bx(b, null, L, Vector3(-27, 1.05, -19.95), Vector3(1.2, 2.1, 0.1), Color(0.4, 0.25, 0.15), false)
	_bx(b, null, L, Vector3(-33, 1.8, -19.95), Vector3(3.0, 1.2, 0.1), Color(0.2, 0.26, 0.32), false)
	_label(root, L, "OFFICE", Vector3(-30, 3.4, -19.88), 48, Color.WHITE, 0.01)
	# small Murugan shrine with a Vel near the office
	_bx(b, body, L, Vector3(-17, 0.6, -27), Vector3(2.0, 1.2, 1.6), CREAM)
	_bx(b, null, L, Vector3(-17, 1.3, -27), Vector3(2.2, 0.2, 1.8), TAMIL_RED, false)
	_vel(b, L, Vector3(-17, 1.4, -27), 1.0)
	# parked trucks, spare tyres and diesel drums
	for p in [[Vector3(24, 0, -12), Color(0.15, 0.35, 0.75), Color(0.85, 0.75, 0.2)], [Vector3(36, 0, -12), Color(0.1, 0.5, 0.3), Color(0.9, 0.5, 0.15)]]:
		if TruckVisual.add_prop(root, L * Transform3D(Basis(), p[0]), p[1]):
			MeshKit.col_box(body, L * Transform3D(Basis(), p[0] + Vector3(0, 1.5, 0)), Vector3(2.5, 3.0, 10.0))
		else:
			prop_truck(b, body, L, p[0], 0.0, p[1], p[2])
	for i in range(4):
		b.add_cylinder(L * Transform3D(Basis(), Vector3(-40, 0.15 + i * 0.3, 10)), 0.52, 0.52, 0.28, 10, DARK)
	for i in range(3):
		_cyl(b, body, L, Vector3(-40 + i * 0.8, 0.45, 18), 0.3, 0.3, 0.9, Color(0.15, 0.3, 0.6))


static func _petrol(L: Transform3D, b: MeshBatcher, lamps: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.035, -1), 60, 36, Color(0.7, 0.7, 0.68))
	_bx(b, null, L, Vector3(0, 6.4, 0), Vector3(30, 0.8, 14), WHITE, false)
	_bx(b, null, L, Vector3(0, 6.0, 0), Vector3(30.2, 0.4, 14.2), GREEN, false)
	lamps.add_box(L * Transform3D(Basis(), Vector3(0, 5.95, 0)), Vector3(26, 0.05, 10), Color.WHITE)
	for x: float in [-10.0, 10.0]:
		for z: float in [-4.0, 4.0]:
			_bx(b, body, L, Vector3(x, 3.0, z), Vector3(0.6, 6.0, 0.6), WHITE)
	for x: float in [-8.0, 0.0, 8.0]:
		_bx(b, null, L, Vector3(x, 0.1, 0), Vector3(1.4, 0.2, 5.0), Color(0.9, 0.8, 0.2), false)
		_bx(b, body, L, Vector3(x, 1.15, 0), Vector3(0.9, 1.9, 0.6), WHITE)
		_bx(b, null, L, Vector3(x, 2.2, 0), Vector3(0.95, 0.25, 0.65), GREEN, false)
		_bx(b, null, L, Vector3(x, 1.4, 0.31), Vector3(0.5, 0.4, 0.02), Color(0.1, 0.12, 0.15), false)
	_bx(b, body, L, Vector3(0, 2.0, -13.5), Vector3(12, 4.0, 7), CREAM)
	_bx(b, null, L, Vector3(0, 1.6, -9.95), Vector3(8, 2.2, 0.1), Color(0.2, 0.28, 0.35), false)
	_label(root, L, "KOVAI FUELS", Vector3(0, 6.1, 7.15), 64, Color.WHITE, 0.012)
	_bx(b, body, L, Vector3(-26, 4.5, 12), Vector3(0.5, 9.0, 0.5), Color(0.5, 0.5, 0.5))
	_bx(b, null, L, Vector3(-26, 8.3, 12), Vector3(5.0, 3.0, 0.4), GREEN, false)
	_label(root, L, "KOVAI FUELS", Vector3(-26, 9.1, 12.22), 56, Color(1, 0.9, 0.2), 0.012)
	_label(root, L, "DIESEL  |  PETROL\n24 HOURS", Vector3(-26, 7.9, 12.22), 40, Color.WHITE, 0.01)


static func _bus_stand(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.035, 0), 76, 60, Color(0.55, 0.53, 0.49))
	_bx(b, null, L, Vector3(0, 6.3, -2), Vector3(60, 0.6, 22), Color(0.72, 0.72, 0.7), false)
	for i in range(7):
		var x := -27.0 + i * 9.0
		for z: float in [-12.0, 8.0]:
			_bx(b, body, L, Vector3(x, 3.0, z), Vector3(0.7, 6.0, 0.7), Color(0.8, 0.78, 0.7))
	var cols := [Color(0.15, 0.35, 0.7), Color(0.75, 0.15, 0.12), Color(0.15, 0.55, 0.35), Color(0.85, 0.6, 0.1)]
	var bi := 0
	for x: float in [-21.0, -7.0, 7.0, 21.0]:
		prop_bus(b, body, L, Vector3(x, 0, -2), 0.0, cols[bi])
		bi += 1
	var shops := ["TEA", "FRUITS", "BOOKS", "HOTEL", "MOBILE", "BAKERY"]
	for i in range(6):
		var x2 := -30.0 + i * 12.0
		_bx(b, body, L, Vector3(x2, 2.0, -26), Vector3(10, 4.0, 6), [CREAM, Color(0.8, 0.9, 0.95), Color(0.95, 0.85, 0.7)][i % 3])
		_bx(b, null, L, Vector3(x2, 3.4, -22.9), Vector3(8, 0.8, 0.1), TAMIL_RED, false)
		_label(root, L, shops[i], Vector3(x2, 3.4, -22.83), 48, Color.WHITE, 0.012, false, 90.0)
	_bx(b, null, L, Vector3(0, 7.5, 9.05), Vector3(34, 1.8, 0.3), Color(0.1, 0.25, 0.55), false)
	_label(root, L, "காந்திபுரம் பேருந்து நிலையம்", Vector3(0, 7.85, 9.25), 64, Color(1, 0.9, 0.3), 0.014)
	_label(root, L, "GANDHIPURAM BUS STAND", Vector3(0, 7.1, 9.25), 64, Color.WHITE, 0.013)


static func _temple(L: Transform3D, b: MeshBatcher, lamps: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.03, 0), 90, 80, Color(0.82, 0.75, 0.6))
	var wall := Color(0.9, 0.86, 0.76)
	_bx(b, body, L, Vector3(0, 1.5, -40), Vector3(90, 3.0, 0.6), wall)
	_bx(b, body, L, Vector3(-45, 1.5, 0), Vector3(0.6, 3.0, 80), wall)
	_bx(b, body, L, Vector3(45, 1.5, 0), Vector3(0.6, 3.0, 80), wall)
	for sx: float in [-1.0, 1.0]:
		_bx(b, body, L, Vector3(27 * sx, 1.5, 40), Vector3(36, 3.0, 0.6), wall)
		# red and white temple wall stripes on the outer face
		for i in range(15):
			var x := sx * (9.6 + i * 2.4)
			_bx(b, null, L, Vector3(x, 1.5, 40.32), Vector3(1.2, 2.6, 0.05), TAMIL_RED, false)
	# gopuram over the entrance
	for sx: float in [-1.0, 1.0]:
		_bx(b, body, L, Vector3(5.25 * sx, 4.0, 40), Vector3(5.5, 8.0, 9.0), GRANITE)
	_bx(b, null, L, Vector3(0, 7.0, 40), Vector3(5.0, 2.0, 9.0), GRANITE, false)
	var figure_cols := [Color(0.2, 0.4, 0.85), Color(0.15, 0.6, 0.3), Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.9, 0.5, 0.7)]
	for i in range(6):
		var w := 16.0 - i * 2.0
		var d := 9.0 - i * 1.0
		var y := 8.0 + i * 3.0 + 1.5
		_bx(b, null, L, Vector3(0, y, 40), Vector3(w, 3.0, d), TERRACOTTA if i % 2 == 0 else CREAM, false)
		var n := int(w / 1.3)
		for k in range(n):
			var fx := -w * 0.5 + 0.65 + k * 1.3
			var fc: Color = figure_cols[(k + i) % figure_cols.size()]
			_bx(b, null, L, Vector3(fx, y, 40 + d * 0.5 + 0.12), Vector3(0.5, 1.4, 0.25), fc, false)
			_bx(b, null, L, Vector3(fx, y, 40 - d * 0.5 - 0.12), Vector3(0.5, 1.4, 0.25), fc, false)
	b.add_cylinder(L * Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3(0, 27.2, 40)), 1.6, 1.6, 6.0, 10, TERRACOTTA)
	for k in range(5):
		b.add_cylinder(L * Transform3D(Basis(), Vector3(-2.0 + k, 29.3, 40)), 0.25, 0.0, 1.2, 6, GOLD)
	_bx(b, null, L, Vector3(0, 6.9, 44.55), Vector3(5.2, 1.2, 0.1), TAMIL_RED, false)
	_label(root, L, "அருள்மிகு முருகன் திருக்கோயில்", Vector3(0, 7.15, 44.62), 48, Color(1, 0.9, 0.3), 0.0075)
	_label(root, L, "ARULMIGU MURUGAN TEMPLE", Vector3(0, 6.6, 44.62), 40, Color.WHITE, 0.0072)
	# sanctum with vimana
	_bx(b, body, L, Vector3(0, 3.0, -24), Vector3(12, 6.0, 12), CREAM)
	for i in range(3):
		var vs := 10.0 - i * 3.0
		_bx(b, null, L, Vector3(0, 7.25 + i * 2.5, -24), Vector3(vs, 2.5, vs), TERRACOTTA if i % 2 == 0 else CREAM, false)
	b.add_ellipsoid(L * Transform3D(Basis(), Vector3(0, 14.8, -24)), Vector3(1.8, 1.4, 1.8), GOLD, 4, 8)
	b.add_cylinder(L * Transform3D(Basis(), Vector3(0, 16.6, -24)), 0.3, 0.0, 1.4, 6, GOLD)
	# pillared mandapam
	_bx(b, null, L, Vector3(0, 5.3, -8), Vector3(16, 0.6, 16), GRANITE, false)
	for x: float in [-6.0, -2.0, 2.0, 6.0]:
		for z: float in [-14.0, -8.0, -2.0]:
			_cyl(b, body, L, Vector3(x, 2.5, z), 0.4, 0.4, 5.0, GRANITE)
	# flag mast (kodimaram) and stone lamp pillar
	_cyl(b, body, L, Vector3(0, 7.0, 14), 0.35, 0.2, 14.0, GOLD)
	_bx(b, body, L, Vector3(0, 0.6, 14), Vector3(2.0, 1.2, 2.0), GRANITE)
	_cyl(b, body, L, Vector3(0, 3.0, 22), 0.4, 0.3, 6.0, GRANITE)
	lamps.add_box(L * Transform3D(Basis(), Vector3(0, 6.2, 22)), Vector3(0.6, 0.3, 0.6), Color.WHITE)
	# flower stalls outside the gate
	for sx: float in [-1.0, 1.0]:
		var sp := Vector3(16 * sx, 0, 47)
		_bx(b, body, L, sp + Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 2.2), Color(0.9, 0.82, 0.6))
		_bx(b, null, L, sp + Vector3(0, 2.6, 1.3), Vector3(3.6, 0.1, 1.6), TAMIL_RED, false, Vector3(0.2, 0, 0))
		for k in range(8):
			var fc2: Color = [Color(1.0, 0.55, 0.0), Color(1.0, 0.85, 0.1), Color(0.95, 0.95, 0.95), Color(0.9, 0.2, 0.4)][k % 4]
			b.add_ellipsoid(L * Transform3D(Basis(), sp + Vector3(-1.3 + k * 0.37, 1.0, 1.25)), Vector3(0.16, 0.12, 0.16), fc2, 3, 5)
		_label(root, L, "பூக்கடை  FLOWERS", sp + Vector3(0, 2.1, 1.12), 40, Color(0.5, 0.05, 0.05), 0.007, false, 60.0)


static func _mill(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.03, 0), 110, 90, Color(0.6, 0.58, 0.54))
	_bx(b, body, L, Vector3(0, 5.0, -10), Vector3(90, 10.0, 50), Color(0.85, 0.82, 0.74))
	for i in range(8):
		b.add_wedge(L * Transform3D(Basis(), Vector3(0, 11.2, -35 + 3.125 + i * 6.25)), Vector3(90, 2.4, 6.25), Color(0.45, 0.5, 0.55))
	_cyl(b, body, L, Vector3(38, 15, -30), 1.6, 1.0, 30.0, Color(0.62, 0.3, 0.24), true, 10)
	for i in range(10):
		_bx(b, null, L, Vector3(-40 + i * 9, 6.0, 15.05), Vector3(5.0, 1.8, 0.1), Color(0.2, 0.26, 0.3), false)
	_bx(b, null, L, Vector3(0, 8.5, 15.12), Vector3(36, 2.2, 0.15), Color(0.1, 0.25, 0.55), false)
	_label(root, L, "KOVAI SPINNING MILLS", Vector3(0, 8.5, 15.22), 64, Color.WHITE, 0.02, false, 300.0)
	for sx: float in [-1.0, 1.0]:
		_bx(b, body, L, Vector3(31 * sx, 1.1, 40), Vector3(48, 2.2, 0.3), Color(0.82, 0.8, 0.72))


static func _logistics(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.03, 0), 120, 90, Color(0.55, 0.55, 0.53))
	for x: float in [-30.0, 30.0]:
		_bx(b, body, L, Vector3(x, 5.0, -20), Vector3(50, 10.0, 34), Color(0.6, 0.66, 0.72))
		b.add_prism(L * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(x, 11.6, -20)), Vector3(34.6, 3.2, 50.6), Color(0.4, 0.45, 0.5))
		for i in range(4):
			_bx(b, null, L, Vector3(x - 18 + i * 12, 2.5, -2.95), Vector3(4.5, 5.0, 0.1), Color(0.25, 0.27, 0.3), false)
	var cc := [Color(0.75, 0.2, 0.15), Color(0.15, 0.35, 0.65), Color(0.85, 0.6, 0.15), Color(0.2, 0.55, 0.35)]
	for i in range(6):
		for lvl in range(2 if i % 2 == 0 else 1):
			_bx(b, body, L, Vector3(-40 + i * 13, 1.3 + lvl * 2.6, 22), Vector3(12.2, 2.6, 2.45), cc[(i + lvl) % 4])
	_bx(b, null, L, Vector3(0, 9.0, -2.9), Vector3(30, 2.0, 0.15), Color(0.85, 0.5, 0.1), false)
	_label(root, L, "KOVAI LOGISTICS PARK", Vector3(0, 9.0, -2.8), 64, Color.WHITE, 0.018, false, 300.0)


static func _railway(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(0, 0.02, 0), 600, 4.2, Color(0.45, 0.42, 0.38))
	var x := -299.0
	while x < 299.0:
		if absf(x) > 7.0:
			b.add_box(L * Transform3D(Basis(), Vector3(x, 0.06, 0)), Vector3(0.25, 0.08, 2.7), Color(0.6, 0.6, 0.58))
		x += 0.65
	for z: float in [-0.84, 0.84]:
		b.add_box(L * Transform3D(Basis(), Vector3(0, 0.12, z)), Vector3(600, 0.12, 0.08), Color(0.35, 0.33, 0.32))
	# raised boom barriers
	for side: float in [-1.0, 1.0]:
		var pp := Vector3(7.5 * side, 0, 4.5 * side)
		_bx(b, body, L, pp + Vector3(0, 0.6, 0), Vector3(0.35, 1.2, 0.35), Color(0.3, 0.3, 0.3))
		for k in range(8):
			_bx(b, null, L, pp + Vector3(0, 1.6 + k * 0.75, 0), Vector3(0.14, 0.75, 0.14), RED if k % 2 == 0 else WHITE, false)
		var cb := pp + Vector3(1.2 * side, 0, 0)
		_bx(b, body, L, cb + Vector3(0, 1.4, 0), Vector3(0.12, 2.8, 0.12), Color(0.4, 0.4, 0.4))
		_bx(b, null, L, cb + Vector3(0, 2.7, 0), Vector3(0.05, 0.25, 1.6), WHITE, false, Vector3(0.7, 0, 0))
		_bx(b, null, L, cb + Vector3(0, 2.7, 0), Vector3(0.05, 0.25, 1.6), WHITE, false, Vector3(-0.7, 0, 0))
	_bx(b, body, L, Vector3(13, 1.4, 8), Vector3(3.0, 2.8, 3.0), CREAM)
	_bx(b, null, L, Vector3(13, 2.95, 8), Vector3(3.4, 0.3, 3.4), TAMIL_RED, false)
	_bx(b, body, L, Vector3(9, 2.0, -10), Vector3(0.15, 4.0, 0.15), Color(0.4, 0.4, 0.4))
	_bx(b, null, L, Vector3(9, 3.6, -10), Vector3(3.6, 1.4, 0.1), Color(0.98, 0.85, 0.1), false)
	_label(root, L, "ரயில்வே கேட்\nRAILWAY LEVEL CROSSING", Vector3(9, 3.6, -9.93), 32, Color.BLACK, 0.008, false, 90.0)
	_label(root, L, "LC GATE 42", Vector3(13, 2.0, 9.52), 32, Color(0.2, 0.2, 0.2), 0.008, false, 60.0)


static func _arch(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	for sx: float in [-1.0, 1.0]:
		_bx(b, body, L, Vector3(11.5 * sx, 4.5, 0), Vector3(1.8, 9.0, 1.8), CREAM)
		_bx(b, null, L, Vector3(11.5 * sx, 2.0, 0), Vector3(1.9, 0.4, 1.9), TAMIL_RED, false)
		b.add_ellipsoid(L * Transform3D(Basis(), Vector3(11.5 * sx, 10.6, 0)), Vector3(1.0, 1.0, 1.0), GOLD, 4, 8)
	_bx(b, null, L, Vector3(0, 8.6, 0), Vector3(25, 2.4, 1.2), CREAM, false)
	_bx(b, null, L, Vector3(0, 7.45, 0), Vector3(25.1, 0.2, 1.25), TAMIL_RED, false)
	_bx(b, null, L, Vector3(0, 9.85, 0), Vector3(25.1, 0.2, 1.25), TAMIL_RED, false)
	b.add_ellipsoid(L * Transform3D(Basis(), Vector3(0, 10.6, 0)), Vector3(1.4, 1.2, 1.0), GOLD, 4, 8)
	_label(root, L, "கோயம்புத்தூர் உங்களை வரவேற்கிறது", Vector3(0, 9.05, 0.62), 64, TAMIL_RED, 0.012, false, 260.0)
	_label(root, L, "WELCOME TO COIMBATORE", Vector3(0, 8.1, 0.62), 64, Color(0.1, 0.25, 0.55), 0.012, false, 260.0)
	_label(root, L, "நன்றி  மீண்டும் வருக", Vector3(0, 9.05, -0.62), 64, TAMIL_RED, 0.012, true, 260.0)
	_label(root, L, "THANK YOU  -  VISIT AGAIN", Vector3(0, 8.1, -0.62), 64, Color(0.1, 0.25, 0.55), 0.012, true, 260.0)


static func _tea_stall(L: Transform3D, b: MeshBatcher, lamps: MeshBatcher, body: StaticBody3D, root: Node3D) -> void:
	_flat(b, L, Vector3(6, 0.025, 8), 34, 12, Color(0.55, 0.45, 0.35))
	var wood := Color(0.5, 0.33, 0.18)
	_bx(b, null, L, Vector3(0, 1.4, -1.5), Vector3(5.0, 2.8, 0.15), Color(0.3, 0.5, 0.6), false)
	for sx: float in [-1.0, 1.0]:
		_bx(b, null, L, Vector3(2.5 * sx, 1.4, 0), Vector3(0.15, 2.8, 3.0), Color(0.3, 0.5, 0.6), false)
	MeshKit.col_box(body, L * Transform3D(Basis(), Vector3(0, 1.4, 0)), Vector3(5.2, 2.8, 3.2))
	b.add_wedge(L * Transform3D(Basis(), Vector3(0, 3.05, 0.3)), Vector3(5.8, 0.5, 4.0), Color(0.55, 0.6, 0.65))
	_bx(b, null, L, Vector3(0, 0.5, 1.2), Vector3(4.2, 1.0, 0.6), wood, false)
	b.add_cylinder(L * Transform3D(Basis(), Vector3(-1.2, 1.3, 1.2)), 0.22, 0.16, 0.55, 8, GOLD)
	b.add_cylinder(L * Transform3D(Basis(), Vector3(-0.6, 1.2, 1.2)), 0.18, 0.18, 0.35, 8, Color(0.6, 0.6, 0.62))
	for k in range(5):
		b.add_cylinder(L * Transform3D(Basis(), Vector3(0.2 + k * 0.18, 1.06, 1.25)), 0.035, 0.03, 0.12, 6, Color(0.9, 0.85, 0.75))
	for k in range(7):
		b.add_ellipsoid(L * Transform3D(Basis(), Vector3(1.6, 2.25 - k * 0.09, 1.3 + (k % 2) * 0.06)), Vector3(0.1, 0.05, 0.05), Color(0.95, 0.85, 0.15), 3, 5)
	for x: float in [-2.0, 2.0]:
		_bx(b, null, L, Vector3(x, 0.45, 3.8), Vector3(2.4, 0.08, 0.5), wood, false)
		for lx: float in [-1.0, 1.0]:
			_bx(b, null, L, Vector3(x + lx, 0.22, 3.8), Vector3(0.08, 0.44, 0.4), wood, false)
	lamps.add_box(L * Transform3D(Basis(), Vector3(0, 2.75, 1.0)), Vector3(0.6, 0.06, 0.1), Color.WHITE)
	_bx(b, null, L, Vector3(0, 3.55, 2.2), Vector3(4.6, 0.9, 0.1), Color(0.95, 0.8, 0.15), false)
	_label(root, L, "குமார் டீ கடை", Vector3(0, 3.75, 2.27), 48, TAMIL_RED, 0.009, false, 90.0)
	_label(root, L, "KUMAR TEA STALL", Vector3(0, 3.33, 2.27), 40, Color(0.1, 0.1, 0.1), 0.008, false, 90.0)


static func _board(L: Transform3D, b: MeshBatcher, body: StaticBody3D, root: Node3D, text: String, w: float) -> void:
	for sx: float in [-1.0, 1.0]:
		_bx(b, body, L, Vector3((w * 0.5 - 0.4) * sx, 2.6, 0), Vector3(0.15, 5.2, 0.15), Color(0.5, 0.5, 0.5))
	_bx(b, null, L, Vector3(0, 4.6, 0), Vector3(w, 2.2, 0.12), Color(0.05, 0.42, 0.22), false)
	_bx(b, null, L, Vector3(0, 4.6, -0.01), Vector3(w + 0.15, 2.35, 0.1), WHITE, false)
	_label(root, L, text, Vector3(0, 4.6, 0.075), 40, Color.WHITE, 0.0105, false, 140.0)


static func _milestone(L: Transform3D, b: MeshBatcher, root: Node3D, text: String) -> void:
	b.add_box(L * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.55, 0.9, 0.22), WHITE)
	b.add_cylinder(L * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.9, 0)), 0.275, 0.275, 0.22, 10, Color(0.98, 0.8, 0.1), true, true)
	_label(root, L, text, Vector3(0, 0.55, 0.115), 32, Color.BLACK, 0.0048, false, 50.0)
