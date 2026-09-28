extends Node
## Autoload: owns the server and/or client session and polls them each physics tick.

signal server_started(port: int)
signal server_stopped
signal client_state_changed(state: int)
signal roster_changed(players: Array)

var server: ServerSession
var client: ClientSession
var net_config: Dictionary


func _ready() -> void:
	net_config = GameData.table("network")


func default_port() -> int:
	return int(net_config["default_port"])


func make_transport(kind: String) -> Transport:
	return WebSocketTransport.new() if kind == "ws" else ENetTransport.new()


func start_server(port: int = -1, kind: String = "enet") -> Error:
	stop_server()
	var actual_port := port if port > 0 else default_port()
	var session := ServerSession.new(make_transport(kind), net_config)
	var err := session.start(actual_port)
	if err != OK:
		return err
	server = session
	server.log_line.connect(func(text: String) -> void: print("[server] ", text))
	server_started.emit(actual_port)
	return OK


func stop_server() -> void:
	if server != null:
		server.stop()
		server = null
		server_stopped.emit()


func start_client(address: String, port: int = -1, kind: String = "enet", player_name: String = "Player") -> Error:
	stop_client()
	client = ClientSession.new(make_transport(kind), net_config, player_name)
	client.input_mode = InputClassifier.mode_name(InputRouter.mode)
	client.state_changed.connect(func(state: int) -> void: client_state_changed.emit(state))
	client.roster_changed.connect(func(players: Array) -> void: roster_changed.emit(players))
	return client.connect_to(address, port if port > 0 else default_port())


func stop_client() -> void:
	if client != null:
		client.disconnect_from_server()
		client = null
		client_state_changed.emit(ClientSession.State.DISCONNECTED)
		roster_changed.emit([])


## Listen server for local play: starts a server and joins it from this process.
func host_and_join(player_name: String, port: int = -1, kind: String = "enet") -> Error:
	var err := start_server(port, kind)
	if err != OK:
		return err
	return start_client("127.0.0.1", port, kind, player_name)


func stop_all() -> void:
	stop_client()
	stop_server()


func _physics_process(delta: float) -> void:
	if server != null:
		server.tick(delta)
	if client != null:
		client.tick(delta)


func status_text() -> String:
	var lines := PackedStringArray()
	if server != null:
		lines.append("server: %s, %d/%d players" % [server.transport.get_kind(), server.ready_count(), server.max_clients])
	if client != null:
		var line := "client: %s" % client.state_name()
		if client.is_connected_to_server():
			line += ", id %d as '%s', rtt %d ms" % [client.peer_id, client.display_name, client.rtt_ms]
		elif not client.reject_reason.is_empty():
			line += " (%s)" % client.reject_reason
		lines.append(line)
	return "offline" if lines.is_empty() else "\n".join(lines)
