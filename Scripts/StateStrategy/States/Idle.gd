extends State
class_name Idle


func enter() -> void:
	state_machine.animatedSprite.play("idle")

func physics_process(_delta: float) -> void:
	StateHelper.checkMove(state_machine)
	StateHelper.checkCast(state_machine)
	StateHelper.checkAttack(state_machine)
