class_name SkillTooltip
extends RefCounted

static func text_line(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 280
	return label

static func create(skill: Skill, hotkey: String) -> PanelContainer:
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
	column.add_child(text_line(skill.skillName, 20, gold))
	column.add_child(text_line(("ULTIMATE · " if skill.is_ultimate else "") + "Tecla " + ("R ou 4" if skill.is_ultimate else hotkey), 13, gold))
	column.add_child(text_line(skill.description, 15, pale))
	if skill is ShadowBolt and skill.resetCastTime:
		column.add_child(text_line("DOT MASTER PRONTO · Próximo lançamento instantâneo, mesmo em recarga. Mantém o custo de mana.", 14, Color("a5edbd")))
	if not skill.talent_description.is_empty():
		column.add_child(text_line(skill.talent_description.strip_edges(), 14, Color("a5dbb4")))
	var separator = HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(separator)
	column.add_child(text_line("%s: %d     Recarga: %.1f s" % [skill.cost_label, skill.skillManaCost, skill.skillCoolDownTime * skill.cooldown_scale], 14, Color("9dc8f0")))
	column.add_child(text_line("Conjuração: " + skill.cast_description(), 14, pale))
	if skill.skillCastTime > 0:
		column.add_child(text_line("Mover interrompe a conjuração.", 13, Color("bcb29f")))
	if skill.targeting() != Skill.TargetMode.SELF:
		column.add_child(text_line("Alcance: %d" % int(skill.cast_range), 14, pale))
	column.add_child(text_line("Alvo: " + skill.target_description(), 13, Color("bcb29f")))
	return panel
