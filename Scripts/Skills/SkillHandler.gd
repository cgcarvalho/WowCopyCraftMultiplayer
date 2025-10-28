

class_name SKillHandler extends Node

@rpc("any_peer", "call_local")
func loadSkillScene(filePath : String, idCasterChar : int, idTargetChar : int) -> void:
	var loadSkill : Skill = load(filePath).instantiate()
	var target_player : Character = MultiplayerManager.playerList.get(idTargetChar)
	var caster_player : Character = MultiplayerManager.playerList.get(idCasterChar)
	
	caster_player.charCurrentMana -= loadSkill.skillManaCost
	
	checkPassive(loadSkill, caster_player)

	get_parent().add_child(loadSkill)
	loadSkill.cast(caster_player, target_player)


func checkPassive(skill : Skill, caster : Character) -> void:
	if skill is DamageOverTime:
		if caster.passiveSkill and (caster.passiveSkill is DotMaster):
			skill.onDamage.connect(caster.passiveSkill.on_proc)
		
		
