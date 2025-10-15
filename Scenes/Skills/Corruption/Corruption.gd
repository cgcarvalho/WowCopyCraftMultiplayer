
class_name Corruption
extends DamageOverTime
const filePath : String = "res://Scenes/Skills/Corruption/Corruption.tscn"
const iconFilePath : String = "res://Art/Skills/Corruption Icon.png"
const  damage = 2
const dotSeconds = 10
const coolDowntime = 2
const manaCost = 5

func _init() -> void:
	skillScenePath = filePath
	skillBaseDamage = damage
	skillDotSeconds = dotSeconds
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Corruption"
