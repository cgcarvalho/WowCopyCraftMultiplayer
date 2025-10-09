
class_name ShadowBolt
extends DirectDamage

const filePath : String = "res://Scenes/Skills/Shadow_bolt.tscn"
const  speed = 500
const  damage = 10

func _init() -> void:
	skillScenePath = filePath
	projectileSpeed = speed
	skillBaseDamage = damage
	skillName = "Shadow Bolt"
