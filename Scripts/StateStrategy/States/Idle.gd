extends State
class_name Idle


func enter() -> void:
	state_machine.animatedSprite.play("idle")

func physics_process(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input_key = Input.get_vector("skill_1", "skill_2", "skill_3", "skill_4")
	if input_dir.length() > 0:
		state_machine.set_state(Walk.new())
	elif input_key.length() > 0:
		state_machine.set_state(Cast.new())
