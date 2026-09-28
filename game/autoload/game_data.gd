extends Node
## Autoload: data tables + parsed launch arguments.

const DATA_DIR := "res://data"

var registry := GameDataRegistry.new()
var args: Dictionary = CliArgs.DEFAULTS.duplicate()


func _enter_tree() -> void:
	args = CliArgs.parse(CliArgs.collect())
	if not registry.load_from_dir(DATA_DIR):
		for error in registry.errors:
			push_error("Data: %s" % error)


func table(table_name: String) -> Dictionary:
	return registry.table(table_name)


func is_dedicated_server() -> bool:
	return args["server"] or OS.has_feature("dedicated_server")


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
