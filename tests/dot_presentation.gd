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
	await get_tree().process_frame
	main.request_player("res://Scenes/Characters/Heroes/Aurora.tscn")
	var player: Character = MultiplayerManager.playerList[1]
	player.set_physics_process(false)
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var enemy: Character = encounter.boss
	player.charCurrentTarget = enemy
	var ui = main.get_node("DotStatusUI")
	check(ui.groups_for(enemy).is_empty() and not ui.selected_panel.visible, "No status panel before a debuff is active")
	var first: DamageOverTime = load("res://Scenes/Skills/Corruption/Corruption.tscn").instantiate()
	main.add_child(first)
	first.cast(player, enemy)
	first.set_physics_process(false)
	var second: DamageOverTime = load("res://Scenes/Skills/Curse of Death/CurseOfDeath.tscn").instantiate()
	main.add_child(second)
	second.cast(player, enemy)
	second.set_physics_process(false)
	first.skillTimer = 2.5
	second.skillTimer = 7.5
	var groups = ui.groups_for(enemy)
	check(groups.size() == 2, "Different DoTs create separate readable indicators")
	ui.refresh = 0
	ui._process(0.1)
	check(ui.selected_panel.visible and ui.selected_rows.size() == 2, "Selected target displays names, durations and bars")
	var id = enemy.get_instance_id()
	check(ui.racks.has(id) and ui.racks[id]["rows"].size() == 2, "Two effects share one organized overhead rack")
	var corruption: Dictionary
	for group in groups:
		if group["name"] == "Corruption":
			corruption = group
	check(is_equal_approx(corruption["remaining"], 7.5), "Display counts time remaining instead of elapsed time")
	var third: DamageOverTime = load("res://Scenes/Skills/Corruption/Corruption.tscn").instantiate()
	main.add_child(third)
	third.cast(player, enemy)
	third.set_physics_process(false)
	groups = ui.groups_for(enemy)
	check(groups.size() == 2, "Matching debuffs from multiple applications share one icon")
	for group in groups:
		if group["name"] == "Corruption":
			check(group["count"] == 2 and group["remaining"] == 10, "Stack count and longest remaining duration are preserved")
	third.queue_free()
	await get_tree().process_frame
	check(enemy.debuffList.size() == 2, "Removing a DoT also removes its status registry entry")
	first.renewDot()
	check(first.skillTimer == 0, "Renewal resets the displayed remaining time")
	first.skillTimer = 10
	check(ui.groups_for(enemy).size() == 1, "Expired effects disappear from the readable display")
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	ui.refresh = 0
	ui._process(0.1)
	check(not ui.selected_panel.visible and not ui.racks.has(id), "Last effect removal clears both HUD and overhead indicators")
	var events_before = DamageNumbers.displayed_dot_events
	var life_before = enemy.charCurrentLife
	enemy.deal_damage(2, player, true)
	check(enemy.charCurrentLife == life_before - 2, "Presentation changes do not alter tick damage")
	check(DamageNumbers.displayed_dot_events == events_before + 1, "Server creates periodic damage feedback")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	MultiplayerManager.playerList.clear()
	await get_tree().create_timer(1).timeout
	print("DoT presentation failures: ", failures)
	get_tree().quit(1 if failures else 0)
