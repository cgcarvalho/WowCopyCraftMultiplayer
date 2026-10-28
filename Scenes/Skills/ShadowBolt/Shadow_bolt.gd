
class_name ShadowBolt
extends DirectDamage

const filePath : String = "res://Scenes/Skills/ShadowBolt/Shadow_bolt.tscn"
const iconFilePath : String = "res://Art/Skills/Shadowbolt Icon.png"

const speed = 500
const damage = 10
const coolDowntime = 4
const manaCost = 10
const castTime = 1

func _init() -> void:
	description = "Projétil sombrio: 10 de dano. Dot Master pode liberar um lançamento instantâneo."
	skillScenePath = filePath
	projectileSpeed = speed
	skillBaseDamage = damage
	skillCoolDownTime = coolDowntime
	skillManaCost = manaCost
	skillName = "Shadow Bolt"
	skillCastTime = castTime
