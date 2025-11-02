extends Node

@onready var players: Node = %Players
@onready var multiplayer_spawner: MultiplayerSpawner = %MultiplayerSpawner
@onready var uiHanlder : UIHandler = UIHandler.new(self)

func _ready():
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer_spawner.spawn_function = add_player
	uiHanlder.changeScene(Constants.MAIN_SCREEN)

func become_host():
	%MultiplayerHUD.hide()
	MultiplayerManager.become_host()
	loadCharSelectionScreen()
	
func join_game():
	%MultiplayerHUD.hide()
	MultiplayerManager.join_game()
	loadCharSelectionScreen()

@rpc("any_peer", "call_local", "reliable")
func add_player(spawn_data):
	var id = spawn_data["id"]
	var path = spawn_data["path"]
	var player_instance = load(path).instantiate()
	var listLen = MultiplayerManager.playerList.size()
	
	player_instance.name = str(id) 
	player_instance.set_multiplayer_authority(id)
	player_instance.z_index = Constants.PLAYER_Z_INDEX
	
	MultiplayerManager.playerList[id] = player_instance
	player_instance.global_position = players.get_child(listLen).global_position
	
	if id != 1:
		players.add_child(player_instance, true)
	else:
		return player_instance

func on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var player_node = multiplayer_spawner.get_node_for_peer(id)
		if player_node:
			player_node.queue_free()

	
	
	#map.connect("playerSelected", characterSelect)
	
func loadCharSelectionScreen() -> void:
	var map = uiHanlder.changeScene(Constants.PLAYER_SELECT_SCREEN)
	map.connect("playerSelected", characterSelect)
	
func characterSelect(character : Character) -> void:
	var spawn_data = {
			"id": multiplayer.get_unique_id(),
			"path": character.scenePath
		}
	if multiplayer.is_server():
		multiplayer_spawner.spawn(spawn_data)
	else:
		add_player.rpc(spawn_data)
	
	uiHanlder.changeScene(Constants.MAP_FOREST)
	
