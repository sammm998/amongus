class_name ClientSession
extends RefCounted
## Client side of the connection: handshake, roster, ping/RTT, timeouts.

signal state_changed(state: int)
signal roster_changed(players: Array)
signal rejected(reason: String)

enum State { DISCONNECTED, CONNECTING, HANDSHAKING, CONNECTED, REJECTED, FAILED }

var transport: Transport
var state := State.DISCONNECTED
var peer_id := 0
var display_name := ""
var requested_name := ""
var input_mode := "desktop"
var roster: Array = []
var rtt_ms := -1
var reject_reason := ""
var tick_rate := 0
var protocol_version: int
var max_packet_bytes: int
var connect_timeout: float
var ping_interval: float
var _time := 0.0
var _state_since := 0.0
var _ping_timer := 0.0


func _init(p_transport: Transport, net_config: Dictionary, p_name: String) -> void:
	transport = p_transport
	requested_name = p_name
	protocol_version = int(net_config["protocol_version"])
	max_packet_bytes = int(net_config["max_packet_bytes"])
	connect_timeout = float(net_config["client_connect_timeout_seconds"])
	ping_interval = float(net_config["ping_interval_seconds"])
	transport.connection_succeeded.connect(_on_connected)
	transport.connection_failed.connect(_on_failed)
	transport.server_disconnected.connect(_on_server_disconnected)
	transport.packet_received.connect(_on_packet)


func connect_to(address: String, port: int) -> Error:
	var err := transport.connect_to(address, port)
	if err != OK:
		_set_state(State.FAILED)
		return err
	roster = []
	reject_reason = ""
	_set_state(State.CONNECTING)
	return OK


func disconnect_from_server() -> void:
	transport.close()
	roster = []
	_set_state(State.DISCONNECTED)


func is_connected_to_server() -> bool:
	return state == State.CONNECTED


func tick(delta: float) -> void:
	_time += delta
	transport.poll()
	if state == State.CONNECTING or state == State.HANDSHAKING:
		if _time - _state_since > connect_timeout:
			transport.close()
			_set_state(State.FAILED)
	elif state == State.CONNECTED:
		_ping_timer += delta
		if _ping_timer >= ping_interval:
			_ping_timer = 0.0
			_send(Protocol.Msg.PING, {"t": _now_ms()})


func state_name() -> String:
	return State.keys()[state]


func _now_ms() -> int:
	return int(_time * 1000.0)


func _send(type: int, payload: Dictionary) -> void:
	transport.send(Transport.SERVER_ID, Protocol.encode(type, payload))


func _set_state(new_state: int) -> void:
	if new_state == state:
		return
	state = new_state
	_state_since = _time
	state_changed.emit(state)


func _on_connected() -> void:
	_set_state(State.HANDSHAKING)
	_send(Protocol.Msg.HELLO, {
		"protocol_version": protocol_version, "name": requested_name, "input_mode": input_mode,
	})


func _on_failed() -> void:
	_set_state(State.FAILED)


func _on_server_disconnected() -> void:
	roster = []
	if state != State.REJECTED:
		_set_state(State.DISCONNECTED)


func _on_packet(from_peer: int, bytes: PackedByteArray) -> void:
	if from_peer != Transport.SERVER_ID:
		return
	var msg := Protocol.decode(bytes, max_packet_bytes)
	if not msg["ok"]:
		return
	var p: Dictionary = msg["payload"]
	match msg["type"]:
		Protocol.Msg.WELCOME:
			if state == State.HANDSHAKING:
				peer_id = p["peer_id"]
				display_name = p["name"]
				tick_rate = p["tick_rate"]
				_ping_timer = ping_interval  # measure RTT right away
				_set_state(State.CONNECTED)
		Protocol.Msg.ROSTER:
			if Protocol.validate_roster(p["players"]):
				roster = p["players"]
				roster_changed.emit(roster)
		Protocol.Msg.REJECT:
			reject_reason = p["reason"]
			_set_state(State.REJECTED)
			rejected.emit(reject_reason)
			transport.close()
		Protocol.Msg.PONG:
			rtt_ms = maxi(0, _now_ms() - int(p["t"]))
