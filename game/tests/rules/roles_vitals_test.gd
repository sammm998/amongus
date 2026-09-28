extends GdUnitTestSuite
## GAME_SPEC §5.1 roles and §5.3 health/downed/bleed-out.

var _lobby: Dictionary


func before() -> void:
	_lobby = GameDataRegistry.read_json("res://data/lobby_defaults.json")


func test_traitor_count_table() -> void:
	var expected := {8: 1, 10: 2, 12: 2, 16: 3, 20: 3, 24: 4}
	for players: int in expected:
		assert_int(RoleAssigner.traitor_count(players, _lobby)).override_failure_message("%d players" % players).is_equal(expected[players])


func test_traitor_count_small_and_override() -> void:
	assert_int(RoleAssigner.traitor_count(2, _lobby)).is_equal(1)
	assert_int(RoleAssigner.traitor_count(1, _lobby)).is_equal(0)
	assert_int(RoleAssigner.traitor_count(12, _lobby, 3)).is_equal(3)
	assert_int(RoleAssigner.traitor_count(4, _lobby, 9)).is_equal(3)


func test_assign_exact_count_and_all_players() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ids := [2, 3, 4, 5, 6, 7, 8, 9]
	var roles := RoleAssigner.assign(ids, 2, rng)
	assert_int(roles.size()).is_equal(8)
	assert_int(roles.values().count(RoleAssigner.Role.TRAITOR)).is_equal(2)


func test_assign_is_random() -> void:
	var seen := {}
	for s in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var roles := RoleAssigner.assign([1, 2, 3, 4, 5, 6], 1, rng)
		for id: int in roles:
			if roles[id] == RoleAssigner.Role.TRAITOR:
				seen[id] = true
	assert_int(seen.size()).is_greater(3)


func test_shield_absorbs_first() -> void:
	var v := Vitals.new(100, 50, 90)
	v.shield = 30
	var r := v.apply_damage(40)
	assert_float(r["shield_damage"]).is_equal(30.0)
	assert_float(v.health).is_equal(90.0)
	assert_str(r["result"]).is_equal(Vitals.RESULT_DAMAGED)


func test_zero_health_downs() -> void:
	var v := Vitals.new(100, 50, 90)
	var r := v.apply_damage(150)
	assert_str(r["result"]).is_equal(Vitals.RESULT_DOWNED)
	assert_int(v.state).is_equal(Vitals.State.DOWNED)
	assert_float(v.bleed_left).is_equal(90.0)
	assert_bool(v.is_living()).is_false()


func test_any_damage_to_downed_finishes() -> void:
	var v := Vitals.new()
	v.apply_damage(100)
	var r := v.apply_damage(0.5)
	assert_str(r["result"]).is_equal(Vitals.RESULT_FINISHED)
	assert_int(v.state).is_equal(Vitals.State.ELIMINATED)


func test_bleed_out_and_pause() -> void:
	var v := Vitals.new(100, 50, 10)
	v.apply_damage(100)
	assert_str(v.tick(20.0, true)).is_empty()
	assert_int(v.state).is_equal(Vitals.State.DOWNED)
	v.tick(9.0, false)
	assert_int(v.state).is_equal(Vitals.State.DOWNED)
	assert_str(v.tick(1.5, false)).is_equal("bled_out")
	assert_int(v.state).is_equal(Vitals.State.ELIMINATED)


func test_bleed_out_disabled() -> void:
	var v := Vitals.new(100, 50, 10, false)
	v.apply_damage(100)
	v.tick(1000.0, false)
	assert_int(v.state).is_equal(Vitals.State.DOWNED)


func test_revive_and_spawn_protection() -> void:
	var v := Vitals.new()
	v.apply_damage(100)
	v.revive(50, 0, 5)
	assert_int(v.state).is_equal(Vitals.State.ALIVE)
	assert_float(v.health).is_equal(50.0)
	assert_str(v.apply_damage(30)["result"]).is_equal(Vitals.RESULT_PROTECTED)
	v.tick(5.1, false)
	assert_str(v.apply_damage(30)["result"]).is_equal(Vitals.RESULT_DAMAGED)


func test_eliminated_ignores_damage() -> void:
	var v := Vitals.new()
	v.eliminate()
	assert_str(v.apply_damage(10)["result"]).is_equal(Vitals.RESULT_NONE)


func test_stun() -> void:
	var v := Vitals.new()
	v.stun(4.0)
	assert_bool(v.is_stunned()).is_true()
	v.tick(4.1, false)
	assert_bool(v.is_stunned()).is_false()
