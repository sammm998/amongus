extends Node
## Autoload: `--screenshot <path> [--frames N]` renders N frames, saves the
## viewport as PNG and quits. Also used by the `screenshot` console command.

signal saved(path: String)


func _ready() -> void:
	var path: String = GameData.args["screenshot"]
	if path.is_empty():
		return
	var frames: int = GameData.args["frames"]
	if frames <= 0:
		frames = int(GameData.table("debug")["screenshot_default_frames"])
	for i in frames:
		await get_tree().process_frame
	var err: Error = await capture(path)
	get_tree().quit(0 if err == OK else 1)


func capture(path: String) -> Error:
	if GameData.is_headless():
		push_error("Screenshots need a display (run under xvfb-run).")
		return ERR_UNAVAILABLE
	await RenderingServer.frame_post_draw
	var target := resolve_path(path)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var err := get_viewport().get_texture().get_image().save_png(target)
	if err == OK:
		print("SCREENSHOT_SAVED ", target)
		saved.emit(target)
	else:
		push_error("Screenshot failed (%s): %s" % [error_string(err), target])
	return err


## Relative paths are resolved against the shell's working directory.
static func resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	var cwd := OS.get_environment("PWD")
	return cwd.path_join(path).simplify_path() if not cwd.is_empty() else path
