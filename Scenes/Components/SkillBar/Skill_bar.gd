extends Control

const skillButtonPath = preload("res://Scenes/Components/SkillButton/SkillButton.tscn")
var message: Label
var message_remaining = 0.0
const INPUT_WINDOW = 0.2
var queued_button: Control
var queued_target_id = 0
var queued_selection: Character
var queue_deadline_msec = 0

func _ready() -> void:
	get_parent().get_parent().get_node("SkillHandler").combat_reset.connect(clear_buffer)

func selection_unchanged(hero: Character) -> bool:
	if not is_instance_valid(queued_selection):
		return not is_instance_valid(hero.charCurrentTarget)
	return is_instance_valid(hero.charCurrentTarget) and hero.charCurrentTarget == queued_selection

func clear_buffer() -> void:
	if is_instance_valid(queued_button):
		queued_button.set_queued(false)
	queued_button = null
	queued_selection = null

func buffer_action(button: Control) -> bool:
	clear_buffer()
	if button.pending or button.busy_seconds() > INPUT_WINDOW or not button.can_request(true):
		return false
	queued_button = button
	queued_target_id = button.target_id
	queued_selection = button.skillPlayer.charCurrentTarget
	# Brief scheduling grace lets timer timeout callbacks finish first.
	queue_deadline_msec = Time.get_ticks_msec() + roundi((INPUT_WINDOW + 0.05) * 1000)
	button.set_queued(true)
	return true

func advance_buffer() -> void:
	if not is_instance_valid(queued_button):
		clear_buffer()
		return
	var button = queued_button
	var hero = button.skillPlayer
	if not is_instance_valid(hero) or hero.charCurrentLife <= 0 or hero.spectator or button.pending or button.skillHander.encounter_finished() or Time.get_ticks_msec() > queue_deadline_msec or not selection_unchanged(hero):
		clear_buffer()
		return
	if button.is_busy():
		return
	var target = queued_target_id
	clear_buffer()
	button.execute_request(target)

func createButtons() -> void:
	clear_buffer()
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
	advance_buffer()
	message_remaining -= delta
	if message != null and message_remaining <= 0:
		message.text = ""
