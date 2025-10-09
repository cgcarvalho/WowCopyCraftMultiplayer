extends Node

class_name UIHandler

var mainNode : Node
var teamHP

func _init(main : Node) -> void:
	mainNode = main
	teamHP = mainNode.get_node("TeamHP")
	
func showHPBar(player : Character) -> void:
	teamHP.visible = true
	teamHP.targetPlayer = player
	
func hideHPBar() -> void:
	teamHP.visible = false
	
