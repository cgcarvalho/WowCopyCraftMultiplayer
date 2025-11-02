extends State
class_name Cast

func enter() -> void:
	state_machine.animatedSprite.play("cast")

	
func physics_process(_delta: float) -> void:
	StateHelper.checkMove(state_machine)
	StateHelper.checkAnimationPlaying(state_machine)
		
func exit() -> void:
	pass
