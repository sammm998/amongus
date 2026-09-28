class_name RespawnRules
extends RefCounted
## Revive respawn (GAME_SPEC §5.4): Medical Center or nearest powered medical
## station, never within `exclusion` metres of recent gunfire.


## candidates: Array[Vector3] in preference order; gunfire: Array[Vector3].
## Returns the first safe candidate, else the one farthest from any gunfire.
static func choose(candidates: Array, gunfire: Array, exclusion: float, fallback: Array = []) -> Vector3:
	var all := candidates + fallback
	if all.is_empty():
		return Vector3.ZERO
	for c: Vector3 in all:
		if _nearest(c, gunfire) >= exclusion:
			return c
	var best: Vector3 = all[0]
	var best_d := -1.0
	for c: Vector3 in all:
		var d := _nearest(c, gunfire)
		if d > best_d:
			best_d = d
			best = c
	return best


static func _nearest(p: Vector3, points: Array) -> float:
	var d := INF
	for g: Vector3 in points:
		d = minf(d, p.distance_to(g))
	return d
