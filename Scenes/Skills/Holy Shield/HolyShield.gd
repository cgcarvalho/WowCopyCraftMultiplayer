
class_name HolyShield
extends Shield

const filePath : String = "res://Scenes/Skills/Holy Shield/HolyShield.tscn"
const iconFilePath : String = "res://Art/Skills/Holy Shield Icon.png"

const  shield = 20
const coolDowntime = 20
const manaCost = 10

func _init() -> void:
	skillScenePath = filePath
	skillBaseShield = shield
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Holy Shield"
