class_name WebSocketTransport
extends MultiplayerPeerTransport
## TCP/WebSocket transport for web clients. Reliable only.


func _init() -> void:
	_supports_unreliable = false


func get_kind() -> String:
	return "ws"


func _create_server_peer(port: int, _max_clients: int) -> MultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_server(port) != OK:
		return null
	return peer


func _create_client_peer(address: String, port: int) -> MultiplayerPeer:
	var url := address
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "ws://%s:%d" % [address, port]
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_client(url) != OK:
		return null
	return peer
