extends Node

const PORT = 18092
var main: Node
var session: Node
var encounter: Node
var actor: DualWieldWarrior
var slot = 0
var confirmations: Dictionary = {}

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		get_tree().quit(1)
		return false
	print("PASS: ", message)
	return true

func wait_until(condition: Callable) -> bool:
	var deadline = Time.get_ticks_msec() + 8000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()

func confirmed(step: int, count: int = 2) -> bool:
	return confirmations.get(step, {}).size() == count

@rpc("any_peer", "reliable")
func confirm(step: int) -> void:
	if multiplayer.is_server():
		var received: Dictionary = confirmations.get(step, {})
		received[multiplayer.get_remote_sender_id()] = true
		confirmations[step] = received

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	session.set_physics_process(false)
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	main.get_node("EncounterDirector").set_physics_process(false)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--slot="):
			slot = int(arg.trim_prefix("--slot="))
	var host = "--server" in args
	var peer = ENetMultiplayerPeer.new()
	if not check((peer.create_server(PORT, 2) if host else peer.create_client("127.0.0.1", PORT)) == OK, "Dual warrior ENet peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		await server()
	else:
		await client()

func server() -> void:
	session.open_lobby()
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	session.set_ready(true)
	print("DUAL_NETWORK_SERVER_READY")
	if not check(await wait_until(func(): return session.roster.size() == 2 and session.can_start()), "The new remote class selects its legal mastery and readies up"):
		return
	for hero in MultiplayerManager.playerList.values():
		hero.set_physics_process(false)
		if hero is DualWieldWarrior:
			actor = hero
	session.start_match()
	session._physics_process(3.1)
	actor.set_physics_process(false)
	MultiplayerManager.playerList[1].set_physics_process(false)
	actor.charCritChance = 0
	encounter.boss.charCritChance = 0
	encounter.boss.position = Vector2(600, 390)
	if not check(await wait_until(func(): return actor.global_position.distance_to(encounter.boss.global_position) < 100), "The owner replicates its melee position before attacking"):
		return
	start_pair.rpc_id(int(actor.name))
	if not check(await wait_until(func(): return actor.cadence == 1), "The server resolves both hands and only one Cadence from the remote attack"):
		return
	if not check(encounter.boss.charCurrentLife == 470 and actor.charCurrentMana == 10 and not main.get_node("SkillHandler").attack_times.has(1), "Duplicate requests and a forged host identity cause no extra damage"):
		return
	actor.charCurrentMana = 100
	start_guard.rpc_id(int(actor.name))
	if not check(await wait_until(func(): return actor.charShield == 24), "Remote Blade Guard spends its server-controlled Fury"):
		return
	actor.deal_damage(6, encounter.boss)
	if not check(actor.charShield == 18 and actor.charCurrentMana == 82 and encounter.boss.charCurrentLife == 462, "The server credits one guarded counterattack and its resource gain"):
		return
	print("DUAL_NETWORK_LATE_READY")
	if not check(await wait_until(func(): return session.roster.size() == 3 and confirmed(0)), "Owner and late spectator receive exact shield, Fury, Cadence and mastery snapshots"):
		return
	start_dance.rpc_id(int(actor.name))
	if not check(await wait_until(func(): return encounter.boss.charCurrentLife == 414), "The remote ultimate deals eight server-only pulses without duplicate client damage"):
		return
	if not check(actor.charCurrentMana == 17, "Remote ultimate spends exactly sixty-five Fury"):
		return
	session.prepare_round()
	if not check(await wait_until(func(): return confirmed(1)), "Every client sees a clean retry with the selected mastery preserved"):
		return
	finish.rpc()
	if not check(await wait_until(func(): return confirmed(2)), "Both clients acknowledge final cleanup"):
		return
	get_tree().multiplayer_poll = false
	print("DUAL_NETWORK_SERVER_PASS")
	get_tree().quit()

func client() -> void:
	await multiplayer.connected_to_server
	main.request_player.rpc_id(1, DualWieldWarrior.SCENE_PATH if slot == 1 else "res://Scenes/Characters/Heroes/Lulu.tscn")
	var id = multiplayer.get_unique_id()
	if not check(await wait_until(func(): return MultiplayerManager.playerList.has(id) and session.roster.has(id)), "Client receives its selected hero"):
		return
	MultiplayerManager.playerList[id].set_physics_process(false)
	if slot == 1:
		session.learn_talent.rpc_id(1, "frenzy", 1)
		session.learn_talent.rpc_id(1, "frenzy", 2)
		session.learn_mastery.rpc_id(1, "cross_frenzy")
		session.set_ready.rpc_id(1, true)
		if not check(await wait_until(func(): return session.stage == "active"), "Remote dual warrior enters the active encounter"):
			return
		MultiplayerManager.playerList[id].position = Vector2(530, 390)
	if not check(await wait_until(func():
		for hero in MultiplayerManager.playerList.values():
			if hero is DualWieldWarrior:
				actor = hero
		return is_instance_valid(actor) and actor.cadence == 1 and actor.charCurrentMana == 82 and actor.charShield == 18 and actor.riposte_remaining == 0 and actor.mastery == "cross_frenzy"), "Client observes the actual dual-wield combat state and mastery"):
		return
	if slot == 2 and not check(session.roster[id].spectator, "The late spectator stays outside the active fight"):
		return
	confirm.rpc_id(1, 0)
	if not check(await wait_until(func(): return session.stage == "countdown" and actor.cadence == 0 and actor.riposte_remaining == 0 and actor.charShield == 0 and actor.charCurrentMana == 0), "Retry clears Fury, Cadence, guard and pending actions on the client"):
		return
	if not check(actor.mastery == "cross_frenzy" and actor.skillList[0].tooltip_summary("1").contains("Maestria"), "The new warrior retains its mastery and tooltip after a retry"):
		return
	confirm.rpc_id(1, 1)

@rpc("authority", "reliable")
func start_pair() -> void:
	var id = multiplayer.get_unique_id()
	main.get_node("SkillHandler").basic_attack.rpc_id(1, id, -1)
	main.get_node("SkillHandler").basic_attack.rpc_id(1, id, -1)
	main.get_node("SkillHandler").basic_attack.rpc_id(1, 1, -1)

@rpc("authority", "reliable")
func start_guard() -> void:
	var id = multiplayer.get_unique_id()
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, actor.skillList[2].skillScenePath, id, id)

@rpc("authority", "reliable")
func start_dance() -> void:
	var id = multiplayer.get_unique_id()
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, actor.skillList[3].skillScenePath, id, id)

@rpc("authority", "reliable")
func finish() -> void:
	confirm.rpc_id(1, 2)
	multiplayer.multiplayer_peer.get_host().flush()
	get_tree().multiplayer_poll = false
	print("DUAL_NETWORK_CLIENT_PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
