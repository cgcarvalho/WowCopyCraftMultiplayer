extends Node

var checks = 0
var failures = 0
var main: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func flush_projectiles() -> void:
	for node in main.get_children():
		if node is CombatProjectile:
			node.set_physics_process(false)
			node._physics_process(1.0)
			node.free()

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.get_node("MultiplayerHUD").hide()
	var session = main.get_node("Session")
	session.set_physics_process(false)
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	var boss: Character = encounter.boss
	boss.set_physics_process(false)
	var handler = main.get_node("SkillHandler")
	var preview = main.get_node("CombatPreview")
	for hero_name in ["Aurora", "SirGura", "Charger", "Lulu"]:
		session.open_lobby()
		main.request_player("res://Scenes/Characters/Heroes/" + hero_name + ".tscn")
		var hero: Character = MultiplayerManager.playerList[1]
		hero.set_physics_process(false)
		session.set_ready(true)
		session.start_match()
		session._physics_process(3.1)
		hero.set_physics_process(false)
		hero.charCritChance = 0
		hero.position = Vector2(400, 300)
		boss.charTotalLife = 10000
		boss.charCurrentLife = 10000
		boss.position = hero.position + Vector2(hero.charRange - 1, 0)
		hero.charCurrentTarget = boss
		var states = hero.state_machine
		states._physics_process(0.01)
		check(states.current_state is Attack and not Input.is_action_pressed("attack"), hero_name + ": selected enemy in range starts autoattack without right click")
		var before = boss.charCurrentLife
		states._physics_process(hero.attack_interval * 0.36)
		flush_projectiles()
		check(boss.charCurrentLife < before, hero_name + ": automatic attack produces an actual server-authorized hit")
		Input.action_press("move_right")
		states._physics_process(0.02)
		var origin = hero.position
		states._physics_process(0.02)
		check(states.current_state is Walk and hero.position.x > origin.x, hero_name + ": movement stays active instead of oscillating back to attack")
		Input.action_release("move_right")
		states._physics_process(0.02)
		check(states.current_state is Idle, hero_name + ": restart waits until windup can finish after the previous accepted hit cooldown")
		states.next_basic_attack_at_msec = 0
		states._physics_process(0.02)
		check(states.current_state is Attack, hero_name + ": autoattack resumes after movement stops")
		boss.position = hero.position + Vector2(hero.charRange + 20, 0)
		states._physics_process(0.02)
		states._physics_process(0.02)
		check(states.current_state is Idle, hero_name + ": out-of-range target pauses autoattack")
		boss.position = hero.position + Vector2(hero.charRange - 1, 0)
		states._physics_process(0.02)
		check(states.current_state is Attack, hero_name + ": returning target restarts autoattack without another click")
		hero.ability_animation_time = 0.5
		states._physics_process(0.02)
		states._physics_process(0.02)
		check(states.current_state is Cast, hero_name + ": casting pauses autoattacks")
		hero.ability_animation_time = 0
		states._physics_process(0.02)
		states._physics_process(0.02)
		check(states.current_state is Attack, hero_name + ": finishing a cast resumes autoattack")
		before = boss.charCurrentLife
		handler.basic_attack(1, -1)
		flush_projectiles()
		check(boss.charCurrentLife == before, hero_name + ": restarting attacks cannot bypass the server attack interval")
		if hero_name == "Lulu":
			var button = main.get_node("CombatHUD/SkillBar/PanelContainer/HBoxContainer").get_child(3)
			button.pressed.emit()
			states._physics_process(0.5)
			states._physics_process(0.5)
			check(preview.aiming and states.current_state is Idle and boss.charCurrentLife == before, "Hunter: ground aiming pauses an already running autoattack")
			preview.cancel()
			states._physics_process(0.02)
			check(states.current_state is Attack, "Hunter: cancelling ground aim resumes the selected-target attack")
			button.pressed.emit()
			Input.action_press("attack")
			var cancel = InputEventMouseButton.new()
			cancel.button_index = MOUSE_BUTTON_RIGHT
			cancel.pressed = true
			preview._unhandled_input(cancel)
			states._physics_process(0.02)
			states._physics_process(0.02)
			check(not preview.aiming and states.current_state is Idle and preview.suppress_attack, "Hunter: holding the right-click cancellation gesture does not restart attacks")
			Input.action_release("attack")
			states._physics_process(0.02)
			states._physics_process(0.02)
			check(states.current_state is Attack and not preview.suppress_attack, "Hunter: releasing the cancellation gesture allows autoattack to resume")
		hero.charCurrentTarget = hero
		states._physics_process(0.02)
		states._physics_process(0.02)
		check(states.current_state is Idle, hero_name + ": selecting an ally prevents autoattack")
		hero.charCurrentTarget = null
		states._physics_process(0.02)
		check(states.current_state is Idle, hero_name + ": no selected target leaves the player idle")
		hero.charCurrentTarget = boss
		boss.charCurrentLife = 0
		states._physics_process(0.02)
		check(states.current_state is Idle, hero_name + ": dead targets cannot restart attacks")
		boss.charCurrentLife = 10000
		boss.spectator = true
		states._physics_process(0.02)
		check(states.current_state is Idle, hero_name + ": spectators cannot be autoattacked")
		boss.spectator = false
		states._physics_process(0.02)
		session.stage = "victory"
		before = boss.charCurrentLife
		hero._physics_process(hero.attack_interval * 2)
		flush_projectiles()
		check(boss.charCurrentLife == before and hero.get_node("AnimatedSprite2D").animation == &"idle", hero_name + ": encounter results suspend autoattacks")
		session.stage = "lobby"
		main.on_peer_disconnected(1)
		await get_tree().process_frame
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1).timeout
	print("Autoattack resume failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
