
class_name GreaterHeal
extends Heal


const filePath : String = "res://Scenes/Skills/Greater_heal.tscn"
const  heal = 20

func _init() -> void:
	skillScenePath = filePath
	skillBaseHeal = heal
	skillName = "Greater Heal"
