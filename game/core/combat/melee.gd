class_name Melee
extends RefCounted
## Knife rules (pure). A stab hits the closest target in a cone in front of the
## attacker; it is a backstab when the attacker stands behind the target.


## forward vectors are horizontal unit vectors. Returns {hit, backstab}.
static func stab(attacker: Vector3, attacker_forward: Vector3, target: Vector3, target_forward: Vector3, cfg: Dictionary) -> Dictionary:
	var to_target := Vector3(target.x - attacker.x, 0.0, target.z - attacker.z)
	var dist := to_target.length()
	if dist > float(cfg["range_m"]) or absf(target.y - attacker.y) > 1.8:
		return {"hit": false, "backstab": false}
	if dist > 0.05:
		var cos_cone := cos(deg_to_rad(float(cfg["cone_degrees"])))
		if to_target.normalized().dot(attacker_forward) < cos_cone:
			return {"hit": false, "backstab": false}
	# Behind = the attacker lies in the cone opposite the target's facing.
	var from_target := -to_target.normalized() if dist > 0.05 else -target_forward
	var cos_back := cos(deg_to_rad(float(cfg["backstab_cone_degrees"])))
	return {"hit": true, "backstab": from_target.dot(-target_forward) >= cos_back}


static func damage(result: Dictionary, cfg: Dictionary) -> float:
	if not result["hit"]:
		return 0.0
	return float(cfg["backstab_damage"]) if result["backstab"] else float(cfg["front_damage"])
