
class_name Corruption
extends DamageOverTime
const filePath : String = "res://Scenes/Skills/Corrupiton.tscn"
const iconFilePath : String = "res://Art/Skills/Corruption Icon.png"
const  damage = 2
const dotSeconds = 10

func _init() -> void:
	skillScenePath = filePath
	skillBaseDamage = damage
	skillDotSeconds = dotSeconds
	skillName = "Corruption"
