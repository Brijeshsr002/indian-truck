class_name MeshKit
extends RefCounted
## Shared materials and small scene-building helpers.

static var _mats := {}
static var _glass: StandardMaterial3D
static var _sign_font: SystemFont


static func mat(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_mats[key] = m
	return m


## Always returns a NEW material, because callers switch the emission on and off.
static func emissive(color: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func glass() -> StandardMaterial3D:
	if _glass == null:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.22, 0.34, 0.42, 0.38)
		m.roughness = 0.08
		m.metallic = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass = m
	return _glass


## Windows font with Tamil glyphs (Nirmala UI ships with Windows 10/11).
static func sign_font() -> Font:
	if _sign_font == null:
		_sign_font = SystemFont.new()
		_sign_font.font_names = PackedStringArray(["Nirmala UI", "Latha", "Segoe UI", "Arial"])
		_sign_font.font_weight = 700
	return _sign_font


static func label3d(parent: Node, text: String, xf: Transform3D, font_size := 48,
		color := Color.WHITE, pixel := 0.01, vis_range := 140.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = sign_font()
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.transform = xf
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_range > 0.0:
		l.visibility_range_end = vis_range
	parent.add_child(l)
	return l


static func col_box(body: Node3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = xf
	body.add_child(cs)


static func col_cylinder(body: Node3D, pos: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


static func mesh_instance(parent: Node, mesh: Mesh, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	parent.add_child(mi)
	return mi
