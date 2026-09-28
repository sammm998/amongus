class_name TaskBoard
extends RefCounted
## Task lists and Island Security (GAME_SPEC §5.6).
## Each player gets N distinct tasks, spread across districts. Traitors get an
## equally long fake list: steps advance so they can "work", but add no progress.
## Required progress = sum of agent task weights at match start.

var pool: Dictionary = {}
var lists: Dictionary = {}  # player_id -> Array of task dicts
var required := 0.0
var completed := 0.0
var hold_tolerance := 0.35
var coop_multiplier := 2.0


func _init(tasks_table: Dictionary = {}) -> void:
	pool = tasks_table.get("pool", {})
	hold_tolerance = float(tasks_table.get("hold_tolerance_seconds", 0.35))
	coop_multiplier = float(tasks_table.get("cooperative_weight_multiplier", 2.0))


## station_districts: station_id -> district name (to spread tasks around the map).
func assign(agents: Array, traitors: Array, count: int, station_districts: Dictionary, rng: RandomNumberGenerator) -> void:
	lists.clear()
	required = 0.0
	completed = 0.0
	for pid: int in agents:
		lists[pid] = _draw(count, station_districts, rng, false)
		for t: Dictionary in lists[pid]:
			required += t["weight"]
	for pid: int in traitors:
		lists[pid] = _draw(count, station_districts, rng, true)


func _draw(count: int, station_districts: Dictionary, rng: RandomNumberGenerator, fake: bool) -> Array:
	var ids: Array = pool.keys()
	ids.sort()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var used_districts := {}
	var picked: Array = []
	# Two passes: first prefer tasks whose first station is in a new district.
	for pass_i in 2:
		for task_id: String in ids:
			if picked.size() >= count:
				break
			if picked.any(func(t: Dictionary) -> bool: return t["id"] == task_id):
				continue
			var inst := _instantiate(task_id, rng, fake)
			var district: String = station_districts.get(inst["steps"][0]["station"], "")
			if pass_i == 0 and used_districts.has(district):
				continue
			used_districts[district] = true
			picked.append(inst)
	return picked


func _instantiate(task_id: String, rng: RandomNumberGenerator, fake: bool) -> Dictionary:
	var def: Dictionary = pool[task_id]
	var steps: Array = []
	if def.has("steps"):
		for step: Dictionary in def["steps"]:
			var stations: Array = step["stations"]
			steps.append({"station": stations[rng.randi_range(0, stations.size() - 1)], "hold": float(step.get("hold_seconds", 0.0)), "label": step.get("label", "")})
	else:
		var stations: Array = def["stations"]
		var hold := float(def.get("hold_seconds", 0.0)) if def["kind"] != "travel" else 0.0
		steps.append({"station": stations[rng.randi_range(0, stations.size() - 1)], "hold": hold, "label": def["display_name"]})
	var weight := float(def.get("weight", 1.0))
	if def["kind"] == "cooperative":
		weight *= coop_multiplier
	return {
		"id": task_id, "name": def["display_name"], "kind": def["kind"], "weight": weight,
		"steps": steps, "step": 0, "done": false, "fake": fake,
	}


func tasks_for(player: int) -> Array:
	return lists.get(player, [])


func current_station(player: int, index: int) -> String:
	var list := tasks_for(player)
	if index < 0 or index >= list.size() or list[index]["done"]:
		return ""
	return list[index]["steps"][list[index]["step"]]["station"]


## Validates and applies one task step. `held` = seconds the server saw the
## player hold interact at the station. Returns {ok, reason, task_done, progress}.
func complete_step(player: int, index: int, station: String, held: float) -> Dictionary:
	var list := tasks_for(player)
	if index < 0 or index >= list.size():
		return {"ok": false, "reason": "no_task", "task_done": false, "progress": 0.0}
	var t: Dictionary = list[index]
	if t["done"]:
		return {"ok": false, "reason": "already_done", "task_done": false, "progress": 0.0}
	var step: Dictionary = t["steps"][t["step"]]
	if step["station"] != station:
		return {"ok": false, "reason": "wrong_station", "task_done": false, "progress": 0.0}
	if held + hold_tolerance < float(step["hold"]):
		return {"ok": false, "reason": "too_fast", "task_done": false, "progress": 0.0}
	t["step"] += 1
	var progress := 0.0
	if t["step"] >= t["steps"].size():
		t["done"] = true
		t["step"] = t["steps"].size() - 1
		if not t["fake"]:
			progress = t["weight"]
			completed += progress
	return {"ok": true, "reason": "", "task_done": t["done"], "progress": progress}


func security_percent() -> float:
	if required <= 0.0:
		return 0.0
	return minf(100.0, completed / required * 100.0)


## Public view of a player's own list (what their client receives).
func view_for(player: int) -> Array:
	var out: Array = []
	for t: Dictionary in tasks_for(player):
		var step: Dictionary = t["steps"][t["step"]]
		out.append({
			"id": t["id"], "name": t["name"], "kind": t["kind"], "done": t["done"],
			"step": t["step"], "steps": t["steps"].size(), "station": step["station"],
			"label": step["label"], "hold": step["hold"],
		})
	return out


func all_stations() -> Array:
	var set := {}
	for task: Dictionary in pool.values():
		if task.has("steps"):
			for step: Dictionary in task["steps"]:
				for s: String in step["stations"]:
					set[s] = true
		else:
			for s: String in task["stations"]:
				set[s] = true
	return set.keys()
