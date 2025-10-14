extends State
class_name Cast

var playerCast : Character
var skillHander : SKillHandler 

func enter() -> void:
	playerCast = state_machine.statePlayer
	skillHander = state_machine.mainScene.get_node("SkillHandler")


func physics_process(_delta: float) -> void:
	if Input.is_action_just_released("skill_1") and playerCast.charCurrentTarget:
		skillHander.loadSkillScene.rpc(playerCast.skillList["skill_1"].skillScenePath, int(playerCast.name), int(playerCast.charCurrentTarget.name))
	
	if Input.is_action_just_released("skill_2") and playerCast.charCurrentTarget:
		skillHander.loadSkillScene.rpc(playerCast.skillList["skill_2"].skillScenePath, int(playerCast.name), int(playerCast.charCurrentTarget.name))
	
	if Input.is_action_just_released("skill_3") and playerCast.charCurrentTarget:
		skillHander.loadSkillScene.rpc(playerCast.skillList["skill_3"].skillScenePath, int(playerCast.name), int(playerCast.charCurrentTarget.name))
	
	if Input.is_action_just_released("skill_4") and playerCast.charCurrentTarget:
		skillHander.loadSkillScene.rpc(playerCast.skillList["skill_4"].skillScenePath, int(playerCast.name), int(playerCast.charCurrentTarget.name))
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length() > 0:
		state_machine.set_state(Walk.new())
		
func exit() -> void:
	pass
