extends GdUnitTestSuite

var _field: HeightField


func before_test() -> void:
	_field = HeightField.new({
		"sea_floor": -18.0, "land_level": 2.5, "beach_width": 10.0, "shelf_width": 20.0,
		"shelf_depth": 2.0, "dropoff": 40.0,
		"land": [{"x": 0, "z": 0, "rx": 100, "rz": 60}],
		"hills": [{"x": 0, "z": 0, "radius": 30, "height": 20}],
		"flats": [{"x": 50, "z": 0, "radius": 10, "height": 5.0, "blend": 0.2}],
	})


func test_coast_distance_sign() -> void:
	assert_float(_field.coast_distance(0, 0)).is_greater(0.0)
	assert_float(_field.coast_distance(0, 200)).is_less(0.0)
	assert_float(absf(_field.coast_distance(100, 0))).is_less(1.0)


func test_profile_is_monotonic_from_sea_to_land() -> void:
	var last := -INF
	for d in range(-100, 30):
		var h := _field.coastal_profile(float(d))
		assert_float(h).is_greater_equal(last - 0.0001)
		last = h
	assert_float(_field.coastal_profile(-200.0)).is_equal(-18.0)
	assert_float(_field.coastal_profile(50.0)).is_equal(2.5)


func test_waterline_near_coast_and_shallow_shelf() -> void:
	assert_float(_field.coastal_profile(0.0)).is_between(0.0, 0.5)
	assert_float(_field.coastal_profile(-10.0)).is_between(-2.0, 0.0)


func test_hill_raises_inland_centre() -> void:
	assert_float(_field.height_at(0, 0)).is_greater(15.0)


func test_flat_pad_levels_ground() -> void:
	assert_float(_field.height_at(50, 0)).is_equal_approx(5.0, 0.01)


func test_smooth_max() -> void:
	assert_float(HeightField.smooth_max(0.0, 10.0, 1.0)).is_equal_approx(10.0, 0.001)
	assert_float(HeightField.smooth_max(1.0, 1.0, 2.0)).is_greater(1.0)


func test_cove_map_is_valid() -> void:
	var map: Dictionary = GameDataRegistry.read_json("res://data/maps/sunset_cove.json")
	var field := HeightField.new(map["terrain"])
	var area: Array = map["astronaut_area"]
	var h := field.height_at(float(area[0]), float(area[2]))
	assert_float(h).override_failure_message("astronauts must stand on dry sand").is_between(0.3, 4.0)
	assert_float(field.height_at(300, 0)).is_less(-5.0)
