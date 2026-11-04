extends Node

var main: Node
var boss: Character
var handler: Node
var bar: Control
var preview: Node
var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func spawn(hero_name: String, id: int = 1) -> Character:
	var hero: Character = load("res://Scenes/Characters/Heroes/" + hero_name + ".tscn").instantiate()
	hero.name = str(id)
	hero.set_multiplayer_authority(id)
	MultiplayerManager.playerList[id] = hero
	main.get_node("Players").add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector2(400, 350)
	hero.previous_position = hero.position
	hero.charCritChance = 0
	hero.charCurrentMana = hero.charTotalMana
	hero.charCurrentTarget = boss
	return hero

func effects(path: String) -> int:
	var count = 0
	for node in main.get_children():
		if node is Skill and node.skillScenePath == path:
			count += 1
	return count

func pause_skills() -> void:
	for node in main.get_children():
		if node is Skill:
			node.set_physics_process(false)

func flush_hits() -> void:
	for node in main.get_children():
		if node is CombatProjectile:
			node.set_physics_process(false)
			node._physics_process(1.0)
			node.free()

func cleanup() -> void:
	Input.action_release("move_up")
	Input.action_release("move_right")
	preview.cancel()
	handler.reset_combat()
	main.get_node("CombatHUD/PlayerCastBar").cancel_cast()
	for node in main.get_children():
		if node is Skill or node is CombatProjectile:
			node.free()
	for hero in MultiplayerManager.playerList.values().duplicate():
		hero.free()
	boss.charCurrentLife = boss.charTotalLife
	boss.position = Vector2(480, 350)

func buttons() -> Array:
	return bar.get_node("PanelContainer/HBoxContainer").get_children()

func wait_wall(seconds: float) -> void:
	var deadline = Time.get_ticks_msec() + roundi(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func _ready() -> void:
	call_deferred("run")

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
	boss.charTotalLife = 10000
	boss.charCurrentLife = 10000
	boss.position = Vector2(480, 350)
	handler = main.get_node("SkillHandler")
	bar = main.get_node("CombatHUD/SkillBar")
	preview = main.get_node("CombatPreview")
	for hero_name in ["Aurora", "SirGura", "Charger", "Lulu"]:
		var hero = spawn(hero_name)
		Input.action_press("move_up")
		hero._physics_process(0.01)
		var before = boss.charCurrentLife
		var origin = hero.position
		hero._physics_process(hero.attack_interval * 0.36)
		flush_hits()
		check(hero.position.y < origin.y and hero.state_machine.current_state is Attack, hero_name + " keeps walking while advancing its attack")
		check(boss.charCurrentLife < before, hero_name + " lands an actual server-authorized moving attack")
		check(hero.get_node("AnimatedSprite2D").animation == &"auto_attack" and hero.basic_animation_remaining > 0, hero_name + " presents the accepted strike during the walking cycle")
		before = boss.charCurrentLife
		handler.basic_attack(1, -1)
		flush_hits()
		check(boss.charCurrentLife == before, hero_name + " moving attacks keep the existing server cooldown")
		Input.action_release("move_up")
		cleanup()
	var hunter = spawn("Lulu")
	var aimed: Skill = hunter.skillList[0]
	var before = boss.charCurrentLife
	handler.loadSkillScene(aimed.skillScenePath, 1, -1)
	Input.action_press("move_right")
	hunter._physics_process(0.01)
	hunter._physics_process(0.12)
	handler._physics_process(0.01)
	Input.action_release("move_right")
	check(not handler.casting.has(1), "Movement still interrupts Aimed Shot instead of granting a free moving cast")
	await wait_wall(1.05)
	check(boss.charCurrentLife == before and effects(aimed.skillScenePath) == 0, "Interrupted Aimed Shot never launches its projectile")
	handler.reset_combat()
	hunter.charCurrentMana = 100
	aimed.skillCastTime = 0.15
	Engine.time_scale = 4
	handler.loadSkillScene(aimed.skillScenePath, 1, -1)
	await wait_wall(0.06)
	check(handler.casting.has(1) and main.get_node("CombatHUD/PlayerCastBar").remaining_seconds() > 0, "Cast authority and UI keep the same real deadline when simulation timers advance faster")
	buttons()[1]._on_pressed()
	Engine.time_scale = 1
	await wait_wall(0.18)
	check(bar.queued_button == null and effects(hunter.skillList[1].skillScenePath) == 1, "Buffered skill survives clock divergence and releases after the real cast deadline")
	cleanup()
	var aurora = spawn("Aurora")
	var corruption = buttons()[1]
	var curse = buttons()[2]
	var cost = corruption.skillCast.skillManaCost
	corruption.on_cast_result(1, corruption.skillCast.skillScenePath, true, 0, 0.12)
	handler.cooldowns[1] = {corruption.skillCast.skillScenePath: Time.get_ticks_msec() + 120}
	var mana = aurora.charCurrentMana
	corruption._on_pressed()
	check(bar.queued_button == corruption and corruption.queue_badge.visible and aurora.charCurrentMana == mana, "Last-200ms input is visibly queued without spending mana early")
	await wait_wall(0.18)
	pause_skills()
	check(bar.queued_button == null and aurora.charCurrentMana == mana - cost and effects(corruption.skillCast.skillScenePath) == 1, "Queued cooldown input executes exactly once after readiness")
	handler.reset_combat()
	corruption.on_cast_result(1, corruption.skillCast.skillScenePath, true, 0, 0.5)
	corruption._on_pressed()
	check(bar.queued_button == null, "Inputs more than 200ms early are not held for automatic future casts")
	handler.reset_combat()
	corruption.on_cast_result(1, corruption.skillCast.skillScenePath, true, 0, 0.1)
	curse.on_cast_result(1, curse.skillCast.skillScenePath, true, 0, 0.1)
	corruption._on_pressed()
	curse._on_pressed()
	check(bar.queued_button == curse and not corruption.queue_badge.visible, "A newer skill replaces the single buffered command")
	await wait_wall(0.16)
	pause_skills()
	check(effects(curse.skillCast.skillScenePath) == 1 and bar.queued_button == null, "The replacement executes once")
	handler.reset_combat()
	main.get_node("CombatHUD/PlayerCastBar").start_cast("Fixture", 0.1)
	corruption._on_pressed()
	check(bar.queued_button == corruption, "Last-200ms input can wait for another skill's cast bar")
	await wait_wall(0.16)
	pause_skills()
	check(bar.queued_button == null, "Finishing the cast bar releases its queued input")
	handler.reset_combat()
	corruption.on_cast_result(1, corruption.skillCast.skillScenePath, true, 0, 0.1)
	corruption._on_pressed()
	var escape = InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	preview._input(escape)
	check(bar.queued_button == null and not corruption.queue_badge.visible, "Escape clears the buffered command and its badge")
	corruption._on_pressed()
	preview.select_target(aurora)
	check(bar.queued_button == null, "Changing targets cancels buffered commands instead of redirecting them")
	aurora.charCurrentTarget = boss
	corruption._on_pressed()
	aurora.charCurrentLife = 0
	bar.advance_buffer()
	check(bar.queued_button == null, "Death cancels the buffer")
	aurora.charCurrentLife = aurora.charTotalLife
	corruption._on_pressed()
	bar.queue_deadline_msec = Time.get_ticks_msec() - 1
	bar.advance_buffer()
	check(bar.queued_button == null, "Expired buffered input cannot fire later")
	corruption._on_pressed()
	handler.reset_combat()
	check(bar.queued_button == null and corruption.timer.is_stopped(), "Combat reset clears the buffer and actual button timers")
	corruption.on_cast_result(1, corruption.skillCast.skillScenePath, true, 0, 0.1)
	corruption._on_pressed()
	mana = aurora.charCurrentMana
	boss.position.x = 1400
	corruption.timer.stop()
	corruption.cooldown_until_msec = 0
	bar.advance_buffer()
	check(bar.queued_button == null and aurora.charCurrentMana == mana, "Queued skill revalidates range before spending resources")
	boss.position.x = 480
	corruption.on_cast_result(1, corruption.skillCast.skillScenePath, true, 0, 0.1)
	corruption._on_pressed()
	aurora.charCurrentMana = 0
	corruption.timer.stop()
	corruption.cooldown_until_msec = 0
	bar.advance_buffer()
	check(bar.queued_button == null and aurora.charCurrentMana == 0, "Queued skill revalidates its resource cost at execution")
	cleanup()
	hunter = spawn("Lulu")
	var rain = buttons()[3]
	rain.on_cast_result(1, rain.skillCast.skillScenePath, true, 0, 0.1)
	mana = hunter.charCurrentMana
	rain._on_pressed()
	check(bar.queued_button == rain and not preview.aiming, "Queued ground skill does not start aiming during its cooldown")
	await wait_wall(0.16)
	check(preview.aiming and hunter.charCurrentMana == mana and effects(rain.skillCast.skillScenePath) == 0, "Ground skill buffer opens aim after readiness and waits for an explicit click")
	preview.cancel()
	hunter.last_move_direction = Vector2.RIGHT
	var enemies: Array[Character] = []
	for index in 3:
		var enemy: Character = load("res://Scenes/Characters/Heroes/SirGura.tscn").instantiate()
		enemy.name = str(-2 - index)
		enemy.set_multiplayer_authority(999)
		main.get_node("BossEncounter").add_child(enemy)
		enemy.set_physics_process(false)
		enemy.charTeam = Character.Teams.RED
		enemy.position = hunter.position + [Vector2(-40, 0), Vector2(100, 0), Vector2(200, 0)][index]
		MultiplayerManager.enemies[int(enemy.name)] = enemy
		enemies.append(enemy)
	hunter.charCurrentTarget = null
	preview.cycle_target()
	var first = hunter.charCurrentTarget
	check(first == boss, "Tab initially prioritizes a nearby enemy ahead over a closer enemy behind")
	var seen: Array = [first]
	for index in 3:
		preview.cycle_target()
		seen.append(hunter.charCurrentTarget)
	check(seen.size() == 4 and not seen.slice(1).has(first), "Repeated Tab cycles through nearby enemies instead of reselecting the nearest")
	preview.cycle_target()
	check(hunter.charCurrentTarget == first, "Tab wraps around the target list")
	preview.cycle_target(true)
	check(hunter.charCurrentTarget == seen.back(), "Shift+Tab reverses target order")
	enemies[0].charCurrentLife = 0
	enemies[1].spectator = true
	enemies[2].position.x += 2000
	check(preview.ordered_targets(hunter) == [boss], "Target cycling filters dead, spectator and distant enemies")
	preview.select_target(boss)
	boss.position.x = hunter.position.x + hunter.charRange + 10
	check(preview.target_status().begins_with("FORA"), "Selected enemy has an explicit out-of-autoattack-range status")
	boss.position = hunter.position + Vector2(80, 0)
	check(preview.target_status().begins_with("AO ALCANCE"), "Entering range immediately changes target feedback")
	for enemy in enemies:
		MultiplayerManager.enemies.erase(int(enemy.name))
		enemy.free()
	var ally = spawn("Charger", 2)
	check(is_equal_approx(CombatFeedback.effect_opacity(hunter), 1) and is_equal_approx(CombatFeedback.effect_opacity(ally), 0.4) and is_equal_approx(CombatFeedback.effect_opacity(boss), 1), "Only other players' friendly effects are dimmed; personal and enemy visuals stay clear")
	boss.flash_time = 0
	CombatFeedback.impact(-1, boss.position, "hit", 2)
	var party_burst = CombatFeedback.get_child(CombatFeedback.get_child_count() - 1)
	check(party_burst is ImpactBurst and is_equal_approx(party_burst.intensity, 0.4) and boss.flash_time == 0, "Party impacts are subtle and do not overwrite the enemy's personal-hit flash")
	CombatFeedback.impact(-1, boss.position, "crit", 1)
	var personal_burst = CombatFeedback.get_child(CombatFeedback.get_child_count() - 1)
	check(personal_burst.intensity == 1 and boss.flash_time > 0 and personal_burst.lifetime() < 0.3, "Personal contact produces a distinct brief flash and critical burst")
	CombatFeedback.impact(-1, boss.position, "hit", 1, true)
	var periodic_burst = CombatFeedback.get_child(CombatFeedback.get_child_count() - 1)
	check(periodic_burst.periodic and periodic_burst.intensity < party_burst.intensity and periodic_burst.lifetime() < personal_burst.lifetime(), "Periodic ticks use smaller, shorter feedback to preserve area visibility")
	check(encounter.modulate.a == 1, "Boss warnings retain full visibility")
	CombatFeedback.impact(2, ally.position, "hit", -1)
	var enemy_burst = CombatFeedback.get_child(CombatFeedback.get_child_count() - 1)
	check(enemy_burst.intensity == 1, "Enemy impacts on other party members also keep full visibility")
	cleanup()
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("Fluid combat failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
