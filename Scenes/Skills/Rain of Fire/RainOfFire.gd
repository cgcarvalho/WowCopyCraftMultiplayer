class_name RainOfFire
extends AreaDamage

const filePath : String = "res://Scenes/Skills/Rain of Fire/RainOfFire.tscn"
const iconFilePath : String = "res://Art/Skills/Rain of Fire Icon.png"

const duration = 10
const coolDowntime = 30
const manaCost = 20
const damage = 5

func _init() -> void:
	skillScenePath = filePath
	skillCoolDownTime = coolDowntime
	skillDuration = duration
	skillBaseDamage = damage
	skillManaCost = manaCost
	skillName = "Rain of Fire"
