class_name SoundBank
extends RefCounted
## Original sounds synthesized in code (no external audio files): gunshots per
## weapon family, footsteps, alerts, meeting horn, UI and feedback blips.

const RATE := 22050

static var _cache: Dictionary = {}


static func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var s: AudioStreamWAV
	match sound_name:
		"shot_sidearm":
			s = _gunshot(0.18, 900.0, 0.55, 11)
		"shot_smg":
			s = _gunshot(0.12, 1300.0, 0.45, 12)
		"shot_rifle":
			s = _gunshot(0.22, 700.0, 0.6, 13)
		"shot_marksman":
			s = _gunshot(0.35, 500.0, 0.7, 14)
		"shot_sniper":
			s = _gunshot(0.6, 300.0, 0.85, 15)
		"shot_shotgun":
			s = _gunshot(0.4, 380.0, 0.8, 16)
		"shot_lmg":
			s = _gunshot(0.16, 650.0, 0.6, 17)
		"shot_stun":
			s = _zap()
		"shot_explosive":
			s = _gunshot(0.9, 160.0, 0.9, 18)
		"footstep":
			s = _footstep()
		"alert":
			s = _siren()
		"horn":
			s = _horn()
		"hit":
			s = _blip(1800.0, 0.05, 0.5)
		"pickup":
			s = _chirp(600.0, 1200.0, 0.12)
		"task":
			s = _chime()
		"ping":
			s = _chirp(900.0, 1400.0, 0.18)
		"click":
			s = _blip(1100.0, 0.03, 0.35)
		"down":
			s = _chirp(500.0, 120.0, 0.6)
		_:
			s = _blip(440.0, 0.1, 0.3)
	_cache[sound_name] = s
	return s


static func shot_for_family(family: String) -> String:
	return "shot_" + family


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Noise burst through a falling low-pass with a low "thump".
static func _gunshot(length: float, cutoff: float, body: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 18.0 / length)
		var c := cutoff * (1.0 + 6.0 * exp(-t * 40.0))
		var a := clampf(TAU * c / RATE, 0.0, 1.0)
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		var thump := sin(TAU * 70.0 * t) * exp(-t * 25.0) * body
		out[i] = (lp * 1.6 + thump) * env
	return _wav(out)


static func _zap() -> AudioStreamWAV:
	var n := int(0.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sign(sin(TAU * (1200.0 - 2400.0 * t) * t)) * 0.3 * exp(-t * 8.0)
	return _wav(out)


static func _footstep() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := int(0.09 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.12 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = (lp * 2.0 + sin(TAU * 90.0 * t) * 0.4) * exp(-t * 45.0)
	return _wav(out)


static func _siren() -> AudioStreamWAV:
	var n := int(1.2 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 600.0 + 250.0 * sin(TAU * 2.5 * t)
		phase += TAU * f / RATE
		out[i] = (sin(phase) * 0.6 + sin(phase * 2.0) * 0.15) * minf(1.0, t * 20.0) * minf(1.0, (1.2 - t) * 8.0) * 0.5
	return _wav(out)


static func _horn() -> AudioStreamWAV:
	var n := int(1.4 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for h in [1.0, 2.0, 3.0, 5.0]:
			v += sin(TAU * 220.0 * h * t) / h
		out[i] = v * 0.3 * minf(1.0, t * 10.0) * minf(1.0, (1.4 - t) * 4.0)
	return _wav(out)


static func _blip(freq: float, length: float, volume: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * volume * exp(-t * 6.0 / length)
	return _wav(out)


static func _chirp(f0: float, f1: float, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / length) / RATE
		out[i] = sin(phase) * 0.4 * minf(1.0, (length - t) * 20.0)
	return _wav(out)


static func _chime() -> AudioStreamWAV:
	var n := int(0.6 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if t < 0.15 else 1320.0
		out[i] = sin(TAU * f * t) * 0.35 * exp(-(t - (0.0 if t < 0.15 else 0.15)) * 6.0)
	return _wav(out)
