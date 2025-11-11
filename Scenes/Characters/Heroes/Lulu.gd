
class_name Lulu
extends Character

var image_path = "res://Art/Chars/Lulu - Hunter/Lulu Stand.png"
var scene_path = "res://Scenes/Characters/Heroes/Lulu.tscn"

func _enter_tree() -> void:
	charName = "Lulu"
	charTotalLife = 100
	charCurrentLife = 100
	portraitImagePath = image_path
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 2.0
	scenePath = scene_path
	charBaseDamage = 5
	charRange = Constants.DEFAULT_RANGE_CASTER
	
	addSkillsChar()
	

func addSkillsChar() -> void:
	skillList.append(Charge.new())
	skillList.append(Corruption.new())
	skillList.append(GreaterHeal.new())
	skillList.append(HolyShield.new())
	skillList.append(RainOfFire.new())
