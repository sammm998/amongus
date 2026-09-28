class_name Transport
extends RefCounted
## Packet transport interface. Server peer id is always 1.
## Implementations: ENetTransport, WebSocketTransport, LoopbackTransport.
## Events are only emitted from poll(), so callers control timing.

signal peer_connected(peer_id: int)        ## server side
signal peer_disconnected(peer_id: int)     ## server side
signal connection_succeeded                ## client side
signal connection_failed                   ## client side
signal server_disconnected                 ## client side
signal packet_received(from_peer: int, bytes: PackedByteArray)

const SERVER_ID := 1
const BROADCAST := 0


func get_kind() -> String:
	return "none"


func host(_port: int, _max_clients: int) -> Error:
	return ERR_UNAVAILABLE


func connect_to(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE


func poll() -> void:
	pass


func send(_peer_id: int, _bytes: PackedByteArray, _reliable: bool = true) -> void:
	pass


func disconnect_peer(_peer_id: int) -> void:
	pass


func close() -> void:
	pass


func is_active() -> bool:
	return false


func is_server() -> bool:
	return false


func get_unique_id() -> int:
	return 0
