class_name MeshBatcher
extends RefCounted
## Collects simple primitives into ONE vertex-coloured ArrayMesh.
## Merging a whole world chunk into a single mesh keeps draw calls very low,
## which matters most on integrated graphics.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

static var _vc_material: StandardMaterial3D

const _BOX_FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
]


static func vertex_color_material() -> StandardMaterial3D:
	if _vc_material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = false  # already converted in _push()
		m.roughness = 0.9
		_vc_material = m
	return _vc_material


func is_empty() -> bool:
	return verts.is_empty()


func vertex_count() -> int:
	return verts.size()


func _push(p: Vector3, n: Vector3, c: Color) -> int:
	verts.append(p)
	normals.append(n)
	# Colours are written in sRGB (as picked by eye); shading needs linear values.
	# Converted here because the material flag vertex_color_is_srgb has no effect
	# in the Compatibility renderer (measured: toggling it changed no pixel).
	colors.append(c.srgb_to_linear())
	return verts.size() - 1


func _tri(i0: int, i1: int, i2: int, n: Vector3) -> void:
	var a: Vector3 = verts[i0]
	# Godot treats clockwise triangles (seen from the front) as front faces.
	if (verts[i1] - a).cross(verts[i2] - a).dot(n) > 0.0:
		indices.append(i0)
		indices.append(i2)
		indices.append(i1)
	else:
		indices.append(i0)
		indices.append(i1)
		indices.append(i2)


func add_triangle(p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3, c: Color) -> void:
	var i0 := _push(p0, n, c)
	var i1 := _push(p1, n, c)
	var i2 := _push(p2, n, c)
	_tri(i0, i1, i2, n)


func add_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, c: Color) -> void:
	var i0 := _push(p0, n, c)
	var i1 := _push(p1, n, c)
	var i2 := _push(p2, n, c)
	var i3 := _push(p3, n, c)
	_tri(i0, i1, i2, n)
	_tri(i0, i2, i3, n)


## Quad whose normal is derived from its corners and made to face away from `inside`.
func add_quad_out(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, inside: Vector3, c: Color) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	if n.length_squared() < 1e-10:
		n = (p2 - p0).cross(p3 - p0)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	var mid := (p0 + p1 + p2 + p3) * 0.25
	if n.dot(mid - inside) < 0.0:
		n = -n
	add_quad(p0, p1, p2, p3, n, c)


func add_tri_out(p0: Vector3, p1: Vector3, p2: Vector3, inside: Vector3, c: Color) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	var mid := (p0 + p1 + p2) / 3.0
	if n.dot(mid - inside) < 0.0:
		n = -n
	add_triangle(p0, p1, p2, n, c)


## Flat horizontal quad (for roads, plots, ground patches). Faces up.
func add_flat(center: Vector3, size_x: float, size_z: float, c: Color, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hx := b.x * size_x * 0.5
	var hz := b.z * size_z * 0.5
	add_quad(center - hx - hz, center + hx - hz, center + hx + hz, center - hx + hz, Vector3.UP, c)


func add_box(xf: Transform3D, size: Vector3, c: Color, with_bottom := false) -> void:
	var h := size * 0.5
	for f in _BOX_FACES:
		var n: Vector3 = f[0]
		if not with_bottom and n.y < -0.5:
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var cc := n * h
		var uu := u * h
		var vv := v * h
		add_quad(xf * (cc - uu - vv), xf * (cc + uu - vv), xf * (cc + uu + vv), xf * (cc - uu + vv),
			(xf.basis * n).normalized(), c)


## Cylinder or cone along local Y, centred on xf.origin.
func add_cylinder(xf: Transform3D, r_bottom: float, r_top: float, height: float, sides: int, c: Color,
		cap_top := true, cap_bottom := false) -> void:
	var hh := height * 0.5
	var center := xf.origin
	var top_c := xf * Vector3(0, hh, 0)
	var bot_c := xf * Vector3(0, -hh, 0)
	var up := (xf.basis * Vector3.UP).normalized()
	for i in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var b0 := xf * Vector3(cos(a0) * r_bottom, -hh, sin(a0) * r_bottom)
		var b1 := xf * Vector3(cos(a1) * r_bottom, -hh, sin(a1) * r_bottom)
		if r_top <= 0.001:
			add_tri_out(b0, b1, top_c, center, c)
		else:
			var t0 := xf * Vector3(cos(a0) * r_top, hh, sin(a0) * r_top)
			var t1 := xf * Vector3(cos(a1) * r_top, hh, sin(a1) * r_top)
			add_quad_out(b0, b1, t1, t0, center, c)
			if cap_top:
				add_triangle(top_c, t0, t1, up, c)
		if cap_bottom and r_bottom > 0.001:
			add_triangle(bot_c, b0, b1, -up, c)


## Low-poly ellipsoid (flat shaded), used for tree crowns, heads, fruit.
func add_ellipsoid(xf: Transform3D, radii: Vector3, c: Color, rings := 4, sides := 7) -> void:
	var center := xf.origin
	for r in range(rings):
		var phi0 := PI * float(r) / float(rings) - PI * 0.5
		var phi1 := PI * float(r + 1) / float(rings) - PI * 0.5
		for s in range(sides):
			var th0 := TAU * float(s) / float(sides)
			var th1 := TAU * float(s + 1) / float(sides)
			var p00 := xf * Vector3(cos(phi0) * cos(th0) * radii.x, sin(phi0) * radii.y, cos(phi0) * sin(th0) * radii.z)
			var p01 := xf * Vector3(cos(phi0) * cos(th1) * radii.x, sin(phi0) * radii.y, cos(phi0) * sin(th1) * radii.z)
			var p10 := xf * Vector3(cos(phi1) * cos(th0) * radii.x, sin(phi1) * radii.y, cos(phi1) * sin(th0) * radii.z)
			var p11 := xf * Vector3(cos(phi1) * cos(th1) * radii.x, sin(phi1) * radii.y, cos(phi1) * sin(th1) * radii.z)
			if r == 0:
				add_tri_out(p00, p11, p10, center, c)
			elif r == rings - 1:
				add_tri_out(p00, p01, p10, center, c)
			else:
				add_quad_out(p00, p01, p11, p10, center, c)


## Gable roof: ridge along local X, base width along local Z.
func add_prism(xf: Transform3D, size: Vector3, c: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var inside := xf * Vector3(0, -hy * 0.33, 0)
	var a := xf * Vector3(-hx, -hy, hz)
	var b := xf * Vector3(hx, -hy, hz)
	var d := xf * Vector3(-hx, -hy, -hz)
	var e := xf * Vector3(hx, -hy, -hz)
	var r0 := xf * Vector3(-hx, hy, 0)
	var r1 := xf * Vector3(hx, hy, 0)
	add_quad_out(a, b, r1, r0, inside, c)
	add_quad_out(e, d, r0, r1, inside, c)
	add_tri_out(a, r0, d, inside, c)
	add_tri_out(b, e, r1, inside, c)


## Sawtooth / lean-to roof wedge: vertical face at -Z, slope falling towards +Z.
func add_wedge(xf: Transform3D, size: Vector3, c: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var inside := xf * Vector3(0, -hy / 3.0, -hz / 3.0)
	var a := xf * Vector3(-hx, -hy, hz)
	var b := xf * Vector3(hx, -hy, hz)
	var d := xf * Vector3(-hx, -hy, -hz)
	var e := xf * Vector3(hx, -hy, -hz)
	var t0 := xf * Vector3(-hx, hy, -hz)
	var t1 := xf * Vector3(hx, hy, -hz)
	add_quad_out(a, b, t1, t0, inside, c)
	add_quad_out(d, e, t1, t0, inside, c)
	add_tri_out(a, t0, d, inside, c)
	add_tri_out(b, e, t1, inside, c)


func commit(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material if material != null else vertex_color_material())
	return mesh
