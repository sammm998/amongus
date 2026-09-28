class_name WeaponInstance
extends RefCounted
## Server-authoritative weapon timing: fire rate, bursts, spin-up, magazine and
## reload (incl. shell-by-shell). Times are match-clock seconds.

var def: Dictionary
var id: String
var rarity: String
var mag := 0
var next_fire_at := 0.0
var reload_until := -1.0
var trigger_since := -1.0
var _burst_index := 0
var _burst_start := 0.0


static func create(weapon_def: Dictionary, p_rarity: String = "standard") -> WeaponInstance:
	var w := WeaponInstance.new()
	w.def = weapon_def
	w.id = weapon_def["id"]
	w.rarity = p_rarity
	w.mag = int(weapon_def["mag_size"])
	return w


func ammo_type() -> String:
	return def["ammo_type"]


func mag_size() -> int:
	return int(def["mag_size"])


func is_reloading() -> bool:
	return reload_until >= 0.0


## Trigger state feeds spin-up (LMG). Call every tick with the fire button.
func set_trigger(held: bool, now: float) -> void:
	if held and trigger_since < 0.0:
		trigger_since = now
	elif not held:
		trigger_since = -1.0
		if _burst_index > 0:
			# Releasing mid-burst still completes nothing more; next pull starts fresh.
			_burst_index = 0


func can_fire(now: float) -> bool:
	if is_reloading() or mag <= 0 or now + 0.0001 < next_fire_at:
		return false
	var spin := float(def.get("spin_up", 0.0))
	if spin > 0.0 and (trigger_since < 0.0 or now - trigger_since + 0.0001 < spin):
		return false
	return true


## Consumes one round. Returns the number of pellets to trace (0 if it can't fire).
func fire(now: float) -> int:
	if not can_fire(now):
		return 0
	mag -= 1
	var burst := maxi(1, int(def.get("burst_count", 1)))
	var period := 1.0 / float(def["fire_rate"])
	if burst > 1:
		if _burst_index == 0:
			_burst_start = now
		_burst_index += 1
		if _burst_index < burst and mag > 0:
			next_fire_at = now + float(def.get("burst_interval", 0.0))
		else:
			_burst_index = 0
			next_fire_at = _burst_start + period
	else:
		next_fire_at = now + period
	return int(def.get("pellets", 1))


func start_reload(now: float, reserve: int) -> bool:
	if is_reloading() or mag >= mag_size() or reserve <= 0:
		return false
	reload_until = now + float(def["reload_time"])
	_burst_index = 0
	return true


func cancel_reload() -> void:
	reload_until = -1.0


## Finishes reload steps whose time has come. Returns rounds taken from reserve.
func update(now: float, reserve: int) -> int:
	if not is_reloading() or now + 0.0001 < reload_until:
		return 0
	if bool(def.get("reload_per_shell", false)):
		if reserve <= 0:
			reload_until = -1.0
			return 0
		mag += 1
		if mag < mag_size() and reserve - 1 > 0:
			reload_until += float(def["reload_time"])
		else:
			reload_until = -1.0
		return 1
	var take := mini(mag_size() - mag, reserve)
	mag += take
	reload_until = -1.0
	return take


## Damage for one pellet at `distance` metres.
func damage_at(distance: float, headshot: bool, combat: Dictionary) -> float:
	var rarities: Dictionary = combat.get("rarities", {})
	var mult := float(rarities.get(rarity, {}).get("damage_multiplier", 1.0))
	var dmg := float(def["body_damage"]) * mult * falloff(distance)
	if headshot and bool(def.get("headshot_allowed", true)):
		dmg *= float(combat.get("headshot_multiplier", 1.5))
	return dmg


func falloff(distance: float) -> float:
	var f: Dictionary = def.get("falloff", {})
	var start := float(f.get("start_m", 1e9))
	var end := float(f.get("end_m", 1e9))
	var min_mult := float(f.get("min_multiplier", 1.0))
	if distance <= start or end <= start:
		return 1.0 if distance <= end else min_mult
	return lerpf(1.0, min_mult, clampf((distance - start) / (end - start), 0.0, 1.0))


## Spread cone half-angle in degrees.
func spread_degrees(aiming: bool, moving: bool) -> float:
	var s: Dictionary = def.get("spread", {})
	if moving:
		return float(s.get("moving", 3.0)) * (0.6 if aiming else 1.0)
	return float(s.get("ads", 0.5)) if aiming else float(s.get("hip", 2.0))
