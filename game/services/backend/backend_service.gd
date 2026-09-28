class_name BackendService
extends RefCounted
## Online services interface (GAME_SPEC §3). Implementations: LocalBackend
## (JSON files, tests/offline) and, from M6, NakamaBackend.
## Implementations may be coroutines, so callers must always `await` calls:
##     var result: BackendResult = await backend.read_storage("settings", "main")
## Storage versions are opaque strings. expected_version "" = unconditional
## write, "*" = only create if missing, anything else = must match.

signal authenticated(user_id: String)
signal logged_out


func get_backend_name() -> String:
	return "none"


func is_authenticated() -> bool:
	return false


func get_user_id() -> String:
	return ""


func authenticate_device(_device_id: String, _display_name: String = "") -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)


func logout() -> void:
	pass


func read_storage(_collection: String, _key: String) -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)


func write_storage(_collection: String, _key: String, _value: Dictionary, _expected_version: String = "") -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)


func delete_storage(_collection: String, _key: String) -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)


func list_storage(_collection: String) -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)


func get_profile() -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)


func update_profile(_changes: Dictionary) -> BackendResult:
	return BackendResult.failure(BackendResult.UNAVAILABLE)
