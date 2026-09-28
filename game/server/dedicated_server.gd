extends Node
## Headless dedicated server entry point.
## Flags: --server [--port N] [--transport enet|ws] [--quit-after SECONDS]

var _elapsed := 0.0
var _quit_after := -1.0


func _ready() -> void:
	var net := GameData.table("network")
	Engine.physics_ticks_per_second = int(net["server_tick_rate"])
	var args := GameData.args
	_quit_after = args["quit_after"]
	var err := NetworkManager.start_server(args["port"], args["transport"])
	if err != OK:
		printerr("SERVER_FAILED %s" % error_string(err))
		get_tree().quit(1)
		return
	NetworkManager.server.client_joined.connect(_on_client_joined)
	NetworkManager.server.client_left.connect(_on_client_left)
	var port: int = args["port"] if args["port"] > 0 else NetworkManager.default_port()
	print("SERVER_READY port=%d transport=%s tick=%d" % [port, args["transport"], Engine.physics_ticks_per_second])


func _process(delta: float) -> void:
	_elapsed += delta
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		print("SERVER_STOPPING players=%d" % NetworkManager.server.ready_count())
		NetworkManager.stop_all()
		get_tree().quit(0)


func _on_client_joined(id: int, player_name: String) -> void:
	print("SERVER_CLIENT_JOINED id=%d name=%s players=%d" % [id, player_name, NetworkManager.server.ready_count()])


func _on_client_left(id: int) -> void:
	print("SERVER_CLIENT_LEFT id=%d players=%d" % [id, NetworkManager.server.ready_count()])
