extends Node

var checks = 0
var failures = 0
var main: Node
var session: Node
var encounter: Node
var boss: Character

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func freeze(hero: Character) -> void:
	hero.set_physics_process(false)
	hero.charCritChance = 0

func hero(path: String, id: int) -> Character:
	if id == 1:
		main.request_player("res://Scenes/Characters/Heroes/" + path + ".tscn")
	else:
		session.register_peer(id)
		main.used_slots[id] = id - 1
		main.multiplayer_spawner.spawn({"id": id, "path": "res://Scenes/Characters/Heroes/" + path + ".tscn", "slot": id - 1})
		session.selected(id, MultiplayerManager.playerList[id])
	var actor: Character = MultiplayerManager.playerList[id]
	freeze(actor)
	return actor

func reset(actor: Character, talents: Dictionary, upgrades: Dictionary = {}) -> void:
	actor.reset_for_round(Vector2(500, 300), upgrades, talents)
	freeze(actor)

func ability(actor: Character, id: String, target: Character) -> HeroAbility:
	var skill: HeroAbility = HeroAbility.create(id)
	TalentTree.configure_skill(skill, actor.talents)
	main.add_child(skill)
	skill.set_physics_process(false)
	skill.cast(actor, target)
	return skill

func start() -> void:
	session.prepare_round()
	session._physics_process(3.1)
	for actor in MultiplayerManager.playerList.values():
		freeze(actor)
	boss.charCritChance = 0

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	boss = encounter.boss
	session.set_physics_process(false)
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	main.get_node("MultiplayerHUD").hide()
	session.open_lobby()
	var warrior = hero("SirGura", 1)
	var paladin = hero("Charger", 2)
	var hunter = hero("Lulu", 3)
	var aurora = hero("Aurora", 4)
	for member in session.roster.values():
		member.spectator = false
	check(not TalentTree.valid("Warrior", {"light": 1}), "Talents from another class are rejected")
	check(not TalentTree.valid("Hunter", {"venom": 2, "marksman": 2}), "Hybrid builds cannot exceed the three-point budget")
	check(not TalentTree.valid("Hunter", {"venom": -1}) and not TalentTree.valid("Hunter", {"venom": 1.5}), "Negative and noninteger talent ranks are invalid")
	session.learn_talent("guardian", 3)
	session.learn_talent("light", 1)
	check(session.roster[1].talents.is_empty(), "Lobby validates class and predecessor before learning")
	session.roster[1].ready = true
	session.learn_talent("guardian", 1)
	check(session.roster[1].talents.guardian == 1 and not session.roster[1].ready, "Learning a talent cancels readiness")
	session.learn_talent("guardian", 1)
	check(session.roster[1].talents.guardian == 1, "Duplicate talent request cannot consume or grant extra points")
	session.learn_talent("guardian", 2)
	session.learn_talent("berserker", 1)
	session.learn_talent("guardian", 3)
	check(session.roster[1].talents == {"guardian": 2, "berserker": 1}, "Three sequential or hybrid points can be allocated, a fourth is rejected")
	session.reset_talents()
	check(session.roster[1].talents.is_empty(), "Lobby redistribution refunds all three points")
	start()
	session.learn_talent("guardian", 1)
	check(session.roster[1].talents.is_empty(), "Talents cannot be changed during combat")
	# Every branch's three tiers alter real combat or templates used by validation.
	paladin.position = Vector2(50, 150) # Keep its aura away from other fixtures.
	reset(aurora, {"affliction": 3})
	var hp = boss.charCurrentLife
	boss.deal_damage(10, aurora, true)
	check(boss.charCurrentLife == hp - 12 and aurora.manaRegen == 5, "Affliction amplifies periodic damage and mana regeneration")
	check(aurora.skillList[1].tooltip_summary("2").contains("+20% de dano periódico"), "Periodic skill tooltips include the global Affliction talent")
	var dot = ability(aurora, "poison_arrow", boss)
	boss.debuffList.append(dot) # Any own DoT counts for Soul Reap's existing rule.
	hp = boss.charCurrentLife
	var reap = ability(aurora, "soul_reap", boss)
	check(boss.charCurrentLife == hp - 63, "Deep Harvest adds eighteen per own DoT to Soul Reap")
	dot.queue_free()
	reap.queue_free()
	boss.debuffList.clear()
	reset(aurora, {"destruction": 3})
	check(is_equal_approx(aurora.skillList[0].skillCastTime, 0.7), "Destruction shortens the actual Shadow Bolt cast template")
	var bolt: Skill = load(ShadowBolt.filePath).instantiate()
	TalentTree.configure_skill(bolt, aurora.talents)
	main.add_child(bolt)
	bolt.set_physics_process(false)
	boss.position = aurora.position
	bolt.cast(aurora, boss)
	hp = boss.charCurrentLife
	bolt._physics_process(0.1)
	check(boss.charCurrentLife == hp - 13, "Destruction increases real Shadow Bolt impact damage")
	hp = boss.charCurrentLife
	reap = ability(aurora, "soul_reap", boss)
	check(boss.charCurrentLife == hp - 56, "Destruction's final tier amplifies Soul Reap")
	reap.queue_free()
	reset(aurora, {})
	check(aurora.manaRegen == 3 and aurora.skillList[0].skillCastTime == 1 and aurora.skillList[0].talent_description == "", "Removing talents restores original resource, cast time and tooltip")
	reset(warrior, {"berserker": 3})
	warrior.on_basic_hit()
	check(warrior.charCurrentMana == 16, "Berserker generates sixteen rage per basic hit")
	warrior.momentum = 0
	boss.charCurrentLife = boss.charTotalLife
	hp = boss.charCurrentLife
	var cleave = ability(warrior, "cleave", boss)
	check(boss.charCurrentLife == hp - 30, "Berserker Cleave does twenty-five percent more damage")
	cleave.queue_free()
	hp = boss.charCurrentLife
	var storm = ability(warrior, "bladestorm", warrior)
	storm.tick_effect()
	check(boss.charCurrentLife == hp - 15, "Berserker's final tier increases Bladestorm ticks")
	storm.queue_free()
	reset(warrior, {"guardian": 3}, {"endurance": 1})
	check(warrior.charTotalLife == 210, "Guardian health adds to expedition endurance using base life")
	hp = warrior.charCurrentLife
	warrior.deal_damage(20, boss)
	check(warrior.charCurrentLife == hp - 18, "Guardian reduces incoming damage")
	var wind = ability(warrior, "second_wind", warrior)
	check(warrior.charShield == 30, "Guardian's Second Wind grants thirty shield")
	wind.queue_free()
	reset(warrior, {"guardian": 3}, {"endurance": 1})
	check(warrior.charTotalLife == 210 and warrior.charShield == 0, "Talent health is idempotent and shields clear on retry")
	reset(paladin, {"light": 3})
	check(is_equal_approx(paladin.healing_bonus, 1.2) and is_equal_approx(paladin.skillList[0].skillCastTime, 0.8), "Light boosts healing and shortens Holy Light cast validation")
	check(paladin.skillList[0].tooltip_summary("1").contains("+20% de cura"), "Healing skill tooltips include the Light healing multiplier")
	paladin.charCurrentLife = 10
	var dawn = ability(paladin, "divine_dawn", paladin)
	check(paladin.charCurrentLife == 93, "Radiant Dawn heals sixty base, amplified by Light and the existing aura")
	dawn.queue_free()
	reset(paladin, {"bulwark": 3})
	check(paladin.skillList[2].data.radius == 185, "Bulwark expands the actual Consecration radius")
	hp = paladin.charCurrentLife
	paladin.deal_damage(20, boss)
	check(paladin.charCurrentLife == hp - 17, "Bulwark reduction combines with the paladin aura")
	dawn = ability(paladin, "divine_dawn", paladin)
	check(paladin.charShield == 50, "Bulwark's ultimate gives fifty shield")
	dawn.queue_free()
	reset(paladin, {})
	paladin.position = Vector2(50, 150)
	reset(hunter, {"venom": 3})
	hp = boss.charCurrentLife
	var poison = ability(hunter, "poison_arrow", boss)
	poison.tick_effect()
	check(boss.charCurrentLife == hp - 6 and poison.skillDotSeconds == 10, "Venom increases poison ticks and real effect duration")
	poison.queue_free()
	hp = boss.charCurrentLife
	var rain = ability(hunter, "arrow_rain", boss)
	rain.tick_effect()
	check(boss.charCurrentLife == hp - 14, "Venom's final tier increases Arrow Rain ticks")
	rain.queue_free()
	reset(hunter, {"marksman": 3})
	hp = boss.charCurrentLife
	var shot = ability(hunter, "aimed_shot", boss)
	shot.impact()
	check(boss.charCurrentLife == hp - 40 and is_equal_approx(hunter.skillList[0].skillCastTime, 0.7), "Marksman increases Aimed Shot damage and shortens its template")
	shot.queue_free()
	hunter.steady_time = 1
	check(is_equal_approx(hunter.outgoing_damage_multiplier(), 1.25), "Marksman's final tier increases Steady Aim to twenty-five percent")
	check(hunter.skillList[0].tooltip_summary("1").contains("Talentos:") and hunter.skillList[0].tooltip_summary("1").contains("0.7"), "Skill tooltips include selected talent changes and actual cast time")
	# Fresh report, no fixture damage carried between attempts.
	start()
	paladin.position = Vector2(50, 150)
	boss.position = Vector2(700, 300)
	session._physics_process(10)
	check(is_equal_approx(session.combat_report.elapsed, 10), "Report duration counts combat only, excluding lobby and countdown")
	boss.charCurrentLife = 7
	boss.deal_damage(99, hunter)
	check(session.combat_report.rows[3].damage == 7, "Report damage excludes overkill")
	boss.charCurrentLife = 480
	warrior.charCurrentLife = 100
	warrior.apply_heal(500, paladin)
	check(session.combat_report.rows[2].healing == 50, "Report credits only effective healing to the caster")
	warrior.apply_heal(500, paladin)
	check(session.combat_report.rows[2].healing == 50, "Overhealing cannot inflate the report")
	warrior.apply_shield(20, paladin)
	warrior.apply_shield(10, hunter)
	warrior.deal_damage(12, boss)
	check(session.combat_report.rows[2].absorbed == 12 and session.combat_report.rows[3].absorbed == 0, "Shield absorption belongs to its provider; weaker refresh cannot steal credit")
	warrior.apply_shield(18, hunter) # Eight remain from paladin, ten new from hunter.
	warrior.deal_damage(20, boss)
	check(session.combat_report.rows[2].absorbed == 20 and session.combat_report.rows[3].absorbed == 10 and session.combat_report.rows[1].damage_taken == 2, "Mixed shield contributions are consumed once, with only unabsorbed damage taken")
	warrior.charCurrentLife = 3
	warrior.deal_damage(100, boss)
	warrior.deal_damage(100, boss)
	check(session.combat_report.rows[1].damage_taken == 5 and session.combat_report.rows[1].deaths == 1, "Lethal hits clamp damage taken and count one death")
	warrior.charCurrentLife = 150
	warrior.position = Vector2(500, 300)
	hunter.position = Vector2(520, 300)
	aurora.position = Vector2(550, 450)
	encounter.status = "active"
	encounter.begin_spell("bond")
	encounter.danger_position = warrior.position
	encounter.resolve_area()
	check(session.combat_report.rows[1].mechanics == 1 and session.combat_report.rows[3].mechanics == 1, "Shared mechanics reward players who actually divide the damage")
	encounter.begin_spell("channel")
	encounter.interrupt_channel(hunter)
	encounter.interrupt_channel(hunter)
	check(session.combat_report.rows[3].interrupts == 1, "Only a successful interrupt contributes to the report")
	encounter.begin_spell("rupture")
	encounter.danger_position = Vector2(1050, 480)
	encounter.resolve_area()
	check(session.combat_report.rows[1].mechanics == 2, "Avoiding the locked ground eruption counts a completed mechanic")
	var saved_damage = session.combat_report.rows[3].damage
	main.on_peer_disconnected(3)
	session.finished("victory")
	check(session.report.players.has(3) and session.report.players[3].damage == saved_damage, "Results retain a disconnected player's contribution")
	check(session.report.duration == 10 and session.report.result == "victory", "Finished report freezes result and fight duration")
	session.combat_report.add(1, "damage", 999)
	check(session.report.players[1].damage == 0, "Finished statistics reject late events and snapshots do not alias live counters")
	check(BattleReport.highlights(session.report.players, 2).contains("Cura") and BattleReport.highlights(session.report.players, 3).contains("Interrupções"), "Highlights acknowledge healing, protection and utility contributions")
	# Result screen and talent screen are built by the production UI.
	var ui = main.get_node("SessionUI")
	ui.report_open = true
	ui.rebuild()
	check(ui.content.get_child_count() >= 8, "Victory UI builds the report alongside continuation controls")
	session.stage = "lobby"
	ui.talents_open = true
	ui.rebuild()
	check(ui.content.get_child_count() == 5, "Lobby UI builds two talent paths with redistribution and back controls")
	session.prepare_round()
	check(session.report.is_empty() and session.combat_report.rows[1].damage == 0 and session.combat_report.elapsed == 0, "Next attempt starts fresh statistics without accumulating previous results")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	print("Talents report failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
