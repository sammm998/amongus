class_name GameDataRegistry
extends RefCounted
## Loads the JSON data tables listed in `manifest.json` and validates them.
## Pure: no nodes. Tables are shared, treat them as read-only.

const MANIFEST_FILE := "manifest.json"

var errors: PackedStringArray = []
var _tables: Dictionary = {}


func load_from_dir(dir_path: String) -> bool:
	_tables.clear()
	errors.clear()
	var manifest: Variant = read_json(dir_path.path_join(MANIFEST_FILE))
	if not (manifest is Dictionary) or not (manifest.get("tables") is Array):
		errors.append("Manifest missing or invalid in '%s'." % dir_path)
		return false
	for table_name: Variant in manifest["tables"]:
		var path := dir_path.path_join("%s.json" % table_name)
		var data: Variant = read_json(path)
		if not (data is Dictionary):
			errors.append("Table '%s' missing or not a JSON object (%s)." % [table_name, path])
			continue
		_tables[str(table_name)] = data
	errors.append_array(DataSchemas.validate_all(_tables))
	return errors.is_empty()


func has_table(table_name: String) -> bool:
	return _tables.has(table_name)


func table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		push_error("Unknown data table '%s'." % table_name)
		return {}
	return _tables[table_name]


func table_names() -> PackedStringArray:
	var names := PackedStringArray(_tables.keys())
	names.sort()
	return names


## Replaces or adds a table (tests and host overrides). Does not re-validate.
func set_table(table_name: String, data: Dictionary) -> void:
	_tables[table_name] = data


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON parse error in %s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
