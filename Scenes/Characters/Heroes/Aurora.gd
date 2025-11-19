
class_name Aurora
extends Character

	
var image_path = "res://Art/Chars/Aurora - Warlock/AuroraStand.png"
var scene_path = "res://Scenes/Characters/Heroes/Aurora.tscn"
	
func _enter_tree() -> void:
	charName = "Aurora"
	charTotalLife = 100
	charCurrentLife = 100
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 2.0
	portraitImagePath = image_path
	scenePath = scene_path
	
	addSkillsChar()
	

func addSkillsChar() -> void:
	skillList.append(ShadowBolt.new())
	skillList.append(Corruption.new())
	skillList.append(CurseOfDeath.new())
	
	passiveSkill = DotMaster.new(self)
