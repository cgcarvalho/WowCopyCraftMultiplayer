extends Node

var failures = 0

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var encounter = main.get_node("BossEncounter")
	var boss = encounter.boss
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	check(encounter.status == "waiting", "Encounter waits for a player")
	check(boss.charCurrentLife == Jefferson.MAX_HEALTH, "Jefferson starts with configured HP")
	check(MultiplayerManager.get_character(-1) == boss, "Enemy ID resolves independently of peer IDs")
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	await get_tree().process_frame
	var player: Character = MultiplayerManager.playerList[1]
	player.charCurrentLife = 100
	player.charBaseDamage = 5
	for scene in [Corruption.filePath, GreaterHeal.filePath, HolyShield.filePath, RainOfFire.filePath]:
		player.skillList.append(load(scene).instantiate())
	player.set_physics_process(false)
	player.charCritChance = 0
	encounter._physics_process(0.1)
	check(encounter.status == "active", "First player starts encounter")
	player.global_position = Vector2(300, 300)
	boss.global_position = Vector2(800, 300)
	var distance = boss.global_position.distance_to(player.global_position)
	boss._physics_process(0.5)
	check(boss.global_position.distance_to(player.global_position) < distance, "Boss pursues a living player")
	boss.global_position = player.global_position + Vector2(50, 0)
	boss._physics_process(0.1)
	check(player.charCurrentLife == 92, "Melee deals 8 damage")
	boss._physics_process(0.1)
	check(player.charCurrentLife == 92, "Melee cooldown prevents repeated hits")
	player.charCurrentLife = 100
	encounter.begin_area()
	var announced_position = encounter.danger_position
	check(encounter.danger_visible and encounter.danger_remaining == 2, "Area attack gives two seconds of warning")
	check(player.charCurrentLife == 100, "Telegraph deals no immediate damage")
	var boss_position = boss.global_position
	boss._physics_process(0.5)
	check(boss.global_position == boss_position, "Boss stands still while casting area")
	player.global_position += Vector2(300, 0)
	check(encounter.danger_position == announced_position, "Warning position stays fixed after movement")
	encounter.resolve_area()
	check(player.charCurrentLife == 100, "Moving outside the circle avoids damage")
	encounter.begin_area()
	encounter.resolve_area()
	check(player.charCurrentLife == 75, "Staying inside the circle takes 25 damage")
	check(not encounter.danger_visible, "Area clears after detonation")
	player.charShield = 20
	encounter.begin_area()
	encounter.resolve_area()
	check(player.charCurrentLife == 70 and player.charShield == 0, "Shield absorbs part of boss area damage")
	var handler = main.get_node("SkillHandler")
	player.global_position = boss.global_position
	handler.basic_attack(1, -1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(boss.charCurrentLife == Jefferson.MAX_HEALTH - 5, "Basic attack can damage boss using negative target ID")
	var mana = player.charCurrentMana
	handler.loadSkillScene("res://Scenes/Skills/Greater Heal/Greater_heal.tscn", 1, -1)
	check(player.charCurrentMana == mana, "Players cannot heal the hostile boss")
	handler.loadSkillScene("res://Scenes/Skills/Corruption/Corruption.tscn", 1, 1)
	check(player.charCurrentMana == mana, "Direct hostile spells reject friendly targets")
	handler.loadSkillScene("res://Scenes/Skills/Corruption/Corruption.tscn", 1, -1)
	check(boss.debuffList.size() == 1, "DoT applies to the boss")
	var effect: Skill = boss.debuffList[0]
	effect.set_physics_process(false)
	handler.loadSkillScene("res://Scenes/Skills/Rain of Fire/RainOfFire.tscn", 1, -1)
	var area: AreaDamage
	for node in main.get_children():
		if node is AreaDamage:
			area = node
			area.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(area != null and area.playersInArea.has(boss), "Player AoE detects boss collision layer")
	var life_before = player.charCurrentLife
	var boss_life_before = boss.charCurrentLife
	area._physics_process(1.0)
	check(boss.charCurrentLife == boss_life_before - 5, "Player AoE damages boss")
	check(player.charCurrentLife == life_before, "Player AoE spares allies in the same circle")
	# A dead player is never selected, even if nearest.
	player.charCurrentLife = 0
	check(boss.choose_target() == null, "Boss ignores dead players")
	encounter.begin_area()
	check(not encounter.danger_visible, "Boss does not announce an area without a living target")
	var ally = Character.new()
	ally.charTotalLife = 100
	ally.charCurrentLife = 100
	ally.position = boss.global_position + Vector2(20, 0)
	MultiplayerManager.playerList[2] = ally
	check(boss.choose_target() == ally, "Boss retargets a living ally when first player dies")
	MultiplayerManager.playerList.erase(2)
	ally.free()
	check(boss.choose_target() == null, "Boss ignores disconnected players")
	player.charCurrentLife = 100
	encounter.begin_area()
	boss.charCurrentLife = 0
	encounter._physics_process(0.1)
	check(encounter.status == "victory" and not encounter.danger_visible, "Boss death ends fight and cancels telegraph")
	encounter.resolve_area()
	check(player.charCurrentLife == 100, "Cancelled attack cannot deal post-victory damage")
	await get_tree().process_frame
	check(not is_instance_valid(effect), "Victory removes outstanding effects")
	mana = player.charCurrentMana
	handler.loadSkillScene("res://Scenes/Skills/Holy Shield/HolyShield.tscn", 1, 1)
	check(player.charCurrentMana == mana, "Combat requests rejected after encounter ends")
	encounter.status = "active"
	boss.charCurrentLife = 300
	player.charCurrentLife = 0
	encounter._physics_process(0.1)
	check(encounter.status == "defeat", "Party wipe ends the encounter")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	check(MultiplayerManager.enemies.is_empty(), "Scene cleanup unregisters boss")
	MultiplayerManager.playerList.clear()
	print("Boss fight failures: ", failures)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if failures else 0)
