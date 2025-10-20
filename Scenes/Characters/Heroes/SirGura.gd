
class_name SirGura
extends Character

var image_path = "res://Art/Chars/Sir Gura Targao/stand.png"
	
func _enter_tree() -> void:
	charName = "Sir Gura"
	charTotalLife = 100
	charCurrentLife = 100
	portraitImagePath = image_path
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 2.0
	
	addSkillsChar()
	

func addSkillsChar() -> void:
	skillList.append(Charge.new())
	skillList.append(Corruption.new())
	skillList.append(GreaterHeal.new())
	skillList.append(HolyShield.new())
	skillList.append(RainOfFire.new())
