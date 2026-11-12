"""Builds the Indian cab-over 6x4 lorry for Indian Truck Simulator and exports it as glTF.

Run headless (no Blender UI needed):
  blender.exe --background --factory-startup --python build_indian_lorry.py -- OUT.gltf TEXTURE_DIR [PREVIEW_PREFIX]

Design: an original design inspired by common Indian highway lorries (cab-over cab,
wooden high-side body, Tamil Nadu paint scheme). No manufacturer logos or names.

All geometry below is written in GODOT coordinates (metres): +X = truck left,
+Y = up, +Z = forward. It is converted to Blender's Z-up frame when the mesh is
built, and the glTF exporter converts it back, so the numbers here are exactly the
numbers Godot sees. The frame matches scripts/vehicle/truck.gd (wheel positions,
cockpit eye, doors, collision boxes).

Output objects (names are used by scripts/vehicle/truck_visual.gd):
  Body          every static painted / metal / wood part, interior included
  Glass         windscreen and windows (Godot replaces the material)
  Lamp_head, Lamp_brake, Lamp_reverse, Lamp_ind_l, Lamp_ind_r, Lamp_marker
  Wiper_L, Wiper_R   origin at the wiper pivot (for animation)
  WheelSingle, WheelDual   at the origin, axle along X, outer face towards +X
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Matrix, Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) < 2:
    raise SystemExit("usage: -- OUT.gltf TEXTURE_DIR [PREVIEW_PREFIX]")
OUT_PATH = os.path.abspath(argv[0])
TEX_DIR = os.path.abspath(argv[1])
PREVIEW = argv[2] if len(argv) > 2 else ""

# ------------------------------------------------------------------ scene reset
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for me in list(bpy.data.meshes):
    bpy.data.meshes.remove(me)
for m in list(bpy.data.materials):
    bpy.data.materials.remove(m)

D2R = math.pi / 180.0


def g2b(v):
    """Godot (x, y, z) -> Blender (x, -z, y). A proper rotation, so winding is kept."""
    return Vector((v[0], -v[2], v[1]))


# ------------------------------------------------------------------ materials
TILE = {}  # material name -> (tile size in metres, rotate boards to horizontal)


def _img(name, non_color=False):
    img = bpy.data.images.load(os.path.join(TEX_DIR, name), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def mat(name, color, metallic=0.0, rough=0.5, tex=None, tile=2.0, horizontal=False, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if tex:
        diff = nt.nodes.new("ShaderNodeTexImage")
        diff.image = _img(tex + "_diff_1k.jpg")
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        nt.links.new(diff.outputs["Color"], mix.inputs[6])
        mix.inputs[7].default_value = (color[0], color[1], color[2], 1.0)
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        rough_img = nt.nodes.new("ShaderNodeTexImage")
        rough_img.image = _img(tex + "_rough_1k.jpg", True)
        nt.links.new(rough_img.outputs["Color"], bsdf.inputs["Roughness"])
        nor_img = nt.nodes.new("ShaderNodeTexImage")
        nor_img.image = _img(tex + "_nor_gl_1k.jpg", True)
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nor_img.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    TILE[name] = (tile, horizontal)
    return m


def srgb(h):
    """Hex colour -> linear RGB tuple (Blender colour inputs are linear)."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


M = {
    "cab": mat("CabPaint", srgb("#d8501a"), 0.25, 0.32),
    "cab_yellow": mat("CabYellow", srgb("#f2c21b"), 0.2, 0.35),
    "cab_green": mat("CabGreen", srgb("#167a3a"), 0.2, 0.35),
    "black": mat("SatinBlack", srgb("#1a1a1b"), 0.1, 0.55),
    "chassis": mat("Chassis", srgb("#202021"), 0.35, 0.6),
    "bumper": mat("BumperGrey", srgb("#3a3b3d"), 0.4, 0.45),
    "chrome": mat("Chrome", srgb("#d9dade"), 1.0, 0.12),
    "alu": mat("Aluminium", srgb("#b8babd"), 0.9, 0.32),
    "rubber": mat("Rubber", srgb("#121212"), 0.0, 0.9),
    "plate": mat("PlateYellow", srgb("#f5d417"), 0.0, 0.4),
    "white": mat("PlateWhite", srgb("#f0f0f0"), 0.0, 0.4),
    "reflector": mat("Reflector", srgb("#c4140f"), 0.0, 0.25),
    "mirror": mat("MirrorGlass", srgb("#e6eef2"), 1.0, 0.02),
    "body_yellow": mat("BodyPlanksYellow", srgb("#ffd34a"), 0.0, 0.6, "white_planks_clean", 3.5, True),
    "body_red": mat("BodyPlanksRed", srgb("#d42a1c"), 0.0, 0.6, "white_planks_clean", 3.5, True),
    "body_green": mat("BodyPlanksGreen", srgb("#2ca84f"), 0.0, 0.6, "white_planks_clean", 3.5, True),
    "body_blue": mat("BodyPlanksBlue", srgb("#2a5fd0"), 0.0, 0.6, "white_planks_clean", 3.5, True),
    "post": mat("BodyPostRed", srgb("#b0161a"), 0.3, 0.45),
    "deck": mat("DeckWood", srgb("#ffffff"), 0.0, 0.8, "wood_planks", 2.0),
    "tread": mat("TreadPlate", srgb("#ffffff"), 0.8, 0.4, "metal_plate_02", 1.0),
    "dash": mat("DashPlastic", srgb("#2b2a2a"), 0.0, 0.7),
    "trim": mat("TrimBeige", srgb("#b9a98d"), 0.0, 0.75),
    "seat": mat("SeatFabric", srgb("#6e1712"), 0.0, 0.92),
    "gauge": mat("GaugeFace", srgb("#0b0c10"), 0.0, 0.3),
    "rim": mat("RimRed", srgb("#b3201a"), 0.35, 0.4),
    "lamp": mat("LampLens", srgb("#ffffff"), 0.0, 0.2),
    "glass": mat("GlassTint", srgb("#a9c4cf"), 0.0, 0.05),
    "tassel_r": mat("TasselRed", srgb("#d0161a"), 0.0, 0.8),
    "tassel_y": mat("TasselYellow", srgb("#f2c21b"), 0.0, 0.8),
    "tassel_g": mat("TasselGreen", srgb("#18903f"), 0.0, 0.8),
    "tassel_b": mat("TasselBlue", srgb("#2850c8"), 0.0, 0.8),
}


# ------------------------------------------------------------------ output objects
class Out:
    def __init__(self, name, origin=(0.0, 0.0, 0.0)):
        self.name = name
        self.origin = Vector(origin)
        self.bm = bmesh.new()
        self.mats = []

    def add(self, src, material):
        if material not in self.mats:
            self.mats.append(material)
        mi = self.mats.index(material)
        vmap = {}
        for v in src.verts:
            vmap[v] = self.bm.verts.new(g2b(v.co - self.origin))
        for f in src.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mi
        src.free()

    def finish(self):
        bm = self.bm
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            f.smooth = True
            tile, horizontal = TILE.get(self.mats[f.material_index].name, (2.0, False))
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for loop in f.loops:
                c = loop.vert.co + g2b(self.origin)
                if ax == 0:
                    u, v = (c.z, c.y) if horizontal else (c.y, c.z)
                elif ax == 1:
                    u, v = (c.z, c.x) if horizontal else (c.x, c.z)
                else:
                    u, v = c.x, c.y
                loop[uv].uv = (u / tile, v / tile)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.calc_face_angle(0.0) < 35.0 * D2R
            else:
                e.smooth = False
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        if me.validate(clean_customdata=False):
            print("CLEANED", self.name)
        bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        ob.location = g2b(self.origin)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ------------------------------------------------------------------ primitives (Godot coords)
def xform(rot=(0, 0, 0), pos=(0, 0, 0)):
    """Rotation in degrees about Godot X, Y, Z (applied X then Y then Z), then translation."""
    r = Euler((rot[0] * D2R, rot[1] * D2R, rot[2] * D2R), "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(pos)) @ r


def _finish_prim(bm, m):
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(out, mat_, center, size, rot=(0, 0, 0), bevel=0.0, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0.0:
        b = min(bevel, min(size) * 0.49)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=seg, affect="EDGES", profile=0.5, clamp_overlap=True)
    out.add(_finish_prim(bm, xform(rot, center)), mat_)


def cyl(out, mat_, center, r1, r2, length, n=16, rot=(0, 0, 0), caps=True):
    """Cylinder/cone along Godot +Y before rotation. rot=(90,0,0) points it along Z, (0,0,90) along X."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=n, radius1=r1, radius2=r2, depth=length)
    # create_cone builds along its local Z; turn that into Godot +Y.
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 4, "X"), verts=bm.verts)
    out.add(_finish_prim(bm, xform(rot, center)), mat_)


def sphere(out, mat_, center, radii, seg=12, rings=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    bmesh.ops.scale(bm, vec=Vector(radii), verts=bm.verts)
    out.add(_finish_prim(bm, xform((0, 0, 0), center)), mat_)


def lathe(out, mat_, profile, n=32, m=None):
    """Revolves a closed (radius, x) profile around the X axis."""
    bm = bmesh.new()
    rings = []
    for i in range(n):
        a = 2 * math.pi * i / n
        ring = [bm.verts.new((x, r * math.cos(a), r * math.sin(a))) for (r, x) in profile]
        rings.append(ring)
    k = len(profile)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for j in range(k):
            j2 = (j + 1) % k
            try:
                bm.faces.new((a[j], a[j2], b[j2], b[j]))
            except ValueError:
                pass
    out.add(_finish_prim(bm, m if m is not None else Matrix()), mat_)


def arc(out, mat_, center, r_in, r_out, width, a0, a1, n=12):
    """Curved fender strip around the X axis (a wheel arch). Angles in degrees, 0 = forward (+Z), 90 = up."""
    bm = bmesh.new()
    pts = []
    for i in range(n + 1):
        a = (a0 + (a1 - a0) * i / n) * D2R
        ca, sa = math.cos(a), math.sin(a)
        row = []
        for (r, x) in ((r_in, -width / 2), (r_out, -width / 2), (r_out, width / 2), (r_in, width / 2)):
            row.append(bm.verts.new((x, r * sa, r * ca)))
        pts.append(row)
    for i in range(n):
        a, b = pts[i], pts[i + 1]
        for j in range(4):
            j2 = (j + 1) % 4
            bm.faces.new((a[j], a[j2], b[j2], b[j]))
    bm.faces.new(pts[0][::-1])
    bm.faces.new(pts[-1])
    out.add(_finish_prim(bm, xform((0, 0, 0), center)), mat_)


def sweep(out, mat_, path, half_w, thick):
    """Flat strip (leaf spring) along a list of (z, y) points, width along X."""
    bm = bmesh.new()
    rows = []
    for (z, y) in path:
        rows.append([bm.verts.new((x, y + dy, z)) for (x, dy) in ((-half_w, 0), (half_w, 0), (half_w, thick), (-half_w, thick))])
    for i in range(len(rows) - 1):
        a, b = rows[i], rows[i + 1]
        for j in range(4):
            j2 = (j + 1) % 4
            bm.faces.new((a[j], a[j2], b[j2], b[j]))
    bm.faces.new(rows[0])
    bm.faces.new(rows[-1][::-1])
    out.add(_finish_prim(bm, Matrix()), mat_)


def evaluated_bmesh(ob):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    return bm


# ================================================================== CAB SHELL
CAB_W = 1.23          # half width
CAB_REAR = 2.62
CAB_FRONT = 4.86
CAB_BOTTOM = 0.45
CAB_ROOF = 2.55
WS_KNEE_Y = 1.55      # where the vertical lower front meets the sloped windscreen
WS_TOP = (4.70, 2.40)  # (z, y) top of windscreen slope


def ws_z(y):
    """Z of the windscreen surface at height y (front face slope)."""
    return CAB_FRONT - (y - WS_KNEE_Y) * (CAB_FRONT - WS_TOP[0]) / (WS_TOP[1] - WS_KNEE_Y)


def build_cab_shell():
    profile = [  # (z, y) side profile, counter-clockwise seen from +X
        (CAB_REAR, CAB_BOTTOM), (CAB_FRONT, CAB_BOTTOM), (CAB_FRONT, WS_KNEE_Y),
        (WS_TOP[0], WS_TOP[1]), (4.58, CAB_ROOF), (CAB_REAR, CAB_ROOF),
    ]
    bm = bmesh.new()
    left = [bm.verts.new((CAB_W, y, z)) for (z, y) in profile]
    right = [bm.verts.new((-CAB_W, y, z)) for (z, y) in profile]
    k = len(profile)
    bm.faces.new(left)
    bm.faces.new(right[::-1])
    for i in range(k):
        i2 = (i + 1) % k
        bm.faces.new((left[i2], left[i], right[i], right[i2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.08, segments=3, affect="EDGES", profile=0.5, clamp_overlap=True)
    before = [v.co.copy() for v in bm.verts]
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.045)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Convert the Godot-frame bmesh to a Blender object so booleans can cut the windows.
    me = bpy.data.meshes.new("cab_tmp")
    tmp = bmesh.new()
    vmap = {v: tmp.verts.new(g2b(v.co)) for v in bm.verts}
    for f in bm.faces:
        tmp.faces.new([vmap[v] for v in f.verts])
    bm.free()
    tmp.to_mesh(me)
    tmp.free()
    shell = bpy.data.objects.new("cab_tmp", me)
    bpy.context.scene.collection.objects.link(shell)

    cutters = bpy.data.collections.new("cutters")
    bpy.context.scene.collection.children.link(cutters)

    def cutter(center, size, rot=(0, 0, 0), bevel=0.0):
        o = Out("cut")
        box(o, M["black"], center, size, rot, bevel, 3)
        ob = o.finish()
        bpy.context.scene.collection.objects.unlink(ob)
        cutters.objects.link(ob)
        return ob

    slope = math.degrees(math.atan((CAB_FRONT - WS_TOP[0]) / (WS_TOP[1] - WS_KNEE_Y)))
    # windscreen (tilted with the slope so the opening edge is even)
    cutter((0, 1.99, ws_z(1.99)), (2.16, 0.78, 0.4), (-slope, 0, 0), 0.07)
    # door windows, both sides
    for sx in (1, -1):
        cutter((sx * CAB_W, 1.96, 3.95), (0.4, 0.8, 1.15), (0, 0, 0), 0.06)
    # rear window
    cutter((0, 2.02, CAB_REAR), (1.0, 0.42, 0.3), (0, 0, 0), 0.05)

    mod = shell.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.operand_type = "COLLECTION"
    mod.collection = cutters
    mod.solver = "EXACT"
    bm_cut = evaluated_bmesh(shell)
    # back to Godot frame for Out.add
    res = bmesh.new()
    inv = {v: res.verts.new((v.co.x, v.co.z, -v.co.y)) for v in bm_cut.verts}
    for f in bm_cut.faces:
        try:
            res.faces.new([inv[v] for v in f.verts])
        except ValueError:
            pass
    bm_cut.free()
    for ob in list(cutters.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.collections.remove(cutters)
    bpy.data.objects.remove(shell, do_unlink=True)
    return res, before


body = Out("Body")
glass = Out("Glass")
lamps = {k: Out("Lamp_" + k) for k in ("head", "brake", "reverse", "ind_l", "ind_r", "marker")}

shell_bm, _ = build_cab_shell()
body.add(shell_bm, M["cab"])

# ---- cab paint stripes and panel details
for sx in (1, -1):
    x = sx * (CAB_W + 0.004)
    box(body, M["cab_yellow"], (x, 1.30, 3.62), (0.01, 0.12, 1.9))
    box(body, M["cab_green"], (x, 1.16, 3.62), (0.01, 0.07, 1.9))
    box(body, M["cab_yellow"], (x, 1.06, 3.62), (0.01, 0.03, 1.9))
    # door shut lines
    box(body, M["black"], (x, 1.45, 4.62), (0.008, 1.85, 0.012))
    box(body, M["black"], (x, 1.45, 3.05), (0.008, 1.85, 0.012))
    box(body, M["black"], (x, 0.53, 3.84), (0.008, 0.012, 1.58))
    # door handle, lock, hinges
    box(body, M["chrome"], (sx * (CAB_W + 0.02), 1.47, 3.2), (0.03, 0.04, 0.2), bevel=0.012)
    cyl(body, M["chrome"], (sx * (CAB_W + 0.012), 1.47, 3.36), 0.016, 0.016, 0.02, 10, (0, 0, 90))
    for y in (0.85, 2.05):
        box(body, M["black"], (sx * (CAB_W + 0.012), y, 4.58), (0.025, 0.12, 0.06), bevel=0.01)
    # grab handle at the rear corner of the cab
    cyl(body, M["chrome"], (sx * (CAB_W + 0.05), 1.4, 2.7), 0.016, 0.016, 1.0, 10)
    for y in (0.92, 1.88):
        box(body, M["chrome"], (sx * (CAB_W + 0.025), y, 2.7), (0.05, 0.03, 0.03))
    # two-step entry ladder behind the front wheel
    for (y, z0) in ((0.06, 2.72), (0.34, 2.70)):
        box(body, M["tread"], (sx * 1.08, y, z0), (0.36, 0.035, 0.26), bevel=0.01)
        box(body, M["chassis"], (sx * 0.92, y - 0.06, z0), (0.04, 0.12, 0.26))
    box(body, M["chassis"], (sx * 1.24, 0.2, 2.71), (0.03, 0.42, 0.2))
    # front wheel arch (black plastic) and inner mud flap
    arc(body, M["black"], (sx * 1.0, -0.25, 3.4), 0.6, 0.64, 0.42, 15, 165, 14)
    box(body, M["rubber"], (sx * 1.0, -0.38, 2.74), (0.42, 0.62, 0.015))
    box(body, M["reflector"], (sx * 1.0, -0.6, 2.731), (0.3, 0.06, 0.004))
    # side indicator repeater housing
    box(body, M["black"], (sx * (CAB_W + 0.01), 1.25, 4.42), (0.02, 0.1, 0.18), bevel=0.01)
    box(lamps["ind_l" if sx > 0 else "ind_r"], M["lamp"], (sx * (CAB_W + 0.025), 1.25, 4.42), (0.012, 0.07, 0.14))

    # ---- mirrors: arm, main mirror, convex spotter mirror
    mx = sx * 1.6
    cyl(body, M["black"], (sx * 1.40, 2.28, 4.52), 0.018, 0.018, 0.4, 8, (0, 0, 90))
    cyl(body, M["black"], (sx * 1.40, 1.66, 4.52), 0.018, 0.018, 0.4, 8, (0, 0, 90))
    box(body, M["black"], (sx * 1.25, 2.28, 4.52), (0.03, 0.06, 0.08))
    box(body, M["black"], (sx * 1.25, 1.66, 4.52), (0.03, 0.06, 0.08))
    cyl(body, M["black"], (mx, 1.97, 4.52), 0.016, 0.016, 0.62, 8)
    box(body, M["black"], (mx, 2.0, 4.54), (0.1, 0.5, 0.26), bevel=0.03)
    box(body, M["mirror"], (mx, 2.0, 4.405), (0.075, 0.44, 0.012))
    sphere(body, M["black"], (mx, 1.72, 4.6), (0.08, 0.08, 0.05))
    sphere(body, M["mirror"], (mx, 1.72, 4.555), (0.065, 0.065, 0.012))

# ---- front face: grille, lamps, bumper, crown board
FRONT = CAB_FRONT + 0.005
box(body, M["black"], (0, 1.12, FRONT), (1.5, 0.56, 0.03), bevel=0.012)
for i in range(6):
    box(body, M["chrome"], (0, 0.88 + i * 0.095, FRONT + 0.02), (1.44, 0.022, 0.018), bevel=0.006)
box(body, M["chrome"], (0, 1.12, FRONT + 0.003), (1.56, 0.62, 0.006))
box(body, M["cab_yellow"], (0, 1.47, FRONT + 0.008), (2.3, 0.05, 0.008))
for sx in (1, -1):
    box(body, M["chrome"], (sx * 0.86, 0.70, FRONT + 0.01), (0.46, 0.26, 0.03), bevel=0.012)
    box(lamps["head"], M["lamp"], (sx * 0.86, 0.70, FRONT + 0.03), (0.40, 0.2, 0.015))
    box(body, M["black"], (sx * 1.13, 0.70, FRONT + 0.01), (0.14, 0.2, 0.03), bevel=0.008)
    box(lamps["ind_l" if sx > 0 else "ind_r"], M["lamp"], (sx * 1.13, 0.70, FRONT + 0.03), (0.11, 0.16, 0.012))
# bumper with fog lamps, tow hooks and number plate
box(body, M["bumper"], (0, 0.34, 4.92), (2.5, 0.32, 0.22), bevel=0.04, seg=3)
box(body, M["black"], (0, 0.2, 5.035), (2.3, 0.03, 0.01))
for sx in (1, -1):
    cyl(body, M["chrome"], (sx * 0.78, 0.36, 5.03), 0.075, 0.075, 0.04, 16, (90, 0, 0))
    cyl(body, M["lamp"], (sx * 0.78, 0.36, 5.052), 0.06, 0.06, 0.01, 16, (90, 0, 0))
    box(body, M["chassis"], (sx * 0.45, 0.14, 5.02), (0.08, 0.06, 0.12))
box(body, M["plate"], (0, 0.34, 5.035), (0.62, 0.17, 0.012))
# crown board above the windscreen (painted name board) and roof markers
box(body, M["cab_yellow"], (0, 2.66, 4.72), (2.5, 0.3, 0.24), bevel=0.03)
box(body, M["cab_green"], (0, 2.52, 4.842), (2.44, 0.03, 0.008))
box(body, M["cab_green"], (0, 2.80, 4.842), (2.44, 0.03, 0.008))
for i in range(6):
    x = -1.0 + i * 0.4
    box(body, M["black"], (x, 2.835, 4.75), (0.14, 0.03, 0.1))
    box(lamps["marker"], M["lamp"], (x, 2.865, 4.75), (0.12, 0.05, 0.08), bevel=0.01)
# sun visor strip inside the top of the windscreen
box(body, M["black"], (0, 2.36, ws_z(2.36) - 0.05), (2.2, 0.06, 0.04))
# roof air horns (chrome trumpets)
for i, x in enumerate((-0.22, 0.22)):
    length = 0.55 + i * 0.18
    cyl(body, M["chrome"], (x, 2.64, 3.9 + length / 2 - 0.3), 0.025, 0.1, length, 14, (90, 0, 0), caps=False)
    box(body, M["black"], (x, 2.585, 3.8), (0.06, 0.05, 0.12))
# roof hatch
box(body, M["cab"], (0.3, 2.565, 3.4), (0.7, 0.03, 0.6), bevel=0.02)

# ---- wipers (separate objects, pivot at origin)
wipers = []
for (name, px) in (("Wiper_L", 0.55), ("Wiper_R", -0.36)):
    py = 1.63
    w = Out(name, (px, py, ws_z(py) + 0.03))
    slope_deg = math.degrees(math.atan((CAB_FRONT - WS_TOP[0]) / (WS_TOP[1] - WS_KNEE_Y)))
    # arm lies on the glass, pointing towards the truck's right (-X) and slightly up
    cyl(w, M["black"], (px, py, ws_z(py) + 0.03), 0.025, 0.025, 0.03, 10, (90 - slope_deg, 0, 0))
    box(w, M["black"], (px - 0.3, py + 0.06, ws_z(py + 0.06) + 0.035), (0.6, 0.018, 0.012), (-slope_deg, 0, -10))
    box(w, M["rubber"], (px - 0.36, py + 0.07, ws_z(py + 0.07) + 0.02), (0.68, 0.02, 0.02), (-slope_deg, 0, -10))
    wipers.append(w)

# ---- glass panes
slope = math.degrees(math.atan((CAB_FRONT - WS_TOP[0]) / (WS_TOP[1] - WS_KNEE_Y)))
box(glass, M["glass"], (0, 1.99, ws_z(1.99) - 0.022), (2.18, 0.8, 0.008), (-slope, 0, 0))
for sx in (1, -1):
    box(glass, M["glass"], (sx * (CAB_W - 0.022), 1.96, 3.95), (0.008, 0.82, 1.17))
box(glass, M["glass"], (0, 2.02, CAB_REAR + 0.022), (1.02, 0.44, 0.008))

# ================================================================== INTERIOR
box(body, M["rubber"], (0, CAB_BOTTOM + 0.05, 3.72), (2.3, 0.02, 2.0))
box(body, M["trim"], (0, CAB_ROOF - 0.07, 3.6), (2.3, 0.02, 1.9))                 # headliner
box(body, M["trim"], (0, 1.45, CAB_REAR + 0.06), (2.3, 1.7, 0.02))                # rear wall trim
box(body, M["dash"], (0, 0.80, 3.88), (0.72, 0.56, 1.05), bevel=0.08)             # engine cover
box(body, M["rubber"], (0, 1.085, 3.88), (0.6, 0.012, 0.9))
# dashboard
box(body, M["dash"], (0, 1.34, 4.57), (2.32, 0.36, 0.42), bevel=0.05)
box(body, M["dash"], (0, 1.06, 4.62), (2.2, 0.3, 0.3), bevel=0.03)
box(body, M["dash"], (-0.55, 1.60, 4.34), (0.62, 0.16, 0.26), bevel=0.05)          # gauge hood
box(body, M["gauge"], (-0.55, 1.57, 4.215), (0.52, 0.12, 0.01))
for gx in (-0.72, -0.38):
    cyl(body, M["chrome"], (gx, 1.57, 4.208), 0.055, 0.055, 0.006, 20, (90, 0, 0))
    cyl(body, M["gauge"], (gx, 1.57, 4.203), 0.048, 0.048, 0.004, 20, (90, 0, 0))
box(body, M["dash"], (0.0, 1.0, 4.3), (0.4, 0.4, 0.2), (-25, 0, 0), bevel=0.03)   # centre console
for i in range(3):
    box(body, M["gauge"], (-0.1 + i * 0.1, 1.08, 4.215), (0.06, 0.04, 0.01), (-25, 0, 0))
# steering column (the turning wheel itself is built in Godot)
cyl(body, M["dash"], (-0.55, 1.42, 4.33), 0.045, 0.045, 0.45, 12, (-60, 0, 0))
# pedals
for (px, w_) in ((-0.78, 0.08), (-0.58, 0.12), (-0.36, 0.08)):
    box(body, M["rubber"], (px, 0.68, 4.42), (w_, 0.14, 0.02), (-30, 0, 0))
# gear lever and hand brake beside the driver
cyl(body, M["chrome"], (-0.2, 1.25, 3.78), 0.012, 0.012, 0.36, 8, (12, 0, 0))
sphere(body, M["dash"], (-0.2, 1.44, 3.82), (0.04, 0.04, 0.04))
box(body, M["rubber"], (-0.2, 1.1, 3.75), (0.12, 0.04, 0.12), bevel=0.02)
cyl(body, M["chassis"], (-0.25, 1.12, 3.45), 0.015, 0.015, 0.25, 8, (-20, 0, 0))
# seats: driver on the right (-X), two-person bench on the left
box(body, M["chassis"], (-0.55, 0.72, 3.38), (0.32, 0.4, 0.32))
box(body, M["seat"], (-0.55, 0.98, 3.38), (0.56, 0.14, 0.56), bevel=0.05)
box(body, M["seat"], (-0.55, 1.42, 3.04), (0.56, 0.78, 0.13), (-8, 0, 0), bevel=0.05)
box(body, M["seat"], (-0.55, 1.92, 2.98), (0.3, 0.18, 0.1), (-8, 0, 0), bevel=0.04)
box(body, M["chassis"], (0.62, 0.72, 3.36), (0.8, 0.4, 0.4))
box(body, M["seat"], (0.62, 0.98, 3.36), (0.9, 0.14, 0.56), bevel=0.05)
box(body, M["seat"], (0.62, 1.4, 3.03), (0.9, 0.72, 0.13), (-8, 0, 0), bevel=0.05)
# door trims, window winders and armrests
for sx in (1, -1):
    x = sx * (CAB_W - 0.06)
    box(body, M["trim"], (x, 1.0, 3.83), (0.02, 0.95, 1.5))
    box(body, M["dash"], (sx * (CAB_W - 0.09), 1.2, 3.8), (0.05, 0.05, 0.4), bevel=0.02)
    cyl(body, M["chrome"], (sx * (CAB_W - 0.09), 1.05, 3.5), 0.03, 0.03, 0.02, 10, (0, 0, 90))
    box(body, M["dash"], (sx * 0.55, 2.38, ws_z(2.38) - 0.14), (0.62, 0.02, 0.22), (20, 0, 0))   # sun visors
    box(body, M["dash"], (sx * (CAB_W - 0.08), 2.0, ws_z(2.0) - 0.12), (0.04, 0.9, 0.06), (-10, 0, 0))  # A-pillar trim
cyl(body, M["chrome"], (0, 2.47, 3.6), 0.07, 0.07, 0.03, 16)                         # dome lamp
# windscreen tassels (classic Indian lorry decoration)
tassels = [M["tassel_r"], M["tassel_y"], M["tassel_g"], M["tassel_b"]]
for i in range(14):
    y = 2.30
    box(body, tassels[i % 4], (-1.04 + i * 0.16, y, ws_z(y) - 0.06), (0.1, 0.12, 0.012))
box(body, M["tassel_r"], (0, 2.37, ws_z(2.37) - 0.06), (2.2, 0.015, 0.015))

# ================================================================== CHASSIS AND RUNNING GEAR
AXLE_Y = -0.25
for sx in (1, -1):
    box(body, M["chassis"], (sx * 0.45, 0.0, -0.1), (0.09, 0.28, 9.2), bevel=0.01)
    box(body, M["chassis"], (sx * 0.405, 0.125, -0.1), (0.08, 0.03, 9.2))
    box(body, M["chassis"], (sx * 0.405, -0.125, -0.1), (0.08, 0.03, 9.2))
for z in (4.4, 2.45, 0.6, -0.9, -2.45, -3.75, -4.6):
    box(body, M["chassis"], (0, 0.0, z), (0.82, 0.2, 0.1))
# engine and gearbox under the cab
box(body, M["chassis"], (0, 0.05, 3.7), (0.72, 0.6, 1.2), bevel=0.06)
box(body, M["alu"], (0, 0.38, 3.7), (0.5, 0.08, 0.9), bevel=0.02)
box(body, M["chassis"], (0, -0.02, 2.85), (0.46, 0.42, 0.55), bevel=0.05)
cyl(body, M["chassis"], (0, -0.12, 0.4), 0.05, 0.05, 4.7, 10, (88, 0, 0))          # propeller shaft
cyl(body, M["chassis"], (0, -0.2, -2.45), 0.05, 0.05, 1.3, 10, (90, 0, 0))
# front axle beam and leaf springs
box(body, M["chassis"], (0, AXLE_Y + 0.04, 3.4), (1.65, 0.12, 0.12), bevel=0.02)


for sx in (1, -1):
    for zc, length in ((3.4, 1.5), (-2.45, 2.4)):
        for i in range(5):
            half = length / 2 * (1.0 - i * 0.14)
            pts = []
            for k in range(9):
                t = -1.0 + 2.0 * k / 8
                pts.append((zc + t * half, -0.15 - i * 0.018 - 0.05 * (1 - t * t)))
            bm = bmesh.new()
            rows = []
            for (z, y) in pts:
                rows.append([bm.verts.new((sx * 0.45 + x, y + dy, z)) for (x, dy) in ((-0.04, 0), (0.04, 0), (0.04, 0.016), (-0.04, 0.016))])
            for a_, b_ in zip(rows, rows[1:]):
                for j in range(4):
                    j2 = (j + 1) % 4
                    bm.faces.new((a_[j], a_[j2], b_[j2], b_[j]))
            bm.faces.new(rows[0])
            bm.faces.new(rows[-1][::-1])
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            body.add(bm, M["chassis"])
        box(body, M["chassis"], (sx * 0.45, -0.24, zc), (0.12, 0.05, 0.16))
# rear axles with differentials and hub reduction drums
for z in (-1.8, -3.1):
    cyl(body, M["chassis"], (0, AXLE_Y, z), 0.11, 0.11, 1.62, 14, (0, 0, 90))
    sphere(body, M["chassis"], (0, AXLE_Y, z), (0.24, 0.24, 0.26), 16, 10)
    cyl(body, M["chassis"], (0, AXLE_Y, z + (0.22 if z > -2.5 else -0.22)), 0.09, 0.07, 0.2, 12, (90, 0, 0))
cyl(body, M["chassis"], (0, AXLE_Y + 0.05, -2.45), 0.05, 0.05, 1.2, 10, (90, 0, 0))
# diesel tank (left), battery box and toolbox (right), air tanks
cyl(body, M["alu"], (0.93, 0.02, 1.3), 0.3, 0.3, 1.2, 24, (90, 0, 0))
for z in (0.9, 1.7):
    cyl(body, M["black"], (0.93, 0.02, z), 0.305, 0.305, 0.05, 24, (90, 0, 0), caps=False)
cyl(body, M["black"], (0.93, 0.34, 1.1), 0.06, 0.06, 0.05, 14)
box(body, M["chassis"], (0.62, 0.02, 1.3), (0.26, 0.08, 0.9))
box(body, M["black"], (-0.95, 0.06, 1.55), (0.42, 0.42, 0.72), bevel=0.03)
box(body, M["tread"], (-0.95, 0.285, 1.55), (0.44, 0.02, 0.74))
box(body, M["post"], (-0.98, 0.16, -0.3), (0.36, 0.44, 0.9), bevel=0.02)
box(body, M["chrome"], (-1.165, 0.22, -0.3), (0.01, 0.05, 0.16))
for sx in (1, -1):
    cyl(body, M["chassis"], (sx * 0.8, -0.02, 0.15 if sx > 0 else 0.55), 0.13, 0.13, 0.85, 16, (90, 0, 0))
# spare wheel carrier under the rear overhang
lathe(body, M["rubber"], [(0.3, -0.13), (0.48, -0.15), (0.52, -0.1), (0.52, 0.1), (0.48, 0.15), (0.3, 0.13)], 24,
      xform((0, 0, 90), (0, -0.05, -4.1)))
cyl(body, M["rim"], (0, -0.05, -4.1), 0.3, 0.3, 0.2, 20)
box(body, M["chassis"], (0, 0.12, -4.1), (0.95, 0.06, 0.08))
# exhaust stack (driver side) and air intake (left) behind the cab
cyl(body, M["chrome"], (-1.04, 1.35, 2.42), 0.065, 0.065, 2.3, 16)
cyl(body, M["alu"], (-1.04, 1.9, 2.42), 0.095, 0.095, 0.9, 16, caps=False)
cyl(body, M["black"], (-1.04, 2.52, 2.42), 0.07, 0.07, 0.04, 16)
cyl(body, M["chassis"], (1.04, 1.5, 2.42), 0.1, 0.1, 2.1, 16)
cyl(body, M["chassis"], (1.04, 2.6, 2.42), 0.16, 0.16, 0.1, 16)
sphere(body, M["chassis"], (1.04, 2.66, 2.42), (0.16, 0.06, 0.16))
for sx in (1, -1):
    box(body, M["chassis"], (sx * 0.85, 0.3, 2.42), (0.38, 0.05, 0.05))
# side under-run guards and rear mudguards
for sx in (1, -1):
    for y in (0.12, 0.34):
        box(body, M["cab_yellow"], (sx * 1.23, y, 0.65), (0.03, 0.08, 3.6), bevel=0.01)
    for z in (2.3, 0.65, -1.0):
        box(body, M["chassis"], (sx * 1.12, 0.3, z), (0.2, 0.42, 0.05))
    for z in (-1.8, -3.1):
        arc(body, M["black"], (sx * 0.95, AXLE_Y, z), 0.61, 0.64, 0.66, 25, 155, 12)
    box(body, M["black"], (sx * 0.95, 0.39, -2.45), (0.66, 0.03, 0.42))
    # rear mud flaps with a reflector
    box(body, M["rubber"], (sx * 0.95, -0.2, -3.82), (0.58, 0.82, 0.015))
    box(body, M["reflector"], (sx * 0.95, -0.52, -3.83), (0.4, 0.07, 0.004))
    box(body, M["chassis"], (sx * 0.95, 0.24, -3.8), (0.62, 0.05, 0.05))

# ================================================================== CARGO BODY (wooden high-side)
B_REAR, B_FRONT = -4.6, 2.2
B_LEN = B_FRONT - B_REAR
B_MID = (B_FRONT + B_REAR) / 2
FLOOR_Y = 0.5
TOP_Y = 2.1
# sub-frame long members and cross bearers
for sx in (1, -1):
    box(body, M["chassis"], (sx * 0.45, 0.2, B_MID), (0.1, 0.12, B_LEN))
z = B_REAR + 0.1
while z < B_FRONT:
    box(body, M["post"], (0, 0.40, z), (2.48, 0.1, 0.08))
    z += 0.55
box(body, M["deck"], (0, FLOOR_Y, B_MID), (2.5, 0.08, B_LEN))
# side walls: green kick plank, yellow boards, red top band
for sx in (1, -1):
    x = sx * 1.22
    box(body, M["body_green"], (x, 0.66, B_MID), (0.05, 0.24, B_LEN - 0.04), bevel=0.01)
    box(body, M["body_yellow"], (x, 1.33, B_MID), (0.05, 1.06, B_LEN - 0.04), bevel=0.01)
    box(body, M["body_red"], (x, 1.98, B_MID), (0.05, 0.22, B_LEN - 0.04), bevel=0.01)
    box(body, M["body_blue"], (sx * 1.247, 1.62, B_MID), (0.006, 0.05, B_LEN - 0.3))
    box(body, M["post"], (sx * 1.25, TOP_Y + 0.02, B_MID), (0.06, 0.05, B_LEN + 0.04), bevel=0.01)
    box(body, M["post"], (sx * 1.25, 0.53, B_MID), (0.06, 0.1, B_LEN + 0.04), bevel=0.01)
    for zp in (B_REAR + 0.02, -3.25, -1.9, -0.55, 0.8, B_FRONT - 0.02):
        box(body, M["post"], (sx * 1.255, 1.32, zp), (0.05, 1.62, 0.08), bevel=0.01)
    # rope hooks along the lower rail
    zh = B_REAR + 0.35
    while zh < B_FRONT - 0.2:
        box(body, M["chrome"], (sx * 1.29, 0.5, zh), (0.02, 0.06, 0.05))
        zh += 0.62
# headboard (front wall) and the decorated canopy over the cab roof
box(body, M["body_yellow"], (0, 1.45, B_FRONT - 0.03), (2.5, 1.9, 0.06), bevel=0.01)
box(body, M["body_red"], (0, 2.3, B_FRONT - 0.025), (2.5, 0.16, 0.07))
for sx in (1, -1):
    box(body, M["post"], (sx * 1.25, 1.5, B_FRONT), (0.07, 2.0, 0.1), bevel=0.01)
bm = bmesh.new()  # wedge canopy: flat bottom over the cab roof, sloped top
prof = [(B_FRONT - 0.06, 2.42), (3.0, 2.6), (3.0, 2.68), (B_FRONT - 0.06, 2.8)]
L = [bm.verts.new((1.25, y, zz)) for (zz, y) in prof]
R = [bm.verts.new((-1.25, y, zz)) for (zz, y) in prof]
bm.faces.new(L)
bm.faces.new(R[::-1])
for i in range(4):
    i2 = (i + 1) % 4
    bm.faces.new((L[i2], L[i], R[i], R[i2]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.02, segments=2, affect="EDGES", profile=0.5, clamp_overlap=True)
body.add(bm, M["body_red"])
box(body, M["body_yellow"], (0, 2.64, 3.02), (2.4, 0.06, 0.02))
for i in range(5):
    box(body, M["body_green"] if i % 2 else M["body_blue"], (-0.96 + i * 0.48, 2.64, 3.032), (0.2, 0.04, 0.006))
# tailgate with hinges and chains
box(body, M["body_yellow"], (0, 1.32, B_REAR + 0.01), (2.42, 1.56, 0.06), bevel=0.01)
box(body, M["body_red"], (0, 1.98, B_REAR - 0.025), (2.42, 0.2, 0.012))
box(body, M["body_green"], (0, 0.66, B_REAR - 0.025), (2.42, 0.2, 0.012))
for x in (-0.8, 0.0, 0.8):
    cyl(body, M["chrome"], (x, 0.55, B_REAR - 0.03), 0.025, 0.025, 0.18, 10, (0, 0, 90))
for sx in (1, -1):
    for k in range(5):
        box(body, M["chrome"], (sx * 1.18, 2.05 - k * 0.07, B_REAR - 0.06 - (k % 2) * 0.01), (0.02, 0.05, 0.02))
# rear light bar, under-run bar, plate
box(body, M["chassis"], (0, 0.25, -4.64), (2.36, 0.2, 0.06))
for i in range(10):
    box(body, M["reflector"] if i % 2 == 0 else M["white"], (-1.035 + i * 0.23, 0.0, -4.69), (0.23, 0.12, 0.06))
for sx in (1, -1):
    box(body, M["chassis"], (sx * 0.45, 0.1, -4.66), (0.08, 0.2, 0.08))
box(body, M["plate"], (0, 0.25, -4.68), (0.6, 0.16, 0.012))
for sx in (1, -1):
    box(body, M["black"], (sx * 0.86, 0.25, -4.672), (0.42, 0.18, 0.02))
    box(lamps["brake"], M["lamp"], (sx * 0.95, 0.25, -4.69), (0.22, 0.14, 0.02))
    box(lamps["reverse"], M["lamp"], (sx * 0.72, 0.25, -4.69), (0.12, 0.12, 0.02))
    box(lamps["ind_l" if sx > 0 else "ind_r"], M["lamp"], (sx * 1.13, 0.25, -4.69), (0.12, 0.14, 0.02))
    box(lamps["marker"], M["lamp"], (sx * 1.24, 2.05, B_REAR - 0.04), (0.04, 0.08, 0.03))
    box(lamps["marker"], M["lamp"], (sx * 1.285, 0.66, -1.2), (0.01, 0.06, 0.1))

# ================================================================== WHEELS
TYRE_PROFILE = [(0.29, -0.14), (0.47, -0.15), (0.505, -0.135), (0.515, -0.11), (0.515, 0.11), (0.505, 0.135), (0.47, 0.15), (0.29, 0.14)]


def tyre(out, x_off, width):
    s = width / 0.30
    lathe(out, M["rubber"], [(r, x * s) for (r, x) in TYRE_PROFILE], 36, Matrix.Translation((x_off, 0, 0)))
    # tread lugs in two staggered rows
    for i in range(30):
        a = 360.0 * i / 30
        for row in (-1, 1):
            aa = (a + (6 if row > 0 else 0)) * D2R
            c = (x_off + row * width * 0.22, 0.512 * math.cos(aa), 0.512 * math.sin(aa))
            box(out, M["rubber"], c, (width * 0.36, 0.016, 0.055), (math.degrees(-aa), 0, 0))


def rim(out, face_x, dual):
    sgn = 1.0
    prof = [(0.30, face_x - 0.12), (0.31, face_x - 0.005), (0.29, face_x + 0.005), (0.2, face_x - 0.02),
            (0.13, face_x + 0.02), (0.08, face_x + 0.02), (0.08, face_x - 0.03), (0.28, face_x - 0.13)]
    lathe(out, M["rim"], prof, 32)
    cyl(out, M["chrome"], (face_x + 0.03 * sgn, 0, 0), 0.075, 0.06, 0.06, 16, (0, 0, -90))
    for i in range(10):
        a = 2 * math.pi * i / 10
        cyl(out, M["chrome"], (face_x + 0.03, 0.16 * math.cos(a), 0.16 * math.sin(a)), 0.016, 0.016, 0.03, 6, (0, 0, -90))
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        cyl(out, M["black"], (face_x - 0.008, 0.235 * math.cos(a), 0.235 * math.sin(a)), 0.03, 0.03, 0.006, 10, (0, 0, -90))


wheel_single = Out("WheelSingle")
tyre(wheel_single, 0.0, 0.30)
rim(wheel_single, 0.12, False)
wheel_dual = Out("WheelDual")
for off in (-0.155, 0.155):
    tyre(wheel_dual, off, 0.28)
rim(wheel_dual, 0.27, True)
lathe(wheel_dual, M["rim"], [(0.29, -0.28), (0.3, 0.13), (0.29, 0.13), (0.28, -0.28)], 24)

# ================================================================== finish and export
objects = [body.finish(), glass.finish()]
objects += [o.finish() for o in lamps.values()]
objects += [w.finish() for w in wipers]
ws = wheel_single.finish()
wd = wheel_dual.finish()
# park the wheel templates far below so previews do not show them; Godot reads only the mesh
for o in (ws, wd):
    o.location = (0, 0, -20)

stats = {}
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        stats[o.name] = sum(len(p.vertices) - 2 for p in o.data.polygons)
print("TRIANGLES", stats, "TOTAL", sum(stats.values()))

os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
for o in (ws, wd):
    o.location = (0, 0, 0)
bpy.ops.export_scene.gltf(
    filepath=OUT_PATH,
    export_format="GLTF_SEPARATE",
    export_texture_dir="textures",
    export_yup=True,
    export_apply=True,
    export_tangents=True,
    export_cameras=False,
    export_lights=False,
    export_image_format="AUTO",
)
print("EXPORTED", OUT_PATH)

# ================================================================== optional preview renders
if PREVIEW:
    for o in (ws, wd):
        o.hide_render = True
    # place preview wheels at the real wheel positions
    for (x, z, dual) in ((1.0, 3.4, False), (-1.0, 3.4, False), (0.95, -1.8, True), (-0.95, -1.8, True), (0.95, -3.1, True), (-0.95, -3.1, True)):
        src = wd if dual else ws
        inst = bpy.data.objects.new("pv", src.data)
        inst.location = g2b((x, AXLE_Y, z))
        if x < 0:
            inst.rotation_euler = (0, 0, math.pi)
        bpy.context.scene.collection.objects.link(inst)
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.68, 0.85, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scene.collection.objects.link(sun)
    ground = Out("ground")
    box(ground, M["bumper"], (0, -0.79, 0), (40, 0.02, 40))
    ground.finish()
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 35
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {
        "front": ((7.5, 1.6, 11.5), (0, 0.9, 1.5)),
        "rear": ((-6.5, 2.2, -12.0), (0, 0.9, -1.0)),
        "side": ((12.5, 1.0, 0.0), (0, 0.9, 0.0)),
        "cockpit": ((-0.55, 2.05, 3.35), (-0.3, 1.6, 6.0)),
        "under": ((5.0, -0.45, -0.5), (0, -0.1, -1.0)),
    }
    gl = bpy.data.objects.get("Glass")
    for name, (eye, target) in views.items():
        if gl:
            gl.hide_render = name == "cockpit"
        e, t = g2b(eye), g2b(target)
        cam.location = e
        cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 18 if name == "cockpit" else 35
        scene.render.filepath = PREVIEW + "_" + name + ".png"
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", scene.render.filepath)
