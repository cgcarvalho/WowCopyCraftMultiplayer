extends State
class_name Cast

var skillHandler : SKillHandler

var playerCast : Character

func enter() -> void:
	playerCast = state_machine.statePlayer
	

func physics_process(delta: float) -> void:
	if Input.is_action_just_released("skill_1") and playerCast.charCurrentTarget:
		var skill = playerCast.skillList["skill_1"]
		skillHandler = SKillHandler.new(skill.skillScenePath, state_machine.mainScene, playerCast)
		
	if Input.is_action_just_released("skill_2") and playerCast.charCurrentTarget:
		skillHandler.skillCast = playerCast.skillList["skill_2"]
	if Input.is_action_just_released("skill_3") and playerCast.charCurrentTarget:
		skillHandler.skillCast = playerCast.skillList["skill_3"]
	if Input.is_action_just_released("skill_4") and playerCast.charCurrentTarget:
		skillHandler.skillCast = playerCast.skillList["skill_4"]
	
	if skillHandler:
		skillHandler._physics_process(delta)
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length() > 0:
		state_machine.set_state(Walk.new())

		
func exit() -> void:
	pass
