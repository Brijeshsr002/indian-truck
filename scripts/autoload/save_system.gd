extends Node
## Reads and writes the save game as JSON. Writes go to a temp file first so a
## crash during saving cannot destroy the previous save.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1


func has_save(path := SAVE_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func save_data(data: Dictionary, path := SAVE_PATH) -> Dictionary:
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	# 1. Write the new save to a temp file and check it was written completely.
	var tmp := path + ".tmp"
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Could not write the save file (%s)." % error_string(FileAccess.get_open_error())}
	var wrote := f.store_string(text)
	f.close()
	if not wrote or FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return {"ok": false, "error": "Could not write the save file completely (disk full?). Your previous save is unchanged."}
	# 2. Keep the old save as .bak until the new one is safely in place.
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_bak := abs_path + ".bak"
	var had_old := FileAccess.file_exists(path)
	if had_old:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		var berr := DirAccess.rename_absolute(abs_path, abs_bak)
		if berr != OK:
			return {"ok": false, "error": "Could not replace the old save (%s). Your previous save is unchanged." % error_string(berr)}
	var err := DirAccess.rename_absolute(abs_tmp, abs_path)
	if err != OK:
		if had_old:
			DirAccess.rename_absolute(abs_bak, abs_path)
		return {"ok": false, "error": "Could not finish saving (%s). Your previous save was restored." % error_string(err)}
	return {"ok": true}


func load_data(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"):
		# A save was interrupted after the old file was moved aside: use the backup.
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak"), ProjectSettings.globalize_path(path))
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No saved game found."}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("truck"):
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path + ".corrupt"):
			DirAccess.remove_absolute(abs_path + ".corrupt")
		DirAccess.rename_absolute(abs_path, abs_path + ".corrupt")
		# Try the previous good save before giving up.
		if FileAccess.file_exists(path + ".bak"):
			var bak = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
			if typeof(bak) == TYPE_DICTIONARY and bak.has("truck"):
				DirAccess.rename_absolute(abs_path + ".bak", abs_path)
				return {"ok": true, "data": bak, "warning": "The latest save was damaged, so your previous save was loaded."}
		return {"ok": false, "error": "The save file was damaged. It was kept as a .corrupt file and a new game was started."}
	return {"ok": true, "data": parsed}


# ---------------------------------------------------------------- helpers

static func xform_to_array(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func array_to_xform(a: Array) -> Transform3D:
	if a.size() != 12:
		return Transform3D.IDENTITY
	var b := Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]))
	return Transform3D(b.orthonormalized(), Vector3(a[9], a[10], a[11]))


static func vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec3(a: Array) -> Vector3:
	if a.size() != 3:
		return Vector3.ZERO
	return Vector3(a[0], a[1], a[2])
