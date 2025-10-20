class_name Charge
extends DeslocateAttack

const filePath : String = "res://Scenes/Skills/Charge/Charge.tscn"
const iconFilePath : String = "res://Art/Skills/Charge Icon.png"

const duration = 10
const coolDowntime = 2
const manaCost = 20
const damage = 5
const speed = 1500

func _init() -> void:
	skillScenePath = filePath
	skillCoolDownTime = coolDowntime
	skillBaseDamage = damage
	skillManaCost = manaCost
	skillName = "Charge"
	deslocateSpeed = speed
