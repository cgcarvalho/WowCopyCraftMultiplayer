extends Node2D

var aiming = false
var suppress_attack = false
var preview_skill: Skill
var source_button: Control
var hint = ""

func player() -> Character:
	return MultiplayerManager.playerList.get(multiplayer.get_unique_id())

func hover(skill: Skill) -> void:
	if not aiming:
		preview_skill = skill

func clear_hover() -> void:
	if not aiming:
		preview_skill = null

func begin(skill: Skill, button: Control) -> void:
	preview_skill = skill
	source_button = button
	aiming = true
	hint = "Clique no chão para lançar · Esc / botão direito: cancelar"

func cancel() -> void:
	aiming = false
	preview_skill = null
	source_button = null
	hint = ""

func confirm(point: Vector2) -> bool:
	var hero = player()
	if not aiming or not is_instance_valid(hero) or not is_instance_valid(preview_skill) or not is_instance_valid(source_button):
		cancel()
		return false
	var handler = get_parent().get_node("SkillHandler")
	if not handler.valid_ground(preview_skill, hero, point):
		hint = "Posição fora do alcance ou da arena · Esc: cancelar"
		return false
	source_button.pending = true
	handler.loadSkillScene.rpc_id(1, preview_skill.skillScenePath, int(hero.name), 0, point)
	cancel()
	return true

func _unhandled_input(event: InputEvent) -> void:
	var session = get_parent().get_node("Session")
	var hero = player()
	if not is_instance_valid(hero) or hero.charCurrentLife <= 0 or hero.spectator or (session.running and session.stage != "active"):
		return
	if aiming:
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			if event is InputEventMouseButton:
				suppress_attack = true
			cancel()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			confirm(get_global_mouse_position())
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interrupt"):
		get_parent().get_node("SkillHandler").request_interrupt.rpc_id(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("change_target"):
		var nearest: Character
		for enemy in MultiplayerManager.enemies.values():
			if is_instance_valid(enemy) and enemy.charCurrentLife > 0 and (nearest == null or enemy.global_position.distance_to(hero.global_position) < nearest.global_position.distance_to(hero.global_position)):
				nearest = enemy
		if nearest != null:
			hero.charCurrentTarget = nearest
			hero.ui_handler.showTargetHPBar(nearest, false)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if preview_skill != null and not is_instance_valid(preview_skill):
		cancel()
	queue_redraw()

func _draw() -> void:
	var hero = player()
	var session = get_parent().get_node("Session")
	if not is_instance_valid(hero) or hero.charCurrentLife <= 0 or hero.spectator or (session.running and session.stage != "active"):
		return
	if is_instance_valid(hero.charCurrentTarget) and hero.charCurrentTarget.charCurrentLife > 0:
		var target = hero.charCurrentTarget
		var tint = Color("ff9e76") if hero.global_position.distance_to(target.global_position) > hero.charRange else Color("a3e6b2")
		draw_arc(to_local(target.global_position), 42, 0, TAU, 40, tint, 2, true)
	if not is_instance_valid(preview_skill):
		return
	var center = to_local(hero.global_position)
	var reach = preview_skill.cast_range
	if preview_skill.targeting() != Skill.TargetMode.SELF:
		draw_arc(center, reach, 0, TAU, 100, Color(0.7, 0.8, 1, 0.32), 2, true)
	var radius = float(preview_skill.data.radius) if preview_skill is HeroAbility else 0.0
	if radius <= 0:
		return
	var point = hero.global_position
	if aiming:
		point = get_global_mouse_position()
	elif preview_skill.targeting() != Skill.TargetMode.SELF and is_instance_valid(hero.charCurrentTarget):
		point = hero.charCurrentTarget.global_position
	var valid = not aiming or get_parent().get_node("SkillHandler").valid_ground(preview_skill, hero, point)
	var tint = Color("a6dbae") if valid else Color("ff6969")
	draw_circle(to_local(point), radius, Color(tint, 0.12))
	draw_arc(to_local(point), radius, 0, TAU, 70, Color(tint, 0.85), 3, true)

func _input(event: InputEvent) -> void:
	# During combat Tab targets enemies even if a skill button has keyboard focus.
	var hero = player()
	var session = get_parent().get_node("Session")
	if event.is_action_pressed("change_target") and not aiming and is_instance_valid(hero) and hero.charCurrentLife > 0 and not hero.spectator and (not session.running or session.stage == "active"):
		var nearest: Character
		for enemy in MultiplayerManager.enemies.values():
			if is_instance_valid(enemy) and enemy.charCurrentLife > 0 and (nearest == null or enemy.global_position.distance_to(hero.global_position) < nearest.global_position.distance_to(hero.global_position)):
				nearest = enemy
		if nearest != null:
			hero.charCurrentTarget = nearest
			hero.ui_handler.showTargetHPBar(nearest, false)
		get_viewport().set_input_as_handled()
