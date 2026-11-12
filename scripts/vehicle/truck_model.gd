class_name TruckModel
extends RefCounted
## Simple fallback truck model built from primitives, used only if the detailed
## model (TruckVisual, assets/trucks/indian_lorry.gltf) cannot be loaded. It is an
## original design (no real manufacturer's model or branding). The truck faces +Z;
## it is right-hand drive, so the driver sits on the -X side.

const CAB := Color(0.86, 0.33, 0.08)
const CAB_STRIPE := Color(0.98, 0.8, 0.12)
const GREEN := Color(0.08, 0.5, 0.22)
const BODY := Color(0.94, 0.66, 0.12)
const BAND := Color(0.72, 0.08, 0.08)
const CHASSIS := Color(0.1, 0.1, 0.1)
const INTERIOR := Color(0.3, 0.27, 0.24)
const DASH := Color(0.13, 0.13, 0.14)
const SEAT := Color(0.42, 0.1, 0.08)
const CHROME := Color(0.78, 0.78, 0.8)
const TYRE := Color(0.07, 0.07, 0.07)
const RIM := Color(0.75, 0.12, 0.1)
const GOLD := Color(0.95, 0.72, 0.2)
const PLATE := Color(0.98, 0.85, 0.1)

static var _wheel_meshes := {}


static func _box(b: MeshBatcher, center: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> void:
	b.add_box(Transform3D(Basis.from_euler(rot), center), size, c)


static func build(truck: Node3D) -> Dictionary:
	var b := MeshBatcher.new()
	# --- chassis
	_box(b, Vector3(0.45, -0.05, -0.3), Vector3(0.2, 0.3, 9.6), CHASSIS)
	_box(b, Vector3(-0.45, -0.05, -0.3), Vector3(0.2, 0.3, 9.6), CHASSIS)
	for z: float in [3.4, 1.0, -1.8, -3.1, -4.4]:
		_box(b, Vector3(0, -0.05, z), Vector3(1.0, 0.18, 0.15), CHASSIS)
	# --- cab shell (hollow so the cockpit camera sees an interior)
	_box(b, Vector3(0, 0.5, 3.72), Vector3(2.4, 0.1, 2.15), INTERIOR)
	_box(b, Vector3(0, 2.7, 3.72), Vector3(2.46, 0.1, 2.25), CAB)
	_box(b, Vector3(0, 1.6, 2.64), Vector3(2.46, 2.2, 0.08), CAB)
	_box(b, Vector3(0, 1.0, 4.79), Vector3(2.46, 1.0, 0.08), CAB)
	_box(b, Vector3(0, 2.55, 4.79), Vector3(2.46, 0.2, 0.08), CAB)
	for sx: float in [-1.0, 1.0]:
		_box(b, Vector3(1.18 * sx, 1.975, 4.79), Vector3(0.1, 0.95, 0.1), CAB)
		_box(b, Vector3(1.2 * sx, 1.0, 3.72), Vector3(0.08, 1.0, 2.15), CAB)
		_box(b, Vector3(1.2 * sx, 2.075, 3.07), Vector3(0.08, 1.15, 0.85), CAB)
		_box(b, Vector3(1.2 * sx, 2.6, 3.72), Vector3(0.08, 0.1, 2.15), CAB)
		_box(b, Vector3(1.2 * sx, 2.05, 4.74), Vector3(0.08, 1.1, 0.1), CAB)
		# yellow and green side stripes
		_box(b, Vector3(1.245 * sx, 1.35, 3.72), Vector3(0.02, 0.12, 2.15), CAB_STRIPE)
		_box(b, Vector3(1.245 * sx, 1.18, 3.72), Vector3(0.02, 0.08, 2.15), GREEN)
		# door step, mirror arm, mirror
		_box(b, Vector3(1.15 * sx, 0.15, 3.6), Vector3(0.3, 0.06, 0.6), CHASSIS)
		_box(b, Vector3(1.38 * sx, 2.3, 4.6), Vector3(0.4, 0.04, 0.04), CHASSIS)
		_box(b, Vector3(1.58 * sx, 2.1, 4.6), Vector3(0.06, 0.48, 0.26), CHASSIS)
		# rear mudguards
		_box(b, Vector3(1.0 * sx, 0.38, -2.45), Vector3(0.6, 0.05, 2.3), CHASSIS)
	# front face
	_box(b, Vector3(0, 2.86, 4.78), Vector3(2.5, 0.36, 0.38), CAB_STRIPE)
	_box(b, Vector3(0, 0.95, 4.84), Vector3(1.5, 0.55, 0.05), Color(0.15, 0.15, 0.16))
	for i in range(5):
		_box(b, Vector3(0, 0.75 + i * 0.1, 4.87), Vector3(1.45, 0.025, 0.02), CHROME)
	_box(b, Vector3(0, 0.2, 4.9), Vector3(2.5, 0.35, 0.3), Color(0.14, 0.14, 0.14))
	for sx: float in [-1.0, 1.0]:
		_box(b, Vector3(0.95 * sx, 0.75, 4.83), Vector3(0.44, 0.3, 0.06), CHROME)
	_box(b, Vector3(0, 0.42, 5.05), Vector3(0.6, 0.16, 0.02), PLATE)
	# --- cargo body (wooden high-side deck, painted)
	_box(b, Vector3(0, 0.52, -1.2), Vector3(2.5, 0.15, 6.8), Color(0.45, 0.3, 0.15))
	for sx: float in [-1.0, 1.0]:
		_box(b, Vector3(1.21 * sx, 1.35, -1.2), Vector3(0.08, 1.5, 6.8), BODY)
		_box(b, Vector3(1.26 * sx, 1.95, -1.2), Vector3(0.04, 0.22, 6.8), BAND)
		_box(b, Vector3(1.26 * sx, 0.75, -1.2), Vector3(0.04, 0.12, 6.8), GREEN)
		for z: float in [-4.0, -2.6, -1.2, 0.2, 1.6]:
			_box(b, Vector3(1.255 * sx, 1.35, z), Vector3(0.03, 1.5, 0.08), Color(0.6, 0.38, 0.12))
	_box(b, Vector3(0, 1.55, 2.18), Vector3(2.5, 1.9, 0.08), BODY)
	_box(b, Vector3(0, 2.45, 2.2), Vector3(2.5, 0.12, 0.12), BAND)
	_box(b, Vector3(0, 1.35, -4.6), Vector3(2.5, 1.5, 0.08), BODY)
	_box(b, Vector3(0, 1.95, -4.65), Vector3(2.5, 0.2, 0.03), BAND)
	_box(b, Vector3(0, 0.42, -4.66), Vector3(0.6, 0.16, 0.02), PLATE)
	# fuel tank, exhaust, roof air-horn trumpets
	b.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.95, 0.05, 1.5)), 0.3, 0.3, 1.1, 10, CHROME, true, true)
	b.add_cylinder(Transform3D(Basis(), Vector3(-1.1, 2.0, 2.52)), 0.07, 0.07, 1.6, 8, CHROME)
	for i in range(2):
		var x := -0.25 + i * 0.5
		var length := 0.55 + i * 0.2
		b.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, 2.85, 3.6)), 0.11, 0.04, length, 8, CHROME, true, true)
	# --- interior
	_box(b, Vector3(0, 1.35, 4.5), Vector3(2.3, 0.35, 0.5), DASH)
	_box(b, Vector3(-0.55, 1.58, 4.32), Vector3(0.62, 0.22, 0.05), Color(0.05, 0.05, 0.06))
	_box(b, Vector3(0, 0.78, 3.9), Vector3(0.6, 0.45, 1.0), DASH)
	for sx: float in [-0.55, 0.55]:
		_box(b, Vector3(sx, 0.95, 3.3), Vector3(0.6, 0.12, 0.6), SEAT)
		_box(b, Vector3(sx, 1.42, 2.98), Vector3(0.6, 0.85, 0.12), SEAT)
		_box(b, Vector3(sx, 0.72, 3.3), Vector3(0.3, 0.45, 0.3), DASH)
	b.add_cylinder(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60)), Vector3(-0.55, 1.42, 4.3)), 0.035, 0.035, 0.45, 6, DASH)
	b.add_cylinder(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-15)), Vector3(-0.08, 1.05, 3.65)), 0.02, 0.02, 0.5, 6, CHROME)
	b.add_ellipsoid(Transform3D(Basis(), Vector3(-0.15, 1.3, 3.72)), Vector3(0.04, 0.04, 0.04), Color(0.1, 0.1, 0.1))
	# windscreen tassels (decoration)
	var tassel_cols := [Color(0.85, 0.1, 0.1), CAB_STRIPE, GREEN, Color(0.15, 0.3, 0.8)]
	for i in range(14):
		_box(b, Vector3(-1.04 + i * 0.16, 2.37, 4.72), Vector3(0.1, 0.12, 0.02), tassel_cols[i % 4])
	# The dashboard Vel now comes with the framed photo (DashboardPhoto).
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = b.commit()
	truck.add_child(body_mi)

	# --- glass
	var g := MeshBatcher.new()
	_box(g, Vector3(0, 1.975, 4.79), Vector3(2.26, 0.95, 0.03), Color.WHITE)
	for sx: float in [-1.0, 1.0]:
		_box(g, Vector3(1.2 * sx, 2.02, 4.1), Vector3(0.03, 1.05, 1.2), Color.WHITE)
		_box(g, Vector3(1.6 * sx, 2.1, 4.6), Vector3(0.02, 0.42, 0.22), Color.WHITE)
	var glass_mi := MeshInstance3D.new()
	glass_mi.name = "Glass"
	glass_mi.mesh = g.commit(MeshKit.glass())
	glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	truck.add_child(glass_mi)

	# --- lamps (separate materials so they can switch on and off)
	var mats := {
		"head": MeshKit.emissive(Color(1.0, 0.96, 0.85), 0.2),
		"brake": MeshKit.emissive(Color(0.95, 0.05, 0.04), 0.0),
		"reverse": MeshKit.emissive(Color(1, 1, 1), 0.0),
		"ind_l": MeshKit.emissive(Color(1.0, 0.55, 0.0), 0.0),
		"ind_r": MeshKit.emissive(Color(1.0, 0.55, 0.0), 0.0),
		"marker": MeshKit.emissive(Color(1.0, 0.5, 0.1), 1.0),
	}
	_lamp(truck, mats["head"], [[Vector3(0.95, 0.75, 4.865), Vector3(0.36, 0.22, 0.02)], [Vector3(-0.95, 0.75, 4.865), Vector3(0.36, 0.22, 0.02)]])
	_lamp(truck, mats["brake"], [[Vector3(0.95, 0.6, -4.66), Vector3(0.3, 0.16, 0.04)], [Vector3(-0.95, 0.6, -4.66), Vector3(0.3, 0.16, 0.04)]])
	_lamp(truck, mats["reverse"], [[Vector3(0.6, 0.6, -4.66), Vector3(0.14, 0.12, 0.04)], [Vector3(-0.6, 0.6, -4.66), Vector3(0.14, 0.12, 0.04)]])
	# truck left = +X side, right = -X side
	_lamp(truck, mats["ind_l"], [[Vector3(1.18, 0.75, 4.85), Vector3(0.12, 0.16, 0.04)], [Vector3(1.18, 0.6, -4.66), Vector3(0.12, 0.16, 0.04)], [Vector3(1.24, 1.5, 4.5), Vector3(0.03, 0.08, 0.16)]])
	_lamp(truck, mats["ind_r"], [[Vector3(-1.18, 0.75, 4.85), Vector3(0.12, 0.16, 0.04)], [Vector3(-1.18, 0.6, -4.66), Vector3(0.12, 0.16, 0.04)], [Vector3(-1.24, 1.5, 4.5), Vector3(0.03, 0.08, 0.16)]])
	var markers := []
	for i in range(6):
		markers.append([Vector3(-1.0 + i * 0.4, 3.07, 4.8), Vector3(0.12, 0.08, 0.06)])
	_lamp(truck, mats["marker"], markers)

	mats["spinner"] = build_steering_wheel(truck)

	# --- painted text (fictional company and registration)
	MeshKit.label3d(truck, "MURUGAN TRANSPORT", Transform3D(Basis(), Vector3(0, 2.86, 4.975)), 40, Color(0.6, 0.05, 0.05), 0.0055, 90.0)
	MeshKit.label3d(truck, "TN 37 BZ 4521", Transform3D(Basis(), Vector3(0, 0.42, 5.065)), 40, Color.BLACK, 0.0032, 40.0)
	var back := Basis(Vector3.UP, PI)
	MeshKit.label3d(truck, "HORN OK PLEASE", Transform3D(back, Vector3(0, 1.45, -4.645)), 44, Color(0.6, 0.05, 0.05), 0.0068, 90.0)
	MeshKit.label3d(truck, "USE DIPPER AT NIGHT", Transform3D(back, Vector3(0, 1.08, -4.645)), 30, Color(0.1, 0.25, 0.6), 0.0045, 60.0)
	MeshKit.label3d(truck, "TN 37 BZ 4521", Transform3D(back, Vector3(0, 0.42, -4.675)), 40, Color.BLACK, 0.0032, 40.0)
	for sx: float in [-1.0, 1.0]:
		var side := Basis(Vector3.UP, PI / 2 * sx)
		MeshKit.label3d(truck, "SRI MURUGAN TRANSPORT  -  COIMBATORE", Transform3D(side, Vector3(1.28 * sx, 1.45, -1.2)), 44, Color(0.55, 0.05, 0.05), 0.0075, 90.0)
	return mats


## Small Vel (Lord Murugan's spear) with a marigold garland, mounted on the dashboard.
static func _build_vel(b: MeshBatcher, base: Vector3) -> void:
	_box(b, base + Vector3(0, 0.02, 0), Vector3(0.1, 0.04, 0.1), Color(0.35, 0.18, 0.08))
	b.add_cylinder(Transform3D(Basis(), base + Vector3(0, 0.2, 0)), 0.012, 0.012, 0.34, 6, GOLD)
	b.add_ellipsoid(Transform3D(Basis(Vector3.RIGHT, PI / 2), base + Vector3(0, 0.44, 0)), Vector3(0.05, 0.012, 0.1), GOLD, 3, 8)
	b.add_cylinder(Transform3D(Basis(), base + Vector3(0, 0.33, 0)), 0.04, 0.0, 0.03, 6, GOLD)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var c := Color(1.0, 0.55, 0.0) if i % 2 == 0 else Color(1.0, 0.85, 0.1)
		b.add_ellipsoid(Transform3D(Basis(), base + Vector3(cos(a) * 0.065, 0.06, sin(a) * 0.065)), Vector3(0.02, 0.02, 0.02), c, 3, 5)


static func _lamp(truck: Node3D, material: Material, parts: Array) -> void:
	var b := MeshBatcher.new()
	for p in parts:
		_box(b, p[0], p[1], Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	truck.add_child(mi)


static func wheel_mesh(dual: bool, left_side: bool) -> ArrayMesh:
	var key := "%s_%s" % [dual, left_side]
	if _wheel_meshes.has(key):
		return _wheel_meshes[key]
	var b := MeshBatcher.new()
	var rot := Basis(Vector3(0, 0, 1), PI / 2)
	var r := 0.52
	var out := 1.0 if left_side else -1.0
	var face_x := 0.0
	if dual:
		for off: float in [-0.155, 0.155]:
			b.add_cylinder(Transform3D(rot, Vector3(off, 0, 0)), r, r, 0.28, 14, TYRE, true, true)
		face_x = 0.3 * out
	else:
		b.add_cylinder(Transform3D(rot, Vector3.ZERO), r, r, 0.3, 14, TYRE, true, true)
		face_x = 0.155 * out
	b.add_cylinder(Transform3D(rot, Vector3(face_x, 0, 0)), 0.3, 0.3, 0.03, 12, RIM, true, true)
	b.add_cylinder(Transform3D(rot, Vector3(face_x + 0.03 * out, 0, 0)), 0.1, 0.1, 0.05, 8, CHROME, true, true)
	for i in range(6):
		var a := TAU * float(i) / 6.0
		b.add_box(Transform3D(Basis(), Vector3(face_x + 0.025 * out, cos(a) * 0.19, sin(a) * 0.19)), Vector3(0.03, 0.05, 0.05), CHROME)
	var mesh := b.commit()
	_wheel_meshes[key] = mesh
	return mesh


## Steering wheel (shared by both truck models). The pivot tilts the column, the
## returned spinner turns with the steering.
static func build_steering_wheel(truck: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "SteeringPivot"
	pivot.position = Vector3(-0.55, 1.6, 4.15)
	pivot.rotation.x = deg_to_rad(-60)
	truck.add_child(pivot)
	var spinner := Node3D.new()
	spinner.name = "SteeringWheel"
	pivot.add_child(spinner)
	var sw := MeshBatcher.new()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		sw.add_box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.23, 0, sin(a) * 0.23)), Vector3(0.04, 0.04, 0.115), Color(0.08, 0.08, 0.08))
	for i in range(3):
		var a2 := TAU * float(i) / 3.0 + PI / 2
		sw.add_box(Transform3D(Basis(Vector3.UP, -a2 + PI / 2), Vector3(cos(a2) * 0.11, 0, sin(a2) * 0.11)), Vector3(0.22, 0.02, 0.04), Color(0.2, 0.2, 0.2))
	sw.add_cylinder(Transform3D(Basis(), Vector3.ZERO), 0.06, 0.06, 0.05, 8, GOLD)
	MeshKit.mesh_instance(spinner, sw.commit())
	return spinner
