extends Node

const PORT = 18081
var main: Node
var encounter: Node
var is_host = false
var client_id = 0
var observed_victory = false

func _ready() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func run() -> void:
	is_host = "--server" in OS.get_cmdline_user_args()
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3) if is_host else peer.create_client("127.0.0.1", PORT)
	if error != OK:
		fail("Could not initialize test peer: " + error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	if is_host:
		main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
		MultiplayerManager.playerList[1].set_physics_process(false)
		encounter.status = "active"
		encounter.boss.position = Vector2(700, 250)
		encounter.boss.charCurrentLife = 250
		encounter.danger_position = Vector2(500, 300)
		encounter.danger_visible = true
		encounter.danger_remaining = 2
		encounter.spell_kind = "lance"
		encounter.phase = 2
		encounter.danger_origin = Vector2(700, 250)
		encounter.danger_direction = Vector2.LEFT
		encounter.boss.facing_left = true
		encounter.boss.velocity = Vector2(18, 9)
		encounter.projectiles = [{"id": 50, "position": Vector2(950, 100), "velocity": Vector2(-100, 0), "life": 3.0}]
		print("NETWORK_SERVER_READY")
		multiplayer.peer_disconnected.connect(on_disconnect)
	else:
		await multiplayer.connected_to_server
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/SirGura.tscn")
		await get_tree().create_timer(2).timeout
		client_id = multiplayer.get_unique_id()
		if MultiplayerManager.playerList.size() != 2:
			fail("Client did not receive both player spawns")
			return
		if encounter.boss.charCurrentLife != 250 or encounter.boss.position.distance_to(Vector2(700, 250)) > 1:
			fail("Late join did not receive boss HP and position")
			return
		if not encounter.danger_visible or encounter.danger_position != Vector2(500, 300):
			fail("Late join did not receive the active telegraph")
			return
		print("PASS: late join receives boss state and telegraph")
		if encounter.spell_kind != "lance" or encounter.phase != 2 or encounter.danger_direction != Vector2.LEFT:
			fail("Late join did not receive spell selection, phase and locked aim")
			return
		print("PASS: late join receives spell, phase and locked aim")
		if encounter.projectiles.size() != 1 or encounter.projectiles[0]["position"] != Vector2(950, 100):
			fail("Late join did not receive active projectiles")
			return
		print("PASS: late join receives active projectile sprites")
		if not encounter.boss.facing_left or encounter.boss.velocity != Vector2(18, 9):
			fail("Boss facing and motion state did not replicate")
			return
		print("PASS: facing and movement replicate without client override")
		var handler = main.get_node("SkillHandler")
		handler.basic_attack.rpc_id(1, 1, -1) # Spoofing the host must fail.
		request_attack_check.rpc_id(1)
	await get_tree().create_timer(20).timeout
	fail("Network test timed out")

@rpc("any_peer", "reliable")
func request_attack_check() -> void:
	if not multiplayer.is_server():
		return
	client_id = multiplayer.get_remote_sender_id()
	if encounter.boss.charCurrentLife != 250:
		fail("Spoofed host attack was accepted")
		return
	print("PASS: server rejects spoofed attack")
	request_dot.rpc_id(client_id)

@rpc("authority", "reliable")
func request_dot() -> void:
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, "res://Scenes/Skills/Corruption/Corruption.tscn", multiplayer.get_unique_id(), -1)
	verify_dot.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_dot() -> void:
	if not multiplayer.is_server():
		return
	if encounter.boss.debuffList.size() != 1:
		fail("Client skill could not target boss")
		return
	await get_tree().create_timer(1.3).timeout
	if encounter.boss.charCurrentLife != 248:
		fail("Server did not apply exactly one DoT tick")
		return
	print("PASS: client spell damages boss on server")
	encounter.boss.charCurrentLife = 0
	encounter._physics_process(0.1)

func _process(_delta: float) -> void:
	if not is_host and is_instance_valid(encounter) and encounter.status == "victory" and not observed_victory:
		observed_victory = true
		if encounter.danger_visible or not encounter.projectiles.is_empty() or encounter.boss.charCurrentLife != 0:
			fail("Victory state is inconsistent")
			return
		print("PASS: client receives victory, death and telegraph cancellation")
		if DamageNumbers.displayed_dot_events < 1:
			fail("Client did not receive periodic damage combat text")
			return
		print("PASS: client sees server-authorized DoT damage numbers")
		confirm_victory.rpc_id(1)

@rpc("any_peer", "reliable")
func confirm_victory() -> void:
	if multiplayer.is_server():
		close_client.rpc_id(multiplayer.get_remote_sender_id())

@rpc("authority", "reliable")
func close_client() -> void:
	multiplayer.multiplayer_peer.close()
	print("NETWORK_CLIENT_PASS")
	get_tree().quit()

func on_disconnect(id: int) -> void:
	if id != client_id:
		return
	await get_tree().process_frame
	if MultiplayerManager.playerList.size() != 1 or not is_instance_valid(MultiplayerManager.get_character(-1)):
		fail("Disconnect did not preserve boss and clean player registry")
		return
	print("PASS: disconnect cleans player and preserves encounter")
	print("NETWORK_SERVER_PASS")
	get_tree().quit()
