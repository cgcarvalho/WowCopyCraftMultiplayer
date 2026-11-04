extends Node

const PORT = 18087
var main: Node
var host = false
var client_id = 0
var after_basic = 0
var peak_impact = 0.0
var poison_accepts = 0

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
	encounter.boss.position = Vector2(480, 350)
	CombatFeedback.child_entered_tree.connect(func(node):
		if node is ImpactBurst:
			peak_impact = maxf(peak_impact, node.intensity))
	main.get_node("SkillHandler").cast_confirmed.connect(func(id, path, accepted, _duration, _cooldown):
		if id == client_id and path.ends_with("poison_arrow.tscn") and accepted:
			poison_accepts += 1)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3) if host else peer.create_client("127.0.0.1", PORT)
	if not check(error == OK, "Fluid combat peer initialized"):
		return
	multiplayer.multiplayer_peer = peer
	if host:
		main.request_player("res://Scenes/Characters/Heroes/Charger.tscn")
		MultiplayerManager.playerList[1].set_physics_process(false)
		print("FLUID_NETWORK_SERVER_READY")
	else:
		await multiplayer.connected_to_server
		main.request_player.rpc_id(1, "res://Scenes/Characters/Heroes/Lulu.tscn")
		await get_tree().create_timer(1.0).timeout
		client_id = multiplayer.get_unique_id()
		var hunter = MultiplayerManager.playerList[client_id]
		hunter.set_physics_process(false)
		hunter.position = Vector2(400, 350)
		hunter.charCurrentTarget = encounter.boss
		await get_tree().create_timer(0.2).timeout
		Input.action_press("move_up")
		hunter._physics_process(0.01)
		hunter._physics_process(hunter.attack_interval * 0.36)
		Input.action_release("move_up")
		if not check(hunter.position.y < 350 and hunter.state_machine.current_state is Attack, "Owner walks while releasing its automatic arrow"):
			return
		verify_moving.rpc_id(1)
	get_tree().create_timer(25).timeout.connect(func(): check(false, "Fluid network test timed out"))

@rpc("any_peer", "reliable")
func verify_moving() -> void:
	if not host:
		return
	client_id = multiplayer.get_remote_sender_id()
	await get_tree().create_timer(0.3).timeout
	var hunter = MultiplayerManager.playerList[client_id]
	after_basic = main.get_node("BossEncounter").boss.charCurrentLife
	if not check(hunter.position.y < 340 and after_basic < 480, "Host receives movement and applies the moving arrow once"):
		return
	if not check(is_equal_approx(peak_impact, 0.4), "Host sees the other player's friendly impact at reduced intensity"):
		return
	spam_attack.rpc_id(client_id)

@rpc("authority", "reliable")
func spam_attack() -> void:
	if not check(is_equal_approx(CombatFeedback.effect_opacity(MultiplayerManager.playerList[client_id]), 1), "Remote owner's effects keep full intensity using its own peer identity"):
		return
	var handler = main.get_node("SkillHandler")
	handler.basic_attack.rpc_id(1, client_id, -1)
	handler.basic_attack.rpc_id(1, client_id, -1)
	verify_cadence.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_cadence() -> void:
	if not host:
		return
	await get_tree().create_timer(0.1).timeout
	if not check(main.get_node("BossEncounter").boss.charCurrentLife == after_basic, "Server rejects rapid extra arrows while moving"):
		return
	MultiplayerManager.playerList[client_id].charCurrentMana = 100
	begin_cast.rpc_id(client_id)

@rpc("authority", "reliable")
func begin_cast() -> void:
	await get_tree().create_timer(0.15).timeout
	var buttons = main.get_node("CombatHUD/SkillBar/PanelContainer/HBoxContainer").get_children()
	buttons[0]._on_pressed()
	var cast_bar = main.get_node("CombatHUD/PlayerCastBar")
	var deadline = Time.get_ticks_msec() + 2500
	while not cast_bar.is_casting and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	while cast_bar.is_casting and cast_bar.remaining_seconds() > 0.16:
		await get_tree().process_frame
	if not check(cast_bar.is_casting, "Real Aimed Shot reaches its final input-buffer window"):
		return
	buttons[1]._on_pressed()
	if not check(main.get_node("CombatHUD/SkillBar").queued_button == buttons[1] and buttons[1].queue_badge.visible, "Owner buffers Poison Arrow during the actual last 200ms of Aimed Shot"):
		return
	verify_waiting.rpc_id(1)
	await get_tree().create_timer(0.5).timeout
	if not check(main.get_node("CombatHUD/SkillBar").queued_button == null and poison_accepts == 1 and not buttons[1].timer.is_stopped(), "Queued arrow is accepted exactly once and starts its normal cooldown"):
		return
	verify_resolved.rpc_id(1)

@rpc("any_peer", "reliable")
func verify_waiting() -> void:
	if not host:
		return
	var handler = main.get_node("SkillHandler")
	if not check(handler.casting.has(client_id) and poison_accepts == 0, "Server receives no early Poison Arrow while Aimed Shot is still casting"):
		return

@rpc("any_peer", "reliable")
func verify_resolved() -> void:
	if not host:
		return
	var handler = main.get_node("SkillHandler")
	if not check(poison_accepts == 1 and not handler.casting.has(client_id) and main.get_node("BossEncounter").boss.debuffList.size() == 1, "Server resolves the aimed shot and one buffered poison effect"):
		return
	if not check(main.get_node("BossEncounter").modulate.a == 1, "Enemy warning graphics are unaffected by friendly-effect dimming"):
		return
	finish_client.rpc_id(client_id)
	await get_tree().create_timer(0.4).timeout
	print("FLUID_NETWORK_SERVER_PASS")
	get_tree().quit()

@rpc("authority", "reliable")
func finish_client() -> void:
	print("FLUID_NETWORK_CLIENT_PASS")
	get_tree().quit()
