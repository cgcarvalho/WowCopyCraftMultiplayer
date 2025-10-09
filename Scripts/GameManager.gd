extends Node

@export var player_scene: PackedScene = preload("res://Scenes/Characters/Heroes/Aurora.tscn")
@export var player_scene2: PackedScene = preload("res://Scenes/Characters/Heroes/SirGura.tscn")

func _ready():
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	$MultiplayerSpawner.spawn_function = add_player
	loadMap()

func become_host():
	%MultiplayerHUD.hide()
	MultiplayerManager.become_host()
	$MultiplayerSpawner.spawn(1)
	
func join_game():
	%MultiplayerHUD.hide()
	MultiplayerManager.join_game()

func add_player(id: int):
	var player_instance
	var listLen = MultiplayerManager.playerList.size()


	if id == 1:
		player_instance = player_scene.instantiate()
	else:
		player_instance = player_scene2.instantiate()
		
	player_instance.name = str(id) 
	player_instance.set_multiplayer_authority(id)
	player_instance.z_index = 1
	
	if id == 1:
		player_instance.charTeam = Character.Teams.RED
	else:
		player_instance.charTeam = Character.Teams.BLUE
	
	MultiplayerManager.playerList[id] = player_instance
	player_instance.global_position = %Players.get_child(listLen).global_position

	return player_instance

func on_peer_connected(id: int):
	if multiplayer.is_server():
		$MultiplayerSpawner.spawn(id)
	
func on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var player_node = $MultiplayerSpawner.get_node_for_peer(id)
		if player_node:
			player_node.queue_free()


func loadMap():
	var map = load("res://Scenes/Maps/MapForest.tscn").instantiate()
	get_node_or_null("CurrentMap").add_child(map)
