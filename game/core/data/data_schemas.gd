class_name DataSchemas
extends RefCounted
## Structural validation for data tables. Returns human-readable errors.

const NUMBER := -2  # accepts int or float (JSON numbers parse as float)

const WEAPON_FIELDS := {
	"id": TYPE_STRING, "display_name": TYPE_STRING, "family": TYPE_STRING,
	"body_damage": NUMBER, "pellets": NUMBER, "fire_rate": NUMBER,
	"burst_count": NUMBER, "burst_interval": NUMBER, "spin_up": NUMBER,
	"mag_size": NUMBER, "reload_time": NUMBER, "reload_per_shell": TYPE_BOOL,
	"ammo_type": TYPE_STRING, "rarity_min": TYPE_STRING, "rarity_max": TYPE_STRING,
	"headshot_allowed": TYPE_BOOL, "ttk_expected": NUMBER, "accuracy": NUMBER,
	"spread": TYPE_DICTIONARY, "falloff": TYPE_DICTIONARY, "recoil_pattern": TYPE_ARRAY,
	"move_speed_multiplier": NUMBER, "ads_time": NUMBER, "aim_assist_strength": NUMBER,
	"vehicle_damage_multiplier": NUMBER, "sound_profile": TYPE_DICTIONARY,
	"slot": TYPE_STRING, "range_m": NUMBER,
}
const COMBAT_FIELDS := {
	"max_health": NUMBER, "max_shield": NUMBER, "headshot_multiplier": NUMBER,
	"ttk_band_default": TYPE_ARRAY, "max_rarity_damage_bonus": NUMBER,
	"rarities": TYPE_DICTIONARY, "ammo_types": TYPE_DICTIONARY,
}
const NETWORK_FIELDS := {
	"protocol_version": NUMBER, "default_port": NUMBER, "max_clients": NUMBER,
	"server_tick_rate": NUMBER, "snapshot_rate_near": NUMBER, "interpolation_buffer_ms": NUMBER,
	"lag_compensation_max_ms": NUMBER, "max_packet_bytes": NUMBER, "max_name_length": NUMBER,
	"handshake_timeout_seconds": NUMBER, "ping_interval_seconds": NUMBER,
	"client_connect_timeout_seconds": NUMBER, "reject_kick_delay_seconds": NUMBER,
}
const LOBBY_FIELDS := {
	"player_count": NUMBER, "player_count_min": NUMBER, "player_count_max": NUMBER,
	"traitor_divisor": NUMBER, "traitor_min": NUMBER, "traitor_max": NUMBER,
	"tasks_per_agent": NUMBER, "bleed_out_seconds": NUMBER, "match_time_limit_seconds": NUMBER,
	"meeting": TYPE_DICTIONARY,
}
const INPUT_FIELDS := {
	"deadzone_default": NUMBER, "controller_mode_threshold": NUMBER, "actions": TYPE_DICTIONARY,
}
const DEBUG_FIELDS := {
	"screenshot_default_frames": NUMBER, "console_max_lines": NUMBER, "fps_overlay_refresh_seconds": NUMBER,
}


static func validate_all(tables: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var simple := {
		"combat": COMBAT_FIELDS, "network": NETWORK_FIELDS, "lobby_defaults": LOBBY_FIELDS,
		"input_bindings": INPUT_FIELDS, "debug": DEBUG_FIELDS,
	}
	for table_name: String in simple:
		if tables.has(table_name):
			errs.append_array(check_fields(tables[table_name], simple[table_name], table_name))
	if tables.has("combat"):
		errs.append_array(validate_combat(tables["combat"]))
	if tables.has("weapons"):
		errs.append_array(validate_weapons(tables["weapons"], tables.get("combat", {})))
	return errs


static func check_fields(data: Dictionary, fields: Dictionary, context: String) -> PackedStringArray:
	var errs := PackedStringArray()
	for key: String in fields:
		if not data.has(key):
			errs.append("%s: missing field '%s'." % [context, key])
		elif not is_type(data[key], fields[key]):
			errs.append("%s: field '%s' has wrong type." % [context, key])
	return errs


static func is_type(value: Variant, expected: int) -> bool:
	if expected == NUMBER:
		return value is int or value is float
	return typeof(value) == expected


static func validate_combat(combat: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var max_mult := 1.0 + float(combat.get("max_rarity_damage_bonus", 0.0))
	var rarities: Dictionary = combat.get("rarities", {})
	for rarity_id: String in rarities:
		var mult := float(rarities[rarity_id].get("damage_multiplier", 0.0))
		if mult < 1.0 or mult > max_mult + 0.0001:
			errs.append("combat: rarity '%s' damage multiplier %.3f outside [1, %.2f]." % [rarity_id, mult, max_mult])
	return errs


static func validate_weapons(table: Dictionary, combat: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	if not (table.get("weapons") is Array):
		errs.append("weapons: 'weapons' must be an array.")
		return errs
	var rarities: Dictionary = combat.get("rarities", {})
	var ammo_types: Dictionary = combat.get("ammo_types", {})
	var seen := {}
	for weapon: Variant in table["weapons"]:
		if not (weapon is Dictionary):
			errs.append("weapons: entry is not an object.")
			continue
		var ctx := "weapons[%s]" % weapon.get("id", "?")
		errs.append_array(check_fields(weapon, WEAPON_FIELDS, ctx))
		var id: String = str(weapon.get("id", ""))
		if seen.has(id):
			errs.append("%s: duplicate id." % ctx)
		seen[id] = true
		if not ammo_types.is_empty() and not ammo_types.has(weapon.get("ammo_type", "")):
			errs.append("%s: unknown ammo type '%s'." % [ctx, weapon.get("ammo_type", "")])
		if not rarities.is_empty():
			var rmin: Variant = rarities.get(weapon.get("rarity_min", ""))
			var rmax: Variant = rarities.get(weapon.get("rarity_max", ""))
			if rmin == null or rmax == null:
				errs.append("%s: unknown rarity range." % ctx)
			elif int(rmin["order"]) > int(rmax["order"]):
				errs.append("%s: rarity_min is above rarity_max." % ctx)
		if weapon.has("ttk_band") and str(weapon.get("ttk_band_reason", "")).is_empty():
			errs.append("%s: ttk_band override needs a ttk_band_reason." % ctx)
		if weapon.get("fire_rate", 0.0) is float and float(weapon.get("fire_rate", 0.0)) <= 0.0:
			errs.append("%s: fire_rate must be positive." % ctx)
	return errs
