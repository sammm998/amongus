class_name TTKCalculator
extends RefCounted
## Time-to-kill maths from weapon data (GAME_SPEC §5.5). Assumes perfect aim,
## every pellet hitting, and the first shot fired at t = spin_up.

const EPSILON := 0.0001


static func damage_per_shot(weapon: Dictionary, damage_multiplier: float = 1.0) -> float:
	return float(weapon.get("body_damage", 0.0)) * float(weapon.get("pellets", 1.0)) * damage_multiplier


static func shots_to_kill(per_shot: float, target_hp: float) -> int:
	if per_shot <= 0.0:
		return -1
	return int(ceil(target_hp / per_shot - EPSILON))


## Seconds until the killing shot lands; INF for weapons that deal no damage.
static func body_ttk(weapon: Dictionary, target_hp: float, damage_multiplier: float = 1.0) -> float:
	var shots := shots_to_kill(damage_per_shot(weapon, damage_multiplier), target_hp)
	if shots < 0:
		return INF
	var burst: int = maxi(1, int(weapon.get("burst_count", 1)))
	var period := 1.0 / float(weapon.get("fire_rate", 1.0))
	var index := shots - 1
	return float(weapon.get("spin_up", 0.0)) \
		+ floorf(float(index) / float(burst)) * period \
		+ float(index % burst) * float(weapon.get("burst_interval", 0.0))


## Allowed TTK band for a weapon: its own override, else the default.
## Returns an empty array when the weapon is exempt (e.g. non-lethal).
static func band_for(weapon: Dictionary, default_band: Array) -> Array:
	if weapon.has("ttk_band"):
		return weapon["ttk_band"] if weapon["ttk_band"] is Array else []
	return default_band
