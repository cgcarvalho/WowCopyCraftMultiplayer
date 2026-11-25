extends CanvasLayer

signal playerSelected

const ROLES = {
	"Warlock": "Sombras, maldições e explosão de DoTs",
	"Warrior": "Combate corpo a corpo e resistência",
	"Paladin": "Cura, proteção e áreas sagradas",
	"Hunter": "Flechas à distância, veneno e ataques em área",
	"Engineer": "Rebites, dispositivos e dano em área",
	"DualWarrior": "Duas espadas, combos e contra-ataques"
}
var charList: Array[Character] = []
var portraits: Array[Texture2D] = []
var selected_index = 0
var confirmed = false
var margin: MarginContainer
var content: VBoxContainer
var carousel: HBoxContainer
var previous_button: Button
var next_button: Button
var neighbor_buttons: Array[Button] = []
var neighbor_portraits: Array[TextureRect] = []
var neighbor_names: Array[Label] = []
var neighbor_classes: Array[Label] = []
var portrait: TextureRect
var hero_name: Label
var hero_class: Label
var hero_role: Label
var count_label: Label
var quick_select: GridContainer
var quick_buttons: Array[Button] = []
var detail_pages: Array[HBoxContainer] = []
var passive_panels: Array[PassivePanel] = []
var skill_grids: Array[GridContainer] = []
var play_button: Button
var title: Label
var footer_hint: Label
var portrait_tween: Tween

func text_label(text: String, font_size: int, color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func panel_style(color: Color, padding: int = 12) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("5f6685")
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style

func navigation_button(text: String, description: String) -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = description
	# The carousel has its own keyboard navigation; Enter always confirms.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", panel_style(Color("1b2435"), 8))
	var highlighted = panel_style(Color("30333d"), 8)
	highlighted.border_color = Color("dfbd77")
	button.add_theme_stylebox_override("hover", highlighted)
	button.add_theme_stylebox_override("pressed", highlighted)
	return button

func portrait_texture(character: Character) -> Texture2D:
	var source: Texture2D = load(character.portraitImagePath)
	var image = source.get_image()
	if image == null or image.is_empty():
		return source
	var used = image.get_used_rect()
	if not used.has_area():
		return source
	var cropped = AtlasTexture.new()
	cropped.atlas = source
	cropped.region = used
	cropped.filter_clip = true
	return cropped

func make_portrait() -> TextureRect:
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func neighbor_card(direction: int) -> Button:
	var button = navigation_button("", "Personagem anterior" if direction < 0 else "Próximo personagem")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.size_flags_stretch_ratio = 1
	button.pressed.connect(func(): navigate(direction))
	carousel.add_child(button)
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 12
	box.offset_right = -12
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	button.add_child(box)
	var image = make_portrait()
	image.modulate = Color(0.8, 0.83, 0.9, 0.62)
	box.add_child(image)
	var name_label = text_label("", 20, Color("d2d7e1"))
	box.add_child(name_label)
	var class_label = text_label("", 14, Color("adb8cd"))
	box.add_child(class_label)
	neighbor_buttons.append(button)
	neighbor_portraits.append(image)
	neighbor_names.append(name_label)
	neighbor_classes.append(class_label)
	return button

func build_details(host: Container, character: Character) -> void:
	var page = HBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	page.visible = false
	host.add_child(page)
	detail_pages.append(page)
	var passive = PassivePanel.new()
	passive.configure(character, true)
	passive.custom_minimum_size.x = 280
	passive.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(passive)
	passive_panels.append(passive)
	var skills = VBoxContainer.new()
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills.size_flags_stretch_ratio = 2
	skills.add_theme_constant_override("separation", 8)
	page.add_child(skills)
	var heading = text_label("HABILIDADES · " + character.resource_name, 14, Color("ffe299"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skills.add_child(heading)
	var grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	skills.add_child(grid)
	skill_grids.append(grid)
	for index in character.skillList.size():
		var skill = character.skillList[index]
		var preview = SelectionSkill.new()
		preview.configure(skill, "R / 4" if skill.is_ultimate else str(index + 1))
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(preview)

func _ready() -> void:
	charList = [Aurora.new(), SirGura.new(), DualWieldWarrior.new(), Charger.new(), Lulu.new(), Engineer.new()]
	for character in charList:
		character._enter_tree()
		portraits.append(portrait_texture(character))
	var backdrop = ColorRect.new()
	backdrop.color = Color("101521")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Screen.add_child(backdrop)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Screen.add_child(margin)
	content = VBoxContainer.new()
	margin.add_child(content)
	title = text_label("ESCOLHA SEU PERSONAGEM", 26, Color("ffe299"))
	content.add_child(title)
	carousel = HBoxContainer.new()
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(carousel)
	previous_button = navigation_button("‹", "Anterior · seta esquerda ou A")
	previous_button.custom_minimum_size = Vector2(44, 52)
	previous_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	previous_button.add_theme_font_size_override("font_size", 34)
	previous_button.pressed.connect(func(): navigate(-1))
	carousel.add_child(previous_button)
	neighbor_card(-1)
	var selected_panel = PanelContainer.new()
	selected_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_panel.size_flags_stretch_ratio = 2.2
	var selected_style = panel_style(Color("172032"))
	selected_style.border_color = Color("ac905b")
	selected_panel.add_theme_stylebox_override("panel", selected_style)
	carousel.add_child(selected_panel)
	var selected = VBoxContainer.new()
	selected.add_theme_constant_override("separation", 6)
	selected_panel.add_child(selected)
	portrait = make_portrait()
	selected.add_child(portrait)
	hero_name = text_label("", 28, Color("ffe299"))
	selected.add_child(hero_name)
	hero_class = text_label("", 18, Color("e1c18b"))
	selected.add_child(hero_class)
	hero_role = text_label("", 14, Color("bdc7dc"))
	selected.add_child(hero_role)
	neighbor_card(1)
	next_button = navigation_button("›", "Próximo · seta direita ou D")
	next_button.custom_minimum_size = Vector2(44, 52)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.add_theme_font_size_override("font_size", 34)
	next_button.pressed.connect(func(): navigate(1))
	carousel.add_child(next_button)
	var shortcuts = HBoxContainer.new()
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcuts.add_theme_constant_override("separation", 12)
	content.add_child(shortcuts)
	quick_select = GridContainer.new()
	quick_select.add_theme_constant_override("h_separation", 6)
	quick_select.add_theme_constant_override("v_separation", 6)
	shortcuts.add_child(quick_select)
	for index in charList.size():
		var button = navigation_button(charList[index].charName, "Ver " + charList[index].charName)
		button.toggle_mode = true
		button.pressed.connect(func(): show_character(index))
		quick_select.add_child(button)
		quick_buttons.append(button)
	count_label = text_label("", 14, Color("bdc7dc"))
	count_label.custom_minimum_size.x = 48
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shortcuts.add_child(count_label)
	content.add_child(HSeparator.new())
	var details = MarginContainer.new()
	content.add_child(details)
	for character in charList:
		build_details(details, character)
	content.add_child(HSeparator.new())
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	content.add_child(footer)
	footer_hint = text_label("← / → ou A / D: navegar · Enter: jogar\nPasse o mouse na passiva e nas habilidades para ver os detalhes.", 14, Color("bdc7dc"))
	footer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(footer_hint)
	play_button = Button.new()
	play_button.custom_minimum_size = Vector2(250, 48)
	play_button.add_theme_font_size_override("font_size", 18)
	var play_style = panel_style(Color("5c4930"))
	play_style.border_color = Color("dfbd77")
	play_button.add_theme_stylebox_override("normal", play_style)
	play_button.pressed.connect(choose_character)
	footer.add_child(play_button)
	get_viewport().size_changed.connect(layout_carousel)
	layout_carousel()
	show_character(0, false)
	call_deferred("focus_play_button")

func focus_play_button() -> void:
	if is_inside_tree() and not is_queued_for_deletion() and not confirmed:
		play_button.grab_focus()

func layout_carousel() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = get_window().size
	var compact = window_size.y < 620 or window_size.x < 1000
	var padding = 12 if compact else 16
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	content.add_theme_constant_override("separation", 8 if compact else 10)
	carousel.add_theme_constant_override("separation", 8 if compact else 16)
	title.add_theme_font_size_override("font_size", 22 if compact else 26)
	hero_name.add_theme_font_size_override("font_size", 24 if compact else 28)
	hero_class.add_theme_font_size_override("font_size", 16 if compact else 18)
	portrait.custom_minimum_size.y = 96 if compact else 160
	quick_select.columns = 6 if viewport_size.x >= 720 else 3
	for grid in skill_grids:
		grid.columns = 4 if viewport_size.x >= 1100 else 2
	for index in neighbor_buttons.size():
		neighbor_buttons[index].custom_minimum_size = Vector2(100 if compact else 150, 136 if compact else 190)
		neighbor_names[index].add_theme_font_size_override("font_size", 16 if compact else 20)
		neighbor_classes[index].visible = not compact
	for passive in passive_panels:
		passive.custom_minimum_size.x = 230 if compact else 280
	footer_hint.add_theme_font_size_override("font_size", 13 if compact else 14)
	play_button.custom_minimum_size.x = 210 if compact else 250

func current_character() -> Character:
	return charList[selected_index]

func show_character(index: int, animate: bool = true) -> void:
	if confirmed or charList.is_empty():
		return
	selected_index = posmod(index, charList.size())
	var character = current_character()
	portrait.texture = portraits[selected_index]
	hero_name.text = character.charName
	hero_class.text = "Engenheiro de Campo" if character is Engineer else ClassPassives.class_label(character.charClass)
	hero_role.text = ROLES[character.charClass]
	play_button.text = "Jogar com " + character.charName
	count_label.text = "%d / %d" % [selected_index + 1, charList.size()]
	for side in 2:
		var neighbor = posmod(selected_index + (-1 if side == 0 else 1), charList.size())
		neighbor_portraits[side].texture = portraits[neighbor]
		neighbor_names[side].text = charList[neighbor].charName
		neighbor_classes[side].text = "Engenheiro de Campo" if charList[neighbor] is Engineer else ClassPassives.class_label(charList[neighbor].charClass)
		neighbor_buttons[side].tooltip_text = "Ver " + charList[neighbor].charName
	for page_index in detail_pages.size():
		detail_pages[page_index].visible = page_index == selected_index
		quick_buttons[page_index].set_pressed_no_signal(page_index == selected_index)
	if is_instance_valid(portrait_tween):
		portrait_tween.kill()
	portrait.self_modulate.a = 0.45 if animate else 1.0
	if animate:
		portrait_tween = create_tween()
		portrait_tween.tween_property(portrait, "self_modulate:a", 1.0, 0.16)

func navigate(direction: int) -> void:
	show_character(selected_index + direction)

func choose_character() -> void:
	if confirmed:
		return
	confirmed = true
	play_button.disabled = true
	playerSelected.emit(current_character())

func _input(event: InputEvent) -> void:
	if confirmed or not $Screen.is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		navigate(-1 if key in [KEY_LEFT, KEY_A] else 1)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not confirmed and $Screen.is_visible_in_tree() and event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		choose_character()

func _exit_tree() -> void:
	for character in charList:
		if is_instance_valid(character):
			character.free()
