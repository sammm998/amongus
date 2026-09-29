extends GdUnitTestSuite

const CFG := {"range_m": 2.3, "cone_degrees": 60.0, "front_damage": 20.0, "backstab_damage": 1000.0, "backstab_cone_degrees": 75.0, "cooldown_seconds": 0.8}


func test_stab_from_behind_is_a_backstab() -> void:
	# Target at origin facing -Z; attacker behind it (+Z) facing -Z.
	var r := Melee.stab(Vector3(0, 0, 1.5), Vector3(0, 0, -1), Vector3.ZERO, Vector3(0, 0, -1), CFG)
	assert_bool(r["hit"]).is_true()
	assert_bool(r["backstab"]).is_true()
	assert_float(Melee.damage(r, CFG)).is_equal(1000.0)


func test_stab_from_the_front_is_weak() -> void:
	var r := Melee.stab(Vector3(0, 0, -1.5), Vector3(0, 0, 1), Vector3.ZERO, Vector3(0, 0, -1), CFG)
	assert_bool(r["hit"]).is_true()
	assert_bool(r["backstab"]).is_false()
	assert_float(Melee.damage(r, CFG)).is_equal(20.0)


func test_out_of_range_or_behind_attacker_misses() -> void:
	assert_bool(Melee.stab(Vector3(0, 0, 4), Vector3(0, 0, -1), Vector3.ZERO, Vector3(0, 0, -1), CFG)["hit"]).is_false()
	# Attacker faces away from the target.
	assert_bool(Melee.stab(Vector3(0, 0, 1.5), Vector3(0, 0, 1), Vector3.ZERO, Vector3(0, 0, -1), CFG)["hit"]).is_false()


func test_shot_budget_runs_out() -> void:
	var inv := Inventory.new()
	inv.shots_left = 3
	assert_bool(inv.take_shot()).is_true()
	assert_bool(inv.take_shot()).is_true()
	assert_bool(inv.take_shot()).is_true()
	assert_bool(inv.take_shot()).is_false()
	assert_int(inv.shots_left).is_equal(0)
	assert_bool(inv.select(Inventory.UTILITY)).is_true()
	assert_int(inv.active).is_equal(Inventory.UTILITY)
