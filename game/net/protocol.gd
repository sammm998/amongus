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
	# --- Match (M2) ---
	INPUT = 10,          ## c->s: movement/aim/buttons (see PlayerInput)
	ACTION = 11,         ## c->s: discrete actions (vote, sabotage, chat, start...)
	MATCH_INFO = 20,     ## s->c: phase, timers, player list (names/colours, no roles)
	SNAPSHOT = 21,       ## s->c: world snapshot + private "me" block
	ROLE = 22,           ## s->c: ONLY to its owner: own role + fellow traitors
	TASKS = 23,          ## s->c: own task list
	SABOTAGE_PANEL = 24, ## s->c: traitors only
	WORLD = 25,          ## s->c: public world state (sabotage alerts, security, suspects)
	EVENT = 26,          ## s->c: one-off events (shots, hits, alerts, denials)
	MEETING = 27,        ## s->c: meeting state
	MEETING_RESULT = 28, ## s->c: revive / suspects outcome
	CHAT_MSG = 29,       ## s->c: chat line (already filtered by channel rules)
	RESULTS = 30,        ## s->c: match end: winner + all roles revealed
	ACTIVITY = 31,       ## s->c: delayed activity-map blips (only while comms are up)
	EVIDENCE = 32,       ## s->c: evidence near this player
	REPLAY = 33,         ## s->c: camera replay clip (requested at the security terminal)
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
	Msg.INPUT: {"seq": TYPE_INT, "move": TYPE_VECTOR2, "yaw": TYPE_FLOAT, "pitch": TYPE_FLOAT, "buttons": TYPE_INT, "slot": TYPE_INT, "aim": TYPE_VECTOR3, "view": TYPE_FLOAT, "dt": TYPE_FLOAT},
	Msg.ACTION: {"kind": TYPE_STRING, "target": TYPE_INT, "text": TYPE_STRING},
	Msg.MATCH_INFO: {"map": TYPE_STRING, "phase": TYPE_STRING, "time_left": TYPE_FLOAT, "elapsed": TYPE_FLOAT, "time_limit": TYPE_FLOAT, "players": TYPE_ARRAY, "host": TYPE_INT, "mode": TYPE_STRING, "time_of_day": TYPE_STRING, "drop": TYPE_DICTIONARY},
	Msg.SNAPSHOT: {"tick": TYPE_INT, "time": TYPE_FLOAT, "ack": TYPE_INT, "players": TYPE_ARRAY, "bodies": TYPE_ARRAY, "loot": TYPE_ARRAY, "vehicles": TYPE_ARRAY, "me": TYPE_DICTIONARY},
	Msg.ROLE: {"role": TYPE_STRING, "allies": TYPE_ARRAY},
	Msg.TASKS: {"tasks": TYPE_ARRAY},
	Msg.SABOTAGE_PANEL: {"panel": TYPE_DICTIONARY},
	Msg.WORLD: {"security": TYPE_FLOAT, "sabotages": TYPE_ARRAY, "power": TYPE_BOOL, "suspects": TYPE_ARRAY, "generators": TYPE_ARRAY, "doors": TYPE_ARRAY, "comms": TYPE_BOOL, "comms_parts": TYPE_ARRAY},
	Msg.EVENT: {"kind": TYPE_STRING, "data": TYPE_DICTIONARY},
	Msg.MEETING: {"phase": TYPE_STRING, "time_left": TYPE_FLOAT, "kind": TYPE_STRING, "victim": TYPE_INT, "reporter": TYPE_INT, "info": TYPE_DICTIONARY, "participants": TYPE_ARRAY, "voted": TYPE_ARRAY, "revive_vote": TYPE_BOOL},
	Msg.MEETING_RESULT: {"victim": TYPE_INT, "revived": TYPE_BOOL, "had_vote": TYPE_BOOL, "tally": TYPE_DICTIONARY, "suspects": TYPE_ARRAY},
	Msg.CHAT_MSG: {"from": TYPE_INT, "name": TYPE_STRING, "text": TYPE_STRING, "channel": TYPE_STRING},
	Msg.ACTIVITY: {"blips": TYPE_ARRAY, "comms": TYPE_BOOL},
	Msg.EVIDENCE: {"items": TYPE_ARRAY},
	Msg.REPLAY: {"camera": TYPE_STRING, "frames": TYPE_ARRAY},
	Msg.RESULTS: {"winner": TYPE_STRING, "reason": TYPE_STRING, "players": TYPE_ARRAY, "timeline": TYPE_ARRAY},
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
