extends Node

var checks = 0
var failures = 0
var main: Node
var session: Node
var encounter: Node
var handler: Node
var hero: DualWieldWarrior
var boss: Character

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func reset(talents: Dictionary = {}, mastery: String = "") -> void:
	handler.reset_combat()
	encounter.clear_effects()
	hero.reset_for_round(Vector2(530, 390), {}, talents, mastery)
	hero.set_physics_process(false)
	hero.charCritChance = 0
	boss.global_position = Vector2(600, 390)
	boss.charCurrentLife = boss.charTotalLife
	boss.charShield = 0
	boss.shield_sources.clear()
	boss.charCritChance = 0
	encounter.status = "active"
	session.stage = "active"
	main.get_node("EncounterDirector").reset()

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	handler = main.get_node("SkillHandler")
	boss = encounter.boss
	session.set_physics_process(false)
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	session.open_lobby()
	main.loadCharSelectionScreen()
	var selector = main.get_node("CurrentMap").get_child(0)
	var candidates = selector.charList.filter(func(actor): return actor is DualWieldWarrior)
	check(selector.charList.size() == 6 and candidates.size() == 1, "The new dual-wield warrior appears once alongside all five existing characters")
	selector.playerSelected.emit(candidates[0])
	await get_tree().process_frame
	hero = MultiplayerManager.playerList.get(1) as DualWieldWarrior
	if not is_instance_valid(hero):
		check(false, "Character selection spawns the new warrior")
		get_tree().quit(1)
		return
	session.set_ready(true)
	session.start_match()
	session._physics_process(3.1)
	reset()
	check(hero.charTotalLife == 140 and hero.charCurrentMana == 0 and hero.resource_name == "Fúria", "The new warrior starts with 140 life and zero Fury")
	check(hero.skillList.size() == 4 and hero.skillList[3].is_ultimate, "The warrior has three abilities and a dedicated ultimate")
	check(TalentTree.valid("DualWarrior", {"frenzy": 2, "duelist": 1}) and not TalentTree.valid("DualWarrior", {"berserker": 2}), "Own talent branches accept hybrid builds and reject another warrior's branches")
	check(MasteryCatalog.valid("DualWarrior", {"frenzy": 2}, "cross_frenzy") and not MasteryCatalog.valid("DualWarrior", {"duelist": 1}, "vengeful_guard"), "Both new masteries enforce their class and branch prerequisites")
	var life = boss.charCurrentLife
	handler.basic_attack(1, -1)
	check(boss.charCurrentLife == life - 5 and hero.charCurrentMana == 5 and hero.cadence == 0, "The main-hand hit lands once and generates only its five Fury")
	handler.basic_attack(1, -1)
	check(boss.charCurrentLife == life - 5, "Repeated basic requests cannot bypass the pair's attack interval")
	var offhand_deadline = Time.get_ticks_msec() + 1500
	while hero.cadence == 0 and Time.get_ticks_msec() < offhand_deadline:
		await get_tree().physics_frame
	check(boss.charCurrentLife == life - 10 and hero.charCurrentMana == 10 and hero.cadence == 1, "The off-hand lands after 0.18 seconds and grants one Cadence (life=%d, Fury=%d, Cadence=%d)" % [boss.charCurrentLife, hero.charCurrentMana, hero.cadence])
	reset()
	life = boss.charCurrentLife
	var pair = DualBasicAttack.new()
	pair.caster = hero
	pair.target = boss
	main.add_child(pair)
	pair.set_physics_process(false)
	pair._physics_process(0.2)
	pair._physics_process(0.2)
	check(boss.charCurrentLife == life - 10 and hero.cadence == 1, "Multiple physics steps before deletion cannot repeat the off-hand hit")
	reset()
	life = boss.charCurrentLife
	pair = DualBasicAttack.new()
	pair.caster = hero
	pair.target = boss
	main.add_child(pair)
	pair.set_physics_process(false)
	MultiplayerManager.playerList.erase(1)
	pair._physics_process(0.2)
	MultiplayerManager.playerList[1] = hero
	check(boss.charCurrentLife == life - 5 and hero.cadence == 0, "Leaving the session cancels an already scheduled off-hand")
	reset()
	life = boss.charCurrentLife
	handler.basic_attack(1, -1)
	boss.global_position += Vector2(400, 0)
	await get_tree().create_timer(0.22).timeout
	check(boss.charCurrentLife == life - 5 and hero.charCurrentMana == 5 and hero.cadence == 0, "An out-of-range off-hand causes no damage, resource or Cadence")
	reset()
	handler.basic_attack(1, -1)
	life = boss.charCurrentLife
	handler.reset_combat()
	await get_tree().create_timer(0.22).timeout
	check(boss.charCurrentLife == life and hero.cadence == 0, "Reset invalidates a pending off-hand before it can strike")
	reset()
	for index in 5:
		hero.dual_basic_hit(true)
	check(hero.cadence == 3 and hero.cadence_remaining == 4, "Cadence is capped at three and refreshes for four seconds")
	life = boss.charCurrentLife
	handler.loadSkillScene(hero.skillList[0].skillScenePath, 1, -1)
	check(boss.charCurrentLife == life - 30 and hero.cadence == 0 and hero.charCurrentMana == 35, "Corte Cruzado consumes three Cadences for 30 damage and generates ten Fury")
	reset()
	hero.cadence = 2
	hero.cadence_remaining = 4
	boss.position += Vector2(500, 0)
	handler.loadSkillScene(hero.skillList[0].skillScenePath, 1, -1)
	check(hero.cadence == 2 and not handler.cooldowns.has(1), "An invalid Corte Cruzado preserves its stacks and cooldown")
	hero.update_class_passive(4.1)
	check(hero.cadence == 0 and not ClassPassives.state(hero).active, "Cadence expires and its passive HUD becomes inactive")
	reset({"frenzy": 2}, "cross_frenzy")
	hero.dual_basic_hit(true)
	check(hero.cadence_remaining == 6, "Persistent Rhythm extends the real Cadence duration to six seconds")
	var director = main.get_node("EncounterDirector")
	var minions = []
	for point in [Vector2(630, 400), Vector2(650, 380), Vector2(665, 420)]:
		var minion = director.spawn_enemy("guard", point)
		minion.set_physics_process(false)
		minion.spectator = false
		minion.born_remaining = 0
		minions.append(minion)
	hero.cadence = 3
	life = boss.charCurrentLife
	handler.loadSkillScene(hero.skillList[0].skillScenePath, 1, -1)
	check(boss.charCurrentLife == life - 38, "Crossing talent modifies the combined primary damage exactly once")
	var secondary_hits = 0
	for minion in minions:
		if minion.charCurrentLife == minion.charTotalLife - 8:
			secondary_hits += 1
	check(secondary_hits == 2, "Frenesi Cruzado hits at most two other enemies without recursive attacks")
	reset()
	life = boss.charCurrentLife
	boss.position = Vector2(820, 390)
	handler.loadSkillScene(hero.skillList[1].skillScenePath, 1, -1)
	var deadline = Time.get_ticks_msec() + 1500
	while boss.charCurrentLife == life and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	check(boss.charCurrentLife == life - 10 and hero.global_position.distance_to(boss.global_position) <= 110 and hero.charCurrentMana == 10, "Passo de Aço moves to the target before applying its damage and Fury")
	check(ArenaNavigation.allowed(hero.global_position), "The lunge finishes inside navigable arena bounds")
	reset()
	hero.charCurrentMana = 29
	handler.loadSkillScene(hero.skillList[2].skillScenePath, 1, 1)
	check(hero.charShield == 0 and hero.charCurrentMana == 29, "Insufficient Fury prevents the guard without spending resource")
	hero.charCurrentMana = 100
	handler.loadSkillScene(hero.skillList[2].skillScenePath, 1, 1)
	check(hero.charShield == 24 and hero.charCurrentMana == 70 and hero.riposte_remaining == 3, "Guarda de Lâminas spends 30 Fury and grants its bounded protection")
	life = boss.charCurrentLife
	hero.deal_damage(6, boss)
	check(hero.charShield == 18 and hero.charCurrentMana == 82 and boss.charCurrentLife == life - 8 and hero.riposte_remaining == 0, "The first absorption triggers exactly one riposte and twelve Fury")
	hero.deal_damage(6, boss)
	check(boss.charCurrentLife == life - 8 and hero.charCurrentMana == 82, "Further guard absorptions cannot repeat the counterattack")
	reset()
	hero.charCurrentMana = 100
	hero.apply_shield(20, boss, 5)
	handler.loadSkillScene(hero.skillList[2].skillScenePath, 1, 1)
	hero.deal_damage(6, boss)
	check(hero.riposte_remaining == 3 and hero.charCurrentMana == 70, "Absorption by an older independent shield does not trigger Blade Guard")
	reset()
	hero.charCurrentMana = 100
	handler.loadSkillScene(hero.skillList[2].skillScenePath, 1, 1)
	hero.shield_sources[0].expires_at = Time.get_ticks_msec() - 1
	life = boss.charCurrentLife
	hero.deal_damage(6, boss)
	check(hero.charCurrentLife == 134 and hero.charShield == 0 and boss.charCurrentLife == life, "An expired guard cannot absorb or produce a stale riposte")
	reset({"duelist": 3}, "vengeful_guard")
	var ally: Character = load("res://Scenes/Characters/Heroes/Lulu.tscn").instantiate()
	ally.name = "2"
	main.get_node("Players").add_child(ally)
	MultiplayerManager.playerList[2] = ally
	ally.set_physics_process(false)
	ally.position = hero.position + Vector2(30, 0)
	hero.charCurrentLife = 100
	hero.charCurrentMana = 100
	handler.loadSkillScene(hero.skillList[2].skillScenePath, 1, 1)
	check(hero.charShield == 32 and hero.charCurrentLife == 112 and hero.skillList[1].skillCoolDownTime == 8, "Duelist talents improve guard, recovery and lunge cooldown")
	life = boss.charCurrentLife
	hero.deal_damage(6, boss)
	check(boss.charCurrentLife == life - 16 and ally.charShield == 12, "Guarda Vingativa doubles the riposte and protects the nearest other ally")
	check("Maestria" in hero.skillList[2].tooltip_summary("3"), "The modified ability tooltip includes its selected mastery")
	reset()
	hero.charCurrentMana = 64
	handler.loadSkillScene(hero.skillList[3].skillScenePath, 1, 1)
	check(hero.charCurrentMana == 64 and not handler.cooldowns.has(1), "The ultimate requires its complete Fury cost")
	hero.charCurrentMana = 100
	life = boss.charCurrentLife
	handler.loadSkillScene(hero.skillList[3].skillScenePath, 1, 1)
	var dance = hero.dance_effect
	dance.set_physics_process(false)
	check(hero.charCurrentMana == 35 and is_instance_valid(dance), "Dança das Lâminas spends 65 Fury and starts its own active effect")
	dance._physics_process(4)
	check(boss.charCurrentLife == life - 48, "The ultimate resolves exactly eight half-second pulses even after a long frame")
	reset({"frenzy": 3})
	hero.charCurrentMana = 100
	life = boss.charCurrentLife
	handler.loadSkillScene(hero.skillList[3].skillScenePath, 1, 1)
	dance = hero.dance_effect
	dance.set_physics_process(false)
	dance._physics_process(4)
	check(boss.charCurrentLife == life - 64, "The final Frenzy talent raises the eight pulses to eight damage")
	reset()
	hero.charCurrentMana = 100
	handler.loadSkillScene(hero.skillList[3].skillScenePath, 1, 1)
	dance = hero.dance_effect
	dance.set_physics_process(false)
	hero.position = Vector2(300, 600)
	life = boss.charCurrentLife
	dance._physics_process(1)
	check(dance.global_position == hero.global_position and boss.charCurrentLife == life, "The ultimate follows the warrior and excludes enemies outside its current radius")
	hero.charCurrentLife = 0
	dance._physics_process(0.5)
	check(dance.is_queued_for_deletion(), "Death cancels the remaining ultimate pulses")
	reset({"duelist": 2})
	reset({"duelist": 2})
	check(hero.charTotalLife == 140 and hero.skillList[1].skillCoolDownTime == 8 and hero.cadence == 0 and hero.charShield == 0, "Repeated resets preserve talent calculations and clear temporary combat state")
	boss.position = hero.position + Vector2(250, 0)
	encounter.begin_spell("channel")
	handler.request_interrupt(-1)
	check(encounter.danger_visible and hero.interrupt_remaining == 0, "The dual-wield warrior cannot interrupt beyond the melee reach of 200")
	boss.position = hero.position + Vector2(150, 0)
	handler.request_interrupt(-1)
	check(not encounter.danger_visible and hero.interrupt_remaining == 16, "A valid nearby interruption uses the same melee cooldown as the original warrior")
	var frames = hero.get_node("AnimatedSprite2D").sprite_frames
	for clip in ["idle", "walk", "auto_attack", "cross", "dash", "guard", "spin", "hit", "death"]:
		check(frames.has_animation(clip) and frames.get_frame_count(clip) >= 12, "The photo-inspired warrior has a complete Ludo " + clip + " animation")
	reset()
	hero.charCurrentMana = 100
	hero.charCurrentTarget = boss
	handler.loadSkillScene(hero.skillList[3].skillScenePath, 1, 1)
	dance = hero.dance_effect
	dance.set_physics_process(false)
	hero.ability_animation_time = 0
	hero.state_machine.set_state(Attack.new())
	dance._physics_process(0.2)
	hero._physics_process(0.016)
	hero.update_presentation(0.016)
	var body = hero.get_node("AnimatedSprite2D")
	var first_spin_frame = body.frame
	dance._physics_process(0.2)
	hero._physics_process(0.016)
	hero.update_presentation(0.016)
	check(body.animation == &"spin" and first_spin_frame >= 4 and body.frame > first_spin_frame, "The ultimate body keeps spinning while the ordinary attack state is active")
	reset()
	hero.charCurrentTarget = boss
	hero.state_machine.set_state(Attack.new())
	hero.deal_damage(6, boss)
	hero._physics_process(0.016)
	hero.update_presentation(0.016)
	hero._physics_process(0.06)
	hero.update_presentation(0.06)
	check(body.animation == &"hit" and body.frame >= 2, "The hit reaction advances through its frames while combat continues")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	print("Dual warrior failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
