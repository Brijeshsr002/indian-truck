class_name EngineAudio
extends AudioStreamPlayer3D
## Real-time diesel engine sound. Pitch follows RPM (6-cylinder firing frequency)
## and the roughness follows throttle. 22 kHz mono keeps the CPU cost small.

const RATE := 22050.0

var rpm := 0.0
var throttle := 0.0
var running := false

var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _sub := 0.0
var _lp := 0.0
var _level := 0.0
var _rng := RandomNumberGenerator.new()
var _silence := PackedVector2Array()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	bus = "Engine"
	unit_size = 12.0
	max_distance = 320.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


## Stop feeding the generator before the node is freed, so the audio thread never
## mixes a playback whose owner is being destroyed (shutdown or a new game).
func _exit_tree() -> void:
	set_process(false)
	stop()
	_playback = null


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	if not running and _level < 0.0005:
		# Engine off and faded out: feed silence without per-sample work.
		if _silence.size() != frames:
			_silence.resize(frames)
		_playback.push_buffer(_silence)
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var target := 0.0
	if running:
		target = 0.32 + 0.45 * throttle
	var f := maxf(rpm, 1.0) / 20.0
	var noise_amt := 0.22 + 0.55 * throttle
	for i in range(frames):
		_level += (target - _level) * 0.0009
		_phase = fmod(_phase + f / RATE, 1.0)
		_sub = fmod(_sub + f * 0.5 / RATE, 1.0)
		var p := _phase * TAU
		var s := 0.5 * sin(p) + 0.3 * sin(2.0 * p + 0.6) + 0.16 * sin(3.0 * p + 1.1) + 0.1 * sin(5.0 * p)
		s += 0.22 * sin(_sub * TAU)
		var pulse := maxf(0.0, sin(p))
		pulse = pulse * pulse * pulse * pulse
		s += 0.3 * pulse
		_lp += (_rng.randf_range(-1.0, 1.0) - _lp) * 0.15
		s += _lp * noise_amt
		var v := s * _level * 0.55
		buf[i] = Vector2(v, v)
	_playback.push_buffer(buf)
