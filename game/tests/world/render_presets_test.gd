extends GdUnitTestSuite

const REQUIRED := ["glow", "ssao", "ssil", "volumetric_fog", "sdfgi", "shadow_cascades", "shadow_distance", "shadow_size", "msaa", "render_scale", "foliage_sway", "max_fps"]


func test_presets_complete() -> void:
	var table: Dictionary = GameData.table("render_presets")
	for preset_name: String in ["ultra", "high", "medium", "mobile", "low", "battery_saver"]:
		assert_bool(table["presets"].has(preset_name)).override_failure_message(preset_name).is_true()
		for key: String in REQUIRED:
			assert_bool(table["presets"][preset_name].has(key)).override_failure_message("%s.%s" % [preset_name, key]).is_true()
	assert_bool(table["presets"].has(table["default_desktop"])).is_true()
	assert_bool(table["presets"].has(table["default_mobile"])).is_true()


func test_battery_saver_caps_30_fps() -> void:
	assert_int(int(GameData.table("render_presets")["presets"]["battery_saver"]["max_fps"])).is_equal(30)


func test_mobile_preset_uses_two_cascades_and_no_volumetrics() -> void:
	var mobile: Dictionary = GameData.table("render_presets")["presets"]["mobile"]
	assert_int(int(mobile["shadow_cascades"])).is_equal(2)
	assert_bool(mobile["volumetric_fog"]).is_false()


func test_apply_sets_environment() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	RenderPresets.apply(GameData.table("render_presets")["presets"]["low"], env, sun, null)
	assert_bool(env.glow_enabled).is_false()
	assert_bool(env.volumetric_fog_enabled).is_false()
	assert_float(sun.directional_shadow_max_distance).is_equal(80.0)
	sun.free()
	Engine.max_fps = 0
