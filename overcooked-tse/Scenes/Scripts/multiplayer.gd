extends Node

@onready var multiplayer_ui = $UI
const PLAYER = preload("res://Scenes/Player.tscn")
const MAX_LOCAL_PLAYERS := 4

# Define spawn points for up to 4 players
var spawn_points := [
	Vector3(-3, 1.5, 0),
	Vector3(0, 1.5, 0),
	Vector3(3, 1.5, 0),
	Vector3(6, 1.5, 0)
]
var player_nodes := []

var local_player_count := 0

func _add_player():
	var player = PLAYER.instantiate()
	player.player_index = local_player_count
	player.name = str(local_player_count)
	# Use the spawn point based on player index, fallback to (0,0,0) if out of range
	if local_player_count < spawn_points.size():
		player.position = spawn_points[local_player_count]
	else:
		player.position = Vector3(0, 0, 0)
	add_child(player)
	player_nodes.append(player)
	local_player_count += 1

func _on_add_player_pressed() -> void:
	if local_player_count < MAX_LOCAL_PLAYERS:
		_add_player()
	else:
		print("Maximum number of players reached.")

func _on_remove_player() -> void:
	if player_nodes.size() > 0:
		var player = player_nodes.pop_back()
		player.queue_free()
		local_player_count -= 1
