

class_name SKillHandler extends Node

@rpc("any_peer", "call_local")
func loadSkillScene(filePath : String, idCasterChar : int, idTargetChar : int) -> void:
	var loadSkill : Skill = load(filePath).instantiate()
	var target_player = MultiplayerManager.playerList.get(idTargetChar)
	var caster_player = MultiplayerManager.playerList.get(idCasterChar)
	
	caster_player.charCurrentMana -= loadSkill.skillManaCost
	get_parent().add_child(loadSkill)
	loadSkill.cast(caster_player, target_player)
