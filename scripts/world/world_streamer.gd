class_name WorldStreamer
extends Node
## Loads world chunks near the player and frees distant ones. At most one chunk is
## built per update, so crossing a boundary never causes a long freeze.

var world: CoimbatoreWorld
var target: Node3D
var radius := 420.0
var loaded := {}
var _timer := 0.0


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or world == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.2
	update_now(false)


func update_now(build_all: bool) -> void:
	var p := target.global_position
	for key in loaded.keys():
		if _dist(key, p) > radius + 120.0:
			(loaded[key] as Node).queue_free()
			loaded.erase(key)
	var wanted := []
	for key in world.chunk_specs.keys():
		if loaded.has(key):
			continue
		var d := _dist(key, p)
		if d <= radius:
			wanted.append([d, key])
	wanted.sort_custom(func(x, y): return x[0] < y[0])
	for w in wanted:
		var node := world.build_chunk(w[1])
		world.add_child(node)
		loaded[w[1]] = node
		if not build_all:
			break


func loaded_count() -> int:
	return loaded.size()


func _dist(key: Vector2i, p: Vector3) -> float:
	var c := CoimbatoreWorld.CHUNK
	var minx := key.x * c
	var minz := key.y * c
	var dx := maxf(0.0, maxf(minx - p.x, p.x - (minx + c)))
	var dz := maxf(0.0, maxf(minz - p.z, p.z - (minz + c)))
	return sqrt(dx * dx + dz * dz)
