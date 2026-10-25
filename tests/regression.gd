extends Node

var failures = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	# OfflineMultiplayerPeer exercises server validation without opening sockets.
	main.loadCharSelectionScreen()
	await get_tree().process_frame
	check(main.multiplayer.is_server(), "Offline server authority initialized")
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	await get_tree().process_frame
	var caster: Character = MultiplayerManager.playerList.get(1)
	check(is_instance_valid(caster), "Host spawned through MultiplayerSpawner")
	if not is_instance_valid(caster):
		get_tree().quit(1)
		return
	caster.charCritChance = 0
	caster.apply_shield(20)
	caster.deal_damage(30)
	check(caster.charCurrentLife == 90 and caster.charShield == 0, "Shield absorbs damage before HP")
	caster.charCurrentLife = 100
	caster.apply_shield(20)
	caster.deal_damage(10)
	check(caster.charCurrentLife == 100 and caster.charShield == 10, "Shield absorbs a smaller hit")
	var handler = main.get_node("SkillHandler")
	var mana = caster.charCurrentMana
	handler.loadSkillScene("res://Scenes/Skills/ShadowBolt/Shadow_bolt.tscn", 1, 1)
	check(caster.charCurrentMana == mana, "Reject skill outside character loadout")
	handler.loadSkillScene("res://Scenes/Skills/Corruption/Corruption.tscn", 999, 1)
	check(caster.charCurrentMana == mana, "Reject spoofed caster")
	handler.loadSkillScene("res://Scenes/Skills/Corruption/Corruption.tscn", 1, 999)
	check(caster.charCurrentMana == mana, "Reject missing target")
	var enemy: Character = MultiplayerManager.enemies.get(-1)
	check(is_instance_valid(enemy), "Boss registered as combat target")
	var dot_path = "res://Scenes/Skills/Corruption/Corruption.tscn"
	handler.loadSkillScene(dot_path, 1, -1)
	check(enemy.debuffList.size() == 1, "First DoT applied")
	mana = caster.charCurrentMana
	handler.loadSkillScene(dot_path, 1, -1)
	check(caster.charCurrentMana == mana, "Server rejects cooldown bypass")
	var dot = enemy.debuffList[0]
	dot.skillTimer = 5
	handler.cooldowns.clear()
	handler.loadSkillScene(dot_path, 1, -1)
	check(enemy.debuffList.size() == 1 and dot.skillTimer == 0, "Recast renews matching DoT")
	handler.loadSkillScene("res://Scenes/Skills/Holy Shield/HolyShield.tscn", 1, 1)
	check(caster.charShield == 20, "Shield works while a DoT is active")
	mana = caster.charCurrentMana
	handler.loadSkillScene("res://Scenes/Skills/Rain of Fire/RainOfFire.tscn", 1, 0)
	check(caster.charCurrentMana == mana - 20, "Area skill without target uses caster")
	caster.charCurrentMana = 0
	handler.cooldowns.clear()
	handler.loadSkillScene(dot_path, 1, -1)
	check(caster.charCurrentMana == 0, "Insufficient mana rejected")
	main.request_player("res://Scenes/Characters/Heroes/Aurora.tscn")
	check(MultiplayerManager.playerList.size() == 1, "Duplicate spawn rejected")
	check(caster.get_node("CombatSynchronizer").get_multiplayer_authority() == 1, "Combat replication belongs to server")
	main.on_peer_disconnected(1)
	check(MultiplayerManager.playerList.is_empty(), "Disconnect removes registry entry")
	await get_tree().process_frame
	check(not is_instance_valid(caster), "Disconnect frees player")
	print("Failures: ", failures)
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if failures else 0)
