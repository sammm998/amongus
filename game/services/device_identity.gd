class_name DeviceIdentity
extends RefCounted
## Stable per-install device id used for guest login. Stored in a small file
## so it survives restarts on every platform (OS.get_unique_id is empty on web).


static func get_or_create(path: String) -> String:
	if FileAccess.file_exists(path):
		var existing := FileAccess.get_file_as_string(path).strip_edges()
		if existing.length() >= 8:
			return existing
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(id)
	return id
