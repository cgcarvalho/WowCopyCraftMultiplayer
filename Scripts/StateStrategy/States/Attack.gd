extends State
class_name Attack
	
func enter() -> void:
	state_machine.animatedSprite.animation_looped.connect(dealDamage)
	
	
func physics_process(_delta: float) -> void:
	StateHelper.canMove(_delta, state_machine, false)
	StateHelper.checkCast(state_machine)
	StateHelper.checkRange(state_machine)

func dealDamage():
	var player : Character = state_machine.statePlayer
	var target : Character = state_machine.statePlayer.charCurrentTarget
	target.deal_damage(player.charBaseDamage)
		
func exit() -> void:
	state_machine.animatedSprite.stop()
