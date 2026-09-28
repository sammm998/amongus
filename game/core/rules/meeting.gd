class_name Meeting
extends RefCounted
## Incident / emergency meeting (GAME_SPEC §5.4). Pure state machine.
## Phases: INCIDENT_REVIEW -> DISCUSSION -> [REVIVE_VOTE] -> SUSPECT_VOTE -> DONE.
## Revive vote only when the victim was still DOWNED when reported.
## Revive wins if REVIVE votes > KEEP votes (abstains don't count); a tie keeps
## the victim eliminated unless the host flipped `revive_tie_revives`.
## SUSPECT marker: nominated by >= suspect_threshold of living participants.

enum Phase { INCIDENT_REVIEW, DISCUSSION, REVIVE_VOTE, SUSPECT_VOTE, DONE }
enum Choice { REVIVE, KEEP, ABSTAIN }

const KIND_REPORT := "report"
const KIND_EMERGENCY := "emergency"

var kind := KIND_REPORT
var victim := -1
var reporter := -1
var victim_was_downed := false
var participants: Array = []
var phase := Phase.INCIDENT_REVIEW
var time_left := 0.0
var revive_votes: Dictionary = {}  # voter -> Choice
var nominations: Dictionary = {}   # voter -> target
var info: Dictionary = {}          # incident review data (public)
var _durations := {}
var _tie_revives := false
var _threshold := 0.4


func _init(p_kind: String, p_reporter: int, p_victim: int, p_victim_downed: bool, p_participants: Array, meeting_settings: Dictionary) -> void:
	kind = p_kind
	reporter = p_reporter
	victim = p_victim
	victim_was_downed = p_victim_downed and p_kind == KIND_REPORT
	participants = p_participants.duplicate()
	participants.erase(p_victim)
	_durations = {
		Phase.INCIDENT_REVIEW: float(meeting_settings["incident_review_seconds"]),
		Phase.DISCUSSION: float(meeting_settings["discussion_seconds"]),
		Phase.REVIVE_VOTE: float(meeting_settings["revive_vote_seconds"]),
		Phase.SUSPECT_VOTE: float(meeting_settings["suspect_vote_seconds"]),
	}
	_tie_revives = bool(meeting_settings.get("revive_tie_revives", false))
	_threshold = float(meeting_settings.get("suspect_threshold", 0.4))
	phase = Phase.INCIDENT_REVIEW
	time_left = _durations[phase]


func has_revive_vote() -> bool:
	return kind == KIND_REPORT and victim_was_downed


func is_done() -> bool:
	return phase == Phase.DONE


## Returns true when the phase changed.
func tick(delta: float) -> bool:
	if phase == Phase.DONE:
		return false
	time_left -= delta
	if time_left <= 0.0:
		advance()
		return true
	return false


func advance() -> void:
	match phase:
		Phase.INCIDENT_REVIEW:
			_enter(Phase.DISCUSSION)
		Phase.DISCUSSION:
			_enter(Phase.REVIVE_VOTE if has_revive_vote() else Phase.SUSPECT_VOTE)
		Phase.REVIVE_VOTE:
			_enter(Phase.SUSPECT_VOTE)
		Phase.SUSPECT_VOTE:
			_enter(Phase.DONE)


func _enter(p: int) -> void:
	phase = p
	time_left = _durations.get(p, 0.0)


func can_vote(voter: int) -> bool:
	return voter in participants and voter != victim


## Participant who dropped out (disconnect) no longer counts.
func remove_participant(player: int) -> void:
	participants.erase(player)
	revive_votes.erase(player)
	nominations.erase(player)


func cast_revive(voter: int, choice: int) -> bool:
	if phase != Phase.REVIVE_VOTE or not can_vote(voter) or revive_votes.has(voter):
		return false
	if choice < Choice.REVIVE or choice > Choice.ABSTAIN:
		return false
	revive_votes[voter] = choice
	if revive_votes.size() >= participants.size():
		advance()  # everyone voted: move on early
	return true


func nominate(voter: int, target: int, valid_targets: Array) -> bool:
	if phase != Phase.SUSPECT_VOTE or not can_vote(voter) or nominations.has(voter):
		return false
	if target == voter or not (target in valid_targets):
		return false
	nominations[voter] = target
	return true


## Skip nomination (counts as "voted" for early phase end).
func skip_nomination(voter: int) -> bool:
	if phase != Phase.SUSPECT_VOTE or not can_vote(voter) or nominations.has(voter):
		return false
	nominations[voter] = -1
	if nominations.size() >= participants.size():
		advance()
	return true


func revive_tally() -> Dictionary:
	var t := {"revive": 0, "keep": 0, "abstain": 0}
	for c: int in revive_votes.values():
		match c:
			Choice.REVIVE:
				t["revive"] += 1
			Choice.KEEP:
				t["keep"] += 1
			_:
				t["abstain"] += 1
	return t


func revive_result() -> bool:
	if not has_revive_vote():
		return false
	var t := revive_tally()
	if t["revive"] == t["keep"]:
		return _tie_revives and t["revive"] > 0
	return t["revive"] > t["keep"]


## Players who reached the SUSPECT threshold.
func suspects() -> Array:
	var counts := {}
	for target: int in nominations.values():
		if target >= 0:
			counts[target] = counts.get(target, 0) + 1
	var needed := _threshold * float(participants.size())
	var out: Array = []
	for target: int in counts:
		if float(counts[target]) + 0.0001 >= needed and counts[target] > 0:
			out.append(target)
	out.sort()
	return out


static func phase_name(p: int) -> String:
	return Phase.keys()[p]
