extends State
class_name Cast

func enter() -> void:
	pass
	
func physics_process(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length() > 0:
		state_machine.set_state(Walk.new())
		
func exit() -> void:
	pass
