
class_name ArrowAttack
extends DirectDamage

const filePath : String = "res://Scenes/Skills/ArrowAttack/ArrowAttack.tscn"
const iconFilePath : String = ""

const speed = 500
const damage = 5
const coolDowntime = 0
const manaCost = 0
const castTime = 0

func _init() -> void:
	skillScenePath = filePath
	projectileSpeed = speed
	skillBaseDamage = damage
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Arrow Attack"
	skillCastTime = castTime
