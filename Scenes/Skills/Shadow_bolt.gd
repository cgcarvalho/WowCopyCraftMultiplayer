
class_name ShadowBolt
extends DirectDamege

const filePath : String = "res://Scenes/Skills/Shadow_bolt.tscn"
const  speed = 500

func _init() -> void:
	skillScenePath = filePath
	projectileSpeed = speed
