extends Node

var failures = 0
var checks = 0
var main: Node
var handler: Node
var boss: Character

func check(ok: bool, text: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", text)
	else:
		failures += 1
		push_error(text)

func _ready() -> void:
	call_deferred("run")

func spawn(cls: String) -> Character:
	var hero: Character = load("res://Scenes/Characters/Heroes/" + cls + ".tscn").instantiate()
	hero.name = "1"
	MultiplayerManager.playerList[1] = hero
	main.get_node("Players").add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector2(400, 300)
	hero.charCritChance = 0
	return hero

func cleanup(hero: Character) -> void:
	for child in main.get_children():
		if child is Skill or child is CombatProjectile:
			child.free()
	MultiplayerManager.playerList.erase(1)
	hero.free()
	handler.cooldowns.clear()
	handler.casting.clear()
	handler.attack_times.clear()
	boss.charCurrentLife = 480
	boss.charShield = 0
	boss.position = Vector2(480, 300)

func ability(hero: Character, id: String) -> HeroAbility:
	for skill in hero.skillList:
		if skill is HeroAbility and skill.ability_id == id:
			return skill
	return null

func effect(id: String) -> HeroAbility:
	for child in main.get_children():
		if child is HeroAbility and child.ability_id == id:
			child.set_physics_process(false)
			return child
	return null

func cast(hero: Character, id: String, target: int = -1) -> void:
	handler.loadSkillScene(ability(hero, id).skillScenePath, 1, target)

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.get_node("MultiplayerHUD").hide()
	var encounter = main.get_node("BossEncounter")
	encounter.status = "active"
	encounter.set_physics_process(false)
	boss = encounter.boss
	boss.set_physics_process(false)
	boss.position = Vector2(480, 300)
	handler = main.get_node("SkillHandler")
	for cls in ["Aurora", "SirGura", "Charger", "Lulu"]:
		var hero = spawn(cls)
		check(hero.skillList.size() == 4, cls + " has four class abilities")
		check(hero.skillList[3].is_ultimate, cls + " ultimate occupies R / 4")
		for skill in hero.skillList:
			check(ResourceLoader.exists(skill.skillScenePath) and ResourceLoader.exists(skill.iconFilePath), cls + ": valid scene and icon for " + skill.skillName)
		check(hero.get_node("AnimatedSprite2D").sprite_frames.has_animation("cast"), cls + " has cast animation")
		check(hero.get_node("AnimatedSprite2D").sprite_frames.has_animation("auto_attack"), cls + " has auto attack animation")
		cleanup(hero)
	var aurora = spawn("Aurora")
	check(aurora.skillList[0].skillCoolDownTime == 4, "Shadow Bolt cooldown is exactly 4 seconds")
	for i in [1, 2]:
		var dot: Skill = load(aurora.skillList[i].skillScenePath).instantiate()
		main.add_child(dot)
		dot.cast(aurora, boss)
		dot.set_physics_process(false)
	var reap: HeroAbility = HeroAbility.create("soul_reap")
	main.add_child(reap)
	reap.cast(aurora, boss)
	check(boss.charCurrentLife == 411, "Aurora ultimate scales with her two DoTs (45 + 24)")
	cleanup(aurora)
	var warrior = spawn("SirGura")
	check(warrior.charTotalLife == 150 and warrior.charRange <= 110, "Warrior has melee range and increased health")
	warrior.charCurrentLife = 80
	cast(warrior, "second_wind", 0)
	check(warrior.charCurrentLife == 110 and warrior.charShield == 15, "Second Wind heals and protects without a target")
	var mana = warrior.charCurrentMana
	cast(warrior, "second_wind", 0)
	check(warrior.charCurrentMana == mana, "Server rejects warrior cooldown bypass")
	cast(warrior, "cleave")
	check(boss.charCurrentLife == 456 and warrior.charCurrentLife == 110, "Cleave damages enemies and spares caster")
	boss.position = Vector2(900, 300)
	mana = warrior.charCurrentMana
	handler.cooldowns.clear()
	cast(warrior, "cleave")
	check(warrior.charCurrentMana == mana, "Melee skills reject distant enemies without mana cost")
	boss.position = warrior.position + Vector2(80, 0)
	cast(warrior, "bladestorm", 0)
	var storm = effect("bladestorm")
	storm._physics_process(1.0)
	check(boss.charCurrentLife == 444, "Bladestorm ticks once per second")
	warrior.position += Vector2(350, 0)
	storm._physics_process(1.0)
	check(storm.global_position == warrior.global_position and boss.charCurrentLife == 444, "Bladestorm follows warrior and respects radius")
	warrior.position = Vector2(400, 300)
	boss.position = Vector2(780, 300)
	cast(warrior, "charge")
	var dash = effect("charge")
	dash._physics_process(0.4)
	dash._physics_process(0.02)
	check(warrior.global_position.distance_to(boss.global_position) <= 100 and boss.charCurrentLife == 428, "Charge closes the gap and deals one melee hit")
	cleanup(warrior)
	var paladin = spawn("Charger")
	paladin.charCurrentLife = 50
	cast(paladin, "holy_light", 0)
	await get_tree().create_timer(1.3).timeout
	check(paladin.charCurrentLife == 82, "Holy Light defaults to self and heals after server cast time")
	mana = paladin.charCurrentMana
	handler.cooldowns.clear()
	cast(paladin, "holy_light", -1)
	check(paladin.charCurrentMana == mana, "Paladin cannot heal an enemy")
	cast(paladin, "consecration", 0)
	var ground = effect("consecration")
	var point = ground.global_position
	ground._physics_process(1.0)
	check(boss.charCurrentLife == 473 and paladin.charCurrentLife == 85, "Consecration damages enemy and heals ally")
	paladin.position += Vector2(300, 0)
	ground._physics_process(1.0)
	check(ground.global_position == point and paladin.charCurrentLife == 85, "Consecration remains on its original ground position")
	paladin.position = Vector2(400, 300)
	cast(paladin, "divine_dawn", 0)
	await get_tree().create_timer(0.9).timeout
	check(paladin.charCurrentLife >= 125 and paladin.charShield == 35, "Divine Dawn ultimate heals and shields allies")
	check(boss.charCurrentLife <= 431, "Divine Dawn also damages nearby enemies")
	cleanup(paladin)
	var hunter = spawn("Lulu")
	handler.basic_attack(1, -1)
	check(boss.charCurrentLife == 480, "Hunter auto attack does not hit before arrow impact")
	await get_tree().create_timer(0.2).timeout
	check(boss.charCurrentLife == 472, "Hunter auto attack arrow damages on arrival")
	handler.basic_attack(1, -1)
	await get_tree().create_timer(0.1).timeout
	check(boss.charCurrentLife == 472, "Server enforces hunter attack interval")
	boss.position = Vector2(1120, 300)
	var aimed = HeroAbility.create("aimed_shot")
	main.add_child(aimed)
	aimed.cast(hunter, boss)
	aimed.set_physics_process(false)
	aimed._physics_process(0.6)
	check(not aimed.is_queued_for_deletion() and boss.charCurrentLife == 472, "Aimed Shot remains airborne at long range")
	aimed._physics_process(0.3)
	check(boss.charCurrentLife == 440, "Aimed Shot reaches targets at its full 750 range")
	boss.position = Vector2(480, 300)
	boss.charCurrentLife = 472
	cast(hunter, "poison_arrow")
	var poison = effect("poison_arrow")
	poison._physics_process(0.2)
	check(boss.charCurrentLife == 464, "Poison Arrow applies initial projectile damage")
	poison._physics_process(1.0)
	check(boss.charCurrentLife == 460, "Poison ticks on server")
	check(main.get_node("DotStatusUI").groups_for(boss).size() == 1, "Hunter poison appears in the DoT interface")
	handler.cooldowns.clear()
	cast(hunter, "poison_arrow")
	check(boss.debuffList.size() == 1 and poison.skillTimer == 0, "Same hunter refreshes poison rather than stacking")
	cast(hunter, "arrow_rain")
	await get_tree().create_timer(0.7).timeout
	var rain = effect("arrow_rain")
	rain._physics_process(1.0)
	check(boss.charCurrentLife == 448, "Arrow Rain ultimate deals area damage")
	check(hunter.charCurrentLife == 100, "Arrow Rain does not damage allies")
	boss.position += Vector2(400, 0)
	rain._physics_process(1.0)
	check(boss.charCurrentLife == 448, "Enemies outside Arrow Rain take no damage")
	cleanup(hunter)
	check(boss.get_node("AnimatedSprite2D").sprite_frames.get_frame_count("idle") == 36, "Jefferson uses the 36-frame animation")
	check(boss.get_node("AnimatedSprite2D").sprite_frames.get_animation_speed("idle") == 12, "Jefferson animation plays at source 12 fps")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	MultiplayerManager.playerList.clear()
	print("Hero class failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
