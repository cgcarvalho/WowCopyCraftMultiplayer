extends Node

const HERO_SCENES = [
	"res://Scenes/Characters/Heroes/Aurora.tscn",
	"res://Scenes/Characters/Heroes/SirGura.tscn",
	"res://Scenes/Characters/Heroes/Lulu.tscn",
	"res://Scenes/Characters/Heroes/Charger.tscn",
]
@onready var players: Node = %Players
@onready var multiplayer_spawner: MultiplayerSpawner = %MultiplayerSpawner
@onready var uiHanlder: UIHandler = UIHandler.new(self)
@onready var status: Label = %ConnectionStatus
@onready var server_address: LineEdit = %ServerAddress
var used_slots: Dictionary[int, int] = {}

func _exit_tree() -> void:
	if is_instance_valid(uiHanlder):
		uiHanlder.free()

func _ready() -> void:
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer_spawner.spawn_function = add_player
	uiHanlder.changeScene(Constants.MAIN_SCREEN)

func become_host() -> void:
	var error = MultiplayerManager.become_host()
	if error != OK:
		status.text = "Falha ao criar servidor: " + error_string(error)
		return
	%MultiplayerHUD.hide()
	loadCharSelectionScreen()

func join_game() -> void:
	var error = MultiplayerManager.join_game(server_address.text)
	if error != OK:
		status.text = "Falha ao conectar: " + error_string(error)
		return
	status.text = "Conectando..."
	set_connection_buttons(false)

func on_connected() -> void:
	set_connection_buttons(true)
	%MultiplayerHUD.hide()
	loadCharSelectionScreen()

func on_connection_failed() -> void:
	MultiplayerManager.reset_session()
	set_connection_buttons(true)
	status.text = "Não foi possível conectar ao servidor."

func on_server_disconnected() -> void:
	for player in players.get_children():
		if player is Character:
			players.remove_child(player)
			player.queue_free()
	MultiplayerManager.reset_session()
	used_slots.clear()
	get_tree().reload_current_scene()

func set_connection_buttons(enabled: bool) -> void:
	get_node("MultiplayerHUD/Panel/VBoxContainer/Host").disabled = not enabled
	get_node("MultiplayerHUD/Panel/VBoxContainer/Join").disabled = not enabled

# Only MultiplayerSpawner calls this factory, including on late joining peers.
func add_player(spawn_data: Dictionary) -> Node:
	var id: int = spawn_data["id"]
	var path: String = spawn_data["path"]
	var slot: int = spawn_data["slot"]
	if path not in HERO_SCENES or slot < 0 or slot >= MultiplayerManager.MAX_PLAYERS:
		return null
	var player: Character = load(path).instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	player.z_index = Constants.PLAYER_Z_INDEX
	player.position = players.get_node("SpawnPoint" + str(slot)).position
	MultiplayerManager.playerList[id] = player
	return player

@rpc("any_peer", "call_local", "reliable")
func request_player(path: String) -> void:
	if not multiplayer.is_server() or path not in HERO_SCENES:
		return
	var sender = multiplayer.get_remote_sender_id()
	var id = sender if sender != 0 else multiplayer.get_unique_id()
	if MultiplayerManager.playerList.has(id):
		return
	for slot in MultiplayerManager.MAX_PLAYERS:
		if slot not in used_slots.values():
			used_slots[id] = slot
			multiplayer_spawner.spawn({"id": id, "path": path, "slot": slot})
			return

func on_peer_disconnected(id: int) -> void:
	var player: Character = MultiplayerManager.playerList.get(id)
	MultiplayerManager.playerList.erase(id)
	used_slots.erase(id)
	if is_instance_valid(player):
		for other in MultiplayerManager.playerList.values():
			if other.charCurrentTarget == player:
				other.charCurrentTarget = null
		if multiplayer.is_server():
			player.queue_free()

func loadCharSelectionScreen() -> void:
	var selection = uiHanlder.changeScene(Constants.PLAYER_SELECT_SCREEN)
	selection.playerSelected.connect(characterSelect)

func characterSelect(character: Character) -> void:
	request_player.rpc_id(1, character.scenePath)
	uiHanlder.changeScene(Constants.MAP_FOREST)
