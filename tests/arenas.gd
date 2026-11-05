extends Node

var failures = 0

func check(ok: bool, description: String) -> void:
	if ok:
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
	var session = main.get_node("Session")
	session.set_physics_process(false)
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	session.open_lobby()
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	var hero = MultiplayerManager.playerList[1]
	hero.set_physics_process(false)
	var ui = main.get_node("SessionUI")
	for id in ArenaCatalog.IDS:
		session.stage = "lobby"
		session.set_ready(true)
		var previous: String = session.arena_id
		session.select_arena(id)
		check(session.arena_id == id and ArenaNavigation.arena_id == id, id + " selection applies the matching navigation")
		check(previous == id or not session.roster[1].ready, id + " change cancels stale party readiness")
		main.show_arena()
		var data = ArenaCatalog.definition(id)
		var map = main.get_node("CurrentMap").get_child(0)
		check(map.get_meta("arena_id") == id and main.get_node("CurrentMap").get_child_count() == 1, id + " has exactly one matching map after immediate changes")
		var spawns_safe = true
		for point in data.spawns:
			spawns_safe = spawns_safe and ArenaNavigation.allowed(point)
		check(data.spawns.size() == 4 and spawns_safe, id + " has four valid, unobstructed party spawns")
		check(ArenaNavigation.allowed(data.boss) and encounter.boss.safe_position(data.boss).distance_to(data.boss) < 0.1, id + " boss starts safely inside its arena")
		var swept_safe = true
		var boss_safe = true
		for point in data.obstacles:
			swept_safe = swept_safe and not ArenaNavigation.allowed(point) and ArenaNavigation.move(point - Vector2(110, 0), Vector2(220, 0)).x < point.x
			boss_safe = boss_safe and encounter.boss.safe_position(point).distance_to(point) >= 117.9
		check(swept_safe, id + " swept movement cannot pass through its blockers")
		check(boss_safe, id + " boss steering avoids the selected blockers")
		if data.floor != "":
			check(map.floor_texture != null and map.floor_texture.get_width() >= 256, id + " loads its local Ludo floor texture")
		ui.rebuild()
		var cards = ui.content.find_children("Arena_*", "Button", true, false)
		check(cards.size() == 3, id + " lobby exposes all three arena choices")
		session.set_ready(true)
		session.start_match()
		check(session.stage == "countdown" and hero.position == data.spawns[0] and encounter.boss.position == data.boss, id + " round reset uses the selected player and boss positions")
		session.select_arena("glacier" if id != "glacier" else "forest")
		check(session.arena_id == id, id + " cannot change during countdown")
		session.stage = "active"
		session.select_arena("glacier" if id != "glacier" else "forest")
		check(session.arena_id == id, id + " cannot change during combat")
	# Result-screen changes retain earned upgrades and are used on the next fight.
	session.stage = "victory"
	session.upgrades = {1: {"offense": 1}}
	session.roster[1].reward = "offense"
	session.select_arena("ruins")
	session.retry()
	check(session.round_index == 2 and session.arena_id == "ruins" and hero.position == ArenaCatalog.ARENAS.ruins.spawns[0] and session.upgrades[1].offense == 1, "Changing arena between victories preserves progression and applies on retry")
	session.stage = "defeat"
	session.select_arena("glacier")
	session.retry()
	check(session.round_index == 2 and session.arena_id == "glacier" and encounter.boss.position == ArenaCatalog.ARENAS.glacier.boss, "Defeat retry can change arena without advancing difficulty")
	session.stage = "lobby"
	var current: String = session.arena_id
	session.select_arena("../../unexpected")
	check(session.arena_id == current, "Unknown arena identifiers are rejected")
	check(ArenaNavigation.move(Vector2(800, 400), Vector2(300, 0)).is_equal_approx(Vector2(1100, 400)), "Glacial center has no invisible forest blockers")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1).timeout
	print("Arena failures: ", failures)
	get_tree().quit(1 if failures else 0)
