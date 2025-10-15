
class_name Aurora
extends Character

	
var image_path = "res://Art/Chars/Aurora - Warlock/AuroraStand.png"
	
func _enter_tree() -> void:
	charName = "Aurora"
	charTotalLife = 100
	charCurrentLife = 100
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 2.0
	portraitImagePath = image_path
	
	addSkillsChar()
	

func addSkillsChar() -> void:
	var skill1 = ShadowBolt.new()
	skillList["skill_1"] = skill1
	
	var skill2 = Corruption.new()
	skillList["skill_2"] = skill2
	
	var skill3 = GreaterHeal.new()
	skillList["skill_3"] = skill3
	
	var skill4 = HolyShield.new()
	skillList["skill_4"] = skill4
	
