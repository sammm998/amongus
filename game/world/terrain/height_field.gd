class_name HeightField
extends RefCounted
## Island height function built from data (pure; no nodes).
##
## Land is a smooth union of ellipses. The signed distance d to the coastline
## (positive inland) drives the coastal profile:
##   inland      -> land_level (+ hills)
##   0..beach    -> beach rising from the waterline
##   -shelf..0   -> shallow turquoise shelf
##   beyond      -> drop-off to sea_floor
##
## Definition keys: sea_floor, land_level, beach_width, shelf_width, shelf_depth,
## dropoff, land: [{x, z, rx, rz, [rot]}],
## hills: [{x, z, radius, height, [shape dome|plateau|cone], [sx], [sz], [crater], [coastal]}],
## flats: [{x, z, radius, height, [blend]}], noise: {amplitude, frequency, seed}.

var sea_floor := -18.0
var land_level := 2.2
var beach_width := 14.0
var shelf_width := 28.0
var shelf_depth := 2.5
var dropoff := 60.0
var land: Array = []
var hills: Array = []
var flats: Array = []
var noise_amplitude := 0.0
var _noise := FastNoiseLite.new()


func _init(definition: Dictionary = {}) -> void:
	sea_floor = float(definition.get("sea_floor", sea_floor))
	land_level = float(definition.get("land_level", land_level))
	beach_width = float(definition.get("beach_width", beach_width))
	shelf_width = float(definition.get("shelf_width", shelf_width))
	shelf_depth = float(definition.get("shelf_depth", shelf_depth))
	dropoff = float(definition.get("dropoff", dropoff))
	land = definition.get("land", [])
	hills = definition.get("hills", [])
	flats = definition.get("flats", [])
	var n: Dictionary = definition.get("noise", {})
	noise_amplitude = float(n.get("amplitude", 0.0))
	_noise.seed = int(n.get("seed", 1))
	_noise.frequency = float(n.get("frequency", 0.02))
	_noise.fractal_octaves = 4
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


## Signed distance to the coastline in metres (positive = on land).
func coast_distance(x: float, z: float) -> float:
	var d := -1e9
	for e: Dictionary in land:
		var dx := x - float(e["x"])
		var dz := z - float(e["z"])
		var rot := deg_to_rad(float(e.get("rot", 0.0)))
		if rot != 0.0:
			var c := cos(rot)
			var s := sin(rot)
			var rx := dx * c - dz * s
			dz = dx * s + dz * c
			dx = rx
		var ex := dx / float(e["rx"])
		var ez := dz / float(e["rz"])
		var k := sqrt(ex * ex + ez * ez)
		var ed := (1.0 - k) * minf(float(e["rx"]), float(e["rz"]))
		d = smooth_max(d, ed, 12.0) if d > -1e8 else ed
	return d


func height_at(x: float, z: float) -> float:
	var jitter := _noise.get_noise_2d(x, z)
	var d := coast_distance(x, z) + jitter * 4.0
	var h := coastal_profile(d)
	var inland := smoothstep(beach_width * 0.6, beach_width + 12.0, d)
	for hill: Dictionary in hills:
		var weight := 1.0 if bool(hill.get("coastal", false)) else inland
		h += _hill(hill, x, z) * weight
	if noise_amplitude > 0.0:
		h += jitter * noise_amplitude * inland
	for flat: Dictionary in flats:
		var fd := Vector2(x - float(flat["x"]), z - float(flat["z"])).length()
		var r := float(flat["radius"])
		var w := 1.0 - smoothstep(r * (1.0 - float(flat.get("blend", 0.3))), r, fd)
		h = lerpf(h, float(flat["height"]), w)
	return h


func coastal_profile(d: float) -> float:
	if d >= beach_width:
		return land_level
	if d >= 0.0:
		var t := d / beach_width
		return lerpf(0.15, land_level, t * t * (3.0 - 2.0 * t))
	if d >= -shelf_width:
		var t := -d / shelf_width
		return lerpf(0.15, -shelf_depth, sqrt(t))
	var t := clampf((-d - shelf_width) / dropoff, 0.0, 1.0)
	return lerpf(-shelf_depth, sea_floor, t * t * (3.0 - 2.0 * t))


func normal_at(x: float, z: float, step: float = 1.0) -> Vector3:
	var dx := height_at(x + step, z) - height_at(x - step, z)
	var dz := height_at(x, z + step) - height_at(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


func _hill(hill: Dictionary, x: float, z: float) -> float:
	var dx := (x - float(hill["x"])) / float(hill.get("sx", 1.0))
	var dz := (z - float(hill["z"])) / float(hill.get("sz", 1.0))
	var t := sqrt(dx * dx + dz * dz) / float(hill["radius"])
	if t >= 1.0:
		return 0.0
	var f := 0.0
	match str(hill.get("shape", "dome")):
		"plateau":
			f = smoothstep(1.0, 0.55, t)
		"cone":
			f = pow(1.0 - t, 1.3)
			var crater := float(hill.get("crater", 0.0))
			if crater > 0.0 and t < crater:
				f -= (1.0 - t / crater) * 0.1
		_:
			var u := 1.0 - t * t
			f = u * u
	return float(hill["height"]) * f


## Polynomial smooth maximum: merges shapes without creases.
static func smooth_max(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(a, b, h) + k * h * (1.0 - h)
