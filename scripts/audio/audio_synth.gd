class_name AudioSynth
extends RefCounted
## Generates every sound effect in code, so the game ships no third-party audio
## and has no licensing questions. Results are cached.

const RATE := 22050

static var _cache := {}


static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## Horn 1: standard electric truck horn. Two dissonant tones, slightly clipped.
## Integer frequencies over exactly 1 second, so the loop is seamless.
static func horn_standard() -> AudioStreamWAV:
	if _cache.has("h1"):
		return _cache["h1"]
	var n := RATE
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var s := 0.5 * tanh(2.6 * sin(TAU * 415.0 * t)) + 0.42 * tanh(2.6 * sin(TAU * 523.0 * t))
		s += 0.08 * sin(TAU * 830.0 * t)
		buf[i] = s * 0.5
	_cache["h1"] = _to_wav(buf, true)
	return _cache["h1"]


## Horn 2: deep three-trumpet air horn with a slight pressure wobble.
static func horn_air() -> AudioStreamWAV:
	if _cache.has("h2"):
		return _cache["h2"]
	var n := RATE
	var buf := PackedFloat32Array()
	buf.resize(n)
	var freqs := [185.0, 233.0, 277.0]
	var phases := [0.0, 0.0, 0.0]
	for i in range(n):
		var t := float(i) / RATE
		var wobble := 1.3 * sin(TAU * 6.0 * t)
		var s := 0.0
		for k in range(3):
			var f: float = freqs[k] + wobble
			phases[k] = fmod(float(phases[k]) + f / RATE, 1.0)
			var ph: float = phases[k] * TAU
			var saw := 0.0
			for h in range(1, 9):
				saw += sin(ph * h) / float(h)
			s += saw * 0.26
		buf[i] = clampf(s * 0.62, -1.0, 1.0)
	_cache["h2"] = _to_wav(buf, true)
	return _cache["h2"]


## Horn 3: special multi-tone musical horn. Original 16-step tune.
static func horn_musical() -> AudioStreamWAV:
	if _cache.has("h3"):
		return _cache["h3"]
	var notes := [784.0, 988.0, 1175.0, 988.0, 784.0, 659.0, 784.0, 0.0,
		880.0, 1047.0, 880.0, 784.0, 659.0, 587.0, 659.0, 0.0]
	var step := int(RATE * 0.14)
	var buf := PackedFloat32Array()
	buf.resize(step * notes.size())
	var idx := 0
	for f in notes:
		var freq: float = f
		for j in range(step):
			var t := float(j) / RATE
			var env := minf(1.0, float(j) / (RATE * 0.008)) * minf(1.0, float(step - j) / (RATE * 0.015))
			var s := 0.0
			if freq > 0.0:
				s = 0.55 * tanh(3.0 * sin(TAU * freq * t)) + 0.2 * sin(TAU * freq * 2.0 * t)
			buf[idx] = s * env * 0.5
			idx += 1
	_cache["h3"] = _to_wav(buf, true)
	return _cache["h3"]


## Air brake release "pssht".
static func air_brake() -> AudioStreamWAV:
	if _cache.has("air"):
		return _cache["air"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(RATE * 0.75)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.02) * exp(-t * 4.5)
		var noise := rng.randf_range(-1.0, 1.0)
		var hp := noise - prev
		prev = noise
		buf[i] = hp * env * 0.45
	_cache["air"] = _to_wav(buf, false)
	return _cache["air"]


## Indicator relay click.
static func tick() -> AudioStreamWAV:
	if _cache.has("tick"):
		return _cache["tick"]
	var n := int(RATE * 0.03)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		buf[i] = sin(TAU * 1800.0 * t) * exp(-t * 220.0) * 0.6
	_cache["tick"] = _to_wav(buf, false)
	return _cache["tick"]


## Starter motor cranking, then the engine catching.
static func engine_start() -> AudioStreamWAV:
	if _cache.has("start"):
		return _cache["start"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(RATE * 1.2)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var crank := 0.5 + 0.5 * sin(TAU * 9.0 * t)
		ph = fmod(ph + (60.0 + 25.0 * t) / RATE, 1.0)
		var s := (0.5 * sin(TAU * ph) + 0.3 * rng.randf_range(-1.0, 1.0)) * crank
		var env := minf(1.0, t / 0.05) * (1.0 if t < 1.0 else maxf(0.0, 1.0 - (t - 1.0) / 0.2))
		buf[i] = s * env * 0.5
	_cache["start"] = _to_wav(buf, false)
	return _cache["start"]
