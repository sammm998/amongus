class_name Vitals
extends RefCounted
## Health, shield, downed/bleed-out, spawn protection and stun (GAME_SPEC §5.3).
## Any damage to a downed player eliminates them ("finishing"). No field revive.

enum State { ALIVE, DOWNED, ELIMINATED }

const RESULT_NONE := "none"
const RESULT_PROTECTED := "protected"
const RESULT_DAMAGED := "damaged"
const RESULT_DOWNED := "downed"
const RESULT_FINISHED := "finished"

var max_health := 100.0
var max_shield := 50.0
var health := 100.0
var shield := 0.0
var state := State.ALIVE
var bleed_seconds := 90.0
var bleed_enabled := true
var bleed_left := 0.0
var protection_left := 0.0
var stun_left := 0.0
var downed_at := -1.0
var eliminated_at := -1.0


func _init(p_max_health: float = 100.0, p_max_shield: float = 50.0, p_bleed_seconds: float = 90.0, p_bleed_enabled: bool = true) -> void:
	max_health = p_max_health
	max_shield = p_max_shield
	health = p_max_health
	bleed_seconds = p_bleed_seconds
	bleed_enabled = p_bleed_enabled


func is_living() -> bool:
	return state == State.ALIVE


## Returns {result, shield_damage, health_damage}.
func apply_damage(amount: float, now: float = 0.0) -> Dictionary:
	var out := {"result": RESULT_NONE, "shield_damage": 0.0, "health_damage": 0.0}
	if amount <= 0.0 or state == State.ELIMINATED:
		return out
	if state == State.DOWNED:
		state = State.ELIMINATED
		eliminated_at = now
		out["result"] = RESULT_FINISHED
		return out
	if protection_left > 0.0:
		out["result"] = RESULT_PROTECTED
		return out
	var absorbed := minf(shield, amount)
	shield -= absorbed
	var rest := amount - absorbed
	health -= rest
	out["shield_damage"] = absorbed
	out["health_damage"] = rest
	if health <= 0.0:
		health = 0.0
		state = State.DOWNED
		bleed_left = bleed_seconds
		downed_at = now
		stun_left = 0.0
		out["result"] = RESULT_DOWNED
	else:
		out["result"] = RESULT_DAMAGED
	return out


## Advances timers. Bleed-out pauses while `paused` (meetings). Returns "bled_out" or "".
func tick(delta: float, paused: bool, now: float = 0.0) -> String:
	if paused:
		return ""
	protection_left = maxf(0.0, protection_left - delta)
	stun_left = maxf(0.0, stun_left - delta)
	if state == State.DOWNED and bleed_enabled:
		bleed_left -= delta
		if bleed_left <= 0.0:
			bleed_left = 0.0
			state = State.ELIMINATED
			eliminated_at = now
			return "bled_out"
	return ""


func eliminate(now: float = 0.0) -> void:
	if state != State.ELIMINATED:
		state = State.ELIMINATED
		eliminated_at = now


## Meeting revive: back to ALIVE with reduced health and spawn protection.
func revive(p_health: float, p_shield: float, protection: float) -> void:
	state = State.ALIVE
	health = clampf(p_health, 1.0, max_health)
	shield = clampf(p_shield, 0.0, max_shield)
	protection_left = protection
	bleed_left = 0.0
	stun_left = 0.0


func heal(amount: float) -> void:
	if state == State.ALIVE:
		health = minf(max_health, health + amount)


func add_shield(amount: float) -> void:
	if state == State.ALIVE:
		shield = minf(max_shield, shield + amount)


func stun(seconds: float) -> void:
	if state == State.ALIVE and protection_left <= 0.0:
		stun_left = maxf(stun_left, seconds)


func is_stunned() -> bool:
	return stun_left > 0.0
