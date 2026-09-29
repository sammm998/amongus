class_name CoopTracker
extends RefCounted
## Cooperative task steps (GAME_SPEC §5.6): two players at two consoles within
## a time window. One press waits for the paired console to be completed by a
## *different* player inside the window.

var window := 3.0
var presses: Array = []  # {player, station, time}


func _init(p_window: float = 3.0) -> void:
	window = p_window


## Registers a completed hold at `station`. If the partner console was pressed
## by someone else within the window, returns that press ({player, station});
## otherwise records this press and returns {}.
func press(player: int, station: String, partner_station: String, now: float) -> Dictionary:
	presses = presses.filter(func(p: Dictionary) -> bool: return now - float(p["time"]) <= window)
	for p: Dictionary in presses:
		if p["station"] == partner_station and p["player"] != player:
			presses.erase(p)
			return p
	presses = presses.filter(func(p: Dictionary) -> bool: return not (p["player"] == player and p["station"] == station))
	presses.append({"player": player, "station": station, "time": now})
	return {}
