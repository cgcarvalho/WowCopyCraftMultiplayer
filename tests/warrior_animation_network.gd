extends Node

const PORT = 18085
var main: Node
var host = false
var client_id = 0
var before_storm = 0

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
	if not check(error == OK, "Warrior animation test peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		main.request_player("res://Scenes/Characters/Heroes/Aurora.tscn")
		MultiplayerManager.playerList[1].set_physics_process(false)
		print("WARRIOR_ANIMATION_SERVER_READY")
	else:
		await multiplayer.connected_to_server
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/SirGura.tscn")
		await get_tree().create_timer(1).timeout
		client_id = multiplayer.get_unique_id()
		var warrior = MultiplayerManager.playerList[client_id]
		warrior.set_physics_process(false)
		warrior.position = Vector2(400, 300)
		warrior.charCurrentTarget = encounter.boss
		await get_tree().create_timer(0.3).timeout
		prepare_cleave.rpc_id(1)
	var watchdog = get_tree().create_timer(25)
	watchdog.timeout.connect(func(): check(false, "Warrior animation network test timed out"))

@rpc("any_peer", "reliable")
func prepare_cleave() -> void:
	if not host:
		return
	client_id = multiplayer.get_remote_sender_id()
	var warrior = MultiplayerManager.playerList[client_id]
	warrior.charCurrentMana = 100
	warrior.charCritChance = 0
	begin_cleave.rpc_id(client_id)

@rpc("authority", "reliable")
func begin_cleave() -> void:
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, "res://Scenes/Skills/Classes/cleave.tscn", client_id, -1)
	await get_tree().create_timer(0.2).timeout
	var warrior = MultiplayerManager.playerList[client_id]
	if not check(warrior.attack_sprite.visible and warrior.attack_sprite.animation == &"cleave" and not warrior.get_node("AnimatedSprite2D").visible, "Owner sees the server-accepted wide Cleave swing"):
		return
	verify_cleave.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_cleave() -> void:
	if not host:
		return
	var warrior = MultiplayerManager.playerList[client_id]
	if not check(warrior.attack_sprite.visible and warrior.attack_sprite.animation == &"cleave", "Host sees the remote Warrior's dedicated Cleave animation"):
		return
	if not check(main.get_node("BossEncounter").boss.charCurrentLife == 456 and warrior.charCurrentMana == 75, "Cleave damage and resource cost are applied only by the server"):
		return
	await get_tree().create_timer(0.65).timeout
	if not check(not warrior.attack_sprite.visible and warrior.get_node("AnimatedSprite2D").visible, "Remote Cleave returns to the regular body on the host"):
		return
	warrior.charCurrentMana = 100
	before_storm = main.get_node("BossEncounter").boss.charCurrentLife
	begin_storm.rpc_id(client_id)

@rpc("authority", "reliable")
func begin_storm() -> void:
	var warrior = MultiplayerManager.playerList[client_id]
	if not check(not warrior.attack_sprite.visible, "Owner's Cleave ends at the same effect boundary"):
		return
	main.get_node("SkillHandler").loadSkillScene.rpc_id(1, "res://Scenes/Skills/Classes/bladestorm.tscn", client_id, client_id)
	await get_tree().create_timer(0.2).timeout
	if not check(warrior.attack_sprite.visible and warrior.attack_sprite.animation == &"bladestorm", "Owner sees the accepted Bladestorm animation"):
		return
	warrior.ability_animation_time = 0
	Input.action_press("move_right")
	warrior._physics_process(0.01)
	var origin = warrior.position
	warrior._physics_process(0.05)
	Input.action_release("move_right")
	warrior.update_presentation(0)
	if not check(warrior.position.x > origin.x and warrior.attack_sprite.visible and warrior.attack_sprite.animation == &"bladestorm", "Owner can move while the ultimate animation keeps spinning"):
		return
	await get_tree().create_timer(0.15).timeout
	verify_storm.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_storm() -> void:
	if not host:
		return
	var warrior = MultiplayerManager.playerList[client_id]
	if not check(warrior.position.x > 400 and warrior.attack_sprite.visible and warrior.attack_sprite.animation == &"bladestorm", "Host sees replicated movement together with the remote ultimate spin"):
		return
	await get_tree().create_timer(6.0).timeout
	if not check(not warrior.attack_sprite.visible and warrior.get_node("AnimatedSprite2D").visible, "Host restores the remote body after the ultimate finishes"):
		return
	if not check(main.get_node("BossEncounter").boss.charCurrentLife == before_storm - 72, "Ultimate animation does not duplicate the six authoritative damage ticks"):
		return
	finish_client.rpc_id(client_id)
	await get_tree().create_timer(0.5).timeout
	print("WARRIOR_ANIMATION_SERVER_PASS")
	get_tree().quit()

@rpc("authority", "reliable")
func finish_client() -> void:
	var warrior = MultiplayerManager.playerList[client_id]
	if not check(not warrior.attack_sprite.visible and warrior.get_node("AnimatedSprite2D").visible, "Owner also restores normal presentation after the ultimate"):
		return
	print("WARRIOR_ANIMATION_CLIENT_PASS")
	get_tree().quit()
