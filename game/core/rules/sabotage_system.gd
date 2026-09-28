class_name SabotageSystem
extends RefCounted
## Traitor sabotage (GAME_SPEC §5.7). Shared team cooldown, per-kind cooldowns,
## one critical at a time, blocked during meetings and the opening grace period.
## Timers pause during meetings.

var defs: Dictionary = {}
var team_cooldown := 30.0
var cooldown_multiplier := 1.0
var ready_at: Dictionary = {}  # kind -> time
var team_ready_at := 0.0
var active: Array = []  # [{kind, district, time_left, critical, generators: {}}]


func _init(table: Dictionary, p_cooldown_multiplier: float = 1.0) -> void:
	defs = table.get("sabotages", {})
	team_cooldown = float(table.get("team_cooldown_seconds", 30.0))
	cooldown_multiplier = p_cooldown_multiplier


## "" when allowed, otherwise a reason code.
func can_trigger(kind: String, district: String, now: float, match_elapsed: float, in_meeting: bool, grace: float) -> String:
	if not defs.has(kind):
		return "unknown"
	if in_meeting:
		return "meeting"
	if match_elapsed < grace:
		return "grace"
	if now < team_ready_at:
		return "team_cooldown"
	if now < float(ready_at.get(kind, 0.0)):
		return "cooldown"
	var def: Dictionary = defs[kind]
	if bool(def["critical"]) and critical_active():
		return "critical_active"
	if def["targets"] == "district" and district.is_empty():
		return "no_target"
	for a: Dictionary in active:
		if a["kind"] == kind and a["district"] == district:
			return "already_active"
	return ""


func trigger(kind: String, district: String, now: float) -> Dictionary:
	var def: Dictionary = defs[kind]
	var entry := {
		"kind": kind, "district": district if def["targets"] == "district" else "",
		"time_left": float(def["duration_seconds"]), "critical": bool(def["critical"]),
		"generators": {},
	}
	active.append(entry)
	ready_at[kind] = now + float(def["cooldown_seconds"]) * cooldown_multiplier
	team_ready_at = now + team_cooldown * cooldown_multiplier
	return entry


## Returns events: [{type: "ended"|"critical_expired", kind, district}].
func tick(delta: float, paused: bool) -> Array:
	var events: Array = []
	if paused:
		return events
	for a: Dictionary in active.duplicate():
		a["time_left"] -= delta
		if a["time_left"] <= 0.0:
			active.erase(a)
			events.append({"type": "critical_expired" if a["critical"] else "ended", "kind": a["kind"], "district": a["district"]})
	return events


## Repairs: blackout/camera_jam end at their repair point; power_failure needs
## `generators_required` distinct generators. Returns {repaired, progress}.
func repair(kind: String, district: String, part: String = "") -> Dictionary:
	for a: Dictionary in active:
		if a["kind"] != kind or (not a["district"].is_empty() and a["district"] != district):
			continue
		if kind == "power_failure":
			a["generators"][part] = true
			var need := int(defs[kind].get("generators_required", 2))
			if a["generators"].size() >= need:
				active.erase(a)
				return {"repaired": true, "progress": a["generators"].size()}
			return {"repaired": false, "progress": a["generators"].size()}
		active.erase(a)
		return {"repaired": true, "progress": 1}
	return {"repaired": false, "progress": 0}


func critical_active() -> bool:
	return active.any(func(a: Dictionary) -> bool: return a["critical"])


func is_active(kind: String, district: String = "") -> bool:
	for a: Dictionary in active:
		if a["kind"] == kind and (district.is_empty() or a["district"].is_empty() or a["district"] == district):
			return true
	return false


func power_out() -> bool:
	return is_active("power_failure")


func blackout_districts() -> Array:
	var out: Array = []
	for a: Dictionary in active:
		if a["kind"] == "blackout":
			out.append(a["district"])
	return out


func camera_jammed(district: String) -> bool:
	return power_out() or is_active("camera_jam", district)


## Public alert list (everyone): what is happening, never who did it.
func public_state() -> Array:
	var out: Array = []
	for a: Dictionary in active:
		out.append({"kind": a["kind"], "district": a["district"], "time_left": a["time_left"], "critical": a["critical"], "progress": a["generators"].size()})
	return out


## Private panel data (traitors only).
func panel(now: float) -> Dictionary:
	var kinds := {}
	for kind: String in defs:
		kinds[kind] = {"ready_in": maxf(0.0, float(ready_at.get(kind, 0.0)) - now), "critical": bool(defs[kind]["critical"]), "targets": defs[kind]["targets"]}
	return {"kinds": kinds, "team_ready_in": maxf(0.0, team_ready_at - now)}
