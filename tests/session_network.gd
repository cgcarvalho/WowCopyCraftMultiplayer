extends Node

const PORT = 18083
var host = false
var main: Node
var session: Node
var encounter: Node
var handler: Node
var client_id = 0
var old_hunter: Character
var received_reset = false

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> bool:
	if ok:
		print("PASS: ", text)
		return true
	push_error(text)
	get_tree().quit(1)
	return false

func until(predicate: Callable, text: String, limit: float = 8) -> bool:
	var end = Time.get_ticks_msec() + int(limit * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > end:
			return check(false, text)
		await get_tree().create_timer(0.05).timeout
	return true

func run() -> void:
	host = "--server" in OS.get_cmdline_user_args()
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	handler = main.get_node("SkillHandler")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if not check(err == OK, "Session test peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	main.get_node("MultiplayerHUD").hide()
	if host:
		session.open_lobby()
		main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
		MultiplayerManager.playerList[1].charCritChance = 0
		print("SESSION_NETWORK_SERVER_READY")
		multiplayer.peer_disconnected.connect(disconnected)
	else:
		await multiplayer.connected_to_server
		client_id = multiplayer.get_unique_id()
		main.get_node("SessionUI").selecting_class = false
		main.uiHanlder.changeScene(Constants.MAP_FOREST)
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/Lulu.tscn")
		if not await until(func(): return MultiplayerManager.playerList.has(client_id) and session.roster.has(client_id) and session.roster[client_id]["class"] == "Hunter", "Client class did not reach lobby"):
			return
		old_hunter = MultiplayerManager.playerList[client_id]
		session.set_ready.rpc_id(1, true)
		session.start_match.rpc_id(1) # The client must not start the group.
		session.choose_upgrade.rpc_id(1, "offense") # No reward is available in lobby.
		client_ready.rpc_id(1)
	var watchdog = Timer.new()
	watchdog.one_shot = true
	add_child(watchdog)
	watchdog.timeout.connect(func(): check(false, "Session network test timed out"))
	watchdog.start(40)

@rpc("any_peer", "reliable")
func client_ready() -> void:
	if not host:
		return
	client_id = multiplayer.get_remote_sender_id()
	await get_tree().process_frame
	if not check(session.stage == "lobby" and not session.roster[1].ready and session.roster[client_id].ready, "Client readies only itself and cannot start the host's lobby"):
		return
	if not check(session.upgrades.is_empty(), "Client cannot claim rewards outside a victory"):
		return
	session.set_ready(true)
	if not check(session.can_start(), "Both real peers are selected and ready"):
		return
	session.start_match()
	observe_countdown.rpc_id(client_id)

@rpc("authority", "reliable")
func observe_countdown() -> void:
	if not await until(func(): return session.stage == "countdown", "Client missed countdown"):
		return
	if not check(encounter.status == "waiting", "Client sees countdown before boss combat starts"):
		return
	if not await until(func(): return session.stage == "active", "Client missed combat start"):
		return
	MultiplayerManager.playerList[client_id].position = Vector2(520, 300)
	await get_tree().create_timer(0.25).timeout
	active_received.rpc_id(1)

@rpc("any_peer", "reliable")
func active_received() -> void:
	if not host:
		return
	var warrior = MultiplayerManager.playerList[1]
	warrior.position = Vector2(500, 300)
	warrior.charCritChance = 0
	MultiplayerManager.playerList[client_id].charCritChance = 0
	encounter.boss.position = Vector2(700, 300)
	encounter.boss.charCurrentTarget = warrior
	encounter.boss.target_hold = 1
	encounter.begin_spell("bond")
	observe_bond.rpc_id(client_id)

@rpc("authority", "reliable")
func observe_bond() -> void:
	if not await until(func(): return encounter.danger_visible and encounter.spell_kind == "bond", "Client missed shared mechanic"):
		return
	if not check(encounter.mechanic_targets.size() == 1 and encounter.danger_remaining > 0, "Shared-attack marker and warning replicate"):
		return
	resolve_bond.rpc_id(1)

@rpc("any_peer", "reliable")
func resolve_bond() -> void:
	if not host:
		return
	encounter.resolve_area()
	if not check(MultiplayerManager.playerList[1].charCurrentLife == 126 and MultiplayerManager.playerList[client_id].charCurrentLife == 76, "Shared hit is split once by the server"):
		return
	encounter.begin_spell("channel")
	interrupt_from_client.rpc_id(client_id)

@rpc("authority", "reliable")
func interrupt_from_client() -> void:
	if not await until(func(): return encounter.danger_visible and encounter.spell_kind == "channel", "Client missed interruptible cast"):
		return
	handler.request_interrupt.rpc_id(1)
	interrupt_sent.rpc_id(1)

@rpc("any_peer", "reliable")
func interrupt_sent() -> void:
	if not host:
		return
	if not check(not encounter.danger_visible and MultiplayerManager.playerList[client_id].interrupt_remaining > 15, "Remote player's interrupt cancels server channel"):
		return
	encounter.begin_spell("channel")
	try_interrupt_again.rpc_id(client_id)

@rpc("authority", "reliable")
func try_interrupt_again() -> void:
	await get_tree().create_timer(0.2).timeout
	handler.request_interrupt.rpc_id(1)
	second_interrupt_sent.rpc_id(1)

@rpc("any_peer", "reliable")
func second_interrupt_sent() -> void:
	if not host:
		return
	if not check(encounter.danger_visible, "Server rejects interrupt cooldown bypass"):
		return
	encounter.danger_visible = false
	encounter.boss.charCurrentLife = 0
	encounter._physics_process(0.1)
	choose_reward.rpc_id(client_id)

@rpc("authority", "reliable")
func choose_reward() -> void:
	if not await until(func(): return session.stage == "victory", "Client missed victory"):
		return
	session.choose_upgrade.rpc_id(1, "mastery")
	session.choose_upgrade.rpc_id(1, "endurance") # Duplicate choice must not apply.
	session.retry.rpc_id(1) # Only host may continue.
	reward_sent.rpc_id(1)

@rpc("any_peer", "reliable")
func reward_sent() -> void:
	if not host:
		return
	if not check(session.stage == "victory" and session.upgrades[client_id].mastery == 1 and not session.upgrades[client_id].has("endurance"), "Remote reward is applied once; client cannot restart"):
		return
	await get_tree().process_frame
	session.choose_upgrade("offense")
	session.retry()
	verify_next_round.rpc_id(client_id)

@rpc("authority", "reliable")
func verify_next_round() -> void:
	if not await until(func(): return session.round_index == 2 and session.stage == "countdown", "Client missed next round"):
		return
	await get_tree().create_timer(0.25).timeout
	var hunter = MultiplayerManager.playerList[client_id]
	if not check(hunter == old_hunter and hunter.charCurrentLife == 100 and hunter.charCurrentMana == 100, "Retry preserves remote character and restores health/resource"):
		return
	if not check(is_equal_approx(hunter.cooldown_multiplier, 0.88) and is_equal_approx(MultiplayerManager.playerList[1].damage_bonus, 1.12) and encounter.boss.charCurrentLife == 552, "Both clients receive their own upgrades and stronger boss"):
		return
	if not await until(func(): return session.stage == "active", "Second encounter did not start"):
		return
	request_wipe.rpc_id(1)

@rpc("any_peer", "reliable")
func request_wipe() -> void:
	if not host:
		return
	for hero in MultiplayerManager.playerList.values():
		hero.charCurrentLife = 0
	encounter._physics_process(0.1)
	observe_defeat.rpc_id(client_id)

@rpc("authority", "reliable")
func observe_defeat() -> void:
	if not await until(func(): return session.stage == "defeat", "Client missed party wipe"):
		return
	if not check(MultiplayerManager.playerList[client_id].charCurrentLife == 0, "Client sees defeat and death without disconnecting"):
		return
	continue_after_wipe.rpc_id(1)

@rpc("any_peer", "reliable")
func continue_after_wipe() -> void:
	if not host:
		return
	await get_tree().process_frame
	session.retry()
	await get_tree().create_timer(3.3).timeout
	if not check(session.stage == "active" and session.round_index == 2 and MultiplayerManager.playerList[client_id].charCurrentLife == 100, "Host retries a wipe with progression intact"):
		return
	encounter.boss.charCurrentLife = 0
	encounter._physics_process(0.1)
	session.return_to_selection()
	observe_new_lobby.rpc_id(client_id)

@rpc("authority", "reliable")
func observe_new_lobby() -> void:
	if not await until(func(): return session.stage == "lobby" and not session.transitioning and MultiplayerManager.playerList.is_empty(), "Client retained old characters after selection reset"):
		return
	if not check(session.upgrades.is_empty() and session.round_index == 1, "Selection reset reaches remote peer and clears expedition progression"):
		return
	main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/Charger.tscn")
	if not await until(func(): return MultiplayerManager.playerList.has(client_id) and MultiplayerManager.playerList[client_id].charClass == "Paladin", "Remote class switch failed"):
		return
	if not check(MultiplayerManager.playerList[client_id].resource_name == "Poder sagrado" and not session.roster[client_id].ready, "Remote player changes class and must ready again"):
		return
	multiplayer.multiplayer_peer.close()
	print("SESSION_NETWORK_CLIENT_PASS")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()

func disconnected(id: int) -> void:
	if not host or id != client_id:
		return
	await get_tree().create_timer(0.2).timeout
	if not check(not session.roster.has(id) and not MultiplayerManager.playerList.has(id), "Disconnect cleans both lobby and combat registries"):
		return
	print("SESSION_NETWORK_SERVER_PASS")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()
