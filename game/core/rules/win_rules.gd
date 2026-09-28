class_name WinRules
extends RefCounted
## GAME_SPEC §5.2. Downed players are not living; only ELIMINATED traitors are out.

enum Winner { NONE, AGENTS, TRAITORS }


## players: Array of {role: RoleAssigner.Role, state: Vitals.State}
static func evaluate(players: Array, security: float, critical_expired: bool, elapsed: float, time_limit: float) -> Dictionary:
	var living_agents := 0
	var living_traitors := 0
	var traitors_remaining := 0
	for p: Dictionary in players:
		var is_traitor: bool = p["role"] == RoleAssigner.Role.TRAITOR
		if is_traitor and p["state"] != Vitals.State.ELIMINATED:
			traitors_remaining += 1
		if p["state"] == Vitals.State.ALIVE:
			if is_traitor:
				living_traitors += 1
			else:
				living_agents += 1
	if traitors_remaining == 0:
		return _result(Winner.AGENTS, "all_traitors_eliminated")
	if security >= 100.0:
		return _result(Winner.AGENTS, "security_complete")
	if critical_expired:
		return _result(Winner.TRAITORS, "island_control_lost")
	if living_traitors >= living_agents:
		return _result(Winner.TRAITORS, "traitors_outnumber")
	if time_limit > 0.0 and elapsed >= time_limit:
		return _result(Winner.TRAITORS, "time_limit")
	return _result(Winner.NONE, "")


static func winner_name(w: int) -> String:
	match w:
		Winner.AGENTS:
			return "agents"
		Winner.TRAITORS:
			return "traitors"
	return "none"


static func _result(w: int, reason: String) -> Dictionary:
	return {"winner": w, "reason": reason}
