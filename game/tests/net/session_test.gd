extends GdUnitTestSuite
## Server/client handshake logic over the in-memory loopback transport.

const DT := 1.0 / 30.0

var _net: Dictionary
var _hub: LoopbackHub
var _server: ServerSession
var _clients: Array[ClientSession] = []


func before_test() -> void:
	_net = GameDataRegistry.read_json("res://data/network.json")
	_hub = LoopbackHub.new()
	_server = ServerSession.new(LoopbackTransport.new(_hub), _net)
	assert_int(_server.start(0)).is_equal(OK)
	_clients.clear()


func after_test() -> void:
	for c in _clients:
		c.disconnect_from_server()
	_server.stop()


func _client(player_name: String, config: Dictionary = {}) -> ClientSession:
	var c := ClientSession.new(LoopbackTransport.new(_hub), config if not config.is_empty() else _net, player_name)
	_clients.append(c)
	c.connect_to("loopback", 0)
	return c


func _run(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_server.tick(DT)
		for c in _clients:
			c.tick(DT)
		t += DT


func test_two_clients_join_and_share_roster() -> void:
	var a := _client("Alice")
	var b := _client("Bob")
	_run(0.5)
	assert_int(a.state).is_equal(ClientSession.State.CONNECTED)
	assert_int(b.state).is_equal(ClientSession.State.CONNECTED)
	assert_int(_server.ready_count()).is_equal(2)
	for c in [a, b]:
		var names: Array = c.roster.map(func(p: Dictionary) -> String: return p["name"])
		assert_array(names).contains_exactly_in_any_order(["Alice", "Bob"])
	assert_int(a.peer_id).is_not_equal(b.peer_id)


func test_version_mismatch_rejected() -> void:
	var old := _net.duplicate()
	old["protocol_version"] = int(_net["protocol_version"]) + 1
	var c := _client("Old", old)
	_run(1.0)
	assert_int(c.state).is_equal(ClientSession.State.REJECTED)
	assert_str(c.reject_reason).is_equal(Protocol.REJECT_VERSION_MISMATCH)
	assert_int(_server.ready_count()).is_equal(0)


func test_server_full_rejected() -> void:
	var small := _net.duplicate()
	small["max_clients"] = 1
	_server.stop()
	_hub = LoopbackHub.new()
	_server = ServerSession.new(LoopbackTransport.new(_hub), small)
	_server.start(0)
	var a := _client("A")
	_run(0.3)
	var b := _client("B")
	_run(1.0)
	assert_int(a.state).is_equal(ClientSession.State.CONNECTED)
	assert_int(b.state).is_equal(ClientSession.State.REJECTED)
	assert_str(b.reject_reason).is_equal(Protocol.REJECT_SERVER_FULL)


func test_duplicate_names_get_suffix() -> void:
	var a := _client("Sam")
	var b := _client("sam")
	_run(0.5)
	assert_str(a.display_name).is_equal("Sam")
	assert_str(b.display_name).is_equal("sam 2")


func test_empty_name_rejected() -> void:
	var c := _client("   \t\n  ")
	_run(0.5)
	assert_str(c.reject_reason).is_equal(Protocol.REJECT_BAD_NAME)


func test_sanitize_name() -> void:
	assert_str(ServerSession.sanitize_name("  Big   \tBoss\n ", 20)).is_equal("Big Boss")
	assert_str(ServerSession.sanitize_name("abcdefghijklmnopqrstuvwxyz", 20)).is_equal("abcdefghijklmnopqrst")


func test_disconnect_updates_roster() -> void:
	var a := _client("Alice")
	var b := _client("Bob")
	_run(0.5)
	b.disconnect_from_server()
	_run(0.3)
	assert_int(_server.ready_count()).is_equal(1)
	assert_int(a.roster.size()).is_equal(1)
	assert_str(a.roster[0]["name"]).is_equal("Alice")


func test_ping_measures_rtt() -> void:
	var a := _client("Alice")
	_run(1.5)
	assert_int(a.rtt_ms).is_greater_equal(0)
	assert_int(a.rtt_ms).is_less(200)


func test_silent_client_times_out() -> void:
	# A raw transport that connects but never says HELLO.
	var raw := LoopbackTransport.new(_hub)
	raw.connect_to("loopback", 0)
	var got_reject := [false]
	raw.packet_received.connect(func(_from: int, bytes: PackedByteArray) -> void:
		var msg := Protocol.decode(bytes, 16384)
		if msg["ok"] and msg["type"] == Protocol.Msg.REJECT:
			got_reject[0] = msg["payload"]["reason"] == Protocol.REJECT_HANDSHAKE_TIMEOUT)
	var t := 0.0
	while t < float(_net["handshake_timeout_seconds"]) + 1.0:
		_server.tick(DT)
		raw.poll()
		t += DT
	assert_bool(got_reject[0]).is_true()
	assert_int(_server.clients.size()).is_equal(0)
	assert_bool(_hub.clients.has(raw.get_unique_id())).is_false()


func test_garbage_before_hello_is_rejected() -> void:
	var raw := LoopbackTransport.new(_hub)
	raw.connect_to("loopback", 0)
	_server.tick(DT)
	raw.poll()
	raw.send(Transport.SERVER_ID, PackedByteArray([7, 7, 7]))
	_server.tick(DT)
	assert_int(_server.clients.size()).is_equal(0)


func test_server_messages_are_recorded() -> void:
	var sent: Array = []
	_server.message_sent.connect(func(peer: int, type: int, _p: Dictionary) -> void: sent.append([peer, type]))
	var a := _client("Alice")
	_run(0.3)
	assert_bool(sent.has([a.peer_id, Protocol.Msg.WELCOME])).is_true()
	assert_bool(sent.has([a.peer_id, Protocol.Msg.ROSTER])).is_true()


func test_server_shutdown_disconnects_clients() -> void:
	var a := _client("Alice")
	_run(0.3)
	_server.stop()
	_run(0.1)
	assert_int(a.state).is_equal(ClientSession.State.DISCONNECTED)
	assert_array(a.roster).is_empty()
