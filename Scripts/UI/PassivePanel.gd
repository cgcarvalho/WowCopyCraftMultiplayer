class_name PassivePanel
extends PanelContainer

var hero: Character
var selection = false
var title: Label
var detail: Label
var progress: ProgressBar

func configure(character: Character, in_selection: bool = false) -> void:
	for child in get_children():
		child.free()
	hero = character
	selection = in_selection
	custom_minimum_size.y = 90 if selection else 0
	name = "Passive_" + character.charClass
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color("191d27")
	style.border_color = Color("806d45")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		style.set_content_margin(side, 8)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 5)
	add_theme_stylebox_override("panel", style)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	title = make_label(13, Color("f1cf84"))
	column.add_child(title)
	detail = make_label(13, Color("e6dfd2"))
	column.add_child(detail)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 3
	progress.show_percentage = false
	progress.max_value = 1
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.visible = not selection
	column.add_child(progress)
	set_process(not selection)
	refresh()

func make_label(size: int, color: Color) -> Label:
	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func refresh() -> void:
	if not is_instance_valid(hero):
		return
	var info = ClassPassives.definition(hero.charClass, hero.talents)
	title.text = "PASSIVA · " + info.name
	tooltip_text = info.name + "\n" + info.description + "\nAtivação automática · sem tecla própria"
	if selection:
		detail.text = info.summary
	else:
		var status = ClassPassives.state(hero)
		detail.text = status.text
		detail.add_theme_color_override("font_color", Color("a5edbd") if status.active else Color("d0c6b6"))
		progress.value = status.value

func _process(_delta: float) -> void:
	refresh()

func _make_custom_tooltip(_for_text: String) -> Object:
	if not is_instance_valid(hero):
		return null
	var info = ClassPassives.definition(hero.charClass, hero.talents)
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = get_theme_stylebox("panel").duplicate()
	style.border_color = Color("b68a45")
	style.set_border_width_all(2)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 14)
	panel.add_theme_stylebox_override("panel", style)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(SkillTooltip.text_line("PASSIVA · " + info.name, 20, Color("f1cf84")))
	column.add_child(SkillTooltip.text_line(info.description, 15, Color("e6dfd2")))
	column.add_child(SkillTooltip.text_line("Ativação automática · sem tecla própria", 13, Color("9dc8f0")))
	if not selection:
		column.add_child(SkillTooltip.text_line(ClassPassives.state(hero).text, 14, Color("a5edbd")))
	return panel
