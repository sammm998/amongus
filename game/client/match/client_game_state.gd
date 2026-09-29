class_name ClientGameState
extends RefCounted
## Everything the client knows about the current match, built only from
## messages the server sent to this client. UI and controllers read from here.

signal info_changed
signal role_changed
signal tasks_changed
signal panel_changed
signal world_changed
signal meeting_changed
signal meeting_result(payload: Dictionary)
signal results_received(payload: Dictionary)
signal chat_received(payload: Dictionary)
signal event_received(kind: String, data: Dictionary)
signal snapshot_received(payload: Dictionary)

const SNAPSHOT_BUFFER := 32

var info: Dictionary = {}
var phase := ""
var players: Dictionary = {}  # id -> {name, color, bot}
var host := 0
var role := ""
var allies: Array = []
var tasks: Array = []
var panel: Dictionary = {}
var world: Dictionary = {"security": 0.0, "sabotages": [], "power": true, "suspects": [], "generators": []}
var meeting: Dictionary = {}
var last_meeting_result: Dictionary = {}
var results: Dictionary = {}
var snapshots: Array = []
var me: Dictionary = {}
var chat_log: Array = []
var server_time_offset := 0.0   # server_time - local_time
var _offset_ready := false


func reset() -> void:
	info = {}
	phase = ""
	players = {}
	role = ""
	allies = []
	tasks = []
	panel = {}
	meeting = {}
	results = {}
	snapshots = []
	me = {}
	chat_log = []
	_offset_ready = false


func handle(type: int, p: Dictionary, local_time: float) -> void:
	match type:
		Protocol.Msg.MATCH_INFO:
			var old_phase := phase
			info = p
			phase = p["phase"]
			host = p["host"]
			players.clear()
			for e: Dictionary in p["players"]:
				players[e["id"]] = e
			if old_phase != phase and phase == "WAITING":
				role = ""
				allies = []
				tasks = []
				panel = {}
				results = {}
				meeting = {}
			info_changed.emit()
		Protocol.Msg.ROLE:
			role = p["role"]
			allies = p["allies"]
			role_changed.emit()
		Protocol.Msg.TASKS:
			tasks = p["tasks"]
			tasks_changed.emit()
		Protocol.Msg.SABOTAGE_PANEL:
			panel = p["panel"]
			panel_changed.emit()
		Protocol.Msg.WORLD:
			world = p
			world_changed.emit()
		Protocol.Msg.MEETING:
			meeting = p
			meeting_changed.emit()
		Protocol.Msg.MEETING_RESULT:
			last_meeting_result = p
			meeting = {}
			meeting_result.emit(p)
			meeting_changed.emit()
		Protocol.Msg.RESULTS:
			results = p
			results_received.emit(p)
		Protocol.Msg.CHAT_MSG:
			chat_log.append(p)
			if chat_log.size() > 60:
				chat_log.pop_front()
			chat_received.emit(p)
		Protocol.Msg.EVENT:
			event_received.emit(p["kind"], p["data"])
		Protocol.Msg.SNAPSHOT:
			_add_snapshot(p, local_time)
			me = p["me"]
			snapshot_received.emit(p)


func _add_snapshot(p: Dictionary, local_time: float) -> void:
	var offset := float(p["time"]) - local_time
	if not _offset_ready:
		server_time_offset = offset
		_offset_ready = true
	else:
		# Track the freshest arrival; drift slowly otherwise (jitter tolerant).
		server_time_offset = maxf(offset, lerpf(server_time_offset, offset, 0.02))
	snapshots.append(p)
	if snapshots.size() > SNAPSHOT_BUFFER:
		snapshots.pop_front()


func server_now(local_time: float) -> float:
	return local_time + server_time_offset


## Interpolated remote state at a server time: {id: [pos, yaw, pitch, state, weapon, flags]}.
func sample_players(t: float) -> Dictionary:
	var out := {}
	if snapshots.is_empty():
		return out
	var a: Dictionary = snapshots[0]
	var b: Dictionary = snapshots[-1]
	for i in range(snapshots.size() - 1):
		if float(snapshots[i]["time"]) <= t and float(snapshots[i + 1]["time"]) >= t:
			a = snapshots[i]
			b = snapshots[i + 1]
			break
	if t > float(b["time"]):
		a = b
	var span := maxf(0.0001, float(b["time"]) - float(a["time"]))
	var f := clampf((t - float(a["time"])) / span, 0.0, 1.0)
	var prev := {}
	for e: Array in a["players"]:
		prev[e[0]] = e
	for e: Array in b["players"]:
		var pe: Array = prev.get(e[0], e)
		out[e[0]] = [(pe[1] as Vector3).lerp(e[1], f), lerp_angle(pe[2], e[2], f), lerpf(pe[3], e[3], f), e[4], e[5], e[6]]
	return out


func latest() -> Dictionary:
	return snapshots[-1] if not snapshots.is_empty() else {}


func player_name(id: int) -> String:
	return players.get(id, {}).get("name", "?")


func player_color(id: int) -> int:
	return int(players.get(id, {}).get("color", 0))


func is_suspect(id: int) -> bool:
	for s: Array in world.get("suspects", []):
		if s[0] == id:
			return true
	return false


func my_id() -> int:
	return int(me.get("id", 0))


func my_state() -> int:
	return int(me.get("state", Vitals.State.ALIVE))


func is_spectator() -> bool:
	return bool(me.get("spectator", false))


func district_dark(district: String) -> bool:
	if not bool(world.get("power", true)):
		return true
	for s: Dictionary in world.get("sabotages", []):
		if s["kind"] == "blackout" and s["district"] == district:
			return true
	return false


func camera_jammed(district: String) -> bool:
	if not bool(world.get("power", true)):
		return true
	for s: Dictionary in world.get("sabotages", []):
		if s["kind"] == "camera_jam" and (s["district"] == district or String(s["district"]).is_empty()):
			return true
	return false
