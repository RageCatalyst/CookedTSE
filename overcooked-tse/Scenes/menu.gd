extends Control

const MAX_PLAYERS := 4
var joined_players := [false, false, false, false]

@onready var player_labels := [
	$VBoxContainer/PlayerList/Label,
	$VBoxContainer/PlayerList/Label2,
	$VBoxContainer/PlayerList/Label3,
	$VBoxContainer/PlayerList/Label4
]

func _on_start_pressed():
	if joined_players.count(true) == 0:
		return # Don't start if no players
	var game_scene = preload("res://Scenes/game.tscn").instantiate()
	var multiplayer = game_scene
	multiplayer.local_player_count = 0
	for i in range(MAX_PLAYERS):
		if joined_players[i]:
			multiplayer.call_deferred("_add_player")
	get_tree().root.add_child(game_scene)
	get_tree().current_scene = game_scene
	queue_free()

func _on_quit_pressed():
	get_tree().quit()

func _on_add_player_pressed():
	for i in range(MAX_PLAYERS):
		if not joined_players[i]:
			joined_players[i] = true
			_update_player_labels()
			break

func _on_remove_player_pressed():
	for i in range(MAX_PLAYERS - 1, -1, -1):
		if joined_players[i]:
			joined_players[i] = false
			_update_player_labels()
			break

func _update_player_labels():
	for i in range(MAX_PLAYERS):
		if joined_players[i]:
			player_labels[i].text = "- Player %d: Joined" % [i+1]
		else:
			player_labels[i].text = "- Player %d: Not Joined" % [i+1]
