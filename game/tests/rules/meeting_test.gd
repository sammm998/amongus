extends GdUnitTestSuite
## GAME_SPEC §5.4 meetings, revive vote, suspect vote, ties.

var _settings: Dictionary


func before() -> void:
	_settings = GameDataRegistry.read_json("res://data/lobby_defaults.json")["meeting"]


func _report(downed: bool, participants := [1, 2, 3, 4, 5, 6]) -> Meeting:
	return Meeting.new(Meeting.KIND_REPORT, 1, 9, downed, participants, _settings)


func test_phase_order_with_revive_vote() -> void:
	var m := _report(true)
	assert_int(m.phase).is_equal(Meeting.Phase.INCIDENT_REVIEW)
	assert_float(m.time_left).is_equal(8.0)
	m.tick(8.01)
	assert_int(m.phase).is_equal(Meeting.Phase.DISCUSSION)
	assert_float(m.time_left).is_equal(45.0)
	m.tick(45.01)
	assert_int(m.phase).is_equal(Meeting.Phase.REVIVE_VOTE)
	assert_float(m.time_left).is_equal(20.0)
	m.tick(20.01)
	assert_int(m.phase).is_equal(Meeting.Phase.SUSPECT_VOTE)
	m.tick(15.01)
	assert_bool(m.is_done()).is_true()


func test_no_revive_vote_if_victim_already_eliminated_or_emergency() -> void:
	var m := _report(false)
	m.tick(8.01)
	m.tick(45.01)
	assert_int(m.phase).is_equal(Meeting.Phase.SUSPECT_VOTE)
	var e := Meeting.new(Meeting.KIND_EMERGENCY, 1, -1, true, [1, 2, 3], _settings)
	assert_bool(e.has_revive_vote()).is_false()


func _to_revive(m: Meeting) -> void:
	m.tick(8.01)
	m.tick(45.01)


func test_majority_revives() -> void:
	var m := _report(true)
	_to_revive(m)
	m.cast_revive(1, Meeting.Choice.REVIVE)
	m.cast_revive(2, Meeting.Choice.REVIVE)
	m.cast_revive(3, Meeting.Choice.KEEP)
	m.cast_revive(4, Meeting.Choice.ABSTAIN)
	assert_bool(m.revive_result()).is_true()


func test_tie_keeps_eliminated_unless_flipped() -> void:
	var m := _report(true)
	_to_revive(m)
	m.cast_revive(1, Meeting.Choice.REVIVE)
	m.cast_revive(2, Meeting.Choice.KEEP)
	assert_bool(m.revive_result()).is_false()
	var flipped := _settings.duplicate()
	flipped["revive_tie_revives"] = true
	var m2 := Meeting.new(Meeting.KIND_REPORT, 1, 9, true, [1, 2, 3], flipped)
	_to_revive(m2)
	m2.cast_revive(1, Meeting.Choice.REVIVE)
	m2.cast_revive(2, Meeting.Choice.KEEP)
	assert_bool(m2.revive_result()).is_true()


func test_no_votes_keeps_eliminated() -> void:
	var m := _report(true)
	_to_revive(m)
	assert_bool(m.revive_result()).is_false()


func test_victim_cannot_vote_and_no_double_votes() -> void:
	var m := Meeting.new(Meeting.KIND_REPORT, 1, 3, true, [1, 2, 3, 4], _settings)
	_to_revive(m)
	assert_bool(m.cast_revive(3, Meeting.Choice.REVIVE)).is_false()
	assert_bool(m.cast_revive(1, Meeting.Choice.REVIVE)).is_true()
	assert_bool(m.cast_revive(1, Meeting.Choice.KEEP)).is_false()
	assert_bool(m.cast_revive(42, Meeting.Choice.KEEP)).is_false()


func test_votes_only_in_their_phase() -> void:
	var m := _report(true)
	assert_bool(m.cast_revive(1, Meeting.Choice.REVIVE)).is_false()
	assert_bool(m.nominate(1, 2, [1, 2, 3])).is_false()


func test_everyone_voted_ends_phase_early() -> void:
	var m := _report(true, [1, 2, 3])
	_to_revive(m)
	m.cast_revive(1, Meeting.Choice.KEEP)
	m.cast_revive(2, Meeting.Choice.KEEP)
	m.cast_revive(3, Meeting.Choice.KEEP)
	assert_int(m.phase).is_equal(Meeting.Phase.SUSPECT_VOTE)


func test_suspect_threshold_forty_percent() -> void:
	var m := _report(false, [1, 2, 3, 4, 5])  # threshold 2 of 5
	m.tick(8.01)
	m.tick(45.01)
	var targets := [1, 2, 3, 4, 5]
	assert_bool(m.nominate(1, 4, targets)).is_true()
	assert_bool(m.nominate(2, 4, targets)).is_true()
	assert_bool(m.nominate(3, 5, targets)).is_true()
	assert_array(m.suspects()).contains_exactly([4])


func test_cannot_nominate_self_or_invalid() -> void:
	var m := _report(false, [1, 2, 3])
	m.tick(8.01)
	m.tick(45.01)
	assert_bool(m.nominate(1, 1, [1, 2, 3])).is_false()
	assert_bool(m.nominate(1, 77, [1, 2, 3])).is_false()


func test_nobody_nominates_no_suspects() -> void:
	var m := _report(false, [1, 2, 3])
	m.tick(8.01)
	m.tick(45.01)
	m.tick(15.01)
	assert_array(m.suspects()).is_empty()


func test_victim_removed_from_participants() -> void:
	var m := Meeting.new(Meeting.KIND_REPORT, 1, 2, true, [1, 2, 3], _settings)
	assert_bool(2 in m.participants).is_false()
