class_name RoleAssigner
extends RefCounted
## GAME_SPEC §5.1: traitor count = round(players / 6), clamped 1..4 (host can override).

enum Role { AGENT, TRAITOR }


static func traitor_count(players: int, settings: Dictionary, host_override: int = -1) -> int:
	if players < 2:
		return 0
	var upper := mini(int(settings.get("traitor_max", 4)), players - 1)
	if host_override > 0:
		return clampi(host_override, 1, upper)
	var n := roundi(float(players) / float(settings.get("traitor_divisor", 6)))
	return clampi(n, int(settings.get("traitor_min", 1)), upper)


## Returns {player_id: Role}. Roles never leave the server except as allowed by RoleVisibility.
static func assign(player_ids: Array, count: int, rng: RandomNumberGenerator) -> Dictionary:
	var shuffled := player_ids.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var roles := {}
	for i in shuffled.size():
		roles[shuffled[i]] = Role.TRAITOR if i < count else Role.AGENT
	return roles


static func role_name(role: int) -> String:
	return "traitor" if role == Role.TRAITOR else "agent"
