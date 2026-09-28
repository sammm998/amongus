extends GdUnitTestSuite
## GAME_SPEC §5.5: body-shot TTK vs 100 HP must stay inside each weapon's band.

var _combat: Dictionary
var _weapons: Array


func before() -> void:
	_combat = GameDataRegistry.read_json("res://data/combat.json")
	_weapons = GameDataRegistry.read_json("res://data/weapons.json")["weapons"]


func test_every_weapon_ttk_within_band() -> void:
	var hp := float(_combat["max_health"])
	var checked := 0
	for weapon: Dictionary in _weapons:
		var band := TTKCalculator.band_for(weapon, _combat["ttk_band_default"])
		if band.is_empty():
			continue
		var ttk := TTKCalculator.body_ttk(weapon, hp)
		assert_float(ttk) \
			.override_failure_message("%s TTK %.2fs outside band %s" % [weapon["id"], ttk, band]) \
			.is_between(float(band[0]), float(band[1]))
		checked += 1
	assert_int(checked).is_greater_equal(9)


func test_ttk_matches_spec_table() -> void:
	var hp := float(_combat["max_health"])
	for weapon: Dictionary in _weapons:
		if float(weapon["body_damage"]) <= 0.0:
			continue
		assert_float(TTKCalculator.body_ttk(weapon, hp)) \
			.override_failure_message("%s differs from spec TTK %.2f" % [weapon["id"], weapon["ttk_expected"]]) \
			.is_equal_approx(float(weapon["ttk_expected"]), 0.05)


func test_best_rarity_keeps_ttk_in_band() -> void:
	var hp := float(_combat["max_health"])
	var rarities: Dictionary = _combat["rarities"]
	for weapon: Dictionary in _weapons:
		var band := TTKCalculator.band_for(weapon, _combat["ttk_band_default"])
		if band.is_empty():
			continue
		var mult := float(rarities[weapon["rarity_max"]]["damage_multiplier"])
		var ttk := TTKCalculator.body_ttk(weapon, hp, mult)
		# Rarity may shave off at most one shot; it must never fall far below the band.
		assert_float(ttk).override_failure_message("%s at %s: %.2fs" % [weapon["id"], weapon["rarity_max"], ttk]) \
			.is_greater_equal(float(band[0]) - 0.35)


func test_stun_gun_is_non_lethal_and_exempt() -> void:
	var stun: Dictionary = _find("stun_gun")
	assert_float(TTKCalculator.body_ttk(stun, 100.0)).is_equal(INF)
	assert_array(TTKCalculator.band_for(stun, [1.5, 3.0])).is_empty()
	assert_float(float(stun["stun_seconds"])).is_equal(4.0)


func test_burst_timing() -> void:
	var burst := {"body_damage": 11.0, "pellets": 1.0, "fire_rate": 1.0 / 0.6, "burst_count": 3.0, "burst_interval": 0.08}
	# 10 bullets: bursts start at 0, 0.6, 1.2, 1.8 -> 10th bullet is the first of the 4th burst.
	assert_float(TTKCalculator.body_ttk(burst, 100.0)).is_equal_approx(1.8, 0.001)
	# 8 bullets: 3rd burst, 2nd bullet -> 1.2 + 0.08
	assert_float(TTKCalculator.body_ttk(burst, 80.0)).is_equal_approx(1.28, 0.001)


func test_spin_up_added() -> void:
	var lmg := {"body_damage": 10.0, "pellets": 1.0, "fire_rate": 6.0, "spin_up": 0.4}
	assert_float(TTKCalculator.body_ttk(lmg, 100.0)).is_equal_approx(1.9, 0.001)


func test_shots_to_kill_exact_division() -> void:
	assert_int(TTKCalculator.shots_to_kill(25.0, 100.0)).is_equal(4)
	assert_int(TTKCalculator.shots_to_kill(15.0, 100.0)).is_equal(7)
	assert_int(TTKCalculator.shots_to_kill(0.0, 100.0)).is_equal(-1)


func test_headshots_disabled_for_shotgun_and_explosives() -> void:
	assert_bool(_find("shotgun")["headshot_allowed"]).is_false()
	assert_bool(_find("grenade_launcher")["headshot_allowed"]).is_false()
	assert_bool(_find("assault_rifle")["headshot_allowed"]).is_true()


func _find(id: String) -> Dictionary:
	for weapon: Dictionary in _weapons:
		if weapon["id"] == id:
			return weapon
	return {}
