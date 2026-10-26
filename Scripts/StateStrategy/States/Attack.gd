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
	if is_instance_valid(target) and target.charCurrentLife > 0:
		state_machine.mainScene.get_node("SkillHandler").basic_attack.rpc_id(1, int(player.name), int(target.name))
		
func exit() -> void:
	state_machine.animatedSprite.stop()

