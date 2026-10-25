extends Node

const SERVER_PORT = 8080
const MAX_PLAYERS = 4
var playerList: Dictionary[int, Character]
var enemies: Dictionary[int, Character]

func get_character(id: int) -> Character:
	return playerList.get(id) if id > 0 else enemies.get(id)


func become_host() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, MAX_PLAYERS - 1)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error

func join_game(address: String) -> Error:
	if address.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address.strip_edges(), SERVER_PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error

func reset_session() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	playerList.clear()
	enemies.clear()
