

class_name SKillHandler extends Node

@rpc("any_peer", "call_local")
func loadSkillScene(filePath : String, startPosition : Vector2, idTargetChar : int) -> void:
	var loadSkill : Skill = load(filePath).instantiate()
	var target_player = MultiplayerManager.playerList.get(idTargetChar)
	
	get_parent().add_child(loadSkill)
	loadSkill.cast(startPosition, target_player)
