class_name DotMaster
extends PassiveSkill

var procChance : float = ClassPassives.DOT_CHANCE

func _init(chararcater: Character) -> void:
	casterCharacter = chararcater


func on_proc() -> void:
	if not is_instance_valid(casterCharacter) or not casterCharacter.multiplayer.is_server() or casterCharacter.charCurrentLife <= 0 or casterCharacter.spectator:
		return
	var handler = casterCharacter.get_tree().current_scene.get_node("SkillHandler")
	if handler.encounter_finished():
		return
	var chance = randf()
	
	if procChance >= chance:
		var list = casterCharacter.skillList.filter(func(element): return element is ShadowBolt)
		if len(list) > 0:
			var skill : Skill = list[0]
			skill.resetCoolDown = true
			skill.resetCastTime = true
			casterCharacter.shadow_bolt_ready = true
			var owner_id = int(casterCharacter.name)
			handler.proc_ready[owner_id] = skill.skillScenePath
			if owner_id != 1:
				handler.reset_skill.rpc_id(owner_id, skill.skillScenePath, owner_id)


func physics_process(_delta: float) -> void:
	pass

