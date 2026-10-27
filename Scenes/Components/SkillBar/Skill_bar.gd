extends Control

const skillButtonPath = preload("res://Scenes/Components/SkillButton/SkillButton.tscn")
var message: Label
var message_remaining = 0.0

func createButtons() -> void:
	var player: Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if not is_instance_valid(player):
		return
	visible = true
	for child in $PanelContainer/HBoxContainer.get_children():
		$PanelContainer/HBoxContainer.remove_child(child)
		child.queue_free()
	var hotkey = 1
	for skill in player.skillList:
		var button = skillButtonPath.instantiate()
		button.skillPlayer = player
		button.skillCast = skill
		$PanelContainer/HBoxContainer.add_child(button)
		button.texture_normal = load(skill.iconFilePath)
		button.changeKey = "R" if skill.is_ultimate else str(hotkey)
		button.tooltip_text = skill.tooltip_summary("R / 4" if skill.is_ultimate else str(hotkey))
		hotkey += 1
	if message == null:
		message = Label.new()
		message.position = Vector2(0, -28)
		message.add_theme_font_size_override("font_size", 16)
		message.add_theme_color_override("font_color", Color("ffe299"))
		add_child(message)

func show_feedback(text: String) -> void:
	if message != null:
		message.text = text
		message_remaining = 2.5

func _process(delta: float) -> void:
	message_remaining -= delta
	if message != null and message_remaining <= 0:
		message.text = ""
