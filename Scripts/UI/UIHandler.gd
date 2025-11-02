extends Node

class_name UIHandler

var mainNode : Node
var playerHP
var targetHP
var skillBar
var buffList

func _init(main : Node) -> void:
	mainNode = main
	playerHP = mainNode.get_node("PlayerHP")
	targetHP = mainNode.get_node("TargetHP")
	skillBar = mainNode.get_node("SkillBar")
	buffList = mainNode.get_node("BuffList")

#region HP Bar
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
#endregion

func createSkillBar() -> void:
	skillBar.createButtons()

func createBuffs(skill : Skill) -> void:
	buffList.createBuff(skill)

func changeScene(path : String) -> Node:
	var map = mainNode.get_node("CurrentMap")
	if map.get_child_count() > 0:
		map.get_child(0).queue_free()
	var newScene = load(path).instantiate()
	map.add_child(newScene)
	
	return newScene
	
