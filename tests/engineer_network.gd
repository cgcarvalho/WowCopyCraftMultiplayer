extends Node

const PORT = 18090
const POINT = Vector2(290, 275)
const BEACON = "res://Scenes/Skills/Classes/field_beacon.tscn"
const OVERLOAD = "res://Scenes/Skills/Classes/overload.tscn"

var main: Node
var session: Node
var encounter: Node
var acknowledged := false
var saw_overload_pulse := false

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
	var deadline = Time.get_ticks_msec() + 7000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var host = "--server" in OS.get_cmdline_user_args()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if not check(error == OK, "Engineer ENet peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		await run_server()
	else:
		await run_client()

func run_server() -> void:
	session.open_lobby()
	main.request_player("res://Scenes/Characters/Heroes/Aurora.tscn")
	session.set_ready(true)
	print("ENGINEER_NETWORK_SERVER_READY")
	if not check(await wait_until(func(): return session.roster.size() == 2 and session.can_start()), "The remote Engineer class is accepted and readies up"):
		return
	var id = multiplayer.get_peers()[0]
	var teo = MultiplayerManager.playerList[id] as Engineer
	teo.charCritChance = 0
	session.start_match()
	session._physics_process(3.1)
	encounter.boss.global_position = POINT + Vector2(45, 0)
	if not check(await wait_until(func(): return teo.in_beacon(POINT) and teo.charCurrentMana == 0), "Server accepts the remote ground cast and spends Pressure"):
		return
	if not check(await wait_until(func(): return teo.circuit_hits == 1 and teo.charCurrentMana == 7), "A remote basic hit charges the Beacon and generates Pressure once"):
		return
	teo.charCurrentMana = 60
	if not check(await wait_until(func(): return teo.overload_position == POINT and teo.overload_remaining > 0 and teo.charCurrentMana == 0), "Server places the remote Overload at the Beacon"):
		return
	if not check(await wait_until(func(): return teo.overload_pulses >= 1), "The Overload pulses on the server"):
		return
	teo.charCurrentLife = 0
	if not check(await wait_until(func(): return acknowledged), "Client confirmed the Engineer's device cleanup"):
		return
	get_tree().multiplayer_poll = false
	print("ENGINEER_NETWORK_SERVER_PASS")
	get_tree().quit()

func run_client() -> void:
	await multiplayer.connected_to_server
	var id = multiplayer.get_unique_id()
	main.request_player.rpc_id(1, Engineer.SCENE_PATH)
	if not check(await wait_until(func(): return MultiplayerManager.playerList.get(id) is Engineer), "Client receives its selected Engineer"):
		return
	var teo = MultiplayerManager.playerList[id] as Engineer
	main.child_entered_tree.connect(func(child: Node):
		if child is SkillFX and child.clip == &"coil":
			saw_overload_pulse = child.initial_point == POINT and child.diameter == 350)
	session.set_ready.rpc_id(1, true)
	if not check(await wait_until(func(): return session.stage == "active"), "Client enters combat"):
		return
	var handler = main.get_node("SkillHandler")
	handler.loadSkillScene.rpc_id(1, BEACON, id, 0, POINT)
	if not check(await wait_until(func(): return teo.in_beacon(POINT) and teo.charCurrentMana == 0), "Client sees the replicated Beacon radius and resource"):
		return
	handler.basic_attack.rpc_id(1, id, -1)
	if not check(await wait_until(func(): return teo.circuit_hits == 1), "Client sees the replicated Circuito Fechado count"):
		return
	if not await wait_until(func(): return teo.charCurrentMana == 60):
		check(false, "Client did not receive Pressure for Overload")
		return
	handler.loadSkillScene.rpc_id(1, OVERLOAD, id, id)
	if not check(await wait_until(func(): return teo.overload_position == POINT and teo.overload_remaining > 0), "Client sees the Overload in the correct location"):
		return
	if not check(await wait_until(func(): return teo.charCurrentLife == 0 and teo.beacon_remaining == 0 and teo.overload_remaining == 0), "Replicated devices clear when the Engineer dies"):
		return
	if not check(saw_overload_pulse, "Client sees the server's pulse centered on the saved Beacon spot and using its combat radius"):
		return
	acknowledge.rpc_id(1)
	multiplayer.multiplayer_peer.get_host().flush()
	get_tree().multiplayer_poll = false
	print("ENGINEER_NETWORK_CLIENT_PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

@rpc("any_peer", "reliable")
func acknowledge() -> void:
	acknowledged = true
