class_name CliArgs
extends RefCounted
## Parses launch flags. Accepts "--key value" and "--key=value".
## Flags go after "--" on the Godot command line (user args), but plain args are read too.

const DEFAULTS := {
	"server": false,
	"host": false,
	"port": -1,
	"connect": "",
	"transport": "enet",
	"name": "",
	"profile": "",
	"screenshot": "",
	"frames": -1,
	"quit_after": -1.0,
	"expect_roster": -1,
	"backend_dir": "",
	"console": false,
}
const BOOL_FLAGS := ["server", "host", "console"]
const TRANSPORTS := ["enet", "ws"]


static func collect() -> PackedStringArray:
	var all := OS.get_cmdline_args()
	all.append_array(OS.get_cmdline_user_args())
	return all


static func parse(args: PackedStringArray) -> Dictionary:
	var result := DEFAULTS.duplicate()
	var i := 0
	while i < args.size():
		var arg := args[i]
		i += 1
		if not arg.begins_with("--") or arg == "--":
			continue
		var key := arg.substr(2)
		var value := ""
		var has_inline := key.contains("=")
		if has_inline:
			value = key.get_slice("=", 1)
			key = key.get_slice("=", 0)
		key = key.replace("-", "_")
		if not result.has(key):
			continue
		if key in BOOL_FLAGS:
			result[key] = true if not has_inline else value in ["1", "true", "yes"]
			continue
		if not has_inline:
			if i >= args.size():
				continue
			value = args[i]
			i += 1
		match typeof(DEFAULTS[key]):
			TYPE_INT:
				if value.is_valid_int():
					result[key] = value.to_int()
			TYPE_FLOAT:
				if value.is_valid_float():
					result[key] = value.to_float()
			_:
				result[key] = value
	if not result["transport"] in TRANSPORTS:
		result["transport"] = DEFAULTS["transport"]
	return result
