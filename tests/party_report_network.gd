extends Node

const PORT = 18084
const CLASSES = ["Aurora", "SirGura", "Charger", "Lulu"]
const BUILDS = ["affliction", "guardian", "light", "marksman"]
var host = false
var main: Node
var session: Node
var acknowledgements: Dictionary = {}
var active_peers: Dictionary = {}

func check(ok: bool, text: String) -> bool:
	if ok:
		print("PASS: ", text)
	else:
		push_error(text)
		get_tree().quit(1)
	return ok

func until(predicate: Callable, text: String) -> bool:
	var deadline = Time.get_ticks_msec() + 20000
	while is_instance_valid(session) and not predicate.call():
		if Time.get_ticks_msec() > deadline:
			return check(false, text)
		await get_tree().create_timer(0.05).timeout
	return is_instance_valid(session)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	host = "--server" in args
	var slot = 0
	for arg in args:
		if arg.begins_with("--slot="):
			slot = arg.trim_prefix("--slot=").to_int()
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var peer = ENetMultiplayerPeer.new()
	if not check((peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)) == OK, "Four-player test peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	main.get_node("MultiplayerHUD").hide()
	if host:
		session.open_lobby()
	else:
		await multiplayer.connected_to_server
	main.uiHanlder.changeScene(Constants.MAP_FOREST)
	main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/" + CLASSES[slot] + ".tscn")
	var id = multiplayer.get_unique_id()
	if not await until(func(): return session.roster.has(id) and session.roster[id]["class"] != "", "Player did not select a class"):
		return
	# Twenty multibyte characters are allowed by the production name validator.
	session.set_player_name.rpc_id(1, "🧙".repeat(19) + str(slot))
	for tier in range(1, 4):
		session.learn_talent.rpc_id(1, BUILDS[slot], tier)
	session.set_ready.rpc_id(1, true)
	if host:
		print("PARTY_REPORT_SERVER_READY")
		if not await until(func(): return session.roster.size() == 4 and session.can_start(), "Four players did not finish lobby readiness"):
			return
		if not check(TalentTree.spent(session.roster[1].talents) == 3, "Full party readies with valid talent builds"):
			return
		session.start_match()
		if not await until(func(): return session.stage == "active", "Full party countdown did not finish"):
			return
		if not await until(func(): return active_peers.size() == 3, "Clients missed the full party start"):
			return
		var paladin: Character
		for actor in MultiplayerManager.playerList.values():
			actor.set_physics_process(false)
			actor.charCritChance = 0
			if actor.charClass == "Paladin":
				paladin = actor
		encounter.boss.charCritChance = 0
		for actor in MultiplayerManager.playerList.values():
			actor.steady_time = 0
			encounter.boss.deal_damage(10, actor)
			actor.charCurrentLife = actor.charTotalLife - 20
			actor.apply_heal(100, paladin)
			actor.apply_shield(5, paladin)
			actor.deal_damage(5, encounter.boss)
		encounter.boss.charCurrentLife = 0
		encounter._physics_process(0.1)
		if not check(session.report.players.size() == 4 and session.report.players[int(paladin.name)].healing == 80, "Full party report includes all contributions and effective group healing"):
			return
		if not check(var_to_bytes(session.report).size() > 1350, "Four-player results with long UTF-8 names exceed an unreliable sync packet"):
			return
		if not await until(func(): return acknowledgements.size() == 3, "A peer did not receive the complete four-player report"):
			return
		finish_test.rpc()
	else:
		if not await until(func(): return session.stage == "active", "Client missed the full party start"):
			return
		if not check(session.roster.size() == 4 and MultiplayerManager.playerList.size() == 4 and TalentTree.spent(session.roster[id].talents) == 3, "Client receives all four players and its selected talents"):
			return
		active_received.rpc_id(1)
		if not await until(func(): return session.stage == "victory" and session.report.get("players", {}).size() == 4, "Client missed complete report after victory"):
			return
		var players: Dictionary = session.report.players
		var complete = true
		for row in players.values():
			complete = complete and row.damage == 10 and row.damage_taken == 0 and row.deaths == 0
		if not check(complete, "Reliable snapshot delivers all four accurate result rows to client"):
			return
		report_received.rpc_id(1)

@rpc("any_peer", "reliable")
func active_received() -> void:
	if host:
		active_peers[multiplayer.get_remote_sender_id()] = true

@rpc("any_peer", "reliable")
func report_received() -> void:
	if host:
		acknowledgements[multiplayer.get_remote_sender_id()] = true

@rpc("authority", "call_local", "reliable")
func finish_test() -> void:
	print("PARTY_REPORT_SERVER_PASS" if host else "PARTY_REPORT_CLIENT_PASS")
	await get_tree().create_timer(0.8 if host else 0.2).timeout
	MultiplayerManager.reset_session()
	get_tree().current_scene = self
	if is_instance_valid(main):
		main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
