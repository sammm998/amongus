extends GdUnitTestSuite


func test_tokenize() -> void:
	assert_array(Array(ConsoleCommandRegistry.tokenize("  echo  a   b "))).contains_exactly(["echo", "a", "b"])
	assert_array(Array(ConsoleCommandRegistry.tokenize("say \"hello there\" x"))).contains_exactly(["say", "hello there", "x"])
	assert_array(Array(ConsoleCommandRegistry.tokenize(""))).is_empty()
	assert_array(Array(ConsoleCommandRegistry.tokenize("x \"\""))).contains_exactly(["x", ""])


func test_execute_and_unknown() -> void:
	var r := ConsoleCommandRegistry.new()
	r.register("Add", "adds", func(a: PackedStringArray) -> String: return str(a[0].to_int() + a[1].to_int()))
	assert_str(r.execute("add 2 3")).is_equal("5")
	assert_str(r.execute("ADD 1 1")).is_equal("2")
	assert_str(r.execute("nope")).contains("Unknown command")
	assert_str(r.execute("   ")).is_empty()


func test_help_and_complete() -> void:
	var r := ConsoleCommandRegistry.new()
	r.register("net", "network", func(_a: PackedStringArray) -> String: return "")
	r.register("new", "new thing", func(_a: PackedStringArray) -> String: return "")
	r.register("quit", "quit", func(_a: PackedStringArray) -> String: return "")
	assert_str(r.help_text()).contains("network")
	assert_array(Array(r.complete("ne"))).contains_exactly(["net", "new"])
	assert_array(Array(r.complete("q"))).contains_exactly(["quit"])


func test_debug_console_autoload_commands() -> void:
	for command_name in ["help", "fps", "net", "roster", "input", "data", "backend", "screenshot", "quit"]:
		assert_bool(DebugConsole.registry.has_command(command_name)).override_failure_message(command_name).is_true()
	assert_str(DebugConsole.run("data")).contains("weapons")
	assert_str(DebugConsole.run("net")).is_equal("offline")
