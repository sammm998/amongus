extends GdUnitTestSuite
## GAME_SPEC §5.2 win conditions, §5.6 tasks, §5.7 sabotage, match phases, comms.

const A := RoleAssigner.Role.AGENT
const T := RoleAssigner.Role.TRAITOR
const ALIVE := Vitals.State.ALIVE
const DOWNED := Vitals.State.DOWNED
const OUT := Vitals.State.ELIMINATED


func _p(role: int, state: int) -> Dictionary:
	return {"role": role, "state": state}


func test_agents_win_when_all_traitors_eliminated() -> void:
	var r := WinRules.evaluate([_p(A, ALIVE), _p(A, ALIVE), _p(T, OUT)], 10.0, false, 0.0, 1500.0)
	assert_int(r["winner"]).is_equal(WinRules.Winner.AGENTS)


func test_downed_traitor_is_not_eliminated() -> void:
	var r := WinRules.evaluate([_p(A, ALIVE), _p(A, ALIVE), _p(T, DOWNED)], 10.0, false, 0.0, 1500.0)
	assert_int(r["winner"]).is_equal(WinRules.Winner.NONE)


func test_agents_win_on_full_security() -> void:
	var r := WinRules.evaluate([_p(A, ALIVE), _p(A, ALIVE), _p(T, ALIVE)], 100.0, false, 0.0, 1500.0)
	assert_str(r["reason"]).is_equal("security_complete")


func test_traitors_win_when_equal_living_downed_not_counted() -> void:
	var r := WinRules.evaluate([_p(A, ALIVE), _p(A, DOWNED), _p(T, ALIVE)], 10.0, false, 0.0, 1500.0)
	assert_int(r["winner"]).is_equal(WinRules.Winner.TRAITORS)
	assert_str(r["reason"]).is_equal("traitors_outnumber")


func test_traitors_win_on_critical_and_time_limit() -> void:
	var players := [_p(A, ALIVE), _p(A, ALIVE), _p(A, ALIVE), _p(T, ALIVE)]
	assert_str(WinRules.evaluate(players, 10.0, true, 0.0, 1500.0)["reason"]).is_equal("island_control_lost")
	assert_str(WinRules.evaluate(players, 10.0, false, 1500.0, 1500.0)["reason"]).is_equal("time_limit")
	assert_int(WinRules.evaluate(players, 10.0, false, 100.0, 1500.0)["winner"]).is_equal(WinRules.Winner.NONE)


func _board(agents: Array, traitors: Array, count: int) -> TaskBoard:
	var board := TaskBoard.new(GameDataRegistry.read_json("res://data/tasks.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	board.assign(agents, traitors, count, {}, rng)
	return board


func test_tasks_assigned_equal_length_and_distinct() -> void:
	var board := _board([1, 2, 3], [4], 6)
	for pid in [1, 2, 3, 4]:
		var ids: Array = board.tasks_for(pid).map(func(t: Dictionary) -> String: return t["id"])
		assert_int(ids.size()).is_equal(6)
		var unique := {}
		for id: String in ids:
			unique[id] = true
		assert_int(unique.size()).is_equal(6)


func test_required_scales_with_agents() -> void:
	var small := _board([1, 2], [3], 4)
	var big := _board([1, 2, 3, 4, 5, 6], [7], 4)
	assert_float(big.required).is_greater(small.required * 2.5)


func _finish_all(board: TaskBoard, pid: int) -> void:
	for i in board.tasks_for(pid).size():
		while not board.tasks_for(pid)[i]["done"]:
			var t: Dictionary = board.tasks_for(pid)[i]
			var step: Dictionary = t["steps"][t["step"]]
			var r := board.complete_step(pid, i, step["station"], step["hold"])
			assert_bool(r["ok"]).is_true()


func test_completing_all_agent_tasks_reaches_100() -> void:
	var board := _board([1, 2], [3], 3)
	_finish_all(board, 1)
	assert_float(board.security_percent()).is_between(1.0, 99.0)
	_finish_all(board, 2)
	assert_float(board.security_percent()).is_equal(100.0)


func test_fake_traitor_tasks_give_no_progress() -> void:
	var board := _board([1], [2], 3)
	_finish_all(board, 2)
	assert_float(board.security_percent()).is_equal(0.0)
	assert_bool(board.tasks_for(2).all(func(t: Dictionary) -> bool: return t["done"])).is_true()


func test_step_validation() -> void:
	var board := _board([1], [], 3)
	var t: Dictionary = board.tasks_for(1)[0]
	var step: Dictionary = t["steps"][0]
	assert_str(board.complete_step(1, 0, "nowhere", 99.0)["reason"]).is_equal("wrong_station")
	if float(step["hold"]) > 1.0:
		assert_str(board.complete_step(1, 0, step["station"], 0.1)["reason"]).is_equal("too_fast")
	assert_str(board.complete_step(1, 99, step["station"], 99.0)["reason"]).is_equal("no_task")


func test_multi_step_needs_sequence() -> void:
	var board := TaskBoard.new(GameDataRegistry.read_json("res://data/tasks.json"))
	board.pool = {"deliver_medical": board.pool["deliver_medical"]}
	var rng := RandomNumberGenerator.new()
	board.assign([1], [], 1, {}, rng)
	assert_str(board.complete_step(1, 0, "med_pharmacy", 5.0)["reason"]).is_equal("wrong_station")
	assert_bool(board.complete_step(1, 0, "harbor_cargo", 5.0)["ok"]).is_true()
	assert_bool(board.tasks_for(1)[0]["done"]).is_false()
	assert_bool(board.complete_step(1, 0, "med_pharmacy", 5.0)["task_done"]).is_true()


func _sab() -> SabotageSystem:
	return SabotageSystem.new(GameDataRegistry.read_json("res://data/sabotages.json"))


func test_sabotage_blocked_in_grace_and_meetings() -> void:
	var s := _sab()
	assert_str(s.can_trigger("blackout", "harbor", 10.0, 30.0, false, 60.0)).is_equal("grace")
	assert_str(s.can_trigger("blackout", "harbor", 100.0, 100.0, true, 60.0)).is_equal("meeting")
	assert_str(s.can_trigger("blackout", "harbor", 100.0, 100.0, false, 60.0)).is_empty()


func test_team_and_kind_cooldowns() -> void:
	var s := _sab()
	s.trigger("blackout", "harbor", 100.0)
	assert_str(s.can_trigger("camera_jam", "harbor", 110.0, 110.0, false, 60.0)).is_equal("team_cooldown")
	assert_str(s.can_trigger("camera_jam", "harbor", 131.0, 131.0, false, 60.0)).is_empty()
	assert_str(s.can_trigger("blackout", "medical", 131.0, 131.0, false, 60.0)).is_equal("cooldown")
	assert_str(s.can_trigger("blackout", "medical", 191.0, 191.0, false, 60.0)).is_empty()


func test_only_one_critical() -> void:
	var s := _sab()
	s.trigger("power_failure", "", 100.0)
	s.team_ready_at = 0.0
	s.ready_at["power_failure"] = 0.0
	assert_str(s.can_trigger("power_failure", "", 200.0, 200.0, false, 60.0)).is_equal("critical_active")


func test_non_critical_auto_ends_and_timers_pause() -> void:
	var s := _sab()
	s.trigger("blackout", "harbor", 100.0)
	assert_array(s.tick(100.0, true)).is_empty()
	assert_bool(s.is_active("blackout", "harbor")).is_true()
	var ev := s.tick(60.1, false)
	assert_str(ev[0]["type"]).is_equal("ended")
	assert_bool(s.is_active("blackout", "harbor")).is_false()


func test_power_failure_countdown_and_generator_repair() -> void:
	var s := _sab()
	s.trigger("power_failure", "", 100.0)
	assert_bool(s.power_out()).is_true()
	assert_bool(s.camera_jammed("harbor")).is_true()
	assert_bool(s.repair("power_failure", "", "gen_a")["repaired"]).is_false()
	assert_bool(s.repair("power_failure", "", "gen_a")["repaired"]).is_false()
	assert_bool(s.repair("power_failure", "", "gen_b")["repaired"]).is_true()
	assert_bool(s.power_out()).is_false()
	var s2 := _sab()
	s2.trigger("power_failure", "", 0.0)
	var ev := s2.tick(90.1, false)
	assert_str(ev[0]["type"]).is_equal("critical_expired")


func test_blackout_repair_at_breaker() -> void:
	var s := _sab()
	s.trigger("blackout", "harbor", 100.0)
	assert_bool(s.repair("blackout", "medical")["repaired"]).is_false()
	assert_bool(s.repair("blackout", "harbor")["repaired"]).is_true()


func test_sabotage_state_never_names_the_saboteur() -> void:
	var s := _sab()
	s.trigger("blackout", "harbor", 100.0)
	for entry: Dictionary in s.public_state():
		for key: String in entry:
			assert_bool(key in ["kind", "district", "time_left", "critical", "progress"]).is_true()


func test_match_phase_flow() -> void:
	var m := MatchPhases.new({"countdown_seconds": 1.0, "role_reveal_seconds": 1.0, "resuming_seconds": 1.0, "results_seconds": 1.0})
	assert_bool(m.start()).is_true()
	m.tick(1.1)
	assert_int(m.phase).is_equal(MatchPhases.Phase.ROLE_REVEAL)
	m.tick(1.1)
	assert_int(m.phase).is_equal(MatchPhases.Phase.ACTIVE)
	m.tick(10.0)
	assert_float(m.elapsed).is_equal(10.0)
	assert_bool(m.begin_meeting()).is_true()
	m.tick(50.0)
	assert_float(m.elapsed).is_equal(10.0)
	assert_bool(m.end_meeting()).is_true()
	assert_int(m.phase).is_equal(MatchPhases.Phase.RESUMING)
	m.tick(1.1)
	assert_int(m.phase).is_equal(MatchPhases.Phase.ACTIVE)
	assert_bool(m.end_match()).is_true()
	m.tick(3.1)
	assert_int(m.phase).is_equal(MatchPhases.Phase.RESULTS)


func test_downed_cannot_communicate_at_all() -> void:
	assert_str(CommsRules.sender_channel(DOWNED, false, false)).is_empty()
	assert_str(CommsRules.sender_channel(DOWNED, true, false)).is_empty()


func test_meeting_victim_muted_and_dead_channel() -> void:
	assert_str(CommsRules.sender_channel(ALIVE, true, true)).is_empty()
	assert_str(CommsRules.sender_channel(ALIVE, true, false)).is_equal(CommsRules.MEETING)
	assert_str(CommsRules.sender_channel(OUT, true, false)).is_equal(CommsRules.DEAD)
	assert_bool(CommsRules.can_receive(CommsRules.DEAD, ALIVE, 0.0, 30.0)).is_false()
	assert_bool(CommsRules.can_receive(CommsRules.DEAD, OUT, 0.0, 30.0)).is_true()
	assert_bool(CommsRules.can_receive(CommsRules.PROXIMITY, ALIVE, 40.0, 30.0)).is_false()


func test_match_settings_mode_overrides() -> void:
	var lobby: Dictionary = GameDataRegistry.read_json("res://data/lobby_defaults.json")
	var modes: Dictionary = GameDataRegistry.read_json("res://data/modes.json")
	var casual := MatchSettings.build(lobby, modes, "casual")
	assert_bool(casual["meeting"]["revive_tie_revives"]).is_true()
	assert_float(float(casual["meeting"]["discussion_seconds"])).is_equal(60.0)
	var custom := MatchSettings.build(lobby, modes, "standard", {"bleed_out_seconds": 30.0})
	assert_float(float(custom["bleed_out_seconds"])).is_equal(30.0)
	assert_float(float(lobby["bleed_out_seconds"])).is_equal(90.0)
