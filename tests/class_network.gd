extends Node

const PORT = 18082
var host = false
var main: Node
var boss: Character
var handler: Node
var client_id = 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> bool:
	if not ok:
		push_error(text)
		get_tree().quit(1)
		return false
	print("PASS: ", text)
	return true

func run() -> void:
	host = "--server" in OS.get_cmdline_user_args()
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.status = "active"
	boss = encounter.boss
	boss.set_physics_process(false)
	boss.position = Vector2(500, 300)
	handler = main.get_node("SkillHandler")
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if not check(err == OK, "Class test peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		main.request_player("res://Scenes/Characters/Heroes/Charger.tscn")
		var paladin = MultiplayerManager.playerList[1]
		paladin.set_physics_process(false)
		paladin.position = Vector2(450, 300)
		paladin.charCurrentLife = 70
		print("CLASS_NETWORK_SERVER_READY")
	else:
		await multiplayer.connected_to_server
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/Lulu.tscn")
		await get_tree().create_timer(1).timeout
		client_id = multiplayer.get_unique_id()
		var hunter = MultiplayerManager.playerList[client_id]
		hunter.position = Vector2(400, 300)
		hunter.set_physics_process(false)
		await get_tree().create_timer(0.4).timeout
		handler.loadSkillScene.rpc_id(1, "res://Scenes/Skills/Classes/holy_light.tscn", client_id, client_id)
		handler.loadSkillScene.rpc_id(1, "res://Scenes/Skills/Classes/poison_arrow.tscn", client_id, -1)
		verify_poison.rpc_id(1)
	var watchdog = Timer.new()
	watchdog.one_shot = true
	add_child(watchdog)
	watchdog.timeout.connect(func(): check(false, "Class network test timed out"))
	watchdog.start(20)

@rpc("any_peer", "reliable")
func verify_poison() -> void:
	if not host:
		return
	client_id = multiplayer.get_remote_sender_id()
	MultiplayerManager.playerList[client_id].charCritChance = 0
	await get_tree().create_timer(0.5).timeout
	var hunter = MultiplayerManager.playerList[client_id]
	if not check(boss.charCurrentLife == 472, "Client poison projectile applies damage exactly once on host"):
		return
	if not check(hunter.charCurrentMana >= 80 and hunter.charCurrentMana < 87, "Server rejects cross-class healing and charges only poison mana"):
		return
	await get_tree().create_timer(1).timeout
	if not check(boss.charCurrentLife == 467, "Poison periodic damage is not doubled across peers"):
		return
	for effect in boss.debuffList:
		effect.set_physics_process(false)
	hunter.charCurrentLife = 60
	hunter.charCritChance = 0
	handler.loadSkillScene("res://Scenes/Skills/Classes/holy_light.tscn", 1, 1)
	await get_tree().create_timer(1.3).timeout
	if not check(MultiplayerManager.playerList[1].charCurrentLife == 107, "Host paladin healing resolves after cast time"):
		return
	MultiplayerManager.playerList[1].charCurrentMana = 5
	handler.loadSkillScene("res://Scenes/Skills/Classes/divine_dawn.tscn", 1, 1)
	await get_tree().create_timer(1.1).timeout
	if not check(hunter.charCurrentLife == 100 and hunter.charShield == 35, "Paladin ultimate heals and shields remote ally"):
		return
	verify_client_state.rpc_id(client_id)

@rpc("authority", "reliable")
func verify_client_state() -> void:
	var hunter = MultiplayerManager.playerList[client_id]
	if not check(hunter.charCurrentLife == 100 and hunter.charShield == 35, "Remote client receives ultimate health and shield"):
		return
	if not check(main.get_node("DotStatusUI").groups_for(boss).size() == 1, "Client sees replicated poison status"):
		return
	hunter.charCurrentTarget = boss
	# This fixture pauses automatic physics; tick the character to expire cast art.
	hunter._physics_process(1.0)
	if not check(hunter.state_machine.current_state is Attack and not Input.is_action_pressed("attack"), "Remote Hunter starts autoattacking a selected enemy without holding right click"):
		return
	hunter.state_machine._physics_process(hunter.attack_interval * 0.36)
	verify_arrow.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_arrow() -> void:
	if not host:
		return
	var before = boss.charCurrentLife
	await get_tree().create_timer(0.3).timeout
	if not check(boss.charCurrentLife == before - 9, "Remote hunter arrow deals one server-authorized hit"):
		return
	var sprite = MultiplayerManager.playerList[1].get_node("AnimatedSprite2D")
	sprite.flip_h = true
	sprite.play("auto_attack")
	verify_charger_animation.rpc_id(client_id)

@rpc("authority", "reliable")
func verify_charger_animation() -> void:
	await get_tree().create_timer(0.25).timeout
	var sprite = MultiplayerManager.playerList[1].get_node("AnimatedSprite2D")
	if not check(sprite.animation == &"auto_attack" and sprite.sprite_frames.get_frame_count("auto_attack") == 8 and sprite.scale.is_equal_approx(Vector2(1.2, 1.2)) and sprite.flip_h, "Remote client sees Charger's dedicated hammer animation, calibrated size and facing"):
		return
	end_charger_animation.rpc_id(1)

@rpc("any_peer", "reliable")
func end_charger_animation() -> void:
	if not host:
		return
	MultiplayerManager.playerList[1].get_node("AnimatedSprite2D").play("idle")
	verify_charger_idle.rpc_id(client_id)

@rpc("authority", "reliable")
func verify_charger_idle() -> void:
	await get_tree().create_timer(0.25).timeout
	var sprite = MultiplayerManager.playerList[1].get_node("AnimatedSprite2D")
	if not check(sprite.animation == &"idle" and sprite.scale == Vector2.ONE, "Remote Charger restores idle scale after the attack"):
		return
	complete_animation_test.rpc_id(1)

@rpc("any_peer", "reliable")
func complete_animation_test() -> void:
	if not host:
		return
	finish_client.rpc_id(client_id)
	await get_tree().create_timer(0.5).timeout
	print("CLASS_NETWORK_SERVER_PASS")
	get_tree().quit()

@rpc("authority", "reliable")
func finish_client() -> void:
	print("CLASS_NETWORK_CLIENT_PASS")
	get_tree().quit()
