class_name ServerSession
extends RefCounted
## Authoritative connection handling: handshake, version check, capacity,
## roster and ping. Pure logic over a Transport; the owner calls tick().

signal client_joined(peer_id: int, display_name: String)
signal client_left(peer_id: int)
## Every message this server sends (used by tests, e.g. the role-leak test).
signal message_sent(peer_id: int, type: int, payload: Dictionary)
signal log_line(text: String)

enum ClientState { HANDSHAKING, READY }

var transport: Transport
var clients: Dictionary = {}  # peer_id -> {state, name, input_mode, connected_at}
var protocol_version: int
var max_clients: int
var tick_rate: int
var max_packet_bytes: int
var max_name_length: int
var handshake_timeout: float
var kick_delay: float
var _time := 0.0
var _pending_kicks: Dictionary = {}  # peer_id -> time to drop the connection


func _init(p_transport: Transport, net_config: Dictionary) -> void:
	transport = p_transport
	protocol_version = int(net_config["protocol_version"])
	max_clients = int(net_config["max_clients"])
	tick_rate = int(net_config["server_tick_rate"])
	max_packet_bytes = int(net_config["max_packet_bytes"])
	max_name_length = int(net_config["max_name_length"])
	handshake_timeout = float(net_config["handshake_timeout_seconds"])
	kick_delay = float(net_config["reject_kick_delay_seconds"])
	transport.peer_connected.connect(_on_peer_connected)
	transport.peer_disconnected.connect(_on_peer_disconnected)
	transport.packet_received.connect(_on_packet)


## Transport-level slots include clients still handshaking, so leave headroom
## and enforce the real cap at HELLO time.
func start(port: int) -> Error:
	return transport.host(port, max_clients + 4)


func stop() -> void:
	transport.close()
	clients.clear()
	_pending_kicks.clear()


func tick(delta: float) -> void:
	_time += delta
	transport.poll()
	for peer_id: int in clients.keys():
		var c: Dictionary = clients[peer_id]
		if c["state"] == ClientState.HANDSHAKING and _time - c["connected_at"] > handshake_timeout:
			_reject(peer_id, Protocol.REJECT_HANDSHAKE_TIMEOUT)
	for peer_id: int in _pending_kicks.keys():
		if _time >= _pending_kicks[peer_id]:
			_pending_kicks.erase(peer_id)
			transport.disconnect_peer(peer_id)


func ready_count() -> int:
	var n := 0
	for c: Dictionary in clients.values():
		if c["state"] == ClientState.READY:
			n += 1
	return n


func roster() -> Array:
	var ids: Array = []
	for peer_id: int in clients:
		if clients[peer_id]["state"] == ClientState.READY:
			ids.append(peer_id)
	ids.sort()
	var players: Array = []
	for peer_id: int in ids:
		players.append({"id": peer_id, "name": clients[peer_id]["name"]})
	return players


func send_to(peer_id: int, type: int, payload: Dictionary) -> void:
	transport.send(peer_id, Protocol.encode(type, payload))
	message_sent.emit(peer_id, type, payload)


func broadcast_ready(type: int, payload: Dictionary) -> void:
	for peer_id: int in clients:
		if clients[peer_id]["state"] == ClientState.READY:
			send_to(peer_id, type, payload)


func _on_peer_connected(peer_id: int) -> void:
	clients[peer_id] = {
		"state": ClientState.HANDSHAKING, "name": "", "input_mode": "", "connected_at": _time,
	}


func _on_peer_disconnected(peer_id: int) -> void:
	_pending_kicks.erase(peer_id)
	if not clients.has(peer_id):
		return
	var was_ready: bool = clients[peer_id]["state"] == ClientState.READY
	clients.erase(peer_id)
	if was_ready:
		log_line.emit("client %d left" % peer_id)
		client_left.emit(peer_id)
		broadcast_ready(Protocol.Msg.ROSTER, {"players": roster()})


func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if not clients.has(peer_id):
		return
	var msg := Protocol.decode(bytes, max_packet_bytes)
	var state: int = clients[peer_id]["state"]
	if not msg["ok"]:
		log_line.emit("bad packet from %d: %s" % [peer_id, msg["error"]])
		if state == ClientState.HANDSHAKING:
			_reject(peer_id, Protocol.REJECT_PROTOCOL_ERROR)
		return
	match msg["type"]:
		Protocol.Msg.HELLO:
			if state == ClientState.HANDSHAKING:
				_handle_hello(peer_id, msg["payload"])
		Protocol.Msg.PING:
			if state == ClientState.READY:
				send_to(peer_id, Protocol.Msg.PONG, {"t": msg["payload"]["t"]})
		_:
			pass  # clients may not send server-bound-only types; ignore


func _handle_hello(peer_id: int, hello: Dictionary) -> void:
	if hello["protocol_version"] != protocol_version:
		_reject(peer_id, Protocol.REJECT_VERSION_MISMATCH)
		return
	if ready_count() >= max_clients:
		_reject(peer_id, Protocol.REJECT_SERVER_FULL)
		return
	var display_name := sanitize_name(hello["name"], max_name_length)
	if display_name.is_empty():
		_reject(peer_id, Protocol.REJECT_BAD_NAME)
		return
	display_name = _unique_name(display_name)
	var c: Dictionary = clients[peer_id]
	c["state"] = ClientState.READY
	c["name"] = display_name
	c["input_mode"] = hello["input_mode"].left(16)
	send_to(peer_id, Protocol.Msg.WELCOME, {"peer_id": peer_id, "tick_rate": tick_rate, "name": display_name})
	log_line.emit("client %d joined as '%s'" % [peer_id, display_name])
	client_joined.emit(peer_id, display_name)
	broadcast_ready(Protocol.Msg.ROSTER, {"players": roster()})


func _reject(peer_id: int, reason: String) -> void:
	send_to(peer_id, Protocol.Msg.REJECT, {"reason": reason})
	clients.erase(peer_id)
	log_line.emit("rejected %d: %s" % [peer_id, reason])
	# Drop the connection a little later so the REJECT message is delivered first.
	_pending_kicks[peer_id] = _time + kick_delay


func _unique_name(base: String) -> String:
	var taken := {}
	for c: Dictionary in clients.values():
		if c["state"] == ClientState.READY:
			taken[c["name"].to_lower()] = true
	var candidate := base
	var n := 2
	while taken.has(candidate.to_lower()):
		var suffix := " %d" % n
		candidate = base.left(max_name_length - suffix.length()) + suffix
		n += 1
	return candidate


## Trims, drops control characters, collapses whitespace and truncates.
static func sanitize_name(raw: String, max_length: int) -> String:
	var out := ""
	var last_space := true
	for ch in raw:
		var code := ch.unicode_at(0)
		if code < 32 or code == 127:
			continue
		if ch == " " or ch == "\t":
			if last_space:
				continue
			out += " "
			last_space = true
		else:
			out += ch
			last_space = false
	return out.strip_edges().left(max_length).strip_edges()
