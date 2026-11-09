extends Node

const PORT = 18089
const LULU = "res://Scenes/Characters/Heroes/Lulu.tscn"
const MULTI_SHOT = "res://Scenes/Skills/Classes/multishot.tscn"
const HEALTH_STEPS = [
	Vector2i(61, 80), Vector2i(43, 62), Vector2i(0, 62), Vector2i.ZERO,
	Vector2i(80, 80), Vector2i.ZERO
]
var main: Node
var session: Node
var encounter: Node
var acknowledgments: Dictionary = {}

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> bool:
	if not ok:
		push_error(description)
		get_tree().quit(1)
		return false
	print("PASS: ", description)
	return true

func wait_until(condition: Callable) -> bool:
	var deadline = Time.get_ticks_msec() + 8000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	session.set_physics_process(false)
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var args = OS.get_cmdline_user_args()
	var host = "--server" in args
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if not check(error == OK, "ENet peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		await run_server()
	else:
		await run_client("--slot=3" in args)

func run_server() -> void:
	session.open_lobby()
	session.select_arena("ruins")
	main.request_player(LULU)
	session.set_ready(true)
	var hero: Character = MultiplayerManager.playerList[1]
	hero.set_physics_process(false)
	hero.charCritChance = 0
	print("RUNES_NETWORK_SERVER_READY")
	if not check(await wait_until(func(): return session.roster.size() == 3 and session.can_start()), "Three players ready up normally"):
		return
	session.start_match()
	session._physics_process(3.1)
	var boss: Jefferson = encounter.boss
	boss.deal_damage(boss.charTotalLife, hero)
	encounter._physics_process(0.1)
	encounter.resolve_area()
	var first: RunicConductor = MultiplayerManager.get_character(-2)
	var second: RunicConductor = MultiplayerManager.get_character(-3)
	if not check(is_instance_valid(first) and is_instance_valid(second), "A party of three spawns two distinct enemy targets"):
		return
	first.deal_damage(19, hero)
	print("RUNES_NETWORK_LATE_READY")
	if not check(await wait_until(func(): return acknowledged(0) and session.roster.size() == 4), "All three clients receive the active ward and damaged rune"):
		return
	hero.position = first.position - Vector2(150, 0)
	main.get_node("SkillHandler").loadSkillScene(MULTI_SHOT, 1, -2)
	if not check(await wait_until(func(): return encounter.conductor_health == HEALTH_STEPS[1] and acknowledged(1)), "Multi-Shot damages both runes and replicates the new life totals"):
		return
	first.deal_damage(200, hero)
	boss.deal_damage(200, hero)
	if not check(boss.charCurrentLife == boss.charTotalLife / 2 and await wait_until(func(): return acknowledged(2)), "Breaking one rune leaves the ward and the second rune active"):
		return
	second.deal_damage(200, hero)
	boss.deal_damage(30, hero)
	if not check(boss.charCurrentLife == boss.charTotalLife / 2 - 30 and await wait_until(func(): return acknowledged(3)), "The final rune releases the boss and disappears on every peer"):
		return
	encounter.finish("defeat")
	session.retry()
	session.set_ready(true)
	if not check(await wait_until(func(): return session.can_start()), "The late spectator readies up for the next attempt"):
		return
	session.start_match()
	session._physics_process(3.1)
	boss.deal_damage(boss.charTotalLife, hero)
	encounter._physics_process(0.1)
	encounter.resolve_area()
	if not check(encounter.living_players().size() == 4 and await wait_until(func(): return acknowledged(4)), "Four active players see two fully restored runes on the next attempt"):
		return
	encounter.finish("defeat")
	if not check(await wait_until(func(): return acknowledged(5)), "A defeat with an intact ward clears both runes on every peer"):
		return
	finish_client.rpc()
	if not check(await wait_until(func(): return acknowledged(HEALTH_STEPS.size())), "All clients acknowledge shutdown"):
		return
	get_tree().multiplayer_poll = false
	print("RUNES_NETWORK_SERVER_PASS")
	get_tree().quit()

func run_client(late: bool) -> void:
	await multiplayer.connected_to_server
	main.request_player.rpc_id(1, LULU)
	var id = multiplayer.get_unique_id()
	if not check(await wait_until(func(): return MultiplayerManager.playerList.has(id) and session.roster.has(id)), "Client selects a hero"):
		return
	MultiplayerManager.playerList[id].set_physics_process(false)
	if not late:
		session.set_ready.rpc_id(1, true)
	for step in HEALTH_STEPS.size():
		if step == 4:
			if not check(await wait_until(func(): return session.stage == "lobby"), "Client returns to the lobby for the next attempt"):
				return
			session.set_ready.rpc_id(1, true)
		var expected: Vector2i = HEALTH_STEPS[step]
		var expected_stage = "defeat" if step == 5 else "active"
		if not check(await wait_until(func(): return encounter.conductor_health == expected and session.stage == expected_stage), "Client receives synchronized rune health %s" % expected):
			return
		for index in encounter.conductors.size():
			var conductor: RunicConductor = encounter.conductors[index]
			var registered = MultiplayerManager.get_character(-2 - index)
			if not check(conductor.charCurrentLife == expected[index] and conductor.visible == (expected[index] > 0) and registered == (conductor if expected[index] > 0 else null), "Rune visibility and targeting agree with its life"):
				return
			if step == 0 and not check(conductor.position == ArenaCatalog.ARENAS.ruins.conductors[index], "Client rune occupies the correct arena position"):
				return
		if late and step == 0:
			if not check(session.roster[id].spectator and encounter.phase == 2, "The late arrival spectates the current phase"):
				return
		confirm.rpc_id(1, step)

func acknowledged(step: int) -> bool:
	return acknowledgments.get(step, {}).size() == 3

@rpc("any_peer", "reliable")
func confirm(step: int) -> void:
	if multiplayer.is_server():
		var peers: Dictionary = acknowledgments.get(step, {})
		peers[multiplayer.get_remote_sender_id()] = true
		acknowledgments[step] = peers

@rpc("authority", "reliable")
func finish_client() -> void:
	confirm.rpc_id(1, HEALTH_STEPS.size())
	multiplayer.multiplayer_peer.get_host().flush()
	get_tree().multiplayer_poll = false
	print("RUNES_NETWORK_CLIENT_PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
