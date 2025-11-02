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
	
	state_machine.statePlayer.position += velocity * delta
	
	if velocity.length() == 0 and checkIdle:
		state_machine.set_state(Idle.new())

static func checkMove(state_machine : StateStrategy) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0:
		state_machine.set_state(Walk.new())
		
static func checkCast(state_machine : StateStrategy) -> void:
	if (Input.is_action_pressed("skill_1") or 
		Input.is_action_pressed("skill_2") or 
		Input.is_action_pressed("skill_3") or  
		Input.is_action_pressed("skill_4")):
		
		state_machine.set_state(Cast.new())

static func checkAttack(state_machine : StateStrategy) -> void:
	if Input.is_action_pressed("attack"):
		state_machine.set_state(Attack.new())

static func checkAnimationPlaying(state_machine : StateStrategy) -> void:
	if not state_machine.animatedSprite.is_playing():
		state_machine.set_state(Idle.new())

static func checkRange(state_machine : StateStrategy) -> void:
	var player = state_machine.statePlayer
	var target = state_machine.statePlayer.charCurrentTarget
	if target:
		var distance = player.global_position.distance_to(target.global_position)
		
		if not state_machine.animatedSprite.flip_h:
			distance -= 200
		
		print(distance)
		if distance <= player.charRange:
			state_machine.animatedSprite.play("auto_attack")
		else:
			state_machine.set_state(Idle.new())
