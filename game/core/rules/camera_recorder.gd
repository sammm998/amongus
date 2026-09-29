class_name CameraRecorder
extends RefCounted
## Security camera replay buffer (GAME_SPEC §5.8): the last N seconds of each
## feed as low-rate snapshots (positions + pose), not video. Jammed or
## unpowered cameras record nothing (a gap).

var seconds := 10.0
var feeds: Dictionary = {}  # camera id -> Array of [time, entries or null]


func _init(p_seconds: float = 10.0) -> void:
	seconds = p_seconds


func record(camera_id: String, now: float, entries: Array, jammed: bool) -> void:
	if not feeds.has(camera_id):
		feeds[camera_id] = []
	var frames: Array = feeds[camera_id]
	frames.append([now, null if jammed else entries])
	while not frames.is_empty() and now - float(frames[0][0]) > seconds:
		frames.pop_front()


## Clip for replay: [[seconds_before_now, entries or null], ...] oldest first.
func clip(camera_id: String, now: float) -> Array:
	var out: Array = []
	for f: Array in feeds.get(camera_id, []):
		out.append([now - float(f[0]), f[1]])
	return out
