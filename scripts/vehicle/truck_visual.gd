class_name TruckVisual
extends RefCounted
## Detailed truck model: an original Indian cab-over 6x4 lorry made in Blender by
## tools/blender/build_indian_lorry.py and exported to assets/trucks/indian_lorry.gltf
## (PBR materials, CC0 Poly Haven textures). No manufacturer logos or names.
##
## The model uses the same frame as Truck (faces +Z, right-hand drive, wheel centres
## at the VehicleWheel3D positions), so collision, doors, cockpit eye and the
## dashboard photo line up. Truck falls back to TruckModel if this cannot load.

const MODEL_PATH := "res://assets/trucks/indian_lorry.gltf"
const LAMP_KEYS := ["head", "brake", "reverse", "ind_l", "ind_r", "marker"]

static var _scene: PackedScene
static var _load_failed := false
static var _wheel_meshes := {}


static func _load() -> PackedScene:
	if _scene == null and not _load_failed:
		if ResourceLoader.exists(MODEL_PATH):
			_scene = load(MODEL_PATH) as PackedScene
		if _scene == null:
			_load_failed = true
			push_warning("Detailed truck model not found (%s); using the simple model." % MODEL_PATH)
	return _scene


static func available() -> bool:
	return _load() != null


## Wheel mesh from the model (axle along X, outer face towards +X), or null.
static func wheel_mesh(dual: bool) -> Mesh:
	var key := "dual" if dual else "single"
	if _wheel_meshes.has(key):
		return _wheel_meshes[key]
	var ps := _load()
	if ps == null:
		return null
	var inst := ps.instantiate()
	for k in ["single", "dual"]:
		var mi := inst.find_child("WheelDual" if k == "dual" else "WheelSingle", true, false) as MeshInstance3D
		if mi:
			_wheel_meshes[k] = mi.mesh
	inst.free()
	return _wheel_meshes.get(key)


## Adds the model to the truck. Returns the same dictionary TruckModel.build does
## (lamp materials and the steering spinner), or {} if the model is unavailable.
static func build(truck: Node3D) -> Dictionary:
	var ps := _load()
	if ps == null:
		return {}
	var root := ps.instantiate() as Node3D
	if root == null:
		return {}
	root.name = "Model"
	# Wheel templates are only used through wheel_mesh(); drop them from the body.
	for n in ["WheelSingle", "WheelDual"]:
		var w := root.find_child(n, true, false)
		if w:
			w.get_parent().remove_child(w)
			w.free()
	var mats := {
		"head": MeshKit.emissive(Color(1.0, 0.96, 0.85), 0.2),
		"brake": MeshKit.emissive(Color(0.95, 0.05, 0.04), 0.0),
		"reverse": MeshKit.emissive(Color(1, 1, 1), 0.0),
		"ind_l": MeshKit.emissive(Color(1.0, 0.55, 0.0), 0.0),
		"ind_r": MeshKit.emissive(Color(1.0, 0.55, 0.0), 0.0),
		"marker": MeshKit.emissive(Color(1.0, 0.5, 0.1), 1.0),
	}
	var missing: Array[String] = []
	for k in LAMP_KEYS:
		var lamp := root.find_child("Lamp_" + k, true, false) as MeshInstance3D
		if lamp == null:
			missing.append("Lamp_" + k)
			continue
		lamp.material_override = mats[k]
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glass := root.find_child("Glass", true, false) as MeshInstance3D
	if glass:
		glass.material_override = MeshKit.glass()
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		missing.append("Glass")
	if root.find_child("Body", true, false) == null:
		missing.append("Body")
	if not missing.is_empty():
		push_warning("Truck model is missing parts: %s; using the simple model." % ", ".join(missing))
		root.free()
		return {}
	truck.add_child(root)
	mats["wipers"] = [root.find_child("Wiper_L", true, false), root.find_child("Wiper_R", true, false)]
	mats["spinner"] = TruckModel.build_steering_wheel(truck)
	_add_labels(truck)
	return mats


## Painted lettering (fictional company and registration), placed on the model's panels.
static func _add_labels(truck: Node3D) -> void:
	var red := Color(0.6, 0.05, 0.05)
	MeshKit.label3d(truck, "MURUGAN TRANSPORT", Transform3D(Basis(), Vector3(0, 2.66, 4.848)), 40, red, 0.0052, 90.0)
	MeshKit.label3d(truck, "TN 37 BZ 4521", Transform3D(Basis(), Vector3(0, 0.34, 5.046)), 40, Color.BLACK, 0.0032, 40.0)
	var back := Basis(Vector3.UP, PI)
	MeshKit.label3d(truck, "HORN OK PLEASE", Transform3D(back, Vector3(0, 1.5, -4.636)), 44, red, 0.0068, 90.0)
	MeshKit.label3d(truck, "USE DIPPER AT NIGHT", Transform3D(back, Vector3(0, 1.1, -4.636)), 30, Color(0.1, 0.25, 0.6), 0.0045, 60.0)
	MeshKit.label3d(truck, "TN 37 BZ 4521", Transform3D(back, Vector3(0, 0.25, -4.692)), 40, Color.BLACK, 0.0032, 40.0)
	for sx: float in [-1.0, 1.0]:
		var side := Basis(Vector3.UP, PI / 2 * sx)
		MeshKit.label3d(truck, "SRI MURUGAN TRANSPORT  -  COIMBATORE", Transform3D(side, Vector3(1.252 * sx, 1.3, -1.2)), 44, red, 0.0062, 90.0)


## Height of the body origin above the ground when the truck stands on its wheels.
const RIDE_HEIGHT := 0.77
const AXLE_Y := -0.25
const PROP_WHEELS := [[1.0, 3.4, false], [-1.0, 3.4, false], [0.95, -1.8, true], [-0.95, -1.8, true], [0.95, -3.1, true], [-0.95, -3.1, true]]


## Parked lorry for yards and depots: the same model without physics, with its own
## cab colour. xf is the ground point under the truck. Returns false if unavailable.
static func add_prop(parent: Node3D, xf: Transform3D, cab_color: Color) -> bool:
	var ps := _load()
	if ps == null:
		return false
	var root := ps.instantiate() as Node3D
	for n in ["WheelSingle", "WheelDual"]:
		var w := root.find_child(n, true, false)
		if w:
			w.get_parent().remove_child(w)
			w.free()
	root.name = "ParkedLorry"
	root.transform = xf * Transform3D(Basis(), Vector3(0, RIDE_HEIGHT, 0))
	var body := root.find_child("Body", true, false) as MeshInstance3D
	if body and body.mesh:
		for i in body.mesh.get_surface_count():
			var m := body.mesh.surface_get_material(i) as StandardMaterial3D
			if m and m.resource_name == "CabPaint":
				var tinted := m.duplicate() as StandardMaterial3D
				tinted.albedo_color = cab_color
				body.set_surface_override_material(i, tinted)
	var glass := root.find_child("Glass", true, false) as MeshInstance3D
	if glass:
		glass.material_override = MeshKit.glass()
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in LAMP_KEYS:
		var lamp := root.find_child("Lamp_" + k, true, false) as MeshInstance3D
		if lamp:
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for p in PROP_WHEELS:
		var mi := MeshInstance3D.new()
		mi.mesh = wheel_mesh(bool(p[2]))
		mi.position = Vector3(float(p[0]), AXLE_Y, float(p[1]))
		if float(p[0]) < 0.0:
			mi.rotation.y = PI
		root.add_child(mi)
	parent.add_child(root, true)  # readable names (ParkedLorry2, ...) when several share a chunk
	return true
