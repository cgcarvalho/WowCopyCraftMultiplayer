extends State
class_name Walk

func enter() -> void:
	state_machine.animatedSprite.play("walk")

func physics_process(delta: float) -> void:
	
	StateHelper.canMove(delta, state_machine, true)
	StateHelper.checkCast(state_machine)
	StateHelper.checkAttack(state_machine)
	
func exit() -> void:
	state_machine.animatedSprite.stop()
