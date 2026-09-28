class_name MatchPhases
extends RefCounted
## Match state machine (GAME_SPEC §4):
## WAITING -> COUNTDOWN -> ROLE_REVEAL -> ACTIVE <-> INCIDENT_MEETING (-> RESUMING) -> MATCH_END -> RESULTS
## The match clock (for the time limit and sabotage grace) runs during ACTIVE and RESUMING only.

enum Phase { WAITING, COUNTDOWN, ROLE_REVEAL, ACTIVE, INCIDENT_MEETING, RESUMING, MATCH_END, RESULTS }

var phase := Phase.WAITING
var time_left := 0.0
var elapsed := 0.0  # match clock
var countdown := 5.0
var role_reveal := 7.0
var resuming := 3.0
var results := 20.0


func _init(flow: Dictionary = {}) -> void:
	countdown = float(flow.get("countdown_seconds", countdown))
	role_reveal = float(flow.get("role_reveal_seconds", role_reveal))
	resuming = float(flow.get("resuming_seconds", resuming))
	results = float(flow.get("results_seconds", results))


func start() -> bool:
	if phase != Phase.WAITING:
		return false
	_enter(Phase.COUNTDOWN, countdown)
	return true


## Advances timers; returns true when the phase changed by itself.
func tick(delta: float) -> bool:
	if phase == Phase.ACTIVE or phase == Phase.RESUMING:
		elapsed += delta
	match phase:
		Phase.COUNTDOWN, Phase.ROLE_REVEAL, Phase.RESUMING, Phase.MATCH_END:
			time_left -= delta
			if time_left <= 0.0:
				match phase:
					Phase.COUNTDOWN:
						_enter(Phase.ROLE_REVEAL, role_reveal)
					Phase.ROLE_REVEAL, Phase.RESUMING:
						_enter(Phase.ACTIVE, 0.0)
					Phase.MATCH_END:
						_enter(Phase.RESULTS, results)
				return true
	return false


func begin_meeting() -> bool:
	if phase != Phase.ACTIVE and phase != Phase.RESUMING:
		return false
	_enter(Phase.INCIDENT_MEETING, 0.0)
	return true


func end_meeting() -> bool:
	if phase != Phase.INCIDENT_MEETING:
		return false
	_enter(Phase.RESUMING, resuming)
	return true


func end_match() -> bool:
	if phase == Phase.MATCH_END or phase == Phase.RESULTS or phase == Phase.WAITING:
		return false
	_enter(Phase.MATCH_END, 3.0)
	return true


func is_playing() -> bool:
	return phase == Phase.ACTIVE or phase == Phase.RESUMING


func in_meeting() -> bool:
	return phase == Phase.INCIDENT_MEETING


func phase_name() -> String:
	return Phase.keys()[phase]


func _enter(p: int, duration: float) -> void:
	phase = p
	time_left = duration
