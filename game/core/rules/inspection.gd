class_name Inspection
extends RefCounted
## Body inspection (GAME_SPEC §5.8): estimated time (±15 s), damage category,
## range band, weapon family, rough direction of the last hit. Never the attacker.

const FIELDS := ["seconds_ago", "damage_type", "range", "weapon_family", "direction"]


static func report(incident: Dictionary, now: float, rng: RandomNumberGenerator, noise_seconds: float = 15.0) -> Dictionary:
	if incident.is_empty() or not incident.has("time"):
		return {"known": false}
	var ago := now - float(incident["time"]) + rng.randf_range(-noise_seconds, noise_seconds)
	return {
		"known": true,
		"seconds_ago": float(maxi(5, int(round(ago / 5.0)) * 5)),
		"damage_type": incident.get("damage_type", "unknown"),
		"range": incident.get("range", "unknown"),
		"weapon_family": incident.get("weapon_family", "unknown"),
		"direction": incident.get("direction", "unknown"),
	}
