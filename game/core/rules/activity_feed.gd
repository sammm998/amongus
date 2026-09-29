class_name ActivityFeed
extends RefCounted
## Activity map (GAME_SPEC §5.8): approximate, delayed (5–15 s) event blips per
## district — never exact positions or names. False alarms inject fake events.

var events: Array = []  # {kind, district, time, reveal_at}
var min_delay := 5.0
var max_delay := 15.0
var keep_seconds := 60.0
var coalesce_seconds := 8.0


func _init(cfg: Dictionary = {}) -> void:
	min_delay = float(cfg.get("min_delay_seconds", min_delay))
	max_delay = float(cfg.get("max_delay_seconds", max_delay))
	keep_seconds = float(cfg.get("keep_seconds", keep_seconds))
	coalesce_seconds = float(cfg.get("coalesce_seconds", coalesce_seconds))


## Returns true if a new blip was created (repeated events in a district merge).
func record(kind: String, district: String, now: float, rng: RandomNumberGenerator) -> bool:
	for e: Dictionary in events:
		if e["kind"] == kind and e["district"] == district and now - float(e["time"]) < coalesce_seconds:
			return false
	events.append({"kind": kind, "district": district, "time": now, "reveal_at": now + rng.randf_range(min_delay, max_delay)})
	return true


func prune(now: float) -> void:
	events = events.filter(func(e: Dictionary) -> bool: return now - float(e["reveal_at"]) <= keep_seconds)


## What the map shows right now: revealed blips with their age since reveal.
func visible(now: float) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		if float(e["reveal_at"]) <= now and now - float(e["reveal_at"]) <= keep_seconds:
			out.append({"kind": e["kind"], "district": e["district"], "age": now - float(e["reveal_at"])})
	return out
