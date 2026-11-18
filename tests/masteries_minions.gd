extends Node

var checks = 0
var failures = 0
var main: Node
var session: Node
var director: EncounterDirector
var handler: Node
var encounter: Node
var current_hero: Character

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func spawn_hero(cls: String, id: int, point: Vector2) -> Character:
	var hero: Character = load("res://Scenes/Characters/Heroes/" + cls + ".tscn").instantiate()
	hero.name = str(id)
	hero.set_multiplayer_authority(id)
	MultiplayerManager.playerList[id] = hero
	main.get_node("Players").add_child(hero)
	hero.set_physics_process(false)
	hero.position = point
	hero.charCritChance = 0
	hero.charCurrentMana = hero.charTotalMana
	return hero

func enemy(kind: String, point: Vector2) -> LesserEnemy:
	var node = director.spawn_enemy(kind, point)
	node.set_physics_process(false)
	node.born_remaining = 0
	node.spectator = false
	node.charCritChance = 0
	return node

func hero(cls: String, mastery_id: String) -> Character:
	if is_instance_valid(current_hero):
		current_hero.free()
	current_hero = spawn_hero(cls, 1, Vector2(420, 410))
	if not mastery_id.is_empty():
		var branch: String = MasteryCatalog.DEFINITIONS[mastery_id].branch
		current_hero.talents = {branch: 2}
		current_hero.mastery = mastery_id
	handler.reset_combat()
	director.clear_units()
	encounter.boss.charCurrentLife = encounter.boss.charTotalLife
	encounter.boss.position = Vector2(1300, 180)
	return current_hero

func effect(id: String, caster: Character, victim: Character, point: Vector2 = Vector2.INF) -> HeroAbility:
	var skill: HeroAbility = HeroAbility.create(id)
	main.add_child(skill)
	TalentTree.configure_skill(skill, caster.talents)
	skill.aim_position = point
	skill.cast(caster, victim)
	skill.set_physics_process(false)
	return skill

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.get_node("MultiplayerHUD").hide()
	session = main.get_node("Session")
	director = main.get_node("EncounterDirector")
	handler = main.get_node("SkillHandler")
	encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	director.set_physics_process(false)
	session.set_physics_process(false)
	encounter.status = "active"
	var player = hero("Lulu", "infection")
	check(MasteryCatalog.valid("Hunter", {"venom": 2, "marksman": 1}, "infection"), "Hybrid 2/1 unlocks its major branch mastery")
	check(not MasteryCatalog.valid("Hunter", {"venom": 1}, "infection"), "A mastery requires two points in its own branch")
	check(not MasteryCatalog.valid("Warlock", {"affliction": 3}, "infection"), "A foreign class cannot equip another class's mastery")
	check(MasteryCatalog.valid("Hunter", {"venom": 3}, ""), "Legacy talent choices with no mastery remain valid")
	var victim = enemy("hound", Vector2(620, 410))
	var near = enemy("acolyte", Vector2(692, 410))
	var far = enemy("guard", Vector2(1100, 410))
	var poison = effect("poison_arrow", player, victim)
	poison._physics_process(0.35)
	poison.elapsed = 7.25
	victim.deal_damage(100, player)
	check(near.debuffList.size() == 1 and far.debuffList.is_empty(), "Original poison spreads only to enemies inside its residual radius")
	var copied = near.debuffList[0] as HeroAbility
	check(copied.secondary_effect and is_equal_approx(float(copied.data.duration), 2.75), "Poison copy is secondary and preserves the shorter remaining duration")
	var display = main.get_node("DotStatusUI").groups_for(near)
	check(display.size() == 1 and is_equal_approx(display[0].remaining, 2.75), "Copied poison's HUD countdown preserves its fractional remaining duration")
	handler.copy_dot(copied.skillScenePath, 1, int(near.name), 2.0)
	check(is_equal_approx(copied.skillDotSeconds, 2.75) and is_equal_approx(float(copied.data.duration), 2.75), "Refreshing a copy keeps the longer residual duration in gameplay and presentation")
	near.deal_damage(1000, player)
	check(far.debuffList.is_empty(), "A secondary infection terminates without another propagation")
	var reapplied = enemy("guard", Vector2(700, 500))
	handler.copy_dot(poison.skillScenePath, 1, int(reapplied.name), 1.25)
	var residual = reapplied.debuffList[0]
	effect("poison_arrow", player, reapplied)
	check(not residual.secondary_effect and is_equal_approx(residual.skillDotSeconds, 10.0) and is_equal_approx(float(residual.data.duration), 10.0), "A fresh original Poison Arrow restores full talent duration and original propagation")
	player = hero("Lulu", "piercing")
	victim = enemy("guard", Vector2(620, 410))
	near = enemy("guard", Vector2(710, 410))
	far = enemy("guard", Vector2(820, 410))
	var off_line = enemy("guard", Vector2(710, 470))
	var aimed = effect("aimed_shot", player, victim)
	aimed._physics_process(0.25)
	var piercing: PiercingArrow
	for child in main.get_children():
		if child is PiercingArrow:
			piercing = child
	check(is_instance_valid(piercing), "Aimed Shot creates its piercing extension after the confirmed primary hit")
	if is_instance_valid(piercing):
		piercing.set_physics_process(false)
		piercing._physics_process(0.5)
	check(near.charCurrentLife < near.charTotalLife and far.charCurrentLife == far.charTotalLife and off_line.charCurrentLife == off_line.charTotalLife, "Piercing uses segment collision, direction, range and a unique target set")
	player = hero("Teo", "conductive_rivet")
	var engineer = player as Engineer
	victim = enemy("guard", Vector2(600, 410))
	near = enemy("guard", Vector2(650, 410))
	engineer.deploy_beacon(victim.global_position, 10)
	for i in 3:
		engineer.on_basic_hit(victim)
	var rivet: CombatProjectile
	for child in main.get_children():
		if child is CombatProjectile and child.style == "rivet" and not child.basic:
			rivet = child
	check(is_instance_valid(rivet) and rivet.damage == 7 and engineer.circuit_hits == 0, "Circuit mastery produces one secondary rivet with its own damage")
	if is_instance_valid(rivet):
		rivet.set_physics_process(false)
		rivet._physics_process(0.5)
	check(near.charCurrentLife == near.charTotalLife - 7, "Secondary rivet damage is applied once")
	player = hero("Teo", "shelter_circuit")
	engineer = player as Engineer
	victim = enemy("guard", Vector2(600, 410))
	engineer.deploy_beacon(Vector2(500, 410), 10)
	var friend = spawn_hero("SirGura", 2, Vector2(520, 440))
	for i in 6:
		engineer.on_basic_hit(victim)
	check(friend.charShield == 6 and player.charShield == 6, "Shelter Circuit refreshes one bounded contribution per ally")
	friend.free()
	player = hero("Charger", "chain_light")
	player.charCurrentLife = 100
	friend = spawn_hero("SirGura", 2, Vector2(460, 410))
	var third = spawn_hero("Lulu", 3, Vector2(490, 410))
	friend.charCurrentLife = 70
	third.charCurrentLife = 20
	var heal = effect("holy_light", player, friend)
	check(friend.charCurrentLife > 70 and third.charCurrentLife > 20 and player.charCurrentLife == 100, "Chain Light chooses the second ally by lowest life fraction")
	heal.free()
	friend.free()
	third.free()
	player = hero("Charger", "protective_ground")
	var ground = effect("consecration", player, player)
	ground.tick_effect()
	ground.tick_effect()
	check(player.charShield == 4, "Consecration renews its shield contribution without stacking each tick")
	var guard = enemy("guard", Vector2(500, 410))
	player.upsert_shield(20, guard, 4, "runic_guard")
	player.remove_sourced_shield(int(guard.name), "runic_guard")
	check(player.charShield == 4, "Removing a provider's shield preserves other sources")
	ground.free()
	player = hero("SirGura", "shared_guard")
	friend = spawn_hero("Lulu", 2, Vector2(490, 410))
	var wind = effect("second_wind", player, player)
	check(player.charShield == 30 and friend.charShield == 15, "Shared Guard grants half the talent-adjusted shield to the nearest ally")
	wind.free()
	friend.free()
	player = hero("SirGura", "drag")
	victim = enemy("guard", Vector2(515, 410))
	var storm = effect("bladestorm", player, player)
	var origin = victim.position
	storm.tick_effect()
	var pulled = victim.position
	storm.tick_effect()
	check(pulled.distance_to(origin) > 30 and victim.position == pulled, "Bladestorm pulls eligible minions and honors each target's pull interval")
	storm.free()
	player = hero("Aurora", "echo")
	victim = enemy("guard", Vector2(620, 410))
	near = enemy("guard", Vector2(690, 410))
	var bolt: Skill = load(ShadowBolt.filePath).instantiate()
	main.add_child(bolt)
	bolt.cast(player, victim)
	bolt.set_physics_process(false)
	bolt._physics_process(1.0)
	var echoes = 0
	for child in main.get_children():
		if child is CombatProjectile and child.style == "magic":
			echoes += 1
	check(echoes == 1, "Shadow Bolt emits exactly one echo for one eligible nearby enemy")
	player = hero("Aurora", "contagion")
	victim = enemy("guard", Vector2(620, 410))
	near = enemy("guard", Vector2(710, 410))
	for index in [1, 2]:
		var dot: DamageOverTime = load(player.skillList[index].skillScenePath).instantiate()
		main.add_child(dot)
		dot.cast(player, victim)
		dot.skillTimer = 8
		dot.set_physics_process(false)
	var reap = effect("soul_reap", player, victim)
	check(near.debuffList.size() == 2, "Soul Reap spreads each of Aurora's original curses to the nearby survivor")
	for dot in near.debuffList:
		check(is_equal_approx(dot.skillDotSeconds, 2), "Contagion preserves remaining duration and creates a bounded copy")
	reap.free()
	player = hero("Lulu", "")
	session.open_lobby()
	session.selected(1, player)
	session.learn_talent("venom", 1)
	session.learn_mastery("infection")
	check(session.roster[1].mastery == "", "Lobby rejects a mastery before the second prerequisite")
	session.learn_talent("venom", 2)
	session.learn_mastery("infection")
	check(session.roster[1].mastery == "infection" and not session.roster[1].ready, "Lobby equips an authorized mastery and cancels readiness")
	session.reset_talents()
	check(session.roster[1].mastery == "", "Redistributing talents clears the now-invalid mastery")
	session.select_encounter_mode("expedition")
	session.set_ready(true)
	session.start_match()
	session._physics_process(3.1)
	player.set_physics_process(false)
	check(session.stage == "active" and director.phase == "waves" and encounter.boss.spectator, "Expedition starts a teaching wave and removes Jefferson from selectable combat")
	var acolyte = director.living_enemies()[0]
	acolyte.set_physics_process(false)
	acolyte.born_remaining = 0
	acolyte.spectator = false
	acolyte.global_position = player.global_position + Vector2(160, 0)
	acolyte.start_cast(player)
	acolyte.cast_remaining = 1.0
	acolyte._process(0)
	check(acolyte.sprite.frame == 4 and not acolyte.sprite.is_playing(), "A late observer's acolyte pose follows confirmed warning progress")
	acolyte.cast_remaining = 0.1
	acolyte._process(0)
	check(acolyte.sprite.frame > 4 and acolyte.sprite.frame < 9, "The casting pose advances without releasing the spell before impact")
	player.charCurrentTarget = acolyte
	main.get_node("SessionUI").update_enemy_cast(player)
	check(main.get_node("SessionUI").enemy_cast_text.visible and "Selo Volátil" in main.get_node("SessionUI").enemy_cast_text.text, "The selected caster shows its skill name, remaining time and interrupt key")
	handler.request_interrupt()
	check(acolyte.cast_remaining == 0 and player.interrupt_remaining == 16, "F interrupts the selected caster and begins cooldown only on success")
	main.get_node("SessionUI").update_enemy_cast(player)
	check(not main.get_node("SessionUI").enemy_cast_text.visible, "An interrupted warning clears its target cast caption")
	player.interrupt_remaining = 0
	handler.request_interrupt()
	check(player.interrupt_remaining == 0, "An invalid interruption preserves its cooldown")
	acolyte.deal_damage(1000, player)
	director._physics_process(0.01)
	check(director.phase == "rest" and session.report.is_empty(), "Completing a wave schedules the next segment without granting a victory reward")
	director._physics_process(2.1)
	check(director.wave_index == 2 and director.living_enemies().size() == 2, "Solo mixed wave uses its fixed composition")
	for target in director.living_enemies():
		target.set_physics_process(false)
		target.born_remaining = 0
		target.spectator = false
		target.deal_damage(1000, player)
	player.charCurrentLife = 20
	director._physics_process(0.01)
	director._physics_process(6.1)
	player.set_physics_process(false)
	check(director.phase == "boss" and encounter.status == "active" and not encounter.boss.spectator and player.charCurrentLife == player.charTotalLife, "The boss transition restores the group after the six-second respite")
	encounter.finish("victory")
	check(session.stage == "victory" and director.living_enemies().is_empty(), "Encounter completion clears temporary enemies and publishes the final reward")
	session.stage = "active"
	encounter.status = "prelude"
	for map_id in ArenaCatalog.IDS:
		ArenaNavigation.configure(map_id)
		for party_size in range(1, 5):
			director.participants = party_size
			director.clear_units()
			director.spawn_pack(director.mixed_pack())
			var spawned = director.living_enemies()
			var valid = spawned.size() == party_size + 1
			for unit in spawned:
				unit.set_physics_process(false)
				valid = valid and ArenaNavigation.allowed(unit.global_position) and int(unit.name) <= -100
				valid = valid and unit.charTotalLife == roundi(int(LesserEnemy.STATS[unit.enemy_kind].life) * (1 + 0.15 * (party_size - 1)))
			check(valid, "%s supports the planned composition and life scaling for %d players" % [map_id, party_size])
	director.clear_units()
	ArenaNavigation.configure("forest")
	session.stage = "active"
	var protector = enemy("guard", Vector2(600, 400))
	var protected = enemy("acolyte", Vector2(650, 400))
	protector.protect_ally()
	check(protected.charShield == 20, "Guard applies a source-owned protection to a nearby lesser enemy")
	protector.deal_damage(1000, player)
	check(protected.charShield == 0, "Killing the Guard removes only its linked remaining protection")
	protected.start_cast(player)
	var old_life = player.charCurrentLife
	player.global_position += Vector2(0, 95)
	protected.finish_cast()
	check(player.charCurrentLife == old_life, "Leaving a locked acolyte warning avoids its damage")
	var hound = enemy("hound", player.global_position + Vector2(160, 0))
	hound.start_cast(player)
	player.global_position += Vector2(0, 80)
	old_life = player.charCurrentLife
	hound.finish_cast()
	check(player.charCurrentLife == old_life, "A hound's warned dash can be avoided by ordinary movement")
	hound.cast_remaining = 0
	hound.action_time = 0.5
	hound._process(0)
	check(hound.sprite.frame == 9, "The hound's recovery pose uses the replicated action clock")
	director.clear_units()
	director.phase = "boss"
	director.participants = 4
	session.encounter_mode = "reinforcements"
	encounter.status = "active"
	encounter.boss.spectator = false
	encounter.boss.charCurrentLife = roundi(encounter.boss.charTotalLife * 0.70)
	encounter.danger_visible = true
	encounter.spell_kind = "channel"
	director._physics_process(0.1)
	check(director.living_enemies().is_empty(), "Reinforcements wait while Cataclysm is being channelled")
	encounter.danger_visible = false
	director._physics_process(0.1)
	var reinforcement_count = director.living_enemies().size()
	director._physics_process(0.1)
	check(reinforcement_count == 3 and director.living_enemies().size() == 3 and director.reinforced == [75], "The health threshold produces a bounded reinforcement pack only once")
	director.reset()
	player.reset_for_round(player.global_position, {}, {"marksman": 2}, "piercing")
	check("Linha Perfurante" in MasteryCatalog.summary(player.mastery) and "Maestria" in player.skillList[0].tooltip_summary("1"), "Combat tooltips include the selected skill's mastery")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	print("Mastery and minion failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
