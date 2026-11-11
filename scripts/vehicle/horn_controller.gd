class_name HornController
extends Node3D
## Three independent truck horns, each with its own sound, input action and 3D
## audio player (so distance and direction work from cockpit and outside cameras).

const HORN_NAMES := ["Standard horn", "Air horn", "Special multi-tone horn"]

var players: Array[AudioStreamPlayer3D] = []
var pressed := [false, false, false]
## When true, Horn 1 sounds all three horns together (optional combined setup).
var combined := false


func _ready() -> void:
	var streams := [AudioSynth.horn_standard(), AudioSynth.horn_air(), AudioSynth.horn_musical()]
	for i in range(3):
		var p := AudioStreamPlayer3D.new()
		p.name = "Horn%d" % (i + 1)
		p.stream = streams[i]
		p.bus = "Horns"
		p.unit_size = 22.0
		p.max_distance = 650.0
		p.volume_db = 0.0
		add_child(p)
		players.append(p)


func set_horn(index: int, on: bool) -> void:
	if index < 0 or index > 2:
		return
	if pressed[index] == on:
		return
	pressed[index] = on
	_refresh()


func release_all() -> void:
	pressed = [false, false, false]
	_refresh()


func is_sounding(index: int) -> bool:
	return index >= 0 and index < players.size() and players[index].playing


func _refresh() -> void:
	var want: Array = pressed.duplicate()
	if combined and pressed[0]:
		want = [true, true, true]
	for i in range(3):
		var p := players[i]
		if want[i] and not p.playing:
			p.play()
		elif not want[i] and p.playing:
			p.stop()
