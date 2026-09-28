extends GdUnitTestSuite
## GAME_SPEC §5.5 weapon timing, ammo, reload, damage modifiers.

var _weapons := {}
var _combat: Dictionary


func before() -> void:
	_combat = GameDataRegistry.read_json("res://data/combat.json")
	for w: Dictionary in GameDataRegistry.read_json("res://data/weapons.json")["weapons"]:
		_weapons[w["id"]] = w


func test_fire_rate_enforced() -> void:
	var w := WeaponInstance.create(_weapons["pistol"])
	assert_int(w.fire(0.0)).is_equal(1)
	assert_int(w.fire(0.2)).is_equal(0)
	assert_int(w.fire(1.0 / 3.0)).is_equal(1)
	assert_int(w.mag).is_equal(10)


func test_empty_mag_cannot_fire_and_reload_refills() -> void:
	var w := WeaponInstance.create(_weapons["pistol"])
	w.mag = 0
	assert_int(w.fire(0.0)).is_equal(0)
	assert_bool(w.start_reload(0.0, 24)).is_true()
	assert_int(w.update(1.0, 24)).is_equal(0)
	assert_int(w.update(1.5, 24)).is_equal(12)
	assert_int(w.mag).is_equal(12)


func test_reload_limited_by_reserve_and_no_reload_when_full() -> void:
	var w := WeaponInstance.create(_weapons["pistol"])
	assert_bool(w.start_reload(0.0, 24)).is_false()
	w.mag = 2
	w.start_reload(0.0, 5)
	assert_int(w.update(2.0, 5)).is_equal(5)
	assert_int(w.mag).is_equal(7)


func test_cannot_fire_while_reloading() -> void:
	var w := WeaponInstance.create(_weapons["assault_rifle"])
	w.mag = 3
	w.start_reload(0.0, 30)
	assert_int(w.fire(1.0)).is_equal(0)


func test_shotgun_reloads_shell_by_shell() -> void:
	var w := WeaponInstance.create(_weapons["shotgun"])
	w.mag = 3
	w.start_reload(0.0, 10)
	assert_int(w.update(0.5, 10)).is_equal(1)
	assert_bool(w.is_reloading()).is_true()
	assert_int(w.update(1.0, 9)).is_equal(1)
	assert_bool(w.is_reloading()).is_false()
	assert_int(w.mag).is_equal(5)
	assert_int(w.fire(2.0)).is_equal(8)


func test_burst_rifle_timing() -> void:
	var w := WeaponInstance.create(_weapons["burst_rifle"])
	assert_int(w.fire(0.0)).is_equal(1)
	assert_int(w.fire(0.05)).is_equal(0)
	assert_int(w.fire(0.08)).is_equal(1)
	assert_int(w.fire(0.16)).is_equal(1)
	assert_int(w.fire(0.3)).is_equal(0)
	assert_int(w.fire(0.6)).is_equal(1)


func test_lmg_spin_up() -> void:
	var w := WeaponInstance.create(_weapons["lmg"])
	w.set_trigger(true, 0.0)
	assert_int(w.fire(0.2)).is_equal(0)
	assert_int(w.fire(0.4)).is_equal(1)
	w.set_trigger(false, 0.5)
	w.set_trigger(true, 0.6)
	assert_int(w.fire(0.7)).is_equal(0)


func test_headshot_multiplier_and_exceptions() -> void:
	var ar := WeaponInstance.create(_weapons["assault_rifle"])
	assert_float(ar.damage_at(5.0, true, _combat)).is_equal_approx(18.0, 0.001)
	var sg := WeaponInstance.create(_weapons["shotgun"])
	assert_float(sg.damage_at(1.0, true, _combat)).is_equal_approx(8.0, 0.001)


func test_falloff() -> void:
	var sg := WeaponInstance.create(_weapons["shotgun"])
	assert_float(sg.falloff(5.0)).is_equal(1.0)
	assert_float(sg.falloff(30.0)).is_equal_approx(0.2, 0.001)
	assert_float(sg.falloff(14.0)).is_between(0.2, 1.0)


func test_rarity_bonus_capped() -> void:
	var w := WeaponInstance.create(_weapons["assault_rifle"], "prototype")
	assert_float(w.damage_at(1.0, false, _combat)).is_less_equal(12.0 * 1.1 + 0.001)


func test_ray_capsule_and_head() -> void:
	var feet := Vector3(0, 0, -10)
	var body := HitscanMath.test_player(Vector3(0, 1.0, 0), Vector3(0, 0, -1), feet, 1.7, 0.38, 1.5, 0.34)
	assert_bool(body["hit"]).is_true()
	assert_bool(body["headshot"]).is_false()
	assert_float(body["distance"]).is_equal_approx(9.62, 0.01)
	var head := HitscanMath.test_player(Vector3(0, 1.55, 0), Vector3(0, 0, -1), feet, 1.7, 0.38, 1.5, 0.34)
	assert_bool(head["headshot"]).is_true()
	var miss := HitscanMath.test_player(Vector3(2, 1.0, 0), Vector3(0, 0, -1), feet, 1.7, 0.38, 1.5, 0.34)
	assert_bool(miss["hit"]).is_false()
	var behind := HitscanMath.test_player(Vector3(0, 1.0, 0), Vector3(0, 0, 1), feet, 1.7, 0.38, 1.5, 0.34)
	assert_bool(behind["hit"]).is_false()


func test_spread_stays_in_cone() -> void:
	for i in 50:
		var d := HitscanMath.apply_spread(Vector3(0, 0, -1), 3.0, randf(), randf())
		assert_float(rad_to_deg(d.angle_to(Vector3(0, 0, -1)))).is_less_equal(3.01)
