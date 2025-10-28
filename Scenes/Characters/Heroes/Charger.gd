
class_name Charger
extends Character

	
var image_path = "res://Art/Chars/Charger/Charger.png"
	
func _enter_tree() -> void:
	charName = "Charger"
	charTotalLife = 100
	charCurrentLife = 100
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 2.0
	portraitImagePath = image_path
	
	addSkillsChar()
	

func addSkillsChar() -> void:
	skillList.append(Consecration.new())
	skillList.append(GreaterHeal.new())
	
