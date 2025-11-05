
class_name GreaterHeal
extends Heal


const filePath : String = "res://Scenes/Skills/Greater Heal/Greater_heal.tscn"
const iconFilePath : String = "res://Art/Skills/Heal icon.png"
const  heal = 20
const coolDowntime = 10
const manaCost = 20
const castTime = 2

func _init() -> void:
	skillScenePath = filePath
	skillBaseHeal = heal
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Greater Heal"
	skillCastTime = castTime
