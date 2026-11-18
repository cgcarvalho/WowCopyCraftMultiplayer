extends Node

const PORT = 18091
const LULU = "res://Scenes/Characters/Heroes/Lulu.tscn"
var main: Node
var session: Node
var encounter: Node
var director: EncounterDirector
var confirmations: Dictionary = {}
var slot = 0

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

func confirmed(step: int) -> bool:
	return confirmations.get(step, {}).size() == 3

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
	director = main.get_node("EncounterDirector")
	session.set_physics_process(false)
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	director.set_physics_process(false)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--slot="):
			slot = int(arg.trim_prefix("--slot="))
	var peer = ENetMultiplayerPeer.new()
	var host = "--server" in args
	if not check((peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)) == OK, "Mastery ENet peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		await server()
	else:
		await client()

func server() -> void:
	session.open_lobby()
	session.select_encounter_mode("expedition")
	main.request_player(LULU)
	session.learn_talent("venom", 1)
	session.learn_talent("venom", 2)
	session.learn_mastery("infection")
	session.set_ready(true)
	print("MINIONS_NETWORK_SERVER_READY")
	if not check(await wait_until(func(): return session.roster.size() == 3 and session.can_start()), "Three players select legal masteries and ready up"):
		return
	session.start_match()
	session._physics_process(3.1)
	var player: Character = MultiplayerManager.playerList[1]
	player.set_physics_process(false)
	player.charCritChance = 0
	var target = director.living_enemies()[0]
	target.set_physics_process(false)
	target.position = player.position + Vector2(170, 0)
	target.born_remaining = 0
	target.spectator = false
	target.deal_damage(13, player)
	target.start_cast(player)
	target.cast_remaining = 1.8
	for actor in MultiplayerManager.playerList.values():
		actor.set_physics_process(false)
		actor.position = player.position
	print("MINIONS_NETWORK_LATE_READY")
	if not check(await wait_until(func(): return session.roster.size() == 4 and confirmed(0)), "Late client receives existing minion life, cast and mastery snapshots"):
		return
	ask_interrupt.rpc()
	if not check(await wait_until(func(): return target.cast_remaining == 0 and confirmed(1)), "Selected remote interruption resolves once and replicates to every client"):
		return
	target.deal_damage(500, player)
	director._physics_process(0.01)
	director._physics_process(2.1)
	for enemy in director.living_enemies():
		enemy.set_physics_process(false)
		enemy.born_remaining = 0
		enemy.spectator = false
	if not check(director.living_enemies().size() == 4 and await wait_until(func(): return confirmed(2)), "Three-participant mixed wave keeps its composition after a late spectator arrives"):
		return
	var pack = director.living_enemies()
	for index in pack.size():
		pack[index].position = player.position + Vector2(180 + index * 35, 0)
	var poisoned: Character = pack[0]
	main.get_node("SkillHandler").loadSkillScene(player.skillList[1].skillScenePath, 1, int(poisoned.name))
	if not check(await wait_until(func(): return not poisoned.debuffList.is_empty()), "Host poison reaches the selected mixed-wave enemy"):
		return
	poisoned.debuffList[0].elapsed = 7.0
	poisoned.deal_damage(500, player)
	if not check(await wait_until(func(): return confirmed(6)), "Exactly two bounded secondary poisons replicate without a second initial impact"):
		return
	for enemy in director.living_enemies():
		enemy.deal_damage(500, player)
	director._physics_process(0.01)
	director._physics_process(6.1)
	if not check(await wait_until(func(): return confirmed(3)), "Boss transition and hero mastery arrive intact on all clients"):
		return
	encounter.finish("defeat")
	if not check(await wait_until(func(): return confirmed(4)), "Defeat clears spawned enemies on host and all clients"):
		return
	finish.rpc()
	if not check(await wait_until(func(): return confirmed(5)), "Every client acknowledges final cleanup"):
		return
	get_tree().multiplayer_poll = false
	print("MINIONS_NETWORK_SERVER_PASS")
	get_tree().quit()

func client() -> void:
	await multiplayer.connected_to_server
	main.request_player.rpc_id(1, LULU)
	var id = multiplayer.get_unique_id()
	if not check(await wait_until(func(): return MultiplayerManager.playerList.has(id) and session.roster.has(id)), "Client selects a hunter"):
		return
	var actor: Character = MultiplayerManager.playerList[id]
	actor.set_physics_process(false)
	if slot != 3:
		session.learn_talent.rpc_id(1, "venom", 1)
		session.learn_talent.rpc_id(1, "venom", 2)
		session.learn_mastery.rpc_id(1, "infection")
		session.set_ready.rpc_id(1, true)
	if not check(await wait_until(func():
		var target = MultiplayerManager.get_character(-100)
		return is_instance_valid(target) and target.charCurrentLife == 52 and is_equal_approx(target.cast_remaining, 1.8) and director.phase == "waves"), "Client sees the exact life and active warning of the already spawned caster"):
		return
	var host: Character = MultiplayerManager.playerList[1]
	if not check(host.mastery == "infection" and host.talents.get("venom", 0) == 2, "Mastery and prerequisites replicate together"):
		return
	if slot == 3 and not check(session.roster[id].spectator and actor.spectator, "Late arrival stays a spectator during the active attempt"):
		return
	confirm.rpc_id(1, 0)
	if not check(await wait_until(func():
		var target = MultiplayerManager.get_character(-100)
		return is_instance_valid(target) and target.cast_remaining == 0), "Client sees the confirmed interrupt"):
		return
	confirm.rpc_id(1, 1)
	if not check(await wait_until(func(): return director.wave_index == 2 and director.living_enemies().size() == 4), "Client receives four distinct mixed-wave enemies"):
		return
	var ids: Array[int] = []
	for enemy in director.living_enemies():
		ids.append(int(enemy.name))
	if not check(ids.size() == 4 and not ids.has(-1) and not ids.has(-2) and not ids.has(-3), "Dynamic enemy identities preserve Jefferson and conductor identities"):
		return
	confirm.rpc_id(1, 2)
	if not check(await wait_until(func(): return copied_poisons() == 2 and director.living_enemies().size() == 3), "Client receives both secondary poison copies with their remaining duration"):
		return
	var unchanged = 0
	for enemy in director.living_enemies():
		if enemy.charCurrentLife == enemy.charTotalLife:
			unchanged += 1
	if not check(unchanged == 3, "Secondary copies do not replay Poison Arrow's initial damage on clients"):
		return
	confirm.rpc_id(1, 6)
	if not check(await wait_until(func(): return director.phase == "boss" and encounter.status == "active" and director.living_enemies().is_empty()), "Client sees restored boss phase and no surviving wave enemies"):
		return
	if slot != 3 and not check(actor.mastery == "infection", "The local hero keeps its mastery after the respite"):
		return
	confirm.rpc_id(1, 3)
	if not check(await wait_until(func(): return session.stage == "defeat" and director.get_node("Enemies").get_child_count() == 0), "Temporary enemies are removed after defeat"):
		return
	confirm.rpc_id(1, 4)

func copied_poisons() -> int:
	var count = 0
	for enemy in director.living_enemies():
		for effect in enemy.debuffList:
			if is_instance_valid(effect) and effect is HeroAbility and effect.secondary_effect and effect.ability_id == "poison_arrow" and float(effect.data.duration) <= 3.0 and is_equal_approx(effect.skillDotSeconds, float(effect.data.duration)):
				count += 1
	return count

@rpc("authority", "reliable")
func ask_interrupt() -> void:
	if slot == 1:
		var actor = MultiplayerManager.playerList[multiplayer.get_unique_id()]
		actor.charCurrentTarget = MultiplayerManager.get_character(-100)
		var handler = main.get_node("SkillHandler")
		handler.request_interrupt.rpc_id(1, handler.interrupt_target_id())

@rpc("authority", "reliable")
func finish() -> void:
	confirm.rpc_id(1, 5)
	multiplayer.multiplayer_peer.get_host().flush()
	get_tree().multiplayer_poll = false
	print("MINIONS_NETWORK_CLIENT_PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
