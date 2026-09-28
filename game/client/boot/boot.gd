extends Node
## Main scene: routes to the dedicated server or the client front end.

const SERVER_SCENE := "res://server/dedicated_server.tscn"
const CLIENT_SCENE := "res://client/lobby/dev_lobby.tscn"


func _ready() -> void:
	var target := SERVER_SCENE if GameData.is_dedicated_server() else CLIENT_SCENE
	get_tree().change_scene_to_file.call_deferred(target)
