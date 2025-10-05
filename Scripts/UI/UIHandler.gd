extends Node

class_name UIHandler

var mainNode : Node
var teamHP

func _init(main : Node) -> void:
	mainNode = main
	teamHP = mainNode.get_node("TeamHP")
	

func showHPBar(totalLife : int, currentLife : int, portraitPath : String) -> void:
	teamHP.visible = true
	teamHP.show(totalLife, currentLife, portraitPath)
	
func hideHPBar() -> void:
	teamHP.visible = false
	
