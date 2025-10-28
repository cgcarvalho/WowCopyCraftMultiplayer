class_name DotMaster
extends PassiveSkill

var procChance : float = 0.05

func _init(chararcater: Character) -> void:
	casterCharacter = chararcater


func on_proc() -> void:
	var chance = randf()
	
	if procChance >= chance:
		var list = casterCharacter.skillList.filter(func(element): return element is ShadowBolt)
		if len(list) > 0:
			var skill = list[0]
			skill.resetCoolDown = true


func physics_process(_delta: float) -> void:
	pass
