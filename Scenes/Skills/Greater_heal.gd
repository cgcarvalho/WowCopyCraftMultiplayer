
class_name GreaterHeal
extends Heal


const filePath : String = "res://Scenes/Skills/Greater_heal.tscn"
const iconFilePath : String = "res://Art/Skills/Heal icon.png"
const  heal = 20

func _init() -> void:
	skillScenePath = filePath
	skillBaseHeal = heal
	skillName = "Greater Heal"
