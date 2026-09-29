extends GdUnitTestSuite
## GAME_SPEC §5.6–5.8: inspection, activity map, camera replay, evidence, co-op tasks, new sabotages.


func test_inspection_never_names_attacker() -> void:
	var rng := RandomNumberGenerator.new()
	var inc := {"time": 100.0, "damage_type": "gunfire", "weapon_family": "rifle", "range": "mid", "direction": "back", "attacker": 7}
	var r := Inspection.report(inc, 160.0, rng)
	assert_bool(r["known"]).is_true()
	assert_bool(r.has("attacker")).is_false()
	assert_float(float(r["seconds_ago"])).is_between(45.0, 75.0)
	assert_int(int(r["seconds_ago"]) % 5).is_equal(0)
	assert_bool(Inspection.report({}, 0.0, rng)["known"]).is_false()


func test_activity_is_delayed_and_coalesced() -> void:
	var feed := ActivityFeed.new({"min_delay_seconds": 5.0, "max_delay_seconds": 15.0, "keep_seconds": 60.0, "coalesce_seconds": 8.0})
	var rng := RandomNumberGenerator.new()
	assert_bool(feed.record("gunfire", "harbor", 10.0, rng)).is_true()
	assert_bool(feed.record("gunfire", "harbor", 12.0, rng)).is_false()
	assert_array(feed.visible(12.0)).is_empty()
	assert_int(feed.visible(26.0).size()).is_equal(1)
	var b: Dictionary = feed.visible(26.0)[0]
	assert_bool(b.has("pos")).is_false()
	assert_str(b["district"]).is_equal("harbor")
	feed.prune(200.0)
	assert_array(feed.events).is_empty()


func test_camera_replay_keeps_ten_seconds_and_gaps() -> void:
	var rec := CameraRecorder.new(10.0)
	for i in 60:
		rec.record("cam", i * 0.2, [[1, Vector3(i, 0, 0), 0.0, 0]], i >= 50)
	var clip := rec.clip("cam", 11.8)
	assert_float(float(clip[0][0])).is_less_equal(10.0)
	assert_bool(clip[-1][1] == null).is_true()
	assert_bool(clip[0][1] != null).is_true()


func test_evidence_expires_and_merges() -> void:
	var log := EvidenceLog.new(180.0, 10)
	var a := log.add("casing", Vector3.ZERO, "rifle", 0.0)
	var b := log.add("casing", Vector3(0.2, 0, 0), "rifle", 1.0)
	assert_int(a).is_equal(b)
	log.add("impact", Vector3(5, 0, 0), "rifle", 2.0)
	assert_int(log.near(Vector3.ZERO, 1.0).size()).is_equal(1)
	log.prune(200.0)
	assert_array(log.items).is_empty()


func test_coop_needs_two_players_within_window() -> void:
	var c := CoopTracker.new(3.0)
	assert_bool(c.press(1, "a", "b", 0.0).is_empty()).is_true()
	assert_bool(c.press(1, "b", "a", 1.0).is_empty()).is_true()  # same player can't pair with itself
	var r := c.press(2, "b", "a", 2.0)
	assert_int(int(r["player"])).is_equal(1)
	assert_bool(c.press(3, "a", "b", 10.0).is_empty()).is_true()
	assert_bool(c.press(4, "b", "a", 14.0).is_empty()).is_true()  # outside window


func _sab() -> SabotageSystem:
	return SabotageSystem.new(GameDataRegistry.read_json("res://data/sabotages.json"))


func test_comms_failure_lasts_until_both_consoles_rebooted() -> void:
	var s := _sab()
	s.trigger("comms_failure", "", 100.0)
	s.tick(1000.0, false)
	assert_bool(s.comms_down()).is_true()
	assert_bool(s.repair("comms_failure", "", "cc_comms")["repaired"]).is_false()
	assert_bool(s.repair("comms_failure", "", "nowhere")["repaired"]).is_false()
	assert_bool(s.repair("comms_failure", "", "relay_harbor")["repaired"]).is_true()
	assert_bool(s.comms_down()).is_false()


func test_false_alarm_is_instant_and_door_lock_targets_building() -> void:
	var s := _sab()
	s.trigger("false_alarm", "harbor", 100.0)
	assert_array(s.active).is_empty()
	assert_str(s.can_trigger("door_lock", "", 200.0, 200.0, false, 60.0)).is_equal("no_target")
	s.trigger("door_lock", "cc_hall", 200.0)
	assert_bool(s.doors_locked("cc_hall")).is_true()
	s.tick(41.0, false)
	assert_bool(s.doors_locked("cc_hall")).is_false()


func test_panel_hides_sabotages_for_missing_features() -> void:
	var kinds: Dictionary = _sab().panel(0.0, [])["kinds"]
	assert_bool(kinds.has("blackout")).is_true()
	assert_bool(kinds.has("vehicle_lockdown")).is_false()
	assert_bool(kinds.has("bridge_lock")).is_false()
	assert_bool(_sab().panel(0.0, ["vehicles"])["kinds"].has("vehicle_lockdown")).is_true()
