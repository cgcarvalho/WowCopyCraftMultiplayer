extends Node

const SERVER_PORT = 8080
const SERVER_IP = "192.168.50.60"

var playerList : Dictionary[int, Character]

func become_host():
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	multiplayer.multiplayer_peer = server_peer
	
	
func join_game():
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	multiplayer.multiplayer_peer = client_peer
