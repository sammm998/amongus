class_name Protocol
extends RefCounted
## Wire format and message schemas. A message is var_to_bytes([type, payload]).
## Never uses the *_with_objects variants, so peers cannot inject objects.

enum Msg {
	HELLO = 1,    ## c->s: protocol_version, name, input_mode
	WELCOME = 2,  ## s->c: peer_id, tick_rate, name (sanitized)
	REJECT = 3,   ## s->c: reason
	ROSTER = 4,   ## s->c: players [{id, name}]
	PING = 5,     ## c->s: t (client ms)
	PONG = 6,     ## s->c: t (echo)
}

const REJECT_VERSION_MISMATCH := "version_mismatch"
const REJECT_SERVER_FULL := "server_full"
const REJECT_BAD_NAME := "bad_name"
const REJECT_HANDSHAKE_TIMEOUT := "handshake_timeout"
const REJECT_PROTOCOL_ERROR := "protocol_error"

const SCHEMAS := {
	Msg.HELLO: {"protocol_version": TYPE_INT, "name": TYPE_STRING, "input_mode": TYPE_STRING},
	Msg.WELCOME: {"peer_id": TYPE_INT, "tick_rate": TYPE_INT, "name": TYPE_STRING},
	Msg.REJECT: {"reason": TYPE_STRING},
	Msg.ROSTER: {"players": TYPE_ARRAY},
	Msg.PING: {"t": TYPE_INT},
	Msg.PONG: {"t": TYPE_INT},
}

const ROSTER_ENTRY := {"id": TYPE_INT, "name": TYPE_STRING}


static func encode(type: int, payload: Dictionary) -> PackedByteArray:
	return var_to_bytes([type, payload])


## Returns {ok: bool, type: int, payload: Dictionary, error: String}.
static func decode(bytes: PackedByteArray, max_bytes: int) -> Dictionary:
	if bytes.is_empty() or bytes.size() > max_bytes:
		return _fail("bad_size")
	var value: Variant = bytes_to_var(bytes)
	if not (value is Array) or value.size() != 2:
		return _fail("bad_envelope")
	if not (value[0] is int) or not SCHEMAS.has(value[0]):
		return _fail("unknown_type")
	if not (value[1] is Dictionary):
		return _fail("bad_payload")
	var error := validate_fields(value[1], SCHEMAS[value[0]])
	if not error.is_empty():
		return _fail(error)
	return {"ok": true, "type": value[0], "payload": value[1], "error": ""}


## Strict check: exactly the schema keys, with exact types.
static func validate_fields(payload: Dictionary, schema: Dictionary) -> String:
	if payload.size() != schema.size():
		return "bad_fields"
	for key: String in schema:
		if not payload.has(key):
			return "missing_%s" % key
		if typeof(payload[key]) != schema[key]:
			return "bad_type_%s" % key
	return ""


static func validate_roster(players: Array) -> bool:
	for entry: Variant in players:
		if not (entry is Dictionary) or not validate_fields(entry, ROSTER_ENTRY).is_empty():
			return false
	return true


static func type_name(type: int) -> String:
	var idx := Msg.values().find(type)
	return Msg.keys()[idx] if idx >= 0 else "UNKNOWN(%d)" % type


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "type": -1, "payload": {}, "error": error}
