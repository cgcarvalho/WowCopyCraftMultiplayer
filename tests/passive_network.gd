extends Node

const PORT = 18086
var main: Node
var host = false
var client_id = 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		get_tree().quit(1)
		return false
	print("PASS: ", message)
	return true

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	host = "--server" in OS.get_cmdline_user_args()
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.status = "active"
	encounter.boss.set_physics_process(false)
	encounter.boss.position = Vector2(480, 300)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if not check(error == OK, "Passive test peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
		var warrior = MultiplayerManager.playerList[1]
		warrior.set_physics_process(false)
		for hit in 3:
			warrior.on_basic_hit()
		print("PASSIVE_NETWORK_SERVER_READY")
	else:
		await multiplayer.connected_to_server
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/Aurora.tscn")
		await get_tree().create_timer(1.0).timeout
		client_id = multiplayer.get_unique_id()
		var aurora = MultiplayerManager.playerList[client_id]
		aurora.set_physics_process(false)
		aurora.position = Vector2(400, 300)
		aurora.charCurrentTarget = encounter.boss
		var warrior = MultiplayerManager.playerList[1]
		if not check(warrior.momentum == 3 and is_equal_approx(warrior.momentum_time, 4) and ClassPassives.state(warrior).text.contains("+9%"), "Client receives the remote Warrior's actual stacks and remaining duration"):
			return
		prepare_dot.rpc_id(1)
	get_tree().create_timer(25).timeout.connect(func(): check(false, "Passive network test timed out"))

@rpc("any_peer", "reliable")
func prepare_dot() -> void:
	if not host:
		return
	client_id = multiplayer.get_remote_sender_id()
	var aurora = MultiplayerManager.playerList[client_id]
	aurora.passiveSkill.procChance = 1.0
	main.get_node("SkillHandler").cooldowns[client_id] = {ShadowBolt.filePath: Time.get_ticks_msec() + 10000}
	begin_dot.rpc_id(client_id)

@rpc("authority", "reliable")
func begin_dot() -> void:
	var aurora = MultiplayerManager.playerList[client_id]
	var bolt_button = main.get_node("CombatHUD/SkillBar/PanelContainer/HBoxContainer").get_child(0)
	bolt_button.on_cast_result(client_id, ShadowBolt.filePath, true, 0, 10)
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, aurora.skillList[1].skillScenePath, client_id, -1)
	tick_dot.rpc_id(1)

@rpc("any_peer", "reliable")
func tick_dot() -> void:
	if not host:
		return
	var dot = main.get_node("BossEncounter").boss.debuffList[0]
	dot.set_physics_process(false)
	dot._physics_process(1.0)
	if not check(MultiplayerManager.playerList[client_id].shadow_bolt_ready, "A real server-side DoT tick grants the remote Aurora's proc"):
		return
	verify_ready.rpc_id(client_id)

@rpc("authority", "reliable")
func verify_ready() -> void:
	await get_tree().create_timer(0.2).timeout
	var aurora = MultiplayerManager.playerList[client_id]
	var hud = main.get_node("SessionUI").passive_text
	hud.configure(aurora)
	if not check(aurora.shadow_bolt_ready and hud.detail.text.contains("PRONTO") and hud.progress.value == 1, "Owner sees the replicated ready proc in the passive HUD"):
		return
	var bolt_button = main.get_node("CombatHUD/SkillBar/PanelContainer/HBoxContainer").get_child(0)
	if not check(bolt_button.timer.is_stopped() and bolt_button.skillCast.cast_description().contains("Instantânea"), "Proc unlocks the owner's cooldown and updates the Shadow Bolt tooltip"):
		return
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, aurora.skillList[2].skillScenePath, client_id, -1)
	verify_retained.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_retained() -> void:
	if not host:
		return
	if not check(MultiplayerManager.playerList[client_id].shadow_bolt_ready and main.get_node("SkillHandler").proc_ready.has(client_id), "Another client spell preserves the server's pending Shadow Bolt proc"):
		return
	cast_bolt.rpc_id(client_id)

@rpc("authority", "reliable")
func cast_bolt() -> void:
	var bolt_button = main.get_node("CombatHUD/SkillBar/PanelContainer/HBoxContainer").get_child(0)
	bolt_button._on_pressed()
	await get_tree().create_timer(0.2).timeout
	var aurora = MultiplayerManager.playerList[client_id]
	var hud = main.get_node("SessionUI").passive_text
	hud.refresh()
	if not check(not aurora.shadow_bolt_ready and not hud.detail.text.contains("PRONTO") and not bolt_button.skillCast.resetCastTime, "Successful client cast clears the ready HUD and instant-cast tooltip"):
		return
	if not check(not bolt_button.timer.is_stopped() and bolt_button.timer.time_left > 3, "Consumed proc starts a fresh cooldown instead of clearing it with an old reset flag"):
		return
	aurora.passiveSkill.procChance = 1.0
	aurora.passiveSkill.on_proc()
	if not check(not aurora.shadow_bolt_ready, "Client-side passive evaluation cannot manufacture a server proc"):
		return
	verify_consumed.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_consumed() -> void:
	if not host:
		return
	var handler = main.get_node("SkillHandler")
	if not check(not MultiplayerManager.playerList[client_id].shadow_bolt_ready and not handler.proc_ready.has(client_id) and not handler.casting.has(client_id), "Server consumes the proc once and resolves Shadow Bolt instantly"):
		return
	MultiplayerManager.playerList[1].update_class_passive(4.1)
	finish_client.rpc_id(client_id)
	await get_tree().create_timer(0.5).timeout
	print("PASSIVE_NETWORK_SERVER_PASS")
	get_tree().quit()

@rpc("authority", "reliable")
func finish_client() -> void:
	await get_tree().create_timer(0.2).timeout
	var warrior = MultiplayerManager.playerList[1]
	if not check(warrior.momentum == 0 and not ClassPassives.state(warrior).active, "Remote Warrior indicator expires when the server removes the stacks"):
		return
	print("PASSIVE_NETWORK_CLIENT_PASS")
	get_tree().quit()
