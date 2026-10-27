class_name SelectionSkill
extends HBoxContainer

var skill: Skill
var hotkey = ""

func configure(ability: Skill, key: String) -> void:
	skill = ability
	hotkey = key
	name = "Preview_Ultimate" if skill.is_ultimate else "Preview_" + key
	tooltip_text = skill.tooltip_summary(key)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(188, 32)
	add_theme_constant_override("separation", 8)
	var icon = TextureRect.new()
	icon.texture = load(skill.iconFilePath)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	var title = Label.new()
	title.text = ("R · " if skill.is_ultimate else key + " · ") + skill.skillName
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("d3b0ff") if skill.is_ultimate else Color.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

func _make_custom_tooltip(_for_text: String) -> Object:
	return SkillTooltip.create(skill, hotkey) if is_instance_valid(skill) else null
