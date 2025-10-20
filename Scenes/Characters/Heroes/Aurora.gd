
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
	skillList.append(ShadowBolt.new())
	skillList.append(Corruption.new())
	skillList.append(GreaterHeal.new())
	skillList.append(HolyShield.new())
	skillList.append(RainOfFire.new())
	#skillList.append(Might.new())
