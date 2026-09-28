class_name BackendResult
extends RefCounted
## Outcome of a BackendService call.

const NOT_AUTHENTICATED := "not_authenticated"
const NOT_FOUND := "not_found"
const VERSION_CONFLICT := "version_conflict"
const INVALID_ARGUMENT := "invalid_argument"
const IO_ERROR := "io_error"
const UNAVAILABLE := "unavailable"

var ok := false
var error := ""
var message := ""
var data: Dictionary = {}


static func success(p_data: Dictionary = {}) -> BackendResult:
	var r := BackendResult.new()
	r.ok = true
	r.data = p_data
	return r


static func failure(code: String, p_message: String = "") -> BackendResult:
	var r := BackendResult.new()
	r.error = code
	r.message = p_message if not p_message.is_empty() else code
	return r


func _to_string() -> String:
	return "BackendResult(ok)" if ok else "BackendResult(%s: %s)" % [error, message]
