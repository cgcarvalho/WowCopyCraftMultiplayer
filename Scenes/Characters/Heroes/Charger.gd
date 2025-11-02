
class_name Charger
extends Character

	
var image_path = "res://Art/Chars/Charger/Charger.png"
var scene_path = "res://Scenes/Characters/Heroes/Charger.tscn"

func _enter_tree() -> void:
	charName = "Charger"
	charTotalLife = 100
	charCurrentLife = 100
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 2.0
	portraitImagePath = image_path
	scenePath = scene_path

	addSkillsChar()
	

func addSkillsChar() -> void:
	skillList.append(Consecration.new())
	skillList.append(GreaterHeal.new())
	
