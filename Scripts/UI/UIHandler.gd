extends Node

class_name UIHandler

var mainNode : Node
var playerHP
var targetHP
var skillBar

func _init(main : Node) -> void:
	mainNode = main
	playerHP = mainNode.get_node("PlayerHP")
	targetHP = mainNode.get_node("TargetHP")
	skillBar = mainNode.get_node("SkillBar")

func showPlayerHPBar(player : Character, targetSelf : bool) -> void:
		playerHP.visible = true
		playerHP.targetSelf = targetSelf
		playerHP.targetPlayer = player
			
func showTargetHPBar(player : Character, targetSelf : bool) -> void:
		targetHP.visible = true
		targetHP.targetSelf = targetSelf
		targetHP.targetPlayer = player
	
func hideTargetHPBar() -> void:
		targetHP.visible = false
	

func createSkillBar() -> void:
	skillBar.createButtons()
