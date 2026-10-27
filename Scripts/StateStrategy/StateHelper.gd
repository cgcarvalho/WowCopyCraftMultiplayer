extends Node
class_name StateHelper

const speed : int = 300

static func canMove(delta : float, state_machine : StateStrategy, checkIdle : bool) -> void:
	var velocity = Vector2.ZERO 
	
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_action_pressed("move_up"):
		velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
	
	state_machine.statePlayer.global_position = ArenaNavigation.move(state_machine.statePlayer.global_position, velocity * delta)
	
	if velocity.length() == 0 and checkIdle:
		state_machine.set_state(Idle.new())

static func checkMove(state_machine : StateStrategy) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0:
		state_machine.set_state(Walk.new())
		
static func checkCast(state_machine : StateStrategy) -> void:
	if state_machine.statePlayer.ability_animation_time > 0 and Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx():
		state_machine.set_state(Cast.new())

static func checkAttack(state_machine: StateStrategy) -> void:
	var preview = state_machine.mainScene.get_node("CombatPreview")
	if preview.suppress_attack:
		if not Input.is_action_pressed("attack"):
			preview.suppress_attack = false
		return
	if Input.is_action_pressed("attack") and state_machine.statePlayer.ability_animation_time <= 0 and not preview.aiming:
		var player = state_machine.statePlayer
		var target = player.charCurrentTarget
		if is_instance_valid(target) and target.charCurrentLife > 0 and target.charTeam != player.charTeam and player.global_position.distance_to(target.global_position) <= player.charRange:
			state_machine.set_state(Attack.new())
		elif Input.is_action_just_pressed("attack"):
			state_machine.mainScene.get_node("CombatHUD/SkillBar").show_feedback("Selecione um inimigo ao alcance")

static func checkAnimationPlaying(state_machine : StateStrategy) -> void:
	if state_machine.statePlayer.ability_animation_time <= 0:
		state_machine.set_state(Idle.new())

static func checkRange(state_machine : StateStrategy) -> void:
	var player = state_machine.statePlayer
	var target = state_machine.statePlayer.charCurrentTarget
	if is_instance_valid(target) and target.charCurrentLife > 0:
		var distance = player.global_position.distance_to(target.global_position)
		
		if distance <= player.charRange:
			state_machine.animatedSprite.play("auto_attack")
		else:
			state_machine.set_state(Idle.new())
	else:
		state_machine.set_state(Idle.new())

