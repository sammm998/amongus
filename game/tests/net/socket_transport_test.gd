extends GdUnitTestSuite
## Real sockets in one process: a server and two clients over ENet and WebSocket.

var _net: Dictionary


func before() -> void:
	_net = GameDataRegistry.read_json("res://data/network.json")


func test_enet_two_clients() -> void:
	_check_transport(func() -> Transport: return ENetTransport.new(), 25101)


func test_websocket_two_clients() -> void:
	_check_transport(func() -> Transport: return WebSocketTransport.new(), 25102)


func test_enet_connect_to_closed_port_fails() -> void:
	var cfg := _net.duplicate()
	cfg["client_connect_timeout_seconds"] = 1.0
	var c := ClientSession.new(ENetTransport.new(), cfg, "Lonely")
	c.connect_to("127.0.0.1", 25109)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3000 and c.state != ClientSession.State.FAILED:
		c.tick(1.0 / 60.0)
		OS.delay_msec(16)
	assert_int(c.state).is_equal(ClientSession.State.FAILED)


func _check_transport(make: Callable, port: int) -> void:
	var server := ServerSession.new(make.call(), _net)
	assert_int(server.start(port)).is_equal(OK)
	var a := ClientSession.new(make.call(), _net, "Alice")
	var b := ClientSession.new(make.call(), _net, "Bob")
	assert_int(a.connect_to("127.0.0.1", port)).is_equal(OK)
	assert_int(b.connect_to("127.0.0.1", port)).is_equal(OK)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 5000:
		server.tick(1.0 / 60.0)
		a.tick(1.0 / 60.0)
		b.tick(1.0 / 60.0)
		if a.roster.size() == 2 and b.roster.size() == 2:
			break
		OS.delay_msec(5)
	assert_int(a.state).is_equal(ClientSession.State.CONNECTED)
	assert_int(b.state).is_equal(ClientSession.State.CONNECTED)
	assert_int(a.roster.size()).is_equal(2)
	assert_int(b.roster.size()).is_equal(2)
	a.disconnect_from_server()
	b.disconnect_from_server()
	server.stop()
