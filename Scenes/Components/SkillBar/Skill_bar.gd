extends Control

const skillButtonPath = preload("res://Scenes/Components/SkillButton/SkillButton.tscn")

func createButtons() -> void:
	var player : Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if player:
		var hotKey = 1
		for key in player.skillList.keys():
			var skill = player.skillList[key]
			var button = skillButtonPath.instantiate().duplicate()
			
			get_node("PanelContainer").get_node("HBoxContainer").add_child(button)
			
			button.tooltip_text = skill.skillName
			button.texture_normal = load(skill.iconFilePath)
			button.changeKey = str(hotKey)
			hotKey += 1
			

			
			
			
		
		

	
