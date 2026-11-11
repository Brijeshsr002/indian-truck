extends Node
## Reads and writes the save game as JSON. Writes go to a temp file first so a
## crash during saving cannot destroy the previous save.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1


func has_save(path := SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_data(data: Dictionary, path := SAVE_PATH) -> Dictionary:
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Could not write the save file (%s)." % error_string(FileAccess.get_open_error())}
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	var err := DirAccess.rename_absolute(abs_tmp, abs_path)
	if err != OK:
		return {"ok": false, "error": "Could not finish saving (%s)." % error_string(err)}
	return {"ok": true}


func load_data(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No saved game found."}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("truck"):
		var abs_path := ProjectSettings.globalize_path(path)
		DirAccess.rename_absolute(abs_path, abs_path + ".corrupt")
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
