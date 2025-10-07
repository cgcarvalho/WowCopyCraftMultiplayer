extends Node

class_name SKillHandler


var currentSkill: Skill
var animatedSprite : AnimatedSprite2D
var mainScene : Node
var playerCaster : Character


func _init(path : String, main : Node, player : Character) -> void:
	mainScene = main
	playerCaster = player
	loadSkillScene(path)
	


func _physics_process(delta: float) -> void:
	if currentSkill:
		currentSkill.physics_process(delta)



func loadSkillScene(filePath : String) -> void:
	var loadSkill : Skill = load(filePath).instantiate().duplicate()
	currentSkill = loadSkill
	currentSkill.skill_handler = self
	currentSkill.z_index = 5
	animatedSprite = loadSkill.get_node("AnimatedSprite2D")
	mainScene.add_child(loadSkill)
	currentSkill.enter()
	
	
