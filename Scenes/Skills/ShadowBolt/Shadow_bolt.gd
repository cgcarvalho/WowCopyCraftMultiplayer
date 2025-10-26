
class_name ShadowBolt
extends DirectDamage

const filePath : String = "res://Scenes/Skills/ShadowBolt/Shadow_bolt.tscn"
const iconFilePath : String = "res://Art/Skills/Shadowbolt Icon.png"

const  speed = 500
const  damage = 10
const  coolDowntime = 20#1.5
const manaCost = 10

func _init() -> void:
	skillScenePath = filePath
	projectileSpeed = speed
	skillBaseDamage = damage
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Shadow Bolt"
