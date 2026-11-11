class_name DashboardPhoto
extends Node3D
## Framed Lord Murugan photograph on the truck dashboard, with glass, a marigold
## garland and an optional Vel and flowers. It is a child of the truck, so it stays
## fixed to the dashboard while driving, braking, turning and after getting out.
##
## Image source, in order: the player's imported photo (user://cabin_photo.png),
## then the bundled freely licensed default (res://assets/cabin/murugan_default.jpg).

const DEFAULT_IMAGE := "res://assets/cabin/murugan_default.jpg"
const USER_IMAGE := "user://cabin_photo.png"
const PHOTO_HEIGHT := 0.22

## Positions on the dashboard (truck local space; the driver sits at x = -0.55).
const SLOTS := {
	"centre": Vector3(-0.02, 1.53, 4.52),
	"driver_side": Vector3(-1.0, 1.53, 4.55),
	"passenger_side": Vector3(0.55, 1.53, 4.52),
}
const SLOT_LABELS := {"centre": "Centre of dashboard", "driver_side": "Driver side, near the pillar", "passenger_side": "Passenger side"}
const FRAMES := {
	"gold": Color(0.93, 0.72, 0.25),
	"wood": Color(0.42, 0.24, 0.12),
	"silver": Color(0.8, 0.8, 0.82),
	"red": Color(0.65, 0.08, 0.06),
}

var image_size := Vector2i.ZERO
var source := ""
var _photo: MeshInstance3D
var _glass: MeshInstance3D
var _frame: MeshInstance3D
var _extras: MeshInstance3D


func _ready() -> void:
	name = "DashboardPhoto"
	rebuild()


## Re-reads settings and rebuilds the frame. Cheap; called when settings change.
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var slot: String = GameConfig.settings.get("cabin_photo_slot", "centre")
	position = SLOTS.get(slot, SLOTS["centre"])
	rotation = Vector3(deg_to_rad(-14.0), PI, 0.0)  # faces the driver, tilted back
	var tex := _load_texture()
	var aspect := 0.75
	if tex != null:
		aspect = float(image_size.x) / float(maxi(1, image_size.y))
	var h := PHOTO_HEIGHT
	var w := clampf(h * aspect, 0.06, 0.3)
	var lift := h * 0.5 + 0.03
	# photo
	_photo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	_photo.mesh = q
	var m := StandardMaterial3D.new()
	if tex != null:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m.albedo_color = Color(0.15, 0.1, 0.08)
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.12  # stays readable in a dark cabin
	_photo.material_override = m
	_photo.position = Vector3(0, lift, 0)
	_photo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_photo)
	# glass over the photo
	_glass = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(w, h)
	_glass.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.9, 0.95, 1.0, 0.08)
	gm.roughness = 0.03
	gm.metallic = 0.2
	gm.metallic_specular = 1.0
	_glass.material_override = gm
	_glass.position = Vector3(0, lift, 0.004)
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)
	# frame, back board and stand
	var style: String = GameConfig.settings.get("cabin_photo_frame", "gold")
	var fc: Color = FRAMES.get(style, FRAMES["gold"])
	var b := MeshBatcher.new()
	var t := 0.014
	b.add_box(Transform3D(Basis(), Vector3(0, lift + h * 0.5 + t * 0.5, 0.002)), Vector3(w + t * 2.0, t, 0.012), fc)
	b.add_box(Transform3D(Basis(), Vector3(0, lift - h * 0.5 - t * 0.5, 0.002)), Vector3(w + t * 2.0, t, 0.012), fc)
	b.add_box(Transform3D(Basis(), Vector3(-w * 0.5 - t * 0.5, lift, 0.002)), Vector3(t, h, 0.012), fc)
	b.add_box(Transform3D(Basis(), Vector3(w * 0.5 + t * 0.5, lift, 0.002)), Vector3(t, h, 0.012), fc)
	b.add_box(Transform3D(Basis(), Vector3(0, lift, -0.005)), Vector3(w + t * 2.0, h + t * 2.0, 0.006), Color(0.2, 0.12, 0.08))
	b.add_box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, lift - h * 0.15, -0.03)), Vector3(0.03, h * 0.7, 0.006), Color(0.2, 0.12, 0.08))
	b.add_box(Transform3D(Basis(), Vector3(0, 0.012, 0)), Vector3(w + 0.04, 0.024, 0.07), fc.darkened(0.3))
	# marigold garland: along the top, drooping down both sides
	var n := 13
	for i in range(n):
		var u := float(i) / float(n - 1)
		var x := lerpf(-w * 0.5 - t, w * 0.5 + t, u)
		var y := lift + h * 0.5 + t - sin(u * PI) * 0.012
		var col := Color(1.0, 0.5, 0.0) if i % 2 == 0 else Color(1.0, 0.82, 0.1)
		b.add_ellipsoid(Transform3D(Basis(), Vector3(x, y, 0.012)), Vector3(0.011, 0.011, 0.011), col, 3, 6)
	for sx in [-1.0, 1.0]:
		for i in range(7):
			var y2 := lift + h * 0.5 - 0.02 - i * 0.022
			var col2 := Color(1.0, 0.5, 0.0) if i % 2 == 0 else Color(1.0, 0.82, 0.1)
			b.add_ellipsoid(Transform3D(Basis(), Vector3(sx * (w * 0.5 + t + 0.004), y2, 0.012)), Vector3(0.01, 0.01, 0.01), col2, 3, 6)
		b.add_ellipsoid(Transform3D(Basis(), Vector3(sx * (w * 0.5 + t + 0.004), lift - h * 0.5 - 0.02, 0.014)), Vector3(0.008, 0.012, 0.004), Color(0.1, 0.45, 0.15), 3, 5)
	_frame = MeshKit.mesh_instance(self, b.commit())
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# optional Vel and flowers beside the photo
	if bool(GameConfig.settings.get("cabin_photo_extras", true)):
		var e := MeshBatcher.new()
		var vx := w * 0.5 + 0.07
		var gold := Color(0.95, 0.72, 0.2)
		e.add_box(Transform3D(Basis(), Vector3(vx, 0.015, 0)), Vector3(0.05, 0.03, 0.05), Color(0.35, 0.18, 0.08))
		e.add_cylinder(Transform3D(Basis(), Vector3(vx, 0.16, 0)), 0.006, 0.006, 0.26, 6, gold)
		e.add_cylinder(Transform3D(Basis(), Vector3(vx, 0.29, 0)), 0.02, 0.0, 0.015, 6, gold)
		e.add_ellipsoid(Transform3D(Basis(), Vector3(vx, 0.33, 0)), Vector3(0.026, 0.055, 0.006), gold, 3, 8)
		for i in range(6):
			var a := TAU * float(i) / 6.0
			var fcol: Color = [Color(1.0, 0.5, 0.0), Color(1.0, 0.82, 0.1), Color(0.95, 0.95, 0.92)][i % 3]
			e.add_ellipsoid(Transform3D(Basis(), Vector3(-w * 0.5 - 0.06 + cos(a) * 0.022, 0.018, sin(a) * 0.022)), Vector3(0.012, 0.01, 0.012), fcol, 3, 5)
		e.add_ellipsoid(Transform3D(Basis(), Vector3(-w * 0.5 - 0.06, 0.022, 0)), Vector3(0.01, 0.012, 0.01), Color(0.85, 0.1, 0.15), 3, 5)
		_extras = MeshKit.mesh_instance(self, e.commit())
		_extras.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _load_texture() -> Texture2D:
	image_size = Vector2i.ZERO
	source = ""
	if FileAccess.file_exists(USER_IMAGE):
		var img := Image.load_from_file(USER_IMAGE)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			image_size = img.get_size()
			source = "player photo"
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(DEFAULT_IMAGE):
		var tex := load(DEFAULT_IMAGE) as Texture2D
		if tex != null:
			image_size = Vector2i(tex.get_width(), tex.get_height())
			source = "default"
			return tex
	return null


## Imports a photo chosen by the player. Returns "" on success or an error message.
static func import_photo(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "File not found."
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return "That file is not a JPG, PNG or WebP image Godot can read."
	var longest := maxi(img.get_width(), img.get_height())
	if longest > 1024:
		var s := 1024.0 / float(longest)
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	var err := img.save_png(USER_IMAGE)
	if err != OK:
		return "Could not save the photo (%s)." % error_string(err)
	return ""


static func clear_photo() -> void:
	if FileAccess.file_exists(USER_IMAGE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_IMAGE))
