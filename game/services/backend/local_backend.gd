class_name LocalBackend
extends BackendService
## BackendService stored as JSON files under a root directory.
## Layout: <root>/accounts.json, <root>/users/<user_id>/<collection>/<key>.json

const PROFILE_COLLECTION := "profile"
const PROFILE_KEY := "main"
const EDITABLE_PROFILE_FIELDS := ["display_name"]
const MAX_DISPLAY_NAME := 20

var root_dir: String
var _user_id := ""
var _name_regex := RegEx.create_from_string("^[a-z0-9_]{1,64}$")
var _device_regex := RegEx.create_from_string("^[A-Za-z0-9_-]{8,128}$")


func _init(p_root_dir: String) -> void:
	root_dir = p_root_dir


func get_backend_name() -> String:
	return "local"


func is_authenticated() -> bool:
	return not _user_id.is_empty()


func get_user_id() -> String:
	return _user_id


func authenticate_device(device_id: String, display_name: String = "") -> BackendResult:
	if _device_regex.search(device_id) == null:
		return BackendResult.failure(BackendResult.INVALID_ARGUMENT, "device id must be 8-128 chars of [A-Za-z0-9_-]")
	var accounts_path := root_dir.path_join("accounts.json")
	var accounts: Dictionary = _read_json(accounts_path, {})
	var created := false
	if not accounts.has(device_id):
		accounts[device_id] = {"user_id": _new_user_id(), "created_unix": int(Time.get_unix_time_from_system())}
		if not _write_json(accounts_path, accounts):
			return BackendResult.failure(BackendResult.IO_ERROR, "cannot write accounts")
		created = true
	_user_id = accounts[device_id]["user_id"]
	var profile := get_profile()
	if not profile.ok:
		var name := display_name.strip_edges().left(MAX_DISPLAY_NAME)
		if name.is_empty():
			name = "Guest-%s" % _user_id.left(4).to_upper()
		var write := write_storage(PROFILE_COLLECTION, PROFILE_KEY, {
			"display_name": name, "level": 1, "xp": 0,
			"created_unix": accounts[device_id]["created_unix"],
		})
		if not write.ok:
			_user_id = ""
			return write
		profile = get_profile()
	authenticated.emit(_user_id)
	return BackendResult.success({"user_id": _user_id, "created": created, "profile": profile.data["value"]})


func logout() -> void:
	if is_authenticated():
		_user_id = ""
		logged_out.emit()


func read_storage(collection: String, key: String) -> BackendResult:
	var check := _check(collection, key)
	if not check.ok:
		return check
	var record: Variant = _read_json(_record_path(collection, key), null)
	if not (record is Dictionary):
		return BackendResult.failure(BackendResult.NOT_FOUND)
	return BackendResult.success({"value": record["value"], "version": str(record["version"])})


func write_storage(collection: String, key: String, value: Dictionary, expected_version: String = "") -> BackendResult:
	var check := _check(collection, key)
	if not check.ok:
		return check
	var path := _record_path(collection, key)
	var existing: Variant = _read_json(path, null)
	var current_version := int(existing["version"]) if existing is Dictionary else 0
	if expected_version == "*" and current_version != 0:
		return BackendResult.failure(BackendResult.VERSION_CONFLICT, "record already exists")
	if expected_version != "" and expected_version != "*" and expected_version != str(current_version):
		return BackendResult.failure(BackendResult.VERSION_CONFLICT, "expected %s, found %d" % [expected_version, current_version])
	var new_version := current_version + 1
	if not _write_json(path, {"version": new_version, "value": value}):
		return BackendResult.failure(BackendResult.IO_ERROR, "cannot write %s" % path)
	return BackendResult.success({"version": str(new_version)})


func delete_storage(collection: String, key: String) -> BackendResult:
	var check := _check(collection, key)
	if not check.ok:
		return check
	var path := _record_path(collection, key)
	if not FileAccess.file_exists(path):
		return BackendResult.failure(BackendResult.NOT_FOUND)
	if DirAccess.remove_absolute(path) != OK:
		return BackendResult.failure(BackendResult.IO_ERROR)
	return BackendResult.success()


func list_storage(collection: String) -> BackendResult:
	var check := _check(collection, "x")
	if not check.ok:
		return check
	var keys := PackedStringArray()
	var dir := DirAccess.open(_user_dir().path_join(collection))
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".json"):
				keys.append(file_name.trim_suffix(".json"))
	keys.sort()
	return BackendResult.success({"keys": keys})


func get_profile() -> BackendResult:
	return read_storage(PROFILE_COLLECTION, PROFILE_KEY)


func update_profile(changes: Dictionary) -> BackendResult:
	for field: Variant in changes:
		if not field in EDITABLE_PROFILE_FIELDS:
			return BackendResult.failure(BackendResult.INVALID_ARGUMENT, "field '%s' is not editable" % field)
	if changes.has("display_name"):
		var name := str(changes["display_name"]).strip_edges()
		if name.is_empty() or name.length() > MAX_DISPLAY_NAME:
			return BackendResult.failure(BackendResult.INVALID_ARGUMENT, "display name must be 1-%d characters" % MAX_DISPLAY_NAME)
		changes = changes.duplicate()
		changes["display_name"] = name
	var current := get_profile()
	if not current.ok:
		return current
	var merged: Dictionary = current.data["value"].duplicate()
	merged.merge(changes, true)
	var write := write_storage(PROFILE_COLLECTION, PROFILE_KEY, merged, current.data["version"])
	if not write.ok:
		return write
	return BackendResult.success({"value": merged, "version": write.data["version"]})


func _check(collection: String, key: String) -> BackendResult:
	if not is_authenticated():
		return BackendResult.failure(BackendResult.NOT_AUTHENTICATED)
	if _name_regex.search(collection) == null or _name_regex.search(key) == null:
		return BackendResult.failure(BackendResult.INVALID_ARGUMENT, "collection and key must match [a-z0-9_]{1,64}")
	return BackendResult.success()


func _user_dir() -> String:
	return root_dir.path_join("users").path_join(_user_id)


func _record_path(collection: String, key: String) -> String:
	return _user_dir().path_join(collection).path_join("%s.json" % key)


func _new_user_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func _read_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed != null else fallback


## Writes via a temp file + rename so a crash never leaves a half-written record.
static func _write_json(path: String, data: Variant) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK
