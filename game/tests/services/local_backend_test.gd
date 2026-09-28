extends GdUnitTestSuite

const DEVICE := "device_test_0001"

var _dir: String
var _backend: LocalBackend


func before_test() -> void:
	_dir = create_temp_dir("backend_%d" % randi())
	_backend = LocalBackend.new(_dir)


func test_calls_require_login() -> void:
	var r := _backend.read_storage("settings", "main")
	assert_str(r.error).is_equal(BackendResult.NOT_AUTHENTICATED)


func test_guest_login_creates_account_and_profile() -> void:
	var r := _backend.authenticate_device(DEVICE)
	assert_bool(r.ok).is_true()
	assert_bool(r.data["created"]).is_true()
	assert_str(r.data["profile"]["display_name"]).starts_with("Guest-")
	assert_int(int(r.data["profile"]["level"])).is_equal(1)


func test_same_device_same_account_after_restart() -> void:
	var first := _backend.authenticate_device(DEVICE)
	var again := LocalBackend.new(_dir).authenticate_device(DEVICE)
	assert_str(again.data["user_id"]).is_equal(first.data["user_id"])
	assert_bool(again.data["created"]).is_false()
	var other := LocalBackend.new(_dir).authenticate_device("device_test_0002")
	assert_str(other.data["user_id"]).is_not_equal(first.data["user_id"])


func test_invalid_device_id() -> void:
	assert_str(_backend.authenticate_device("short").error).is_equal(BackendResult.INVALID_ARGUMENT)
	assert_str(_backend.authenticate_device("../../etc/passwd").error).is_equal(BackendResult.INVALID_ARGUMENT)


func test_storage_roundtrip_and_versions() -> void:
	_backend.authenticate_device(DEVICE)
	var w1 := _backend.write_storage("settings", "main", {"volume": 0.8})
	assert_str(w1.data["version"]).is_equal("1")
	var w2 := _backend.write_storage("settings", "main", {"volume": 0.5}, "1")
	assert_str(w2.data["version"]).is_equal("2")
	var stale := _backend.write_storage("settings", "main", {"volume": 0.1}, "1")
	assert_str(stale.error).is_equal(BackendResult.VERSION_CONFLICT)
	var create_only := _backend.write_storage("settings", "main", {}, "*")
	assert_str(create_only.error).is_equal(BackendResult.VERSION_CONFLICT)
	var read := _backend.read_storage("settings", "main")
	assert_float(float(read.data["value"]["volume"])).is_equal(0.5)
	assert_str(read.data["version"]).is_equal("2")


func test_storage_persists_across_instances() -> void:
	_backend.authenticate_device(DEVICE)
	_backend.write_storage("hud", "layout_standard", {"buttons": [1, 2, 3]})
	var fresh := LocalBackend.new(_dir)
	fresh.authenticate_device(DEVICE)
	assert_array(fresh.read_storage("hud", "layout_standard").data["value"]["buttons"]).has_size(3)


func test_list_and_delete() -> void:
	_backend.authenticate_device(DEVICE)
	_backend.write_storage("loadouts", "b", {})
	_backend.write_storage("loadouts", "a", {})
	assert_array(Array(_backend.list_storage("loadouts").data["keys"])).contains_exactly(["a", "b"])
	assert_bool(_backend.delete_storage("loadouts", "a").ok).is_true()
	assert_str(_backend.read_storage("loadouts", "a").error).is_equal(BackendResult.NOT_FOUND)
	assert_str(_backend.delete_storage("loadouts", "a").error).is_equal(BackendResult.NOT_FOUND)


func test_path_traversal_rejected() -> void:
	_backend.authenticate_device(DEVICE)
	assert_str(_backend.write_storage("../x", "k", {}).error).is_equal(BackendResult.INVALID_ARGUMENT)
	assert_str(_backend.read_storage("settings", "../../accounts").error).is_equal(BackendResult.INVALID_ARGUMENT)


func test_users_are_isolated() -> void:
	_backend.authenticate_device(DEVICE)
	_backend.write_storage("settings", "main", {"secret": true})
	var other := LocalBackend.new(_dir)
	other.authenticate_device("device_test_0002")
	assert_str(other.read_storage("settings", "main").error).is_equal(BackendResult.NOT_FOUND)


func test_update_profile() -> void:
	_backend.authenticate_device(DEVICE)
	var r := _backend.update_profile({"display_name": "  Captain  "})
	assert_bool(r.ok).is_true()
	assert_str(_backend.get_profile().data["value"]["display_name"]).is_equal("Captain")
	assert_str(_backend.update_profile({"xp": 99999}).error).is_equal(BackendResult.INVALID_ARGUMENT)
	assert_str(_backend.update_profile({"display_name": ""}).error).is_equal(BackendResult.INVALID_ARGUMENT)


func test_logout() -> void:
	_backend.authenticate_device(DEVICE)
	_backend.logout()
	assert_bool(_backend.is_authenticated()).is_false()


func test_device_identity_is_stable() -> void:
	var path := _dir.path_join("device_id.txt")
	var a := DeviceIdentity.get_or_create(path)
	var b := DeviceIdentity.get_or_create(path)
	assert_str(a).is_equal(b)
	assert_int(a.length()).is_equal(32)


func test_interface_defaults_are_unavailable() -> void:
	var base := BackendService.new()
	assert_str(base.read_storage("a", "b").error).is_equal(BackendResult.UNAVAILABLE)
