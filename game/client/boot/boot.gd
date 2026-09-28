extends Node
## Main scene: routes to the dedicated server or the client front end.

const SERVER_SCENE := "res://server/dedicated_server.tscn"
const CLIENT_SCENE := "res://client/lobby/dev_lobby.tscn"
## `--scene <name>` jumps straight to a scene (look-dev, tests).
const SCENES := {
	"cove": "res://world/sunset_cove/sunset_cove.tscn",
	"lobby": CLIENT_SCENE,
}


func _ready() -> void:
	var target := SERVER_SCENE if GameData.is_dedicated_server() else CLIENT_SCENE
	var scene: String = GameData.args["scene"]
	if not GameData.is_dedicated_server() and SCENES.has(scene):
		target = SCENES[scene]
	get_tree().change_scene_to_file.call_deferred(target)
