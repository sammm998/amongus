class_name EvidenceLog
extends RefCounted
## Evidence left at incident sites (GAME_SPEC §5.8), persisting for a while:
## shell casings (weapon family), impact marks, dropped items. Never names anyone.

var items: Array = []  # {id, kind, pos, family, time}
var lifetime := 180.0
var max_items := 400
var _next_id := 1


func _init(p_lifetime: float = 180.0, p_max: int = 400) -> void:
	lifetime = p_lifetime
	max_items = p_max


func add(kind: String, pos: Vector3, family: String, now: float) -> int:
	# Don't pile identical evidence on the same spot.
	for e: Dictionary in items:
		if e["kind"] == kind and e["family"] == family and (e["pos"] as Vector3).distance_to(pos) < 0.6:
			e["time"] = now
			return e["id"]
	var id := _next_id
	_next_id += 1
	items.append({"id": id, "kind": kind, "pos": pos, "family": family, "time": now})
	if items.size() > max_items:
		items.pop_front()
	return id


func prune(now: float) -> void:
	items = items.filter(func(e: Dictionary) -> bool: return now - float(e["time"]) <= lifetime)


func near(pos: Vector3, radius: float) -> Array:
	return items.filter(func(e: Dictionary) -> bool: return (e["pos"] as Vector3).distance_to(pos) <= radius)


func get_item(id: int) -> Dictionary:
	for e: Dictionary in items:
		if e["id"] == id:
			return e
	return {}
