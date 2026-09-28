class_name ENetTransport
extends MultiplayerPeerTransport
## UDP transport for native clients.


func get_kind() -> String:
	return "enet"


func _create_server_peer(port: int, max_clients: int) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, max_clients) != OK:
		return null
	return peer


func _create_client_peer(address: String, port: int) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		return null
	return peer
