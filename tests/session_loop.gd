extends Node

var failures = 0
var checks = 0
var main: Node
var session: Node
var encounter: Node
var handler: Node
var boss: Character

func check(ok: bool, text: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", text)
	else:
		failures += 1
		push_error(text)

func clear_skills() -> void:
	for node in main.get_children():
		if node is Skill or node is CombatProjectile:
			node.queue_free()

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("Session")
	encounter = main.get_node("BossEncounter")
	handler = main.get_node("SkillHandler")
	boss = encounter.boss
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	session.set_physics_process(false)
	session.open_lobby()
	main.get_node("MultiplayerHUD").hide()
	check(session.running and session.stage == "lobby", "Host opens a connected lobby instead of starting combat")
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	var warrior: Character = MultiplayerManager.playerList[1]
	warrior.set_physics_process(false)
	warrior.charCritChance = 0
	check(warrior.resource_name == "Raiva" and warrior.charCurrentMana == 0, "Warrior starts with rage instead of regenerating mana")
	check(not session.can_start(), "An unready player prevents starting")
	session.set_player_name("  Testador  ")
	check(session.roster[1].name == "Testador", "Lobby display name is trimmed on server")
	var hp = boss.charCurrentLife
	handler.basic_attack(1, -1)
	check(boss.charCurrentLife == hp, "Lobby rejects combat requests")
	session.set_ready(true)
	check(session.can_start(), "Host can start after selecting class and readying")
	session.start_match()
	check(session.stage == "countdown" and session.countdown == 3, "Start begins synchronized three-second countdown")
	check(warrior.charCurrentLife == 150 and warrior.charCurrentMana == 0, "Round preparation restores health and class starting resource")
	session._physics_process(3.1)
	warrior.set_physics_process(false)
	check(session.stage == "active" and encounter.status == "active", "Countdown starts the encounter")
	warrior.on_basic_hit()
	check(warrior.charCurrentMana == 12 and warrior.momentum == 1, "Warrior basic hit generates rage and Momentum")
	warrior.deal_damage(10, boss)
	check(warrior.charCurrentMana == 20, "Taking a hit also generates rage")
	for i in 8:
		warrior.on_basic_hit()
	check(warrior.charCurrentMana == 100 and warrior.momentum == 5, "Rage and Momentum are capped")
	warrior.update_class_passive(4.1)
	check(warrior.momentum == 0, "Momentum expires without continued attacks")
	# A second player is spawned by the authoritative factory for cooperative mechanics.
	session.register_peer(2)
	main.used_slots[2] = 1
	main.multiplayer_spawner.spawn({"id": 2, "path": "res://Scenes/Characters/Heroes/Lulu.tscn", "slot": 1})
	var hunter: Character = MultiplayerManager.playerList[2]
	session.selected(2, hunter)
	hunter.spectator = false
	session.roster[2].spectator = false
	hunter.set_physics_process(false)
	hunter.charCritChance = 0
	check(hunter.resource_name == "Foco" and hunter.manaRegen == 8, "Hunter uses regenerating focus")
	hunter.previous_position = hunter.global_position
	hunter.update_class_passive(1.1)
	check(is_equal_approx(hunter.outgoing_damage_multiplier(), 1.15), "Hunter gains damage by holding position")
	hunter.position += Vector2(20, 0)
	hunter.update_class_passive(0.1)
	check(is_equal_approx(hunter.outgoing_damage_multiplier(), 1), "Moving breaks Hunter's steady aim")
	warrior.position = Vector2(500, 300)
	hunter.position = Vector2(520, 300)
	warrior.charCurrentLife = 150
	hunter.charCurrentLife = 100
	boss.position = Vector2(700, 300)
	encounter.begin_spell("bond")
	check(encounter.danger_visible and encounter.danger_remaining == 3, "Shared attack has a three-second group warning")
	encounter.resolve_area()
	check(warrior.charCurrentLife == 126 and hunter.charCurrentLife == 76, "Grouping splits shared damage equally")
	warrior.charCurrentLife = 150
	hunter.charCurrentLife = 100
	hunter.position = Vector2(200, 300)
	boss.charCurrentTarget = warrior
	boss.target_hold = 1
	encounter.begin_spell("bond")
	encounter.resolve_area()
	check(warrior.charCurrentLife == 102 and hunter.charCurrentLife == 100, "An isolated marked player receives the entire shared hit")
	warrior.charCurrentLife = 150
	hunter.charCurrentLife = 100
	hunter.position = warrior.position
	encounter.begin_spell("spread")
	encounter.resolve_area()
	check(warrior.charCurrentLife == 114 and hunter.charCurrentLife == 64, "Stacked red marks cause overlapping explosions")
	warrior.charCurrentLife = 150
	hunter.charCurrentLife = 100
	hunter.position = Vector2(200, 300)
	encounter.begin_spell("spread")
	encounter.resolve_area()
	check(warrior.charCurrentLife == 132 and hunter.charCurrentLife == 82, "Spreading prevents overlapping red-mark damage")
	encounter.begin_spell("channel")
	handler.request_interrupt()
	check(not encounter.danger_visible and warrior.interrupt_remaining == 16, "A nearby Warrior interrupts the channel with server cooldown")
	hp = warrior.charCurrentLife
	encounter.resolve_area()
	check(warrior.charCurrentLife == hp, "An interrupted channel cannot damage the group later")
	warrior.interrupt_remaining = 0
	boss.position = Vector2(1000, 300)
	encounter.begin_spell("channel")
	handler.request_interrupt()
	check(encounter.danger_visible and warrior.interrupt_remaining == 0, "An out-of-range interrupt is rejected without spending cooldown")
	encounter.resolve_area()
	check(warrior.charCurrentLife == hp - 42, "Uninterrupted channel damages living players")
	check(ArenaNavigation.move(Vector2(740, 185), Vector2(220, 0)).x <= 775, "Fast movement cannot tunnel through a tree")
	check(ArenaNavigation.allowed(ArenaNavigation.move(Vector2(60, 300), Vector2(-800, 0))), "Player movement remains inside arena bounds")
	check(ArenaNavigation.move(Vector2(740, 220), Vector2(120, 80)).distance_to(Vector2(740, 220)) > 30, "Player can slide around a trunk")
	# Aiming commits a finite, server-validated location only after confirmation.
	var rain: HeroAbility = HeroAbility.create("arrow_rain")
	warrior.skillList.append(rain)
	warrior.charCurrentMana = 100
	warrior.position = Vector2(500, 300)
	check(not handler.valid_ground(rain, warrior, Vector2(NAN, 300)), "Server rejects non-finite ground aim")
	check(not handler.valid_ground(rain, warrior, Vector2(9000, 300)), "Server rejects out-of-arena ground aim")
	handler.loadSkillScene(rain.skillScenePath, 1, 0, Vector2(650, 330))
	await get_tree().create_timer(0.7).timeout
	var placed: HeroAbility
	for node in main.get_children():
		if node is HeroAbility and node.ability_id == "arrow_rain":
			placed = node
	check(placed != null and placed.global_position == Vector2(650, 330), "Confirmed ground area uses the chosen point instead of snapping to target")
	clear_skills()
	# Victory rewards are applied once, and a pending cast from a previous round is invalidated.
	warrior.skillList.append(ShadowBolt.new())
	warrior.charCurrentMana = 100
	boss.position = Vector2(700, 300)
	handler.loadSkillScene(ShadowBolt.filePath, 1, -1)
	var old_token = handler.round_token
	boss.charCurrentLife = 0
	encounter._physics_process(0.1)
	check(session.stage == "victory", "Boss death opens reward stage without disconnecting")
	session.choose_upgrade("offense")
	session.choose_upgrade("offense")
	check(session.upgrades[1].offense == 1, "Each victory grants exactly one reward choice per player")
	session.retry()
	check(session.stage == "victory", "Host waits until every participant chooses a reward")
	session.roster[2].reward = "mastery"
	session.upgrades[2] = {"mastery": 1}
	session.retry()
	warrior.set_physics_process(false)
	hunter.set_physics_process(false)
	check(session.stage == "countdown" and session.round_index == 2, "A new encounter begins with existing peers and characters")
	check(boss.charCurrentLife == 552, "Next boss gains 15 percent of base health")
	check(is_equal_approx(warrior.damage_bonus, 1.12) and is_equal_approx(hunter.cooldown_multiplier, 0.88), "Chosen upgrades apply to the correct characters")
	check(handler.round_token > old_token and handler.cooldowns.is_empty(), "Round reset clears cooldowns and invalidates old cast generations")
	await get_tree().create_timer(1.2).timeout
	check(boss.charCurrentLife == 552, "A cast started before victory cannot hit the next boss")
	session._physics_process(3.1)
	warrior.charCurrentLife = 0
	hunter.charCurrentLife = 0
	encounter._physics_process(0.1)
	check(session.stage == "defeat", "Party wipe opens retry screen")
	session.retry()
	warrior.set_physics_process(false)
	hunter.set_physics_process(false)
	check(session.stage == "countdown" and warrior.charCurrentLife == 150 and hunter.charCurrentLife == 100, "Retry revives the complete party")
	check(session.round_index == 2 and session.upgrades[1].offense == 1, "Defeat keeps existing progression and does not grant extra rewards")
	session.stage = "defeat"
	await session.return_to_selection()
	await get_tree().process_frame
	check(session.stage == "lobby" and session.round_index == 1 and session.upgrades.is_empty(), "Return to selection starts a fresh expedition")
	check(MultiplayerManager.playerList.is_empty() and session.roster[1]["class"] == "", "Selection reset despawns old characters while retaining party")
	main.request_player("res://Scenes/Characters/Heroes/Charger.tscn")
	var paladin: Character = MultiplayerManager.playerList[1]
	paladin.set_physics_process(false)
	check(paladin.resource_name == "Poder sagrado" and paladin.charTotalMana == 5 and paladin.charCurrentMana == 2, "Paladin begins with two holy-power charges, cap five")
	paladin.on_basic_hit()
	check(paladin.charCurrentMana == 3, "Paladin basic attack generates holy power")
	paladin.charCurrentLife = 50
	paladin.apply_heal(20, paladin)
	check(paladin.charCurrentLife == 73, "Paladin aura amplifies healing to nearby allies")
	paladin.reset_for_round(Vector2(200, 300), {"endurance": 2, "mastery": 2})
	paladin.set_physics_process(false)
	check(paladin.charTotalLife == 182 and paladin.charCurrentLife == 182, "Endurance upgrades use base health and fully restore the player")
	paladin.reset_for_round(Vector2(200, 300), {"endurance": 2, "mastery": 2})
	paladin.set_physics_process(false)
	check(paladin.charTotalLife == 182, "Repeated retries never multiply an already-upgraded base stat")
	check(is_equal_approx(paladin.healing_bonus, 1.3), "Mastery increases healing independently of damage")
	# A victory never grants a free reward to someone who joined afterward.
	session.stage = "victory"
	session.register_peer(3)
	check(session.roster[3].spectator and session.roster[3].reward == "skip", "A late arrival cannot claim a reward for a battle they missed")
	session.roster[1].reward = "offense"
	session.roster[2].reward = "skip"
	session.upgrades[1] = {"offense": 1}
	session.retry()
	check(session.stage == "lobby" and not session.roster[1].ready, "Late arrivals bring the group back to readiness before joining the next fight")
	check(session.upgrades[1].offense == 1, "Returning to lobby for late arrivals preserves earned progression")
	main.on_peer_disconnected(3)
	main.on_peer_disconnected(2)
	main.used_slots[2] = 1
	session.register_peer(2)
	main.multiplayer_spawner.spawn({"id": 2, "path": "res://Scenes/Characters/Heroes/Lulu.tscn", "slot": 1})
	var replacement: Character = MultiplayerManager.playerList[2]
	replacement.set_physics_process(false)
	session.selected(2, replacement)
	session.roster[2].ready = true
	session.set_ready(true)
	session.start_match()
	check(session.stage == "countdown", "Reconfirmed party can start after a late-arrival lobby")
	main.on_peer_disconnected(2)
	check(session.stage == "lobby" and not session.roster[1].ready, "Disconnect during countdown cancels start and requires reconfirmation")
	check(CombatFeedback.events > 0 and CombatFeedback.sounds.hit.get_length() > 0, "Combat emits distinct presentation events and loads real sound cues")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	print("Session loop failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
