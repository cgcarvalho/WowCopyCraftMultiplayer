extends Node

class_name UIHandler

var mainNode : Node
var playerHP
var targetHP

func _init(main : Node) -> void:
	mainNode = main
	playerHP = mainNode.get_node("PlayerHP")
	targetHP = mainNode.get_node("TargetHP")

func showPlayerHPBar(player : Character) -> void:
		playerHP.visible = true
		playerHP.targetPlayer = player
			
func showTargetHPBar(player : Character) -> void:
		targetHP.visible = true
		targetHP.targetPlayer = player
	
func hideTargetHPBar() -> void:
		targetHP.visible = false
	
