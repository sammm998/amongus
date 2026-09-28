class_name MatchSettings
extends RefCounted
## Flattens lobby defaults + game mode overrides + host overrides into one
## settings dictionary. Overrides use dotted keys ("meeting.discussion_seconds").


static func build(lobby: Dictionary, modes: Dictionary, mode: String, overrides: Dictionary = {}) -> Dictionary:
	var settings := lobby.duplicate(true)
	settings["mode"] = mode
	for source: Dictionary in [modes.get(mode, {}), overrides]:
		for key: String in source:
			set_path(settings, key, source[key])
	return settings


static func set_path(target: Dictionary, path: String, value: Variant) -> void:
	var parts := path.split(".")
	var node := target
	for i in parts.size() - 1:
		if not (node.get(parts[i]) is Dictionary):
			node[parts[i]] = {}
		node = node[parts[i]]
	node[parts[parts.size() - 1]] = value
