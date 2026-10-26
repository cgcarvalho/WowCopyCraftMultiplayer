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
	var boss: Jefferson = encounter.boss
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	var player: Character = MultiplayerManager.playerList[1]
	player.set_physics_process(false)
	player.charCritChance = 0
	encounter.status = "active"
	encounter.opening_delay = 0
	boss.position = Vector2(700, 300)
	player.position = Vector2(200, 300)
	var before = boss.position
	boss._physics_process(0.05)
	check(boss.velocity.length() <= Jefferson.ACCELERATION * 0.05 + 0.01, "Movement accelerates gradually")
	check(boss.position.distance_to(before) < 2, "Small frame does not jump toward the target")
	player.position = boss.position + Vector2(80, 0)
	var distance = player.position.distance_to(boss.position)
	boss.velocity = Vector2.ZERO
	boss._physics_process(0.2)
	check(player.position.distance_to(boss.position) > distance, "Mage retreats from close melee players")
	boss.position = Vector2(700, 300)
	player.position = Vector2(450, 300)
	var desired = boss.desired_velocity(player)
	check(absf(desired.x) < 0.1 and absf(desired.y) > 10, "Mage strafes while in casting range")
	var safe = boss.safe_position(Vector2(850, 185))
	check(safe.distance_to(Vector2(850, 185)) >= 117.9, "Steering keeps boss outside tree trunks")
	check(Jefferson.ARENA.has_point(boss.safe_position(Vector2(-1000, -1000))), "Escape destination stays inside arena")
	check(boss.safe_position(Vector2(9999, 9999)).x <= Jefferson.ARENA.end.x, "Escape cannot leave opposite arena boundary")
	var edge = boss.safe_position(Vector2(850, 125))
	check(edge.distance_to(Vector2(850, 185)) >= 117.9 and edge.y >= Jefferson.ARENA.position.y, "Tree avoidance remains valid next to arena wall")
	var ally = Character.new()
	ally.name = "2"
	ally.charTotalLife = 100
	ally.charCurrentLife = 100
	ally.position = Vector2(250, 300)
	MultiplayerManager.playerList[2] = ally
	boss.charCurrentTarget = player
	boss.target_hold = 1
	boss.threat[2] = 200
	check(boss.choose_target() == player, "Target hold avoids rapid target flicker")
	boss.target_hold = 0
	check(boss.choose_target() == ally, "Boss prioritizes a high-threat attacker after target hold")
	var threat_before = float(boss.threat[2])
	boss.deal_damage(10, ally)
	check(float(boss.threat[2]) > threat_before, "Incoming damage records attacker threat")
	ally.charCurrentLife = 0
	check(boss.choose_target() == player, "Dead high-threat players are ignored")
	MultiplayerManager.playerList.erase(2)
	ally.free()
	boss.player_velocities[1] = Vector2(300, 0)
	check(boss.predict_target(player).distance_to(player.position) <= 90.1, "Projectile leading is capped to a dodgeable distance")
	boss.charCurrentTarget = null
	boss.target_hold = 0
	player.position = Vector2(300, 300)
	boss.position = Vector2(700, 300)
	encounter.begin_spell("lance")
	var aim: Vector2 = encounter.danger_direction
	check(encounter.danger_visible and encounter.danger_remaining == 1.6, "Arcane lance has a visible windup")
	player.position += Vector2(0, 120)
	check(encounter.danger_direction == aim, "Lance aim stays locked while player dodges")
	player.charCurrentLife = 100
	encounter.resolve_area()
	check(player.charCurrentLife == 100, "Stepping outside the line avoids lance damage")
	encounter.begin_spell("lance")
	encounter.resolve_area()
	check(player.charCurrentLife == 78, "Standing in lance line deals exactly 22 damage")
	player.charCurrentLife = 100
	encounter.begin_spell("volley")
	check(encounter.projectiles.is_empty(), "Volley windup does not spawn damaging projectiles")
	encounter.resolve_area()
	check(encounter.projectiles.size() == 3, "First phase fires three orb sprites")
	encounter.projectiles = [{"id": 900, "position": player.position - Vector2(100, 0), "velocity": Vector2(400, 0), "life": 2.0}]
	encounter.update_projectiles(0.5)
	check(player.charCurrentLife == 88 and encounter.projectiles.is_empty(), "Swept orb collision hits once even across a long frame")
	encounter.update_projectiles(0.5)
	check(player.charCurrentLife == 88, "Removed orb cannot hit a player twice")
	encounter.projectiles = [{"id": 901, "position": Vector2(900, 50), "velocity": Vector2.RIGHT, "life": 0.01}]
	encounter.update_projectiles(0.1)
	check(encounter.projectiles.is_empty(), "Missed projectiles expire")
	player.position = boss.position + Vector2(60, 0)
	encounter.last_spell = "volley"
	encounter.spell_cooldowns.clear()
	check(encounter.select_spell() == "blink", "Boss selects escape when a player crowds him")
	encounter.begin_spell("blink")
	var origin = boss.position
	var destination: Vector2 = encounter.danger_position
	check(boss.position == origin and encounter.danger_remaining > 1, "Teleport announces its destination before moving")
	encounter.resolve_area()
	check(boss.position == destination and boss.velocity == Vector2.ZERO, "Teleport lands at the announced safe destination")
	check(destination.distance_to(player.position) > origin.distance_to(player.position), "Teleport increases separation from nearby player")
	encounter.last_spell = "volley"
	check(encounter.select_spell() != "blink", "Escape cooldown prevents teleport spam")
	player.position = Vector2(300, 300)
	boss.charCurrentLife = boss.charTotalLife / 2
	encounter.area_cooldown = 100
	encounter._physics_process(0.01)
	check(encounter.phase == 2, "Half health activates second phase")
	check(encounter.select_spell() == "ward", "Second phase prioritizes runic ward once")
	encounter.begin_spell("ward")
	encounter.resolve_area()
	check(boss.charShield == 50 and encounter.ward_used, "Runic ward grants an absorbable 50-point shield")
	check(encounter.select_spell() != "ward", "Used ward is not selected repeatedly")
	boss.charShield = 0
	encounter.begin_spell("volley")
	encounter.resolve_area()
	check(encounter.projectiles.size() == 5, "Second phase widens volley to five orbs")
	check(encounter.area_cooldown < encounter.AREA_INTERVAL, "Second phase shortens recovery between spells")
	var visuals = encounter.get_node("SpellVisual")
	check(visuals.atlas != null and visuals.atlas.get_width() >= 512 and visuals.atlas.get_height() >= 512, "Spell sprites load as a 4-column animated atlas")
	check(boss.get_node("AnimatedSprite2D").scale.x >= 0.29, "Jefferson sprite is enlarged")
	encounter.finish("victory")
	check(encounter.projectiles.is_empty() and not encounter.danger_visible, "Victory cancels every pending projectile and warning")
	var life = player.charCurrentLife
	encounter.update_projectiles(1)
	check(player.charCurrentLife == life, "No orb damage remains after victory")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	MultiplayerManager.playerList.clear()
	await get_tree().create_timer(1).timeout
	print("Jefferson tactics failures: ", failures)
	get_tree().quit(1 if failures else 0)
