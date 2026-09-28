class_name ConsoleCommandRegistry
extends RefCounted
## Debug console commands. Handlers take PackedStringArray args and return output text.

var _commands: Dictionary = {}  # name -> {help, handler}


func register(command_name: String, help: String, handler: Callable) -> void:
	_commands[command_name.to_lower()] = {"help": help, "handler": handler}


func has_command(command_name: String) -> bool:
	return _commands.has(command_name.to_lower())


func names() -> PackedStringArray:
	var list := PackedStringArray(_commands.keys())
	list.sort()
	return list


func execute(line: String) -> String:
	var parts := tokenize(line)
	if parts.is_empty():
		return ""
	var command_name := parts[0].to_lower()
	if not _commands.has(command_name):
		return "Unknown command '%s'. Type 'help'." % command_name
	var result: Variant = _commands[command_name]["handler"].call(parts.slice(1))
	return "" if result == null else str(result)


func help_text() -> String:
	var lines := PackedStringArray()
	for command_name in names():
		lines.append("%-12s %s" % [command_name, _commands[command_name]["help"]])
	return "\n".join(lines)


func complete(prefix: String) -> PackedStringArray:
	var matches := PackedStringArray()
	for command_name in names():
		if command_name.begins_with(prefix.to_lower()):
			matches.append(command_name)
	return matches


## Splits on whitespace; double quotes group words.
static func tokenize(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var current := ""
	var in_quotes := false
	var has_token := false
	for ch in line:
		if ch == "\"":
			in_quotes = not in_quotes
			has_token = true
		elif (ch == " " or ch == "\t") and not in_quotes:
			if has_token:
				out.append(current)
			current = ""
			has_token = false
		else:
			current += ch
			has_token = true
	if has_token:
		out.append(current)
	return out
