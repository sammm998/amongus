extends GdUnitTestSuite

const DATA_DIR := "res://data"


func test_real_data_loads_without_errors() -> void:
	var registry := GameDataRegistry.new()
	var ok := registry.load_from_dir(DATA_DIR)
	assert_array(Array(registry.errors)).is_empty()
	assert_bool(ok).is_true()
	for table_name in ["weapons", "combat", "lobby_defaults", "network", "input_bindings", "debug"]:
		assert_bool(registry.has_table(table_name)).override_failure_message("missing %s" % table_name).is_true()


func test_missing_manifest_fails() -> void:
	var registry := GameDataRegistry.new()
	assert_bool(registry.load_from_dir("res://does_not_exist")).is_false()
	assert_array(Array(registry.errors)).is_not_empty()


func test_manifest_table_missing_file_is_reported() -> void:
	var dir := create_temp_dir("data_missing")
	_write(dir.path_join("manifest.json"), {"tables": ["ghost"]})
	var registry := GameDataRegistry.new()
	assert_bool(registry.load_from_dir(dir)).is_false()
	assert_str(registry.errors[0]).contains("ghost")


func test_schema_catches_bad_weapon() -> void:
	var combat: Dictionary = GameDataRegistry.read_json("res://data/combat.json")
	var weapons: Dictionary = GameDataRegistry.read_json("res://data/weapons.json")
	var bad: Dictionary = weapons["weapons"][0].duplicate(true)
	bad.erase("fire_rate")
	bad["ammo_type"] = "plasma"
	bad["rarity_min"] = "prototype"
	bad["rarity_max"] = "standard"
	var errors := DataSchemas.validate_weapons({"weapons": [bad]}, combat)
	var text := "\n".join(errors)
	assert_str(text).contains("missing field 'fire_rate'")
	assert_str(text).contains("unknown ammo type")
	assert_str(text).contains("rarity_min is above rarity_max")


func test_schema_rejects_duplicate_weapon_ids() -> void:
	var combat: Dictionary = GameDataRegistry.read_json("res://data/combat.json")
	var weapons: Dictionary = GameDataRegistry.read_json("res://data/weapons.json")
	var w: Dictionary = weapons["weapons"][0]
	var errors := DataSchemas.validate_weapons({"weapons": [w, w]}, combat)
	assert_str("\n".join(errors)).contains("duplicate id")


func test_band_override_requires_reason() -> void:
	var combat: Dictionary = GameDataRegistry.read_json("res://data/combat.json")
	var weapons: Dictionary = GameDataRegistry.read_json("res://data/weapons.json")
	var w: Dictionary = weapons["weapons"][0].duplicate(true)
	w["ttk_band"] = [0.1, 0.2]
	w.erase("ttk_band_reason")
	assert_str("\n".join(DataSchemas.validate_weapons({"weapons": [w]}, combat))).contains("ttk_band_reason")


func test_rarity_damage_bonus_capped_at_ten_percent() -> void:
	var combat: Dictionary = GameDataRegistry.read_json("res://data/combat.json").duplicate(true)
	assert_array(Array(DataSchemas.validate_combat(combat))).is_empty()
	combat["rarities"]["prototype"]["damage_multiplier"] = 1.2
	assert_str("\n".join(DataSchemas.validate_combat(combat))).contains("prototype")


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
