extends Control

const buff = preload("res://Scenes/Components/Buff/Buff.tscn")

func createBuff(skill : Skill) -> void:
	var player : Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if player:
			
		var button = buff.instantiate()
		
		get_node("PanelContainer").get_node("HBoxContainer").add_child(button)
		
		button.texture_normal = load(skill.iconFilePath)
		button.timer.wait_time = skill.buffDuration			
