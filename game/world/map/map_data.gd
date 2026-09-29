class_name MapData
extends RefCounted
## Read-only view of a map JSON file with lookups shared by server, client and bots.

var raw: Dictionary
var field: HeightField
var grid: HeightGrid
var beach_width := 0.0
var stations: Dictionary = {}   # id -> dict (with "pos": Vector3)
var districts: Array = []
var waypoints: Dictionary = {}  # id -> Vector3
var _astar := AStar3D.new()
var _wp_ids: Dictionary = {}    # name -> astar id
var _wp_names: Array = []


static func load_map(map_id: String) -> MapData:
	var m := MapData.new()
	m.raw = GameDataRegistry.read_json("res://data/maps/%s.json" % map_id)
	m._init_from_raw()
	return m


func _init_from_raw() -> void:
	field = HeightField.new(raw["terrain"])
	grid = _load_grid()
	beach_width = field.beach_width
	districts = raw.get("districts", [])
	for s: Dictionary in raw.get("stations", []):
		var d := s.duplicate()
		d["pos"] = ground_point(float(s["x"]), float(s["z"]))
		stations[s["id"]] = d
	var wps: Dictionary = raw.get("waypoints", {})
	for name: String in wps:
		var p: Array = wps[name]
		var pos := ground_point(float(p[0]), float(p[1]))
		waypoints[name] = pos
		_bucket_add(name, pos)
		var id := _wp_names.size()
		_wp_names.append(name)
		_wp_ids[name] = id
		_astar.add_point(id, pos)
	for e: Array in raw.get("edges", []):
		if _wp_ids.has(e[0]) and _wp_ids.has(e[1]):
			_astar.connect_points(_wp_ids[e[0]], _wp_ids[e[1]])


func id() -> String:
	return raw.get("id", "")


## Terrain rectangle (origin, size): the grid when present, else collision + margin.
func terrain_rect() -> Rect2:
	if raw.has("grid"):
		var g: Dictionary = raw["grid"]
		return Rect2(g["origin"][0], g["origin"][1], g["size"][0], g["size"][1])
	var col: Dictionary = raw["collision"]
	var size := float(col["size"]) + 120.0
	return Rect2(float(col["center"][0]) - size * 0.5, float(col["center"][1]) - size * 0.5, size, size)


## Large maps carry a "grid" entry: heights are pre-baked into a HeightGrid
## (cached in data/maps/<id>.heights) instead of evaluating the field each call.
func _load_grid() -> HeightGrid:
	if not raw.has("grid"):
		return null
	var spec: Dictionary = raw["grid"]
	var key := str(hash(JSON.stringify(raw["terrain"]) + JSON.stringify(spec)))
	var path := "res://data/maps/%s.heights" % raw.get("id", "map")
	var g := HeightGrid.load_cached(path, key)
	if g != null:
		return g
	g = HeightGrid.bake(field, Vector2(spec["origin"][0], spec["origin"][1]), Vector2(spec["size"][0], spec["size"][1]), float(spec["cell"]))
	# Cache next to the map when running from source (tools/bake_maps.gd commits it).
	if OS.has_feature("editor") or not OS.has_feature("template"):
		g.save(ProjectSettings.globalize_path(path), key)
	return g


func height(x: float, z: float) -> float:
	return grid.height(x, z) if grid != null and grid.contains(x, z) else field.height_at(x, z)


func normal(x: float, z: float) -> Vector3:
	return grid.normal(x, z) if grid != null and grid.contains(x, z) else field.normal_at(x, z, 0.5)


func coast_distance(x: float, z: float) -> float:
	return grid.coast_distance(x, z) if grid != null and grid.contains(x, z) else field.coast_distance(x, z)


## Ground position; on building floors the pad height is used (flats).
func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


## Adds a waypoint (used by AutoWaypoints).
func add_waypoint(name: String, pos: Vector3) -> void:
	if _wp_ids.has(name):
		return
	waypoints[name] = pos
	_bucket_add(name, pos)
	var id := _wp_names.size()
	_wp_names.append(name)
	_wp_ids[name] = id
	_astar.add_point(id, pos)


func connect_waypoints(a: String, b: String) -> void:
	if _wp_ids.has(a) and _wp_ids.has(b) and a != b:
		_astar.connect_points(_wp_ids[a], _wp_ids[b])


func station(station_id: String) -> Dictionary:
	return stations.get(station_id, {})


func station_pos(station_id: String) -> Vector3:
	return stations.get(station_id, {}).get("pos", Vector3.ZERO)


func stations_of_kind(kind: String) -> Array:
	var out: Array = []
	for s: Dictionary in stations.values():
		if s["kind"] == kind:
			out.append(s)
	return out


func station_districts() -> Dictionary:
	var out := {}
	for s: Dictionary in stations.values():
		out[s["id"]] = s["district"]
	return out


## District containing a point (closest centre within its radius; "roads" otherwise).
func district_at(pos: Vector3) -> String:
	var best := ""
	var best_d := INF
	for d: Dictionary in districts:
		if d["id"] == "roads":
			continue
		var dist := Vector2(pos.x - float(d["x"]), pos.z - float(d["z"])).length()
		if dist <= float(d["radius"]) and dist < best_d:
			best = d["id"]
			best_d = dist
	return best if not best.is_empty() else "roads"


func district_name(district_id: String) -> String:
	for d: Dictionary in districts:
		if d["id"] == district_id:
			return d["name"]
	return district_id


func district_ids(include_roads: bool = false) -> Array:
	var out: Array = []
	for d: Dictionary in districts:
		if include_roads or d["id"] != "roads":
			out.append(d["id"])
	return out


func spawn_points() -> Array:
	var out: Array = []
	for s: Dictionary in raw.get("spawns", []):
		out.append(ground_point(float(s["x"]), float(s["z"])) + Vector3(0, 0.1, 0))
	return out


func nearest_waypoint(pos: Vector3) -> String:
	if _wp_names.is_empty():
		return ""
	return _wp_names[_astar.get_closest_point(pos)]


## Waypoint path (positions) from one point to another, ending exactly at `to`.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if _wp_names.is_empty():
		out.append(to)
		return out
	var a := _astar.get_closest_point(from)
	var b := _astar.get_closest_point(to)
	var pts := _astar.get_point_path(a, b)
	# Skip the first waypoint when we're already past it toward the second.
	if pts.size() >= 2 and from.distance_to(pts[1]) < pts[0].distance_to(pts[1]):
		pts = pts.slice(1)
	out.append_array(pts)
	out.append(to)
	return out


const WP_BUCKET := 32.0
var _wp_buckets: Dictionary = {}  # Vector2i -> Array[String]


func _bucket_add(name: String, pos: Vector3) -> void:
	var key := Vector2i(floori(pos.x / WP_BUCKET), floori(pos.z / WP_BUCKET))
	if not _wp_buckets.has(key):
		_wp_buckets[key] = []
	_wp_buckets[key].append(name)


## Waypoint names sorted by distance (closest first). Searches spatial buckets
## in growing rings so big maps stay cheap.
func nearest_waypoints(pos: Vector3, count: int) -> Array:
	var list: Array = []
	var c := Vector2i(floori(pos.x / WP_BUCKET), floori(pos.z / WP_BUCKET))
	var ring := 0
	while ring < 64:
		for bz in range(c.y - ring, c.y + ring + 1):
			for bx in range(c.x - ring, c.x + ring + 1):
				if maxi(absi(bx - c.x), absi(bz - c.y)) != ring:
					continue
				for name: String in _wp_buckets.get(Vector2i(bx, bz), []):
					list.append([pos.distance_squared_to(waypoints[name]), name])
		# Everything within `ring` buckets is found; one more ring guarantees order.
		if list.size() >= count and ring >= 1:
			break
		ring += 1
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return list.slice(0, count).map(func(e: Array) -> String: return e[1])


## Path starting at a chosen waypoint (e.g. one the caller can actually see).
func path_via(start_wp: String, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not _wp_ids.has(start_wp):
		out.append(to)
		return out
	out.append_array(_astar.get_point_path(_wp_ids[start_wp], _astar.get_closest_point(to)))
	out.append(to)
	return out


func waypoint_names() -> Array:
	return _wp_names.duplicate()


func waypoint_position(name: String) -> Vector3:
	return waypoints.get(name, Vector3.ZERO)
