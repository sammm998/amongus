extends GdUnitTestSuite
## GAME_SPEC §10 M2 "done when": a full 8-player all-bot match plays start to
## finish with a winner, and the role-leak test passes (§4 security invariants).

const DT := 1.0 / 30.0
const MAX_SECONDS := 420.0

var _match: MatchServer
var _log: Dictionary = {}  # pid -> Array of [type, payload]


func _run_match(seed_value: int) -> Dictionary:
	_match = MatchServer.new()
	add_child(_match)
	_match.set_physics_process(false)
	_match.setup("slice", "test_fast", {}, seed_value)
	_log.clear()
	_match.outbound.connect(func(pid: int, type: int, payload: Dictionary) -> void:
		if not _log.has(pid):
			_log[pid] = []
		_log[pid].append([type, payload]))
	var ended := [false]
	_match.match_ended.connect(func(_r: Dictionary) -> void: ended[0] = true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_match.fill_bots(8)
	assert_bool(_match.request_start()).is_true()
	var t := 0.0
	while not ended[0] and t < MAX_SECONDS:
		_match.tick(DT)
		t += DT
	return _match.result


func after_test() -> void:
	if _match != null:
		_match.queue_free()
		_match = null


func test_full_bot_match_has_a_winner() -> void:
	var result: Dictionary = await _run_match(11)
	assert_bool(result.is_empty()).override_failure_message("match did not finish").is_false()
	assert_bool(result["winner"] in ["agents", "traitors"]).is_true()
	assert_int(result["players"].size()).is_equal(8)
	var traitors: Array = result["players"].filter(func(p: Dictionary) -> bool: return p["role"] == "traitor")
	assert_int(traitors.size()).is_equal(1)


func test_role_leak_agents_never_learn_other_roles() -> void:
	var result: Dictionary = await _run_match(12)
	assert_bool(result.is_empty()).is_false()
	var roles := {}
	for p: Dictionary in result["players"]:
		roles[p["id"]] = p["role"]
	var checked_agents := 0
	for pid: int in _log:
		var msgs: Array = _log[pid]
		var role_msgs := msgs.filter(func(m: Array) -> bool: return m[0] == Protocol.Msg.ROLE)
		assert_int(role_msgs.size()).override_failure_message("player %d got %d ROLE messages" % [pid, role_msgs.size()]).is_equal(1)
		assert_str(role_msgs[0][1]["role"]).is_equal(roles[pid])
		var results_index := msgs.find_custom(func(m: Array) -> bool: return m[0] == Protocol.Msg.RESULTS)
		for i in msgs.size():
			var type: int = msgs[i][0]
			var payload: Dictionary = msgs[i][1]
			if type == Protocol.Msg.RESULTS:
				continue
			if type == Protocol.Msg.ROLE:
				continue
			assert_bool(_contains_key(payload, "role")).override_failure_message("role key leaked in %s to %d" % [Protocol.type_name(type), pid]).is_false()
			assert_bool(_contains_key(payload, "allies")).is_false()
		if roles[pid] == "agent":
			checked_agents += 1
			assert_array(role_msgs[0][1]["allies"]).is_empty()
			var panels := msgs.filter(func(m: Array) -> bool: return m[0] == Protocol.Msg.SABOTAGE_PANEL)
			assert_array(panels).override_failure_message("agent %d received the sabotage panel" % pid).is_empty()
		else:
			var allies: Array = role_msgs[0][1]["allies"].map(func(a: Dictionary) -> int: return a["id"])
			for a: int in allies:
				assert_str(roles[a]).is_equal("traitor")
		# Full role list only arrives with RESULTS at the very end.
		assert_int(results_index).is_greater_equal(0)
	assert_int(checked_agents).is_greater_equal(6)


func test_snapshots_never_include_roles() -> void:
	await _run_match(13)
	for pid: int in _log:
		for m: Array in _log[pid]:
			if m[0] == Protocol.Msg.SNAPSHOT:
				for entry: Array in m[1]["players"]:
					assert_int(entry.size()).is_equal(7)
					for v: Variant in entry:
						assert_bool(v is String and (v == "traitor" or v == "agent")).is_false()


func _contains_key(value: Variant, key: String) -> bool:
	if value is Dictionary:
		for k: Variant in value:
			if str(k) == key or _contains_key(value[k], key):
				return true
	elif value is Array:
		for v: Variant in value:
			if _contains_key(v, key):
				return true
	return false
