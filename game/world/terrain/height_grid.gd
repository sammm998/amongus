class_name HeightGrid
extends RefCounted
## Baked height + coast-distance grid (bilinear sampling). Baking once and
## caching to disk keeps big islands fast to load, also on the web.

const MAGIC := "TIHG1"

var origin := Vector2.ZERO
var cell := 2.0
var width := 0
var depth := 0
var heights := PackedFloat32Array()
var coast := PackedFloat32Array()


static func bake(field: HeightField, p_origin: Vector2, size: Vector2, p_cell: float) -> HeightGrid:
	var g := HeightGrid.new()
	g.origin = p_origin
	g.cell = p_cell
	g.width = int(ceil(size.x / p_cell)) + 1
	g.depth = int(ceil(size.y / p_cell)) + 1
	g.heights.resize(g.width * g.depth)
	g.coast.resize(g.width * g.depth)
	var i := 0
	for zi in g.depth:
		for xi in g.width:
			var v := field.sample_both(p_origin.x + xi * p_cell, p_origin.y + zi * p_cell)
			g.heights[i] = v.x
			g.coast[i] = v.y
			i += 1
	return g


func contains(x: float, z: float) -> bool:
	return x >= origin.x and z >= origin.y and x <= origin.x + (width - 1) * cell and z <= origin.y + (depth - 1) * cell


func height(x: float, z: float) -> float:
	return _sample(heights, x, z)


func coast_distance(x: float, z: float) -> float:
	return _sample(coast, x, z)


func normal(x: float, z: float) -> Vector3:
	var dx := height(x + cell, z) - height(x - cell, z)
	var dz := height(x, z + cell) - height(x, z - cell)
	return Vector3(-dx, 2.0 * cell, -dz).normalized()


func _sample(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / cell, 0.0, width - 1.001)
	var fz := clampf((z - origin.y) / cell, 0.0, depth - 1.001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - x0
	var tz := fz - z0
	var i := z0 * width + x0
	var a := lerpf(arr[i], arr[i + 1], tx)
	var b := lerpf(arr[i + width], arr[i + width + 1], tx)
	return lerpf(a, b, tz)


func save(path: String, key: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_pascal_string(MAGIC)
	f.store_pascal_string(key)
	f.store_float(origin.x)
	f.store_float(origin.y)
	f.store_float(cell)
	f.store_32(width)
	f.store_32(depth)
	f.store_buffer(heights.to_byte_array())
	f.store_buffer(coast.to_byte_array())
	return OK


## Loads a cached grid if it was baked from the same terrain definition.
static func load_cached(path: String, key: String) -> HeightGrid:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_pascal_string() != MAGIC or f.get_pascal_string() != key:
		return null
	var g := HeightGrid.new()
	g.origin = Vector2(f.get_float(), f.get_float())
	g.cell = f.get_float()
	g.width = f.get_32()
	g.depth = f.get_32()
	var n := g.width * g.depth
	g.heights = f.get_buffer(n * 4).to_float32_array()
	g.coast = f.get_buffer(n * 4).to_float32_array()
	return g if g.heights.size() == n and g.coast.size() == n else null
