
class_name SirGura
extends Character

var image_path = "res://Art/Chars/Sir Gura Targao/stand.png"
	
func _enter_tree() -> void:
	charName = "Sir Gura"
	charTotalLife = 100
	charCurrentLife = 100
	portraitImagePath = image_path
	
	addSkillsChar()
	

func addSkillsChar() -> void:
	var skill1 = ShadowBolt.new()
	skillList["skill_1"] = skill1
	
	var skill2 = Corruption.new()
	skillList["skill_2"] = skill2
	
	var skill3 = GreaterHeal.new()
	skillList["skill_3"] = skill3
	
