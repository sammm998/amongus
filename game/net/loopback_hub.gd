class_name LoopbackHub
extends RefCounted
## Shared state of an in-memory LoopbackTransport network.

var server: LoopbackTransport = null
var clients: Dictionary = {}  # peer_id -> LoopbackTransport
var max_clients := 32
var _next_id := 2


func allocate_id() -> int:
	var id := _next_id
	_next_id += 1
	return id
