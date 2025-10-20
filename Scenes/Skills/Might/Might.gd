#extends StaticBody2D

class_name Might
extends Buff

const filePath : String = "res://Scenes/Skills/Might/Might.tscn"
const iconFilePath : String = "res://Art/Buffs/Might.png"

const  shield = 20
const coolDowntime = 2
const manaCost = 10
const duration = 10

func _init() -> void:
	skillScenePath = filePath
	skillCoolDownTime = coolDowntime
	buffDuration = duration
	skillManaCost = manaCost
	skillName = "Might"
