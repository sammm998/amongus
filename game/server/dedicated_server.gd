extends Node
## Headless dedicated server entry point.
## Flags: --server [--port N] [--transport enet|ws] [--quit-after SECONDS]

var _elapsed := 0.0
var _quit_after := -1.0


func _ready() -> void:
	var net := GameData.table("network")
	var args := GameData.args
	var speed: float = maxf(1.0, args["sim_speed"])
	Engine.physics_ticks_per_second = int(net["server_tick_rate"] * speed)
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = speed
	_quit_after = args["quit_after"]
	var err := NetworkManager.start_server(args["port"], args["transport"])
	if err != OK:
		printerr("SERVER_FAILED %s" % error_string(err))
		get_tree().quit(1)
		return
	NetworkManager.server.client_joined.connect(_on_client_joined)
	NetworkManager.server.client_left.connect(_on_client_left)
	var match_server := NetworkManager.match_server
	match_server.match_ended.connect(_on_match_ended)
	if args["bots"] > 0:
		match_server.fill_bots(args["bots"])
	if args["auto_start"]:
		match_server.request_start.call_deferred()
	var port: int = args["port"] if args["port"] > 0 else NetworkManager.default_port()
	print("SERVER_READY port=%d transport=%s tick=%d" % [port, args["transport"], Engine.physics_ticks_per_second])


var _diag_timer := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if OS.get_environment("TI_BOT_DIAG") == "1":
		_diag_timer += delta
		if _diag_timer > 5.0:
			_diag_timer = 0.0
			var ms := NetworkManager.match_server
			for id: int in ms.bots:
				var b: BotBrain = ms.bots[id]
				var p: ServerPlayer = ms.players[id]
				print("DIAG t=%.0f %s %s goal=%s d=%.1f path=%d/%d stuck=%d pos=%s prompt=%s" % [ms.phases.elapsed, p.name, b.role, b.goal_kind, p.feet().distance_to(b.goal_pos), b.path_i, b.path.size(), b.stuck_count, p.feet().snapped(Vector3.ONE * 0.1), b.me.get("prompt", {}).get("label", "")])
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		print("SERVER_STOPPING players=%d" % NetworkManager.server.ready_count())
		NetworkManager.stop_all()
		get_tree().quit(0)


func _on_match_ended(result: Dictionary) -> void:
	var roles := {}
	for p: Dictionary in result["players"]:
		roles[p["role"]] = roles.get(p["role"], 0) + 1
	print("MATCH_RESULT winner=%s reason=%s duration=%.0f security=%.0f roles=%s" % [result["winner"], result["reason"], result["duration"], result["security"], roles])
	for line: Dictionary in result["timeline"]:
		print("  [%6.1f] %s" % [line["t"], line["text"]])
	if GameData.args["auto_start"]:
		NetworkManager.stop_all()
		get_tree().quit(0)


func _on_client_joined(id: int, player_name: String) -> void:
	print("SERVER_CLIENT_JOINED id=%d name=%s players=%d" % [id, player_name, NetworkManager.server.ready_count()])


func _on_client_left(id: int) -> void:
	print("SERVER_CLIENT_LEFT id=%d players=%d" % [id, NetworkManager.server.ready_count()])
