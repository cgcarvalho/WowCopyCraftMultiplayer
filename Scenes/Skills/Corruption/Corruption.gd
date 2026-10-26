
class_name Corruption
extends DamageOverTime
const filePath : String = "res://Scenes/Skills/Corruption/Corruption.tscn"
const iconFilePath : String = "res://Art/Skills/Corruption Icon.png"
const  damage = 2
const dotSeconds = 10
const coolDowntime = 2
const manaCost = 5

func _init() -> void:
	description = "Aplica 2 de dano/s por 10s. Reaplicar renova o efeito."
	skillScenePath = filePath
	skillBaseDamage = damage
	skillDotSeconds = dotSeconds
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Corruption"
