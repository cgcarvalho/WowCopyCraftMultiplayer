extends TextureButton

@onready var player_cast_bar: Control = $"../../../../PlayerCastBar"
@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var timer: Timer = $Timer
@onready var time: Label = $Time
@onready var key: Label = $Key
var skillCast: Skill
var skillPlayer: Character
var skillHander
var pending = false
var target_id = 0
var changeKey = "":
	set(value):
		changeKey = value
		key.text = value
		shortcut = Shortcut.new()
		var events: Array[InputEvent] = []
		for code in ([KEY_R, KEY_4] if value == "R" else [value.unicode_at(0)]):
			for alt in [false, true]:
				var input_key = InputEventKey.new()
				input_key.keycode = code
				input_key.alt_pressed = alt
				events.append(input_key)
		shortcut.events = events

func _ready() -> void:
	skillHander = get_tree().current_scene.get_node("SkillHandler")
	skillHander.cast_confirmed.connect(on_cast_result)
	set_process(false)

func _process(_delta: float) -> void:
	if not is_instance_valid(skillCast) or not is_instance_valid(skillPlayer):
		set_process(false)
		return
	time.text = "%d" % ceili(timer.time_left)
	progress_bar.value = timer.time_left
	if skillCast.resetCoolDown:
		skillCast.resetCoolDown = false
		timer.stop()
		_on_timer_timeout()

func feedback(message: String) -> void:
	var bar = get_parent().get_parent().get_parent()
	bar.show_feedback(message)

func _on_pressed() -> void:
	if pending or not timer.is_stopped():
		return
	if validateCast():
		pending = true
		skillHander.loadSkillScene.rpc_id(1, skillCast.skillScenePath, int(skillPlayer.name), target_id)

func validateCast() -> bool:
	if skillPlayer.charCurrentLife <= 0 or player_cast_bar.is_casting:
		return false
	if skillPlayer.charCurrentMana < skillCast.skillManaCost:
		feedback("Mana insuficiente")
		return false
	var selected = skillPlayer.charCurrentTarget
	if skillCast.targeting() == Skill.TargetMode.ALLY and (Input.is_key_pressed(KEY_ALT) or not is_instance_valid(selected) or selected.charTeam != skillPlayer.charTeam):
		selected = skillPlayer
	target_id = int(selected.name) if is_instance_valid(selected) else 0
	var resolved = skillHander.selected_target(skillCast, skillPlayer, target_id)
	if not skillHander.valid_target(skillCast, skillPlayer, resolved):
		feedback("Selecione um inimigo vivo ao alcance" if skillCast.targeting() == Skill.TargetMode.ENEMY else "Alvo fora do alcance")
		return false
	return true

func on_cast_result(caster_id: int, path: String, accepted: bool, duration: float, cooldown: float) -> void:
	if not is_instance_valid(skillPlayer) or not is_instance_valid(skillCast):
		return
	if caster_id != int(skillPlayer.name) or path != skillCast.skillScenePath:
		return
	pending = false
	if not accepted:
		feedback("Habilidade indisponível")
		return
	progress_bar.max_value = cooldown
	timer.start(maxf(0.01, cooldown))
	# Keep hover/tooltips active; _on_pressed rejects requests while the timer runs.
	disabled = false
	set_process(true)
	if duration > 0:
		skillHander.castBar(skillCast.skillName, duration)

func _on_timer_timeout() -> void:
	disabled = false
	time.text = ""
	progress_bar.value = 0
	set_process(false)

func tooltip_label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 280
	return label

func _make_custom_tooltip(_for_text: String) -> Object:
	if not is_instance_valid(skillCast):
		return null
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color("16130f")
	style.border_color = Color("b68a45")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 14)
	panel.add_theme_stylebox_override("panel", style)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var gold = Color("f1cf84")
	var pale = Color("e6dfd2")
	column.add_child(tooltip_label(skillCast.skillName, 20, gold))
	column.add_child(tooltip_label(("ULTIMATE · " if skillCast.is_ultimate else "") + "Tecla " + ("R ou 4" if skillCast.is_ultimate else changeKey), 13, gold))
	column.add_child(tooltip_label(skillCast.description, 15, pale))
	var separator = HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(separator)
	column.add_child(tooltip_label("Mana: %d     Recarga: %.1f s" % [skillCast.skillManaCost, skillCast.skillCoolDownTime], 14, Color("9dc8f0")))
	column.add_child(tooltip_label("Conjuração: " + skillCast.cast_description(), 14, pale))
	if skillCast.targeting() != Skill.TargetMode.SELF:
		column.add_child(tooltip_label("Alcance: %d" % int(skillCast.cast_range), 14, pale))
	column.add_child(tooltip_label("Alvo: " + skillCast.target_description(), 13, Color("bcb29f")))
	return panel
