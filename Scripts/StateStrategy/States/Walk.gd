extends State
class_name Walk

var velocity = Vector2.ZERO 
const speed = 400 


func enter() -> void:
	state_machine.animatedSprite.play("walk")

func physics_process(delta: float) -> void:
	velocity = Vector2.ZERO 
	
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
	
	if Input.is_key_pressed(KEY_NUMBERSIGN):
		state_machine.set_state(Cast.new())
		
	if velocity.length() == 0:
		state_machine.set_state(Idle.new())
		


func exit() -> void:
	state_machine.animatedSprite.stop()
