class_name LoopbackTransport
extends Transport
## In-memory transport for tests and single-process bot matches.
## All transports sharing one LoopbackHub form one "network".

enum Ev { CONNECTED, FAILED, SERVER_GONE, PEER_JOINED, PEER_LEFT, PACKET }

var hub: LoopbackHub
var _id := 0
var _server := false
var _active := false
var _queue: Array = []


func _init(shared_hub: LoopbackHub) -> void:
	hub = shared_hub


func get_kind() -> String:
	return "loopback"


func host(_port: int, max_clients: int) -> Error:
	if hub.server != null:
		return ERR_ALREADY_IN_USE
	hub.server = self
	hub.max_clients = max_clients
	_server = true
	_active = true
	_id = SERVER_ID
	return OK


func connect_to(_address: String, _port: int) -> Error:
	_active = true
	if hub.server == null or hub.clients.size() >= hub.max_clients:
		_enqueue([Ev.FAILED])
		return OK
	_id = hub.allocate_id()
	hub.clients[_id] = self
	_enqueue([Ev.CONNECTED])
	hub.server._enqueue([Ev.PEER_JOINED, _id])
	return OK


func _enqueue(event: Array) -> void:
	_queue.append(event)


func poll() -> void:
	var events := _queue
	_queue = []
	for event: Array in events:
		match event[0]:
			Ev.CONNECTED:
				connection_succeeded.emit()
			Ev.FAILED:
				_active = false
				connection_failed.emit()
			Ev.SERVER_GONE:
				_active = false
				server_disconnected.emit()
			Ev.PEER_JOINED:
				peer_connected.emit(event[1])
			Ev.PEER_LEFT:
				peer_disconnected.emit(event[1])
			Ev.PACKET:
				packet_received.emit(event[1], event[2])


func send(peer_id: int, bytes: PackedByteArray, _reliable: bool = true) -> void:
	if not _active:
		return
	if _server:
		var targets: Array = hub.clients.keys() if peer_id == BROADCAST else [peer_id]
		for target: int in targets:
			if hub.clients.has(target):
				hub.clients[target]._enqueue([Ev.PACKET, SERVER_ID, bytes.duplicate()])
	elif hub.server != null and hub.clients.get(_id) == self:
		hub.server._enqueue([Ev.PACKET, _id, bytes.duplicate()])


func disconnect_peer(peer_id: int) -> void:
	if not _server or not hub.clients.has(peer_id):
		return
	var client: LoopbackTransport = hub.clients[peer_id]
	hub.clients.erase(peer_id)
	client._enqueue([Ev.SERVER_GONE])
	_enqueue([Ev.PEER_LEFT, peer_id])


func close() -> void:
	if not _active:
		return
	_active = false
	if _server:
		for client: LoopbackTransport in hub.clients.values():
			client._enqueue([Ev.SERVER_GONE])
		hub.clients.clear()
		hub.server = null
	elif hub.clients.get(_id) == self:
		hub.clients.erase(_id)
		if hub.server != null:
			hub.server._enqueue([Ev.PEER_LEFT, _id])


func is_active() -> bool:
	return _active


func is_server() -> bool:
	return _server and _active


func get_unique_id() -> int:
	return _id
