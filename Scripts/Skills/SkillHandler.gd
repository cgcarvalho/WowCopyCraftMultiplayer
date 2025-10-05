extends Node

class_name SKillHandler

var skillCast : Skill
var mainScene : Node
var playerCaster : Character
var playerTarget : Character
var hold : bool = true
var scenePath : String

func _init(main : Node, caster: Character, target : Character, skill : Skill) -> void:
	pass


func loadScene() -> void:
	var loadSkill = load(scenePath).instantiate().duplicate()
	mainScene.add_child(loadSkill)


func cast(caster : Vector2, target : Vector2):
	if target != null:
		#scale = Vector2(0.2, 0.2)
		#$AnimatedSprite2D.z_index = 1
		#$AnimatedSprite2D.play()
		#skillCaster = caster
		#skillTarget = target
