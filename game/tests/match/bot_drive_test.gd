extends GdUnitTestSuite
## Bots take buggies for long trips on the island (and get out again).


func test_bots_drive_buggies() -> void:
	var m := MatchServer.new()
	add_child(m)
	m.set_physics_process(false)
	m.setup("island", "test_fast", {}, 21)
	await get_tree().physics_frame
	await get_tree().physics_frame
	m.fill_bots(12)
	m.request_start()
	var drove := {}
	var left := {}
	var t := 0.0
	while t < 240.0 and m.result.is_empty():
		m.tick(1.0 / 30.0)
		t += 1.0 / 30.0
		for p: ServerPlayer in m.players.values():
			if p.vehicle >= 0:
				drove[p.id] = true
			elif drove.has(p.id):
				left[p.id] = true
	prints("PROBE drove", drove.size(), "left", left.size())
	assert_int(drove.size()).override_failure_message("no bot ever took a vehicle").is_greater(0)
	assert_int(left.size()).is_greater(0)
	m.queue_free()
