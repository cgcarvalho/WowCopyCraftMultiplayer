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
@onready var menu: CanvasLayer = $MultiplayerHUD
@onready var status: Label = menu.get_node("%ConnectionStatus")
@onready var server_address: LineEdit = menu.get_node("%ServerAddress")
var used_slots: Dictionary[int, int] = {}
var pending_spawns: Dictionary = {}
var retiring: Dictionary = {}
var retirement_serial = 0

func _exit_tree() -> void:
	if is_instance_valid(uiHanlder):
		uiHanlder.free()

func _ready() -> void:
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.peer_connected.connect(func(id): $Session.register_peer(id))
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer_spawner.spawn_function = add_player
	menu.host_requested.connect(become_host)
	menu.join_requested.connect(join_game)

func become_host() -> void:
	var error = MultiplayerManager.become_host()
	if error != OK:
		status.text = "Falha ao criar servidor: " + error_string(error)
		return
	%MultiplayerHUD.hide()
	$Session.open_lobby()
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
	$Session.running = true
	$Session.register.rpc_id(1)
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
	server_address.editable = enabled
	menu.get_node("%Host").disabled = not enabled
	menu.get_node("%Join").disabled = not enabled

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
	player.position = $Session.SPAWNS[slot] if $Session.running else players.get_node("SpawnPoint" + str(slot)).position
	MultiplayerManager.playerList[id] = player
	return player

@rpc("any_peer", "call_local", "reliable")
func request_player(path: String) -> void:
	if not multiplayer.is_server() or path not in HERO_SCENES:
		return
	var sender = multiplayer.get_remote_sender_id()
	var id = sender if sender != 0 else multiplayer.get_unique_id()
	if not $Session.can_select(id) or pending_spawns.has(id) or retiring.has(id):
		return
	pending_spawns[id] = true
	if $Session.running and $Session.roster.has(id):
		$Session.roster[id].ready = false
		$Session.revision += 1
	if MultiplayerManager.playerList.has(id):
		if not $Session.running:
			pending_spawns.erase(id)
			return
		if not await retire_character(id):
			pending_spawns.erase(id)
			return
	if id != 1 and id not in multiplayer.get_peers():
		pending_spawns.erase(id)
		return
	var slot = used_slots.get(id, -1)
	if slot == -1:
		for index in MultiplayerManager.MAX_PLAYERS:
			if index not in used_slots.values():
				slot = index
				break
	if slot >= 0:
		used_slots[id] = slot
		multiplayer_spawner.spawn({"id": id, "path": path, "slot": slot})
		$Session.selected(id, MultiplayerManager.playerList[id])
	pending_spawns.erase(id)

func remove_character(id: int) -> void:
	var hero = MultiplayerManager.playerList.get(id)
	MultiplayerManager.playerList.erase(id)
	if is_instance_valid(hero):
		hero.queue_free()

func on_peer_disconnected(id: int) -> void:
	$Session.remove_peer(id)
	pending_spawns.erase(id)
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
	$SessionUI.selecting_class = true
	var selection = uiHanlder.changeScene(Constants.PLAYER_SELECT_SCREEN)
	selection.playerSelected.connect(characterSelect)

func characterSelect(character: Character) -> void:
	$SessionUI.selecting_class = false
	request_player.rpc_id(1, character.scenePath)
	uiHanlder.changeScene(Constants.MAP_FOREST)

func leave_session() -> void:
	MultiplayerManager.reset_session()
	get_tree().reload_current_scene()

func retire_character(id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if not MultiplayerManager.playerList.has(id):
		return true
	retirement_serial += 1
	var serial = retirement_serial
	retiring[id] = {"serial": serial, "paused": false}
	if id == 1 or id in multiplayer.get_peers():
		pause_character_sync.rpc_id(id, id, serial)
		var deadline = Time.get_ticks_msec() + 2500
		while retiring.has(id) and not retiring[id].paused:
			if id != 1 and id not in multiplayer.get_peers():
				break
			if Time.get_ticks_msec() > deadline:
				retiring.erase(id)
				return false
			await get_tree().process_frame
	remove_character(id)
	retiring.erase(id)
	await get_tree().process_frame
	return true

@rpc("authority", "call_local", "reliable")
func pause_character_sync(id: int, serial: int) -> void:
	if multiplayer.get_unique_id() != id:
		return
	var hero = MultiplayerManager.playerList.get(id)
	if is_instance_valid(hero):
		var sync = hero.get_node_or_null("MultiplayerSynchronizer")
		if sync != null:
			# Stop the owning peer before despawn. A reliable acknowledgement on
			# the same ENet channel forms a barrier after earlier movement packets.
			sync.replication_interval = 3600
			sync.delta_interval = 3600
	await get_tree().physics_frame
	character_sync_paused.rpc_id(1, id, serial)

@rpc("any_peer", "call_local", "reliable")
func character_sync_paused(id: int, serial: int) -> void:
	if not multiplayer.is_server() or not retiring.has(id):
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender != id and not (sender == 0 and id == multiplayer.get_unique_id()):
		return
	if retiring[id].serial == serial:
		retiring[id].paused = true
