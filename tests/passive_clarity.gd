extends Node

var main: Node
var handler: Node
var boss: Character
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func text_in(node: Node) -> String:
	var text = node.text if node is Label else ""
	for child in node.get_children():
		text += "\n" + text_in(child)
	return text

func panels_in(node: Node) -> Array:
	var panels = [node] if node is PassivePanel else []
	for child in node.get_children():
		panels.append_array(panels_in(child))
	return panels

func spawn(hero_name: String, id: int = 1) -> Character:
	var hero: Character = load("res://Scenes/Characters/Heroes/" + hero_name + ".tscn").instantiate()
	hero.name = str(id)
	MultiplayerManager.playerList[id] = hero
	main.get_node("Players").add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector2(400, 300)
	hero.previous_position = hero.global_position
	hero.charCurrentMana = hero.charTotalMana
	hero.charCritChance = 0
	return hero

func pause_effects() -> void:
	for node in main.get_children():
		if node is Skill:
			node.set_physics_process(false)

func cleanup() -> void:
	handler.reset_combat()
	for node in main.get_children():
		if node is Skill or node is CombatProjectile:
			node.free()
	for hero in MultiplayerManager.playerList.values().duplicate():
		hero.free()
	boss.charCurrentLife = boss.charTotalLife

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
	boss.charCritChance = 0
	boss.position = Vector2(480, 300)
	handler = main.get_node("SkillHandler")
	for hero_name in ["Aurora", "SirGura", "Charger", "Lulu"]:
		var hero = spawn(hero_name)
		var info = ClassPassives.definition(hero.charClass)
		check(info.name != "Sem passiva" and not info.summary.is_empty() and not info.description.is_empty(), hero_name + " has a named passive with a visible summary and full explanation")
		var panel = PassivePanel.new()
		panel.size = Vector2(568, 49)
		panel.configure(hero)
		main.add_child(panel)
		var tooltip = panel._make_custom_tooltip(panel.tooltip_text)
		check(text_in(tooltip).contains(info.description) and text_in(tooltip).contains("Ativação automática"), hero_name + " passive tooltip explains its actual trigger and effects")
		check(panel.mouse_filter == Control.MOUSE_FILTER_STOP and panel.detail.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.progress.mouse_filter == Control.MOUSE_FILTER_IGNORE, hero_name + " passive tooltip can be opened over the entire panel")
		tooltip.free()
		hero.charCurrentLife = 0
		panel.refresh()
		check(panel.detail.text.contains("derrotado") and panel.progress.value == 0, hero_name + " displays the passive as inactive on death")
		hero.charCurrentLife = hero.charTotalLife
		hero.spectator = true
		panel.refresh()
		check(panel.detail.text.contains("espectador") and not ClassPassives.state(hero).active, hero_name + " spectators do not display an active passive")
		panel.free()
		cleanup()
	var aurora = spawn("Aurora")
	var bolt: Skill = aurora.skillList[0]
	var corruption: Skill = aurora.skillList[1]
	var curse: Skill = aurora.skillList[2]
	check(is_equal_approx(aurora.passiveSkill.procChance, 0.05), "Dot Master keeps the existing five-percent chance")
	aurora.passiveSkill.procChance = 1.0
	handler.cooldowns[1] = {bolt.skillScenePath: Time.get_ticks_msec() + 10000}
	handler.loadSkillScene(corruption.skillScenePath, 1, -1)
	pause_effects()
	var dot = boss.debuffList[0]
	dot._physics_process(1.0)
	check(aurora.shadow_bolt_ready and handler.proc_ready.get(1) == bolt.skillScenePath and bolt.resetCastTime, "An actual DoT tick activates a server-owned Shadow Bolt proc")
	check(ClassPassives.state(aurora).text.contains("PRONTO") and ClassPassives.state(aurora).value == 1, "Aurora HUD explicitly announces the instant Shadow Bolt and its hotkey")
	var tooltip = SkillTooltip.create(bolt, "1")
	check(text_in(tooltip).contains("DOT MASTER PRONTO") and bolt.cast_description().contains("Instantânea"), "Ready Shadow Bolt tooltip shows the proc and the actual instant cast")
	tooltip.free()
	handler.loadSkillScene(curse.skillScenePath, 1, -1)
	pause_effects()
	check(aurora.shadow_bolt_ready and handler.proc_ready.get(1) == bolt.skillScenePath, "Casting another spell does not consume the Shadow Bolt proc")
	aurora.charCurrentMana = 0
	handler.loadSkillScene(bolt.skillScenePath, 1, -1)
	check(aurora.shadow_bolt_ready and handler.proc_ready.has(1), "Insufficient mana preserves the proc")
	aurora.charCurrentMana = 100
	handler.loadSkillScene(bolt.skillScenePath, 1, 1)
	check(aurora.shadow_bolt_ready and handler.proc_ready.has(1), "An invalid target preserves the proc")
	var mana = aurora.charCurrentMana
	handler.loadSkillScene(bolt.skillScenePath, 1, -1)
	pause_effects()
	check(not aurora.shadow_bolt_ready and not handler.proc_ready.has(1) and not handler.casting.has(1), "Successful Shadow Bolt consumes its proc and bypasses the existing cooldown without a cast timer")
	check(aurora.charCurrentMana == mana - bolt.skillManaCost and not bolt.resetCastTime and not bolt.resetCoolDown, "Proc still costs mana and clears tooltip and cooldown-reset flags")
	mana = aurora.charCurrentMana
	handler.loadSkillScene(bolt.skillScenePath, 1, -1)
	check(aurora.charCurrentMana == mana and not aurora.shadow_bolt_ready, "The consumed proc cannot bypass another cooldown")
	aurora.passiveSkill.on_proc()
	handler.reset_combat()
	check(not aurora.shadow_bolt_ready and not bolt.resetCastTime and handler.proc_ready.is_empty(), "Combat reset clears both the real proc and its visible readiness")
	aurora.charCurrentLife = 0
	aurora.passiveSkill.on_proc()
	check(not aurora.shadow_bolt_ready, "A defeated Aurora cannot gain a new proc")
	cleanup()
	var warrior = spawn("SirGura")
	warrior.on_basic_hit()
	check(ClassPassives.state(warrior).text.contains("1/5") and ClassPassives.state(warrior).text.contains("+3%") and ClassPassives.state(warrior).text.contains("4.0s"), "Warrior status shows stacks, current bonus and remaining duration")
	for hit in 6:
		warrior.on_basic_hit()
	check(ClassPassives.state(warrior).text.contains("+15%") and is_equal_approx(warrior.outgoing_damage_multiplier(), 1.15), "Warrior's maximum displayed bonus matches actual damage scaling")
	warrior.update_class_passive(4.1)
	check(not ClassPassives.state(warrior).active and ClassPassives.state(warrior).value == 0, "Warrior indicator expires with its actual passive")
	var config = warrior.get_node("CombatSynchronizer").replication_config
	check(config.has_property(NodePath(".:momentum_time")) and config.has_property(NodePath(".:shadow_bolt_ready")), "Passive readiness and stack duration replicate from the combat authority")
	cleanup()
	var paladin = spawn("Charger")
	var ally = spawn("SirGura", 2)
	ally.charCurrentLife = 50
	ally.apply_heal(20, paladin)
	check(ally.charCurrentLife == 73 and ClassPassives.state(paladin).text.contains("+15%") and ClassPassives.state(paladin).text.contains("-5%"), "Aura description matches the actual fifteen-percent healing bonus")
	ally.deal_damage(20, paladin)
	check(ally.charCurrentLife == 54, "Aura description matches the actual five-percent incoming damage reduction")
	var second_paladin = spawn("Charger", 3)
	ally.apply_heal(20, paladin)
	check(ally.charCurrentLife == 77, "Two nearby paladins do not stack the aura's healing bonus")
	paladin.position.x += 300
	second_paladin.position.x += 300
	ally.apply_heal(20, paladin)
	check(ally.charCurrentLife == 97, "Leaving both aura ranges removes the benefit as described")
	cleanup()
	var hunter = spawn("Lulu")
	hunter.update_class_passive(0.5)
	check(not ClassPassives.state(hunter).active and is_equal_approx(ClassPassives.state(hunter).value, 0.5), "Hunter indicator displays progress toward steady aim")
	hunter.update_class_passive(0.6)
	check(ClassPassives.state(hunter).active and ClassPassives.state(hunter).text.contains("+15%") and is_equal_approx(hunter.outgoing_damage_multiplier(), 1.15), "Hunter's active status matches actual bonus damage")
	hunter.position.x += 20
	hunter.update_class_passive(0.1)
	check(not ClassPassives.state(hunter).active and ClassPassives.state(hunter).value == 0, "Moving clears both steady aim and the progress indicator")
	hunter.talents = {"marksman": 3}
	hunter.update_class_passive(1.1)
	check(ClassPassives.definition(hunter.charClass, hunter.talents).summary.contains("+25%") and ClassPassives.state(hunter).text.contains("+25%") and is_equal_approx(hunter.outgoing_damage_multiplier(), 1.25), "Hunter passive description and live status follow the selected talent")
	cleanup()
	var selection = load("res://Scenes/Components/PlayerSelect/PlayerSelect.tscn").instantiate()
	main.add_child(selection)
	var panels = panels_in(selection)
	check(panels.size() == 4, "Character selection shows a separate visible passive panel for every hero")
	for panel in panels:
		var info = ClassPassives.definition(panel.hero.charClass)
		check(panel.selection and panel.title.text.contains("PASSIVA") and panel.detail.text == info.summary and not panel.progress.visible, panel.hero.charName + " selection shows the passive independently of active skills")
		var passive_tooltip = panel._make_custom_tooltip(panel.tooltip_text)
		check(text_in(passive_tooltip).contains(info.description), panel.hero.charName + " selection offers the complete passive tooltip")
		passive_tooltip.free()
	selection.free()
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("Passive clarity failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
