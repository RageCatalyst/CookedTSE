extends Node

@onready var multiplayer_ui = $UI
const PLAYER = preload("res://Scenes/Player.tscn")

var peer = ENetMultiplayerPeer.new()

func _on_host_pressed():
	peer.create_server(25565)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(
		func(pid):
			print("Peer " + str(pid) + " has joined the game!")
			_add_player(pid)
	)
	_add_player(multiplayer.get_unique_id())
	multiplayer_ui.hide()
	
func _add_player(pid):
	var player = PLAYER.instantiate()
	player.name = str(pid)
	add_child(player)
	player.position = Vector3(0, 2, 0)


func _on_connect_pressed():
	peer.create_client("localhost", 25565)
	multiplayer.multiplayer_peer = peer
	multiplayer_ui.hide()
