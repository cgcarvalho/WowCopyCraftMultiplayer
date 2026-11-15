extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var session = main.get_node("Session")
	var encounter = main.get_node("BossEncounter")
	var boss: Jefferson = encounter.boss
	var handler = main.get_node("SkillHandler")
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	session.open_lobby()
	main.loadCharSelectionScreen()
	var selector = main.get_node("CurrentMap").get_child(0)
	var teo_preview = selector.charList.filter(func(hero): return hero is Engineer)
	check(teo_preview.size() == 1 and teo_preview[0].skillList.size() == 4, "Téo appears once in character selection with four abilities")
	selector.playerSelected.emit(teo_preview[0])
	await get_tree().process_frame
	var teo: Engineer = MultiplayerManager.playerList.get(1)
	if not is_instance_valid(teo):
		check(false, "Téo must spawn from character selection")
		get_tree().quit(1)
		return

	session.set_ready(true)
	session.start_match()
	session._physics_process(3.1)
	teo.charCritChance = 0
	teo.global_position = Vector2(530, 390)
	boss.global_position = Vector2(590, 390)
	var point = boss.global_position
	var rivet: String = teo.skillList[0].skillScenePath
	var beacon: String = teo.skillList[1].skillScenePath
	var valve: String = teo.skillList[2].skillScenePath
	var ultimate: String = teo.skillList[3].skillScenePath
	check(teo.charTotalLife == 115 and teo.charCurrentMana == 20 and teo.resource_name == "Pressão", "Téo starts a round with 115 life and 20 Pressure")
	handler.loadSkillScene(beacon, 1, 0, Vector2(1500, 390))
	handler.loadSkillScene(beacon, 1, 0)
	check(teo.beacon_remaining == 0 and teo.charCurrentMana == 20, "Invalid beacon positions do not spend Pressure")
	handler.loadSkillScene(beacon, 1, 0, point)
	check(teo.in_beacon(point) and teo.charCurrentMana == 0, "A valid Beacon spends 20 Pressure and marks its radius")
	var hp := boss.charCurrentLife
	for hit_index in 3:
		handler.attack_times.clear()
		handler.basic_attack(1, -1)
		await get_tree().create_timer(0.16).timeout
		check(teo.circuit_hits == (hit_index + 1) % 3, "A basic attack inside the Beacon advances Circuito Fechado")
	check(boss.charCurrentLife == hp - 35 and teo.charCurrentMana == 26, "The third basic hit adds 14 damage and five Pressure")
	hp = boss.charCurrentLife
	handler.loadSkillScene(rivet, 1, -1)
	check(teo.charCurrentMana == 26, "Rivet Shot generates Pressure only on impact")
	await get_tree().create_timer(0.58).timeout
	check(boss.charCurrentLife == hp - 16 and teo.charCurrentMana == 44, "Rivet Shot hits for 16 and generates 18 Pressure")
	hp = boss.charCurrentLife
	handler.loadSkillScene(valve, 1, 0, point)
	await get_tree().create_timer(0.58).timeout
	check(boss.charCurrentLife == hp - 31 and teo.charCurrentMana == 16, "Valve Burst causes 31 damage inside a Beacon")
	teo.charCurrentMana = 100
	var original_remaining := teo.beacon_remaining
	teo.beacon_remaining = 0
	handler.loadSkillScene(ultimate, 1, 1)
	check(teo.charCurrentMana == 100, "Overload without an active Beacon does not start or spend Pressure")
	teo.beacon_remaining = original_remaining
	hp = boss.charCurrentLife
	handler.loadSkillScene(ultimate, 1, 1)
	await get_tree().create_timer(0.66).timeout
	check(teo.overload_position == point and teo.overload_remaining > 0 and teo.charCurrentMana == 40, "Overload starts at the Beacon for 60 Pressure")
	teo.deploy_beacon(Vector2(420, 390), 10)
	teo.update_devices(5)
	check(teo.overload_pulses == 4 and boss.charCurrentLife == hp - 48 and teo.overload_remaining == 0, "Overload lands four pulses at its original position")
	teo.charCurrentLife = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(teo.beacon_remaining == 0 and teo.circuit_hits == 0, "Death clears Téo's devices and Circuito Fechado")

	teo.reset_for_round(Vector2(530, 390), {}, {"safeguard": 3})
	handler.reset_combat()
	handler.loadSkillScene(beacon, 1, 0, point)
	check(teo.beacon_remaining <= 6 and teo.beacon_remaining > 0 and teo.charCurrentMana == 20, "Portable Beacon has no cost and lasts six seconds")
	teo.charCurrentMana = 100
	hp = boss.charCurrentLife
	handler.loadSkillScene(valve, 1, 0, point)
	await get_tree().create_timer(0.58).timeout
	check(boss.charCurrentLife == hp - 23 and teo.charShield == 10, "Safety Valve trades extra damage for an allied shield")
	teo.shield_sources[0].expires_at = Time.get_ticks_msec()
	teo.deal_damage(1)
	check(teo.charShield == 0 and teo.charCurrentLife == 114, "An expired temporary shield no longer absorbs damage")
	handler.loadSkillScene(ultimate, 1, 1)
	await get_tree().create_timer(0.66).timeout
	hp = boss.charCurrentLife
	teo.update_devices(5)
	check(boss.charCurrentLife == hp - 40 and teo.charShield == 6, "Emergency Network pulses four times and protects nearby allies")

	teo.reset_for_round(Vector2(530, 390), {}, {"workshop": 3})
	handler.reset_combat()
	handler.loadSkillScene(beacon, 1, 0, point)
	handler.loadSkillScene(rivet, 1, -1)
	await get_tree().create_timer(0.57).timeout
	check(teo.charCurrentMana == 24 and teo.overload_radius() == 135, "Workshop increases Rivet generation and configures the smaller Overload radius")

	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	print("Engineer failures: ", failures)
	get_tree().quit(1 if failures else 0)
