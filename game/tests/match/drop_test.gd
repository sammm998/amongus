extends GdUnitTestSuite
## Opening drop on the full island: everyone starts on the plane, jumps,
## glides down under a canopy and lands on walkable ground.

const DT := 1.0 / 30.0


func test_everyone_drops_from_the_plane_and_lands_ashore() -> void:
	var m := MatchServer.new()
	add_child(m)
	m.set_physics_process(false)
	m.setup("island", "test_fast", {}, 3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	m.fill_bots(10)
	assert_bool(m.request_start()).is_true()
	var t := 0.0
	while m.drop.is_empty() and t < 60.0:
		m.tick(DT)
		t += DT
	assert_bool(m.drop.is_empty()).override_failure_message("drop never started").is_false()
	for p: ServerPlayer in m.players.values():
		assert_int(p.air).is_equal(PlayerMotor.Air.PLANE)
		assert_float(p.feet().y).is_greater(150.0)
	var saw_chute := false
	var landed_all := false
	var limit := t + 150.0
	while t < limit and not landed_all:
		m.tick(DT)
		t += DT
		landed_all = true
		for p: ServerPlayer in m.players.values():
			saw_chute = saw_chute or p.air == PlayerMotor.Air.CHUTE
			if p.air != PlayerMotor.Air.NONE:
				landed_all = false
	assert_bool(saw_chute).is_true()
	assert_bool(landed_all).override_failure_message("not everyone landed").is_true()
	for p: ServerPlayer in m.players.values():
		assert_float(p.feet().y).override_failure_message("%s landed at %s" % [p.name, p.feet()]).is_greater(-1.0)
	m.queue_free()
