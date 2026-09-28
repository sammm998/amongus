class_name MultiplayerPeerTransport
extends Transport
## Transport over a raw Godot MultiplayerPeer (no SceneMultiplayer/RPCs).

var _peer: MultiplayerPeer
var _is_server := false
var _last_status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _supports_unreliable := true


func _create_server_peer(_port: int, _max_clients: int) -> MultiplayerPeer:
	return null


func _create_client_peer(_address: String, _port: int) -> MultiplayerPeer:
	return null


func host(port: int, max_clients: int) -> Error:
	close()
	var peer := _create_server_peer(port, max_clients)
	if peer == null:
		return ERR_CANT_CREATE
	_attach(peer, true)
	return OK


func connect_to(address: String, port: int) -> Error:
	close()
	var peer := _create_client_peer(address, port)
	if peer == null:
		return ERR_CANT_CONNECT
	_attach(peer, false)
	return OK


func _attach(peer: MultiplayerPeer, server: bool) -> void:
	_peer = peer
	_is_server = server
	_last_status = peer.get_connection_status()
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int) -> void:
	if _is_server:
		peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if _is_server:
		peer_disconnected.emit(id)


func poll() -> void:
	if _peer == null:
		return
	var peer := _peer
	peer.poll()
	var status := peer.get_connection_status()
	if not _is_server and status != _last_status:
		var previous := _last_status
		_last_status = status
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			connection_succeeded.emit()
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_peer = null
			if previous == MultiplayerPeer.CONNECTION_CONNECTING:
				connection_failed.emit()
			else:
				server_disconnected.emit()
			return
	_last_status = status
	while _peer == peer and peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var bytes := peer.get_packet()
		packet_received.emit(from, bytes)


func send(peer_id: int, bytes: PackedByteArray, reliable: bool = true) -> void:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_peer.set_target_peer(peer_id)
	if reliable or not _supports_unreliable:
		_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	else:
		_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	_peer.put_packet(bytes)


func disconnect_peer(peer_id: int) -> void:
	if _peer != null and _is_server:
		_peer.disconnect_peer(peer_id)


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_last_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func is_active() -> bool:
	return _peer != null


func is_server() -> bool:
	return _is_server and _peer != null


func get_unique_id() -> int:
	return _peer.get_unique_id() if _peer != null else 0
