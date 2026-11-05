extends Node

const PORT = 18088
var main: Node
var session: Node
var client_id = 0

func fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	session.set_physics_process(false)
	main.get_node("BossEncounter").set_physics_process(false)
	main.get_node("BossEncounter").boss.set_physics_process(false)
	var host = "--server" in OS.get_cmdline_user_args()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if error != OK:
		fail("Could not create arena test peer")
		return
	multiplayer.multiplayer_peer = peer
	if host:
		session.open_lobby()
		session.select_arena("ruins")
		main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
		MultiplayerManager.playerList[1].set_physics_process(false)
		print("ARENA_NETWORK_SERVER_READY")
	else:
		await multiplayer.connected_to_server
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/Lulu.tscn")
		await get_tree().create_timer(1.5).timeout
		if session.arena_id != "ruins" or ArenaNavigation.obstacles().size() != 4:
			fail("Late join missed selected arena or navigation")
			return
		print("PASS: late join receives the non-default arena and matching blockers")
		var ui = main.get_node("SessionUI")
		if not ui.selecting_class or main.get_node("CurrentMap").get_child(0).get_meta("arena_id", "") != "":
			fail("Arena replication replaced the class selection screen")
			return
		print("PASS: arena replication preserves a client's class selection screen")
		ui.selecting_class = false
		main.show_arena()
		ui.rebuild()
		if main.get_node("CurrentMap").get_child(0).get_meta("arena_id") != "ruins":
			fail("Selected class did not reveal matching arena")
			return
		print("PASS: client loads the selected arena after class selection")
		for card in ui.content.find_children("Arena_*", "Button", true, false):
			if not card.disabled:
				fail("Remote client can use a host arena button")
				return
		print("PASS: remote clients see arena previews with host controls disabled")
		session.select_arena.rpc_id(1, "glacier")
		verify_spoof.rpc_id(1)
	var watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.timeout.connect(func(): fail("Arena network test timed out"))
	add_child(watchdog)
	watchdog.start(20)

@rpc("any_peer", "reliable")
func verify_spoof() -> void:
	if not multiplayer.is_server():
		return
	client_id = multiplayer.get_remote_sender_id()
	if session.arena_id != "ruins":
		fail("Remote peer changed the host's arena")
		return
	print("PASS: server rejects a remote arena change")
	call_deferred("host_start")

func host_start() -> void:
	# Change and immediately start before the unreliable synchronizer can tick.
	session.select_arena("glacier")
	for member in session.roster.values():
		member.ready = true
	session.start_match()
	if session.stage != "countdown":
		fail("Host did not start the round")
		return
	session.select_arena("forest")
	if session.arena_id != "glacier":
		fail("Host changed layout during countdown")
		return
	print("PASS: host cannot change the layout after starting countdown")
	check_round.rpc_id(client_id)

@rpc("authority", "reliable")
func check_round() -> void:
	var map = main.get_node("CurrentMap").get_child(0)
	var hero = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if session.arena_id != "glacier" or map.get_meta("arena_id") != "glacier" or not ArenaNavigation.obstacles().is_empty():
		fail("Reliable round reset did not atomically apply the new map and blockers")
		return
	print("PASS: round reset atomically switches client map and collision layout")
	if hero == null or hero.position != ArenaCatalog.ARENAS.glacier.spawns[1] or main.get_node("BossEncounter").boss.position != ArenaCatalog.ARENAS.glacier.boss:
		fail("Client reset used stale player or boss spawn positions")
		return
	print("PASS: client reset uses the selected arena's player and boss spawns")
	finish_server.rpc_id(1)

@rpc("any_peer", "reliable")
func finish_server() -> void:
	if multiplayer.is_server():
		finish_client.rpc_id(multiplayer.get_remote_sender_id())
		print("ARENA_NETWORK_SERVER_PASS")
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()

@rpc("authority", "reliable")
func finish_client() -> void:
	print("ARENA_NETWORK_CLIENT_PASS")
	get_tree().quit()
