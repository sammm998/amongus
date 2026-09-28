extends GdUnitTestSuite

const MAX := 16384


func test_roundtrip() -> void:
	var bytes := Protocol.encode(Protocol.Msg.HELLO, {"protocol_version": 1, "name": "Ada", "input_mode": "touch"})
	var msg := Protocol.decode(bytes, MAX)
	assert_bool(msg["ok"]).is_true()
	assert_int(msg["type"]).is_equal(Protocol.Msg.HELLO)
	assert_str(msg["payload"]["name"]).is_equal("Ada")


func test_rejects_empty_and_oversized() -> void:
	assert_str(Protocol.decode(PackedByteArray(), MAX)["error"]).is_equal("bad_size")
	var big := Protocol.encode(Protocol.Msg.REJECT, {"reason": "x".repeat(200)})
	assert_str(Protocol.decode(big, 64)["error"]).is_equal("bad_size")


func test_rejects_garbage() -> void:
	var junk := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9])
	assert_bool(Protocol.decode(junk, MAX)["ok"]).is_false()
	assert_str(Protocol.decode(var_to_bytes("hello"), MAX)["error"]).is_equal("bad_envelope")
	assert_str(Protocol.decode(var_to_bytes([1, 2, 3]), MAX)["error"]).is_equal("bad_envelope")


func test_rejects_unknown_type() -> void:
	assert_str(Protocol.decode(var_to_bytes([999, {}]), MAX)["error"]).is_equal("unknown_type")
	assert_str(Protocol.decode(var_to_bytes(["1", {}]), MAX)["error"]).is_equal("unknown_type")


func test_rejects_missing_wrong_and_extra_fields() -> void:
	var missing := Protocol.decode(var_to_bytes([Protocol.Msg.PING, {}]), MAX)
	assert_bool(missing["ok"]).is_false()
	var wrong := Protocol.decode(var_to_bytes([Protocol.Msg.PING, {"t": "now"}]), MAX)
	assert_str(wrong["error"]).is_equal("bad_type_t")
	var extra := Protocol.decode(var_to_bytes([Protocol.Msg.PING, {"t": 1, "role": "traitor"}]), MAX)
	assert_str(extra["error"]).is_equal("bad_fields")


func test_objects_are_never_decoded() -> void:
	var obj := RefCounted.new()
	var bytes := var_to_bytes_with_objects([Protocol.Msg.PING, {"t": obj}])
	assert_bool(Protocol.decode(bytes, MAX)["ok"]).is_false()


func test_roster_validation() -> void:
	assert_bool(Protocol.validate_roster([{"id": 2, "name": "A"}])).is_true()
	assert_bool(Protocol.validate_roster([{"id": 2}])).is_false()
	assert_bool(Protocol.validate_roster([{"id": 2, "name": "A", "role": "agent"}])).is_false()
	assert_bool(Protocol.validate_roster(["x"])).is_false()


func test_every_message_type_has_schema() -> void:
	for type: int in Protocol.Msg.values():
		assert_bool(Protocol.SCHEMAS.has(type)).override_failure_message(Protocol.type_name(type)).is_true()
