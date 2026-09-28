extends Node
## Autoload: owns the BackendService and performs guest login on clients.

signal login_finished(ok: bool)

const DEFAULT_LOCAL_DIR := "user://local_backend"

var service: BackendService
var display_name := ""
var last_error := ""


func _ready() -> void:
	var dir: String = GameData.args["backend_dir"]
	service = LocalBackend.new(dir if not dir.is_empty() else DEFAULT_LOCAL_DIR)
	if not GameData.is_dedicated_server():
		login.call_deferred()


func login() -> void:
	var profile: String = GameData.args["profile"]
	var id_file := "user://device_id%s.txt" % ("" if profile.is_empty() else "_" + profile.validate_filename())
	var device_id := DeviceIdentity.get_or_create(id_file)
	var result: BackendResult = await service.authenticate_device(device_id)
	if result.ok:
		display_name = result.data["profile"]["display_name"]
		last_error = ""
	else:
		last_error = result.message
		push_warning("Backend login failed: %s" % result)
	login_finished.emit(result.ok)


func status_text() -> String:
	if service == null:
		return "no backend"
	if service.is_authenticated():
		return "%s (%s backend)" % [display_name, service.get_backend_name()]
	return "not signed in" + ("" if last_error.is_empty() else " — " + last_error)
