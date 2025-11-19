class_name CurseOfDeath
extends DamageOverTime
const filePath : String = "res://Scenes/Skills/Curse of Death/CurseOfDeath.tscn"
const iconFilePath : String = "res://Art/Skills/Curse of Death Icon.png"
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
	skillName = "Curse of Death"
