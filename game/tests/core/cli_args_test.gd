extends GdUnitTestSuite


func test_defaults() -> void:
	var a := CliArgs.parse(PackedStringArray())
	assert_bool(a["server"]).is_false()
	assert_int(a["port"]).is_equal(-1)
	assert_str(a["transport"]).is_equal("enet")


func test_space_and_equals_forms() -> void:
	var a := CliArgs.parse(PackedStringArray(["--server", "--port", "4000", "--name=Ada Lovelace", "--quit-after", "2.5"]))
	assert_bool(a["server"]).is_true()
	assert_int(a["port"]).is_equal(4000)
	assert_str(a["name"]).is_equal("Ada Lovelace")
	assert_float(a["quit_after"]).is_equal(2.5)


func test_dashes_map_to_underscores() -> void:
	var a := CliArgs.parse(PackedStringArray(["--expect-roster", "2", "--backend-dir", "/tmp/x"]))
	assert_int(a["expect_roster"]).is_equal(2)
	assert_str(a["backend_dir"]).is_equal("/tmp/x")


func test_unknown_and_invalid_values_ignored() -> void:
	var a := CliArgs.parse(PackedStringArray(["--bogus", "1", "--port", "abc", "--transport", "carrier_pigeon", "godot_arg"]))
	assert_int(a["port"]).is_equal(-1)
	assert_str(a["transport"]).is_equal("enet")


func test_screenshot_flag() -> void:
	var a := CliArgs.parse(PackedStringArray(["--screenshot", "docs/art/shot.png", "--frames", "60"]))
	assert_str(a["screenshot"]).is_equal("docs/art/shot.png")
	assert_int(a["frames"]).is_equal(60)


func test_bool_with_value() -> void:
	assert_bool(CliArgs.parse(PackedStringArray(["--console=false"]))["console"]).is_false()
	assert_bool(CliArgs.parse(PackedStringArray(["--console=1"]))["console"]).is_true()
